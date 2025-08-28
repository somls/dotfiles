# =============================================================================
# PowerShell Configuration Test Script
#
# 用于验证PowerShell配置是否正确安装和工作
# Last Modified: 2025-07-29
# =============================================================================

[CmdletBinding()]
param(
    [switch]$Detailed,
    [switch]$FixIssues
)

# 颜色输出函数
function Write-TestResult {
    param([string]$Test, [bool]$Passed, [string]$Details = "")
    $status = if ($Passed) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($Passed) { "Green" } else { "Red" }

    Write-Host "$status $Test" -ForegroundColor $color
    if ($Details -and ($Detailed -or -not $Passed)) {
        Write-Host "      $Details" -ForegroundColor Gray
    }
}

function Write-Section {
    param([string]$Title)
    Write-Host "`n🔍 $Title" -ForegroundColor Cyan
    Write-Host ("=" * ($Title.Length + 4)) -ForegroundColor DarkCyan
}

function Write-Summary {
    param([int]$Passed, [int]$Total)
    $failed = $Total - $Passed
    Write-Host "`n📊 测试结果总结" -ForegroundColor Magenta
    Write-Host "=================" -ForegroundColor DarkMagenta
    Write-Host "通过: $Passed/$Total" -ForegroundColor Green
    if ($failed -gt 0) {
        Write-Host "失败: $failed/$Total" -ForegroundColor Red
    }

    $percentage = [math]::Round(($Passed / $Total) * 100, 1)
    Write-Host "成功率: $percentage%" -ForegroundColor $(if ($percentage -ge 90) { "Green" } elseif ($percentage -ge 70) { "Yellow" } else { "Red" })
}

# 测试计数器
$script:TotalTests = 0
$script:PassedTests = 0

function Test-Condition {
    param([string]$TestName, [scriptblock]$TestScript, [string]$Details = "")
    $script:TotalTests++

    try {
        $result = & $TestScript
        if ($result) {
            $script:PassedTests++
            Write-TestResult $TestName $true $Details
        } else {
            Write-TestResult $TestName $false $Details
        }
        return $result
    } catch {
        Write-TestResult $TestName $false "错误: $($_.Exception.Message)"
        return $false
    }
}

# 开始测试
Write-Host "🚀 PowerShell 配置验证测试" -ForegroundColor Magenta
Write-Host "============================" -ForegroundColor DarkMagenta
Write-Host "测试时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# 1. 基础配置测试
Write-Section "基础配置"

Test-Condition "PowerShell 配置文件存在" {
    Test-Path $PROFILE
} "路径: $PROFILE"

Test-Condition "配置目录存在" {
    $configDir = Join-Path $env:USERPROFILE ".powershell"
    Test-Path $configDir
} "路径: $(Join-Path $env:USERPROFILE '.powershell')"

Test-Condition "核心模块文件存在" {
    $configDir = Join-Path $env:USERPROFILE ".powershell"
    $coreFiles = @("functions.ps1", "aliases.ps1", "extra.ps1")
    $allExist = $true
    foreach ($file in $coreFiles) {
        if (-not (Test-Path (Join-Path $configDir $file))) {
            $allExist = $false
            break
        }
    }
    return $allExist
} "检查 functions.ps1, aliases.ps1, extra.ps1"

# 2. 符号链接测试
Write-Section "符号链接"

Test-Condition "主配置文件符号链接" {
    if (Test-Path $PROFILE) {
        $item = Get-Item $PROFILE
        return $item.LinkType -eq "SymbolicLink"
    }
    return $false
} "检查主配置文件是否为符号链接"

Test-Condition "配置目录符号链接" {
    $configDir = Join-Path $env:USERPROFILE ".powershell"
    if (Test-Path $configDir) {
        $item = Get-Item $configDir
        return $item.LinkType -eq "SymbolicLink"
    }
    return $false
} "检查配置目录是否为符号链接"

# 3. 核心函数测试
Write-Section "核心函数"

Test-Condition "Clean-ScoopCache 函数" {
    Get-Command Clean-ScoopCache -ErrorAction SilentlyContinue
} "Scoop缓存清理功能"

Test-Condition "Update-System 函数" {
    Get-Command Update-System -ErrorAction SilentlyContinue
} "系统更新功能"

Test-Condition "Enable-Proxy 函数" {
    Get-Command Enable-Proxy -ErrorAction SilentlyContinue
} "代理启用功能"

Test-Condition "Switch-ProxyPort 函数" {
    Get-Command Switch-ProxyPort -ErrorAction SilentlyContinue
} "代理端口切换功能"

Test-Condition "Show-ProxyStatus 函数" {
    Get-Command Show-ProxyStatus -ErrorAction SilentlyContinue
} "代理状态显示功能"

