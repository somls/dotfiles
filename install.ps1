<#
.SYNOPSIS
    Deploy dotfiles from this repository to system using "copy install" as default method (optional symbolic links)

.DESCRIPTION
    This script provides complete dotfiles configuration deployment functionality, including:
    - Copy files to system configuration directories (default)
    - Optional creation of symbolic links to system configuration directories (when permissions/developer mode enabled)
    - Backup existing configuration files
    - Support selective installation of specific configuration types
    - Provide rollback and validation functionality
    - Interactive installation mode

.PARAMETER DryRun
    Preview mode, show operations to be performed but don't actually execute

.PARAMETER Type
    Only install specified types of configurations (e.g., PowerShell, Git, etc.)
    If not specified, will configure default components (Scoop, CMD, PowerShell, Starship, Git) and ask about other components

.PARAMETER Mode
    Installation mode: Copy (default) or Symlink

.PARAMETER Force
    Force overwrite existing files and links, even if target already exists

.PARAMETER Rollback
    Rollback to backup state, restore previous configuration

.PARAMETER Validate
    Validate correctness of existing symbolic links

.PARAMETER Interactive
    Interactive mode, confirm each operation individually

.PARAMETER BackupDir
    Backup directory path, defaults to .dotfiles-backup under user directory

.PARAMETER SetDevMode
    Enable developer mode, subsequent installations will default to symbolic links

.PARAMETER UnsetDevMode
    Disable developer mode, subsequent installations will default to copy mode

.EXAMPLE
    .\install.ps1
    Configure default components (Scoop, CMD, PowerShell, Starship, Git) and ask about other components

.EXAMPLE
    .\install.ps1 -Type PowerShell,Git,Neovim -Force
    Force install specified configurations

.EXAMPLE
    .\install.ps1 -Mode Symlink -Type PowerShell
    Install PowerShell configuration using symbolic links

.EXAMPLE
    .\install.ps1 -DryRun
    Preview what would be installed without making changes

.EXAMPLE
    .\install.ps1 -Rollback
    Restore previous configuration from backup

.EXAMPLE
    .\install.ps1 -Validate
    Check if existing symbolic links are correct
#>

param(
    [Parameter(ParameterSetName = 'Install')]
    [switch]$DryRun,

    [Parameter(ParameterSetName = 'Install')]
    [ValidateSet('PowerShell', 'Git', 'Starship', 'Scoop', 'Neovim', 'CMD', 'WindowsTerminal')]
    [string[]]$Type,

    [Parameter(ParameterSetName = 'Install')]
    [ValidateSet('Copy','Symlink')]
    [string]$Mode = 'Copy',

    [Parameter(ParameterSetName = 'Install')]
    [switch]$Force,

    [Parameter(ParameterSetName = 'Rollback', Mandatory)]
    [switch]$Rollback,

    [Parameter(ParameterSetName = 'Validate', Mandatory)]
    [switch]$Validate,

    [Parameter(ParameterSetName = 'Install')]
    [switch]$Interactive,

    [Parameter(ParameterSetName = 'Install')]
    [ValidateScript({
        if (-not (Test-Path $_ -IsValid)) {
            throw "Invalid backup directory path: $_"
        }
        $true
    })]
    [string]$BackupDir = "$env:USERPROFILE\.dotfiles-backup",

    [Parameter(ParameterSetName = 'SetDevMode', Mandatory)]
    [switch]$SetDevMode,

    [Parameter(ParameterSetName = 'UnsetDevMode', Mandatory)]
    [switch]$UnsetDevMode
)

# Define default installation applications (core tools)
$script:DefaultComponents = @('Scoop', 'CMD', 'PowerShell', 'Starship', 'Git', 'WindowsTerminal')

