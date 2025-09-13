# =============================================================================
# Development Symbolic Link Script (dev-symlink.ps1)
# Real-time configuration sync for development - Developer use only
# =============================================================================

param(
    [ValidateSet("create", "remove", "status", "refresh", "diagnose")]
    [string]$Action = "status",

    [string[]]$ConfigType = @(),
    [switch]$Force,
    [switch]$DryRun,
    [switch]$All,
    [switch]$Verbose
)

# Color output functions
function Write-Success { param($Message) Write-Host $Message -ForegroundColor Green }
function Write-Error { param($Message) Write-Host $Message -ForegroundColor Red }
function Write-Info { param($Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Status { param($Message) Write-Host $Message -ForegroundColor Cyan }

# Check administrator privileges
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check developer mode
function Test-DeveloperMode {
    try {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
        $devMode = Get-ItemProperty -Path $regPath -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
        return $devMode.AllowDevelopmentWithoutDevLicense -eq 1
    } catch {
        return $false
    }
}

# Adaptive path detection functions
function Find-WindowsTerminalPath {
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState"
    )

    # Find all Windows Terminal packages
    $terminalPackages = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Directory |
        Where-Object { $_.Name -like "Microsoft.WindowsTerminal*" }

    foreach ($package in $terminalPackages) {
        $localStatePath = Join-Path $package.FullName "LocalState"
        if (Test-Path $localStatePath) {
            $possiblePaths += $localStatePath
        }
    }

    return $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
}

function Find-ScoopPath {
    # Check common Scoop installation paths
    $possiblePaths = @(
        "$env:USERPROFILE\scoop",
        "$env:SCOOP",
        "C:\scoop"
    )

    # Try to detect from PATH
    $scoopCommand = Get-Command scoop -ErrorAction SilentlyContinue
    if ($scoopCommand) {
        $scoopFromPath = $scoopCommand.Source
        $scoopRoot = Split-Path (Split-Path $scoopFromPath -Parent) -Parent
        $possiblePaths += $scoopRoot
    }

    return $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
}

function Find-NeovimConfigPath {
    # Standard paths for different Neovim installations
    $possiblePaths = @(
        "$env:LOCALAPPDATA\nvim",
        "$env:APPDATA\nvim"
    )

    # Check if nvim is available and get config path
    try {
        $nvimConfigPath = & nvim --headless -c "lua print(vim.fn.stdpath('config'))" -c "qa" 2>$null
        if ($nvimConfigPath -and (Test-Path (Split-Path $nvimConfigPath -Parent))) {
            $possiblePaths += $nvimConfigPath
        }
    } catch {
        # Neovim not installed or not in PATH
    }

    return $possiblePaths | Where-Object { Test-Path (Split-Path $_ -Parent) } | Select-Object -First 1
}

function Find-PowerShellPaths {
    $paths = @()

    # PowerShell 7+ path
    if (Test-Path "$env:USERPROFILE\Documents\PowerShell") {
        $paths += "$env:USERPROFILE\Documents\PowerShell"
    }

    # Windows PowerShell 5.1 path
    if (Test-Path "$env:USERPROFILE\Documents\WindowsPowerShell") {
        $paths += "$env:USERPROFILE\Documents\WindowsPowerShell"
    }

    return $paths
}

function Find-StarshipConfigPath {
    # Standard config locations
    $possiblePaths = @(
        "$env:USERPROFILE\.config",
        "$env:APPDATA"
    )

    # Check if starship is available and supports config path detection
    try {
        # Starship stores config in STARSHIP_CONFIG env var or ~/.config/starship.toml
        if ($env:STARSHIP_CONFIG) {
            $starshipDir = Split-Path $env:STARSHIP_CONFIG -Parent
            $possiblePaths += $starshipDir
        }
    } catch {
        # Starship not available
    }

    return $possiblePaths | Where-Object {
        if (-not (Test-Path $_)) {
            try { New-Item -Path $_ -ItemType Directory -Force | Out-Null; $true }
            catch { $false }
        } else { $true }
    } | Select-Object -First 1
}

# Configuration mapping with adaptive path detection
function Get-ConfigMappings {
    $dotfilesDir = $PSScriptRoot
    $mappings = @{}

    # PowerShell - detect available PowerShell installations
    $powershellPaths = Find-PowerShellPaths
    if ($powershellPaths.Count -gt 0) {
        $mappings["powershell"] = @{
            Source = "$dotfilesDir\configs\powershell"
            Targets = $powershellPaths
            Files = @(
                @{ File = "Microsoft.PowerShell_profile.ps1"; Target = "Microsoft.PowerShell_profile.ps1"; IsDirectory = $false }
                @{ File = ".powershell"; Target = ".powershell"; IsDirectory = $true }
            )
        }
    }

    # Git - universal user profile location
    $mappings["git"] = @{
        Source = "$dotfilesDir\configs\git"
        Targets = @("$env:USERPROFILE")
        Files = @(
            @{ File = "gitconfig"; Target = ".gitconfig"; IsDirectory = $false }
            @{ File = "gitconfig.local"; Target = ".gitconfig.local"; IsDirectory = $false }
            @{ File = "gitignore_global"; Target = ".gitignore_global"; IsDirectory = $false }
            @{ File = "gitmessage"; Target = ".gitmessage"; IsDirectory = $false }
        )
    }

    # Starship - adaptive config path
    $starshipPath = Find-StarshipConfigPath
    if ($starshipPath) {
        $mappings["starship"] = @{
            Source = "$dotfilesDir\configs\starship"
            Targets = @($starshipPath)
            Files = @(
                @{ File = "starship.toml"; Target = "starship.toml"; IsDirectory = $false }
            )
        }
    }

    # Neovim - adaptive config detection
    $neovimPath = Find-NeovimConfigPath
    if ($neovimPath) {
        $mappings["neovim"] = @{
            Source = "$dotfilesDir\configs\neovim"
            Targets = @($neovimPath)
            Files = @(
                @{ File = "init.lua"; Target = "init.lua"; IsDirectory = $false }
                @{ File = "lazy-lock.json"; Target = "lazy-lock.json"; IsDirectory = $false }
                @{ File = "lua"; Target = "lua"; IsDirectory = $true }
            )
        }
    }

    # Windows Terminal - adaptive package detection
    $terminalPath = Find-WindowsTerminalPath
    if ($terminalPath) {
        $mappings["WindowsTerminal"] = @{
            Source = "$dotfilesDir\configs\WindowsTerminal"
            Targets = @($terminalPath)
            Files = @(
                @{ File = "settings.json"; Target = "settings.json"; IsDirectory = $false }
            )
        }
    }

    # Scoop - adaptive installation detection
    $scoopPath = Find-ScoopPath
    if ($scoopPath) {
        $mappings["scoop"] = @{
            Source = "$dotfilesDir\configs\scoop"
            Targets = @($scoopPath)
            Files = @(
                @{ File = "config.json"; Target = "config.json"; IsDirectory = $false }
            )
        }
    }

    return $mappings
}

# Create symbolic link
function New-SymbolicLink {
    param(
        [string]$LinkPath,
        [string]$TargetPath,
        [bool]$IsDirectory = $false
    )

    try {
        $itemType = if ($IsDirectory) { "SymbolicLink" } else { "SymbolicLink" }

        # Ensure parent directory exists
        $parentDir = Split-Path $LinkPath -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
        }

        # Remove existing item if it exists
        if (Test-Path $LinkPath) {
            Remove-Item $LinkPath -Force -Recurse
        }

        # Create symbolic link
        New-Item -ItemType $itemType -Path $LinkPath -Target $TargetPath -Force | Out-Null
        return $true
    } catch {
        Write-Error "Failed to create link: $($_.Exception.Message)"
        return $false
    }
}

