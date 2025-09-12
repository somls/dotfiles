<#
.SYNOPSIS
    Unified management interface for Windows Dotfiles system

.DESCRIPTION
    This script provides a unified command-line interface for managing your dotfiles configuration.
    It acts as a central dispatcher for all dotfiles operations including environment detection,
    application installation, configuration deployment, and system health checks.

.PARAMETER Command
    The command to execute. Available commands:
    - detect: Analyze system environment and detect installed applications
    - install-apps: Install development applications and tools
    - deploy: Deploy configuration files to system locations
    - health: Perform system health checks and diagnostics
    - status: Show current system status
    - setup: Complete setup process (detect -> install-apps -> deploy -> health)
    - clean: Clean up logs and temporary files
    - help: Show detailed help information

.PARAMETER Type
    Specify configuration types for deploy command (e.g., PowerShell, Git, Starship)

.PARAMETER Category
    Specify application category for install-apps command (Essential, Development, etc.)

.PARAMETER Fix
    Attempt to automatically fix issues (for health command)

.PARAMETER Force
    Force operations without confirmation prompts

.PARAMETER Detailed
    Show detailed output and debug information

.PARAMETER DryRun
    Preview operations without executing them

.PARAMETER Interactive
    Run in interactive mode with step-by-step confirmations

.EXAMPLE
    .\manage.ps1 setup
    Complete setup process: detect environment, install apps, deploy configs, and check health

.EXAMPLE
    .\manage.ps1 detect -Detailed
    Perform detailed environment detection

.EXAMPLE
    .\manage.ps1 deploy -Type PowerShell,Git,Starship
    Deploy only specific configuration types

.EXAMPLE
    .\manage.ps1 health -Fix
    Run health check and automatically fix detected issues

.EXAMPLE
    .\manage.ps1 install-apps -Category Essential
    Install only essential applications

.EXAMPLE
    .\manage.ps1 status
    Show current system and configuration status
#>

param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet('detect', 'install-apps', 'deploy', 'health', 'status', 'setup', 'clean', 'verify-links', 'force-links', 'help')]
    [string]$Command,

    [string[]]$Type,
    [string]$Category,
    [switch]$Fix,
    [switch]$Force,
    [switch]$Detailed,
    [switch]$DryRun,
    [switch]$Interactive
)

# Set script location and paths
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogsDir = Join-Path $ScriptRoot ".dotfiles\logs"
$BackupsDir = Join-Path $ScriptRoot ".dotfiles\backups"
$CacheDir = Join-Path $ScriptRoot ".dotfiles\cache"

# Ensure directories exist
@($LogsDir, $BackupsDir, $CacheDir) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

# Color and formatting functions
function Write-Header {
    param([string]$Text, [string]$Color = 'Cyan')
    Write-Host "`n" -NoNewline
    Write-Host "=" * 60 -ForegroundColor $Color
    Write-Host "  $Text" -ForegroundColor $Color
    Write-Host "=" * 60 -ForegroundColor $Color
    Write-Host ""
}

function Write-Step {
    param([string]$Text, [int]$Step = 0, [int]$Total = 0)
    $prefix = if ($Total -gt 0) { "[$Step/$Total]" } else { "[INFO]" }
    Write-Host "$prefix " -ForegroundColor Yellow -NoNewline
    Write-Host $Text -ForegroundColor White
}

function Write-Success {
    param([string]$Text)
    Write-Host "[✓] " -ForegroundColor Green -NoNewline
    Write-Host $Text -ForegroundColor White
}

function Write-Warning {
    param([string]$Text)
    Write-Host "[!] " -ForegroundColor Yellow -NoNewline
    Write-Host $Text -ForegroundColor White
}

function Write-Error {
    param([string]$Text)
    Write-Host "[✗] " -ForegroundColor Red -NoNewline
    Write-Host $Text -ForegroundColor White
}