# Read user configuration file first (takes effect when parameters not explicitly passed)
# Note: Configuration file reading is temporarily disabled due to JSON format issues
# The script will use built-in defaults instead
try {
    $configPath = Join-Path $PSScriptRoot 'config/install.json'
    if ($false -and (Test-Path $configPath)) {  # Temporarily disabled
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        # Only apply configuration defaults when not specified via CLI
        if (-not $PSBoundParameters.ContainsKey('Mode') -and $cfg.DefaultMode) {
            $Mode = $cfg.DefaultMode
        }
        if (-not $PSBoundParameters.ContainsKey('Type') -and $cfg.DefaultComponents) {
            $Type = $cfg.DefaultComponents
        }
    }
} catch {
    Write-Warning "Failed to read configuration file: $($_.Exception.Message)"
}

# Global variables
$script:SourceDir = $PSScriptRoot
$script:BackupDir = $BackupDir
$script:InstallResults = @{
    Success = @()
    Failed = @()
    Skipped = @()
}

# Initialize log file
$script:LogFile = Join-Path $script:SourceDir "install.log"

# Installation mode parsing (default copy, developers can choose symbolic links)
# Rules:
# 1) Explicit -Mode parameter has highest priority
# 2) Otherwise if environment variable DOTFILES_DEV_MODE=true/1/yes or ~/.dotfiles.dev-mode marker file exists, use Symlink (dev mode)
# 3) Otherwise default Copy (production mode)
$script:EffectiveMode = 'Copy'
$script:IsDevMode = $false

if ($PSBoundParameters.ContainsKey('Mode')) {
    $script:EffectiveMode = $Mode
    Write-Host "[INFO] Using explicit mode parameter: $Mode" -ForegroundColor Cyan
} else {
    # Check environment variable
    $envDevMode = $env:DOTFILES_DEV_MODE
    if ($envDevMode -in @('true', '1', 'yes', 'on')) {
        $script:EffectiveMode = 'Symlink'
        $script:IsDevMode = $true
        Write-Host "[INFO] Developer mode detected via environment variable" -ForegroundColor Yellow
    } else {
        # Check marker file
        $devModeFile = Join-Path $env:USERPROFILE '.dotfiles.dev-mode'
        if (Test-Path $devModeFile) {
            $script:EffectiveMode = 'Symlink'
            $script:IsDevMode = $true
            Write-Host "[INFO] Developer mode detected via marker file" -ForegroundColor Yellow
        } else {
            Write-Host "[INFO] Production mode, will use copy configuration" -ForegroundColor Cyan
        }
    }
}

$modeDesc = if ($script:EffectiveMode -eq 'Symlink') { "Symbolic Links" } else { "File Copy" }
Write-Host "[INFO] Configuration mode: $script:EffectiveMode - $modeDesc" -ForegroundColor Green

