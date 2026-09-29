# Terno

Terno 是本地运行的远程终端客户端，提供浏览器界面和 MCP 接口。支持 SSH 终端、SFTP、主机与密钥管理以及本地端口转发；连接从本机直接发起。Linux 服务器也可以安装 Terno Agent，在不运行 SSH 服务的情况下提供终端、文件和端口转发功能。

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

Linux 服务器可运行 Terno Agent。通过目标服务器可访问的 HTTPS 地址打开 Terno，在 **New host** 中选择 **Terno Agent** 并生成安装命令，无需填写服务器地址或端口；在目标服务器上以普通用户执行该命令，即可下载校验 Agent、初始化身份、启动 systemd 用户服务并向 Terno 报到。Terno 验证 Agent 身份后自动保存发现的地址。安装命令包含可重建 Agent 身份和访问密钥的私有材料，安装完成后也必须保密。Agent 默认监听 `0.0.0.0:7222`，Terno 必须能直连该端口，服务器应只允许 Terno 电脑访问。安装命令和脚本需要 `bash`、`curl`、`jq`、`sha256sum`和可用的 systemd 用户管理器。