# Main script execution
function Invoke-ScriptWithLogging {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments = @(),
        [string]$LogPrefix
    )

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logFile = Join-Path $LogsDir "$LogPrefix-$timestamp.log"

    $fullArgs = @($ScriptPath) + $Arguments

    try {
        $output = & powershell.exe -File @fullArgs 2>&1
        $output | Out-File -FilePath $logFile -Encoding UTF8

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Operation completed successfully"
            Write-Host "    Log: $logFile" -ForegroundColor Gray
        } else {
            Write-Error "Operation failed with exit code $LASTEXITCODE"
            Write-Host "    Log: $logFile" -ForegroundColor Gray
        }

        return $LASTEXITCODE -eq 0
    } catch {
        Write-Error "Failed to execute script: $($_.Exception.Message)"
        $_.Exception.Message | Out-File -FilePath $logFile -Encoding UTF8
        return $false
    }
}

# Command implementations
function Invoke-DetectCommand {
    Write-Header "🔍 Environment Detection" "Cyan"
    Write-Step "Analyzing system environment and installed applications..."

    $scriptPath = Join-Path $ScriptRoot "detect-environment.ps1"
    $args = @()
    if ($Detailed) { $args += "-Detailed" }

    return Invoke-ScriptWithLogging -ScriptPath $scriptPath -Arguments $args -LogPrefix "detect-environment"
}

function Invoke-InstallAppsCommand {
    Write-Header "📦 Application Installation" "Blue"
    Write-Step "Installing development applications and tools..."

    $scriptPath = Join-Path $ScriptRoot "install_apps.ps1"
    $args = @()
    if ($Category) { $args += "-Category", $Category }
    if ($Force) { $args += "-Force" }
    if ($DryRun) { $args += "-DryRun" }

    return Invoke-ScriptWithLogging -ScriptPath $scriptPath -Arguments $args -LogPrefix "install-apps"
}

function Invoke-DeployCommand {
    Write-Header "⚙️ Configuration Deployment" "Green"
    Write-Step "Deploying configuration files to system locations..."

    $scriptPath = Join-Path $ScriptRoot "install.ps1"
    $args = @()
    if ($Type) { $args += "-Type", ($Type -join ",") }
    if ($Force) { $args += "-Force" }
    if ($DryRun) { $args += "-DryRun" }
    if ($Interactive) { $args += "-Interactive" }

    return Invoke-ScriptWithLogging -ScriptPath $scriptPath -Arguments $args -LogPrefix "deploy"
}

function Invoke-HealthCommand {
    Write-Header "🏥 System Health Check" "Magenta"
    Write-Step "Performing system health checks and diagnostics..."

    $scriptPath = Join-Path $ScriptRoot "health-check.ps1"
    $args = @()
    if ($Fix) { $args += "-Fix" }
    if ($Detailed) { $args += "-Detailed" }

    return Invoke-ScriptWithLogging -ScriptPath $scriptPath -Arguments $args -LogPrefix "health-check"
}

