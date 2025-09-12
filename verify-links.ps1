<#
.SYNOPSIS
    Verify and manage symbolic links for dotfiles configurations

.DESCRIPTION
    This script provides comprehensive symbolic link management for your dotfiles system:
    - Verify existing symbolic links and their validity
    - Force create/recreate symbolic links between repository and system configurations
    - Detailed reporting of link status and issues
    - Backup existing configurations before making changes
    - Support for selective link management by configuration type

.PARAMETER Verify
    Check the status of existing symbolic links without making changes

.PARAMETER ForceLink
    Force create/recreate symbolic links, overwriting existing files/links

.PARAMETER Type
    Specify configuration types to process (PowerShell, Git, Starship, etc.)
    If not specified, processes all available configurations

.PARAMETER Backup
    Create backup of existing configurations before making changes (default: true)

.PARAMETER BackupDir
    Directory to store backups (default: ~/.dotfiles-backup-links)

.PARAMETER Detailed
    Show detailed output including file paths and link targets

.PARAMETER DryRun
    Preview what would be done without making actual changes

.PARAMETER Interactive
    Ask for confirmation before each link operation

.EXAMPLE
    .\verify-links.ps1 -Verify
    Check the status of all existing symbolic links

.EXAMPLE
    .\verify-links.ps1 -ForceLink -Type Git,PowerShell
    Force recreate symbolic links for Git and PowerShell configurations

.EXAMPLE
    .\verify-links.ps1 -ForceLink -DryRun
    Preview what links would be created without making changes

.EXAMPLE
    .\verify-links.ps1 -Verify -Detailed
    Show detailed information about all symbolic links

.EXAMPLE
    .\verify-links.ps1 -ForceLink -Interactive
    Interactively create symbolic links with confirmation prompts
#>

param(
    [Parameter(ParameterSetName = 'Verify', Mandatory)]
    [switch]$Verify,

    [Parameter(ParameterSetName = 'ForceLink', Mandatory)]
    [switch]$ForceLink,

    [ValidateSet('PowerShell', 'Git', 'Starship', 'Scoop', 'Neovim', 'CMD', 'WindowsTerminal')]
    [string[]]$Type,

    [switch]$NoBackup,

    [string]$BackupDir = "$env:USERPROFILE\.dotfiles-backup-links",

    [switch]$Detailed,

    [switch]$DryRun,

    [switch]$Interactive
)

# Initialize script variables
$script:ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ConfigsDir = Join-Path $script:ScriptRoot "configs"
$script:BackupDir = $BackupDir
$script:Results = @{
    Valid = @()
    Invalid = @()
    Missing = @()
    Created = @()
    Failed = @()
    Skipped = @()
}

# Color and formatting functions
function Write-ColoredOutput {
    param(
        [string]$Text,
        [string]$Color = 'White',
        [string]$Prefix = '',
        [switch]$NoNewline
    )

    if ($Prefix) {
        Write-Host $Prefix -ForegroundColor $Color -NoNewline
        Write-Host " $Text" -ForegroundColor White -NoNewline:$NoNewline
    } else {
        Write-Host $Text -ForegroundColor $Color -NoNewline:$NoNewline
    }
}

function Write-Success { param([string]$Text) Write-ColoredOutput $Text 'Green' '[✓]' }
function Write-Error { param([string]$Text) Write-ColoredOutput $Text 'Red' '[✗]' }
function Write-Warning { param([string]$Text) Write-ColoredOutput $Text 'Yellow' '[!]' }
function Write-Info { param([string]$Text) Write-ColoredOutput $Text 'Cyan' '[i]' }
function Write-Header {
    param([string]$Text)
    Write-Host "`n" -NoNewline
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
}

