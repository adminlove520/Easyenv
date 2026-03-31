# Easyenv Windows 基础环境安装脚本 (PowerShell 版)
# 支持: Scoop, Winget
# 包含: Python 3.13, Docker Desktop, Java 1.8, NVM-windows, Go, Rust

$OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Title ($Message) {
    Write-Host "`n==============================================" -ForegroundColor Blue
    Write-Host "===== $Message =====" -ForegroundColor Cyan
    Write-Host "==============================================`n" -ForegroundColor Blue
}

function Write-Success ($Message) { Write-Host "SUCCESS: $Message" -ForegroundColor Green }
function Write-Warning ($Message) { Write-Host "WARNING: $Message" -ForegroundColor Yellow }
function Write-Error ($Message) { Write-Host "ERROR: $Message" -ForegroundColor Red }

# ==============================================
# 前置检查: 管理员权限
# ==============================================
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "请以管理员权限运行此 PowerShell 脚本。"
    exit 1
}

# ==============================================
# 交互选项
# ==============================================
Write-Title "Easyenv Windows 环境一键部署"

$useMirror = Read-Host "是否使用国内镜像加速 (China Mirrors)? (y/n)"
$useMirror = ($useMirror -eq 'y' -or $useMirror -eq 'Y')

Write-Host "请选择安装工具:"
Write-Host "1) Scoop (推荐，适用于开发环境)"
Write-Host "2) Winget (Windows 自带)"
$managerChoice = Read-Host "请输入选项编号 (1/2, 默认为 1)"
if (-not $managerChoice) { $managerChoice = "1" }

Write-Host "`n请选择要安装的组件 (用空格分隔，例如: 1 2 4):"
Write-Host "1) Python 3.13"
Write-Host "2) Docker Desktop"
Write-Host "3) Java 1.8"
Write-Host "4) NVM (Node.js 版本管理)"
Write-Host "5) Go"
Write-Host "6) Rust"
Write-Host "7) 安装全部"
Write-Host "0) 取消"
$components = Read-Host "请输入选项编号"
$choices = $components -split " "

# ==============================================
# 包管理器准备
# ==============================================
if ($managerChoice -eq "1") {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Title "正在安装 Scoop"
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
        $installScript = "https://get.scoop.sh"
        if ($useMirror) {
            $env:SCOOP_MIRROR = 'https://gitee.com/squall-p/scoop'
            # 备注：Scoop 官方脚本安装时可以使用镜像，但此处简化处理
        }
        irm $installScript | iex
        scoop bucket add main
        scoop bucket add extras
    }
    $manager = "scoop"
} else {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error "未找到 Winget，请确保您的 Windows 系统已预装 App Installer。"
        exit 1
    }
    $manager = "winget"
}

# ==============================================
# 安装函数
# ==============================================
function Install-App ($name, $scoopPkg, $wingetPkg) {
    Write-Title "正在安装 $name"
    if ($manager -eq "scoop") {
        scoop install $scoopPkg
    } else {
        winget install --id $wingetPkg --silent --accept-package-agreements --accept-source-agreements
    }
}

foreach ($choice in $choices) {
    switch ($choice) {
        "1" { 
            Install-App "Python 3.13" "python" "Python.Python.3.13"
            if ($useMirror) {
                Write-Host "配置 Pip 国内源..."
                pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
            }
        }
        "2" { Install-App "Docker Desktop" "docker" "Docker.DockerDesktop" }
        "3" { Install-App "Java 1.8" "openjdk8" "Oracle.JavaRuntimeEnvironment" } # Winget ID 可能随版本变化
        "4" { 
            Install-App "NVM" "nvm" "CoreyButler.NVMforWindows"
            if ($useMirror) {
                Write-Host "配置 NVM 国内镜像..."
                nvm node_mirror https://npmmirror.com/mirrors/node/
                nvm npm_mirror https://npmmirror.com/mirrors/npm/
            }
        }
        "5" { 
            Install-App "Go" "go" "Google.Go"
            if ($useMirror) {
                Write-Host "配置 Go Proxy..."
                [Environment]::SetEnvironmentVariable("GOPROXY", "https://goproxy.cn,direct", "User")
            }
        }
        "6" { 
            Write-Title "正在安装 Rust"
            # Rust 通常使用 rustup
            if ($useMirror) {
                $env:RUSTUP_DIST_SERVER = "https://mirrors.ustc.edu.cn/rust-static"
                $env:RUSTUP_UPDATE_ROOT = "https://mirrors.ustc.edu.cn/rust-static/rustup"
            }
            $rustInstall = "$env:TEMP\rustup-init.exe"
            Invoke-WebRequest -Uri "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe" -OutFile $rustInstall
            & $rustInstall -y --no-modify-path
            Remove-Item $rustInstall
        }
        "7" { 
            # 递归调用全部
            $choices = "1", "2", "3", "4", "5", "6"
        }
        "0" { exit 0 }
    }
}

Write-Success "环境部署完成！部分应用可能需要重启终端或系统生效。"
pause
