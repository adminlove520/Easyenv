#!/bin/bash
# CentOS基础环境安装部署脚本(国内源优化版)
# 包含: Python 3.9, Docker, Docker Compose, Java 1.8, NVM, Go
# 已配置国内源，确保在国内网络环境下可用
# 支持交互式选择安装组件

# ==============================================
# 配置区：集中管理可定制参数
# ==============================================
# 版本配置
PYTHON_VERSION="3.9.18"
NVM_VERSION="v0.39.7"
GO_VERSION="1.21.3"

# 国内源配置
PYPI_MIRROR="https://pypi.tuna.tsinghua.edu.cn/simple"
DOCKER_REPO="https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo"
DOCKER_MIRROR="https://registry.cn-hangzhou.aliyuncs.com"
GOPROXY="https://goproxy.cn,direct"
NVM_MIRROR="https://gitee.com/mirrors/nvm/raw"
PYTHON_MIRROR="https://mirrors.huaweicloud.com/python"
PYTHON_OFFICIAL_URL="https://www.python.org/ftp/python"
GO_MIRROR="https://mirrors.aliyun.com/golang"
NPM_REGISTRY="https://registry.npmmirror.com"

# 外部源配置脚本URL
MIRROR_SCRIPT_URL="https://gitee.com/SuperManito/LinuxMirrors/raw/main/ChangeMirrors.sh"

# 安装组件选择 (默认全不安装，将通过交互选择设置)
INSTALL_PYTHON=false
INSTALL_DOCKER=false
INSTALL_JAVA=false
INSTALL_NVM=false
INSTALL_GO=false

# ==============================================
# 颜色配置 (参考行业标准终端配色方案)
# ==============================================
# 基础颜色
BLACK="\033[30m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"

# 亮色/粗体
LIGHT_RED="\033[1;31m"
LIGHT_GREEN="\033[1;32m"
LIGHT_YELLOW="\033[1;33m"
LIGHT_BLUE="\033[1;34m"
LIGHT_MAGENTA="\033[1;35m"
LIGHT_CYAN="\033[1;36m"
LIGHT_WHITE="\033[1;37m"

# 背景色
BACKGROUND_RED="\033[41m"
BACKGROUND_GREEN="\033[42m"
BACKGROUND_YELLOW="\033[43m"
BACKGROUND_BLUE="\033[44m"

# 样式控制
BOLD="\033[1m"
UNDERLINE="\033[4m"
BLINK="\033[5m"
REVERSE="\033[7m"
NC="\033[0m"  # 重置所有样式

# 功能配色方案 - 便于统一维护
TITLE_COLOR="${LIGHT_BLUE}"        # 标题使用亮蓝色
INFO_COLOR="${CYAN}"               # 信息提示使用青色
SUCCESS_COLOR="${LIGHT_GREEN}"     # 成功信息使用亮绿色
WARNING_COLOR="${YELLOW}"          # 警告信息使用黄色
ERROR_COLOR="${LIGHT_RED}"         # 错误信息使用亮红色
PROMPT_COLOR="${LIGHT_YELLOW}"     # 交互提示使用亮黄色
HIGHLIGHT_COLOR="${LIGHT_MAGENTA}" # 高亮内容使用亮洋红色
SEPARATOR_COLOR="${BLUE}"          # 分隔线使用蓝色

# 临时文件目录
TEMP_DIR=$(mktemp -d /tmp/centos_setup.XXXXXX)
LOG_FILE="${TEMP_DIR}/install.log"

# ==============================================
# 工具函数
# ==============================================