# Get adaptive configuration paths (copied from install.ps1)
function Get-AdaptiveConfigPaths {
    try {
        Write-Verbose "Detecting adaptive configuration paths..."
        $paths = @{}

        # Windows Terminal path detection
        $wtPaths = @(
            "AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState",
            "AppData\Local\Microsoft\Windows Terminal"
        )

        $wtPath = "AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
        foreach ($path in $wtPaths) {
            $fullPath = Join-Path $env:USERPROFILE $path
            if (Test-Path $fullPath) {
                $wtPath = $path
                Write-Verbose "Found Windows Terminal directory: $fullPath"
                break
            }
        }
        $paths["WindowsTerminal"] = $wtPath

        # PowerShell path detection (version-dependent)
        $psVersion = $PSVersionTable.PSVersion.Major
        if ($psVersion -ge 6) {
            $paths["PowerShell"] = "Documents\PowerShell"
            Write-Verbose "PowerShell version: $($PSVersionTable.PSVersion), config path: Documents\PowerShell"
        } else {
            $paths["PowerShell"] = "Documents\WindowsPowerShell"
            Write-Verbose "PowerShell version: $($PSVersionTable.PSVersion), config path: Documents\WindowsPowerShell"
        }

        # Scoop configuration path
        $paths["Scoop"] = ".config\scoop"

        # Starship configuration path
        $paths["Starship"] = ".config"

        # Neovim configuration path
        $nvimPaths = @(
            "AppData\Local\nvim",
            ".config\nvim"
        )

        $nvimPath = "AppData\Local\nvim"
        foreach ($path in $nvimPaths) {
            $fullPath = Join-Path $env:USERPROFILE $path
            if (Test-Path $fullPath) {
                $nvimPath = $path
                Write-Verbose "Found existing Neovim config: $fullPath"
                break
            }
        }
        $paths["Neovim"] = $nvimPath

        # Git configuration (always in user home)
        $paths["Git"] = ""

        Write-Verbose "Adaptive path detection completed successfully"
        return $paths
    }
    catch {
        Write-Error "Exception during path detection: $($_.Exception.Message)"
        # Return default paths
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

# Get configuration mappings
function Get-ConfigurationMappings {
    $adaptivePaths = Get-AdaptiveConfigPaths

    return @{
        # Git configurations - Force symbolic links to maintain repository sync
        "configs\git\gitconfig" = @{
            Target = ".gitconfig"
            Type = "Git"
            ForceSymlink = $true
            Description = "Git configuration file"
        }
        "configs\git\gitignore_global" = @{
            Target = ".gitignore_global"
            Type = "Git"
            ForceSymlink = $true
            Description = "Global Git ignore patterns"
        }
        "configs\git\gitmessage" = @{
            Target = ".gitmessage"
            Type = "Git"
            ForceSymlink = $true
            Description = "Git commit message template"
        }
        "configs\git\gitconfig.d" = @{
            Target = ".gitconfig.d"
            Type = "Git"
            ForceSymlink = $true
            Description = "Git configuration includes directory"
        }

        # PowerShell
        "configs\powershell\Microsoft.PowerShell_profile.ps1" = @{
            Target = "$($adaptivePaths['PowerShell'])\Microsoft.PowerShell_profile.ps1"
            Type = "PowerShell"
            Description = "PowerShell profile script"
        }

        # Windows Terminal
        "configs\WindowsTerminal\settings.json" = @{
            Target = "$($adaptivePaths['WindowsTerminal'])\settings.json"
            Type = "WindowsTerminal"
            Description = "Windows Terminal settings"
        }

        # Starship
        "configs\starship\starship.toml" = @{
            Target = "$($adaptivePaths['Starship'])\starship.toml"
            Type = "Starship"
            Description = "Starship prompt configuration"
        }

        # Neovim (Force symbolic link for entire configuration directory)
        "configs\neovim" = @{
            Target = "$($adaptivePaths['Neovim'])"
            Type = "Neovim"
            ForceSymlink = $true
            Description = "Neovim configuration directory"
        }
    }
}

# Check if path is a symbolic link and get its target
function Get-SymbolicLinkInfo {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return @{ Exists = $false; IsSymlink = $false; Target = $null }
    }

    try {
        $item = Get-Item $Path -Force
        $isSymlink = $item.LinkType -eq 'SymbolicLink'
        $target = if ($isSymlink) { $item.Target } else { $null }

        return @{
            Exists = $true
            IsSymlink = $isSymlink
            Target = $target
            FullPath = $item.FullName
        }
    }
    catch {
        return @{ Exists = $false; IsSymlink = $false; Target = $null; Error = $_.Exception.Message }
    }
}

# Backup existing file or directory
function Backup-ExistingItem {
    param(
        [string]$ItemPath,
        [string]$BackupDirectory
    )

    if (-not (Test-Path $ItemPath)) {
        return $true
    }

    try {
        if (-not (Test-Path $BackupDirectory)) {
            New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
            Write-Info "Created backup directory: $BackupDirectory"
        }

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $itemName = Split-Path $ItemPath -Leaf
        $backupName = "${itemName}.backup-${timestamp}"
        $backupPath = Join-Path $BackupDirectory $backupName

        if (Test-Path $ItemPath -PathType Container) {
            Copy-Item $ItemPath $backupPath -Recurse -Force
        } else {
            Copy-Item $ItemPath $backupPath -Force
        }

        Write-Info "Backed up to: $backupPath"
        return $true
    }
    catch {
        Write-Error "Failed to backup $ItemPath`: $($_.Exception.Message)"
        return $false
    }
}

# Create symbolic link safely
function New-SymbolicLinkSafe {
    param(
        [string]$LinkPath,
        [string]$TargetPath,
        [switch]$Force
    )

    try {
        # Resolve full paths
        $fullTargetPath = Resolve-Path $TargetPath -ErrorAction Stop

        # Ensure parent directory exists
        $parentDir = Split-Path $LinkPath -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            Write-Info "Created directory: $parentDir"
        }

        # Handle existing item
        if (Test-Path $LinkPath) {
            if ($Force) {
                Remove-Item $LinkPath -Force -Recurse
                Write-Info "Removed existing item: $LinkPath"
            } else {
                throw "Target already exists and -Force not specified"
            }
        }

        # Create symbolic link
        $linkItem = New-Item -ItemType SymbolicLink -Path $LinkPath -Target $fullTargetPath -Force

        return @{
            Success = $true
            Message = "Symbolic link created successfully"
            LinkPath = $linkItem.FullName
            Target = $fullTargetPath.Path
        }
    }
    catch {
        return @{
            Success = $false
            Message = $_.Exception.Message
            LinkPath = $LinkPath
            Target = $TargetPath
        }
    }
}

