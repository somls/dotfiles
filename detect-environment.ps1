<#
.SYNOPSIS
    Environment Detection Script - Detect user system environment and installed applications

.DESCRIPTION
    This script provides comprehensive system environment detection:
    - Detect Windows version and system information
    - Detect installed development tools and applications
    - Identify application installation methods (System, Portable, Scoop, etc.)
    - Provide configuration path detection and validation
    - Generate detailed environment reports and recommendations

.PARAMETER Json
    Output detection results in JSON format

.PARAMETER Detailed
    Show detailed information including paths, versions, etc.

.PARAMETER LogFile
    Specify log file path, defaults to detect-environment.log

.PARAMETER Quiet
    Quiet mode, only output critical information

.EXAMPLE
    .\detect-environment.ps1
    Basic environment detection

.EXAMPLE
    .\detect-environment.ps1 -Detailed
    Detailed mode detection

.EXAMPLE
    .\detect-environment.ps1 -Json
    JSON format output

.EXAMPLE
    .\detect-environment.ps1 -Json -LogFile "my-detection.log"
    JSON output and log to specified file
#>

param(
    [switch]$Json,
    [switch]$Detailed,
    [string]$LogFile = "detect-environment.log",
    [switch]$Quiet,
    [switch]$Help
)

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    return
}

# Set strict mode and error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'  # Continue execution to collect more information

