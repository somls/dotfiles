# ~/.powershell/functions.ps1
# Core utility functions

# Git quick operations
function ngc { 
    param([string]$msg = "update")
    git add .
    git commit -m $msg
    git push
}

function gst { git status --short }
function glog { git log --oneline -10 }

# Directory operations
function mkcd { 
    param([string]$path)
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    Set-Location $path
}

function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function ~ { Set-Location $env:USERPROFILE }

# System management
function sys-update {
    if (Get-Command scoop -ErrorAction SilentlyContinue) { 
        scoop update *
        if ($LASTEXITCODE -ne 0) { return }
    }
    if (Get-Command winget -ErrorAction SilentlyContinue) { 
        winget upgrade --all
        if ($LASTEXITCODE -ne 0) { return }
    }
}

function swp { 
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop cleanup *
        scoop cache rm *
    }
}

# Utility tools
function which { param($cmd) (Get-Command $cmd).Source }
function reload { . $PROFILE }
function edit-profile { code $PROFILE }

# Quick system information
function sysinfo {
    $os = (Get-CimInstance Win32_OperatingSystem).Caption
    $cpu = (Get-CimInstance Win32_Processor).Name
    $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    
    Write-Host "System Information" -ForegroundColor Cyan
    Write-Host "OS: $os" -ForegroundColor White
    Write-Host "CPU: $cpu" -ForegroundColor White
    Write-Host "RAM: ${ram}GB" -ForegroundColor White
}

# Configuration information
function config-info {
    Write-Host "Dotfiles Configuration Information" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host "Configuration Directory: $(Split-Path $PROFILE -Parent)" -ForegroundColor White
    Write-Host "Profile Mode: Standard" -ForegroundColor White
    Write-Host ""
    Write-Host "Core Commands:" -ForegroundColor Yellow
    Write-Host "  Git: ngc, gst, glog" -ForegroundColor Gray
    Write-Host "  System: sys-update, swp, sysinfo" -ForegroundColor Gray
    Write-Host "  Navigation: mkcd, .., ..., ~" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Usage Help: Get-Help <command-name>" -ForegroundColor Green
}

# Configuration performance analysis
function profile-perf {
    Write-Host "PowerShell Configuration Performance Report" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    
    # Intelligent configuration directory detection
    $configDir = if ($env:USERPROFILE -and (Test-Path (Join-Path $env:USERPROFILE ".powershell"))) {
        Join-Path $env:USERPROFILE ".powershell"
    } elseif (Test-Path ".\.powershell") {
        Resolve-Path ".\.powershell"
    } elseif (Test-Path ".\powershell\.powershell") {
        Resolve-Path ".\powershell\.powershell"
    } else {
        Split-Path $PROFILE -Parent
    }
    
    $profilePath = if (Test-Path (Join-Path (Split-Path $configDir -Parent) "Microsoft.PowerShell_profile.ps1")) {
        Join-Path (Split-Path $configDir -Parent) "Microsoft.PowerShell_profile.ps1"
    } else {
        $PROFILE
    }
    
    Write-Host "Configuration File Analysis:" -ForegroundColor Yellow
    Write-Host "  Main Profile: $profilePath" -ForegroundColor Gray
    Write-Host "  Config Directory: $configDir" -ForegroundColor Gray
    Write-Host ""
    
    # Check each configuration file
    $configFiles = @("functions", "aliases", "history", "keybindings", "tools", "theme", "extra")
    $totalSize = 0
    
    Write-Host "Configuration File Status:" -ForegroundColor Yellow
    foreach ($config in $configFiles) {
        $configPath = Join-Path $configDir "$config.ps1"
        if (Test-Path $configPath) {
            $size = (Get-Item $configPath).Length
            $totalSize += $size
            $sizeKB = [math]::Round($size / 1KB, 2)
            Write-Host "  OK $config.ps1 (${sizeKB}KB)" -ForegroundColor Green
        } else {
            Write-Host "  ERROR $config.ps1 (missing)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Performance Metrics:" -ForegroundColor Yellow
    Write-Host "  Total Config Size: $([math]::Round($totalSize / 1KB, 2))KB" -ForegroundColor White
    Write-Host "  Profile Mode: Standard" -ForegroundColor White
    
    # Module loading status
    $loadedModules = Get-Module | Where-Object { $_.ModuleType -eq 'Script' -or $_.Name -like '*profile*' }
    Write-Host "  Loaded Modules: $($loadedModules.Count)" -ForegroundColor White
    
    # Startup suggestions
    Write-Host ""
    Write-Host "Performance Optimization Suggestions:" -ForegroundColor Green
    if ($totalSize -gt 50KB) {
        Write-Host "  • Configuration files are large, consider trimming unnecessary features" -ForegroundColor Gray
    }
    Write-Host "  • Use 'reload' to reload configuration" -ForegroundColor Gray
}

# Missing utility functions
function New-Directory {
    param([string]$Path)
    New-Item -ItemType Directory -Path $Path -Force
}

function Get-FileSize {
    param([string]$Path)
    if (Test-Path $Path) {
        $item = Get-Item $Path
        if ($item.PSIsContainer) {
            $size = (Get-ChildItem $Path -Recurse -File | Measure-Object -Property Length -Sum).Sum
        } else {
            $size = $item.Length
        }
        
        # Format file size
        if ($size -gt 1GB) {
            "{0:N2} GB" -f ($size / 1GB)
        } elseif ($size -gt 1MB) {
            "{0:N2} MB" -f ($size / 1MB)
        } elseif ($size -gt 1KB) {
            "{0:N2} KB" -f ($size / 1KB)
        } else {
            "$size bytes"
        }
    } else {
        Write-Error "Path not found: $Path"
    }
}

function Start-Elevated {
    param(
        [string]$Command,
        [string[]]$Arguments = @()
    )
    
    if (-not $Command) {
        # If no command specified, start new PowerShell session as administrator
        Start-Process pwsh -Verb RunAs
    } else {
        # Run specified command as administrator
        $argumentList = if ($Arguments.Count -gt 0) { $Arguments -join ' ' } else { '' }
        Start-Process $Command -ArgumentList $argumentList -Verb RunAs
    }
}