# Verify symbolic links
function Invoke-SymbolicLinkVerification {
    Write-Header "🔍 Verifying Symbolic Links"

    $configMappings = Get-ConfigurationMappings

    # Filter by type if specified
    $configurationsToCheck = if ($Type) {
        $configMappings.GetEnumerator() | Where-Object { $_.Value.Type -in $Type }
    } else {
        $configMappings.GetEnumerator()
    }

    Write-Info "Checking $($configurationsToCheck.Count) configuration(s)..."
    Write-Host ""

    foreach ($config in $configurationsToCheck) {
        $sourcePath = Join-Path $script:ScriptRoot $config.Key
        $targetPath = if ([System.IO.Path]::IsPathRooted($config.Value.Target)) {
            $config.Value.Target
        } else {
            Join-Path $env:USERPROFILE $config.Value.Target
        }

        $componentType = $config.Value.Type
        $description = $config.Value.Description

        Write-Host "[$componentType] " -ForegroundColor Yellow -NoNewline
        Write-Host $description -ForegroundColor White

        # Check source exists
        if (-not (Test-Path $sourcePath)) {
            Write-Error "  Source missing: $sourcePath"
            $script:Results.Missing += @{
                Type = $componentType
                Source = $sourcePath
                Target = $targetPath
                Issue = "Source missing"
            }
            continue
        }

        # Check target
        $linkInfo = Get-SymbolicLinkInfo $targetPath

        if (-not $linkInfo.Exists) {
            Write-Warning "  Target missing: $targetPath"
            $script:Results.Missing += @{
                Type = $componentType
                Source = $sourcePath
                Target = $targetPath
                Issue = "Target missing"
            }
        }
        elseif (-not $linkInfo.IsSymlink) {
            Write-Warning "  Not a symbolic link: $targetPath"
            $script:Results.Invalid += @{
                Type = $componentType
                Source = $sourcePath
                Target = $targetPath
                Issue = "Not a symbolic link"
            }
        }
        else {
            # Check if link target is correct
            $expectedTarget = (Resolve-Path $sourcePath).Path
            $actualTarget = $linkInfo.Target

            if ($actualTarget -eq $expectedTarget) {
                Write-Success "  Valid symbolic link"
                if ($Detailed) {
                    Write-Host "    Source: " -ForegroundColor Gray -NoNewline
                    Write-Host $sourcePath -ForegroundColor DarkGray
                    Write-Host "    Target: " -ForegroundColor Gray -NoNewline
                    Write-Host $targetPath -ForegroundColor DarkGray
                    Write-Host "    Points to: " -ForegroundColor Gray -NoNewline
                    Write-Host $actualTarget -ForegroundColor DarkGray
                }
                $script:Results.Valid += @{
                    Type = $componentType
                    Source = $sourcePath
                    Target = $targetPath
                }
            }
            else {
                Write-Error "  Invalid link target"
                if ($Detailed) {
                    Write-Host "    Expected: " -ForegroundColor Gray -NoNewline
                    Write-Host $expectedTarget -ForegroundColor DarkGray
                    Write-Host "    Actual: " -ForegroundColor Gray -NoNewline
                    Write-Host $actualTarget -ForegroundColor DarkGray
                }
                $script:Results.Invalid += @{
                    Type = $componentType
                    Source = $sourcePath
                    Target = $targetPath
                    Expected = $expectedTarget
                    Actual = $actualTarget
                    Issue = "Wrong target"
                }
            }
        }

        Write-Host ""
    }
}

