# detect-environment.ps1
# Environment detection script for checking user environment and application installation

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

    # Check commands (prefer command detection, more reliable)
    foreach ($cmd in $Commands) {
        $command = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($command) {
            $result.Installed = $true
            $result.Path = $command.Source

            # Determine installation type
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

            # Get version information
            try {
                $versionOutput = & $cmd --version 2>$null | Select-Object -First 1
                if ($versionOutput) {
                    $result.Version = $versionOutput.Trim()
                }
            } catch {
                # Some applications may not support --version parameter
            }

            return $result
        }
    }

    return $result
}

function Get-ConfigPaths {
    param([string]$AppName, [bool]$IsInstalled, [string]$InstallPath)

    # Simplified: only return main configuration paths
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

# Main detection logic
$detection = @{
    System = Get-WindowsVersion
    Applications = @{}
    Recommendations = @()
}

# Check applications (simplified version, only check commands)
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

# Generate recommendations
$installedCount = ($detection.Applications.Values | Where-Object { $_.Installed }).Count
$totalCount = $detection.Applications.Count

if (-not $detection.Applications.PowerShell.Installed) {
    $detection.Recommendations += "Recommend installing PowerShell 7+ for better experience"
}

if (-not $detection.Applications.Git.Installed) {
    $detection.Recommendations += "Recommend installing Git for version control"
}

if ($installedCount -eq 0) {
    $detection.Recommendations += "No supported applications detected, recommend installing basic tools first"
} elseif ($installedCount -lt 3) {
    $detection.Recommendations += "Few applications detected, consider installing more development tools"
}

# Output results
if ($Json) {
    $detection | ConvertTo-Json -Depth 4
} else {
    Write-Host "Environment Detection Report" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan

    # System information
    Write-Host "`nSystem Information:" -ForegroundColor Yellow
    Write-Host "  OS: $($detection.System.Name)" -ForegroundColor Gray
    Write-Host "  Version: $($detection.System.Version) (Build $($detection.System.Build))" -ForegroundColor Gray
    Write-Host "  Windows 11: $($detection.System.IsWindows11)" -ForegroundColor Gray

    # Application status
    Write-Host "`nApplication Status:" -ForegroundColor Yellow
    foreach ($appName in $detection.Applications.Keys) {
        $app = $detection.Applications[$appName]
        $status = if ($app.Installed) { "OK" } else { "MISSING" }
        $installType = if ($app.Installed) { " ($($app.InstallType))" } else { "" }

        Write-Host "  $status $appName$installType" -ForegroundColor $(if ($app.Installed) { 'Green' } else { 'Red' })

        if ($Detailed -and $app.Installed) {
            Write-Host "    Path: $($app.Path)" -ForegroundColor DarkGray
            if ($app.Version) {
                Write-Host "    Version: $($app.Version)" -ForegroundColor DarkGray
            }
            if ($app.ConfigPaths) {
                Write-Host "    Config Paths:" -ForegroundColor DarkGray
                foreach ($type in $app.ConfigPaths.Keys) {
                    Write-Host "      $type`: $($app.ConfigPaths[$type])" -ForegroundColor DarkGray
                }
            }
        }
    }

    # Recommendations
    if ($detection.Recommendations.Count -gt 0) {
        Write-Host "`nRecommendations:" -ForegroundColor Yellow
        foreach ($rec in $detection.Recommendations) {
            Write-Host "  • $rec" -ForegroundColor Gray
        }
    }

    Write-Host "`nDetection Complete" -ForegroundColor Green
}