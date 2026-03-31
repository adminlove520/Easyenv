# Easyenv 基础环境安装部署脚本

一个用于在 CentOS (7+) 和 Ubuntu (20.04+) 系统上快速部署开发环境的自动化脚本。已针对国内网络环境进行优化，支持交互式组件选择。

## 功能特点

- **多系统支持**：兼容 CentOS 7+、Ubuntu 20.04+、Debian 等主流 Linux 发行版
- **多组件支持**：可选安装 Python、Docker、Java、NVM、Go、Rust
- **国内源优化**：自动配置国内镜像源（PyPI、Docker、NPM、Go Proxy、Rustup 等）
- **交互式选择**：可视化菜单，按需安装
- **日志记录**：自动保存详细安装日志以便排查问题

## 支持的组件及版本

| 组件 | 版本 | 说明 |
|------|------|------|
| Python | 3.13.12 | 编程语言 (源码编译安装) |
| Docker | 最新稳定版 | 容器化平台 (含 Docker Compose) |
| Java | 1.8 | OpenJDK 8 |
| NVM | v0.40.4 | Node 版本管理器 (含 Node.js LTS) |
| Go | 1.21.3 | 编程语言 |
| Rust | stable | 编程语言 (含国内镜像配置) |

## 使用方法

### 前置要求

- 操作系统：CentOS 7+ 或 Ubuntu 20.04+
- 权限：需要 root 用户权限
- 网络：能够访问互联网

### 快速开始

1. 下载脚本并赋予执行权限：
   ```bash
   git clone https://github.com/adminlove520/Easyenv.git
   cd Easyenv
   chmod +x setup_env.sh
   ```

2. 运行脚本：
   ```bash
   ./setup_env.sh
   ```

3. 按照菜单提示选择需要安装的组件：
   - 输入选项编号（多个选项用空格分隔，例如: `1 2 4`）
   - 输入 `7` 安装全部组件
   - 输入 `0` 取消安装

4. 脚本将自动检测您的系统环境并开始执行安装

## 注意事项

1. **环境变量**：安装完成后，建议执行 `source /etc/profile` 或重新登录 SSH 使环境生效。
2. **安装耗时**：部分组件（如 Python）通过源码编译安装，耗时取决于您的服务器配置。
3. **国内加速**：脚本默认配置了国内主流镜像源，若您在海外服务器运行，请根据需要调整脚本开头的镜像变量。
4. **日志查看**：脚本会在运行时提示日志文件位置（通常在 `/tmp/setup_env.XXXXXX/install.log`）。

## 选项说明

运行脚本后显示的菜单：
```
===== Easyenv 基础环境一键部署 =====
1) Python 3.13.12
2) Docker 和 Docker Compose
3) Java 1.8
4) NVM v0.40.4
5) Go 1.21.3
6) Rust stable
7) 安装全部组件
0) 取消
```

## 鸣谢

- [LinuxMirrors](https://linuxmirrors.cn/) - 系统镜像站一键配置工具
- [HuaweiCloud](https://mirrors.huaweicloud.com/)、[Tsinghua](https://mirrors.tuna.tsinghua.edu.cn/)、[USTC](https://mirrors.ustc.edu.cn/) - 优秀的国内镜像资源提供商

## 许可证

MIT License
