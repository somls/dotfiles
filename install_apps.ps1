# install_apps.ps1
# 应用安装脚本 - 使用 Scoop 安装推荐软件包

[CmdletBinding()]
param(
    [switch]$DryRun,       # 预览模式，不实际安装
    [string[]]$Category = @('Essential'),   # 安装指定类别
    [switch]$Update        # 更新已安装的包
)

# 推荐软件包配置
$PackageCategories = @{
    Essential = @(
        'git',
        'pwsh',
        'starship',
        '7zip',
        'curl'
    )
    Development = @(
        'nodejs',
        'python',
        'gh',
        'delta',
        'ripgrep',
        'bat',
        'fd'
    )
    Editors = @(
        'neovim',
        'windows-terminal'
    )
}

function Write-Status {
    param([string]$Message, [string]$Type = 'Info')
    $color = switch ($Type) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        default { 'Cyan' }
    }
    $icon = switch ($Type) {
        'Success' { '✅' }
        'Warning' { '⚠️ ' }
        'Error' { '❌' }
        default { 'ℹ️ ' }
    }
    Write-Host "$icon $Message" -ForegroundColor $color
}

# 检查 Scoop 是否安装
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Status "Scoop 未安装，正在安装..." 'Warning'
    try {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-RestMethod get.scoop.sh | Invoke-Expression
        Write-Status "Scoop 安装成功" 'Success'
    } catch {
        Write-Status "Scoop 安装失败: $($_.Exception.Message)" 'Error'
        Write-Host "请手动安装 Scoop: https://scoop.sh/" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "📦 应用安装器" -ForegroundColor Cyan
Write-Host "=" * 30 -ForegroundColor Cyan

# 确定要安装的包
$packagesToInstall = @()
foreach ($cat in $Category) {
    if ($PackageCategories.ContainsKey($cat)) {
        $packagesToInstall += $PackageCategories[$cat]
        Write-Status "选择类别: $cat" 'Info'
    } else {
        Write-Status "未知类别: $cat，可用类别: $($PackageCategories.Keys -join ', ')" 'Warning'
    }
}

if ($packagesToInstall.Count -eq 0) {
    Write-Status "没有选择任何软件包" 'Warning'
    exit 0
}

# 获取已安装的包
Write-Status "检查已安装软件..." 'Info'
try {
    $installedPackages = @(scoop list 6>$null | ForEach-Object {
        if ($_ -match '^(\S+)') { $matches[1] }
    })
} catch {
    $installedPackages = @()
}

Write-Host "`n📋 安装计划:" -ForegroundColor Yellow
$toInstall = @()
$toUpdate = @()

foreach ($package in $packagesToInstall) {
    if ($installedPackages -contains $package) {
        $toUpdate += $package
        Write-Host "  ⏭️  $package (已安装)" -ForegroundColor Gray
    } else {
        $toInstall += $package
        Write-Host "  📦 $package (将安装)" -ForegroundColor Green
    }
}

# 确认安装
if ($toInstall.Count -gt 0) {
    Write-Host "`n即将安装 $($toInstall.Count) 个新软件包" -ForegroundColor Yellow
    if (-not $DryRun) {
        $response = Read-Host "继续安装？(Y/n)"
        if ($response -match '^[nN]') {
            Write-Status "用户取消安装" 'Info'
            exit 0
        }
    }
}

# 更新已安装的包
if ($Update -and $toUpdate.Count -gt 0) {
    Write-Host "`n🔄 更新已安装软件..." -ForegroundColor Yellow
    if ($DryRun) {
        Write-Status "预览: 将更新 $($toUpdate -join ', ')" 'Info'
    } else {
        scoop update $toUpdate
        Write-Status "更新完成" 'Success'
    }
}

# 安装新软件包
if ($toInstall.Count -gt 0) {
    Write-Host "`n📦 开始安装..." -ForegroundColor Yellow

    if ($DryRun) {
        Write-Status "预览: 将安装 $($toInstall -join ', ')" 'Info'
    } else {
        $successCount = 0
        foreach ($package in $toInstall) {
            Write-Status "正在安装 $package..." 'Info'

            try {
                scoop install $package
                if ($LASTEXITCODE -eq 0) {
                    Write-Status "$package 安装成功" 'Success'
                    $successCount++
                } else {
                    Write-Status "$package 安装失败" 'Error'
                }
            } catch {
                Write-Status "$package 安装异常: $($_.Exception.Message)" 'Error'
            }
        }

        Write-Host "`n✅ 安装完成: $successCount/$($toInstall.Count) 个软件包" -ForegroundColor Green

        if ($successCount -gt 0) {
            Write-Host "`n💡 后续步骤:" -ForegroundColor Yellow
            Write-Host "• 重启终端以应用新工具" -ForegroundColor Gray
            Write-Host "• 运行 .\install.ps1 配置应用设置" -ForegroundColor Gray
            Write-Host "• 运行 .\health-check.ps1 验证配置" -ForegroundColor Gray
        }
    }
} else {
    Write-Status "所有软件包都已安装" 'Success'
}