# 4. 别名测试
Write-Section "命令别名"

Test-Condition "swp 别名" {
    Get-Alias swp -ErrorAction SilentlyContinue
} "指向 Clean-ScoopCache"

Test-Condition "update 别名" {
    Get-Alias update -ErrorAction SilentlyContinue
} "指向 Update-System"

Test-Condition "proxy 别名" {
    Get-Alias proxy -ErrorAction SilentlyContinue
} "指向 Show-ProxyStatus"

Test-Condition "px 别名" {
    Get-Alias px -ErrorAction SilentlyContinue
} "指向 Switch-ProxyPort"

Test-Condition "reload 别名" {
    Get-Alias reload -ErrorAction SilentlyContinue
} "指向 Reload-Profile"

# 5. 代理配置测试
Write-Section "代理配置"

Test-Condition "代理端口配置" {
    if (Get-Variable -Name "ProxyPorts" -Scope Global -ErrorAction SilentlyContinue) {
        $ports = $global:ProxyPorts
        return ($ports.ContainsKey("clash") -and $ports.ContainsKey("v2ray") -and $ports.ContainsKey("default"))
    }
    return $false
} "检查 clash, v2ray, default 端口配置"

Test-Condition "默认代理端口 (V2rayN)" {
    if (Get-Variable -Name "ProxyPorts" -Scope Global -ErrorAction SilentlyContinue) {
        return $global:ProxyPorts.default -eq 10808
    }
    return $false
} "默认端口应为 10808 (V2rayN)"

# 6. 工具集成测试
Write-Section "第三方工具"

$tools = @{
    "Starship" = "starship"
    "FZF" = "fzf"
    "Bat" = "bat"
    "Ripgrep" = "rg"
    "Fd" = "fd"
    "Zoxide" = "zoxide"
}

foreach ($toolName in $tools.Keys) {
    $command = $tools[$toolName]
    Test-Condition "$toolName 工具" {
        Get-Command $command -ErrorAction SilentlyContinue
    } "命令: $command"
}

# 7. 功能测试
Write-Section "功能测试"

Test-Condition "配置重载功能" {
    try {
        # 测试 Reload-Profile 函数是否可以调用
        $reloadFunc = Get-Command Reload-Profile -ErrorAction SilentlyContinue
        return $reloadFunc -ne $null
    } catch {
        return $false
    }
} "测试 reload 命令可用性"

Test-Condition "配置信息显示" {
    Get-Command Show-ConfigInfo -ErrorAction SilentlyContinue
} "测试 config-info 命令"

Test-Condition "代理状态显示" {
    try {
        # 尝试调用代理状态函数
        if (Get-Command Show-ProxyStatus -ErrorAction SilentlyContinue) {
            return $true
        }
        return $false
    } catch {
        return $false
    }
} "测试代理状态查看功能"

# 8. 性能测试
Write-Section "性能检查"

Test-Condition "配置加载时间" {
    try {
        $startTime = Get-Date
        . $PROFILE
        $endTime = Get-Date
        $loadTime = ($endTime - $startTime).TotalMilliseconds
        return $loadTime -lt 3000  # 小于3秒认为正常
    } catch {
        return $false
    }
} "检查配置加载是否在合理时间内完成"

# 显示测试结果总结
Write-Summary $script:PassedTests $script:TotalTests

# 问题修复建议
if ($script:PassedTests -lt $script:TotalTests) {
    Write-Host "`n🔧 问题修复建议" -ForegroundColor Yellow
    Write-Host "=================" -ForegroundColor DarkYellow

    if ($FixIssues) {
        Write-Host "正在尝试自动修复问题..." -ForegroundColor Cyan

        # 尝试重新加载配置
        try {
            . $PROFILE
            Write-Host "✅ 已重新加载配置" -ForegroundColor Green
        } catch {
            Write-Host "❌ 配置重新加载失败: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "1. 运行 'reload' 重新加载配置" -ForegroundColor Gray
        Write-Host "2. 检查符号链接是否正确创建" -ForegroundColor Gray
        Write-Host "3. 以管理员权限重新运行安装脚本" -ForegroundColor Gray
        Write-Host "4. 使用 '.\install.ps1 -CreateLinks -Force' 强制重新安装" -ForegroundColor Gray
        Write-Host "5. 使用 '-FixIssues' 参数尝试自动修复" -ForegroundColor Gray
    }
}

# 返回测试结果
if ($script:PassedTests -eq $script:TotalTests) {
    Write-Host "`n🎉 所有测试通过！PowerShell 配置运行正常。" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n⚠️  存在 $($script:TotalTests - $script:PassedTests) 个问题需要修复。" -ForegroundColor Yellow
    exit 1
}
