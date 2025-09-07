# DotfilesUtilities.psm1
# Integrated utilities module - combines UI management and validation functionality
# Streamlined and efficient single module design

#Requires -Version 5.1

# Strict mode
Set-StrictMode -Version Latest

# ==================== Configuration and Constants ====================

# Color theme
$script:Colors = @{
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "Cyan"
    Debug = "Gray"
    Accent = "Magenta"
}

# Icon collection
$script:Icons = @{
    Success = "+"
    Error = "x"
    Warning = "!"
    Info = "."
    Check = "?"
    Time = "T"
}

# Validation result class
class ValidationResult {
    [string]$Component
    [bool]$IsValid
    [string]$Status
    [string]$Message
    [string]$Details
    [string]$Suggestion
    [hashtable]$Metadata
    [timespan]$Duration

    ValidationResult([string]$component) {
        $this.Component = $component
        $this.IsValid = $false
        $this.Status = "Unknown"
        $this.Message = ""
        $this.Details = ""
        $this.Suggestion = ""
        $this.Metadata = @{}
        $this.Duration = [timespan]::Zero
    }
}

# ==================== Output and UI Functions ====================

function Write-DotfilesMessage {
    <#
    .SYNOPSIS
        Unified message output function with color and icon support
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("Success", "Error", "Warning", "Info", "Debug")]
        [string]$Type = "Info",

        [switch]$NoNewLine,
        [switch]$NoIcon,
        [switch]$NoTimestamp
    )

    $color = $script:Colors[$Type]
    $icon = if ($NoIcon) { "" } else { "$($script:Icons[$Type]) " }
    $timestamp = if ($NoTimestamp) { "" } else { "[$(Get-Date -Format 'HH:mm:ss')] " }

    $output = "$timestamp$icon$Message"

    if ($NoNewLine) {
        Write-Host $output -ForegroundColor $color -NoNewline
    } else {
        Write-Host $output -ForegroundColor $color
    }
}

function Write-DotfilesHeader {
    <#
    .SYNOPSIS
        Display formatted header
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [string]$Subtitle = "",
        [string]$Separator = "="
    )

    $titleLength = $Title.Length
    $separatorLine = $Separator * [math]::Max($titleLength, 40)

    Write-Host ""
    Write-Host $separatorLine -ForegroundColor $script:Colors.Accent
    Write-Host $Title -ForegroundColor $script:Colors.Accent
    if ($Subtitle) {
        Write-Host $Subtitle -ForegroundColor $script:Colors.Info
    }
    Write-Host $separatorLine -ForegroundColor $script:Colors.Accent
    Write-Host ""
}

function Show-DotfilesProgress {
    <#
    .SYNOPSIS
        Display progress bar
    #>
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete = -1,
        [switch]$Completed
    )

    if ($Completed) {
        Write-Progress -Activity $Activity -Completed
    } else {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
    }
}

function Write-DotfilesSummary {
    <#
    .SYNOPSIS
        Display operation summary
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Summary
    )

    Write-DotfilesHeader -Title "Operation Summary"

    foreach ($key in $Summary.Keys) {
        $value = $Summary[$key]
        $type = switch ($key) {
            { $_ -match "Error|Failed" } { "Error" }
            { $_ -match "Warning" } { "Warning" }
            { $_ -match "Success|Passed" } { "Success" }
            default { "Info" }
        }

        Write-DotfilesMessage -Message "$key`: $value" -Type $type -NoTimestamp
    }
}

# ==================== Validation Functions ====================

function Test-DotfilesPath {
    <#
    .SYNOPSIS
        Validate if path exists and is accessible
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Type = "Any" # File, Directory, Any
    )

    try {
        if (-not (Test-Path $Path)) {
            return @{ IsValid = $false; Message = "Path does not exist" }
        }

        $item = Get-Item $Path -ErrorAction Stop

        switch ($Type) {
            "File" {
                if ($item.PSIsContainer) {
                    return @{ IsValid = $false; Message = "Expected file but found directory" }
                }
            }
            "Directory" {
                if (-not $item.PSIsContainer) {
                    return @{ IsValid = $false; Message = "Expected directory but found file" }
                }
            }
        }

        return @{
            IsValid = $true
            Message = "Path is valid"
            Item = $item
        }
    }
    catch {
        return @{ IsValid = $false; Message = "Cannot access path: $($_.Exception.Message)" }
    }
}

