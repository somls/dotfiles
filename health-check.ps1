<#
.SYNOPSIS
    System Health Check Script for Dotfiles Configuration
    
.DESCRIPTION
    This script performs comprehensive health checks on the dotfiles configuration,
    including system requirements, application installations, configuration files,
    and symbolic links status.
    
.PARAMETER Fix
    Attempt to automatically fix detected issues
    
.PARAMETER Detailed
    Show detailed output including debug information
    
.PARAMETER OutputFormat
    Output format: Console, JSON, or Both
    
.PARAMETER Category
    Specific category to check: System, Applications, ConfigFiles, SymLinks, All
    
.EXAMPLE
    .\health-check.ps1
    Performs basic health check with console output
    
.EXAMPLE
    .\health-check.ps1 -Fix -Detailed
    Performs detailed health check and attempts to fix issues
    
.EXAMPLE
    .\health-check.ps1 -Category Applications -OutputFormat JSON
    Checks only applications and outputs results in JSON format
#>

param(
    [switch]$Fix,
    [switch]$Detailed,
    
    [ValidateSet('Console', 'JSON', 'Both')]
    [string]$OutputFormat = 'Console',
    
    [ValidateSet('System', 'Applications', 'ConfigFiles', 'SymLinks', 'All')]
    [string]$Category = 'All'
)

# Script configuration
$script:SourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:LogFile = Join-Path $script:SourceRoot "health-check.log"
$script:HealthResults = @{}

# Initialize health check results
function Initialize-HealthResults {
    $script:HealthResults = @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        OverallStatus = 'UNKNOWN'
        Categories = @{
            System = @{ Status = 'UNKNOWN'; Score = 0; MaxScore = 0; Issues = @(); Fixes = @() }
            Applications = @{ Status = 'UNKNOWN'; Score = 0; MaxScore = 0; Issues = @(); Fixes = @() }
            ConfigFiles = @{ Status = 'UNKNOWN'; Score = 0; MaxScore = 0; Issues = @(); Fixes = @() }
            SymLinks = @{ Status = 'UNKNOWN'; Score = 0; MaxScore = 0; Issues = @(); Fixes = @() }
        }
        Summary = @{
            TotalChecks = 0
            PassedChecks = 0
            FailedChecks = 0
            FixedIssues = 0
        }
    }
}

