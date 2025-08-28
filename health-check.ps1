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
        'Success' { '✅' }
        'Warning' { '⚠️ ' }
        'Error' { '❌' }
        'Info' { 'ℹ️ ' }
        default { '•' }
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

Write-Host "🩺 Dotfiles 健康检查" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan
Write-Host "项目路径: $root" -ForegroundColor Gray
Write-Host ""

# 检查核心配置文件
function Test-CoreFiles {
    Write-Status "检查核心配置文件..." 'Info'

    $coreFiles = @{
        'PowerShell Profile' = 'powershell\Microsoft.PowerShell_profile.ps1'
        'Git Config' = 'git\.gitconfig'

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

# 检查PowerShell配置
function Test-PowerShellConfig {
    if ($Component -ne 'All' -and $Component -ne 'PowerShell') { return $true }

    Write-Status "检查PowerShell配置..." 'Info'

    $psFiles = @{
        'Aliases' = 'powershell\.powershell\aliases.ps1'
        'Functions' = 'powershell\.powershell\functions.ps1'
        'Theme' = 'powershell\.powershell\theme.ps1'
    }

    $allGood = $true
    foreach ($name in $psFiles.Keys) {
        $path = Join-Path $root $psFiles[$name]
        $exists = Test-ConfigFile -Path $path -Component 'PowerShell'
        if (-not $exists) { $allGood = $false }
    }

    # 检查PowerShell配置是否已安装
    $profilePath = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
    if (Test-Path $profilePath) {
        Write-Status "PowerShell配置已安装" 'Success' 'PowerShell'
    } else {
        Write-Status "PowerShell配置未安装" 'Warning' 'PowerShell'
        $results.Recommendations += "运行 .\install.ps1 -Type PowerShell 安装配置"
    }

    return $allGood
}

# 检查Git配置
function Test-GitConfig {
    if ($Component -ne 'All' -and $Component -ne 'Git') { return $true }

    Write-Status "检查Git配置..." 'Info'

    # 检查Git是否安装
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        Write-Status "Git未安装" 'Error' 'Git'
        $results.Issues += "Git未安装，请先安装Git"
        return $false
    }

    Write-Status "Git已安装: $($gitCmd.Source)" 'Success' 'Git'

    # 检查用户配置（兼容包含本地文件 ~/.gitconfig.local 的场景）
    $userName = git config --global --get user.name 2>$null
    $userEmail = git config --global --get user.email 2>$null

    $localGitconfig = Join-Path $env:USERPROFILE ".gitconfig.local"
    if ((-not $userName -or -not $userEmail) -and (Test-Path $localGitconfig)) {
        try {
            $localContent = Get-Content -Raw $localGitconfig
            if (-not $userName) {
                $m = [regex]::Match($localContent, "(?m)^\s*name\s*=\s*(.+)$")
                if ($m.Success) { $userName = $m.Groups[1].Value.Trim() }
            }
            if (-not $userEmail) {
                $m2 = [regex]::Match($localContent, "(?m)^\s*email\s*=\s*(.+)$")
                if ($m2.Success) { $userEmail = $m2.Groups[1].Value.Trim() }
            }
        } catch {}
    }

    $isPlaceholderName = $userName -and ($userName -match "(?i)^your name$")
    $isPlaceholderEmail = $userEmail -and ($userEmail -match "(?i)^your\\.email@example\\.com$")

    if (-not $userName -or -not $userEmail -or $isPlaceholderName -or $isPlaceholderEmail) {
        Write-Status "Git用户信息未配置或仍为占位内容" 'Warning' 'Git'
        $results.Recommendations += "配置Git用户信息: git config --global user.name 'Your Name'"
        $results.Recommendations += "配置Git用户邮箱: git config --global user.email 'your@email.com'"
        if (Test-Path $localGitconfig) {
            $results.Recommendations += "亦可编辑 $localGitconfig 设置 [user] name/email"
        }
    } else {
        Write-Status "Git用户信息已配置: $userName <$userEmail>" 'Success' 'Git'
    }

    return $true
}

# 检查Neovim配置
function Test-NeovimConfig {
    if ($Component -ne 'All' -and $Component -ne 'Neovim') { return $true }

    Write-Status "检查Neovim配置..." 'Info'

    # 检查Neovim是否安装
    $nvimCmd = Get-Command nvim -ErrorAction SilentlyContinue
    if (-not $nvimCmd) {
        Write-Status "Neovim未安装" 'Error' 'Neovim'
        $results.Issues += "Neovim未安装，请先安装Neovim"
        $results.Recommendations += "运行 scoop install neovim 或 choco install neovim 安装Neovim"
        return $false
    }

    # 获取版本信息
    try {
        $versionOutput = & nvim --version 2>$null | Select-Object -First 1
        if ($versionOutput -match "NVIM v(\d+\.\d+\.\d+)") {
            $version = $matches[1]
            Write-Status "Neovim已安装: v$version" 'Success' 'Neovim'
        } else {
            Write-Status "Neovim已安装但无法获取版本" 'Warning' 'Neovim'
        }
    } catch {
        Write-Status "检测Neovim版本时出错" 'Warning' 'Neovim'
    }

    # 检查配置文件（按当前最小化配置）
    $configFiles = @{
        'Init File' = 'neovim\init.lua'
        'Plugin List' = 'neovim\lua\plugins.lua'
    }

    $allGood = $true
    foreach ($name in $configFiles.Keys) {
        $path = Join-Path $root $configFiles[$name]
        $exists = Test-ConfigFile -Path $path -Component 'Neovim'
        if (-not $exists) { $allGood = $false }
    }

    # 检查Neovim配置是否已安装
    $nvimConfigPath = "$env:LOCALAPPDATA\nvim"
    if (Test-Path $nvimConfigPath) {
        Write-Status "Neovim配置已安装" 'Success' 'Neovim'

        # 检查关键文件
        $initFile = Join-Path $nvimConfigPath "init.lua"
        if (Test-Path $initFile) {
            Write-Status "配置文件完整" 'Success' 'Neovim'
        } else {
            Write-Status "配置文件不完整" 'Warning' 'Neovim'
            $results.Issues += "Neovim配置文件不完整"
        }

        # 检测 lazy.nvim 是否已引导
        $lazyPath = "$env:LOCALAPPDATA\nvim-data\lazy\lazy.nvim"
        if (Test-Path $lazyPath) {
            Write-Status "lazy.nvim 已就绪" 'Success' 'Neovim'
        } else {
            Write-Status "lazy.nvim 尚未安装（首次启动Neovim会自动安装）" 'Warning' 'Neovim'
        }
    } else {
        Write-Status "Neovim配置未安装" 'Warning' 'Neovim'
        $results.Recommendations += "运行 .\install.ps1 -Type Neovim 安装配置"
    }

    # 读取本仓库 init.lua 以根据当前配置调整建议
    $repoInit = Join-Path $root 'neovim\init.lua'
    $initContent = if (Test-Path $repoInit) { Get-Content -Raw $repoInit } else { '' }

    $nodeProviderDisabled = $initContent -match 'vim\.g\.loaded_node_provider\s*=\s*0'
    $pyProviderDisabled = $initContent -match 'vim\.g\.loaded_python3_provider\s*=\s*0'

    # 可选：检查 Treesitter 编译器（Windows 友好）
    $compilers = @('zig', 'clang', 'gcc', 'cc', 'cl')
    $compilerFound = $false
    foreach ($c in $compilers) {
        if (Get-Command $c -ErrorAction SilentlyContinue) { $compilerFound = $true; break }
    }
    if (-not $compilerFound) {
        $results.Recommendations += "为 nvim-treesitter 编译建议安装 zig 或 llvm（scoop install zig / llvm）"
        Write-Status "未检测到可用的 C/zig 编译器，Treesitter 本地编译将不可用" 'Warning' 'Neovim'
    } else {
        Write-Status "已检测到可用编译器用于 Treesitter（$c）" 'Success' 'Neovim'
    }

    # Provider 建议：仅在未显式禁用时提示
    if (-not $nodeProviderDisabled) {
        $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
        if ($nodeCmd) {
            $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
            if ($npmCmd) {
                # 可进一步检测 neovim npm 包
                $neovimPkg = (& npm ls -g neovim --depth=0 2>$null)
                if (-not ($neovimPkg -match 'neovim@')) {
                    $results.Recommendations += "可安装 Node.js provider：npm install -g neovim"
                }
            }
        }
    } else {
        Write-Status "已禁用 Node.js provider（按当前配置）" 'Info' 'Neovim'
    }

    if (-not $pyProviderDisabled) {
        $py = Get-Command python -ErrorAction SilentlyContinue
        $py3 = Get-Command python3 -ErrorAction SilentlyContinue
        if ($py -or $py3) {
            $pipCmd = Get-Command pip -ErrorAction SilentlyContinue
            if ($pipCmd) {
                $pynvim = (& pip show pynvim 2>$null)
                if (-not $pynvim) {
                    $results.Recommendations += "可安装 Python provider：pip install --user pynvim"
                }
            }
        }
    } else {
        Write-Status "已禁用 Python3 provider（按当前配置）" 'Info' 'Neovim'
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

# 检查符号链接状态
function Test-SymbolicLinks {
    if ($Quick) { return $true }

    Write-Status "检查符号链接状态..." 'Info'

    $brokenLinks = @()
    Get-ChildItem -Path $root -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.LinkType -eq 'SymbolicLink') {
            if (-not (Test-Path $_.Target)) {
                $brokenLinks += $_
            }
        }
    }

    if ($brokenLinks.Count -gt 0) {
        Write-Status "发现 $($brokenLinks.Count) 个损坏的符号链接" 'Warning'
        if ($Detailed) {
            foreach ($link in $brokenLinks) {
                Write-Host "  • $($link.FullName) -> $($link.Target)" -ForegroundColor DarkGray
            }
        }
        $results.Issues += "存在损坏的符号链接"
        return $false
    } else {
        Write-Status "符号链接状态正常" 'Success'
        return $true
    }
}

# 主执行逻辑
$allChecks = @()

# 执行检查
$allChecks += Test-CoreFiles
$allChecks += Test-PowerShellConfig
$allChecks += Test-GitConfig
$allChecks += Test-NeovimConfig
Test-Applications
$allChecks += Test-SymbolicLinks

# 生成报告
Write-Host "`n" + "=" * 50 -ForegroundColor Cyan
Write-Host "健康检查完成" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

$overallStatus = if ($allChecks -contains $false) { 'Warning' } else { 'Success' }

Write-Status "总体状态: $overallStatus" $overallStatus

# 显示问题和建议
if ($results.Issues.Count -gt 0) {
    Write-Host "`n🔍 发现的问题:" -ForegroundColor Yellow
    foreach ($issue in $results.Issues) {
        Write-Host "  • $issue" -ForegroundColor Red
    }
}

if ($results.Recommendations.Count -gt 0) {
    Write-Host "`n💡 建议:" -ForegroundColor Yellow
    foreach ($rec in $results.Recommendations) {
        Write-Host "  • $rec" -ForegroundColor Gray
    }
}

# 自动修复
if ($Fix -and $results.Issues.Count -gt 0) {
    Write-Host "`n🔧 尝试自动修复..." -ForegroundColor Cyan

    # 这里可以添加自动修复逻辑
    Write-Status "自动修复功能开发中" 'Info'
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
