#Requires -Version 5.1

<#
.SYNOPSIS
    基于 packages.txt 的应用安装脚本 - 使用 Scoop 安装推荐软件包

.DESCRIPTION
    这个脚本基于 scoop/packages.txt 文件提供软件包安装功能：
    - 自动安装 Scoop 包管理器
    - 严格按照 packages.txt 分类安装工具
    - 支持分类安装和全量安装
    - 支持预览模式和更新功能

.PARAMETER Essential
    仅安装核心必需工具（默认）- 13个包

.PARAMETER Development
    安装开发工具 - 2个包

.PARAMETER GitEnhanced
    安装Git增强工具 - 1个包

.PARAMETER Programming
    安装编程语言支持 - 2个包

.PARAMETER All
    安装所有工具（全部分类）- 18个包

.PARAMETER DryRun
    预览模式，显示将要安装的包但不实际安装

.PARAMETER Update
    更新已安装的软件包

.PARAMETER Force
    强制重新安装，即使已安装

.EXAMPLE
    .\install_apps.ps1
    安装核心必需工具（13个包）

.EXAMPLE
    .\install_apps.ps1 -All
    安装所有工具（18个包）

.EXAMPLE
    .\install_apps.ps1 -Essential -Development
    安装核心工具和开发工具

.EXAMPLE
    .\install_apps.ps1 -DryRun -All
    预览所有将要安装的工具

.NOTES
    基于 D:\sync\dotfiles\scoop\packages.txt
    与健康检查脚本保持一致的包分类
#>

[CmdletBinding()]
param(
    [switch]$Essential,
    [switch]$Development,
    [switch]$GitEnhanced,
    [switch]$Programming,
    [switch]$All,
    [switch]$DryRun,
    [switch]$Update,
    [switch]$Force
)

# 工具包定义 - 严格基于 scoop/packages.txt
$Script:Packages = @{
    Essential = @(
        # 核心开发工具 (Essential) - 13个包
        'git', 'ripgrep', 'zoxide', 'fzf', 'bat', 'fd', 'jq',
        'neovim', 'starship', 'vscode', 'sudo', 'curl', '7zip'
    )
    Development = @(
        # 开发工具 (Development) - 2个包
        'shellcheck', 'gh'
    )
    GitEnhanced = @(
        # Git增强工具 (GitEnhanced) - 1个包
        'lazygit'
    )
    Programming = @(
        # 编程语言支持 (Programming) - 2个包
        'python', 'nodejs'
    )
}

# 包分类信息
$Script:CategoryInfo = @{
    Essential = @{
        Description = "核心开发工具 (Essential)"
        Count = 13
        Note = "基础必需工具，推荐安装"
        Priority = 'High'
    }
    Development = @{
        Description = "开发工具 (Development)"
        Count = 2
        Note = "代码开发和检查工具"
        Priority = 'Medium'
    }
    GitEnhanced = @{
        Description = "Git增强工具 (GitEnhanced)"
        Count = 1
        Note = "Git可视化管理工具"
        Priority = 'Medium'
    }
    Programming = @{
        Description = "编程语言支持 (Programming)"
        Count = 2
        Note = "Python和Node.js运行时"
        Priority = 'High'
    }
}

# 颜色输出函数
function Write-Message {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )

    $colors = @{
        'Info'    = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
    }

    $icons = @{
        'Info'    = 'ℹ️'
        'Success' = '✅'
        'Warning' = '⚠️'
        'Error'   = '❌'
    }

    Write-Host "$($icons[$Type]) $Message" -ForegroundColor $colors[$Type]
}

