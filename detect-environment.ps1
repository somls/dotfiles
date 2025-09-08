# Simple Environment Detection Script
param(
    [switch]$Json,
    [switch]$Detailed,
    [string]$LogFile = "detect-environment.log",
    [switch]$Quiet
)

# Set error handling
$ErrorActionPreference = 'Continue'

# Simple logging function
function Write-Log {
    param([string]$Message, [string]$Level = 'Info')
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    
    try {
        Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}

    if (-not $Quiet) {
        $color = switch ($Level) {
            'Success' { 'Green' }
            'Warning' { 'Yellow' }
            'Error' { 'Red' }
            default { 'White' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

# Get system information
function Get-SystemInfo {
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        return @{
            Name = $os.Caption
            Version = $os.Version
            Build = [int]$os.BuildNumber
            Architecture = $os.OSArchitecture
            IsWindows11 = [int]$os.BuildNumber -ge 22000
        }
    } catch {
        return @{
            Name = "Unknown Windows"
            Version = "Unknown"
            Build = 0
            Architecture = "Unknown"
            IsWindows11 = $false
        }
    }
}

# Test application installation
function Test-App {
    param([string]$AppName, [string[]]$Commands)
    
    $result = @{
        Name = $AppName
        Installed = $false
        Version = "Not Found"
        Path = $null
        InstallType = "Not Found"
    }

    foreach ($cmd in $Commands) {
        try {
            $command = Get-Command $cmd -ErrorAction SilentlyContinue
            if ($command) {
                $result.Installed = $true
                $result.Path = $command.Source
                
                # Determine install type
                if ($command.Source -like "*scoop*") {
                    $result.InstallType = "Scoop"
                } elseif ($command.Source -like "*Program Files*") {
                    $result.InstallType = "System Install"
                } elseif ($command.Source -like "*WindowsApps*") {
                    $result.InstallType = "Microsoft Store"
                } else {
                    $result.InstallType = "Portable/Custom"
                }

                # Try to get version using safe methods
                try {
                    switch ($cmd) {
                        "wt" {
                            # Windows Terminal - get version from registry or skip
                            $result.Version = "Installed (Microsoft Store)"
                        }
                        "code" {
                            # VS Code - try alternative method
                            try {
                                $versionOutput = & $cmd --version 2>$null | Select-Object -First 1
                                if ($versionOutput) {
                                    $result.Version = $versionOutput.Trim()
                                }
                            } catch {
                                $result.Version = "Installed"
                            }
                        }
                        "scoop" {
                            # Scoop - use scoop --version safely
                            try {
                                $versionOutput = & scoop --version 2>$null | Select-Object -First 1
                                if ($versionOutput) {
                                    $result.Version = $versionOutput.Trim()
                                }
                            } catch {
                                $result.Version = "Installed"
                            }
                        }
                        default {
                            # For other commands, use standard --version
                            $versionOutput = & $cmd --version 2>$null
                            if ($versionOutput -and $versionOutput -match '\d+\.\d+') {
                                $result.Version = ($versionOutput | Select-Object -First 1).ToString().Trim()
                            }
                        }
                    }
                } catch {}

                Write-Log "Application detected: $AppName ($($result.InstallType))" 'Success'
                return $result
            }
        } catch {}
    }

    Write-Log "Application not found: $AppName" 'Warning'
    return $result
}

# Initialize detection
$detection = @{
    DetectionTime = Get-Date
    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    System = @{}
    Applications = @{}
    Recommendations = @()
}

Write-Log "Starting environment detection"

# Detect system
$detection.System = Get-SystemInfo

# Applications to check
$appsToCheck = @{
    PowerShell = @("pwsh", "powershell")
    Git = @("git")
    Scoop = @("scoop")
    Starship = @("starship")
    Neovim = @("nvim")
    VSCode = @("code")
    WindowsTerminal = @("wt")
    Ripgrep = @("rg")
    Fzf = @("fzf")
    Bat = @("bat")
    Fd = @("fd")
    Python = @("python", "py")
    NodeJS = @("node")
    Zoxide = @("zoxide", "z")
    LazyGit = @("lazygit")
}

# Detect applications
foreach ($appName in $appsToCheck.Keys) {
    $detection.Applications[$appName] = Test-App -AppName $appName -Commands $appsToCheck[$appName]
}

# Generate simple recommendations
$installedCount = ($detection.Applications.Values | Where-Object { $_.Installed }).Count
$detection.Recommendations += "Environment detection completed successfully"
$detection.Recommendations += "Found $installedCount installed applications out of $($detection.Applications.Count) checked"

if ($installedCount -ge 10) {
    $detection.Recommendations += "Rich development environment detected"
} elseif ($installedCount -ge 5) {
    $detection.Recommendations += "Good development environment detected"
} else {
    $detection.Recommendations += "Basic development environment detected"
}

# Output results
if ($Json) {
    $detection | ConvertTo-Json -Depth 3
} else {
    if (-not $Quiet) {
        Write-Host "`nEnvironment Detection Report" -ForegroundColor Cyan
        Write-Host ("=" * 50) -ForegroundColor Cyan
        Write-Host "Detection Time: $($detection.DetectionTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Host "PowerShell Version: $($detection.PowerShellVersion)"
        
        Write-Host "`nSystem Information:" -ForegroundColor Yellow
        Write-Host "  OS: $($detection.System.Name)"
        Write-Host "  Version: $($detection.System.Version) (Build $($detection.System.Build))"
        Write-Host "  Architecture: $($detection.System.Architecture)"
        
        $installedApps = $detection.Applications.Values | Where-Object { $_.Installed }
        $missingApps = $detection.Applications.Values | Where-Object { -not $_.Installed }
        
        Write-Host "`nApplication Statistics:" -ForegroundColor Yellow
        Write-Host "  Total: $($detection.Applications.Count)"
        Write-Host "  Installed: $($installedApps.Count)" -ForegroundColor Green
        Write-Host "  Not Installed: $($missingApps.Count)" -ForegroundColor Red
        
        if ($Detailed) {
            Write-Host "`nInstalled Applications:" -ForegroundColor Green
            foreach ($app in ($installedApps | Sort-Object Name)) {
                Write-Host "  • $($app.Name) ($($app.InstallType))"
                if ($app.Version -ne "Not Found") {
                    Write-Host "    Version: $($app.Version)" -ForegroundColor Gray
                }
            }
            
            if ($missingApps.Count -gt 0) {
                Write-Host "`nNot Installed:" -ForegroundColor Red
                foreach ($app in ($missingApps | Sort-Object Name)) {
                    Write-Host "  • $($app.Name)"
                }
            }
        }
        
        Write-Host "`nRecommendations:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $detection.Recommendations.Count; $i++) {
            Write-Host "  $($i + 1). $($detection.Recommendations[$i])"
        }
        
        Write-Host "`nDetection completed!" -ForegroundColor Green
    }
}

Write-Log "Detection completed successfully" 'Success'