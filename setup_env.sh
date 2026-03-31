#!/bin/bash
# 基础环境安装部署脚本(国内源优化版)
# 包含: Python 3.13, Docker, Docker Compose, Java 1.8, NVM, Go, Rust
# 支持系统: CentOS 7+, Ubuntu 20.04+
# 已配置国内源，确保在国内网络环境下可用
# 支持交互式选择安装组件

# ==============================================
# 配置区：集中管理可定制参数
# ==============================================
# 版本配置
PYTHON_VERSION="3.13.12"
NVM_VERSION="v0.40.4"
GO_VERSION="1.21.3"
RUST_VERSION="stable"

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

# 外部源配置脚本URL
MIRROR_SCRIPT_URL="https://gitee.com/SuperManito/LinuxMirrors/raw/main/ChangeMirrors.sh"

# 安装组件选择 (默认全不安装，将通过交互选择设置)
INSTALL_PYTHON=false
INSTALL_DOCKER=false
INSTALL_JAVA=false
INSTALL_NVM=false
INSTALL_GO=false
INSTALL_RUST=false

# 操作系统检测
OS_ID=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
fi

# ==============================================
# 工具函数
# ==============================================

# 日志记录和显示逻辑 (参考原有脚本)
# 为简化代码，此处直接定义颜色变量
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

TEMP_DIR=$(mktemp -d /tmp/setup_env.XXXXXX)
LOG_FILE="${TEMP_DIR}/install.log"

log() {
    local level=$1
    local message=$2
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

progress() {
    echo -e "\n${SEPARATOR_COLOR}==============================================${NC}"
    echo -e "${TITLE_COLOR}===== 正在执行: $1 =====${NC}"
    echo -e "${SEPARATOR_COLOR}==============================================${NC}\n"
    log "INFO" "开始执行: $1"
}

success() {
    echo -e "\n${SUCCESS_COLOR}===== 执行成功: $1 =====${NC}\n"
    log "INFO" "执行成功: $1"
}

error() {
    echo -e "\n${ERROR_COLOR}===== 执行失败: $1 =====${NC}\n" >&2
    log "ERROR" "执行失败: $1"
}

warning() {
    echo -e "${WARNING_COLOR}警告: $1${NC}"
    log "WARNING" "警告: $1"
}

info() {
    echo -e "${INFO_COLOR}信息: $1${NC}"
    log "INFO" "信息: $1"
}

command_exists() {
    command -v "$1" &> /dev/null
}

handle_error() {
    local step=$1
    local exit_code=$2
    error "在执行 '$step' 时发生错误，退出码: $exit_code"
    cleanup
    exit $exit_code
}

cleanup() {
    log "INFO" "开始清理临时文件"
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
    log "INFO" "清理完成"
}

verify_install() {
    local name=$1
    local command=$2
    local version_cmd=$3
    if command_exists "$command"; then
        log "INFO" "$name 版本: $($version_cmd 2>&1 | head -n 1)"
        return 0
    else
        log "ERROR" "$name 验证失败: 未找到命令 $command"
        return 1
    fi
}

# ==============================================
# 前置检查
# ==============================================

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${ERROR_COLOR}请使用root用户运行此脚本${NC}" >&2
        exit 1
    fi
}

check_os() {
    log "INFO" "检查操作系统"
    case "$OS_ID" in
        centos|rocky|almalinux)
            info "检测到 CentOS 系系统: $OS_ID"
            ;;
        ubuntu|debian)
            info "检测到 Ubuntu 系系统: $OS_ID"
            ;;
        *)
            error "不支持的系统: $OS_ID"
            exit 1
            ;;
    esac
}

check_network() {
    log "INFO" "检查网络连接"
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        warning "无法访问公网，请确保网络正常"
    fi
}

# ==============================================
# 组件安装函数
# ==============================================