# 检查Scoop是否已安装
function Test-ScoopInstalled {
    try {
        $null = Get-Command scoop -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# 安装Scoop包管理器
function Install-Scoop {
    if (Test-ScoopInstalled) {
        Write-Message "Scoop 已安装" 'Success'
        return $true
    }

    Write-Message "正在安装 Scoop 包管理器..." 'Info'

    try {
        # 设置执行策略（如果需要）
        if ((Get-ExecutionPolicy -Scope CurrentUser) -eq 'Restricted') {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        }

        # 下载并安装Scoop
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

        # 刷新环境变量
        $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('PATH', 'User')

        if (Test-ScoopInstalled) {
            Write-Message "Scoop 安装成功" 'Success'

            # 添加常用bucket
            Write-Message "正在添加 bucket..." 'Info'
            scoop bucket add main 2>$null
            scoop bucket add extras 2>$null
            scoop bucket add versions 2>$null

            return $true
        } else {
            Write-Message "Scoop 安装验证失败" 'Error'
            return $false
        }
    }
    catch {
        Write-Message "Scoop 安装失败: $($_.Exception.Message)" 'Error'
        return $false
    }
}

# 获取已安装的包列表
function Get-InstalledPackages {
    if (-not (Test-ScoopInstalled)) {
        return @()
    }

    try {
        $output = scoop list 2>$null | Where-Object { $_ -match '^\s*(\S+)' }
        if ($output) {
            return $output | ForEach-Object {
                if ($_ -match '^\s*(\S+)') {
                    $matches[1]
                }
            } | Where-Object { $_ }
        }
        return @()
    }
    catch {
        return @()
    }
}

# 安装单个包
function Install-Package {
    param(
        [string]$PackageName,
        [switch]$DryRun,
        [switch]$Force
    )

    if ($DryRun) {
        Write-Message "预览: 将安装 $PackageName" 'Info'
        return $true
    }

    # 检查是否已安装
    $installed = Get-InstalledPackages
    if ($PackageName -in $installed -and -not $Force) {
        Write-Message "$PackageName 已安装，跳过" 'Success'
        return $true
    }

    Write-Message "正在安装 $PackageName..." 'Info'

    try {
        if ($Force -and $PackageName -in $installed) {
            $output = scoop uninstall $PackageName 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Message "卸载 $PackageName 失败" 'Warning'
            }
        }

        $output = scoop install $PackageName 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Message "$PackageName 安装成功" 'Success'
            return $true
        } else {
            Write-Message "$PackageName 安装失败: $output" 'Error'
            return $false
        }
    }
    catch {
        Write-Message "$PackageName 安装异常: $($_.Exception.Message)" 'Error'
        return $false
    }
}

# 更新包
function Update-Packages {
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Message "预览: 将更新所有已安装的包" 'Info'
        return
    }

    Write-Message "正在更新 Scoop 和所有已安装的包..." 'Info'

    try {
        # 更新 Scoop 本身
        scoop update

        # 更新所有包
        scoop update *

        Write-Message "包更新完成" 'Success'
    }
    catch {
        Write-Message "包更新失败: $($_.Exception.Message)" 'Error'
    }
}

# 显示分类信息
function Show-CategoryInfo {
    param([array]$Categories)

    Write-Host "`n📊 软件包分类信息:" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor Gray

    $totalCount = 0
    foreach ($category in $Categories) {
        $info = $Script:CategoryInfo[$category]
        $packages = $Script:Packages[$category]

        Write-Host "📁 $($info.Description)" -ForegroundColor Yellow
        Write-Host "   数量: $($packages.Count) 个包" -ForegroundColor Gray
        Write-Host "   优先级: $($info.Priority)" -ForegroundColor Gray
        Write-Host "   说明: $($info.Note)" -ForegroundColor Gray

        if ($packages.Count -le 5) {
            Write-Host "   包列表: $($packages -join ', ')" -ForegroundColor DarkGray
        }

        $totalCount += $packages.Count
        Write-Host ""
    }

    Write-Host "📦 总计: $totalCount 个软件包" -ForegroundColor Green
}

