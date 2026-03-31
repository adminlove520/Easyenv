#!/bin/bash
# 基础环境安装部署脚本
# 包含: Python 3.13, Docker, Java 1.8, NVM, Go, Rust
# 支持系统: CentOS 7+, Ubuntu 20.04+, Windows (Git Bash)
# 支持交互式选择安装组件及镜像配置

# ==============================================
# 配置区
# ==============================================
PYTHON_VERSION="3.13.12"
NVM_VERSION="v0.40.4"
GO_VERSION="1.21.3"
RUST_VERSION="stable"

# 默认不使用国内镜像
USE_MIRROR=false

# 国内源配置
PYPI_MIRROR="https://pypi.tuna.tsinghua.edu.cn/simple"
DOCKER_MIRROR="https://registry.cn-hangzhou.aliyuncs.com"
GOPROXY="https://goproxy.cn,direct"
NVM_MIRROR="https://gitee.com/mirrors/nvm/raw"
PYTHON_MIRROR="https://mirrors.huaweicloud.com/python"
PYTHON_OFFICIAL_URL="https://www.python.org/ftp/python"
GO_MIRROR="https://mirrors.aliyun.com/golang"
NPM_REGISTRY="https://registry.npmmirror.com"
RUSTUP_DIST_SERVER="https://mirrors.ustc.edu.cn/rust-static"
RUSTUP_UPDATE_ROOT="https://mirrors.ustc.edu.cn/rust-static/rustup"

MIRROR_SCRIPT_URL="https://gitee.com/SuperManito/LinuxMirrors/raw/main/ChangeMirrors.sh"

# ==============================================
# 操作系统检测
# ==============================================
OS_TYPE="unknown"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_TYPE=$ID
    fi
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
    OS_TYPE="windows"
fi

# ==============================================
# 终端颜色设置
# ==============================================
if [ -t 1 ]; then
    export TERM=xterm-256color
    NC=$(tput sgr0)
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    CYAN=$(tput setaf 6)
    LIGHT_BLUE=$(tput bold; tput setaf 4)
    LIGHT_GREEN=$(tput bold; tput setaf 2)
    LIGHT_RED=$(tput bold; tput setaf 1)
    LIGHT_YELLOW=$(tput bold; tput setaf 3)
    LIGHT_MAGENTA=$(tput bold; tput setaf 5)
else
    NC="" RED="" GREEN="" YELLOW="" BLUE="" CYAN="" LIGHT_BLUE="" LIGHT_GREEN="" LIGHT_RED="" LIGHT_YELLOW="" LIGHT_MAGENTA=""
fi

TITLE_COLOR="${LIGHT_BLUE}"
INFO_COLOR="${CYAN}"
SUCCESS_COLOR="${LIGHT_GREEN}"
WARNING_COLOR="${YELLOW}"
ERROR_COLOR="${LIGHT_RED}"
PROMPT_COLOR="${LIGHT_YELLOW}"
HIGHLIGHT_COLOR="${LIGHT_MAGENTA}"
SEPARATOR_COLOR="${BLUE}"

TEMP_DIR=$(mktemp -d /tmp/setup_env.XXXXXX 2>/dev/null || mktemp -d)
LOG_FILE="${TEMP_DIR}/install.log"