# Force create symbolic links
function Invoke-ForceLinking {
    Write-Header "🔗 Force Creating Symbolic Links"

    $configMappings = Get-ConfigurationMappings

    # Filter by type if specified
    $configurationsToLink = if ($Type) {
        $configMappings.GetEnumerator() | Where-Object { $_.Value.Type -in $Type }
    } else {
        $configMappings.GetEnumerator()
    }

    Write-Info "Processing $($configurationsToLink.Count) configuration(s)..."

    if ($DryRun) {
        Write-Warning "DRY RUN MODE - No changes will be made"
    }

    Write-Host ""

    foreach ($config in $configurationsToLink) {
        $sourcePath = Join-Path $script:ScriptRoot $config.Key
        $targetPath = if ([System.IO.Path]::IsPathRooted($config.Value.Target)) {
            $config.Value.Target
        } else {
            Join-Path $env:USERPROFILE $config.Value.Target
        }

        $componentType = $config.Value.Type
        $description = $config.Value.Description

        Write-Host "[$componentType] " -ForegroundColor Yellow -NoNewline
        Write-Host $description -ForegroundColor White

        # Check if source exists
        if (-not (Test-Path $sourcePath)) {
            Write-Error "  Source not found: $sourcePath"
            $script:Results.Failed += @{
                Type = $componentType
                Source = $sourcePath
                Target = $targetPath
                Error = "Source not found"
            }
            continue
        }

        # Interactive confirmation
        if ($Interactive) {
            $choices = @(
                [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "Create symbolic link")
                [System.Management.Automation.Host.ChoiceDescription]::new("&No", "Skip this configuration")
                [System.Management.Automation.Host.ChoiceDescription]::new("&All", "Create all remaining links")
            )

            $decision = $Host.UI.PromptForChoice(
                "Create Symbolic Link",
                "Create symbolic link for $componentType configuration?`n  Source: $sourcePath`n  Target: $targetPath",
                $choices,
                0
            )

            switch ($decision) {
                0 {
                    # Yes - continue with creation
                }
                1 {
                    # No - skip
                    Write-Warning "  Skipped by user"
                    $script:Results.Skipped += $componentType
                    continue
                }
                2 {
                    # All - disable interactive mode
                    $Interactive = $false
                }
            }
        }

        if ($DryRun) {
            Write-Info "  Would create symbolic link:"
            Write-Host "    Source: " -ForegroundColor Gray -NoNewline
            Write-Host $sourcePath -ForegroundColor DarkGray
            Write-Host "    Target: " -ForegroundColor Gray -NoNewline
            Write-Host $targetPath -ForegroundColor DarkGray
            continue
        }

        # Backup existing target if it exists and backup is enabled
        if (-not $NoBackup -and (Test-Path $targetPath)) {
            Write-Info "  Backing up existing configuration..."
            if (-not (Backup-ExistingItem $targetPath $script:BackupDir)) {
                Write-Error "  Failed to backup, skipping..."
                $script:Results.Failed += @{
                    Type = $componentType
                    Source = $sourcePath
                    Target = $targetPath
                    Error = "Backup failed"
                }
                continue
            }
        }

        # Create symbolic link
        Write-Info "  Creating symbolic link..."
        $result = New-SymbolicLinkSafe -LinkPath $targetPath -TargetPath $sourcePath -Force

        if ($result.Success) {
            Write-Success "  Symbolic link created successfully"
            if ($Detailed) {
                Write-Host "    Link: " -ForegroundColor Gray -NoNewline
                Write-Host $result.LinkPath -ForegroundColor DarkGray
                Write-Host "    Target: " -ForegroundColor Gray -NoNewline
                Write-Host $result.Target -ForegroundColor DarkGray
            }
            $script:Results.Created += @{
                Type = $componentType
                Source = $sourcePath
                Target = $targetPath
            }
        } else {
            Write-Error "  Failed to create symbolic link: $($result.Message)"
            $script:Results.Failed += @{
                Type = $componentType
                Source = $sourcePath
                Target = $targetPath
                Error = $result.Message
            }
        }

        Write-Host ""
    }
}

