# =============================================================================
# PowerShell Profile - Simplified Configuration
# =============================================================================

# Runtime environment
$IsWinPS = ($PSVersionTable.PSEdition -eq 'Desktop' -or $PSVersionTable.PSVersion.Major -lt 6)

# Import essential modules for Windows PowerShell 5.1
if ($IsWinPS) {
    Import-Module Microsoft.PowerShell.Management -Force -ErrorAction SilentlyContinue
    Import-Module Microsoft.PowerShell.Utility -Force -ErrorAction SilentlyContinue
    Import-Module Microsoft.PowerShell.Security -Force -ErrorAction SilentlyContinue
}

# Import essential modules for PowerShell 7+ (Core)
if (-not $IsWinPS) {
    Import-Module Microsoft.PowerShell.Management -Force -ErrorAction SilentlyContinue
    Import-Module Microsoft.PowerShell.Utility -Force -ErrorAction SilentlyContinue
    Import-Module Microsoft.PowerShell.Security -Force -ErrorAction SilentlyContinue
}

# Basic settings
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Configuration directory detection
$ProfileDir = $null

if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
    $ProfileDir = Join-Path (Split-Path $PSCommandPath -Parent) ".powershell"
} elseif (Test-Path (Join-Path (Split-Path $PROFILE -Parent) ".powershell")) {
    $ProfileDir = Join-Path (Split-Path $PROFILE -Parent) ".powershell"
} elseif (Test-Path ".\configs\powershell\.powershell") {
    $ProfileDir = Resolve-Path ".\configs\powershell\.powershell"
} elseif ($env:DOTFILES_DIR -and (Test-Path (Join-Path $env:DOTFILES_DIR "configs\powershell\.powershell"))) {
    $ProfileDir = Join-Path $env:DOTFILES_DIR "configs\powershell\.powershell"
} else {
    $ProfileDir = Join-Path (Split-Path $PROFILE -Parent) ".powershell"
}

# Initialize profile directory
if (-not (Test-Path $ProfileDir)) {
    New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
}

# Load configurations
$coreConfigs = if ($IsWinPS) { @("functions.winps", "aliases") } else { @("functions", "aliases") }
$optionalConfigs = @("history", "keybindings", "tools", "theme", "extra")

# Load core configurations
foreach ($config in $coreConfigs) {
    $configPath = Join-Path $ProfileDir "$config.ps1"
    if (Test-Path $configPath) {
        try {
            . $configPath
        } catch {
            Write-Warning "Failed to load $config.ps1"
        }
    }
}

# Load optional configurations
foreach ($config in $optionalConfigs) {
    $configPath = Join-Path $ProfileDir "$config.ps1"
    if (Test-Path $configPath) {
        try {
            . $configPath
        } catch {
            Write-Warning "Failed to load $config.ps1"
        }
    }
}

# Starship prompt
if (Get-Command starship -ErrorAction SilentlyContinue) {
    try {
        Invoke-Expression (&starship init powershell)
    } catch {
        function global:prompt {
            $path = (Get-Location).Path.Replace($env:USERPROFILE, '~')
            "PS $path> "
        }
    }
} else {
    function global:prompt {
        $path = (Get-Location).Path.Replace($env:USERPROFILE, '~')
        "PS $path> "
    }
}

# Chocolatey Profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}
