# health-check.ps1
# 简化版健康检查：验证核心配置和组件状态

[CmdletBinding()]
param(
    [switch]$Quick,       # 快速模式：跳过耗时检查
    [switch]$Json,        # 以 JSON 形式输出结果
    [string]$OutFile,     # 将报告写入文件
    [switch]$Fix,         # 自动修复发现的问题
    [ValidateSet('PowerShell', 'Git', 'WindowsTerminal', 'Alacritty', 'Neovim', 'All')]
    [string]$Component = 'All',  # 检查特定组件
    [switch]$Detailed     # 详细输出
)

$ErrorActionPreference = 'SilentlyContinue'

$root = $PSScriptRoot
$results = @{
    System = @{}
    Components = @{}
    Issues = @()
    Recommendations = @()
}

function Write-Status {
    param([string]$Message, [string]$Type = 'Info', [string]$Component = '')

    $color = switch ($Type) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Info' { 'Cyan' }
        default { 'Gray' }
    }

    $prefix = switch ($Type) {
        'Success' { 'OK' }
        'Warning' { 'Warning' }
        'Error' { 'Error' }
        'Info' { 'Info' }
        default { '*' }
    }

    $displayMessage = if ($Component) { "[$Component] $Message" } else { $Message }
    Write-Host "$prefix $displayMessage" -ForegroundColor $color
}

function Test-ConfigFile {
    param([string]$Path, [string]$Component)

    if (Test-Path $Path) {
        Write-Status "配置文件存在: $Path" 'Success' $Component
        return $true
    } else {
        Write-Status "配置文件缺失: $Path" 'Warning' $Component
        $results.Issues += "缺失配置文件: $Path"
        return $false
    }
}

Write-Host "Dotfiles 健康检查" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan
Write-Host "项目路径: $root" -ForegroundColor Gray
Write-Host ""

# 检查核心配置文件
function Test-CoreFiles {
    Write-Status "检查核心配置文件..." 'Info'

    $coreFiles = @{
        'PowerShell Profile' = 'powershell\Microsoft.PowerShell_profile.ps1'
        'Git Config' = 'git\gitconfig'
        'Windows Terminal' = 'WindowsTerminal\settings.json'
        'Alacritty' = 'Alacritty\alacritty.toml'
        'Starship Config' = 'starship\starship.toml'
        'Neovim Config' = 'neovim\init.lua'
    }

    $allGood = $true
    foreach ($name in $coreFiles.Keys) {
        $path = Join-Path $root $coreFiles[$name]
        $exists = Test-ConfigFile -Path $path -Component $name
        $results.Components[$name] = @{ Exists = $exists; Path = $path }
        if (-not $exists) { $allGood = $false }
    }

    return $allGood
}

# 检查应用程序安装状态
function Test-Applications {
    Write-Status "检查应用程序安装状态..." 'Info'

    $apps = @{
        'PowerShell 7' = @('pwsh')
        'Git' = @('git')
        'Windows Terminal' = @('wt')
        'Starship' = @('starship')
        'Neovim' = @('nvim')
        'Ripgrep' = @('rg')
        'FZF' = @('fzf')
        'Bat' = @('bat')
        'Fd' = @('fd')
        'Zoxide' = @('zoxide')
        'JQ' = @('jq')
        'Btop' = @('btop')
        'Dust' = @('dust')
        'Procs' = @('procs')
        'GitHub CLI' = @('gh')
        'Choose' = @('choose')
        'Duf' = @('duf')
        'Delta' = @('delta')
        'Lazygit' = @('lazygit')
        'FnM' = @('fnm')
        'ShellCheck' = @('shellcheck')
        'Prettier' = @('prettier')
        'Eza' = @('eza')
        'Tre' = @('tre')
        'Bandwhich' = @('bandwhich')
    }

    foreach ($appName in $apps.Keys) {
        $commands = $apps[$appName]
        $found = $false

        foreach ($cmd in $commands) {
            $command = Get-Command $cmd -ErrorAction SilentlyContinue
            if ($command) {
                Write-Status "$appName 已安装: $($command.Source)" 'Success'
                $found = $true
                break
            }
        }

        if (-not $found) {
            Write-Status "$appName 未安装" 'Warning'
            $results.Recommendations += "建议安装 $appName"
        }
    }
}

# 主执行逻辑
$allChecks = @()

# 执行检查
$allChecks += Test-CoreFiles
Test-Applications

# 生成报告
Write-Host "`n" + "=" * 50 -ForegroundColor Cyan
Write-Host "健康检查完成" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

$overallStatus = if ($allChecks -contains $false) { 'Warning' } else { 'Success' }

Write-Status "总体状态: $overallStatus" $overallStatus

# 显示问题和建议
if ($results.Issues.Count -gt 0) {
    Write-Host "`n发现的问题:" -ForegroundColor Yellow
    foreach ($issue in $results.Issues) {
        Write-Host "  • $issue" -ForegroundColor Red
    }
}

if ($results.Recommendations.Count -gt 0) {
    Write-Host "`n建议:" -ForegroundColor Yellow
    foreach ($rec in $results.Recommendations) {
        Write-Host "  • $rec" -ForegroundColor Gray
    }
}

# 输出结果
if ($Json) {
    $jsonResult = $results | ConvertTo-Json -Depth 4
    if ($OutFile) {
        $jsonResult | Out-File -Encoding UTF8 -FilePath $OutFile
        Write-Status "报告已保存到: $OutFile" 'Info'
    } else {
        Write-Output $jsonResult
    }
} elseif ($OutFile) {
    $textReport = @"
Dotfiles 健康检查报告
生成时间: $(Get-Date)
项目路径: $root

总体状态: $overallStatus

发现的问题:
$($results.Issues | ForEach-Object { "• $_" } | Out-String)

建议:
$($results.Recommendations | ForEach-Object { "• $_" } | Out-String)
"@
    $textReport | Out-File -Encoding UTF8 -FilePath $OutFile
    Write-Status "报告已保存到: $OutFile" 'Info'
}

# 退出码
if ($results.Issues.Count -gt 0) { exit 1 } else { exit 0 }