# ==============================================
# 工具函数
# ==============================================
log() {
    local level=$1; local message=$2; local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

progress() {
    echo -e "\n${SEPARATOR_COLOR}==============================================${NC}"
    echo -e "${TITLE_COLOR}===== 正在执行: $1 =====${NC}"
    echo -e "${SEPARATOR_COLOR}==============================================${NC}\n"
    log "INFO" "开始执行: $1"
}

success() { echo -e "\n${SUCCESS_COLOR}===== 执行成功: $1 =====${NC}\n"; log "INFO" "执行成功: $1"; }
error() { echo -e "\n${ERROR_COLOR}===== 执行失败: $1 =====${NC}\n" >&2; log "ERROR" "执行失败: $1"; }
warning() { echo -e "${WARNING_COLOR}警告: $1${NC}"; log "WARNING" "警告: $1"; }
info() { echo -e "${INFO_COLOR}信息: $1${NC}"; log "INFO" "信息: $1"; }

command_exists() { command -v "$1" &> /dev/null; }

handle_error() {
    local step=$1; local exit_code=$2
    error "在执行 '$step' 时发生错误，退出码: $exit_code"
    [ "$OS_TYPE" != "windows" ] && cleanup
    exit $exit_code
}

cleanup() {
    log "INFO" "开始清理临时文件"
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
    log "INFO" "清理完成"
}

verify_install() {
    local name=$1; local command=$2; local version_cmd=$3
    if command_exists "$command"; then
        log "INFO" "$name 版本: $($version_cmd 2>&1 | head -n 1)"
        return 0
    else
        log "ERROR" "$name 验证失败: 未找到命令 $command"
        return 1
    fi
}

# ==============================================
# 交互菜单
# ==============================================
select_options() {
    echo -e "\n${TITLE_COLOR}===== 环境配置选项 =====${NC}"
    echo -ne "${PROMPT_COLOR}是否使用国内镜像加速 (China Mirrors)? (y/n): ${NC}"
    read mirror_confirm
    [[ $mirror_confirm == "y" || $mirror_confirm == "Y" ]] && USE_MIRROR=true

    echo -e "\n${TITLE_COLOR}===== 请选择要安装的组件 (可多选) =====${NC}"
    echo -e "${INFO_COLOR}1)${NC} Python ${HIGHLIGHT_COLOR}${PYTHON_VERSION}${NC}"
    echo -e "${INFO_COLOR}2)${NC} Docker 和 Docker Compose"
    echo -e "${INFO_COLOR}3)${NC} Java 1.8"
    echo -e "${INFO_COLOR}4)${NC} NVM ${HIGHLIGHT_COLOR}${NVM_VERSION}${NC}"
    echo -e "${INFO_COLOR}5)${NC} Go ${HIGHLIGHT_COLOR}${GO_VERSION}${NC}"
    echo -e "${INFO_COLOR}6)${NC} Rust ${HIGHLIGHT_COLOR}${RUST_VERSION}${NC}"
    echo -e "${INFO_COLOR}7)${NC} 安装全部组件"
    echo -e "${INFO_COLOR}0)${NC} 取消"
    echo -ne "${PROMPT_COLOR}请输入选项编号 (空格分隔): ${NC}"
    read -a input
    
    INSTALL_PYTHON=false; INSTALL_DOCKER=false; INSTALL_JAVA=false; INSTALL_NVM=false; INSTALL_GO=false; INSTALL_RUST=false
    for choice in "${input[@]}"; do
        case $choice in
            1) INSTALL_PYTHON=true ;;
            2) INSTALL_DOCKER=true ;;
            3) INSTALL_JAVA=true ;;
            4) INSTALL_NVM=true ;;
            5) INSTALL_GO=true ;;
            6) INSTALL_RUST=true ;;
            7) INSTALL_PYTHON=true; INSTALL_DOCKER=true; INSTALL_JAVA=true; INSTALL_NVM=true; INSTALL_GO=true; INSTALL_RUST=true ;;
            0) exit 0 ;;
        esac
    done
}

# ==============================================
# Linux 安装逻辑
# ==============================================
install_linux_base() {
    progress "安装基础依赖"
    if [[ "$OS_TYPE" == "centos" || "$OS_TYPE" == "rocky" || "$OS_TYPE" == "almalinux" ]]; then
        yum install -y wget gcc gcc-c++ make openssl-devel bzip2-devel libffi-devel zlib-devel readline-devel sqlite-devel perl net-tools tk-devel xz-devel gdbm-devel ncurses-devel || handle_error "基础依赖失败" $?
    elif [[ "$OS_TYPE" == "ubuntu" || "$OS_TYPE" == "debian" ]]; then
        apt-get update && apt-get install -y wget build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev curl libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev || handle_error "基础依赖失败" $?
    fi
}

configure_linux_mirrors() {
    if [ "$USE_MIRROR" = true ]; then
        progress "配置系统源"
        curl -sSL "${MIRROR_SCRIPT_URL}" | bash || warning "系统源配置失败"
    fi
}

install_linux_python() {
    [ "$INSTALL_PYTHON" = false ] && return 0
    progress "安装 Python ${PYTHON_VERSION}"
    local python_tar="Python-${PYTHON_VERSION}.tgz"
    local download_url="${PYTHON_OFFICIAL_URL}/${PYTHON_VERSION}/${python_tar}"
    [ "$USE_MIRROR" = true ] && download_url="${PYTHON_MIRROR}/${PYTHON_VERSION}/${python_tar}"
    
    wget -c -P "$TEMP_DIR" "$download_url" || handle_error "Python下载失败" 1
    tar -zxvf "${TEMP_DIR}/${python_tar}" -C "$TEMP_DIR"
    cd "${TEMP_DIR}/Python-${PYTHON_VERSION}"
    ./configure --prefix=/usr/local/python3 --enable-optimizations --with-lto --enable-shared || handle_error "Python配置失败" $?
    make -j $(nproc) && make install || handle_error "Python安装失败" $?
    ln -sf /usr/local/python3/bin/python3 /usr/bin/python3
    ln -sf /usr/local/python3/bin/pip3 /usr/bin/pip3
    echo "/usr/local/python3/lib" > /etc/ld.so.conf.d/python3.conf && ldconfig
    
    if [ "$USE_MIRROR" = true ]; then
        mkdir -p ~/.pip
        cat > ~/.pip/pip.conf << EOF
[global]
index-url = ${PYPI_MIRROR}
EOF
    fi
    verify_install "Python" "python3" "python3 --version"
}