# Logging function
function Write-HealthLog {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,
        
        [Parameter(Position = 1)]
        [ValidateSet('INFO', 'SUCCESS', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Console output with colors
    if ($OutputFormat -eq 'Console' -or $OutputFormat -eq 'Both') {
        switch ($Level) {
            "INFO" { Write-Host $logMessage -ForegroundColor White }
            "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
            "WARN" { Write-Host $logMessage -ForegroundColor Yellow }
            "ERROR" { Write-Host $logMessage -ForegroundColor Red }
            "DEBUG" { 
                if ($Detailed) { 
                    Write-Host $logMessage -ForegroundColor Gray 
                } 
            }
            default { Write-Host $logMessage }
        }
    }
    
    # File logging
    try {
        Add-Content -Path $script:LogFile -Value $logMessage -Encoding UTF8
    }
    catch {
        # Continue if logging fails
    }
}

# Update category score
function Update-CategoryScore {
    param(
        [string]$Category,
        [int]$Score,
        [int]$MaxScore = 1
    )
    
    $script:HealthResults.Categories[$Category].Score += $Score
    $script:HealthResults.Categories[$Category].MaxScore += $MaxScore
    
    # Update summary
    $script:HealthResults.Summary.TotalChecks += $MaxScore
    $script:HealthResults.Summary.PassedChecks += $Score
    $script:HealthResults.Summary.FailedChecks += ($MaxScore - $Score)
}

# Add issue to category
function Add-CategoryIssue {
    param(
        [string]$Category,
        [string]$Issue,
        [string]$Fix = $null
    )
    
    $script:HealthResults.Categories[$Category].Issues += $Issue
    if ($Fix) {
        $script:HealthResults.Categories[$Category].Fixes += $Fix
    }
}

# Check system requirements
function Test-SystemRequirements {
    Write-HealthLog "Checking system requirements..." "INFO"
    
    # Check Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -ge 10) {
        Write-HealthLog "Windows version: $($osVersion) - OK" "SUCCESS"
        Update-CategoryScore -Category "System" -Score 1
    } else {
        Write-HealthLog "Windows version: $($osVersion) - Outdated" "WARN"
        Add-CategoryIssue -Category "System" -Issue "Windows version is outdated" -Fix "Upgrade to Windows 10 or later"
        Update-CategoryScore -Category "System" -Score 0
    }
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -ge 5) {
        Write-HealthLog "PowerShell version: $psVersion - OK" "SUCCESS"
        Update-CategoryScore -Category "System" -Score 1
    } else {
        Write-HealthLog "PowerShell version: $psVersion - Outdated" "WARN"
        Add-CategoryIssue -Category "System" -Issue "PowerShell version is outdated" -Fix "Upgrade to PowerShell 5.1 or later"
        Update-CategoryScore -Category "System" -Score 0
    }
    
    # Check execution policy
    $executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($executionPolicy -eq 'RemoteSigned' -or $executionPolicy -eq 'Unrestricted') {
        Write-HealthLog "Execution policy: $executionPolicy - OK" "SUCCESS"
        Update-CategoryScore -Category "System" -Score 1
    } else {
        Write-HealthLog "Execution policy: $executionPolicy - Restrictive" "WARN"
        Add-CategoryIssue -Category "System" -Issue "PowerShell execution policy is too restrictive" -Fix "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
        Update-CategoryScore -Category "System" -Score 0
        
        if ($Fix) {
            try {
                Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                Write-HealthLog "Fixed: Set execution policy to RemoteSigned" "SUCCESS"
                $script:HealthResults.Summary.FixedIssues++
                # Update the score after fixing
                Update-CategoryScore -Category "System" -Score 1 -MaxScore 0
            }
            catch {
                Write-HealthLog "Failed to fix execution policy: $($_.Exception.Message)" "ERROR"
            }
        }
    }
    
    # Enhanced environment compatibility checks
    Test-EnvironmentCompatibility
}

# Enhanced environment compatibility check
function Test-EnvironmentCompatibility {
    Write-HealthLog "Checking environment compatibility..." "INFO"
    
    # Check available disk space
    try {
        $drive = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $env:SystemDrive }
        $freeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        if ($freeSpaceGB -ge 2) {
            Write-HealthLog "Disk space: ${freeSpaceGB}GB available - OK" "SUCCESS"
            Update-CategoryScore -Category "System" -Score 1
        } else {
            Write-HealthLog "Disk space: ${freeSpaceGB}GB available - Low" "WARN"
            Add-CategoryIssue -Category "System" -Issue "Low disk space (${freeSpaceGB}GB)" -Fix "Free up disk space (minimum 2GB recommended)"
            Update-CategoryScore -Category "System" -Score 0
        }
    } catch {
        Write-HealthLog "Could not check disk space: $($_.Exception.Message)" "WARN"
    }
    
    # Check internet connectivity
    try {
        $testUrls = @(
            "https://get.scoop.sh",
            "https://github.com",
            "https://raw.githubusercontent.com"
        )
        
        $connectivityOK = $false
        foreach ($url in $testUrls) {
            try {
                $null = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 5 -ErrorAction Stop
                $connectivityOK = $true
                break
            } catch {
                continue
            }
        }
        
        if ($connectivityOK) {
            Write-HealthLog "Internet connectivity - OK" "SUCCESS"
            Update-CategoryScore -Category "System" -Score 1
        } else {
            Write-HealthLog "Internet connectivity - Failed" "WARN"
            Add-CategoryIssue -Category "System" -Issue "No internet connectivity" -Fix "Check network connection and proxy settings"
            Update-CategoryScore -Category "System" -Score 0
        }
    } catch {
        Write-HealthLog "Could not test internet connectivity: $($_.Exception.Message)" "WARN"
    }
    
    # Check user permissions
    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($isAdmin) {
            Write-HealthLog "User permissions: Administrator - OK" "SUCCESS"
            Update-CategoryScore -Category "System" -Score 1
        } else {
            Write-HealthLog "User permissions: Standard user - Limited" "INFO"
            Write-HealthLog "Note: Some operations may require administrator privileges" "INFO"
            Update-CategoryScore -Category "System" -Score 1  # Not necessarily a problem
        }
    } catch {
        Write-HealthLog "Could not check user permissions: $($_.Exception.Message)" "WARN"
    }
    
    # Check Windows features (Developer Mode for symbolic links)
    try {
        $devMode = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
        if ($devMode -and $devMode.AllowDevelopmentWithoutDevLicense -eq 1) {
            Write-HealthLog "Developer Mode: Enabled - OK" "SUCCESS"
            Update-CategoryScore -Category "System" -Score 1
        } else {
            Write-HealthLog "Developer Mode: Disabled - Limited symbolic link support" "INFO"
            Write-HealthLog "Note: Enable Developer Mode for better symbolic link support without admin privileges" "INFO"
            Update-CategoryScore -Category "System" -Score 1  # Not critical
        }
    } catch {
        Write-HealthLog "Could not check Developer Mode status" "DEBUG"
    }
}

