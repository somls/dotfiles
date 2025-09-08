<#
.SYNOPSIS
    Application Installation Script via Scoop
    
.DESCRIPTION
    This script installs applications using Scoop package manager.
    It can install predefined application sets or individual applications.
    
.PARAMETER Category
    Application category to install: Essential, Development, Programming, Media, All
    
.PARAMETER Apps
    Specific applications to install (comma-separated)
    
.PARAMETER Force
    Force installation without confirmation
    
.PARAMETER Quiet
    Suppress non-essential output
    
.PARAMETER DryRun
    Show what would be installed without actually installing
    
.EXAMPLE
    .\install_apps.ps1 -Category Essential
    Installs essential applications
    
.EXAMPLE
    .\install_apps.ps1 -Apps "git,nodejs,python"
    Installs specific applications
    
.EXAMPLE
    .\install_apps.ps1 -Category All -Force
    Installs all applications without confirmation
#>

param(
    [ValidateSet('Essential', 'Development', 'Programming', 'Media', 'All')]
    [string]$Category,
    
    [string[]]$Apps,
    
    [switch]$Force,
    [switch]$Quiet,
    [switch]$DryRun
)

# Script configuration
$script:SourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:LogFile = Join-Path $script:SourceRoot "install_apps.log"

# Application definitions
$script:AppCategories = @{
    Essential = @{
        Description = "Essential Tools"
        Apps = @(
            "git", "7zip", "curl", "wget", "which", "grep", "sed", "jq",
            "powershell", "windows-terminal", "starship"
        )
    }
    
    Development = @{
        Description = "Development Tools"
        Apps = @(
            "nodejs", "python", "go", "rustup", "dotnet-sdk",
            "vscode", "neovim", "docker", "docker-compose"
        )
    }
    
    Programming = @{
        Description = "Programming Language Support"
        Apps = @(
            "gcc", "llvm", "cmake", "make", "ninja",
            "ruby", "php", "java", "kotlin", "scala"
        )
    }
    
    Media = @{
        Description = "Media and Graphics Tools"
        Apps = @(
            "ffmpeg", "imagemagick", "gimp", "inkscape",
            "vlc", "obs-studio", "audacity"
        )
    }
}