# Check if path is symbolic link
function Test-SymbolicLink {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return $false
    }

    $item = Get-Item $Path -Force
    return ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
}

# Get symbolic link target
function Get-SymbolicLinkTarget {
    param([string]$Path)

    if (Test-SymbolicLink $Path) {
        $item = Get-Item $Path -Force
        return $item.Target
    }
    return $null
}

# Process configuration
function Process-Configuration {
    param(
        [string]$ConfigName,
        [hashtable]$Config,
        [string]$Action
    )

    Write-Status "Processing $ConfigName configuration..."

    foreach ($target in $Config.Targets) {
        foreach ($fileMapping in $Config.Files) {
            $sourcePath = Join-Path $Config.Source $fileMapping.File
            $targetPath = Join-Path $target $fileMapping.Target

            # Skip if source doesn't exist
            if (-not (Test-Path $sourcePath)) {
                Write-Info "  Source not found: $sourcePath"
                continue
            }

            switch ($Action) {
                "status" {
                    if (Test-Path $targetPath) {
                        if (Test-SymbolicLink $targetPath) {
                            $linkTarget = Get-SymbolicLinkTarget $targetPath
                            if ($linkTarget -eq $sourcePath) {
                                Write-Success "  [OK] $targetPath -> $sourcePath"
                            } else {
                                Write-Error "  [ERROR] $targetPath -> $linkTarget (wrong target)"
                            }
                        } else {
                            Write-Info "  [WARNING] $targetPath (not a symbolic link)"
                        }
                    } else {
                        Write-Info "  [MISSING] $targetPath (not exists)"
                    }
                }

                "create" {
                    if ($DryRun) {
                        Write-Info "  [DRY RUN] Would create: $targetPath -> $sourcePath"
                    } else {
                        if (New-SymbolicLink $targetPath $sourcePath $fileMapping.IsDirectory) {
                            Write-Success "  [CREATED] $targetPath -> $sourcePath"
                        } else {
                            Write-Error "  [FAILED] Failed to create: $targetPath"
                        }
                    }
                }

                "remove" {
                    if (Test-Path $targetPath -and (Test-SymbolicLink $targetPath)) {
                        if ($DryRun) {
                            Write-Info "  [DRY RUN] Would remove: $targetPath"
                        } else {
                            Remove-Item $targetPath -Force -Recurse
                            Write-Success "  [REMOVED] $targetPath"
                        }
                    }
                }

                "refresh" {
                    if (Test-Path $targetPath) {
                        if (Test-SymbolicLink $targetPath) {
                            $linkTarget = Get-SymbolicLinkTarget $targetPath
                            if ($linkTarget -ne $sourcePath) {
                                if ($DryRun) {
                                    Write-Info "  [DRY RUN] Would refresh: $targetPath"
                                } else {
                                    Remove-Item $targetPath -Force -Recurse
                                    if (New-SymbolicLink $targetPath $sourcePath $fileMapping.IsDirectory) {
                                        Write-Success "  [REFRESHED] $targetPath -> $sourcePath"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

# Main execution
Write-Status "Development Symbolic Link Manager"
Write-Status "================================="

# Check permissions
$isAdmin = Test-Administrator
$isDeveloperMode = Test-DeveloperMode

if (-not $isAdmin -and -not $isDeveloperMode) {
    Write-Error "This script requires either:"
    Write-Error "  1. Administrator privileges, OR"
    Write-Error "  2. Developer Mode enabled in Windows Settings"
    Write-Error ""
    Write-Error "To enable Developer Mode:"
    Write-Error "  Settings > Update & Security > For developers > Developer mode"
    exit 1
}

if ($isDeveloperMode) {
    Write-Info "Developer Mode detected - symbolic links can be created without admin privileges"
} elseif ($isAdmin) {
    Write-Info "Administrator privileges detected"
}

# Get configuration mappings and show detection results
Write-Status "Detecting application installations..."
$mappings = Get-ConfigMappings

# Show detection summary
$detectedApps = $mappings.Keys -join ", "
if ($detectedApps) {
    Write-Success "Detected applications: $detectedApps"
} else {
    Write-Error "No supported applications detected on this system"
    exit 1
}

# Show specific path detections for troubleshooting
Write-Host ""
Write-Status "Path Detection Results:"
foreach ($configName in $mappings.Keys) {
    $config = $mappings[$configName]
    Write-Host "  $configName -> $($config.Targets -join ', ')" -ForegroundColor Cyan
}
Write-Host ""

# Determine which configurations to process
$configsToProcess = @()
if ($All -or $ConfigType.Count -eq 0) {
    $configsToProcess = $mappings.Keys
} else {
    $configsToProcess = $ConfigType | Where-Object { $mappings.ContainsKey($_) }
}

# Process each configuration
if ($Action -eq "diagnose") {
    Write-Status "=== DIAGNOSTIC INFORMATION ==="
    Write-Host ""

    Write-Status "Environment Variables:"
    Write-Host "  USERPROFILE: $env:USERPROFILE"
    Write-Host "  LOCALAPPDATA: $env:LOCALAPPDATA"
    Write-Host "  APPDATA: $env:APPDATA"
    Write-Host "  SCOOP: $env:SCOOP"
    Write-Host "  STARSHIP_CONFIG: $env:STARSHIP_CONFIG"
    Write-Host ""

    Write-Status "Application Detection Details:"

    # Windows Terminal detection
    Write-Host "Windows Terminal:"
    $terminalPackages = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "Microsoft.WindowsTerminal*" }
    if ($terminalPackages) {
        foreach ($pkg in $terminalPackages) {
            $localState = Join-Path $pkg.FullName "LocalState"
            $exists = Test-Path $localState
            $status = if ($exists) { "EXISTS" } else { "NOT FOUND" }
            Write-Host "  - $($pkg.Name): $localState [$status]"
        }
    } else {
        Write-Host "  - No Windows Terminal packages found"
    }

    # Scoop detection
    Write-Host "Scoop:"
    $scoopCmd = Get-Command scoop -ErrorAction SilentlyContinue
    if ($scoopCmd) {
        Write-Host "  - Command found: $($scoopCmd.Source)"
        $scoopRoot = Split-Path (Split-Path $scoopCmd.Source -Parent) -Parent
        Write-Host "  - Detected root: $scoopRoot"
    } else {
        Write-Host "  - Scoop command not found in PATH"
    }

    # Neovim detection
    Write-Host "Neovim:"
    $nvimCmd = Get-Command nvim -ErrorAction SilentlyContinue
    if ($nvimCmd) {
        Write-Host "  - Command found: $($nvimCmd.Source)"
        try {
            $nvimConfig = & nvim --headless -c "lua print(vim.fn.stdpath('config'))" -c "qa" 2>$null | Out-String
            $nvimConfig = $nvimConfig.Trim()
            Write-Host "  - Config path: $nvimConfig"
        } catch {
            Write-Host "  - Could not determine config path"
        }
    } else {
        Write-Host "  - Neovim command not found in PATH"
    }

    # PowerShell paths
    Write-Host "PowerShell:"
    $ps7Path = "$env:USERPROFILE\Documents\PowerShell"
    $ps51Path = "$env:USERPROFILE\Documents\WindowsPowerShell"
    $ps7Status = if (Test-Path $ps7Path) { "EXISTS" } else { "NOT FOUND" }
    $ps51Status = if (Test-Path $ps51Path) { "EXISTS" } else { "NOT FOUND" }
    Write-Host "  - PowerShell 7+: $ps7Path [$ps7Status]"
    Write-Host "  - Windows PowerShell 5.1: $ps51Path [$ps51Status]"

    Write-Host ""
    Write-Status "Available configurations for this system:"
    foreach ($configName in $mappings.Keys) {
        Write-Success "  ✓ $configName"
    }

    if ($mappings.Keys.Count -eq 0) {
        Write-Error "  No configurations available - applications may not be installed"
    }

    return
}

foreach ($configName in $configsToProcess) {
    Process-Configuration $configName $mappings[$configName] $Action
    Write-Host ""
}

# Summary
switch ($Action) {
    "status" {
        Write-Status "Status check completed. Use other actions to manage symbolic links:"
        Write-Host "  .\dev-symlink.ps1 -Action create    # Create symbolic links"
        Write-Host "  .\dev-symlink.ps1 -Action remove    # Remove symbolic links"
        Write-Host "  .\dev-symlink.ps1 -Action refresh   # Refresh symbolic links"
        Write-Host "  .\dev-symlink.ps1 -Action diagnose  # Show detailed detection info"
        Write-Host "  .\dev-symlink.ps1 -Action status    # Check status"
        Write-Host ""
        Write-Host "Additional options:"
        Write-Host "  -ConfigType powershell,git    # Process specific config types only"
        Write-Host "  -All                          # Process all detected configurations"
        Write-Host "  -DryRun                       # Preview changes without applying"
        Write-Host "  -Verbose                      # Show detailed output"
    }
    "create" {
        if (-not $DryRun) {
            Write-Success "Symbolic link creation completed!"
        }
    }
    "remove" {
        if (-not $DryRun) {
            Write-Success "Symbolic link removal completed!"
        }
    }
    "refresh" {
        if (-not $DryRun) {
            Write-Success "Symbolic link refresh completed!"
        }
    }
}

if ($DryRun) {
    Write-Info "This was a dry run. Use without -DryRun to perform actual operations."
}