# Display summary
function Show-Summary {
    Write-Header "📊 Summary"

    if ($Verify) {
        $total = $script:Results.Valid.Count + $script:Results.Invalid.Count + $script:Results.Missing.Count

        Write-Host "Link Verification Results:" -ForegroundColor White
        Write-Success "Valid links: $($script:Results.Valid.Count)"
        Write-Error "Invalid links: $($script:Results.Invalid.Count)"
        Write-Warning "Missing links: $($script:Results.Missing.Count)"
        Write-Host "Total checked: $total" -ForegroundColor Gray

        if ($script:Results.Invalid.Count -gt 0 -or $script:Results.Missing.Count -gt 0) {
            Write-Host "`nTo fix issues, run:" -ForegroundColor Yellow
            Write-Host "  .\verify-links.ps1 -ForceLink" -ForegroundColor Cyan
        }
    }

    if ($ForceLink) {
        $total = $script:Results.Created.Count + $script:Results.Failed.Count + $script:Results.Skipped.Count

        Write-Host "Link Creation Results:" -ForegroundColor White
        Write-Success "Created: $($script:Results.Created.Count)"
        Write-Error "Failed: $($script:Results.Failed.Count)"
        Write-Warning "Skipped: $($script:Results.Skipped.Count)"
        Write-Host "Total processed: $total" -ForegroundColor Gray

        if ($script:Results.Created.Count -gt 0) {
            Write-Host "`nSuccessfully created symbolic links for:" -ForegroundColor Green
            $script:Results.Created | ForEach-Object {
                Write-Host "  • $($_.Type)" -ForegroundColor Gray
            }
        }

        if ($script:Results.Failed.Count -gt 0) {
            Write-Host "`nFailed to create links for:" -ForegroundColor Red
            $script:Results.Failed | ForEach-Object {
                Write-Host "  • $($_.Type): $($_.Error)" -ForegroundColor Gray
            }
        }
    }

    if (-not $NoBackup -and (Get-ChildItem $script:BackupDir -ErrorAction SilentlyContinue)) {
        Write-Host "`nBackups stored in: $script:BackupDir" -ForegroundColor Gray
    }
}

# Main execution
try {
    Write-Header "🔗 Dotfiles Symbolic Link Manager"

    # Check if running in developer mode
    $devModeFile = Join-Path $script:ScriptRoot '.dotfiles.dev-mode'
    if (Test-Path $devModeFile) {
        Write-Info "Developer mode detected - symbolic links are preferred"
    } else {
        Write-Warning "Not in developer mode - consider enabling with: .\manage.ps1 install -SetDevMode"
    }

    Write-Host ""

    if ($Verify) {
        Invoke-SymbolicLinkVerification
    }
    elseif ($ForceLink) {
        Invoke-ForceLinking
    }

    Show-Summary

    # Exit with appropriate code
    $exitCode = if ($script:Results.Failed.Count -gt 0) { 1 } else { 0 }
    Write-Host ""
    exit $exitCode
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    exit 1
}
