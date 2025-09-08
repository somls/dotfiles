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
$script:SourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:LogFile = Join-Path $script:SourceRoot "dev-link.log"

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
    }
    catch {
        # Continue if logging fails
    }
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
    $paths['WindowsTerminal'] = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
    
    # Package manager paths - 检测实际的Scoop安装位置
    $scoopPath = $env:SCOOP
    if (-not $scoopPath) {
        # 检查常见的Scoop安装位置
        $possibleScoopPaths = @(
            "$env:USERPROFILE\scoop",
            "G:\Scoop",
            "C:\Scoop"
        )
        foreach ($path in $possibleScoopPaths) {
            if (Test-Path $path) {
                $scoopPath = $path
                break
            }
        }
    }
    $paths['Scoop'] = if ($scoopPath) { $scoopPath } else { "$env:USERPROFILE\scoop" }
    
    # CMD scripts 已移除
    
    return $paths
}

# Define source to target mappings
function Get-ComponentMappings {
    return @{
        # Git 配置 - 主要配置
        'Git' = @(
            @{ Source = "git\gitconfig"; Target = ".gitconfig" }
        )
        # Git 配置 - 扩展文件
        'GitExtras' = @(
            @{ Source = "git\gitignore_global"; Target = ".gitignore_global" },
            @{ Source = "git\gitmessage"; Target = ".gitmessage" }
        )
        # PowerShell 配置 - 主配置文件
        'PowerShell' = @(
            @{ Source = "powershell\Microsoft.PowerShell_profile.ps1"; Target = "Microsoft.PowerShell_profile.ps1" }
        )
        # PowerShell 配置 - 扩展文件夹
        'PowerShellExtras' = @(
            @{ Source = "powershell\.powershell"; Target = ".powershell" }
        )
        # PowerShell 模块
        'PowerShellModule' = @(
            @{ Source = "modules\DotfilesUtilities.psm1"; Target = "DotfilesUtilities\DotfilesUtilities.psm1"; IsModule = $true }
        )
        # Neovim 配置
        'Neovim' = @(
            @{ Source = "neovim"; Target = "." }
        )
        # Starship 提示符配置
        'Starship' = @(
            @{ Source = "starship\starship.toml"; Target = "starship.toml" }
        )
        # Windows Terminal 配置
        'WindowsTerminal' = @(
            @{ Source = "WindowsTerminal\settings.json"; Target = "settings.json" }
        )
        # Scoop 包管理器配置
        'Scoop' = @(
            @{ Source = "scoop\config.json"; Target = "config.json" }
        )
        # CMD 脚本已移除 - 简化项目结构
    }
}

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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
            New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            Write-DevLog "Created target directory: $targetDir" "INFO"
        }
        catch {
            Write-DevLog "Failed to create target directory: $targetDir - $($_.Exception.Message)" "ERROR"
            return $false
        }
    }
    
    # Remove existing target if it exists
    if (Test-Path $Target) {
        if (-not $Force) {
            $response = Read-Host "Target exists: $Target. Replace? (y/N)"
            if ($response -ne 'y' -and $response -ne 'Y') {
                Write-DevLog "Skipped: $Target" "WARN"
                return $false
            }
        }
        
        try {
            Remove-Item $Target -Force -Recurse
            Write-DevLog "Removed existing target: $Target" "INFO"
        }
        catch {
            Write-DevLog "Failed to remove existing target: $Target - $($_.Exception.Message)" "ERROR"
            return $false
        }
    }
    
    # Create symbolic link
    try {
        $item = Get-Item $sourcePath
        if ($item.PSIsContainer) {
            New-Item -Path $Target -ItemType SymbolicLink -Value $sourcePath | Out-Null
        } else {
            New-Item -Path $Target -ItemType SymbolicLink -Value $sourcePath | Out-Null
        }
        Write-DevLog "Created symbolic link: $Target -> $sourcePath" "SUCCESS"
        return $true
    }
    catch {
        Write-DevLog "Failed to create symbolic link: $Target -> $sourcePath - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Remove symbolic link
function Remove-SymbolicLink {
    param(
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
    }
    catch {
        Write-DevLog "Failed to remove symbolic link: $Target - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Check symbolic link status
function Get-SymbolicLinkStatus {
    param(
        [string]$Source,
        [string]$Target,
        [string]$ComponentName
    )
    
    $sourcePath = Join-Path $script:SourceRoot $Source
    $status = @{
        Component = $ComponentName
        Source = $sourcePath
        Target = $Target
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
        # 特殊处理PowerShell模块
        if ($mapping.IsModule -and $ComponentName -eq 'PowerShellModule') {
            $targetPath = Join-Path $basePath $mapping.Target
            # 确保模块目录存在
            $moduleDir = Split-Path $targetPath -Parent
            if (-not (Test-Path $moduleDir)) {
                New-Item -Path $moduleDir -ItemType Directory -Force | Out-Null
                Write-DevLog "Created module directory: $moduleDir" "INFO"
            }
        } else {
            $targetPath = Join-Path $basePath $mapping.Target
        }
        
        switch ($Action) {
            'Create' {
                $result = New-SymbolicLink -Source $mapping.Source -Target $targetPath -ComponentName $ComponentName
                if (-not $result) { $success = $false }
            }
            'Remove' {
                $result = Remove-SymbolicLink -Target $targetPath -ComponentName $ComponentName
                if (-not $result) { $success = $false }
            }
            'Status' {
                $status = Get-SymbolicLinkStatus -Source $mapping.Source -Target $targetPath -ComponentName $ComponentName
                
                $statusText = if ($status.Exists) {
                    if ($status.IsSymbolicLink) {
                        if ($status.IsValid) {
                            "Valid symbolic link"
                        } else {
                            "Invalid symbolic link (points to: $($status.TargetPath))"
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

# Main execution
function Main {
    Write-DevLog "Starting dev-link.ps1 - Action: $Action" "INFO"
    
    # Check administrator privileges for symbolic link creation
    if ($Action -eq 'Create' -and -not (Test-Administrator)) {
        Write-DevLog "Administrator privileges required for creating symbolic links" "ERROR"
        Write-DevLog "Please run PowerShell as Administrator and try again" "ERROR"
        exit 1
    }
    
    $components = if ($Component) {
        @($Component)
    } else {
        # 默认处理所有主要组件
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