function Invoke-StatusCommand {
    Write-Header "📊 System Status" "Yellow"

    # Quick environment check
    Write-Step "Checking system status..."

    try {
        # Check PowerShell version
        $psVersion = $PSVersionTable.PSVersion.ToString()
        Write-Host "  PowerShell Version: " -NoNewline
        Write-Host $psVersion -ForegroundColor Green

        # Check Windows version
        $osVersion = (Get-CimInstance Win32_OperatingSystem).Version
        Write-Host "  Windows Version: " -NoNewline
        Write-Host $osVersion -ForegroundColor Green

        # Check recent logs
        $recentLogs = Get-ChildItem -Path $LogsDir -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 5
        if ($recentLogs) {
            Write-Host "`n  Recent Operations:"
            foreach ($log in $recentLogs) {
                $age = (Get-Date) - $log.LastWriteTime
                $ageStr = if ($age.Days -gt 0) { "$($age.Days)d ago" } elseif ($age.Hours -gt 0) { "$($age.Hours)h ago" } else { "$($age.Minutes)m ago" }
                Write-Host "    • $($log.Name) " -NoNewline -ForegroundColor Gray
                Write-Host "($ageStr)" -ForegroundColor DarkGray
            }
        }

        return $true
    } catch {
        Write-Error "Failed to get system status: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-SetupCommand {
    Write-Header "🚀 Complete Setup Process" "Cyan"
    Write-Host "This will run the complete setup process:" -ForegroundColor White
    Write-Host "  1. Environment Detection" -ForegroundColor Gray
    Write-Host "  2. Application Installation" -ForegroundColor Gray
    Write-Host "  3. Configuration Deployment" -ForegroundColor Gray
    Write-Host "  4. Health Check Validation" -ForegroundColor Gray
    Write-Host ""

    if (-not $Force) {
        $confirmation = Read-Host "Continue? (y/N)"
        if ($confirmation -notmatch '^[Yy]$') {
            Write-Warning "Setup cancelled by user"
            return $false
        }
    }

    $success = $true

    # Step 1: Environment Detection
    Write-Step "Environment Detection" 1 4
    $success = $success -and (Invoke-DetectCommand)

    # Step 2: Application Installation
    if ($success) {
        Write-Step "Application Installation" 2 4
        $success = $success -and (Invoke-InstallAppsCommand)
    }

    # Step 3: Configuration Deployment
    if ($success) {
        Write-Step "Configuration Deployment" 3 4
        $success = $success -and (Invoke-DeployCommand)
    }

    # Step 4: Health Check
    if ($success) {
        Write-Step "Health Check Validation" 4 4
        $success = $success -and (Invoke-HealthCommand)
    }

    if ($success) {
        Write-Header "🎉 Setup Complete!" "Green"
        Write-Success "Your Windows development environment is ready!"
    } else {
        Write-Header "❌ Setup Failed" "Red"
        Write-Error "Setup process encountered errors. Check logs for details."
    }

    return $success
}

function Invoke-VerifyLinksCommand {
    Write-Header "🔍 Symbolic Link Verification" "Cyan"
    Write-Step "Verifying symbolic links between repository and system configurations..."

    $scriptPath = Join-Path $ScriptRoot "verify-links.ps1"
    $args = @("-Verify")
    if ($Detailed) { $args += "-Detailed" }
    if ($Type) { $args += "-Type", ($Type -join ",") }

    return Invoke-ScriptWithLogging -ScriptPath $scriptPath -Arguments $args -LogPrefix "verify-links"
}

function Invoke-ForceLinksCommand {
    Write-Header "🔗 Force Create Symbolic Links" "Green"
    Write-Step "Force creating symbolic links between repository and system configurations..."

    $scriptPath = Join-Path $ScriptRoot "verify-links.ps1"
    $args = @("-ForceLink")
    if ($Type) { $args += "-Type", ($Type -join ",") }
    if ($Force) { $args += "-NoBackup" }
    if ($DryRun) { $args += "-DryRun" }
    if ($Interactive) { $args += "-Interactive" }
    if ($Detailed) { $args += "-Detailed" }

    return Invoke-ScriptWithLogging -ScriptPath $scriptPath -Arguments $args -LogPrefix "force-links"
}

function Invoke-CleanCommand {
    Write-Header "🧹 Cleanup" "Yellow"
    Write-Step "Cleaning up logs and temporary files..."

    try {
        # Clean old logs (keep last 10)
        $allLogs = Get-ChildItem -Path $LogsDir -Filter "*.log" | Sort-Object LastWriteTime -Descending
        $logsToDelete = $allLogs | Select-Object -Skip 10

        $deletedCount = 0
        foreach ($log in $logsToDelete) {
            Remove-Item $log.FullName -Force
            $deletedCount++
        }

        # Clean cache directory
        if (Test-Path $CacheDir) {
            $cacheFiles = Get-ChildItem -Path $CacheDir -Recurse
            foreach ($file in $cacheFiles) {
                Remove-Item $file.FullName -Force -Recurse
            }
        }

        Write-Success "Cleanup completed"
        Write-Host "    Deleted $deletedCount old log files" -ForegroundColor Gray
        Write-Host "    Cleared cache directory" -ForegroundColor Gray

        return $true
    } catch {
        Write-Error "Cleanup failed: $($_.Exception.Message)"
        return $false
    }
}

function Show-Help {
    Write-Header "📖 Dotfiles Management System Help" "Cyan"

    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  .\manage.ps1 <command> [options]" -ForegroundColor White
    Write-Host ""

    Write-Host "COMMANDS:" -ForegroundColor Yellow

    @(
        @("detect", "Analyze system environment and detect installed applications")
        @("install-apps", "Install development applications and tools")
        @("deploy", "Deploy configuration files to system locations")
        @("health", "Perform system health checks and diagnostics")
        @("status", "Show current system and configuration status")
        @("setup", "Complete setup process (recommended for new installations)")
        @("clean", "Clean up logs and temporary files")
        @("verify-links", "Verify symbolic links between repository and system configurations")
        @("force-links", "Force create/recreate symbolic links")
        @("help", "Show this help information")
    ) | ForEach-Object {
        Write-Host "  $($_[0])".PadRight(15) -ForegroundColor Green -NoNewline
        Write-Host $_[1] -ForegroundColor White
    }

    Write-Host ""
    Write-Host "COMMON OPTIONS:" -ForegroundColor Yellow
    Write-Host "  -Force".PadRight(15) -ForegroundColor Magenta -NoNewline
    Write-Host "Skip confirmation prompts" -ForegroundColor White
    Write-Host "  -Detailed".PadRight(15) -ForegroundColor Magenta -NoNewline
    Write-Host "Show detailed output and debug information" -ForegroundColor White
    Write-Host "  -DryRun".PadRight(15) -ForegroundColor Magenta -NoNewline
    Write-Host "Preview operations without executing them" -ForegroundColor White
    Write-Host "  -Interactive".PadRight(15) -ForegroundColor Magenta -NoNewline
    Write-Host "Run in interactive mode with confirmations" -ForegroundColor White

    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  .\manage.ps1 setup" -ForegroundColor Gray
    Write-Host "  .\manage.ps1 deploy -Type PowerShell,Git" -ForegroundColor Gray
    Write-Host "  .\manage.ps1 health -Fix" -ForegroundColor Gray
    Write-Host "  .\manage.ps1 install-apps -Category Essential" -ForegroundColor Gray
    Write-Host "  .\manage.ps1 verify-links -Detailed" -ForegroundColor Gray
    Write-Host "  .\manage.ps1 force-links -Type Git,PowerShell" -ForegroundColor Gray
}

# Main execution logic
switch ($Command.ToLower()) {
    'detect' {
        $exitCode = if (Invoke-DetectCommand) { 0 } else { 1 }
    }
    'install-apps' {
        $exitCode = if (Invoke-InstallAppsCommand) { 0 } else { 1 }
    }
    'deploy' {
        $exitCode = if (Invoke-DeployCommand) { 0 } else { 1 }
    }
    'health' {
        $exitCode = if (Invoke-HealthCommand) { 0 } else { 1 }
    }
    'status' {
        $exitCode = if (Invoke-StatusCommand) { 0 } else { 1 }
    }
    'setup' {
        $exitCode = if (Invoke-SetupCommand) { 0 } else { 1 }
    }
    'clean' {
        $exitCode = if (Invoke-CleanCommand) { 0 } else { 1 }
    }
    'verify-links' {
        $exitCode = if (Invoke-VerifyLinksCommand) { 0 } else { 1 }
    }
    'force-links' {
        $exitCode = if (Invoke-ForceLinksCommand) { 0 } else { 1 }
    }
    'help' {
        Show-Help
        $exitCode = 0
    }
    default {
        Write-Error "Unknown command: $Command"
        Show-Help
        $exitCode = 1
    }
}

exit $exitCode