# Logging function
function Write-InstallLog {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,
        
        [Parameter(Position = 1)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$Level = "INFO",
        
        [System.Exception]$Exception = $null
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    
    if ($Exception) {
        $logEntry += " | Exception: $($Exception.Message)"
        if ($Exception.InnerException) {
            $logEntry += " | Inner: $($Exception.InnerException.Message)"
        }
    }

    # Write to log file
    try {
        Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {
        # Continue if unable to write to log file
    }

    # Console output with colors and icons
    if (-not $DryRun -or $Level -in @('ERROR', 'WARN')) {
        $colorMap = @{
            "INFO"    = "White"
            "WARN"    = "Yellow"
            "ERROR"   = "Red"
            "SUCCESS" = "Green"
            "DEBUG"   = "Gray"
        }

        $iconMap = @{
            "INFO"    = "[INFO]"
            "WARN"    = "[WARN]"
            "ERROR"   = "[ERROR]"
            "SUCCESS" = "[SUCCESS]"
            "DEBUG"   = "[DEBUG]"
        }

        $color = $colorMap[$Level]
        if (-not $color) { $color = "White" }
        
        $icon = $iconMap[$Level]
        if (-not $icon) { $icon = "[INFO]" }

        Write-Host "$icon $Message" -ForegroundColor $color
    }
}

# Platform compatibility check
function Test-PlatformCompatibility {
    Write-InstallLog "Checking platform compatibility..." "INFO"
    
    if ($PSVersionTable.Platform -and $PSVersionTable.Platform -ne 'Win32NT') {
        Write-InstallLog "This script is designed for Windows only. Current platform: $($PSVersionTable.Platform)" "ERROR"
        return $false
    }

    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-InstallLog "PowerShell 5.0 or higher required. Current version: $($PSVersionTable.PSVersion)" "ERROR"
        return $false
    }

    Write-InstallLog "Platform compatibility check passed: Windows PowerShell $($PSVersionTable.PSVersion)" "SUCCESS"
    return $true
}

# Administrator permission check
function Test-AdminPermission {
    Write-InstallLog "Checking administrator permissions..." "INFO"
    
    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($script:EffectiveMode -eq 'Symlink') {
            if ($isAdmin) {
                Write-InstallLog "Administrator permission check passed" "SUCCESS"
                return $true
            } else {
                Write-InstallLog "Symbolic link mode requires administrator permissions" "WARN"
                
                # Ask user if they want to continue with copy mode
                $choices = @(
                    [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "Continue with copy mode")
                    [System.Management.Automation.Host.ChoiceDescription]::new("&No", "Exit script")
                )
                
                $decision = $Host.UI.PromptForChoice(
                    "Permission Required",
                    "Symbolic link mode requires administrator permissions. Continue with copy mode instead?",
                    $choices,
                    0
                )
                
                if ($decision -eq 0) {
                    $script:EffectiveMode = 'Copy'
                    Write-InstallLog "Switched to copy mode due to insufficient permissions" "INFO"
                    return $true
                } else {
                    Write-InstallLog "User chose to exit due to insufficient permissions" "INFO"
                    return $false
                }
            }
        } else {
            # Copy mode doesn't require admin permissions
            Write-InstallLog "Copy mode - administrator permissions not required" "INFO"
            return $true
        }
    } catch {
        Write-InstallLog "Failed to check administrator permissions" "ERROR" -Exception $_
        return $false
    }
}

