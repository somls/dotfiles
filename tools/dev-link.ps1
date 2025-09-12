<#
.SYNOPSIS
    Developer Symbolic Link Management Script

.DESCRIPTION
    This script manages symbolic links for development mode.
    It can create, remove, or check the status of symbolic links
    between the dotfiles repository and application configuration directories.

.PARAMETER Action
    The action to perform: Create, Remove, or Status

.PARAMETER Component
    Specific component to manage. If not specified, manages all components.

.PARAMETER Force
    Force operation without confirmation prompts

.PARAMETER Quiet
    Suppress non-essential output

.EXAMPLE
    .\dev-link.ps1 -Action Create
    Creates symbolic links for all components

.EXAMPLE
    .\dev-link.ps1 -Action Status -Component PowerShell
    Shows status of PowerShell symbolic links

.EXAMPLE
    .\dev-link.ps1 -Action Remove -Force
    Removes all symbolic links without confirmation
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Create', 'Remove', 'Status')]
    [string]$Action,

    [ValidateSet('Git', 'GitExtras', 'PowerShell', 'PowerShellExtras', 'PowerShellModule', 'Neovim', 'Starship', 'WindowsTerminal', 'Scoop')]
    [string]$Component,

    [switch]$Force,
    [switch]$Quiet
)

# Script configuration
$script:SourceRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$script:LogsDir = Join-Path $script:SourceRoot ".dotfiles\logs"
$script:LogFile = Join-Path $script:LogsDir "dev-link-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Ensure logs directory exists
if (-not (Test-Path $script:LogsDir)) {
    New-Item -ItemType Directory -Path $script:LogsDir -Force | Out-Null
}

# Logging function
function Write-DevLog {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"

    # Console output with colors
    if (-not $Quiet) {
        $color = switch ($Level) {
            'INFO'    { 'White' }
            'SUCCESS' { 'Green' }
            'WARN'    { 'Yellow' }
            'ERROR'   { 'Red' }
            'DEBUG'   { 'Gray' }
            default   { 'White' }
        }

        $icon = switch ($Level) {
            'INFO'    { '[i]' }
            'SUCCESS' { '[+]' }
            'WARN'    { '[!]' }
            'ERROR'   { '[x]' }
            'DEBUG'   { '[d]' }
            default   { '[?]' }
        }

        Write-Host "$icon $Message" -ForegroundColor $color
    }

    # File logging
    try {
        Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8
    } catch {
        # Continue if unable to write to log file
    }
}

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Get target paths for each component
function Get-ComponentPaths {
    $paths = @{}

    # PowerShell configuration paths
    $documentsPath = [Environment]::GetFolderPath('MyDocuments')
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $paths['PowerShell'] = "$documentsPath\PowerShell"
        $paths['PowerShellModule'] = "$documentsPath\PowerShell\Modules"
    } else {
        $paths['PowerShell'] = "$documentsPath\WindowsPowerShell"
        $paths['PowerShellModule'] = "$documentsPath\WindowsPowerShell\Modules"
    }

    # Git configuration paths
    $paths['Git'] = "$env:USERPROFILE"
    $paths['GitExtras'] = "$env:USERPROFILE"

    # PowerShell extras
    $paths['PowerShellExtras'] = "$env:USERPROFILE"

    # Application configuration paths
    $paths['Neovim'] = "$env:LOCALAPPDATA\nvim"
    $paths['Starship'] = "$env:USERPROFILE\.config"

    # Windows Terminal - Dynamic detection
    $possibleWTPaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState"
    )

    $wtPath = $null
    $wtPackages = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Directory -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -like "Microsoft.WindowsTerminal*" }

    foreach ($package in $wtPackages) {
        $localStatePath = Join-Path $package.FullName "LocalState"
        if (Test-Path $localStatePath) {
            $wtPath = $localStatePath
            break
        }
    }

    if (-not $wtPath) {
        foreach ($path in $possibleWTPaths) {
            if (Test-Path $path) {
                $wtPath = $path
                break
            }
        }
    }

    $paths['WindowsTerminal'] = if ($wtPath) { $wtPath } else { $possibleWTPaths[0] }

    # Scoop - Dynamic detection
    $scoopPath = $env:SCOOP
    if (-not $scoopPath) {
        $possibleScoopPaths = @(
            "$env:USERPROFILE\scoop",
            "$env:SystemDrive\Scoop",
            "$env:ProgramData\scoop"
        )

        if (-not $env:SCOOP_GLOBAL) {
            $possibleScoopPaths += @(
                "$env:USERPROFILE\AppData\Local\scoop",
                "$env:SystemDrive\scoop"
            )
        }

        foreach ($path in $possibleScoopPaths) {
            if ($path -and (Test-Path $path)) {
                $scoopPath = $path
                break
            }
        }
    }
    $paths['Scoop'] = if ($scoopPath) { $scoopPath } else { "$env:USERPROFILE\scoop" }

    return $paths
}

