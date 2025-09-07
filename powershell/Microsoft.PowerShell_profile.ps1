# =============================================================================
# PowerShell 7 Profile - Complete functionality configuration
# Optimized startup performance while preserving all modules
# =============================================================================

# Fast mode check (optional)
$FastMode = $env:POWERSHELL_FAST_MODE -eq "1"
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

# Delay load optional configurations (unless fast mode)
if (-not $FastMode) {
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

# Performance optimization functions
function Test-ProfilePerformance {
    <#
    .SYNOPSIS
    Test PowerShell configuration file loading performance
    #>
    $startTime = Get-Date
    
    # Simulate complete configuration loading process
    $configs = @("functions", "aliases", "history", "keybindings", "tools", "theme", "extra")
    foreach ($config in $configs) {
        $configPath = Join-Path $ProfileDir "$config.ps1"
        if (Test-Path $configPath) {
            . $configPath
        }
    }
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalMilliseconds
    
    Write-Host "`n⏱️  Profile Performance Test" -ForegroundColor Cyan
    Write-Host "Load Time: $duration ms" -ForegroundColor Green
    Write-Host "Fast Mode: $FastMode" -ForegroundColor Yellow
    Write-Host "PowerShell Edition: $(if ($IsWinPS) { 'Windows PowerShell' } else { 'PowerShell 7+' })" -ForegroundColor Gray
}

# Fast mode toggle functions
function Enable-FastMode {
    <#
    .SYNOPSIS
    Enable fast mode for better performance
    #>
    $env:POWERSHELL_FAST_MODE = "1"
    Write-Host "✅ Fast mode enabled. Restart PowerShell for full effect." -ForegroundColor Green
}

function Disable-FastMode {
    <#
    .SYNOPSIS
    Disable fast mode for full functionality
    #>
    $env:POWERSHELL_FAST_MODE = "0"
    Write-Host "❌ Fast mode disabled. Full features enabled." -ForegroundColor Yellow
}

# Startup tips
if (-not $FastMode) {
    if ($IsWinPS) {
        Write-Host "Tip: Use 'Enable-FastMode' for better performance or 'config-info' for features" -ForegroundColor DarkGray
    } else {
        Write-Host "💡 Use 'Enable-FastMode' for better performance or 'config-info' to view features" -ForegroundColor DarkGray
    }
}