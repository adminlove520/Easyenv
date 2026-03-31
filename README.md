# Easyenv 基础环境一键安装部署脚本

一个用于在 **CentOS (7+)**、**Ubuntu (20.04+)** 以及 **Windows** 系统上快速部署开发环境的自动化工具。支持交互式组件选择，并提供可选的国内网络环境优化。

## 功能特点

- **全平台支持**：兼容 CentOS、Ubuntu、Debian、Rocky Linux 等主流 Linux 发行版，以及 Windows (通过 PowerShell 或 Git Bash)。
- **多组件支持**：可选安装 Python 3.13、Docker (含 Compose)、Java 1.8 (OpenJDK 8)、NVM (Node 版本管理)、Go、Rust。
- **镜像源可选**：支持交互式选择是否开启国内镜像加速（不再强制开启，适用于全球 VPS）。
- **统一入口**：Linux 系统下直接运行 `setup_env.sh`，Windows 系统下支持 `setup_env.ps1`。
- **多安装方式 (Windows)**：支持通过 **Scoop** 或 **Winget** 安装组件。

## 支持的组件及版本

| 组件 | 版本 | 说明 |
|------|------|------|
| Python | 3.13.12 | Linux 源码编译 / Windows 二进制安装 |
| Docker | 最新稳定版 | Linux: Docker Engine / Windows: Docker Desktop |
| Java | 1.8 (8) | OpenJDK 8 |
| NVM | v0.40.4 | Linux: nvm-sh / Windows: nvm-windows |
| Go | 1.21.3 | 编程语言 |
| Rust | stable | 包含 rustup 安装及镜像配置 |

## 使用方法

### Linux (CentOS / Ubuntu / Debian)

1. 下载并运行：
   ```bash
   git clone https://github.com/adminlove520/Easyenv.git
   cd Easyenv
   chmod +x setup_env.sh
   sudo ./setup_env.sh
   ```

2. 在交互菜单中：
   - 选择是否使用国内镜像加速 (`y/n`)。
   - 输入组件编号（空格分隔，如 `1 2 4`）或输入 `7` 安装全部。

### Windows

#### 方法 A：使用 PowerShell (推荐)

1. 以 **管理员身份** 运行 PowerShell。
2. 下载并运行：
   ```powershell
   git clone https://github.com/adminlove520/Easyenv.git
   cd Easyenv
   Set-ExecutionPolicy Bypass -Scope Process -Force
   .\setup_env.ps1
   ```
3. 按照提示选择安装工具 (**Scoop** 或 **Winget**) 及组件。

#### 方法 B：使用 Git Bash

1. 打开 Git Bash。
2. 运行脚本（脚本会自动转发给 PowerShell 处理）：
   ```bash
   ./setup_env.sh
   ```

## 注意事项

1. **镜像加速**：若您在海外 VPS 上运行，请在询问时输入 `n`。
2. **权限要求**：Linux 下需 root 权限，Windows 下需管理员权限。
3. **环境变量**：安装完成后，建议执行 `source /etc/profile` (Linux) 或重启终端 (Windows) 使环境生效。

## 鸣谢

- [Scoop](https://scoop.sh/) - 适用于 Windows 的命令行包管理器。
- [LinuxMirrors](https://linuxmirrors.cn/) - 系统镜像站一键配置工具。

## 许可证

MIT License