# 日志记录函数
log() {
    local level=$1
    local message=$2
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# 进度显示函数 - 使用标题色和分隔符
progress() {
    echo -e "\n${SEPARATOR_COLOR}==============================================${NC}"
    echo -e "${TITLE_COLOR}===== 正在执行: $1 =====${NC}"
    echo -e "${SEPARATOR_COLOR}==============================================${NC}\n"
    log "INFO" "开始执行: $1"
}

# 成功提示函数 - 使用成功色
success() {
    echo -e "\n${SUCCESS_COLOR}===== 执行成功: $1 =====${NC}\n"
    log "INFO" "执行成功: $1"
}

# 错误提示函数 - 使用错误色
error() {
    echo -e "\n${ERROR_COLOR}===== 执行失败: $1 =====${NC}\n" >&2
    log "ERROR" "执行失败: $1"
}

# 警告提示函数 - 使用警告色
warning() {
    echo -e "${WARNING_COLOR}警告: $1${NC}"
    log "WARNING" "警告: $1"
}

# 信息提示函数 - 使用信息色
info() {
    echo -e "${INFO_COLOR}信息: $1${NC}"
    log "INFO" "信息: $1"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" &> /dev/null
}

# 错误处理函数
handle_error() {
    local step=$1
    local exit_code=$2
    error "在执行 '$step' 时发生错误，退出码: $exit_code"
    log "ERROR" "脚本将在清理后退出"
    cleanup
    exit $exit_code
}

# 清理函数
cleanup() {
    log "INFO" "开始清理临时文件"
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    log "INFO" "清理完成"
}

# 验证安装函数
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

# 先在脚本开头添加终端颜色支持检测和配置
# 确保终端支持ANSI颜色
if [ -t 1 ]; then
    # 启用终端颜色支持
    export TERM=xterm-256color
    
    # 颜色配置 (使用更兼容的格式)
    BLACK=$(tput setaf 0)
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    CYAN=$(tput setaf 6)
    WHITE=$(tput setaf 7)
    
    # 亮色/粗体
    LIGHT_RED=$(tput bold; tput setaf 1)
    LIGHT_GREEN=$(tput bold; tput setaf 2)
    LIGHT_YELLOW=$(tput bold; tput setaf 3)
    LIGHT_BLUE=$(tput bold; tput setaf 4)
    LIGHT_MAGENTA=$(tput bold; tput setaf 5)
    LIGHT_CYAN=$(tput bold; tput setaf 6)
    LIGHT_WHITE=$(tput bold; tput setaf 7)
    
    # 重置所有样式
    NC=$(tput sgr0)
else
    # 如果终端不支持颜色，禁用所有颜色代码
    BLACK=""
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    WHITE=""
    LIGHT_RED=""
    LIGHT_GREEN=""
    LIGHT_YELLOW=""
    LIGHT_BLUE=""
    LIGHT_MAGENTA=""
    LIGHT_CYAN=""
    LIGHT_WHITE=""
    NC=""
fi

# 功能配色方案
TITLE_COLOR="${LIGHT_BLUE}"
INFO_COLOR="${CYAN}"
SUCCESS_COLOR="${LIGHT_GREEN}"
WARNING_COLOR="${YELLOW}"
ERROR_COLOR="${LIGHT_RED}"
PROMPT_COLOR="${LIGHT_YELLOW}"
HIGHLIGHT_COLOR="${LIGHT_MAGENTA}"
SEPARATOR_COLOR="${BLUE}"

# 组件选择函数 - 确保颜色正确显示
select_components() {
    # 强制刷新输出缓冲区
    printf "\n${TITLE_COLOR}===== 请选择要安装的组件 (可多选) =====${NC}\n"
    printf "%s\n" "${INFO_COLOR}1)${NC} Python ${HIGHLIGHT_COLOR}${PYTHON_VERSION}${NC}"
    printf "%s\n" "${INFO_COLOR}2)${NC} Docker 和 Docker Compose"
    printf "%s\n" "${INFO_COLOR}3)${NC} Java 1.8"
    printf "%s\n" "${INFO_COLOR}4)${NC} NVM ${HIGHLIGHT_COLOR}${NVM_VERSION}${NC} (Node Version Manager)"
    printf "%s\n" "${INFO_COLOR}5)${NC} Go ${HIGHLIGHT_COLOR}${GO_VERSION}${NC}"
    printf "%s\n" "${INFO_COLOR}6)${NC} 安装全部组件"
    printf "%s\n" "${INFO_COLOR}0)${NC} 取消安装"
    printf "%s" "${PROMPT_COLOR}请输入选项编号 (用空格分隔多个选项，例如: 1 3 5): ${NC}"
    # 强制刷新输出
    [ -n "$ZSH_VERSION" ] && echo -n "" || true
    
    local input
    read -a input
    
    # 验证输入并设置安装选项
    for choice in "${input[@]}"; do
        case $choice in
            1) INSTALL_PYTHON=true ;;
            2) INSTALL_DOCKER=true ;;
            3) INSTALL_JAVA=true ;;
            4) INSTALL_NVM=true ;;
            5) INSTALL_GO=true ;;
            6) 
                INSTALL_PYTHON=true
                INSTALL_DOCKER=true
                INSTALL_JAVA=true
                INSTALL_NVM=true
                INSTALL_GO=true
                ;;
            0) 
                printf "%s\n" "${INFO_COLOR}已取消安装，脚本将退出${NC}"
                exit 0
                ;;
            *) 
                warning "无效选项 '$choice' 将被忽略"
                ;;
        esac
    done
    
    # 检查是否选择了至少一个组件
    if ! $INSTALL_PYTHON && ! $INSTALL_DOCKER && ! $INSTALL_JAVA && ! $INSTALL_NVM && ! $INSTALL_GO; then
        error "未选择任何组件"
        select_components  # 重新调用选择函数
    fi
    
    # 显示用户选择 - 高亮已选组件
    printf "\n${TITLE_COLOR}===== 您选择安装以下组件 =====${NC}\n"
    $INSTALL_PYTHON && printf "%s\n" "- Python ${HIGHLIGHT_COLOR}${PYTHON_VERSION}${NC}"
    $INSTALL_DOCKER && printf "%s\n" "- Docker 和 Docker Compose"
    $INSTALL_JAVA && printf "%s\n" "- Java 1.8"
    $INSTALL_NVM && printf "%s\n" "- NVM ${HIGHLIGHT_COLOR}${NVM_VERSION}${NC}"
    $INSTALL_GO && printf "%s\n" "- Go ${HIGHLIGHT_COLOR}${GO_VERSION}${NC}"
    
    printf "%s" "${PROMPT_COLOR}确认安装以上组件? (y/n): ${NC}"
    local confirm
    read confirm
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        printf "%s\n" "${INFO_COLOR}重新选择组件...${NC}"
        select_components  # 重新调用选择函数
    fi
}
    
    