# Logging function
function Write-DetectionLog {
    param(
        [string]$Message,
        [ValidateSet('Success', 'Warning', 'Error', 'Info', 'Debug')]
        [string]$Level = 'Info',
        [System.Exception]$Exception = $null
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    
    if ($Exception) {
        $logEntry += " | Exception: $($Exception.Message)"
    }

    # Write to log file
    try {
        Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {
        # If unable to write to log file, continue execution without error
    }

    # Console output
    if (-not $Quiet) {
        $color = switch ($Level) {
            'Success' { 'Green' }
            'Warning' { 'Yellow' }
            'Error' { 'Red' }
            'Debug' { 'DarkGray' }
            default { 'White' }
        }
        
        $icon = switch ($Level) {
            'Success' { '[SUCCESS]' }
            'Warning' { '[WARNING]' }
            'Error' { '[ERROR]' }
            'Debug' { '[DEBUG]' }
            default { '[INFO]' }
        }

        Write-Host "$icon $Message" -ForegroundColor $color
    }
}

# Get Windows version information
function Get-WindowsVersion {
    Write-DetectionLog "Starting Windows version detection" 'Debug'

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $result = @{
            Name = $os.Caption
            Version = $os.Version
            Build = [int]$os.BuildNumber
            Architecture = $os.OSArchitecture
            IsWindows11 = [int]$os.BuildNumber -ge 22000
            InstallDate = $os.InstallDate
            LastBootUpTime = $os.LastBootUpTime
        }

        Write-DetectionLog "Windows version detection successful: $($result.Name) Build $($result.Build)" 'Success'
        return $result
    } catch {
        Write-DetectionLog "Windows version detection failed, using default values" 'Warning' -Exception $_.Exception
        return @{
            Name = "Unknown Windows"
            Version = "Unknown"
            Build = 0
            Architecture = "Unknown"
            IsWindows11 = $false
            InstallDate = $null
            LastBootUpTime = $null
        }
    }
}

# Detect application installation
function Test-ApplicationInstalled {
    param(
        [string]$AppName,
        [string[]]$Commands,
        [hashtable]$ConfigPaths = @{}
    )

    Write-DetectionLog "Detecting application: $AppName" 'Debug'

    $result = @{
        Name = $AppName
        Installed = $false
        Version = "Not Found"
        Path = $null
        InstallType = "Not Found"
        DetectionMethod = $null
        Commands = $Commands
        ConfigPaths = @{}
        Error = $null
    }

    foreach ($cmd in $Commands) {
        try {
            Write-DetectionLog "Trying to detect command: $cmd" 'Debug'
            $command = Get-Command $cmd -ErrorAction SilentlyContinue
            if ($command) {
                $result.Installed = $true
                $result.Path = $command.Source
                $result.DetectionMethod = "Command: $cmd"

                # Determine installation type
                $installType = "Unknown"
                if ($command.Source -like "*scoop*") {
                    $installType = "Scoop"
                } elseif ($command.Source -like "*Program Files*") {
                    $installType = "System Install"
                } elseif ($command.Source -like "*WindowsApps*") {
                    $installType = "Microsoft Store"
                } elseif ($command.Source -like "*AppData\Local*") {
                    $installType = "User Install (Local)"
                } elseif ($command.Source -like "*AppData\Roaming*") {
                    $installType = "User Install (Roaming)"
                } else {
                    $installType = "Portable/Custom"
                }
                $result.InstallType = $installType

                # Try to get version information
                $versionFound = $false
                try {
                    Write-DetectionLog "Trying to get version info for $cmd" 'Debug'
                    
                    # Try common version commands
                    $versionCommands = @("--version", "-v", "/v", "version")
                    foreach ($versionCmd in $versionCommands) {
                        try {
                            $versionOutput = & $cmd $versionCmd 2>$null
                            if ($versionOutput -and $versionOutput -match '\d+\.\d+') {
                                $result.Version = ($versionOutput | Select-Object -First 1).ToString().Trim()
                                $versionFound = $true
                                Write-DetectionLog "Got version info: $($result.Version)" 'Debug'
                                break
                            }
                        } catch {
                            # Continue trying other version commands
                        }
                    }

                    # If no version found through commands, try file properties
                    if (-not $versionFound -and $command.Source -and (Test-Path $command.Source)) {
                        try {
                            $fileInfo = Get-Item $command.Source
                            if ($fileInfo.VersionInfo.FileVersion) {
                                $result.Version = $fileInfo.VersionInfo.FileVersion
                                Write-DetectionLog "Got version from file properties: $($result.Version)" 'Debug'
                            }
                        } catch {
                            Write-DetectionLog "Unable to get version info for $cmd" 'Debug'
                        }
                    }
                } catch {
                    Write-DetectionLog "Exception while getting version info for ${cmd}: $($_.Exception.Message)" 'Debug'
                }

                # Detect configuration paths
                foreach ($pathType in $ConfigPaths.Keys) {
                    try {
                        $configPath = $ConfigPaths[$pathType]
                        if (Test-Path $configPath) {
                            $result.ConfigPaths[$pathType] = $configPath
                        }
                    } catch {
                        Write-DetectionLog "Failed to get config path for ${appName}: $($_.Exception.Message)" 'Warning' -Exception $_
                        $result.ConfigPaths = @{}
                    }
                }

                Write-DetectionLog "Application detection successful: $AppName ($($result.InstallType))" 'Success'
                return $result
            }
        } catch {
            Write-DetectionLog "Exception while detecting command ${cmd}: $($_.Exception.Message)" 'Debug' -Exception $_
        }
    }

    Write-DetectionLog "Application not found: $AppName" 'Warning'
    return $result
}

# Get configuration paths for different applications
function Get-ConfigPath {
    param([string]$AppName)
    
    switch ($AppName) {
        "PowerShell" { "$env:USERPROFILE\Documents\PowerShell" }
        "Git" { "$env:USERPROFILE" }
        "Starship" { "$env:USERPROFILE\.config" }
        "Neovim" { "$env:LOCALAPPDATA\nvim" }
        "WindowsTerminal" { "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState" }
        default { $null }
    }
}

# Initialize detection results
$detection = @{
    DetectionTime = Get-Date
    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    ExecutionPolicy = Get-ExecutionPolicy
    System = @{}
    Applications = @{}
    Recommendations = @()
}

Write-DetectionLog "Starting environment detection" 'Info'

# Detect system information
try {
    Write-DetectionLog "Detecting system information..." 'Info'
    $detection.System = Get-WindowsVersion
} catch {
    Write-DetectionLog "System information detection failed" 'Error' -Exception $_
    $detection.System = @{ Name = "Unknown"; Version = "Unknown"; Build = 0; IsWindows11 = $false }
}

# Application detection configuration
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
    Jq = @("jq")
    Curl = @("curl")
    Wget = @("wget")
    # 新增检测项目
    Python = @("python", "py")
    NodeJS = @("node")
    Zoxide = @("zoxide", "z")
    LazyGit = @("lazygit")
    SevenZip = @("7z")
    Sudo = @("sudo")
    ShellCheck = @("shellcheck")
    GitHubCLI = @("gh")
}

Write-DetectionLog "Starting application detection..." 'Info'
$detectionErrors = 0