# Define source to target mappings
function Get-ComponentMappings {
    return @{
        # Git configuration - main config
        'Git' = @(
            @{ Source = "configs\git\gitconfig"; Target = ".gitconfig" }
        )
        # Git configuration - additional files
        'GitExtras' = @(
            @{ Source = "configs\git\gitignore_global"; Target = ".gitignore_global" },
            @{ Source = "configs\git\gitmessage"; Target = ".gitmessage" }
        )
        # PowerShell configuration - main profile
        'PowerShell' = @(
            @{ Source = "configs\powershell\Microsoft.PowerShell_profile.ps1"; Target = "Microsoft.PowerShell_profile.ps1" }
        )
        # PowerShell configuration - additional folders
        'PowerShellExtras' = @(
            @{ Source = "configs\powershell\.powershell"; Target = ".powershell" }
        )
        # PowerShell modules
        'PowerShellModule' = @(
            @{ Source = "modules\DotfilesUtilities.psm1"; Target = "DotfilesUtilities\DotfilesUtilities.psm1"; IsModule = $true },
            @{ Source = "modules\EnvironmentAdapter.psm1"; Target = "EnvironmentAdapter\EnvironmentAdapter.psm1"; IsModule = $true }
        )
        # Neovim configuration
        'Neovim' = @(
            @{ Source = "configs\neovim"; Target = "." }
        )
        # Starship prompt configuration
        'Starship' = @(
            @{ Source = "configs\starship\starship.toml"; Target = "starship.toml" }
        )
        # Windows Terminal configuration
        'WindowsTerminal' = @(
            @{ Source = "configs\WindowsTerminal\settings.json"; Target = "settings.json" }
        )
        # Scoop package manager configuration
        'Scoop' = @(
            @{ Source = "configs\scoop\config.json"; Target = "config.json" }
        )
    }
}

