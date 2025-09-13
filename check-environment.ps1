# =============================================================================
# 环境检查和验证脚本 (check-environment.ps1)
# 全面检查配置状态、应用安装和环境兼容性
# =============================================================================

param(
    [switch]$Detailed,
    [switch]$Fix,
    [string]$ConfigType = "",
    [switch]$Apps,
    [switch]$Config,
    [switch]$All
)

# 脚本配置
$ConfigsDir = Join-Path $PSScriptRoot "configs"
$PackagesFile = Join-Path $PSScriptRoot "configs\scoop\packages.txt"

# 检查结果统计
$CheckResults = @{
    Passed = 0
    Failed = 0
    Warnings = 0
    Total = 0
}

# 颜色输出函数
function Write-Status { param($Message, $Color = "White") Write-Host $Message -ForegroundColor $Color }
function Write-Success { param($Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }

# 检查项目函数
function Test-Item {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [string]$Details = "",
        [bool]$Critical = $false,
        [scriptblock]$Fix = $null
    )

    $script:CheckResults.Total++

    try {
        $result = & $Test
        if ($result) {
            Write-Success $Name
            if ($Detailed -and $Details) {
                Write-Status "    $Details" "Gray"
            }
            $script:CheckResults.Passed++
            return $true
        } else {
            if ($Critical) {
                Write-Error $Name
                $script:CheckResults.Failed++
            } else {
                Write-Warning $Name
                $script:CheckResults.Warnings++
            }

            if ($Details) {
                Write-Status "    $Details" "Gray"
            }

            if ($Fix -and $script:Fix) {
                Write-Info "    Attempting auto-fix..."
                try {
                    & $Fix
                    Write-Success "    Fix completed"
                } catch {
                    Write-Error "    Fix failed: $($_.Exception.Message)"
                }
            }

            return $false
        }
    } catch {
        Write-Error "$Name - Check failed: $($_.Exception.Message)"
        $script:CheckResults.Failed++
        return $false
    }
}

Write-Status "Environment Check and Validation" "Cyan"
Write-Status "=================================" "Cyan"

# 确定检查范围
$checkConfig = $Config -or $All -or (-not $Apps -and $ConfigType -eq "")
$checkApps = $Apps -or $All -or (-not $Config -and $ConfigType -eq "")

# ============================================================================
# 基础环境检查
# ============================================================================
if ($checkConfig -or $checkApps) {
    Write-Status ""
    Write-Status "Basic Environment" "Yellow"

    Test-Item "PowerShell Version Compatible" {
        $version = $PSVersionTable.PSVersion
        $version.Major -ge 5
    } "Current version: $($PSVersionTable.PSVersion)" $true

    Test-Item "Execution Policy Allows Scripts" {
        $policy = Get-ExecutionPolicy -Scope CurrentUser
        $policy -ne "Restricted"
    } "Current policy: $(Get-ExecutionPolicy -Scope CurrentUser)" $false {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    }

    Test-Item "Dotfiles Directory Structure" {
        (Test-Path $ConfigsDir) -and (Test-Path $PackagesFile)
    } "configs directory and packages.txt file" $true

    Test-Item "Git Available" {
        $null -ne (Get-Command git -ErrorAction SilentlyContinue)
    } "Git command line tool" $false
}

# ============================================================================
# 应用程序检查
# ============================================================================
if ($checkApps) {
    Write-Status ""
    Write-Status "Applications Status" "Yellow"

    # Scoop检查
    Test-Item "Scoop Package Manager" {
        $null -ne (Get-Command scoop -ErrorAction SilentlyContinue)
    } "Scoop package manager" $false {
        Write-Info "Install Scoop: .\install-apps.ps1"
    }

    # 解析并检查关键应用
    if (Test-Path $PackagesFile) {
        $packagesContent = Get-Content $PackagesFile -Raw
        $essentialApps = @()
        $lines = $packagesContent -split "`n"
        $inEssential = $false

        foreach ($line in $lines) {
            $line = $line.Trim()
            if ($line -eq "[Essential]") {
                $inEssential = $true
                continue
            } elseif ($line.StartsWith("[") -and $line.EndsWith("]")) {
                $inEssential = $false
                continue
            } elseif ($inEssential -and $line -ne "" -and -not $line.StartsWith("#")) {
                $essentialApps += $line
            }
        }

        foreach ($app in $essentialApps) {
            Test-Item "Application: $app" {
                $cmd = Get-Command $app -ErrorAction SilentlyContinue
                $scoopInstalled = if (Get-Command scoop -ErrorAction SilentlyContinue) {
                    (scoop list 2>$null) -match $app
                } else { $false }

                $cmd -or $scoopInstalled
            } "Essential category application" $false
        }
    }
}