# ==============================================
# 前置检查
# ==============================================

# 检查是否以root用户运行
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${ERROR_COLOR}请使用root用户运行此脚本${NC}" >&2
        exit 1
    fi
}

# 检查系统版本
check_centos_version() {
    log "INFO" "检查系统版本"
    
    if [ -f /etc/centos-release ]; then
        local version=$(grep -oE '[0-9]+\.[0-9]+' /etc/centos-release | cut -d '.' -f1)
        if [ "$version" -ne 7 ]; then
            warning "此脚本主要针对CentOS 7优化，您的系统版本为CentOS $version"
            log "WARNING" "脚本针对CentOS 7优化，但检测到CentOS $version"
        fi
    else
        error "未检测到CentOS系统"
        exit 1
    fi
}

# 检查网络连接
check_network() {
    log "INFO" "检查网络连接"
    local test_urls=("${MIRROR_SCRIPT_URL}" "${PYTHON_MIRROR}" "${DOCKER_REPO}" "https://github.com" "https://www.python.org")
    
    for url in "${test_urls[@]}"; do
        local host=$(echo "$url" | awk -F/ '{print $3}')
        if ! ping -c 2 "$host" &> /dev/null; then
            error "无法连接到 $host，请检查网络"
            exit 1
        fi
    done
}

# 检查curl是否安装
check_curl() {
    if ! command_exists "curl"; then
        progress "安装curl工具"
        yum install -y curl || handle_error "安装curl失败" $?
        success "curl工具安装完成"
    fi
}

# ==============================================
# 前置工作：系统配置
# ==============================================

# 安装基础依赖（不包含源配置）
install_base_dependencies() {
    progress "安装基础依赖包"
    
    # 安装核心依赖包
    yum install -y wget gcc gcc-c++ make openssl-devel bzip2-devel libffi-devel \
                   zlib-devel readline-devel sqlite-devel perl net-tools || \
                   handle_error "安装基础依赖失败" $?
    
    success "基础依赖包安装完成"
}

