#Requires -Version 5.1
<#
.SYNOPSIS
    Setup Git configuration symbolic links to manage all Git configs in dotfiles repository

.DESCRIPTION
    This script will:
    1. Backup existing global Git configuration files
    2. Create symbolic links from system locations to dotfiles repository config files
    3. Ensure all Git configurations are managed by dotfiles repository

.PARAMETER Force
    Force overwrite existing files and links

.PARAMETER Restore
    Restore original configuration files and remove symbolic links

.EXAMPLE
    .\Setup-GitSymlinks.ps1
    Setup Git configuration symbolic links

.EXAMPLE
    .\Setup-GitSymlinks.ps1 -Force
    Force setup symbolic links, overwrite existing files

.EXAMPLE
    .\Setup-GitSymlinks.ps1 -Restore
    Restore original configurations and remove symbolic links

.NOTES
    Author: dotfiles project
    Version: 1.0
    Requires administrator privileges to create symbolic links
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Force overwrite existing files and links")]
    [switch]$Force,

    [Parameter(HelpMessage = "Restore original configuration files and remove symbolic links")]
    [switch]$Restore
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Define colors
$Colors = @{
    Success = 'Green'
    Warning = 'Yellow'
    Error   = 'Red'
    Info    = 'Cyan'
    Header  = 'Magenta'
}

# Get dotfiles root directory (parent of script directory)
$DotfilesRoot = Split-Path -Parent $PSScriptRoot
$GitConfigRoot = Join-Path $DotfilesRoot "git"

# Define file mapping relationships
$GitConfigMappings = @{
    # Global Git configuration file
    "$env:USERPROFILE\.gitconfig" = @{
        Source = Join-Path $GitConfigRoot "gitconfig"
        Backup = Join-Path $GitConfigRoot "gitconfig-backup"
    }

    # Local configuration file
    "$env:USERPROFILE\.gitconfig.local" = @{
        Source = Join-Path $GitConfigRoot ".gitconfig.local"
        Backup = Join-Path $GitConfigRoot ".gitconfig.local.backup"
    }

    # Commit message template
    "$env:USERPROFILE\.gitmessage" = @{
        Source = Join-Path $GitConfigRoot ".gitmessage"
        Backup = Join-Path $GitConfigRoot ".gitmessage.backup"
    }
}