# ============================================================================
# 配置文件检查
# ============================================================================
if ($checkConfig) {
    Write-Status ""
    Write-Status "Configuration Files Status" "Yellow"

    # PowerShell配置
    if ($ConfigType -eq "" -or $ConfigType -eq "powershell") {
        Test-Item "PowerShell Profile Exists" {
            Test-Path $PROFILE
        } "Main PowerShell config file: $PROFILE" $false

        Test-Item "PowerShell Module Directory" {
            $moduleDir = Join-Path (Split-Path $PROFILE) ".powershell"
            Test-Path $moduleDir
        } "PowerShell extension modules directory" $false

        Test-Item "PowerShell Config Validity" {
            if (Test-Path $PROFILE) {
                try {
                    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $PROFILE -Raw), [ref]$null)
                    $true
                } catch {
                    $false
                }
            } else {
                $false
            }
        } "PowerShell Profile syntax check" $false
    }

    # Git配置
    if ($ConfigType -eq "" -or $ConfigType -eq "git") {
        Test-Item "Git Global Config" {
            Test-Path "$env:USERPROFILE\.gitconfig"
        } "Git global configuration file" $false

        Test-Item "Git User Config" {
            $userName = git config --global user.name 2>$null
            $userEmail = git config --global user.email 2>$null
            $userName -and $userEmail -and $userName -ne "Default User"
        } "Git username and email configuration" $false {
            Write-Info "Run .\user-setup.ps1 to configure Git user information"
        }
    }

    # Windows Terminal配置
    if ($ConfigType -eq "" -or $ConfigType -eq "terminal") {
        $terminalSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        Test-Item "Windows Terminal Config" {
            Test-Path $terminalSettingsPath
        } "Windows Terminal settings file" $false
    }

    # Starship配置
    if ($ConfigType -eq "" -or $ConfigType -eq "starship") {
        Test-Item "Starship Prompt" {
            $null -ne (Get-Command starship -ErrorAction SilentlyContinue)
        } "Starship command line tool" $false

        Test-Item "Starship Config File" {
            Test-Path "$env:USERPROFILE\.config\starship.toml"
        } "Starship configuration file" $false
    }

    # Neovim配置
    if ($ConfigType -eq "" -or $ConfigType -eq "neovim") {
        Test-Item "Neovim Editor" {
            $null -ne (Get-Command nvim -ErrorAction SilentlyContinue)
        } "Neovim editor" $false

        Test-Item "Neovim Config" {
            Test-Path "$env:LOCALAPPDATA\nvim"
        } "Neovim configuration directory" $false
    }
}

# ============================================================================
# 配置同步检查
# ============================================================================
if ($checkConfig) {
    Write-Status ""
    Write-Status "Configuration Sync Status" "Yellow"

    # 检查configs目录中的配置是否与系统配置一致
    $configMappings = @{
        "powershell\Microsoft.PowerShell_profile.ps1" = $PROFILE
        "git\gitconfig" = "$env:USERPROFILE\.gitconfig"
        "starship\starship.toml" = "$env:USERPROFILE\.config\starship.toml"
    }

    foreach ($mapping in $configMappings.GetEnumerator()) {
        $sourcePath = Join-Path $ConfigsDir $mapping.Key
        $targetPath = $mapping.Value
        $configName = Split-Path $mapping.Key -Parent

        Test-Item "Config Sync: $configName" {
            if ((Test-Path $sourcePath) -and (Test-Path $targetPath)) {
                $sourceContent = Get-Content $sourcePath -Raw -ErrorAction SilentlyContinue
                $targetContent = Get-Content $targetPath -Raw -ErrorAction SilentlyContinue

                # 简单的内容比较（忽略行尾差异）
                $sourceContent = $sourceContent -replace "`r`n", "`n" -replace "`r", "`n"
                $targetContent = $targetContent -replace "`r`n", "`n" -replace "`r", "`n"

                $sourceContent -eq $targetContent
            } else {
                $false
            }
        } "Source config matches system config" $false {
            Write-Info "Run .\deploy-config.ps1 -ConfigType $configName to sync config"
        }
    }
}

# ============================================================================
# 结果报告
# ============================================================================
Write-Status ""
Write-Status "Check Results Report" "Cyan"
Write-Status "===================" "Cyan"

$totalChecks = $CheckResults.Total
$passedChecks = $CheckResults.Passed
$failedChecks = $CheckResults.Failed
$warningChecks = $CheckResults.Warnings

$successRate = if ($totalChecks -gt 0) { [math]::Round(($passedChecks / $totalChecks) * 100, 1) } else { 0 }

Write-Status "Total Checks: $totalChecks" "White"
Write-Status "Passed: $passedChecks" "Green"
Write-Status "Warnings: $warningChecks" "Yellow"
Write-Status "Failed: $failedChecks" "Red"
Write-Status "Success Rate: $successRate%" $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })

Write-Status ""

if ($successRate -ge 90) {
    Write-Success "Environment status excellent! All critical configurations are ready."
} elseif ($successRate -ge 70) {
    Write-Warning "Environment is basically ready, recommend fixing warning items."
} else {
    Write-Error "Multiple issues found, need to fix before normal use."
}

Write-Status ""
Write-Status "Recommended Actions:" "Yellow"
if ($failedChecks -gt 0 -or $warningChecks -gt 0) {
    Write-Status "• Run .\install-apps.ps1 to install missing applications" "Gray"
    Write-Status "• Run .\deploy-config.ps1 to deploy configuration files" "Gray"
    Write-Status "• Run .\user-setup.ps1 to configure personal information" "Gray"
    if ($Fix) {
        Write-Status "• Auto-fix was attempted using -Fix parameter" "Gray"
    } else {
        Write-Status "• Use -Fix parameter to attempt automatic fixes" "Gray"
    }
}

Write-Status ""
Write-Status "Usage Tips:" "Cyan"
Write-Status "• Use -Apps to check only application status" "Gray"
Write-Status "• Use -Config to check only configuration file status" "Gray"
Write-Status "• Use -ConfigType powershell to check specific configuration" "Gray"
Write-Status "• Use -Detailed to view detailed information" "Gray"
Write-Status "• Use -Fix to attempt automatic problem fixes" "Gray"
