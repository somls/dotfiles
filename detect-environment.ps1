# detect-environment.ps1
# 自动检测用户环境和应用安装情况

[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$Detailed
)

function Get-WindowsVersion {
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        return @{
            Name = $os.Caption
            Version = $os.Version
            Build = $os.BuildNumber
            IsWindows11 = [int]$os.BuildNumber -ge 22000
        }
    } catch {
        return @{ Name = "Unknown"; Version = "Unknown"; Build = 0; IsWindows11 = $false }
    }
}

function Test-ApplicationInstalled {
    param([string]$AppName, [string[]]$Commands)

    $result = @{
        Name = $AppName
        Installed = $false
        InstallType = "Not Found"
        Path = $null
        Version = $null
    }

    # 检查命令（优先使用命令检测，更可靠）
    foreach ($cmd in $Commands) {
        $command = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($command) {
            $result.Installed = $true
            $result.Path = $command.Source

            # 判断安装类型
            $path = $command.Source
            if ($path -match "scoop|portable") {
                $result.InstallType = "Portable/Scoop"
            } elseif ($path -match "Program Files") {
                $result.InstallType = "System Install"
            } elseif ($path -match "AppData") {
                $result.InstallType = "User Install"
            } else {
                $result.InstallType = "System PATH"
            }

            # 获取版本信息
            try {
                $versionOutput = & $cmd --version 2>$null | Select-Object -First 1
                if ($versionOutput) {
                    $result.Version = $versionOutput.Trim()
                }
            } catch {
                # 某些应用可能不支持 --version 参数
            }

            return $result
        }
    }

    return $result
}

function Get-ConfigPaths {
    param([string]$AppName, [bool]$IsInstalled, [string]$InstallPath)

    # 简化版：只返回主要配置路径
    $configPath = switch ($AppName) {
        "WindowsTerminal" { "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState" }
        "Alacritty" { "$env:APPDATA\alacritty" }
        "WezTerm" { "$env:LOCALAPPDATA\wezterm" }
        "PowerShell" { "$env:USERPROFILE\Documents\PowerShell" }
        "Neovim" { "$env:LOCALAPPDATA\nvim" }
        default { $null }
    }

    if ($configPath -and (Test-Path (Split-Path $configPath -Parent))) {
        return @{ Config = $configPath }
    }

    return @{}
}

# 主检测逻辑
$detection = @{
    System = Get-WindowsVersion
    Applications = @{}
    Recommendations = @()
}

# 检测应用程序（简化版，只检测命令）
$appsToCheck = @{
    PowerShell = @("pwsh")
    WindowsTerminal = @("wt")
    WezTerm = @("wezterm")
    Alacritty = @("alacritty")
    Git = @("git")
    Starship = @("starship")
    Neovim = @("nvim")
    Scoop = @("scoop")
}

foreach ($appName in $appsToCheck.Keys) {
    $commands = $appsToCheck[$appName]
    $result = Test-ApplicationInstalled -AppName $appName -Commands $commands

    if ($result.Installed) {
        $result.ConfigPaths = Get-ConfigPaths -AppName $appName -IsInstalled $true -InstallPath $result.Path
    }

    $detection.Applications[$appName] = $result
}

# 生成建议
$installedCount = ($detection.Applications.Values | Where-Object { $_.Installed }).Count
$totalCount = $detection.Applications.Count

if (-not $detection.Applications.PowerShell.Installed) {
    $detection.Recommendations += "建议安装 PowerShell 7+ 以获得更好的体验"
}

if (-not $detection.Applications.Git.Installed) {
    $detection.Recommendations += "建议安装 Git 进行版本控制"
}

if ($installedCount -eq 0) {
    $detection.Recommendations += "未检测到支持的应用程序，建议先安装基础工具"
} elseif ($installedCount -lt 3) {
    $detection.Recommendations += "检测到较少应用程序，可考虑安装更多开发工具"
}

# 输出结果
if ($Json) {
    $detection | ConvertTo-Json -Depth 4
} else {
    Write-Host "🔍 环境检测报告" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan

    # 系统信息
    Write-Host "`n💻 系统信息:" -ForegroundColor Yellow
    Write-Host "  操作系统: $($detection.System.Name)" -ForegroundColor Gray
    Write-Host "  版本: $($detection.System.Version) (Build $($detection.System.Build))" -ForegroundColor Gray
    Write-Host "  Windows 11: $($detection.System.IsWindows11)" -ForegroundColor Gray

    # 应用程序状态
    Write-Host "`n📦 应用程序状态:" -ForegroundColor Yellow
    foreach ($appName in $detection.Applications.Keys) {
        $app = $detection.Applications[$appName]
        $status = if ($app.Installed) { "✅" } else { "❌" }
        $installType = if ($app.Installed) { " ($($app.InstallType))" } else { "" }

        Write-Host "  $status $appName$installType" -ForegroundColor $(if ($app.Installed) { 'Green' } else { 'Red' })

        if ($Detailed -and $app.Installed) {
            Write-Host "    路径: $($app.Path)" -ForegroundColor DarkGray
            if ($app.Version) {
                Write-Host "    版本: $($app.Version)" -ForegroundColor DarkGray
            }
            if ($app.ConfigPaths) {
                Write-Host "    配置路径:" -ForegroundColor DarkGray
                foreach ($type in $app.ConfigPaths.Keys) {
                    Write-Host "      $type`: $($app.ConfigPaths[$type])" -ForegroundColor DarkGray
                }
            }
        }
    }

    # 建议
    if ($detection.Recommendations.Count -gt 0) {
        Write-Host "`n💡 建议:" -ForegroundColor Yellow
        foreach ($rec in $detection.Recommendations) {
            Write-Host "  • $rec" -ForegroundColor Gray
        }
    }

    Write-Host "`n✨ 检测完成" -ForegroundColor Green
}
