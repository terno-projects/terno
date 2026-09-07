#!/bin/sh
set -eu

REPOSITORY="terno-projects/terno"
INSTALL_DIR="${TERNO_INSTALL_DIR:-${HOME:?HOME must be set}/.local/bin}"
INSTALL_PATH="${INSTALL_DIR}/terno"
SERVER_PORT="${TERNO_PORT:-7200}"
HOST_OS="$(uname -s)"
SERVICE_FILE="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user/terno.service"
AGENT_FILE="${HOME}/Library/LaunchAgents/projects.terno.terno.plist"
LOG_DIR="${HOME}/Library/Logs/Terno"
temporary_dir=""
staged_binary=""
no_start=false

fail() { printf 'error: %s\n' "$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }
require() { command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"; }
cleanup() {
  [ -z "${temporary_dir}" ] || rm -rf -- "${temporary_dir}"
  [ -z "${staged_binary}" ] || rm -f -- "${staged_binary}"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

case "${INSTALL_DIR}" in /*) ;; *) fail 'TERNO_INSTALL_DIR must be an absolute path' ;; esac
case "${INSTALL_DIR}" in *'
'*) fail 'install path cannot contain a newline' ;; esac
case "${SERVER_PORT}" in ''|*[!0-9]*) fail 'TERNO_PORT must be an integer from 1 to 65535' ;; esac
[ "${#SERVER_PORT}" -le 5 ] && [ "${SERVER_PORT}" -ge 1 ] && [ "${SERVER_PORT}" -le 65535 ] || fail 'invalid TERNO_PORT'

systemd_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/%/%%/g'; }
xml_escape() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

check_identity() {
  if [ -e "${INSTALL_PATH}" ] || [ -L "${INSTALL_PATH}" ]; then
    [ ! -L "${INSTALL_PATH}" ] || fail 'refusing to replace or remove a symbolic link'
    [ -x "${INSTALL_PATH}" ] || fail 'existing install path is not executable'
    identity="$("${INSTALL_PATH}" --version 2>/dev/null)" || fail 'cannot verify existing binary'
    case "${identity}" in 'terno '*) ;; *) fail 'existing file does not identify itself as Terno' ;; esac
  fi
}

remove_startup() {
  case "${HOST_OS}" in
    Linux)
      if [ -f "${SERVICE_FILE}" ]; then
        require systemctl
        systemctl --user disable --now terno.service || fail 'could not stop the managed user service'
        rm -f -- "${SERVICE_FILE}"
        systemctl --user daemon-reload
      fi
      ;;
    Darwin)
      if [ -f "${AGENT_FILE}" ]; then
        require launchctl
        if launchctl print "gui/$(id -u)/projects.terno.terno" >/dev/null 2>&1; then
          launchctl bootout "gui/$(id -u)" "${AGENT_FILE}" || fail 'could not stop the managed LaunchAgent'
        fi
        rm -f -- "${AGENT_FILE}"
      fi
      ;;
    *) fail "unsupported operating system: ${HOST_OS}" ;;
  esac
}

enable_startup() {
  case "${HOST_OS}" in
    Linux)
      mkdir -p "$(dirname "${SERVICE_FILE}")"
      cat >"${SERVICE_FILE}" <<EOF
[Unit]
Description=Terno Web Server
After=network-online.target

[Service]
Type=simple
ExecStart="$(systemd_escape "${INSTALL_PATH}")"
Environment="PORT=${SERVER_PORT}"
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
      systemctl --user daemon-reload
      systemctl --user enable --now terno.service
      ;;
    Darwin)
      mkdir -p "$(dirname "${AGENT_FILE}")" "${LOG_DIR}"
      cat >"${AGENT_FILE}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>projects.terno.terno</string>
<key>ProgramArguments</key><array><string>$(xml_escape "${INSTALL_PATH}")</string></array>
<key>EnvironmentVariables</key><dict><key>PORT</key><string>${SERVER_PORT}</string></dict>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
<key>StandardOutPath</key><string>$(xml_escape "${LOG_DIR}")/server.log</string>
<key>StandardErrorPath</key><string>$(xml_escape "${LOG_DIR}")/server-error.log</string>
<key>ThrottleInterval</key><integer>5</integer>
</dict></plist>
EOF
      launchctl bootstrap "gui/$(id -u)" "${AGENT_FILE}"
      ;;
  esac
}

case "${1:-}" in
  --uninstall)
    [ "$#" -eq 1 ] || fail 'unexpected arguments'
    check_identity
    remove_startup
    rm -f -- "${INSTALL_PATH}"
    say "Removed managed startup configuration and ${INSTALL_PATH}. Logs and other files were kept."
    exit 0 ;;
  --no-start) [ "$#" -eq 1 ] || fail 'unexpected arguments'; no_start=true ;;
  -h|--help) say 'Usage: install.sh [--no-start | --uninstall]'; exit 0 ;;
  '') [ "$#" -eq 0 ] || fail 'unexpected arguments' ;;
  *) fail "unknown argument: $1" ;;
esac

for tool in curl jq mktemp chmod sed; do require "${tool}"; done
if command -v sha256sum >/dev/null 2>&1; then checksum_tool=sha256sum
elif command -v shasum >/dev/null 2>&1; then checksum_tool=shasum
else fail 'sha256sum or shasum is required'; fi
case "${HOST_OS}" in Linux) target_os=linux ;; Darwin) target_os=darwin ;; *) fail "unsupported OS: ${HOST_OS}" ;; esac
case "$(uname -m)" in x86_64|amd64) target_arch=amd64 ;; arm64|aarch64) target_arch=arm64 ;; *) fail 'only amd64 and arm64 are supported' ;; esac
check_identity
if [ "${no_start}" = false ]; then
  case "${HOST_OS}" in
    Linux) require systemctl; systemctl --user show-environment >/dev/null 2>&1 || fail 'systemd user manager unavailable; use --no-start' ;;
    Darwin) require launchctl; launchctl print "gui/$(id -u)" >/dev/null 2>&1 || fail 'GUI login session unavailable; use --no-start' ;;
  esac
fi

temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/terno-install.XXXXXX")"
curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --connect-timeout 15 --max-time 90 \
  -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/${REPOSITORY}/releases/latest" -o "${temporary_dir}/release.json"
release_tag="$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' "${temporary_dir}/release.json")" || fail 'invalid release tag'
asset_name="terno-${release_tag}-${target_os}-${target_arch}"
expected_checksum="$(jq -er --arg name "${asset_name}" '[.assets[] | select(.name == $name)] | select(length == 1) | .[0].digest | select(test("^sha256:[0-9a-fA-F]{64}$")) | sub("^sha256:"; "") | ascii_downcase' "${temporary_dir}/release.json")" || fail 'release has no unique asset with a SHA256 digest'
say "Downloading Terno ${release_tag} for ${target_os}/${target_arch}..."
curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL --retry 3 --connect-timeout 15 --max-time 300 \
  "https://github.com/${REPOSITORY}/releases/download/${release_tag}/${asset_name}" -o "${temporary_dir}/terno"
if [ "${checksum_tool}" = sha256sum ]; then actual_checksum="$(sha256sum "${temporary_dir}/terno")"
else actual_checksum="$(shasum -a 256 "${temporary_dir}/terno")"; fi
actual_checksum="${actual_checksum%% *}"
[ "${actual_checksum}" = "${expected_checksum}" ] || fail 'SHA256 mismatch; existing installation was not changed'
chmod 0755 "${temporary_dir}/terno"
[ "$("${temporary_dir}/terno" --version)" = "terno ${release_tag#v}" ] || fail 'downloaded binary failed version verification'
mkdir -p "${INSTALL_DIR}"
staged_binary="$(mktemp "${INSTALL_DIR}/.terno-install.XXXXXX")"
cp "${temporary_dir}/terno" "${staged_binary}"
chmod 0755 "${staged_binary}"
remove_startup
mv -f -- "${staged_binary}" "${INSTALL_PATH}"
staged_binary=""
say "Verified and installed ${release_tag} at ${INSTALL_PATH}."
case ":${PATH}:" in *:"${INSTALL_DIR}":*) ;; *) say "Add ${INSTALL_DIR} to PATH, or run the full path shown above." ;; esac
if [ "${no_start}" = true ]; then
  say "Not started. Run: PORT=${SERVER_PORT} \"${INSTALL_PATH}\""
  exit 0
fi
enable_startup
attempt=0
while [ "${attempt}" -lt 30 ]; do
  managed_running=false
  case "${HOST_OS}" in
    Linux) if systemctl --user is-active --quiet terno.service; then managed_running=true; fi ;;
    Darwin) if launchctl print "gui/$(id -u)/projects.terno.terno" 2>/dev/null | grep -q 'state = running'; then managed_running=true; fi ;;
  esac
  if [ "${managed_running}" = true ] && curl -fsS --max-time 2 "http://127.0.0.1:${SERVER_PORT}/api/health" | jq -e --arg version "${release_tag#v}" '.service == "terno" and .status == "ok" and .version == $version' >/dev/null 2>&1; then
    say "Terno is running at http://localhost:${SERVER_PORT}. Login startup enabled."
    exit 0
  fi
  attempt=$((attempt + 1))
  sleep 1
done
fail 'startup not confirmed; check service logs and port conflicts. The installed binary and startup configuration were kept.'