# Create symbolic link
function New-SymbolicLink {
    param(
        [string]$Source,
        [string]$Target,
        [string]$ComponentName
    )

    $sourcePath = Join-Path $script:SourceRoot $Source

    if (-not (Test-Path $sourcePath)) {
        Write-DevLog "Source path does not exist: $sourcePath" "ERROR"
        return $false
    }

    # Create target directory if it doesn't exist
    $targetDir = Split-Path $Target -Parent
    if ($targetDir -and -not (Test-Path $targetDir)) {
        try {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            Write-DevLog "Created target directory: $targetDir" "INFO"
        } catch {
            Write-DevLog "Failed to create target directory: $targetDir - $($_.Exception.Message)" "ERROR"
            return $false
        }
    }

    # Remove existing target if it exists
    if (Test-Path $Target) {
        if (-not $Force) {
            $response = Read-Host "Target exists: $Target. Replace? (y/N)"
            if ($response -notmatch '^[Yy]$') {
                return $false
            }
        }

        try {
            Remove-Item $Target -Force -Recurse
            Write-DevLog "Removed existing target: $Target" "INFO"
        } catch {
            Write-DevLog "Failed to remove existing target: $Target - $($_.Exception.Message)" "ERROR"
            return $false
        }
    }

    # Create symbolic link
    try {
        $item = Get-Item $sourcePath
        if ($item.PSIsContainer) {
            New-Item -ItemType SymbolicLink -Path $Target -Target $sourcePath -Force | Out-Null
        } else {
            New-Item -ItemType SymbolicLink -Path $Target -Target $sourcePath -Force | Out-Null
        }

        Write-DevLog "Created symbolic link: $Target -> $sourcePath" "SUCCESS"
        return $true
    } catch {
        Write-DevLog "Failed to create symbolic link: $Target -> $sourcePath - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Remove symbolic link
function Remove-SymbolicLink {
    param(
        [string]$Source,
        [string]$Target,
        [string]$ComponentName
    )

    if (-not (Test-Path $Target)) {
        Write-DevLog "Target does not exist: $Target" "WARN"
        return $true
    }

    $item = Get-Item $Target
    if ($item.LinkType -ne "SymbolicLink") {
        Write-DevLog "Target is not a symbolic link: $Target" "WARN"
        return $false
    }

    try {
        Remove-Item $Target -Force
        Write-DevLog "Removed symbolic link: $Target" "SUCCESS"
        return $true
    } catch {
        Write-DevLog "Failed to remove symbolic link: $Target - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Get symbolic link status
function Get-SymbolicLinkStatus {
    param(
        [string]$Source,
        [string]$Target,
        [string]$ComponentName
    )

    $sourcePath = Join-Path $script:SourceRoot $Source
    $status = @{
        Component = $ComponentName
        Source = $Source
        Target = $Target
        SourcePath = $sourcePath
        Exists = $false
        IsSymbolicLink = $false
        IsValid = $false
        TargetPath = $null
    }

    if (Test-Path $Target) {
        $status.Exists = $true
        $item = Get-Item $Target

        if ($item.LinkType -eq "SymbolicLink") {
            $status.IsSymbolicLink = $true
            $status.TargetPath = $item.Target

            if ($item.Target -eq $sourcePath) {
                $status.IsValid = $true
            }
        }
    }

    return $status
}

# Process component
function Invoke-ComponentAction {
    param(
        [string]$ComponentName,
        [string]$Action
    )

    $paths = Get-ComponentPaths
    $mappings = Get-ComponentMappings

    if (-not $paths.ContainsKey($ComponentName)) {
        Write-DevLog "Unknown component: $ComponentName" "ERROR"
        return $false
    }

    if (-not $mappings.ContainsKey($ComponentName)) {
        Write-DevLog "No mappings defined for component: $ComponentName" "ERROR"
        return $false
    }

    $basePath = $paths[$ComponentName]
    $componentMappings = $mappings[$ComponentName]
    $success = $true

    Write-DevLog "Processing component: $ComponentName" "INFO"

    foreach ($mapping in $componentMappings) {
        # Handle PowerShell modules specially
        if ($mapping.IsModule -and $ComponentName -eq 'PowerShellModule') {
            $targetPath = Join-Path $basePath $mapping.Target
        } elseif ($mapping.Target -eq ".") {
            # Handle directory mappings (like Neovim)
            $targetPath = $basePath
        } else {
            $targetPath = Join-Path $basePath $mapping.Target
        }

        switch ($Action) {
            'Create' {
                $result = New-SymbolicLink -Source $mapping.Source -Target $targetPath -ComponentName $ComponentName
                if (-not $result) { $success = $false }
            }
            'Remove' {
                $result = Remove-SymbolicLink -Source $mapping.Source -Target $targetPath -ComponentName $ComponentName
                if (-not $result) { $success = $false }
            }
            'Status' {
                $status = Get-SymbolicLinkStatus -Source $mapping.Source -Target $targetPath -ComponentName $ComponentName

                $statusText = if ($status.Exists) {
                    if ($status.IsSymbolicLink) {
                        if ($status.IsValid) {
                            "Valid symbolic link"
                        } else {
                            "Invalid symbolic link (wrong target)"
                        }
                    } else {
                        "Exists but not a symbolic link"
                    }
                } else {
                    "Does not exist"
                }

                Write-DevLog "$ComponentName -> $($mapping.Target): $statusText" "INFO"
            }
        }
    }

    return $success
}

# Environment detection and reporting
function Show-EnvironmentInfo {
    Write-DevLog "=== Environment Detection Report ===" "INFO"

    # System info
    Write-DevLog "OS: $($env:OS) $($env:PROCESSOR_ARCHITECTURE)" "INFO"
    Write-DevLog "User: $($env:USERNAME)" "INFO"
    Write-DevLog "Home: $($env:USERPROFILE)" "INFO"

    # PowerShell info
    Write-DevLog "PowerShell: $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))" "INFO"

    # Path detection results
    $paths = Get-ComponentPaths
    Write-DevLog "=== Detected Paths ===" "INFO"
    foreach ($component in $paths.Keys) {
        $path = $paths[$component]
        $exists = Test-Path $path
        $status = if ($exists) { "EXISTS" } else { "MISSING" }
        Write-DevLog "$component`: $path [$status]" "INFO"
    }

    # Application detection
    Write-DevLog "=== Application Detection ===" "INFO"

    $apps = @{
        'PowerShell 7' = 'pwsh'
        'Windows PowerShell 5' = 'powershell'
        'Git' = 'git'
        'Starship' = 'starship'
        'Scoop' = 'scoop'
    }

    foreach ($appName in $apps.Keys) {
        $command = Get-Command $apps[$appName] -ErrorAction SilentlyContinue
        if ($command) {
            Write-DevLog "$appName`: $($command.Source)" "SUCCESS"
        } else {
            Write-DevLog "$appName`: Not found" "WARN"
        }
    }

    Write-DevLog "=== End Environment Report ===" "INFO"
}

# Main execution
function Main {
    Write-DevLog "Starting dev-link.ps1 - Action: $Action" "INFO"

    # Show environment info for debugging
    if ($Action -eq 'Status' -and -not $Component) {
        Show-EnvironmentInfo
    }

    # Check administrator privileges for symbolic link creation
    if ($Action -eq 'Create' -and -not (Test-Administrator)) {
        Write-DevLog "Administrator privileges required for creating symbolic links" "ERROR"
        Write-DevLog "Please run PowerShell as Administrator and try again" "ERROR"
        exit 1
    }

    $components = if ($Component) {
        @($Component)
    } else {
        # Default components to process
        @('Git', 'GitExtras', 'PowerShell', 'PowerShellExtras', 'PowerShellModule', 'Neovim', 'Starship', 'WindowsTerminal', 'Scoop')
    }

    $overallSuccess = $true

    foreach ($comp in $components) {
        $result = Invoke-ComponentAction -ComponentName $comp -Action $Action
        if (-not $result) {
            $overallSuccess = $false
        }
    }

    if ($overallSuccess) {
        Write-DevLog "Operation completed successfully" "SUCCESS"
        exit 0
    } else {
        Write-DevLog "Operation completed with errors" "ERROR"
        exit 1
    }
}

# Execute main function
Main