foreach ($appName in $appsToCheck.Keys) {
    try {
        $commands = $appsToCheck[$appName]
        $configPaths = @{}
        
        # Add configuration path if available
        $configPath = Get-ConfigPath $appName
        if ($configPath) {
            $configPaths["Config"] = $configPath
        }

        $detection.Applications[$appName] = Test-ApplicationInstalled -AppName $appName -Commands $commands -ConfigPaths $configPaths
    } catch {
        Write-DetectionLog "Exception while detecting application $appName" 'Error' -Exception $_
        $detectionErrors++

        # Add failed detection result
        $detection.Applications[$appName] = @{
            Name = $appName
            Installed = $false
            Version = "Detection Failed"
            Path = $null
            InstallType = "Error"
            DetectionMethod = $null
            Commands = $appsToCheck[$appName]
            ConfigPaths = @{}
            Error = $_.Exception.Message
        }
    }
}

# Generate intelligent recommendations
Write-DetectionLog "Generating recommendations..." 'Info'
try {
    $installedApps = $detection.Applications.Values | Where-Object { $_.Installed }
    $installedCount = $installedApps.Count
    $totalCount = $detection.Applications.Count

    # Basic tools recommendations
    if (-not $detection.Applications.PowerShell.Installed) {
        $detection.Recommendations += "Recommend installing PowerShell 7+ for better experience and features"
    }
    if (-not $detection.Applications.Git.Installed) {
        $detection.Recommendations += "Recommend installing Git for version control"
    }
    if (-not $detection.Applications.Scoop.Installed) {
        $detection.Recommendations += "Recommend installing Scoop package manager for easier software management"
    }

    # Development tools recommendations
    $devTools = @('VSCode', 'Neovim')
    $hasEditor = $devTools | Where-Object { $detection.Applications[$_].Installed }
    if (-not $hasEditor) {
        $detection.Recommendations += "Recommend installing a code editor (VS Code or Neovim)"
    }

    # Terminal tools recommendations
    $terminals = @('WindowsTerminal')
    $hasModernTerminal = $terminals | Where-Object { $detection.Applications[$_].Installed }
    if (-not $hasModernTerminal) {
        $detection.Recommendations += "Recommend installing modern terminal tools (Windows Terminal)"
    }

    # Command line tools recommendations
    $cliTools = @('Ripgrep', 'Fzf', 'Bat', 'Fd', 'Zoxide')
    $installedCliTools = $cliTools | Where-Object { $detection.Applications[$_].Installed }
    if ($installedCliTools.Count -lt 3) {
        $detection.Recommendations += "Recommend installing command line enhancement tools (ripgrep, fzf, bat, fd, zoxide)"
    }

    # Programming language recommendations
    $progLangs = @('Python', 'NodeJS')
    $installedLangs = $progLangs | Where-Object { $detection.Applications[$_].Installed }
    if ($installedLangs.Count -eq 0) {
        $detection.Recommendations += "Consider installing programming languages (Python, Node.js) for development"
    }

    # Git enhancement tools
    if ($detection.Applications.Git.Installed -and -not $detection.Applications.LazyGit.Installed) {
        $detection.Recommendations += "Consider installing LazyGit for enhanced Git workflow"
    }

    # Overall assessment
    if ($installedCount -eq 0) {
        $detection.Recommendations += "No supported applications detected, recommend installing basic development tools first"
    } elseif ($installedCount -lt 3) {
        $detection.Recommendations += "Few applications detected, recommend installing more development tools"
    } elseif ($installedCount -ge 8) {
        $detection.Recommendations += "Rich development environment detected, ready to configure dotfiles"
    }

    # Error statistics
    if ($detectionErrors -gt 0) {
        $detection.Recommendations += "Encountered $detectionErrors errors during detection, recommend checking system environment"
    }

    Write-DetectionLog "Recommendation generation completed, total $($detection.Recommendations.Count) recommendations" 'Success'
} catch {
    Write-DetectionLog "Exception while generating recommendations" 'Error' -Exception $_
    $detection.Recommendations += "Recommendation generation failed, please check environment manually"
}

# Output results
Write-DetectionLog "Preparing to output detection results" 'Info'