# Backup existing files
function Backup-ExistingFile {
    param(
        [string]$FilePath,
        [string]$BackupDir
    )

    if (-not (Test-Path $FilePath)) {
        return $true
    }

    try {
        if (-not (Test-Path $BackupDir)) {
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
            Write-InstallLog "Created backup directory: $BackupDir" "INFO"
        }

        $relativePath = $FilePath.Replace($env:USERPROFILE, '').TrimStart('\')
        $backupPath = Join-Path $BackupDir $relativePath
        $backupParentDir = Split-Path $backupPath -Parent

        if (-not (Test-Path $backupParentDir)) {
            New-Item -ItemType Directory -Path $backupParentDir -Force | Out-Null
        }

        Copy-Item $FilePath $backupPath -Force -Recurse
        Write-InstallLog "Backed up: $relativePath" "INFO"
        return $true
    } catch {
        Write-InstallLog "Failed to backup $FilePath" "ERROR" -Exception $_
        return $false
    }
}

# Rollback functionality
function Start-Rollback {
    Write-InstallLog "Starting rollback process..." "INFO"
    
    if (-not (Test-Path $script:BackupDir)) {
        Write-InstallLog "Backup directory not found: $script:BackupDir" "ERROR"
        return $false
    }

    $backupFiles = Get-ChildItem $script:BackupDir -Recurse -File
    $rolledBack = 0

    foreach ($backupFile in $backupFiles) {
        try {
            $relativePath = $backupFile.FullName.Replace($script:BackupDir, '').TrimStart('\')
            $originalPath = Join-Path $env:USERPROFILE $relativePath

            $originalDir = Split-Path $originalPath -Parent
            if (-not (Test-Path $originalDir)) {
                New-Item -ItemType Directory -Path $originalDir -Force | Out-Null
            }

            Copy-Item $backupFile.FullName $originalPath -Force
            Write-InstallLog "Restored: $relativePath" "SUCCESS"
            $rolledBack++
        } catch {
            Write-InstallLog "Failed to restore $($backupFile.FullName)" "ERROR" -Exception $_
        }
    }

    Write-InstallLog "Rollback completed, restored $rolledBack files" "SUCCESS"
    return $true
}

# Validate symbolic links
function Test-SymbolicLinks {
    Write-InstallLog "Validating symbolic links..." "INFO"
    
    $validLinks = 0
    $invalidLinks = 0

    foreach ($linkPath in $links.Keys) {
        $linkConfig = $links[$linkPath]
        $target = $linkConfig.Target
        $source = Join-Path $script:SourceDir $linkPath

        if (Test-Path $target) {
            try {
                $item = Get-Item $target
                if ($item.LinkType -eq 'SymbolicLink') {
                    $actualTarget = $item.Target
                    $sourcePath = (Resolve-Path $source).Path
                    
                    if ($actualTarget -eq $sourcePath) {
                        Write-InstallLog "Valid link: $target -> $source" "SUCCESS"
                        $validLinks++
                    } else {
                        Write-InstallLog "Invalid link: $target -> $actualTarget (expected: $sourcePath)" "ERROR"
                        $invalidLinks++
                    }
                } else {
                    Write-InstallLog "Not a symbolic link: $target" "WARN"
                }
            } catch {
                Write-InstallLog "Failed to check link: $target" "ERROR" -Exception $_
                $invalidLinks++
            }
        }
    }

    Write-InstallLog "Link validation completed: $validLinks valid, $invalidLinks invalid" "INFO"
    return $invalidLinks -eq 0
}

# Get adaptive configuration paths
function Get-AdaptiveConfigPaths {
    Write-InstallLog "Detecting adaptive configuration paths..." -Level 'DEBUG'
    
    try {
        $paths = @{}

        # Windows Terminal path detection (enhanced with more paths)
        $wtPaths = @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState",
            "$env:LOCALAPPDATA\Microsoft\Windows Terminal",
            "$env:APPDATA\Microsoft\Windows Terminal"
        )

        $wtPath = $null
        foreach ($path in $wtPaths) {
            if (Test-Path $path) {
                $wtPath = $path.Replace($env:USERPROFILE + '\', '')
                Write-InstallLog "Found Windows Terminal directory: $wtPath" "DEBUG"
                break
            }
        }

        if (-not $wtPath) {
            $wtPath = $wtPaths[0].Replace($env:USERPROFILE + '\', '')  # Use first path as default
            Write-InstallLog "Windows Terminal installation not found, using default path: $wtPath" "WARN"
        }

        $paths["WindowsTerminal"] = $wtPath

        # PowerShell path detection (enhanced with version detection)
        $psVersion = $PSVersionTable.PSVersion.Major
        $psPath = if ($psVersion -ge 6) {
            "Documents\PowerShell"  # PowerShell Core/7+
        } else {
            "Documents\WindowsPowerShell"  # Windows PowerShell 5.x
        }

        # Verify PowerShell profile directory exists or can be created
        $fullPsPath = Join-Path $env:USERPROFILE $psPath
        if (-not (Test-Path $fullPsPath)) {
            Write-InstallLog "PowerShell profile directory does not exist, will be created: $fullPsPath" "INFO"
        }

        $paths["PowerShell"] = $psPath
        Write-InstallLog "PowerShell version: $($PSVersionTable.PSVersion), config path: $psPath" -Level 'INFO'

        # Scoop configuration path detection (enhanced)
        $scoopPath = if ($env:SCOOP) {
            # If SCOOP is under user directory, return relative path; otherwise return absolute path
            $scoopFull = $env:SCOOP
            if ($env:USERPROFILE -and $scoopFull -like "${env:USERPROFILE}\*") {
                $relativePath = $scoopFull.Substring($env:USERPROFILE.Length + 1)
                "$relativePath\.config\scoop"
            } else {
                # Absolute path, don't concatenate with $HOME later
                (Join-Path $scoopFull ".config\scoop")
            }
        } elseif (Test-Path "$env:USERPROFILE\scoop") {
            "scoop\.config\scoop"
        } elseif ($env:SCOOP_GLOBAL) {
            # Check for global Scoop installation
            Write-InstallLog "Global Scoop installation detected: $env:SCOOP_GLOBAL" "INFO"
            ".config\scoop"  # Use user config directory
        } else {
            ".config\scoop"  # Default path
        }

        $paths["Scoop"] = $scoopPath

        # Starship configuration path (enhanced)
        $starshipPaths = @(
            ".config",
            "AppData\Roaming"  # Alternative location
        )
        
        $starshipPath = ".config"  # Default
        foreach ($path in $starshipPaths) {
            $fullPath = Join-Path $env:USERPROFILE $path
            if (Test-Path $fullPath) {
                $starshipPath = $path
                break
            }
        }
        
        $paths["Starship"] = $starshipPath

        # Neovim configuration path (enhanced with multiple possible locations)
        $nvimPaths = @(
            "AppData\Local\nvim",
            ".config\nvim"  # Unix-style path on Windows
        )
        
        $nvimPath = "AppData\Local\nvim"  # Default
        foreach ($path in $nvimPaths) {
            $fullPath = Join-Path $env:USERPROFILE $path
            if (Test-Path $fullPath) {
                $nvimPath = $path
                Write-InstallLog "Found existing Neovim config: $fullPath" "DEBUG"
                break
            }
        }
        
        $paths["Neovim"] = $nvimPath

        # Git configuration (always in user home)
        $paths["Git"] = ""  # Empty means directly in user home

        Write-InstallLog "Adaptive path detection completed successfully" "SUCCESS"
        return $paths
    }
    catch {
        Write-InstallLog "Exception during path detection: $($_.Exception.Message)" "ERROR" -Exception $_.Exception
        # Return default path configuration
        return @{
            "WindowsTerminal" = "AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
            "PowerShell" = "Documents\PowerShell"
            "Scoop" = ".config\scoop"
            "Starship" = ".config"
            "Neovim" = "AppData\Local\nvim"
            "Git" = ""
        }
    }
}

# Get adaptive paths configuration
$adaptivePaths = Get-AdaptiveConfigPaths

# Define configuration files to link
# Use adaptive path configuration
$links = @{
    # Git - Force symbolic links to maintain repository configuration sync
    "git\gitconfig"        = @{ Target = ".gitconfig";        Type = "Git"; ForceSymlink = $true };
    "git\gitignore_global" = @{ Target = ".gitignore_global"; Type = "Git"; ForceSymlink = $true };
    "git\gitmessage"       = @{ Target = ".gitmessage";       Type = "Git"; ForceSymlink = $true };
    "git\gitconfig.d"      = @{ Target = ".gitconfig.d";      Type = "Git"; ForceSymlink = $true };

    # PowerShell
    "powershell\Microsoft.PowerShell_profile.ps1" = @{ Target = "$($adaptivePaths['PowerShell'])\Microsoft.PowerShell_profile.ps1"; Type = "PowerShell" };

    # Scoop (users need to copy from config.json.example and customize)
    # "scoop\config.json" = @{ Target = "$($adaptivePaths['Scoop'])\config.json"; Type = "Scoop"; ForceCopy = $true };

    # CMD aliases 已移除 - 简化项目结构

    # Windows Terminal
    "WindowsTerminal\settings.json" = @{ Target = "$($adaptivePaths['WindowsTerminal'])\settings.json"; Type = "WindowsTerminal" };

    # Starship
    "starship\starship.toml" = @{ Target = "$($adaptivePaths['Starship'])\starship.toml"; Type = "Starship" };

    # Neovim (Force symbolic link for entire configuration directory)
    "neovim" = @{ Target = "$($adaptivePaths['Neovim'])"; Type = "Neovim"; ForceSymlink = $true };
}

# Enhancement scripts list
$enhancementScripts = @{
}

# Rollback functionality
function Start-Rollback {
    Write-InstallLog "Starting rollback process..." "INFO"
    
    if (-not (Test-Path $script:BackupDir)) {
        Write-InstallLog "Backup directory not found: $script:BackupDir" "ERROR"
        return $false
    }

    $backupFiles = Get-ChildItem $script:BackupDir -Recurse -File
    $rolledBack = 0

    foreach ($backupFile in $backupFiles) {
        try {
            $relativePath = $backupFile.FullName.Replace($script:BackupDir, '').TrimStart('\')
            $originalPath = Join-Path $env:USERPROFILE $relativePath

            $originalDir = Split-Path $originalPath -Parent
            if (-not (Test-Path $originalDir)) {
                New-Item -ItemType Directory -Path $originalDir -Force | Out-Null
            }

            Copy-Item $backupFile.FullName $originalPath -Force
            Write-InstallLog "Restored: $relativePath" "SUCCESS"
            $rolledBack++
        } catch {
            Write-InstallLog "Failed to restore $($backupFile.FullName)" "ERROR" -Exception $_
        }
    }

    Write-InstallLog "Rollback completed, restored $rolledBack files" "SUCCESS"
    return $true
}

# Create symbolic link
function New-SymbolicLinkSafe {
    param(
        [string]$LinkPath,
        [string]$TargetPath
    )

    try {
        # Ensure parent directory exists
        $parentDir = Split-Path $LinkPath -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        # Remove existing item if it exists
        if (Test-Path $LinkPath) {
            Remove-Item $LinkPath -Force -Recurse
        }

        # Create symbolic link
        New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath -Force | Out-Null
        return @{ Success = $true; Message = "Symbolic link created successfully" }
    } catch {
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

# Copy file safely
function Copy-FileSafe {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )

    try {
        # Ensure parent directory exists
        $parentDir = Split-Path $DestinationPath -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        # Copy file or directory
        if (Test-Path $SourcePath -PathType Container) {
            Copy-Item $SourcePath $DestinationPath -Recurse -Force
        } else {
            Copy-Item $SourcePath $DestinationPath -Force
        }
        
        return @{ Success = $true; Message = "File copied successfully" }
    } catch {
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

# Install configuration
function Install-Configuration {
    param(
        [string]$SourcePath,
        [string]$TargetPath,
        [string]$ComponentType,
        [hashtable]$Config
    )

    Write-InstallLog "Installing $ComponentType..." "INFO"

    # Check if source exists
    if (-not (Test-Path $SourcePath)) {
        Write-InstallLog "Source not found: $SourcePath" "ERROR"
        $script:InstallResults.Failed += "$ComponentType - Source not found"
        return $false
    }

    # Determine target path (handle relative paths)
    $fullTargetPath = if ([System.IO.Path]::IsPathRooted($TargetPath)) {
        $TargetPath
    } else {
        Join-Path $env:USERPROFILE $TargetPath
    }

    # Backup existing configuration
    if (Test-Path $fullTargetPath) {
        if (-not (Backup-ExistingFile $fullTargetPath $script:BackupDir)) {
            Write-InstallLog "Failed to backup existing configuration for $ComponentType" "ERROR"
            $script:InstallResults.Failed += "$ComponentType - Backup failed"
            return $false
        }
    }

    # Determine installation method
    $useSymlink = $false
    if ($Config.ForceSymlink -eq $true) {
        $useSymlink = $true
        Write-InstallLog "$ComponentType requires symbolic links" "INFO"
    } elseif ($Config.ForceCopy -eq $true) {
        $useSymlink = $false
        Write-InstallLog "$ComponentType requires file copy" "INFO"
    } else {
        $useSymlink = ($script:EffectiveMode -eq 'Symlink')
    }

    # Check for existing symbolic link
    if (Test-Path $fullTargetPath) {
        try {
            $item = Get-Item $fullTargetPath
            if ($item.LinkType -eq 'SymbolicLink') {
                $sourcePath = (Resolve-Path $SourcePath).Path
                if ($item.Target -eq $sourcePath) {
                    Write-InstallLog "$ComponentType link already exists and is correct" "SUCCESS"
                    $script:InstallResults.Success += "$ComponentType - Already exists"
                    return $true
                }
            }
        } catch {
            # Continue with installation
        }
    }

    # Perform installation
    if ($useSymlink) {
        $linkResult = New-SymbolicLinkSafe -LinkPath $fullTargetPath -TargetPath $SourcePath
        if ($linkResult.Success) {
            Write-InstallLog "$ComponentType symbolic link created successfully" "SUCCESS"
            $script:InstallResults.Success += "$ComponentType"
            return $true
        } else {
            Write-InstallLog "Failed to create symbolic link for $ComponentType`: $($linkResult.Message)" "ERROR"
            $script:InstallResults.Failed += "$ComponentType - Symlink failed"
            return $false
        }
    } else {
        $copyResult = Copy-FileSafe -SourcePath $SourcePath -DestinationPath $fullTargetPath
        if ($copyResult.Success) {
            Write-InstallLog "$ComponentType copy successful" "SUCCESS"
            $script:InstallResults.Success += "$ComponentType"
            return $true
        } else {
            Write-InstallLog "Failed to copy $ComponentType`: $($copyResult.Message)" "ERROR"
            $script:InstallResults.Failed += "$ComponentType - Copy failed"
            return $false
        }
    }
}

# Main installation logic
function Start-Installation {
    Write-InstallLog "Starting dotfiles installation..." "INFO"
    Write-InstallLog "Source directory: $script:SourceDir" "INFO"
    Write-InstallLog "Backup directory: $script:BackupDir" "INFO"
    Write-InstallLog "Installation mode: $script:EffectiveMode" "INFO"

    $totalItems = 0
    $processedItems = 0

    # Filter links based on Type parameter
    $linksToProcess = if ($Type) {
        $links.GetEnumerator() | Where-Object { $_.Value.Type -in $Type }
    } else {
        # If no Type specified, process default components and ask about optional ones
        $defaultLinks = $links.GetEnumerator() | Where-Object { $_.Value.Type -in $script:DefaultComponents }
        
        if (-not $DryRun -and -not $Interactive) {
            # Ask about optional components
            $optionalComponents = @('Neovim')
            $optionalLinks = $links.GetEnumerator() | Where-Object { $_.Value.Type -in $optionalComponents }
            
            if ($optionalLinks) {
                Write-Host "`nOptional components available:" -ForegroundColor Yellow
                foreach ($component in $optionalComponents) {
                    $description = switch ($component) {
                        'Neovim' { 'Neovim Editor' }
                        default { $component }
                    }
                    Write-Host "  - $description" -ForegroundColor Gray
                }
                
                $choices = @(
                    [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "Install optional components")
                    [System.Management.Automation.Host.ChoiceDescription]::new("&No", "Skip optional components")
                )
                
                $decision = $Host.UI.PromptForChoice(
                    "Optional Components",
                    "Do you want to install optional components?",
                    $choices,
                    1  # Default to No
                )
                
                if ($decision -eq 0) {
                    $defaultLinks + $optionalLinks
                } else {
                    $defaultLinks
                }
            } else {
                $defaultLinks
            }
        } else {
            $defaultLinks
        }
    }

    $totalItems = $linksToProcess.Count
    Write-InstallLog "Processing $totalItems configuration items..." "INFO"

    foreach ($linkEntry in $linksToProcess) {
        $sourcePath = Join-Path $script:SourceDir $linkEntry.Key
        $targetPath = $linkEntry.Value.Target
        $componentType = $linkEntry.Value.Type
        $config = $linkEntry.Value

        $processedItems++
        Write-InstallLog "[$processedItems/$totalItems] Processing $componentType..." "INFO"

        if ($Interactive) {
            $choices = @(
                [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "Install this component")
                [System.Management.Automation.Host.ChoiceDescription]::new("&No", "Skip this component")
                [System.Management.Automation.Host.ChoiceDescription]::new("&All", "Install all remaining components")
            )
            
            $decision = $Host.UI.PromptForChoice(
                "Install Component",
                "Install $componentType configuration?",
                $choices,
                0
            )
            
            switch ($decision) {
                0 { # Yes
                    Install-Configuration -SourcePath $sourcePath -TargetPath $targetPath -ComponentType $componentType -Config $config
                }
                1 { # No
                    Write-InstallLog "Skipped $componentType (user choice)" "INFO"
                    $script:InstallResults.Skipped += $componentType
                }
                2 { # All
                    $Interactive = $false
                    Install-Configuration -SourcePath $sourcePath -TargetPath $targetPath -ComponentType $componentType -Config $config
                }
            }
        } else {
            if ($DryRun) {
                Write-InstallLog "[DRY RUN] Would install $componentType`: $sourcePath -> $targetPath" "INFO"
            } else {
                Install-Configuration -SourcePath $sourcePath -TargetPath $targetPath -ComponentType $componentType -Config $config
            }
        }
    }

    # Summary
    Write-InstallLog "Installation completed!" "SUCCESS"
    Write-InstallLog "Successful: $($script:InstallResults.Success.Count)" "SUCCESS"
    Write-InstallLog "Failed: $($script:InstallResults.Failed.Count)" "ERROR"
    Write-InstallLog "Skipped: $($script:InstallResults.Skipped.Count)" "INFO"

    if ($script:InstallResults.Success.Count -gt 0) {
        Write-InstallLog "Successfully installed: $($script:InstallResults.Success -join ', ')" "SUCCESS"
    }
    if ($script:InstallResults.Failed.Count -gt 0) {
        Write-InstallLog "Failed to install: $($script:InstallResults.Failed -join ', ')" "ERROR"
    }
    if ($script:InstallResults.Skipped.Count -gt 0) {
        Write-InstallLog "Skipped: $($script:InstallResults.Skipped -join ', ')" "INFO"
    }

    return $script:InstallResults.Failed.Count -eq 0
}

# Developer mode management
function Set-DeveloperMode {
    param([bool]$Enable)
    
    $devModeFile = Join-Path $env:USERPROFILE '.dotfiles.dev-mode'
    
    if ($Enable) {
        try {
            "# Dotfiles developer mode enabled`n# This file enables symbolic link mode by default`n# Created: $(Get-Date)" | Out-File $devModeFile -Encoding UTF8
            Write-InstallLog "Developer mode enabled. Future installations will use symbolic links by default." "SUCCESS"
            Write-InstallLog "Marker file created: $devModeFile" "INFO"
        } catch {
            Write-InstallLog "Failed to enable developer mode" "ERROR" -Exception $_
            return $false
        }
    } else {
        try {
            if (Test-Path $devModeFile) {
                Remove-Item $devModeFile -Force
                Write-InstallLog "Developer mode disabled. Future installations will use copy mode by default." "SUCCESS"
                Write-InstallLog "Marker file removed: $devModeFile" "INFO"
            } else {
                Write-InstallLog "Developer mode was not enabled" "INFO"
            }
        } catch {
            Write-InstallLog "Failed to disable developer mode" "ERROR" -Exception $_
            return $false
        }
    }
    
    return $true
}

# Main execution
try {
    # Handle developer mode management
    if ($SetDevMode) {
        $result = Set-DeveloperMode $true
        if ($result) { exit 0 } else { exit 1 }
    }
    
    if ($UnsetDevMode) {
        $result = Set-DeveloperMode $false
        if ($result) { exit 0 } else { exit 1 }
    }

    # Platform compatibility check
    if (-not (Test-PlatformCompatibility)) {
        exit 1
    }

    # Permission check
    if (-not (Test-AdminPermission)) {
        exit 1
    }

    # Handle different operation modes
    if ($Rollback) {
        $success = Start-Rollback
        if ($success) { exit 0 } else { exit 1 }
    }

    if ($Validate) {
        $success = Test-SymbolicLinks
        if ($success) { exit 0 } else { exit 1 }
    }

    # Main installation
    $success = Start-Installation
    if ($success) { exit 0 } else { exit 1 }

} catch {
    Write-InstallLog "Unexpected error during execution: $($_.Exception.Message)" "ERROR" -Exception $_
    exit 1
}