function Write-ColorMessage {
    param(
        [string]$Message,
        [string]$Color = 'White',
        [switch]$NoNewline
    )

    if ($NoNewline) {
        Write-Host $Message -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Test-AdminRights {
    <#
    .SYNOPSIS
        Check if running with administrator privileges
    #>
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Backup-ExistingFile {
    param(
        [string]$FilePath,
        [string]$BackupPath
    )

    if (Test-Path $FilePath) {
        if (Test-Path $BackupPath) {
            if ($Force) {
                Remove-Item $BackupPath -Force
                Write-ColorMessage "  Removed existing backup: $BackupPath" $Colors.Warning
            } else {
                Write-ColorMessage "  Backup file already exists: $BackupPath" $Colors.Warning
                return $false
            }
        }

        Copy-Item $FilePath $BackupPath -Force
        Write-ColorMessage "  Backed up file: $FilePath -> $BackupPath" $Colors.Success
        return $true
    }

    return $false
}

function Create-SymbolicLink {
    param(
        [string]$LinkPath,
        [string]$TargetPath
    )

    try {
        # Remove existing file or link
        if (Test-Path $LinkPath) {
            Remove-Item $LinkPath -Force -ErrorAction Stop
        }

        # Create symbolic link
        New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath -Force | Out-Null
        Write-ColorMessage "  Created symbolic link: $LinkPath -> $TargetPath" $Colors.Success
        return $true
    }
    catch {
        Write-ColorMessage "  Failed to create symbolic link: $($_.Exception.Message)" $Colors.Error
        return $false
    }
}

function Restore-OriginalFile {
    param(
        [string]$LinkPath,
        [string]$BackupPath
    )

    # Remove symbolic link
    if (Test-Path $LinkPath) {
        Remove-Item $LinkPath -Force
        Write-ColorMessage "  Removed symbolic link: $LinkPath" $Colors.Info
    }

    # Restore backup file
    if (Test-Path $BackupPath) {
        Copy-Item $BackupPath $LinkPath -Force
        Write-ColorMessage "  Restored file: $BackupPath -> $LinkPath" $Colors.Success
        Remove-Item $BackupPath -Force
        Write-ColorMessage "  Deleted backup: $BackupPath" $Colors.Info
        return $true
    } else {
        Write-ColorMessage "  Backup file does not exist: $BackupPath" $Colors.Warning
        return $false
    }
}

function Setup-GitSymlinks {
    Write-ColorMessage "`n=== Git Configuration Symbolic Links Setup ===" $Colors.Header

    # Check administrator privileges
    if (-not (Test-AdminRights)) {
        Write-ColorMessage "`nWarning: Creating symbolic links may require administrator privileges" $Colors.Warning
        Write-ColorMessage "If you encounter permission errors, please run this script as administrator" $Colors.Warning
    }

    # Ensure source files exist
    $missingFiles = @()
    foreach ($mapping in $GitConfigMappings.GetEnumerator()) {
        $sourceFile = $mapping.Value.Source
        if (-not (Test-Path $sourceFile)) {
            $missingFiles += $sourceFile
        }
    }

    if ($missingFiles.Count -gt 0) {
        Write-ColorMessage "`nError: The following source files do not exist:" $Colors.Error
        $missingFiles | ForEach-Object { Write-ColorMessage "  - $_" $Colors.Error }
        Write-ColorMessage "Please ensure the dotfiles repository is complete" $Colors.Error
        return $false
    }

    $successCount = 0
    $totalCount = $GitConfigMappings.Count

    Write-ColorMessage "`nStarting symbolic link setup..." $Colors.Info

    foreach ($mapping in $GitConfigMappings.GetEnumerator()) {
        $linkPath = $mapping.Key
        $sourceFile = $mapping.Value.Source
        $backupFile = $mapping.Value.Backup

        Write-ColorMessage "`nProcessing file: $(Split-Path -Leaf $linkPath)" $Colors.Header

        # Backup existing file
        $backupSuccess = Backup-ExistingFile -FilePath $linkPath -BackupPath $backupFile

        # Create symbolic link
        if (Create-SymbolicLink -LinkPath $linkPath -TargetPath $sourceFile) {
            $successCount++
        }
    }

    # Summary
    Write-ColorMessage "`n=== Setup Complete ===" $Colors.Header
    Write-ColorMessage "Successfully setup: $successCount/$totalCount symbolic links" $Colors.Success

    if ($successCount -eq $totalCount) {
        Write-ColorMessage "`nAll Git configuration files are now managed by the dotfiles repository" $Colors.Success
        Write-ColorMessage "Configuration files location: $GitConfigRoot" $Colors.Info
        return $true
    } else {
        Write-ColorMessage "`nSome symbolic links failed to setup, please check permissions and file status" $Colors.Warning
        return $false
    }
}

function Restore-GitConfig {
    Write-ColorMessage "`n=== Restore Original Git Configuration ===" $Colors.Header

    $successCount = 0
    $totalCount = $GitConfigMappings.Count

    foreach ($mapping in $GitConfigMappings.GetEnumerator()) {
        $linkPath = $mapping.Key
        $backupFile = $mapping.Value.Backup

        Write-ColorMessage "`nRestoring file: $(Split-Path -Leaf $linkPath)" $Colors.Header

        if (Restore-OriginalFile -LinkPath $linkPath -BackupPath $backupFile) {
            $successCount++
        }
    }

    Write-ColorMessage "`n=== Restore Complete ===" $Colors.Header
    Write-ColorMessage "Successfully restored: $successCount/$totalCount files" $Colors.Success

    return ($successCount -eq $totalCount)
}

function Show-CurrentStatus {
    Write-ColorMessage "`n=== Git Configuration Status ===" $Colors.Header

    foreach ($mapping in $GitConfigMappings.GetEnumerator()) {
        $linkPath = $mapping.Key
        $sourceFile = $mapping.Value.Source
        $fileName = Split-Path -Leaf $linkPath

        Write-ColorMessage "`n$fileName" $Colors.Info
        Write-ColorMessage "  System location: $linkPath" $Colors.Info
        Write-ColorMessage "  Source file: $sourceFile" $Colors.Info

        if (Test-Path $linkPath) {
            try {
                $item = Get-Item $linkPath -ErrorAction Stop
                if ($item.LinkType -eq 'SymbolicLink') {
                    $target = $item.Target
                    if ($target -eq $sourceFile) {
                        Write-ColorMessage "  Status: ✓ Symbolic link correct" $Colors.Success
                    } else {
                        Write-ColorMessage "  Status: ⚠ Symbolic link target incorrect: $target" $Colors.Warning
                    }
                } else {
                    Write-ColorMessage "  Status: ⚠ Exists but not a symbolic link" $Colors.Warning
                }
            }
            catch {
                Write-ColorMessage "  Status: ❌ Check failed: $($_.Exception.Message)" $Colors.Error
            }
        } else {
            Write-ColorMessage "  Status: ❌ File does not exist" $Colors.Error
        }
    }
}

# Main function
function Main {
    Write-ColorMessage "Git Configuration Symbolic Links Management Tool" $Colors.Header
    Write-ColorMessage "Dotfiles root directory: $DotfilesRoot" $Colors.Info

    if ($Restore) {
        return Restore-GitConfig
    } elseif ($Force -or $PSBoundParameters.Count -eq 0) {
        return Setup-GitSymlinks
    } else {
        Show-CurrentStatus
        return $true
    }
}

# Execute main function
try {
    $success = Main

    if ($success) {
        Write-ColorMessage "`nOperation completed successfully!" $Colors.Success
        exit 0
    } else {
        Write-ColorMessage "`nOperation failed!" $Colors.Error
        exit 1
    }
}
catch {
    Write-ColorMessage "`nError occurred: $($_.Exception.Message)" $Colors.Error
    Write-ColorMessage "Error location: $($_.InvocationInfo.ScriptLineNumber):$($_.InvocationInfo.OffsetInLine)" $Colors.Error
    exit 1
}