# 使用外部脚本配置系统源和更新
configure_system_mirrors() {
    progress "使用外部脚本配置系统源和更新"
    
    echo -e "${INFO_COLOR}即将运行源配置脚本，该脚本会：${NC}"
    echo -e "${INFO_COLOR}1. 配置系统基础源为国内镜像${NC}"
    echo -e "${INFO_COLOR}2. 可能会更新系统组件${NC}"
    echo -e "${INFO_COLOR}3. 过程中可能需要您进行简单交互${NC}"
    echo -ne "${PROMPT_COLOR}是否继续? (y/n): ${NC}"
    local confirm
    read confirm
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        handle_error "用户取消了源配置步骤" 1
    fi
    
    # 执行外部源配置脚本（使用管道方式替代进程替换，提高兼容性）
    log "INFO" "开始执行外部源配置脚本: ${MIRROR_SCRIPT_URL}"
    curl -sSL "${MIRROR_SCRIPT_URL}" | bash || handle_error "外部源配置脚本执行失败" $?
    
    # 源配置完成后更新缓存
    yum clean all || warning "清理yum缓存警告"
    yum makecache fast || warning "生成yum缓存警告"
    
    success "系统源配置和更新完成"
}

# ==============================================
# 组件安装函数
# ==============================================

# 1. 安装Python 3.9
install_python() {
    if [ "$INSTALL_PYTHON" = false ]; then
        log "INFO" "跳过Python安装"
        return 0
    fi
    
    progress "Python ${PYTHON_VERSION}"
    
    # 安装Python编译所需的额外依赖
    log "INFO" "安装Python编译依赖..."
    yum install -y tk-devel xz-devel gdbm-devel db4-devel libpcap-devel ncurses-devel || {
        error "Python编译依赖安装失败，尝试重新配置源后重试"
        yum clean all && yum makecache fast
        
        # 再次尝试安装依赖
        yum install -y tk-devel xz-devel gdbm-devel db4-devel libpcap-devel ncurses-devel || \
            handle_error "Python编译依赖安装失败" $?
    }
    
    local python_tar="Python-${PYTHON_VERSION}.tgz"
    local mirror_url="${PYTHON_MIRROR}/${PYTHON_VERSION}/${python_tar}"
    local official_url="${PYTHON_OFFICIAL_URL}/${PYTHON_VERSION}/${python_tar}"
    
    # 下载Python源码，优先使用镜像源，失败则尝试官方源
    log "INFO" "下载Python ${PYTHON_VERSION}..."
    if ! wget -c -P "$TEMP_DIR" "${mirror_url}"; then
        warning "华为云镜像下载失败，尝试官网源..."
        if ! wget -c -P "$TEMP_DIR" "${official_url}"; then
            handle_error "Python源码下载失败" 1
        fi
    fi
    
    # 验证文件完整性（检查文件大小是否合理）
    local file_size=$(du -k "${TEMP_DIR}/${python_tar}" | cut -f1)
    if [ $file_size -lt 20000 ]; then  # Python 3.9源码包约25MB左右
        handle_error "下载的Python源码包不完整（可能损坏）" 1
    fi
    
    # 解压源码
    log "INFO" "解压Python源码包..."
    tar -zxvf "${TEMP_DIR}/${python_tar}" -C "$TEMP_DIR" || \
        handle_error "Python源码解压失败" $?
    
    local python_src_dir="${TEMP_DIR}/Python-${PYTHON_VERSION}"
    
    # 检查源码目录完整性
    if [ ! -d "$python_src_dir" ]; then
        handle_error "Python源码目录不存在，解压可能失败" 1
    fi
    
    # 检查关键编译文件是否存在
    if [ ! -f "${python_src_dir}/configure" ] || [ ! -f "${python_src_dir}/Makefile.pre.in" ]; then
        handle_error "Python源码不完整，缺少关键编译文件" 1
    fi
    
    cd "$python_src_dir" || handle_error "进入Python源码目录失败" $?
    
    # 配置编译选项（使用3.9专用配置，修复编译问题）
    log "INFO" "配置Python编译选项..."
    ./configure --prefix=/usr/local/python3 \
                --with-ssl-default-suites=openssl \
                --enable-shared \
                --enable-unicode=ucs4 || \
        handle_error "Python配置失败" $?
    
    # 编译（使用多线程加速）
    log "INFO" "开始编译Python（耗时可能较长，请耐心等待）..."
    make -j $(nproc) || handle_error "Python编译失败" $?
    
    # 安装
    log "INFO" "安装Python..."
    make install || handle_error "Python安装失败" $?
    
    # 返回临时目录上层
    cd "$TEMP_DIR/.." || warning "切换目录警告"
    
    # 创建软链接（强制覆盖现有链接）
    log "INFO" "配置Python软链接..."
    ln -sf /usr/local/python3/bin/python3 /usr/bin/python3 || \
        handle_error "创建python3软链接失败" $?
    ln -sf /usr/local/python3/bin/pip3 /usr/bin/pip3 || \
        handle_error "创建pip3软链接失败" $?
    
    # 配置共享库
    log "INFO" "配置Python共享库..."
    echo "/usr/local/python3/lib" > /etc/ld.so.conf.d/python3.conf
    ldconfig || warning "Python共享库配置警告（可能不影响使用）"
    
    # 配置pip国内源(清华源)
    log "INFO" "配置pip国内源..."
    mkdir -p ~/.pip
    cat > ~/.pip/pip.conf << EOF
[global]
index-url = ${PYPI_MIRROR}
[install]
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF
    
    # 为所有用户配置pip源
    mkdir -p /etc/pip
    cp ~/.pip/pip.conf /etc/pip/pip.conf || handle_error "配置全局pip源失败" $?
    
    # 验证安装
    if verify_install "Python" "python3" "python3 --version"; then
        verify_install "Pip" "pip3" "pip3 --version"
        log "INFO" "Pip 源配置: $(pip3 config get global.index-url)"
        success "Python ${PYTHON_VERSION}"
    else
        handle_error "Python安装验证失败" 1
    fi
}