function Test-DotfilesJson {
    <#
    .SYNOPSIS
        Validate JSON file format
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        if (-not (Test-Path $Path)) {
            return @{ IsValid = $false; Message = "File does not exist" }
        }

        $content = Get-Content $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($content)) {
            return @{ IsValid = $false; Message = "File is empty" }
        }

        $jsonObject = $content | ConvertFrom-Json -ErrorAction Stop

        return @{
            IsValid = $true
            Message = "JSON format is valid"
            Object = $jsonObject
            Size = (Get-Item $Path).Length
        }
    }
    catch {
        return @{
            IsValid = $false
            Message = "JSON format error: $($_.Exception.Message)"
        }
    }
}

function Test-DotfilesPowerShell {
    <#
    .SYNOPSIS
        Validate PowerShell script syntax
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        $tokens = $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $Path, [ref]$tokens, [ref]$errors
        )

        if ($errors.Count -eq 0) {
            return @{
                IsValid = $true
                Message = "Syntax is valid"
                TokenCount = $tokens.Count
            }
        } else {
            return @{
                IsValid = $false
                Message = "Syntax error: $($errors[0].Message)"
                ErrorCount = $errors.Count
            }
        }
    }
    catch {
        return @{
            IsValid = $false
            Message = "Cannot parse file: $($_.Exception.Message)"
        }
    }
}

function Get-DotfilesValidationResult {
    <#
    .SYNOPSIS
        Create unified validation result object
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Component,

        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Type = "File"
    )

    $result = [ValidationResult]::new($Component)
    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        # Path validation
        $pathResult = Test-DotfilesPath -Path $Path -Type $Type
        if (-not $pathResult.IsValid) {
            $result.Status = "Error"
            $result.Message = $pathResult.Message
            $result.IsValid = $false
            return $result
        }

        $result.Metadata.Path = $Path
        $result.Metadata.Type = $Type

        # Specific type validation
        if ($Path.EndsWith('.json')) {
            $jsonResult = Test-DotfilesJson -Path $Path
            $result.IsValid = $jsonResult.IsValid
            $result.Status = if ($jsonResult.IsValid) { "Success" } else { "Error" }
            $result.Message = $jsonResult.Message
            if ($jsonResult.Size) { $result.Metadata.Size = $jsonResult.Size }
        }
        elseif ($Path.EndsWith('.ps1')) {
            $psResult = Test-DotfilesPowerShell -Path $Path
            $result.IsValid = $psResult.IsValid
            $result.Status = if ($psResult.IsValid) { "Success" } else { "Error" }
            $result.Message = $psResult.Message
            if ($psResult.TokenCount) { $result.Metadata.TokenCount = $psResult.TokenCount }
        }
        else {
            # Basic file validation
            $item = $pathResult.Item
            $result.IsValid = $true
            $result.Status = "Success"
            $result.Message = "File exists"
            $result.Metadata.Size = if (-not $item.PSIsContainer) { $item.Length } else { $null }
            $result.Metadata.LastModified = $item.LastWriteTime
        }
    }
    catch {
        $result.IsValid = $false
        $result.Status = "Error"
        $result.Message = "Validation failed: $($_.Exception.Message)"
    }
    finally {
        $timer.Stop()
        $result.Duration = $timer.Elapsed
    }

    return $result
}

# ==================== File Operation Helper Functions ====================

function Backup-DotfilesFile {
    <#
    .SYNOPSIS
        Create file backup
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$BackupDir = ""
    )

    try {
        if (-not (Test-Path $Path)) {
            throw "Source file does not exist: $Path"
        }

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $fileName = Split-Path $Path -Leaf
        $backupName = "$fileName.backup.$timestamp"

        if ([string]::IsNullOrEmpty($BackupDir)) {
            $BackupDir = Split-Path $Path -Parent
        }

        $backupPath = Join-Path $BackupDir $backupName
        Copy-Item $Path $backupPath -Force

        return @{
            Success = $true
            BackupPath = $backupPath
            Message = "Backup created successfully"
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Backup failed: $($_.Exception.Message)"
        }
    }
}

function Get-DotfilesEnvironment {
    <#
    .SYNOPSIS
        Get environment information
    #>
    param()

    return @{
        ComputerName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        OSVersion = [System.Environment]::OSVersion.VersionString
        WorkingDirectory = (Get-Location).Path
        ProcessId = $PID
        Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    }
}

