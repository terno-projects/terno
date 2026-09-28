# Terno

Terno 是本地运行的 SSH 客户端，提供浏览器界面和 MCP 接口。支持 SSH 终端、SFTP、主机与密钥管理以及本地端口转发；连接从本机直接发起。

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

安装后访问 http://localhost:7200。

## MCP

在 Terno 页面侧栏打开 **MCP access**，生成 Token 并复制客户端配置。MCP 服务只监听本机地址，使用 Bearer Token 认证；进程重启后已配置的 Token 继续有效，不需要通过界面解锁。Token 只在生成或重置时显示，请当时保存。

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