# 2. 安装Docker和Docker Compose
install_docker() {
    if [ "$INSTALL_DOCKER" = false ]; then
        log "INFO" "跳过Docker安装"
        return 0
    fi
    
    progress "Docker 和 Docker Compose"
    
    # 安装Docker依赖
    yum install -y yum-utils device-mapper-persistent-data lvm2 || \
        handle_error "安装Docker依赖" $?
    
    # 配置阿里云Docker源
    yum-config-manager --add-repo "${DOCKER_REPO}" || \
        handle_error "添加Docker源" $?
    yum makecache fast || handle_error "更新yum缓存" $?
    
    # 安装Docker
    yum install -y docker-ce docker-ce-cli containerd.io || \
        handle_error "安装Docker" $?
    
    # 配置Docker镜像加速器
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["${DOCKER_MIRROR}"]
}
EOF
    
    # 启动Docker并设置开机自启
    systemctl daemon-reload || handle_error "重新加载systemd配置" $?
    systemctl start docker || handle_error "启动Docker服务" $?
    systemctl enable docker || handle_error "设置Docker开机自启" $?
    
    # 从GitHub官方仓库安装最新版本的Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
         -o /usr/local/bin/docker-compose || handle_error "下载Docker Compose" $?
    
    chmod +x /usr/local/bin/docker-compose || handle_error "设置Docker Compose权限" $?
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose || \
        handle_error "创建docker-compose软链接" $?
    
    # 验证安装
    if verify_install "Docker" "docker" "docker --version"; then
        verify_install "Docker Compose" "docker-compose" "docker-compose --version"
        success "Docker 和 Docker Compose"
    else
        handle_error "Docker安装验证失败" 1
    fi
}

# 3. 安装Java 1.8
install_java() {
    if [ "$INSTALL_JAVA" = false ]; then
        log "INFO" "跳过Java安装"
        return 0
    fi
    
    progress "Java 1.8"
    
    # 安装OpenJDK 8
    yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel || \
        handle_error "安装OpenJDK 8" $?
    
    # 配置环境变量
    cat >> /etc/profile << EOF
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
export JRE_HOME=\$JAVA_HOME/jre
export CLASSPATH=.:\$JAVA_HOME/lib:\$JRE_HOME/lib
export PATH=\$PATH:\$JAVA_HOME/bin
EOF
    
    # 立即生效环境变量
    source /etc/profile || handle_error "加载Java环境变量" $?
    
    # 验证安装
    if verify_install "Java" "java" "java -version"; then
        success "Java 1.8"
    else
        handle_error "Java安装验证失败" 1
    fi
}

