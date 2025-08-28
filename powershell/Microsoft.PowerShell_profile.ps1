# =============================================================================
# PowerShell 7 Profile - Optimized Configuration
# 高效/简洁/实用 - 快速启动，核心功能
# Last Modified: 2025-08-13
# =============================================================================

# 快速模式检查
$FastMode = $env:POWERSHELL_FAST_MODE -eq "1"
# 运行时环境
$IsWinPS = ($PSVersionTable.PSEdition -eq 'Desktop' -or $PSVersionTable.PSVersion.Major -lt 6)

# 基础设置 (必需)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# 配置目录
$ProfileDir = Join-Path $env:USERPROFILE ".powershell"

# 快速初始化
if (-not (Test-Path $ProfileDir)) {
    New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
}

# 智能模块加载 - 按需加载，提升启动速度
$coreConfigs = if ($IsWinPS) { @("functions.winps", "aliases") } else { @("functions", "aliases") }
$optionalConfigs = @("history", "keybindings", "tools", "theme", "extra")

# 加载核心配置
foreach ($config in $coreConfigs) {
    $configPath = Join-Path $ProfileDir "$config.ps1"
    if (Test-Path $configPath) {
        try { . $configPath } catch { Write-Warning "Failed to load $config.ps1" }
    }
}

# 延迟加载可选配置 (除非快速模式)
if (-not $FastMode) {
    foreach ($config in $optionalConfigs) {
        $configPath = Join-Path $ProfileDir "$config.ps1"
        if (Test-Path $configPath) {
            try { . $configPath } catch { }
        }
    }
}

# 5. ---- Starship 提示符 ----
if (Get-Command starship -ErrorAction SilentlyContinue) {
    try {
        Invoke-Expression (&starship init powershell)
    } catch {
        # 简单备用提示符
        function global:prompt { "PS $(Split-Path -Leaf (Get-Location))> " }
    }
} else {
    # 默认简单提示符
    function global:prompt {
        $path = (Get-Location).Path.Replace($env:USERPROFILE, '~')
        "PS $path> "
    }
}

# 6. ---- 启动提示 ----
if (-not $FastMode) {
    if ($IsWinPS) {
        Write-Host "Tip: run 'config-info' to see available features" -ForegroundColor DarkGray
    } else {
        Write-Host "💡 使用 'config-info' 查看可用功能" -ForegroundColor DarkGray
    }
}