# 主安装函数
function Install-Applications {
    # 确定要安装的分类
    $categoriesToInstall = @()
    $packagesToInstall = @()

    # 检查参数确定安装范围
    if ($All) {
        $categoriesToInstall = @('Essential', 'Development', 'GitEnhanced', 'Programming')
        Write-Message "将安装所有分类的工具" 'Info'
    } else {
        if ($Essential) { $categoriesToInstall += 'Essential' }
        if ($Development) { $categoriesToInstall += 'Development' }
        if ($GitEnhanced) { $categoriesToInstall += 'GitEnhanced' }
        if ($Programming) { $categoriesToInstall += 'Programming' }

        # 如果没有指定任何分类，默认安装Essential
        if ($categoriesToInstall.Count -eq 0) {
            $categoriesToInstall = @('Essential')
            Write-Message "未指定分类，默认安装核心工具 (Essential)" 'Info'
        }
    }

    # 收集所有要安装的包
    foreach ($category in $categoriesToInstall) {
        $packagesToInstall += $Script:Packages[$category]
    }

    # 显示分类信息
    Show-CategoryInfo -Categories $categoriesToInstall

    if ($DryRun) {
        Write-Host "🔍 预览模式 - 以下是将要安装的软件包:" -ForegroundColor Cyan
        Write-Host ("=" * 50) -ForegroundColor Gray

        foreach ($category in $categoriesToInstall) {
            $info = $Script:CategoryInfo[$category]
            Write-Host "`n[$($info.Description)]" -ForegroundColor Yellow
            foreach ($package in $Script:Packages[$category]) {
                Write-Host "  • $package" -ForegroundColor Gray
            }
        }

        Write-Host "`n💡 使用不带 -DryRun 参数重新运行以开始实际安装" -ForegroundColor Yellow
        return
    }

    # 确认安装
    Write-Host "`n🚀 准备安装 $($packagesToInstall.Count) 个软件包" -ForegroundColor Green
    Write-Host "按回车键继续，或 Ctrl+C 取消..." -ForegroundColor Yellow
    Read-Host

    # 安装软件包
    $installed = 0
    $failed = 0
    $startTime = Get-Date

    foreach ($category in $categoriesToInstall) {
        $info = $Script:CategoryInfo[$category]
        Write-Host "`n🔧 正在安装: $($info.Description)" -ForegroundColor Cyan
        Write-Host ("=" * 40) -ForegroundColor Gray

        foreach ($package in $Script:Packages[$category]) {
            if (Install-Package -PackageName $package -Force:$Force) {
                $installed++
            } else {
                $failed++
            }
        }
    }

    # 显示结果
    $duration = (Get-Date) - $startTime
    Write-Host "`n" + ("=" * 60) -ForegroundColor Green
    Write-Host "🎉 安装完成!" -ForegroundColor Green
    Write-Host ("=" * 60) -ForegroundColor Green
    Write-Host "执行时间: $($duration.ToString('mm\:ss'))" -ForegroundColor Cyan
    Write-Host "计划安装: $($packagesToInstall.Count)" -ForegroundColor Gray
    Write-Host "成功安装: $installed" -ForegroundColor Green

    if ($failed -gt 0) {
        Write-Host "安装失败: $failed" -ForegroundColor Red
        Write-Message "请检查失败的包或重新运行安装" 'Warning'
    }

    Write-Host ""
    Write-Message "建议运行 '.\health-check.ps1' 验证安装结果" 'Info'
    Write-Message "可以运行 'scoop list' 查看已安装的包" 'Info'
}

# 显示帮助信息
function Show-Help {
    Write-Host "📖 Dotfiles 应用安装器使用说明" -ForegroundColor Green
    Write-Host ("=" * 50) -ForegroundColor Green
    Write-Host ""
    Write-Host "基于 scoop/packages.txt 的分类安装系统" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "可用的分类:" -ForegroundColor Yellow
    foreach ($category in @('Essential', 'Development', 'GitEnhanced', 'Programming')) {
        $info = $Script:CategoryInfo[$category]
        Write-Host "  -$category" -ForegroundColor White -NoNewline
        Write-Host "  $($info.Description) ($($info.Count)个包)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "常用命令:" -ForegroundColor Yellow
    Write-Host "  .\install_apps.ps1                    # 安装核心工具 (Essential)"
    Write-Host "  .\install_apps.ps1 -All               # 安装所有工具"
    Write-Host "  .\install_apps.ps1 -Essential -Programming  # 安装指定分类"
    Write-Host "  .\install_apps.ps1 -DryRun -All       # 预览所有安装"
    Write-Host "  .\install_apps.ps1 -Update            # 更新已安装的包"
    Write-Host ""
}

# 主执行逻辑
try {
    Write-Host "🚀 Dotfiles 应用安装器 v2.0" -ForegroundColor Green
    Write-Host ("=" * 40) -ForegroundColor Green
    Write-Host "📂 基于 scoop/packages.txt (18个精选包)" -ForegroundColor Gray
    Write-Host "🎯 分类管理 | 🔍 预览支持 | ⚡ 快速安装" -ForegroundColor Gray
    Write-Host ""

    # 显示帮助
    if ($args -contains '-help' -or $args -contains '--help' -or $args -contains '/?') {
        Show-Help
        exit 0
    }

    # 安装Scoop
    if (-not (Install-Scoop)) {
        Write-Message "无法继续安装，因为 Scoop 安装失败" 'Error'
        Write-Message "请检查网络连接和执行策略设置" 'Warning'
        exit 1
    }

    # 执行更新
    if ($Update) {
        Update-Packages -DryRun:$DryRun
    }

    # 执行安装
    if ($Essential -or $Development -or $GitEnhanced -or $Programming -or $All -or
        (-not $Update)) {
        Install-Applications
    }

} catch {
    Write-Message "安装过程中发生未处理的错误: $($_.Exception.Message)" 'Error'
    Write-Host "堆栈跟踪:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    exit 1
}