# Check application installations
function Test-Applications {
    Write-HealthLog "Checking application installations..." "INFO"
    
    $requiredApps = @{
        'git' = 'Git version control system'
        'scoop' = 'Scoop package manager'
        'starship' = 'Starship prompt'
    }
    
    foreach ($app in $requiredApps.Keys) {
        try {
            $null = Get-Command $app -ErrorAction Stop
            Write-HealthLog "$($requiredApps[$app]): Installed" "SUCCESS"
            Update-CategoryScore -Category "Applications" -Score 1
        }
        catch {
            Write-HealthLog "$($requiredApps[$app]): Not found" "WARN"
            Add-CategoryIssue -Category "Applications" -Issue "$($requiredApps[$app]) is not installed" -Fix "Install $app using Scoop or other package manager"
            Update-CategoryScore -Category "Applications" -Score 0
        }
    }
    
    # Check optional applications
    $optionalApps = @{
        'nvim' = 'Neovim editor'
        'code' = 'Visual Studio Code'
        'wt' = 'Windows Terminal'
    }
    
    foreach ($app in $optionalApps.Keys) {
        try {
            $null = Get-Command $app -ErrorAction Stop
            Write-HealthLog "$($optionalApps[$app]): Installed" "DEBUG"
        }
        catch {
            Write-HealthLog "$($optionalApps[$app]): Not installed (optional)" "DEBUG"
        }
    }
}

# Check configuration files
function Test-ConfigurationFiles {
    Write-HealthLog "Checking configuration files..." "INFO"
    
    $configFiles = @{
        'powershell\Microsoft.PowerShell_profile.ps1' = 'PowerShell profile'
        'git\gitconfig' = 'Git configuration'
        'starship\starship.toml' = 'Starship configuration'
        'neovim\init.lua' = 'Neovim configuration'
    }
    
    foreach ($file in $configFiles.Keys) {
        $filePath = Join-Path $script:SourceRoot $file
        $exists = Test-Path $filePath
        
        if ($exists) {
            Write-HealthLog "$($configFiles[$file]): Found" "SUCCESS"
            $score = 1
        } else {
            Write-HealthLog "$($configFiles[$file]): Missing" "WARN"
            Add-CategoryIssue -Category "ConfigFiles" -Issue "$($configFiles[$file]) is missing" -Fix "Create or restore $file"
            $score = 0
        }
        
        Update-CategoryScore -Category "ConfigFiles" -Score $score
    }
}