install_base_dependencies() {
    progress "安装基础依赖包"
    if [[ "$OS_ID" == "centos" || "$OS_ID" == "rocky" || "$OS_ID" == "almalinux" ]]; then
        yum install -y wget gcc gcc-c++ make openssl-devel bzip2-devel libffi-devel \
                       zlib-devel readline-devel sqlite-devel perl net-tools \
                       tk-devel xz-devel gdbm-devel ncurses-devel || handle_error "安装基础依赖失败" $?
    elif [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
        apt-get update
        apt-get install -y wget build-essential libssl-dev zlib1g-dev libbz2-dev \
                           libreadline-dev libsqlite3-dev curl libncursesw5-dev \
                           xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev || \
                           handle_error "安装基础依赖失败" $?
    fi
    success "基础依赖包安装完成"
}

configure_system_mirrors() {
    progress "配置系统源 (可选)"
    echo -ne "${PROMPT_COLOR}是否使用 LinuxMirrors 脚本配置国内源? (y/n): ${NC}"
    read confirm
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
        curl -sSL "${MIRROR_SCRIPT_URL}" | bash || warning "源配置脚本执行失败，将继续使用当前源"
    fi
}

install_python() {
    if [ "$INSTALL_PYTHON" = false ]; then return 0; fi
    progress "安装 Python ${PYTHON_VERSION}"
    
    local python_tar="Python-${PYTHON_VERSION}.tgz"
    local mirror_url="${PYTHON_MIRROR}/${PYTHON_VERSION}/${python_tar}"
    local official_url="${PYTHON_OFFICIAL_URL}/${PYTHON_VERSION}/${python_tar}"
    
    log "INFO" "下载 Python ${PYTHON_VERSION}..."
    if ! wget -c -P "$TEMP_DIR" "${mirror_url}"; then
        warning "镜像下载失败，尝试官方源..."
        wget -c -P "$TEMP_DIR" "${official_url}" || handle_error "Python源码下载失败" 1
    fi
    
    tar -zxvf "${TEMP_DIR}/${python_tar}" -C "$TEMP_DIR" || handle_error "Python解压失败" $?
    cd "${TEMP_DIR}/Python-${PYTHON_VERSION}"
    
    # Python 3.13 编译配置
    ./configure --prefix=/usr/local/python3 \
                --enable-optimizations \
                --with-lto \
                --enable-shared || handle_error "Python配置失败" $?
                
    make -j $(nproc) || handle_error "Python编译失败" $?
    make install || handle_error "Python安装失败" $?
    
    # 软链接和共享库
    ln -sf /usr/local/python3/bin/python3 /usr/bin/python3
    ln -sf /usr/local/python3/bin/pip3 /usr/bin/pip3
    echo "/usr/local/python3/lib" > /etc/ld.so.conf.d/python3.conf
    ldconfig
    
    # pip国内源
    mkdir -p ~/.pip
    cat > ~/.pip/pip.conf << EOF
[global]
index-url = ${PYPI_MIRROR}
[install]
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF
    
    verify_install "Python" "python3" "python3 --version" && success "Python ${PYTHON_VERSION}"
}

install_docker() {
    if [ "$INSTALL_DOCKER" = false ]; then return 0; fi
    progress "安装 Docker"
    
    if [[ "$OS_ID" == "centos" || "$OS_ID" == "rocky" ]]; then
        yum install -y yum-utils
        yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io
    elif [[ "$OS_ID" == "ubuntu" ]]; then
        apt-get install -y ca-certificates curl gnupg lsb-release
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io
    fi
    
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{ "registry-mirrors": ["${DOCKER_MIRROR}"] }
EOF
    systemctl daemon-reload && systemctl start docker && systemctl enable docker
    
    # Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    verify_install "Docker" "docker" "docker --version" && success "Docker"
}

install_java() {
    if [ "$INSTALL_JAVA" = false ]; then return 0; fi
    progress "安装 Java 1.8"
    if [[ "$OS_ID" == "centos" ]]; then
        yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel
    elif [[ "$OS_ID" == "ubuntu" ]]; then
        apt-get install -y openjdk-8-jdk
    fi
    success "Java 1.8"
}

install_nvm() {
    if [ "$INSTALL_NVM" = false ]; then return 0; fi
    progress "安装 NVM ${NVM_VERSION}"
    
    curl -o- "${NVM_MIRROR}/${NVM_VERSION}/install.sh" | bash || handle_error "NVM下载失败" 1
    
    # 临时使环境变量生效以继续安装Node
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    nvm install --lts && nvm alias default lts/*
    npm config set registry "${NPM_REGISTRY}"
    
    # 写入profile
    if ! grep -q "NVM_DIR" /etc/profile; then
        cat >> /etc/profile << EOF
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"
EOF
    fi
    
    verify_install "Node" "node" "node --version" && success "NVM & Node"
}

install_go() {
    if [ "$INSTALL_GO" = false ]; then return 0; fi
    progress "安装 Go ${GO_VERSION}"
    
    local go_tar="go${GO_VERSION}.linux-amd64.tar.gz"
    wget -P "$TEMP_DIR" "${GO_MIRROR}/${go_tar}" || handle_error "Go下载失败" 1
    rm -rf /usr/local/go && tar -C /usr/local -xzf "${TEMP_DIR}/${go_tar}"
    
    if ! grep -q "GOROOT" /etc/profile; then
        cat >> /etc/profile << EOF
export GOROOT=/usr/local/go
export GOPATH=\$HOME/go
export PATH=\$PATH:\$GOROOT/bin:\$GOPATH/bin
export GOPROXY=${GOPROXY}
EOF
    fi
    success "Go ${GO_VERSION}"
}

install_rust() {
    if [ "$INSTALL_RUST" = false ]; then return 0; fi
    progress "安装 Rust ${RUST_VERSION}"
    
    export RUSTUP_DIST_SERVER="${RUSTUP_DIST_SERVER}"
    export RUSTUP_UPDATE_ROOT="${RUSTUP_UPDATE_ROOT}"
    
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || handle_error "Rust安装失败" 1
    
    if ! grep -q "cargo/bin" /etc/profile; then
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> /etc/profile
    fi
    
    source $HOME/.cargo/env
    success "Rust ${RUST_VERSION}"
}

# ==============================================
# 交互菜单
# ==============================================

select_components() {
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
# 主入口
# ==============================================

main() {
    trap cleanup EXIT
    echo -e "${TITLE_COLOR}===== Easyenv 基础环境一键部署 =====${NC}"
    
    check_root
    check_os
    check_network
    select_components
    
    install_base_dependencies
    configure_system_mirrors
    
    install_python
    install_docker
    install_java
    install_nvm
    install_go
    install_rust
    
    echo -e "\n${SUCCESS_COLOR}===== 安装任务全部完成! =====${NC}"
    echo -e "${INFO_COLOR}请执行 'source /etc/profile' 或重新连接 SSH 使环境生效${NC}"
}

main
