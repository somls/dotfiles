# =============================================================================
# Dotfiles 统一管理脚本 (dotfiles.ps1)
# 所有dotfiles操作的统一入口
# =============================================================================

param(
    [Parameter(Position = 0)]
    [ValidateSet("install-apps", "deploy", "check", "dev-link", "setup-user", "sync", "help")]
    [string]$Command = "help",

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Arguments = @()
)

# 脚本信息
$ScriptVersion = "1.0.0"
$ConfigsDir = Join-Path $PSScriptRoot "configs"

# 颜色输出函数
function Write-Title { param($Message) Write-Host $Message -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Blue }
function Write-Command { param($Cmd, $Desc) Write-Host "  $Cmd" -ForegroundColor Yellow -NoNewline; Write-Host " - $Desc" -ForegroundColor Gray }

# 显示帮助信息
function Show-Help {
    Write-Title "🚀 Dotfiles 管理工具 v$ScriptVersion"
    Write-Title "=================================="
    Write-Host ""

    Write-Host "基于 configs 目录的 Windows dotfiles 配置管理系统" -ForegroundColor Gray
    Write-Host ""

    Write-Title "📋 可用命令："
    Write-Command "install-apps" "安装应用程序（通过Scoop）"
    Write-Command "deploy" "部署配置文件到系统位置"
    Write-Command "check" "检查环境和配置状态"
    Write-Command "dev-link" "开发用符号链接管理"
    Write-Command "setup-user" "配置用户个人信息"
    Write-Command "sync" "智能Git同步（提交+推送/拉取）"
    Write-Command "help" "显示此帮助信息"

    Write-Host ""
    Write-Title "🔧 快速开始："
    Write-Host "  # 新用户完整安装" -ForegroundColor Green
    Write-Host "  .\dotfiles.ps1 setup-user" -ForegroundColor White
    Write-Host "  .\dotfiles.ps1 install-apps" -ForegroundColor White
    Write-Host "  .\dotfiles.ps1 deploy" -ForegroundColor White
    Write-Host ""
    Write-Host "  # 检查状态" -ForegroundColor Green
    Write-Host "  .\dotfiles.ps1 check" -ForegroundColor White
    Write-Host ""
    Write-Host "  # 开发模式（实时同步）" -ForegroundColor Green
    Write-Host "  .\dotfiles.ps1 dev-link create" -ForegroundColor White

    Write-Host ""
    Write-Title "📁 配置结构："
    Write-Host "  configs/" -ForegroundColor Yellow
    Write-Host "  ├── powershell/     # PowerShell 配置" -ForegroundColor Gray
    Write-Host "  ├── git/            # Git 配置" -ForegroundColor Gray
    Write-Host "  ├── starship/       # Starship 提示符" -ForegroundColor Gray
    Write-Host "  ├── WindowsTerminal/ # 终端配置" -ForegroundColor Gray
    Write-Host "  ├── neovim/         # Neovim 编辑器" -ForegroundColor Gray
    Write-Host "  └── scoop/          # 包管理器配置" -ForegroundColor Gray

    Write-Host ""
    Write-Title "💡 命令详情："
    Write-Host "  使用 '.\dotfiles.ps1 <命令> -help' 查看具体命令的帮助" -ForegroundColor Gray
}

# 验证configs目录
if (-not (Test-Path $ConfigsDir)) {
    Write-Host "❌ 错误: configs 目录不存在" -ForegroundColor Red
    Write-Host "请确保在 dotfiles 根目录中运行此脚本" -ForegroundColor Gray
    exit 1
}

Write-Host ""

# 执行命令
switch ($Command) {
    "install-apps" {
        Write-Title "📦 安装应用程序"
        Write-Host "调用: .\install-apps.ps1 $($Arguments -join ' ')" -ForegroundColor Gray
        Write-Host ""

        $scriptPath = Join-Path $PSScriptRoot "install-apps.ps1"
        if (Test-Path $scriptPath) {
            & $scriptPath @Arguments
        } else {
            Write-Host "❌ install-apps.ps1 脚本不存在" -ForegroundColor Red
        }
    }

    "deploy" {
        Write-Title "🚀 部署配置文件"
        Write-Host "调用: .\deploy-config.ps1 $($Arguments -join ' ')" -ForegroundColor Gray
        Write-Host ""

        $scriptPath = Join-Path $PSScriptRoot "deploy-config.ps1"
        if (Test-Path $scriptPath) {
            & $scriptPath @Arguments
        } else {
            Write-Host "❌ deploy-config.ps1 脚本不存在" -ForegroundColor Red
        }
    }

    "check" {
        Write-Title "🔍 检查环境状态"
        Write-Host "调用: .\check-environment.ps1 $($Arguments -join ' ')" -ForegroundColor Gray
        Write-Host ""

        $scriptPath = Join-Path $PSScriptRoot "check-environment.ps1"
        if (Test-Path $scriptPath) {
            & $scriptPath @Arguments
        } else {
            Write-Host "❌ check-environment.ps1 脚本不存在" -ForegroundColor Red
        }
    }

    "dev-link" {
        Write-Title "🔗 开发符号链接管理"
        Write-Host "调用: .\dev-symlink.ps1 $($Arguments -join ' ')" -ForegroundColor Gray
        Write-Host ""

        $scriptPath = Join-Path $PSScriptRoot "dev-symlink.ps1"
        if (Test-Path $scriptPath) {
            & $scriptPath @Arguments
        } else {
            Write-Host "❌ dev-symlink.ps1 脚本不存在" -ForegroundColor Red
        }
    }

    "setup-user" {
        Write-Title "👤 用户配置设置"
        Write-Host "调用: .\setup-user-config.ps1 $($Arguments -join ' ')" -ForegroundColor Gray
        Write-Host ""

        $scriptPath = Join-Path $PSScriptRoot "setup-user-config.ps1"
        if (Test-Path $scriptPath) {
            & $scriptPath @Arguments
        } else {
            Write-Host "❌ setup-user-config.ps1 脚本不存在" -ForegroundColor Red
        }
    }

    "sync" {
        Write-Title "🔄 智能Git同步"
        Write-Host "调用: .\tools\auto-sync.ps1 $($Arguments -join ' ')" -ForegroundColor Gray
        Write-Host ""

        $scriptPath = Join-Path $PSScriptRoot "tools\auto-sync.ps1"
        if (Test-Path $scriptPath) {
            & $scriptPath @Arguments
        } else {
            Write-Host "❌ tools\auto-sync.ps1 脚本不存在" -ForegroundColor Red
        }
    }

    "help" {
        Show-Help
    }

    default {
        Write-Host "❌ 未知命令: $Command" -ForegroundColor Red
        Write-Host ""
        Show-Help
        exit 1
    }
}

Write-Host ""