# Check symbolic links
function Test-SymbolicLinks {
    Write-HealthLog "Checking symbolic links..." "INFO"
    
    # Check if developer mode is enabled
    $devModeFile = Join-Path $env:USERPROFILE ".dotfiles.dev-mode"
    if (-not (Test-Path $devModeFile)) {
        Write-HealthLog "Developer mode not enabled - skipping symbolic link checks" "DEBUG"
        Update-CategoryScore -Category "SymLinks" -Score 1 -MaxScore 1
        return
    }
    
    # Define expected symbolic links based on actual project configuration
    $documentsPath = [Environment]::GetFolderPath('MyDocuments')
    $psProfilePath = if ($PSVersionTable.PSVersion.Major -ge 6) {
        "$documentsPath\PowerShell\Microsoft.PowerShell_profile.ps1"
    } else {
        "$documentsPath\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
    }
    
    $expectedLinks = @{
        # Git 配置
        "$env:USERPROFILE\.gitconfig" = 'Git configuration'
        "$env:USERPROFILE\.gitignore_global" = 'Git global ignore'
        "$env:USERPROFILE\.gitmessage" = 'Git commit message template'
        
        # PowerShell 配置
        $psProfilePath = 'PowerShell profile'
        "$env:USERPROFILE\.powershell" = 'PowerShell extras'
        
        # 应用配置
        "$env:LOCALAPPDATA\nvim" = 'Neovim configuration'
        "$env:USERPROFILE\.config\starship.toml" = 'Starship configuration'
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" = 'Windows Terminal settings'
    }
    
    # 检查Scoop配置 (动态检测路径)
    $scoopPath = $env:SCOOP
    if (-not $scoopPath) {
        $possibleScoopPaths = @("$env:USERPROFILE\scoop", "G:\Scoop", "C:\Scoop")
        foreach ($path in $possibleScoopPaths) {
            if (Test-Path $path) {
                $scoopPath = $path
                break
            }
        }
    }
    if ($scoopPath) {
        $expectedLinks["$scoopPath\config.json"] = 'Scoop configuration'
    }
    
    # 检查PowerShell模块
    $psModulePath = if ($PSVersionTable.PSVersion.Major -ge 6) {
        "$documentsPath\PowerShell\Modules\DotfilesUtilities\DotfilesUtilities.psm1"
    } else {
        "$documentsPath\WindowsPowerShell\Modules\DotfilesUtilities\DotfilesUtilities.psm1"
    }
    $expectedLinks[$psModulePath] = 'PowerShell DotfilesUtilities module'
    
    foreach ($link in $expectedLinks.Keys) {
        if (Test-Path $link) {
            $item = Get-Item $link
            if ($item.LinkType -eq "SymbolicLink") {
                Write-HealthLog "$($expectedLinks[$link]): Valid symbolic link" "SUCCESS"
                Update-CategoryScore -Category "SymLinks" -Score 1
            } else {
                Write-HealthLog "$($expectedLinks[$link]): Exists but not a symbolic link" "WARN"
                Add-CategoryIssue -Category "SymLinks" -Issue "$($expectedLinks[$link]) exists but is not a symbolic link" -Fix "Remove existing file and create symbolic link"
                Update-CategoryScore -Category "SymLinks" -Score 0
            }
        } else {
            Write-HealthLog "$($expectedLinks[$link]): Missing symbolic link" "WARN"
            Add-CategoryIssue -Category "SymLinks" -Issue "$($expectedLinks[$link]) symbolic link is missing" -Fix "Create symbolic link using dev-link.ps1"
            Update-CategoryScore -Category "SymLinks" -Score 0
        }
    }
}

