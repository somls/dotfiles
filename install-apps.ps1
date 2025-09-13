# =============================================================================
# Application Installation Script (install-apps.ps1)
# Automated application installation based on configs/scoop/packages.txt
# =============================================================================

param(
    [string]$Category = "",
    [string[]]$Apps = @(),
    [switch]$List,
    [switch]$DryRun,
    [switch]$Force,
    [switch]$SkipScoop
)

# Script configuration
$PackagesFile = Join-Path $PSScriptRoot "configs\scoop\packages.txt"
$ScoopConfigDir = Join-Path $PSScriptRoot "configs\scoop"

# Color output functions
function Write-Status { param($Message, $Color = "White") Write-Host $Message -ForegroundColor $Color }
function Write-Success { param($Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }

Write-Status "Application Installation Manager" "Cyan"
Write-Status "================================" "Cyan"

# Check packages list file
if (-not (Test-Path $PackagesFile)) {
    Write-Error "Packages list file not found: $PackagesFile"
    exit 1
}

# Parse packages.txt
function Get-PackageCategories {
    $content = Get-Content $PackagesFile -Raw -Encoding UTF8
    $categories = @{}
    $currentCategory = ""

    foreach ($line in ($content -split "`n")) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { continue }

        if ($line.StartsWith("[") -and $line.EndsWith("]")) {
            $currentCategory = $line.Substring(1, $line.Length - 2)
            $categories[$currentCategory] = @()
        } elseif ($currentCategory -ne "" -and -not $line.Contains("=")) {
            $categories[$currentCategory] += $line
        }
    }

    return $categories
}

$PackageCategories = Get-PackageCategories

# List available package categories
if ($List) {
    Write-Status "Available Application Categories:" "Yellow"
    Write-Status "=================================" "Yellow"

    foreach ($cat in $PackageCategories.Keys) {
        $count = $PackageCategories[$cat].Count
        Write-Status "- $cat ($count apps)" "Green"

        foreach ($app in $PackageCategories[$cat]) {
            $installed = if (Get-Command $app -ErrorAction SilentlyContinue) { "INSTALLED" } else { "NOT INSTALLED" }
            Write-Status "  [$installed] $app" "Gray"
        }
        Write-Status ""
    }
    exit 0
}

# Scoop installation and configuration
function Install-Scoop {
    if (-not $SkipScoop -and -not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Info "Installing Scoop package manager..."

        if ($DryRun) {
            Write-Info "[DryRun] Would install Scoop"
            return $true
        }

        try {
            # Set execution policy
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

            # Install Scoop
            Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

            # Add common buckets
            scoop bucket add extras 2>$null
            scoop bucket add versions 2>$null
            scoop bucket add nerd-fonts 2>$null

            Write-Success "Scoop installation completed"
            return $true
        } catch {
            Write-Error "Scoop installation failed: $($_.Exception.Message)"
            return $false
        }
    } else {
        Write-Info "Scoop already installed or skipped"
        return $true
    }
}

# Install applications via Scoop
function Install-Applications {
    param(
        [array]$AppList,
        [string]$CategoryName
    )

    Write-Status ""
    Write-Status "Installing $CategoryName applications..." "Yellow"

    $successCount = 0
    $failCount = 0

    foreach ($app in $AppList) {
        Write-Status "Processing: $app" "Gray"

        # Check if already installed
        $isInstalled = $false
        try {
            $scoopList = scoop list 2>$null
            $isInstalled = $scoopList -match "^$app\s+"
        } catch {
            $isInstalled = $false
        }

        if ($isInstalled -and -not $Force) {
            Write-Info "  Already installed: $app"
            $successCount++
            continue
        }

        if ($DryRun) {
            Write-Info "  [DryRun] Would install: $app"
            $successCount++
            continue
        }

        # Install application
        try {
            $output = scoop install $app 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "  Installed: $app"
                $successCount++
            } else {
                Write-Warning "  Installation completed with warnings: $app"
                $successCount++
            }
        } catch {
            Write-Error "  Failed to install: $app - $($_.Exception.Message)"
            $failCount++
        }
    }

    Write-Status ""
    Write-Status "$CategoryName Results: $successCount succeeded, $failCount failed" "Cyan"
    return @{ Success = $successCount; Failed = $failCount }
}

