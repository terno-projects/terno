# Terno

Go + React 构建的单文件 Web 应用，提供 Termius 风格的响应式界面和可交互终端预览。前端已嵌入可执行文件，运行无需安装 Node.js、Go 或配置额外静态文件。

> 当前为界面演示版本：主机、终端与注册均为演示功能，不建立真实 SSH 连接，不创建账户或持久化用户数据。非 Termius 官方产品。

## 安装

Linux / macOS（需要 `curl`、`jq`，以及 `sha256sum` 或 `shasum`）：

```bash
curl -fsSL https://raw.githubusercontent.com/terno-projects/terno/main/install.sh | sh
```

macOS 可先执行 `brew install jq`；Debian / Ubuntu 可通过系统包管理器安装 `curl jq`。安装脚本本身不使用 `sudo`。

Windows（PowerShell 5.1+）：

```powershell
irm https://raw.githubusercontent.com/terno-projects/terno/main/install.ps1 | iex
```

脚本自动识别系统和架构，下载最新正式版本，并核对 GitHub Release 提供的 SHA256 摘要及程序版本。默认在后台启动并配置**当前用户登录后自动启动**，不会打开浏览器，也不会修改防火墙：

- Linux：systemd user service，需要可用的用户服务管理器；不设置 linger。
- macOS：当前用户的 LaunchAgent，需要在用户图形登录会话中执行。
- Windows：当前用户的启动注册表项，不需要管理员权限。

安装后访问 **http://localhost:7200**。

> 当前版本监听所有网络接口，且没有登录认证或 TLS。仅在可信设备/网络中使用；需要公网部署时，请自行配置防火墙和带认证的 HTTPS 反向代理。

建议先下载并检查脚本再执行：

```bash
curl -fsSL https://raw.githubusercontent.com/terno-projects/terno/main/install.sh -o install.sh
less install.sh
sh install.sh
```

### 仅安装，不启动

没有 systemd 用户会话的服务器、容器，或希望自行管理进程时：

```bash
curl -fsSL https://raw.githubusercontent.com/terno-projects/terno/main/install.sh | sh -s -- --no-start
~/.local/bin/terno
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/terno-projects/terno/main/install.ps1))) -NoStart
& "$env:LOCALAPPDATA\Programs\Terno\bin\terno.exe"
```

`--no-start` / `-NoStart` 不创建或启用自动启动项；如已有本脚本管理的服务，会停用它。安装程序不会结束其他位置的 Terno 进程。

### 自定义安装目录与端口

Linux / macOS：

```bash
curl -fsSL https://raw.githubusercontent.com/terno-projects/terno/main/install.sh -o install.sh
TERNO_INSTALL_DIR="$HOME/.local/bin" TERNO_PORT=7300 sh install.sh
```

Windows：

```powershell
$env:TERNO_PORT = '7300'
$env:TERNO_INSTALL_DIR = "$env:LOCALAPPDATA\Programs\Terno\bin"
irm https://raw.githubusercontent.com/terno-projects/terno/main/install.ps1 | iex
```

安装脚本把 `TERNO_PORT` 写入启动配置；手动运行程序使用 `PORT` 环境变量：

```bash
PORT=7300 ~/.local/bin/terno
~/.local/bin/terno --version
```

```powershell
$env:PORT = '7300'
& "$env:LOCALAPPDATA\Programs\Terno\bin\terno.exe"
```

## 升级

重新执行安装命令即可。脚本先下载并校验新程序，再停止它管理的旧进程并替换可执行文件。升级会短暂停止服务；若使用过自定义安装目录或端口，升级时请继续传入相同参数。

## 卸载

Linux / macOS：

```bash
curl -fsSL https://raw.githubusercontent.com/terno-projects/terno/main/install.sh | sh -s -- --uninstall
```

Windows：

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/terno-projects/terno/main/install.ps1))) -Uninstall
```

卸载停止本脚本管理的服务，移除自动启动配置及安装目录中的 Terno 程序，不删除其他文件。自定义目录安装的用户需传入原 `TERNO_INSTALL_DIR`。macOS 日志保留在 `~/Library/Logs/Terno`；Linux 日志由 systemd journal 管理。

## 服务管理

Linux：

```bash
systemctl --user status terno.service
systemctl --user restart terno.service
systemctl --user stop terno.service
journalctl --user -u terno.service -n 50
```

macOS 日志：`~/Library/Logs/Terno/server.log` 和 `server-error.log`，启动配置：`~/Library/LaunchAgents/projects.terno.terno.plist`。

Windows 启动项：`HKCU\Software\Microsoft\Windows\CurrentVersion\Run` 下的 `Terno Server`；可在任务管理器查看 `terno.exe`。默认安装目录为 `%LOCALAPPDATA%\Programs\Terno\bin`。

## 手动下载

在 [GitHub Releases](https://github.com/terno-projects/terno/releases/latest) 下载对应平台的独立程序：

| 系统 | 架构 | 附件名称 |
| --- | --- | --- |
| Linux | x86_64 / amd64 | `terno-<版本>-linux-amd64` |
| Linux | aarch64 / arm64 | `terno-<版本>-linux-arm64` |
| macOS | Intel | `terno-<版本>-darwin-amd64` |
| macOS | Apple Silicon | `terno-<版本>-darwin-arm64` |
| Windows | x64 | `terno-<版本>-windows-amd64.exe` |
| Windows | ARM64 | `terno-<版本>-windows-arm64.exe` |

Linux / macOS 下载后先执行 `chmod +x <文件名>`，再运行程序。Windows 直接运行 `.exe`；手动运行时保持终端窗口打开。

macOS 程序目前未签名、未公证，可能需要在“系统设置 → 隐私与安全性”中明确允许打开。Windows 程序未签名，SmartScreen 可能提示确认。脚本不会绕过系统安全检查；校验失败时不会安装下载文件。

## 仓库说明

本仓库仅提供公开安装说明、安装脚本和二进制发布，不包含应用源码。品牌及商标属于原权利人。
