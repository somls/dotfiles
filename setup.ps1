<#
.SYNOPSIS
    Dotfiles 快速设置脚本

.DESCRIPTION
    提供交互式界面帮助用户快速配置 dotfiles 安装偏好，包含环境检测和智能推荐

.PARAMETER SkipDetection
    跳过环境检测，使用默认组件

.PARAMETER DryRun
    预览模式，显示将要执行的操作但不实际执行

.EXAMPLE
    .\setup.ps1
    运行交互式设置向导

.EXAMPLE
    .\setup.ps1 -SkipDetection
    跳过环境检测，直接进入组件选择

.EXAMPLE
    .\setup.ps1 -DryRun
    预览模式，查看将要执行的操作
#>

[CmdletBinding()]
param(
    [switch]$SkipDetection,
    [switch]$DryRun
)

Write-Host "🚀 Dotfiles 快速设置向导" -ForegroundColor Magenta
Write-Host "=========================" -ForegroundColor DarkMagenta
Write-Host ""

# 环境检测
$detectedComponents = @()
if (-not $SkipDetection) {
    Write-Host "🔍 检测系统环境..." -ForegroundColor Yellow
    try {
        $detection = & "$PSScriptRoot\detect-environment.ps1" -Json | ConvertFrom-Json

        # 显示检测结果摘要
        $installedApps = @()
        $missingApps = @()

        foreach ($appName in $detection.Applications.PSObject.Properties.Name) {
            $app = $detection.Applications.$appName
            if ($app.Installed) {
                $installedApps += "$appName ($($app.InstallType))"
                $detectedComponents += $appName
            } else {
                $missingApps += $appName
            }
        }

        Write-Host "  ✅ 已安装: $($installedApps -join ', ')" -ForegroundColor Green
        if ($missingApps.Count -gt 0) {
            Write-Host "  ❌ 未安装: $($missingApps -join ', ')" -ForegroundColor Red
        }
        Write-Host ""
    }
    catch {
        Write-Host "  ⚠️  环境检测失败，将使用默认设置" -ForegroundColor Yellow
        Write-Host ""
    }
}

# 询问要安装的组件
Write-Host "📦 选择要配置的组件:" -ForegroundColor Cyan
Write-Host "默认组件 (Scoop, CMD, PowerShell, Starship, Git, WindowsTerminal) 将自动配置" -ForegroundColor Gray
Write-Host "注意：此脚本仅安装配置文件，不会安装软件本身" -ForegroundColor Yellow
Write-Host ""

$components = @{
    'Alacritty' = 'Alacritty 终端'
    'WezTerm' = 'WezTerm 终端'
    'Neovim' = 'Neovim 编辑器'
}

$selectedComponents = @('Scoop', 'CMD', 'PowerShell', 'Starship', 'Git', 'WindowsTerminal')  # 默认组件

# 智能推荐：如果检测到某个应用已安装，默认推荐安装其配置
foreach ($component in $components.Keys) {
    $description = $components[$component]
    $isDetected = $detectedComponents -contains $component
    $recommendation = if ($isDetected) { " (检测到已安装，推荐)" } else { "" }
    $defaultChoice = if ($isDetected) { "Y/n" } else { "y/N" }

    $response = Read-Host "配置 $component ($description)$recommendation? ($defaultChoice)"

    $shouldInstall = if ($isDetected) {
        # 已检测到的应用，默认为是
        $response -eq '' -or $response -eq 'y' -or $response -eq 'Y'
    } else {
        # 未检测到的应用，默认为否
        $response -eq 'y' -or $response -eq 'Y'
    }

    if ($shouldInstall) {
        $selectedComponents += $component
    }
}

# 检测开发模式
$devModeFile = Join-Path $env:USERPROFILE ".dotfiles.dev-mode"
$isDevMode = Test-Path $devModeFile
$installMode = if ($isDevMode) { "开发模式 (符号链接)" } else { "生产模式 (复制文件)" }

Write-Host ""
Write-Host "📋 安装摘要:" -ForegroundColor Yellow
Write-Host "安装模式: $installMode" -ForegroundColor Gray
Write-Host "安装组件: $($selectedComponents -join ', ')" -ForegroundColor Gray
Write-Host ""

$confirm = Read-Host "确认开始安装? (Y/n)"
if ($confirm -eq '' -or $confirm -eq 'y' -or $confirm -eq 'Y') {
    Write-Host "🚀 开始安装..." -ForegroundColor Green

    $installArgs = @{}
    if ($selectedComponents.Count -gt 0) {
        $installArgs.Type = $selectedComponents
    }
    if ($DryRun) {
        $installArgs.DryRun = $true
    }

    & .\install.ps1 @installArgs

    # 后续配置提示
    if (-not $DryRun) {
        Write-Host "`n🔧 后续配置步骤:" -ForegroundColor Yellow
        Write-Host "1. 配置个人信息:" -ForegroundColor Gray
        Write-Host "   .\setup-personal-configs.ps1" -ForegroundColor DarkGray
        Write-Host "   然后编辑 ~/.gitconfig.local 填入您的姓名和邮箱" -ForegroundColor DarkGray

        Write-Host "`n2. 验证安装:" -ForegroundColor Gray
        Write-Host "   .\health-check.ps1" -ForegroundColor DarkGray

        Write-Host "`n3. 可选：安装推荐软件包:" -ForegroundColor Gray
        Write-Host "   .\install_apps.ps1" -ForegroundColor DarkGray

        Write-Host "`n✨ 设置完成！重启终端以应用新配置" -ForegroundColor Green
    }
} else {
    Write-Host "❌ 安装已取消" -ForegroundColor Yellow
}