# 4. 安装NVM (Node Version Manager)
install_nvm() {
    if [ "$INSTALL_NVM" = false ]; then
        log "INFO" "跳过NVM安装"
        return 0
    fi
    
    progress "NVM ${NVM_VERSION}"
    
    # 使用Gitee镜像安装NVM
    curl -o- "${NVM_MIRROR}/${NVM_VERSION}/install.sh" | bash || \
        handle_error "安装NVM" $?
    
    # 配置环境变量
    cat >> /etc/profile << EOF
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"
EOF
    
    # 立即生效环境变量
    source /etc/profile || handle_error "加载NVM环境变量" $?
    
    # 配置npm国内源(淘宝镜像)
    npm config set registry "${NPM_REGISTRY}" || \
        handle_error "配置npm源" $?
    
    # 验证安装
    if verify_install "NVM" "nvm" "nvm --version"; then
        # 安装最新LTS版本的Node.js
        nvm install --lts || handle_error "安装Node.js LTS版本" $?
        nvm alias default lts/* || handle_error "设置默认Node.js版本" $?
        
        verify_install "Node.js" "node" "node --version"
        verify_install "npm" "npm" "npm --version"
        
        log "INFO" "npm 源配置: $(npm config get registry)"
        success "NVM ${NVM_VERSION}"
    else
        handle_error "NVM安装验证失败" 1
    fi
}

# 5. 安装Go
install_go() {
    if [ "$INSTALL_GO" = false ]; then
        log "INFO" "跳过Go安装"
        return 0
    fi
    
    progress "Go ${GO_VERSION}"
    
    local go_tar="go${GO_VERSION}.linux-amd64.tar.gz"
    
    # 使用阿里云镜像下载Go
    wget -P "$TEMP_DIR" "${GO_MIRROR}/${go_tar}" || \
        handle_error "下载Go安装包" $?
    
    # 解压安装
    tar -C /usr/local -xzf "${TEMP_DIR}/${go_tar}" || \
        handle_error "解压Go安装包" $?
    
    # 配置环境变量和国内代理
    cat >> /etc/profile << EOF
export GOROOT=/usr/local/go
export GOPATH=\$HOME/go
export PATH=\$PATH:\$GOROOT/bin:\$GOPATH/bin
export GOPROXY=${GOPROXY}
EOF
    
    # 立即生效环境变量
    source /etc/profile || handle_error "加载Go环境变量" $?
    
    # 验证安装
    if verify_install "Go" "go" "go version"; then
        log "INFO" "Go 代理配置: $(go env GOPROXY)"
        success "Go ${GO_VERSION}"
    else
        handle_error "Go安装验证失败" 1
    fi
}

# ==============================================
# 主函数
# ==============================================

main() {
    # 注册退出清理函数
    trap cleanup EXIT
    trap 'handle_error "脚本被中断" 130' SIGINT SIGTERM
    
    echo -e "\n${TITLE_COLOR}===== CentOS基础环境安装部署脚本(国内源优化版) =====${NC}"
    echo -e "${INFO_COLOR}日志文件将保存至: ${LOG_FILE}${NC}\n"
    
    # 前置检查
    check_root
    check_centos_version
    check_network
    check_curl  # 确保curl已安装，用于后续下载脚本
    
    # 显示组件选择菜单
    select_components
    
    # 执行前置工作（按顺序执行）
    install_base_dependencies          # 1. 安装基础依赖
    configure_system_mirrors           # 2. 配置系统源和更新（最后一项前置工作）
    
    # 根据选择执行组件安装
    install_python
    install_docker
    install_java
    install_nvm
    install_go
    
    # 安装完成提示
    echo -e "\n${SUCCESS_COLOR}===== 所有选择的组件安装完成! =====${NC}"
    echo -e "${INFO_COLOR}提示: 请重新登录shell或执行 'source /etc/profile' 使环境变量生效${NC}"
    log "INFO" "所有选择的组件安装完成"
}

# 启动主函数
main
