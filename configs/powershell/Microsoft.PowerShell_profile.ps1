# =============================================================================
# PowerShell Profile - Simplified Configuration
# =============================================================================

# Runtime environment
$IsWinPS = ($PSVersionTable.PSEdition -eq 'Desktop' -or $PSVersionTable.PSVersion.Major -lt 6)

# Import essential modules with better error handling
function Import-ModuleSafely {
    param([string]$ModuleName)

    try {
        # Check if module is already loaded to avoid duplicate warnings
        if (-not (Get-Module -Name $ModuleName -ErrorAction SilentlyContinue)) {
            Import-Module $ModuleName -Force -ErrorAction Stop -WarningAction SilentlyContinue
        }
    } catch {
        # Silently continue if module import fails - most built-in modules are auto-loaded
        Write-Verbose "Module $ModuleName not imported: $($_.Exception.Message)"
    }
}

# Import essential modules based on PowerShell version
$essentialModules = @(
    'Microsoft.PowerShell.Management'
    'Microsoft.PowerShell.Utility'
)

# Only import Security module if needed and available
if ($IsWinPS -and (Get-Module -ListAvailable Microsoft.PowerShell.Security -ErrorAction SilentlyContinue)) {
    $essentialModules += 'Microsoft.PowerShell.Security'
}

foreach ($module in $essentialModules) {
    Import-ModuleSafely -ModuleName $module
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
$optionalConfigs = if ($IsWinPS) {
    @("keybindings.winps", "history", "modules", "tools", "lazy-load.winps", "theme", "extra")
} else {
    @("keybindings", "history", "modules", "tools", "lazy-load", "theme", "extra")
}

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

if ($env:TERM_PROGRAM -eq "kiro") { . "$(kiro --locate-shell-integration-path pwsh)" }
