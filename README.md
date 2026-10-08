# Terno

Local-first 的 SSH 工作台，支持真实 SSH 终端、SFTP、密钥管理和命令片段。SSH 连接由用户电脑上的 Terno 进程发起；Linux、macOS 和 Windows Agent 主动连接 Terno，不经过中心服务器。

Terno 只发布一个可执行文件：`terno server` 启动网页服务，`terno agent` 在 Linux、macOS 或 Windows 上运行 Agent；不带参数执行 `terno` 也会启动网页服务。

## 安装 Terno 网页服务

Linux / macOS（需安装 `curl` 和 `jq`）：

```bash
curl -fsSL https://raw.githubusercontent.com/terno-projects/terno/main/install.sh | sh
```

Windows（PowerShell）：

```powershell
irm https://raw.githubusercontent.com/terno-projects/terno/main/install.ps1 | iex
```

安装脚本会在后台启动 Terno，并配置当前用户登录后自动启动；不会自动打开浏览器。Linux 使用 systemd user service，macOS 使用 LaunchAgent，Windows 使用当前用户的启动注册表项，全程不需要管理员权限。

安装后访问 http://localhost:7200。

## 卸载 Terno 网页服务

Linux / macOS：

```bash
curl -fsSL https://raw.githubusercontent.com/terno-projects/terno/main/install.sh | sh -s -- --uninstall
```

Windows（PowerShell）：

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/terno-projects/terno/main/install.ps1))) -Uninstall
```

卸载会停止网页服务并移除对应的自动启动项和程序，日志与用户数据仍会保留。Agent 的后台服务或登录自启项需在远端单独停用和移除。

## 安装 Terno Agent

远端 Linux、macOS 和 Windows 电脑安装的也是同一个 `terno` 程序，无需运行 SSH 服务或开放 Agent 入站端口。通过目标电脑可访问的 HTTPS 地址打开 Terno，新建主机时选择 **Terno Agent** 并生成安装命令；无需填写服务器地址或端口。安装弹窗默认选择 **Linux / macOS**，两者共用一条 `sh` 命令，脚本自动识别系统；Windows 选择 **Windows (PowerShell)**。复制对应命令到目标电脑，以需要操作文件和终端的用户身份执行。命令从当前 Terno 下载安装脚本，脚本已包含服务端地址；只需传入配对码。配对码包含私有密钥材料，安装后仍需保密。

安装脚本从公开 Release 下载 amd64 或 arm64 对应程序，校验 SHA-256、初始化身份，并配置后台运行和自动启动：

- Linux：需要 `curl`、`jq`、`sha256sum` 和 systemd。root 安装系统服务；普通用户安装 systemd 用户服务，需可用的用户管理器，退出登录后运行需启用 linger。
- macOS：需要 `curl`、`jq` 和 `shasum`。root 安装 launchd 系统 daemon；普通用户在 GUI 登录会话中安装 LaunchAgent，随用户登录启动。
- Windows：需要 Windows 10 1809 / Windows Server 2019 或更新版本，以及 Windows PowerShell。安装到当前用户目录，通过 Startup 文件夹中的快捷方式配置登录自启，无需管理员权限；退出登录后停止运行。

Terno 验证 Agent 身份后自动保存主机。终端、命令和文件都经 Agent 主动发起的 HTTPS 连接传输，默认从运行用户的主目录开始。交互终端在 Linux 使用 `/bin/sh`、macOS 使用 `/bin/zsh`、Windows 使用 PowerShell；非交互命令在 Linux/macOS 使用 `/bin/sh -lc`，Windows 使用 PowerShell 语法。Windows 交互终端使用 ConPTY，文件操作支持盘符和 UNC 路径。

Agent 凭据保存在用户配置目录的 `terno-agent/` 中；Linux/macOS 使用 `0700` 目录和 `0600` 文件权限，Windows 使用只允许当前用户和 Local System 访问的 ACL。需要手动运行时使用 `terno agent --server <Terno HTTPS 地址>`，Windows 可执行文件名为 `terno.exe`。生成的安装命令下载最新公开 Release；需先发布包含对应平台支持的版本。

生成 Agent 安装命令时只创建临时配对申请，Agent 连接并通过身份验证后才加入主机列表。配对命令有效期为 30 分钟；配对前取消或关闭安装弹窗会撤销命令。未完成的申请也会在 Terno 重启时清除。

## 更新 Terno Agent

在主机列表点击 Agent 行的 **Update Agent**，查看版本、系统和架构，并由服务端下发更新任务。已有安装脚本管理的 Agent 也能直接更新，无需重新安装或配对。更新管理和 MCP 接口均在 Terno 服务端；Agent 通过原有连接执行命令和文件操作，不提供 MCP 服务。

服务端选择官方稳定 Release 中对应平台的产物。独立后台任务下载程序、校验 SHA-256 和版本，然后替换程序并重启 systemd / launchd 服务或 Windows runner，保留配对身份与原有服务配置。重启会中断远端终端与正在执行的命令；关闭弹窗不影响任务。同一个 Agent 同时只接受一个任务，已是目标版本时无需重启，拒绝降级。

服务端 MCP 提供 `get_agent_info({hostId})`、`update_agent({hostId, version?})` 和 `get_agent_update_status({hostId})`。`version` 默认 `latest`，可指定官方稳定版本。更新调用立即返回任务 ID；查询状态直到 `completed`、`up_to_date` 或 `failed`，只有目标版本的 Agent 重连且进程已重启后才确认完成。任务记录保存在远端 Agent 数据目录的 `update.json`；服务端 15 分钟内未能确认时报告失败。

Agent 必须在线、由安装脚本的后台服务管理，且能访问官方 GitHub Releases；无后台服务的手动 Agent 不支持此更新方式。

## 手动下载

可以在 [GitHub Releases](https://github.com/terno-projects/terno/releases/latest) 下载 Linux、macOS 或 Windows 对应架构的可执行文件。