install_linux_docker() {
    [ "$INSTALL_DOCKER" = false ] && return 0
    progress "安装 Docker"
    if [[ "$OS_TYPE" == "centos" || "$OS_TYPE" == "rocky" ]]; then
        yum install -y yum-utils
        [ "$USE_MIRROR" = true ] && yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo || yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io
    elif [[ "$OS_TYPE" == "ubuntu" ]]; then
        apt-get install -y ca-certificates curl gnupg lsb-release
        mkdir -p /etc/apt/keyrings
        local gpg_url="https://download.docker.com/linux/ubuntu/gpg"
        local repo_url="https://download.docker.com/linux/ubuntu"
        if [ "$USE_MIRROR" = true ]; then
            gpg_url="https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg"
            repo_url="https://mirrors.aliyun.com/docker-ce/linux/ubuntu"
        fi
        curl -fsSL "$gpg_url" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $repo_url $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io
    fi
    if [ "$USE_MIRROR" = true ]; then
        mkdir -p /etc/docker
        echo "{ \"registry-mirrors\": [\"${DOCKER_MIRROR}\"] }" > /etc/docker/daemon.json
    fi
    systemctl daemon-reload && systemctl start docker && systemctl enable docker
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose && ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
}

install_linux_java() {
    [ "$INSTALL_JAVA" = false ] && return 0
    progress "安装 Java 1.8"
    [[ "$OS_TYPE" == "centos" ]] && yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel
    [[ "$OS_TYPE" == "ubuntu" ]] && apt-get install -y openjdk-8-jdk
}

install_linux_nvm() {
    [ "$INSTALL_NVM" = false ] && return 0
    progress "安装 NVM"
    local nvm_url="https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh"
    [ "$USE_MIRROR" = true ] && nvm_url="${NVM_MIRROR}/${NVM_VERSION}/install.sh"
    curl -o- "$nvm_url" | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts
    [ "$USE_MIRROR" = true ] && npm config set registry "${NPM_REGISTRY}"
}

install_linux_go() {
    [ "$INSTALL_GO" = false ] && return 0
    progress "安装 Go"
    local go_tar="go${GO_VERSION}.linux-amd64.tar.gz"
    local download_url="https://golang.org/dl/${go_tar}"
    [ "$USE_MIRROR" = true ] && download_url="${GO_MIRROR}/${go_tar}"
    wget -P "$TEMP_DIR" "$download_url"
    rm -rf /usr/local/go && tar -C /usr/local -xzf "${TEMP_DIR}/${go_tar}"
    if ! grep -q "GOROOT" /etc/profile; then
        echo "export GOROOT=/usr/local/go" >> /etc/profile
        echo "export GOPATH=\$HOME/go" >> /etc/profile
        echo "export PATH=\$PATH:\$GOROOT/bin:\$GOPATH/bin" >> /etc/profile
        [ "$USE_MIRROR" = true ] && echo "export GOPROXY=${GOPROXY}" >> /etc/profile
    fi
}

install_linux_rust() {
    [ "$INSTALL_RUST" = false ] && return 0
    progress "安装 Rust"
    if [ "$USE_MIRROR" = true ]; then
        export RUSTUP_DIST_SERVER="${RUSTUP_DIST_SERVER}"
        export RUSTUP_UPDATE_ROOT="${RUSTUP_UPDATE_ROOT}"
    fi
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
}

# ==============================================
# Windows 转发
# ==============================================
run_windows_setup() {
    info "检测到 Windows 环境，正在启动 PowerShell 安装程序..."
    if [ ! -f "./setup_env.ps1" ]; then
        error "未找到 setup_env.ps1，请确保该文件存在"
        exit 1
    fi
    # 转换为 Windows 路径（如果需要）
    powershell.exe -ExecutionPolicy Bypass -File "./setup_env.ps1"
    exit 0
}

# ==============================================
# 主入口
# ==============================================
main() {
    [ "$OS_TYPE" == "windows" ] && run_windows_setup
    
    trap cleanup EXIT
    echo -e "${TITLE_COLOR}===== Easyenv 环境一键部署 (Linux) =====${NC}"
    [ "$(id -u)" -ne 0 ] && { echo -e "${ERROR_COLOR}请使用 root 用户运行此脚本${NC}"; exit 1; }
    
    select_options
    install_linux_base
    configure_linux_mirrors
    install_linux_python
    install_linux_docker
    install_linux_java
    install_linux_nvm
    install_linux_go
    install_linux_rust
    
    echo -e "\n${SUCCESS_COLOR}===== 安装完成! =====${NC}"
    echo -e "${INFO_COLOR}请执行 'source /etc/profile' 或重新登录生效${NC}"
}

main
