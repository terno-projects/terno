# Terno

Termius 风格的 Web 终端工作台，当前为界面演示版本，不建立真实 SSH 连接。

## 安装

Linux / macOS（需安装 `curl` 和 `jq`）：

```bash
curl -fsSL https://raw.githubusercontent.com/terno-projects/terno/main/install.sh | sh
```

Windows（PowerShell）：

```powershell
irm https://raw.githubusercontent.com/terno-projects/terno/main/install.ps1 | iex
```

安装脚本会在后台启动 Terno，并配置当前用户登录后自动启动；不会自动打开浏览器。Linux 使用 systemd user service，macOS 使用 LaunchAgent，Windows 使用当前用户的启动注册表项，全程不需要管理员权限。

安装后访问 http://localhost:7200。重新执行安装命令即可升级。当前无登录认证，请仅在可信网络中使用。

## 卸载

Linux / macOS：

```bash
curl -fsSL https://raw.githubusercontent.com/terno-projects/terno/main/install.sh | sh -s -- --uninstall
```

Windows（PowerShell）：

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/terno-projects/terno/main/install.ps1))) -Uninstall
```

卸载会停止 Terno 并移除对应的自动启动项和程序，日志仍会保留。

## 手动下载

可以在 [GitHub Releases](https://github.com/terno-projects/terno/releases/latest) 下载 Linux、macOS 或 Windows 对应架构的可执行文件。