# Calculate overall status
function Update-OverallStatus {
    $totalScore = 0
    $maxTotalScore = 0
    
    foreach ($category in $script:HealthResults.Categories.Values) {
        $totalScore += $category.Score
        $maxTotalScore += $category.MaxScore
        
        # Calculate category status
        if ($category.MaxScore -eq 0) {
            $category.Status = 'SKIPPED'
        } elseif ($category.Score -eq $category.MaxScore) {
            $category.Status = 'HEALTHY'
        } elseif ($category.Score -gt 0) {
            $category.Status = 'WARNING'
        } else {
            $category.Status = 'ERROR'
        }
    }
    
    # Calculate overall status
    if ($maxTotalScore -eq 0) {
        $script:HealthResults.OverallStatus = 'UNKNOWN'
    } elseif ($totalScore -eq $maxTotalScore) {
        $script:HealthResults.OverallStatus = 'HEALTHY'
    } elseif ($totalScore -gt ($maxTotalScore * 0.7)) {
        $script:HealthResults.OverallStatus = 'WARNING'
    } else {
        $script:HealthResults.OverallStatus = 'ERROR'
    }
}

# Output results
function Write-Results {
    if ($OutputFormat -eq 'JSON' -or $OutputFormat -eq 'Both') {
        $jsonOutput = $script:HealthResults | ConvertTo-Json -Depth 10
        
        if ($OutputFormat -eq 'JSON') {
            Write-Output $jsonOutput
        } else {
            $jsonFile = Join-Path $script:SourceRoot "health-check-results.json"
            $jsonOutput | Out-File -FilePath $jsonFile -Encoding UTF8
            Write-HealthLog "Results saved to: $jsonFile" "INFO"
        }
    }
    
    if ($OutputFormat -eq 'Console' -or $OutputFormat -eq 'Both') {
        Write-HealthLog "=== HEALTH CHECK SUMMARY ===" "INFO"
        Write-HealthLog "Overall Status: $($script:HealthResults.OverallStatus)" "INFO"
        Write-HealthLog "Total Checks: $($script:HealthResults.Summary.TotalChecks)" "INFO"
        Write-HealthLog "Passed: $($script:HealthResults.Summary.PassedChecks)" "SUCCESS"
        Write-HealthLog "Failed: $($script:HealthResults.Summary.FailedChecks)" "ERROR"
        
        if ($Fix) {
            Write-HealthLog "Fixed Issues: $($script:HealthResults.Summary.FixedIssues)" "SUCCESS"
        }
        
        Write-HealthLog "Category Details:" "INFO"
        foreach ($categoryName in $script:HealthResults.Categories.Keys) {
            $category = $script:HealthResults.Categories[$categoryName]
            Write-HealthLog "  $categoryName`: $($category.Status) ($($category.Score)/$($category.MaxScore))" "INFO"
            
            if ($category.Issues.Count -gt 0 -and $Detailed) {
                Write-HealthLog "    Issues:" "WARN"
                foreach ($issue in $category.Issues) {
                    Write-HealthLog "      - $issue" "WARN"
                }
            }
        }
    }
}

# Main execution
function Main {
    Write-HealthLog "Starting dotfiles health check..." "INFO"
    
    Initialize-HealthResults
    
    # Run checks based on category parameter
    if ($Category -eq 'All' -or $Category -eq 'System') {
        Test-SystemRequirements
    }
    
    if ($Category -eq 'All' -or $Category -eq 'Applications') {
        Test-Applications
    }
    
    if ($Category -eq 'All' -or $Category -eq 'ConfigFiles') {
        Test-ConfigurationFiles
    }
    
    if ($Category -eq 'All' -or $Category -eq 'SymLinks') {
        Test-SymbolicLinks
    }
    
    # Calculate final status
    Update-OverallStatus
    
    # Output results
    Write-Results
    
    # Exit with appropriate code
    switch ($script:HealthResults.OverallStatus) {
        'HEALTHY' { exit 0 }
        'WARNING' { exit 1 }
        'ERROR' { exit 2 }
        default { exit 3 }
    }
}

# Execute main function
Main