# Configure Scoop settings
function Configure-Scoop {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Warning "Scoop not available, skipping configuration"
        return
    }

    Write-Info "Configuring Scoop settings..."

    if ($DryRun) {
        Write-Info "[DryRun] Would configure Scoop settings"
        return
    }

    try {
        # Apply Scoop configuration if available
        $scoopConfigFile = Join-Path $ScoopConfigDir "config.json"
        if (Test-Path $scoopConfigFile) {
            Write-Info "Applying Scoop configuration from: $scoopConfigFile"
            $configContent = Get-Content $scoopConfigFile -Raw | ConvertFrom-Json

            foreach ($setting in $configContent.PSObject.Properties) {
                scoop config $setting.Name $setting.Value 2>$null
            }
            Write-Success "Scoop configuration applied"
        }

        # Update Scoop and apps
        Write-Info "Updating Scoop and applications..."
        scoop update 2>$null
        scoop cleanup * 2>$null

        Write-Success "Scoop configuration completed"
    } catch {
        Write-Warning "Scoop configuration failed: $($_.Exception.Message)"
    }
}

# Main installation logic
Write-Info "Starting application installation process..."

# Install Scoop if needed
$scoopReady = Install-Scoop
if (-not $scoopReady) {
    Write-Error "Scoop installation failed, cannot continue"
    exit 1
}

# Determine which categories to install
$CategoriesToInstall = @()

if ($Apps.Count -gt 0) {
    # Install specific applications
    Write-Info "Installing specific applications: $($Apps -join ', ')"
    $results = Install-Applications -AppList $Apps -CategoryName "Custom"
} elseif ($Category -ne "") {
    # Install specific category
    if ($PackageCategories.ContainsKey($Category)) {
        Write-Info "Installing category: $Category"
        $results = Install-Applications -AppList $PackageCategories[$Category] -CategoryName $Category
    } else {
        Write-Error "Category not found: $Category"
        Write-Info "Available categories: $($PackageCategories.Keys -join ', ')"
        exit 1
    }
} else {
    # Interactive category selection
    Write-Status ""
    Write-Status "Available Categories:" "Yellow"
    $i = 0
    $categoryList = @($PackageCategories.Keys)

    foreach ($cat in $categoryList) {
        $count = $PackageCategories[$cat].Count
        Write-Status "  [$($i+1)] $cat ($count apps)" "Green"
        $i++
    }
    Write-Status "  [A] All categories" "Cyan"
    Write-Status "  [Q] Quit" "Red"

    do {
        $choice = Read-Host "`nSelect category [1-$($categoryList.Count)/A/Q]"

        if ($choice -eq "Q" -or $choice -eq "q") {
            Write-Info "Installation cancelled"
            exit 0
        } elseif ($choice -eq "A" -or $choice -eq "a") {
            $CategoriesToInstall = $categoryList
            break
        } elseif ($choice -match '^\d+$') {
            $index = [int]$choice - 1
            if ($index -ge 0 -and $index -lt $categoryList.Count) {
                $CategoriesToInstall = @($categoryList[$index])
                break
            }
        }
        Write-Warning "Invalid selection, please try again"
    } while ($true)

    # Install selected categories
    $totalResults = @{ Success = 0; Failed = 0 }

    foreach ($cat in $CategoriesToInstall) {
        $results = Install-Applications -AppList $PackageCategories[$cat] -CategoryName $cat
        $totalResults.Success += $results.Success
        $totalResults.Failed += $results.Failed
    }

    $results = $totalResults
}

# Configure Scoop after installation
if (-not $DryRun -and $scoopReady) {
    Configure-Scoop
}

# Final summary
Write-Status ""
Write-Status "Installation Summary" "Cyan"
Write-Status "===================" "Cyan"

if ($results) {
    Write-Status "Total applications processed: $($results.Success + $results.Failed)" "White"
    Write-Status "Successfully installed: $($results.Success)" "Green"
    Write-Status "Failed installations: $($results.Failed)" "Red"

    $successRate = if (($results.Success + $results.Failed) -gt 0) {
        [math]::Round(($results.Success / ($results.Success + $results.Failed)) * 100, 1)
    } else { 0 }
    Write-Status "Success rate: $successRate%" $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })
}

if ($DryRun) {
    Write-Info "This was a dry run. Remove -DryRun parameter to perform actual installation"
} else {
    Write-Success "Application installation process completed!"
}

Write-Status ""
Write-Status "Usage Tips:" "Yellow"
Write-Status "- Use -List to see all available applications and categories" "Gray"
Write-Status "- Use -Category Essential to install essential applications" "Gray"
Write-Status "- Use -Apps git,nodejs to install specific applications" "Gray"
Write-Status "- Use -DryRun to preview operations without installing" "Gray"
Write-Status "- Use -Force to reinstall already installed applications" "Gray"
Write-Status ""
Write-Info "Next steps: Run .\dev-symlink.ps1 to set up configuration links"
