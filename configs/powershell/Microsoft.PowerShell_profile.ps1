# =============================================================================
# PowerShell 7 Profile - Complete functionality configuration
# Optimized startup performance while preserving all modules
# =============================================================================


# Runtime environment
$IsWinPS = ($PSVersionTable.PSEdition -eq 'Desktop' -or $PSVersionTable.PSVersion.Major -lt 6)

# Basic settings (required)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Configuration directory
$ProfileDir = Join-Path $env:USERPROFILE ".powershell"

# Quick initialization
if (-not (Test-Path $ProfileDir)) {
    New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
}

# Smart module loading - preserve complete functionality but optimize loading strategy
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
        # Simple fallback prompt
        function global:prompt { 
            $path = (Get-Location).Path.Replace($env:USERPROFILE, '~')
            "PS $path> " 
        }
    }
} else {
    # Default simple prompt
    function global:prompt {
        $path = (Get-Location).Path.Replace($env:USERPROFILE, '~')
        "PS $path> "
    }
}


# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