function Install-DotFile {
    <#
    .SYNOPSIS
        Install single configuration file, supports both copy and symbolic link modes.
    .DESCRIPTION
        Install source file to target location, can be copy or create symbolic link.
        If target file exists, will overwrite based on Force parameter.
        Before overwriting, will create backup of original file.
    .PARAMETER Source
        Full path of source file
    .PARAMETER Target
        Full path of target file
    .PARAMETER Symlink
        If set to $true, create symbolic link instead of copying file
    .PARAMETER Force
        If set to $true, overwrite existing target file
    .PARAMETER BackupDir
        Backup directory path, if target file exists, will create backup in this directory
    .PARAMETER WhatIf
        If set to $true, only show operations that will be performed without executing
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Target,

        [Parameter(Mandatory = $false)]
        [bool]$Symlink = $false,

        [Parameter(Mandatory = $false)]
        [bool]$Force = $false,

        [Parameter(Mandatory = $false)]
        [string]$BackupDir = "",

        [Parameter(Mandatory = $false)]
        [switch]$WhatIf
    )

    # Validate source file exists
    if (-not (Test-Path -Path $Source)) {
        Write-DotfilesMessage -Message "Error: Source file does not exist: $Source" -Type Error
        return $false
    }

    # Ensure target directory exists
    $targetDir = Split-Path -Parent $Target
    if (-not (Test-Path -Path $targetDir)) {
        if ($WhatIf) {
            Write-DotfilesMessage -Message "Will create directory: $targetDir" -Type Info
        } else {
            Write-DotfilesMessage -Message "Creating directory: $targetDir" -Type Info
            New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
        }
    }

    # If target file exists
    if (Test-Path -Path $Target) {
        # If not force overwrite, skip
        if (-not $Force) {
            Write-DotfilesMessage -Message "Skip: Target exists and force overwrite not specified: $Target" -Type Warning
            return $false
        }

        # Create backup
        if (-not $WhatIf) {
            if ([string]::IsNullOrEmpty($BackupDir)) {
                $BackupDir = Split-Path -Parent $Target
            }

            if (-not (Test-Path $BackupDir)) {
                New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
            }

            $fileName = Split-Path -Leaf $Target
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $backupPath = Join-Path -Path $BackupDir -ChildPath "$fileName.backup.$timestamp"

            Write-DotfilesMessage -Message "Backup: $Target -> $backupPath" -Type Info
            Copy-Item -Path $Target -Destination $backupPath -Force
        } else {
            Write-DotfilesMessage -Message "Will backup: $Target" -Type Info
        }

        # Remove existing target
        if ($WhatIf) {
            Write-DotfilesMessage -Message "Will delete: $Target" -Type Info
        } else {
            if (Test-Path -Path $Target -PathType Container) {
                Remove-Item -Path $Target -Recurse -Force
            } else {
                Remove-Item -Path $Target -Force
            }
        }
    }

    # Install file
    if ($Symlink) {
        if ($WhatIf) {
            Write-DotfilesMessage -Message "Will create symbolic link: $Source -> $Target" -Type Info
        } else {
            try {
                if (Test-Path -Path $Source -PathType Container) {
                    # Create symbolic link for directory
                    $command = "New-Item -Path `"$Target`" -ItemType SymbolicLink -Value `"$Source`" -Force"
                    Write-DotfilesMessage -Message "Creating directory link: $Source -> $Target" -Type Info
                    Invoke-Expression $command
                } else {
                    # Create symbolic link for file
                    $command = "New-Item -Path `"$Target`" -ItemType SymbolicLink -Value `"$Source`" -Force"
                    Write-DotfilesMessage -Message "Creating file link: $Source -> $Target" -Type Info
                    Invoke-Expression $command
                }
                return $true
            } catch {
                Write-DotfilesMessage -Message "Failed to create symbolic link: $($_.Exception.Message)" -Type Error
                return $false
            }
        }
    } else {
        if ($WhatIf) {
            Write-DotfilesMessage -Message "Will copy: $Source -> $Target" -Type Info
        } else {
            try {
                if (Test-Path -Path $Source -PathType Container) {
                    # Recursively copy directory
                    Copy-Item -Path $Source -Destination $Target -Recurse -Force
                    Write-DotfilesMessage -Message "Copying directory: $Source -> $Target" -Type Info
                } else {
                    # Copy file
                    Copy-Item -Path $Source -Destination $Target -Force
                    Write-DotfilesMessage -Message "Copying file: $Source -> $Target" -Type Info
                }
                return $true
            } catch {
                Write-DotfilesMessage -Message "Copy failed: $($_.Exception.Message)" -Type Error
                return $false
            }
        }
    }

    return $true
}

# ==================== Export Members ====================

# Export public functions
Export-ModuleMember -Function @(
    'Write-DotfilesMessage',
    'Write-DotfilesHeader',
    'Show-DotfilesProgress',
    'Write-DotfilesSummary',
    'Test-DotfilesPath',
    'Test-DotfilesJson',
    'Test-DotfilesPowerShell',
    'Get-DotfilesValidationResult',
    'Backup-DotfilesFile',
    'Get-DotfilesEnvironment',
    'Install-DotFile'
)

# Export classes
Export-ModuleMember -Variable @(
    'ValidationResult'
)

# Module initialization message
Write-Verbose "DotfilesUtilities module loaded - includes UI and validation functionality"