try {
    if ($Json) {
        Write-DetectionLog "Outputting results in JSON format" 'Info'
        $jsonOutput = $detection | ConvertTo-Json -Depth 5 -ErrorAction Stop
        Write-Output $jsonOutput
    } else {
        Write-DetectionLog "Outputting results in formatted text" 'Info'

        if (-not $Quiet) {
            Write-Host "`nEnvironment Detection Report" -ForegroundColor Cyan
            Write-Host ("=" * 60) -ForegroundColor Cyan
            Write-Host "Detection Time: $($detection.DetectionTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
            Write-Host "PowerShell Version: $($detection.PowerShellVersion)" -ForegroundColor Gray
            Write-Host "Execution Policy: $($detection.ExecutionPolicy)" -ForegroundColor Gray

            # System information
            Write-Host "`nSystem Information:" -ForegroundColor Yellow
            Write-Host "  Operating System: $($detection.System.Name)" -ForegroundColor Gray
            Write-Host "  Version: $($detection.System.Version) (Build $($detection.System.Build))" -ForegroundColor Gray
            Write-Host "  Architecture: $($detection.System.Architecture)" -ForegroundColor Gray
            Write-Host "  Windows 11: $($detection.System.IsWindows11)" -ForegroundColor Gray
            if ($Detailed -and $detection.System.InstallDate) {
                Write-Host "  Install Date: $($detection.System.InstallDate.ToString('yyyy-MM-dd'))" -ForegroundColor DarkGray
                Write-Host "  Last Boot: $($detection.System.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor DarkGray
            }

            # Application status statistics
            $installedApps = $detection.Applications.Values | Where-Object { $_.Installed }
            $missingApps = $detection.Applications.Values | Where-Object { -not $_.Installed }

            Write-Host "`nApplication Statistics:" -ForegroundColor Yellow
            Write-Host "  Total: $($detection.Applications.Count)" -ForegroundColor Gray
            Write-Host "  Installed: $($installedApps.Count)" -ForegroundColor Green
            Write-Host "  Not Installed: $($missingApps.Count)" -ForegroundColor Red

            # Detailed application status
            Write-Host "`nApplication Status:" -ForegroundColor Yellow

            # Show installed applications
            if ($installedApps.Count -gt 0) {
                Write-Host "`n  Installed Applications:" -ForegroundColor Green
                foreach ($app in ($installedApps | Sort-Object Name)) {
                    $installInfo = if ($app.InstallType -ne "Not Found") { " ($($app.InstallType))" } else { "" }
                    Write-Host "    • $($app.Name)$installInfo" -ForegroundColor Gray

                    if ($Detailed) {
                        if ($app.Path) {
                            Write-Host "      Path: $($app.Path)" -ForegroundColor DarkGray
                        }
                        if ($app.Version) {
                            Write-Host "      Version: $($app.Version)" -ForegroundColor DarkGray
                        }
                        if ($app.DetectionMethod) {
                            Write-Host "      Detection Method: $($app.DetectionMethod)" -ForegroundColor DarkGray
                        }
                        if ($app.ConfigPaths -and $app.ConfigPaths.Count -gt 0) {
                            Write-Host "      Config Paths:" -ForegroundColor DarkGray
                            foreach ($type in $app.ConfigPaths.Keys) {
                                Write-Host "        $type`: $($app.ConfigPaths[$type])" -ForegroundColor DarkGray
                            }
                        }
                    }
                }
            }

            # Show missing applications
            if ($missingApps.Count -gt 0) {
                Write-Host "`n  Not Installed Applications:" -ForegroundColor Red
                foreach ($app in ($missingApps | Sort-Object Name)) {
                    $errorInfo = if ($app.Error) { " (Error: $($app.Error))" } else { "" }
                    Write-Host "    • $($app.Name)$errorInfo" -ForegroundColor Gray

                    if ($Detailed -and $app.Commands) {
                        Write-Host "      Tried Commands: $($app.Commands -join ', ')" -ForegroundColor DarkGray
                    }
                }
            }

            # Recommendations
            if ($detection.Recommendations.Count -gt 0) {
                Write-Host "`nRecommendations:" -ForegroundColor Yellow
                for ($i = 0; $i -lt $detection.Recommendations.Count; $i++) {
                    Write-Host "  $($i + 1). $($detection.Recommendations[$i])" -ForegroundColor Gray
                }
            }

            Write-Host "`nDetection completed!" -ForegroundColor Green
        }
    }

    Write-DetectionLog "Detection completed successfully" 'Success'
} catch {
    Write-DetectionLog "Error during output: $($_.Exception.Message)" 'Error' -Exception $_.Exception
    Write-Error "Failed to output detection results: $($_.Exception.Message)"
    exit 1
}