# Logging function
function Write-AppLog {
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

# Check if Scoop is installed
function Test-ScoopInstalled {
    try {
        $null = Get-Command scoop -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Enhanced environment compatibility check
function Test-InstallEnvironment {
    Write-AppLog "Checking installation environment compatibility..." "INFO"
    
    $issues = @()
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $issues += "PowerShell 5.0+ required, current: $($PSVersionTable.PSVersion)"
    }
    
    # Check execution policy
    $policy = Get-ExecutionPolicy
    if ($policy -eq 'Restricted') {
        $issues += "Execution policy is Restricted, may prevent script execution"
    }
    
    # Check internet connectivity
    try {
        $null = Invoke-WebRequest -Uri "https://get.scoop.sh" -Method Head -TimeoutSec 10 -ErrorAction Stop
        Write-AppLog "Internet connectivity: OK" "DEBUG"
    } catch {
        $issues += "Internet connectivity issue - may affect package downloads"
    }
    
    # Check available disk space (minimum 2GB)
    try {
        $drive = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $env:SystemDrive }
        $freeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        if ($freeSpaceGB -lt 2) {
            $issues += "Low disk space: ${freeSpaceGB}GB available (minimum 2GB recommended)"
        }
        Write-AppLog "Available disk space: ${freeSpaceGB}GB" "DEBUG"
    } catch {
        Write-AppLog "Could not check disk space" "WARN"
    }
    
    if ($issues.Count -gt 0) {
        Write-AppLog "Environment compatibility issues found:" "WARN"
        foreach ($issue in $issues) {
            Write-AppLog "  - $issue" "WARN"
        }
        
        # Ask user if they want to continue
        $choices = @(
            [System.Management.Automation.Host.ChoiceDescription]::new("&Continue", "Continue despite issues")
            [System.Management.Automation.Host.ChoiceDescription]::new("&Exit", "Exit and fix issues first")
        )
        
        $decision = $Host.UI.PromptForChoice(
            "Environment Issues Detected",
            "Some environment issues were detected. Do you want to continue anyway?",
            $choices,
            1  # Default to Exit
        )
        
        return $decision -eq 0
    }
    
    Write-AppLog "Environment compatibility check passed" "SUCCESS"
    return $true
}

# Install Scoop if not present
function Install-Scoop {
    Write-AppLog "Scoop not found. Installing Scoop..." "INFO"
    
    try {
        # Set execution policy for current user
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        
        # Download and install Scoop
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        
        # Verify installation
        if (Test-ScoopInstalled) {
            Write-AppLog "Scoop installed successfully" "SUCCESS"
            return $true
        } else {
            Write-AppLog "Scoop installation verification failed" "ERROR"
            return $false
        }
    }
    catch {
        Write-AppLog "Failed to install Scoop: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Add Scoop buckets
function Add-ScoopBuckets {
    $buckets = @('extras', 'versions', 'nerd-fonts')
    
    foreach ($bucket in $buckets) {
        try {
            # Check if bucket already exists
            $existingBuckets = & scoop bucket list 2>$null | Where-Object { $_ -match $bucket }
            if (-not $existingBuckets) {
                Write-AppLog "Adding Scoop bucket: $bucket" "INFO"
                $addCommand = "scoop bucket add `"$bucket`""
                Invoke-Expression $addCommand
                if ($LASTEXITCODE -eq 0) {
                    Write-AppLog "Successfully added bucket: $bucket" "SUCCESS"
                } else {
                    Write-AppLog "Failed to add bucket: $bucket (exit code: $LASTEXITCODE)" "WARN"
                }
            } else {
                Write-AppLog "Bucket already exists: $bucket" "DEBUG"
            }
        }
        catch {
            Write-AppLog "Error adding bucket $bucket`: $($_.Exception.Message)" "WARN"
        }
    }
}

# Check if application is installed
function Test-AppInstalled {
    param([string]$AppName)
    
    try {
        $listCommand = "scoop list `"$AppName`""
        $installed = Invoke-Expression $listCommand 2>$null
        return $installed -and ($installed -match $AppName)
    }
    catch {
        return $false
    }
}

# Install single application
function Install-Application {
    param(
        [string]$AppName,
        [int]$MaxRetries = 3
    )
    
    if (Test-AppInstalled -AppName $AppName) {
        Write-AppLog "Already installed: $AppName" "DEBUG"
        return $true
    }
    
    if ($DryRun) {
        Write-AppLog "Would install: $AppName" "INFO"
        return $true
    }
    
    $retryCount = 0
    while ($retryCount -lt $MaxRetries) {
        try {
            Write-AppLog "Installing: $AppName (attempt $($retryCount + 1)/$MaxRetries)" "INFO"
            
            # Use Invoke-Expression to avoid parameter binding issues
            $installCommand = "scoop install `"$AppName`""
            Invoke-Expression $installCommand
            
            if ($LASTEXITCODE -eq 0) {
                Write-AppLog "Successfully installed: $AppName" "SUCCESS"
                return $true
            } else {
                $retryCount++
                if ($retryCount -lt $MaxRetries) {
                    Write-AppLog "Installation failed for $AppName, retrying..." "WARN"
                    Start-Sleep -Seconds 2
                } else {
                    Write-AppLog "Failed to install $AppName after $MaxRetries attempts" "ERROR"
                    return $false
                }
            }
        }
        catch {
            $retryCount++
            if ($retryCount -lt $MaxRetries) {
                Write-AppLog "Exception installing $AppName, retrying: $($_.Exception.Message)" "WARN"
                Start-Sleep -Seconds 2
            } else {
                Write-AppLog "Exception installing $AppName after $MaxRetries attempts: $($_.Exception.Message)" "ERROR"
                return $false
            }
        }
    }
    
    return $false
}

# Install applications from category
function Install-CategoryApps {
    param([string]$CategoryName)
    
    if (-not $script:AppCategories.ContainsKey($CategoryName)) {
        Write-AppLog "Unknown category: $CategoryName" "ERROR"
        return $false
    }
    
    $category = $script:AppCategories[$CategoryName]
    Write-AppLog "Installing category: $($category.Description)" "INFO"
    
    $successCount = 0
    $totalCount = $category.Apps.Count
    
    foreach ($app in $category.Apps) {
        if (Install-Application -AppName $app) {
            $successCount++
        }
    }
    
    Write-AppLog "Category $CategoryName`: $successCount/$totalCount applications installed successfully" "INFO"
    return $successCount -eq $totalCount
}

# Install all categories
function Install-AllApps {
    $overallSuccess = $true
    
    foreach ($categoryName in $script:AppCategories.Keys) {
        $result = Install-CategoryApps -CategoryName $categoryName
        if (-not $result) {
            $overallSuccess = $false
        }
    }
    
    return $overallSuccess
}

# Install specific applications
function Install-SpecificApps {
    param([string[]]$AppList)
    
    $successCount = 0
    $totalCount = $AppList.Count
    
    foreach ($app in $AppList) {
        if (Install-Application -AppName $app.Trim()) {
            $successCount++
        }
    }
    
    Write-AppLog "Specific apps: $successCount/$totalCount applications installed successfully" "INFO"
    return $successCount -eq $totalCount
}

# Show available categories and applications
function Show-AvailableApps {
    Write-AppLog "Available application categories:" "INFO"
    
    foreach ($categoryName in $script:AppCategories.Keys) {
        $category = $script:AppCategories[$categoryName]
        Write-AppLog "  $categoryName`: $($category.Description)" "INFO"
        Write-AppLog "    Apps: $($category.Apps -join ', ')" "DEBUG"
    }
}

# Main execution
function Main {
    Write-AppLog "Starting install_apps.ps1" "INFO"
    
    # Validate parameters
    if (-not $Category -and -not $Apps) {
        Write-AppLog "No category or specific apps specified. Use -Category or -Apps parameter." "ERROR"
        Show-AvailableApps
        exit 1
    }
    
    # Enhanced environment check before proceeding
    if (-not (Test-InstallEnvironment)) {
        Write-AppLog "Environment check failed, aborting installation" "ERROR"
        exit 1
    }
    
    # Check and install Scoop if needed
    if (-not (Test-ScoopInstalled)) {
        if (-not (Install-Scoop)) {
            Write-AppLog "Cannot proceed without Scoop" "ERROR"
            exit 1
        }
    } else {
        Write-AppLog "Scoop is already installed" "DEBUG"
    }
    
    # Add essential buckets
    Add-ScoopBuckets
    
    # Perform installation based on parameters
    $success = $true
    
    if ($Apps) {
        # Install specific applications
        $appList = $Apps -split ',' | ForEach-Object { $_.Trim() }
        $success = Install-SpecificApps -AppList $appList
    }
    elseif ($Category -eq 'All') {
        # Install all categories
        if (-not $Force) {
            $response = Read-Host "This will install ALL applications. Continue? (y/N)"
            if ($response -ne 'y' -and $response -ne 'Y') {
                Write-AppLog "Installation cancelled by user" "INFO"
                exit 0
            }
        }
        $success = Install-AllApps
    }
    else {
        # Install specific category
        $success = Install-CategoryApps -CategoryName $Category
    }
    
    # Final status
    if ($success) {
        Write-AppLog "Application installation completed successfully" "SUCCESS"
        exit 0
    } else {
        Write-AppLog "Application installation completed with errors" "ERROR"
        exit 1
    }
}

# Execute main function
Main