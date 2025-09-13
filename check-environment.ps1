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
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }

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
                Write-Info "    尝试自动修复..."
                try {
                    & $Fix
                    Write-Success "    修复完成"
                } catch {
                    Write-Error "    修复失败: $($_.Exception.Message)"
                }
            }

            return $false
        }
    } catch {
        Write-Error "$Name - 检查出错: $($_.Exception.Message)"
        $script:CheckResults.Failed++
        return $false
    }
}

Write-Status "🔍 环境检查和验证" "Cyan"
Write-Status "=================" "Cyan"

# 确定检查范围
$checkConfig = $Config -or $All -or (-not $Apps -and $ConfigType -eq "")
$checkApps = $Apps -or $All -or (-not $Config -and $ConfigType -eq "")

# ============================================================================
# 基础环境检查
# ============================================================================
if ($checkConfig -or $checkApps) {
    Write-Status ""
    Write-Status "🏗️ 基础环境" "Yellow"

    Test-Item "PowerShell版本兼容" {
        $version = $PSVersionTable.PSVersion
        $version.Major -ge 5
    } "当前版本: $($PSVersionTable.PSVersion)" $true

    Test-Item "执行策略允许脚本运行" {
        $policy = Get-ExecutionPolicy -Scope CurrentUser
        $policy -ne "Restricted"
    } "当前策略: $(Get-ExecutionPolicy -Scope CurrentUser)" $false {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    }

    Test-Item "Dotfiles目录结构" {
        (Test-Path $ConfigsDir) -and (Test-Path $PackagesFile)
    } "configs目录和packages.txt文件" $true

    Test-Item "Git可用" {
        $null -ne (Get-Command git -ErrorAction SilentlyContinue)
    } "Git命令行工具" $false
}

# ============================================================================
# 应用程序检查
# ============================================================================
if ($checkApps) {
    Write-Status ""
    Write-Status "📦 应用程序状态" "Yellow"

    # Scoop检查
    Test-Item "Scoop包管理器" {
        $null -ne (Get-Command scoop -ErrorAction SilentlyContinue)
    } "Scoop包管理器" $false {
        Write-Info "安装Scoop: .\install-apps.ps1"
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
            Test-Item "应用: $app" {
                $cmd = Get-Command $app -ErrorAction SilentlyContinue
                $scoopInstalled = if (Get-Command scoop -ErrorAction SilentlyContinue) {
                    (scoop list 2>$null) -match $app
                } else { $false }

                $cmd -or $scoopInstalled
            } "Essential类别应用" $false
        }
    }
}

# ============================================================================
# 配置文件检查
# ============================================================================
if ($checkConfig) {
    Write-Status ""
    Write-Status "⚙️ 配置文件状态" "Yellow"

    # PowerShell配置
    if ($ConfigType -eq "" -or $ConfigType -eq "powershell") {
        Test-Item "PowerShell Profile存在" {
            Test-Path $PROFILE
        } "主PowerShell配置文件: $PROFILE" $false

        Test-Item "PowerShell模块目录" {
            $moduleDir = Join-Path (Split-Path $PROFILE) ".powershell"
            Test-Path $moduleDir
        } "PowerShell扩展模块目录" $false

        Test-Item "PowerShell配置有效性" {
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
        } "PowerShell Profile语法检查" $false
    }

    # Git配置
    if ($ConfigType -eq "" -or $ConfigType -eq "git") {
        Test-Item "Git全局配置" {
            Test-Path "$env:USERPROFILE\.gitconfig"
        } "Git全局配置文件" $false

        Test-Item "Git用户配置" {
            $userName = git config --global user.name 2>$null
            $userEmail = git config --global user.email 2>$null
            $userName -and $userEmail -and $userName -ne "Default User"
        } "Git用户名和邮箱配置" $false {
            Write-Info "运行 .\setup-user-config.ps1 配置Git用户信息"
        }
    }

    # Windows Terminal配置
    if ($ConfigType -eq "" -or $ConfigType -eq "terminal") {
        $terminalSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        Test-Item "Windows Terminal配置" {
            Test-Path $terminalSettingsPath
        } "Windows Terminal设置文件" $false
    }

    # Starship配置
    if ($ConfigType -eq "" -or $ConfigType -eq "starship") {
        Test-Item "Starship提示符" {
            $null -ne (Get-Command starship -ErrorAction SilentlyContinue)
        } "Starship命令行工具" $false

        Test-Item "Starship配置文件" {
            Test-Path "$env:USERPROFILE\.config\starship.toml"
        } "Starship配置文件" $false
    }

    # Neovim配置
    if ($ConfigType -eq "" -or $ConfigType -eq "neovim") {
        Test-Item "Neovim编辑器" {
            $null -ne (Get-Command nvim -ErrorAction SilentlyContinue)
        } "Neovim编辑器" $false

        Test-Item "Neovim配置" {
            Test-Path "$env:LOCALAPPDATA\nvim"
        } "Neovim配置目录" $false
    }
}

# ============================================================================
# 配置同步检查
# ============================================================================
if ($checkConfig) {
    Write-Status ""
    Write-Status "🔄 配置同步状态" "Yellow"

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

        Test-Item "配置同步: $configName" {
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
        } "源配置与系统配置一致性" $false {
            Write-Info "运行 .\deploy-config.ps1 -ConfigType $configName 同步配置"
        }
    }
}

# ============================================================================
# 结果报告
# ============================================================================
Write-Status ""
Write-Status "📊 检查结果报告" "Cyan"
Write-Status "===============" "Cyan"

$totalChecks = $CheckResults.Total
$passedChecks = $CheckResults.Passed
$failedChecks = $CheckResults.Failed
$warningChecks = $CheckResults.Warnings

$successRate = if ($totalChecks -gt 0) { [math]::Round(($passedChecks / $totalChecks) * 100, 1) } else { 0 }

Write-Status "检查项目: $totalChecks" "White"
Write-Status "通过: $passedChecks" "Green"
Write-Status "警告: $warningChecks" "Yellow"
Write-Status "失败: $failedChecks" "Red"
Write-Status "成功率: $successRate%" $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })

Write-Status ""

if ($successRate -ge 90) {
    Write-Success "🎉 环境状态优秀！所有关键配置都已就绪。"
} elseif ($successRate -ge 70) {
    Write-Warning "⚠️ 环境基本就绪，建议修复警告项目。"
} else {
    Write-Error "❌ 发现多个问题，需要修复后才能正常使用。"
}

Write-Status ""
Write-Status "🛠️ 建议操作:" "Yellow"
if ($failedChecks -gt 0 -or $warningChecks -gt 0) {
    Write-Status "• 运行 .\install-apps.ps1 安装缺失的应用" "Gray"
    Write-Status "• 运行 .\deploy-config.ps1 部署配置文件" "Gray"
    Write-Status "• 运行 .\setup-user-config.ps1 配置个人信息" "Gray"
    if ($Fix) {
        Write-Status "• 使用 -Fix 参数已尝试自动修复" "Gray"
    } else {
        Write-Status "• 使用 -Fix 参数尝试自动修复问题" "Gray"
    }
}

Write-Status ""
Write-Status "💡 使用提示:" "Cyan"
Write-Status "• 使用 -Apps 仅检查应用程序状态" "Gray"
Write-Status "• 使用 -Config 仅检查配置文件状态" "Gray"
Write-Status "• 使用 -ConfigType powershell 检查特定配置" "Gray"
Write-Status "• 使用 -Detailed 查看详细信息" "Gray"
Write-Status "• 使用 -Fix 尝试自动修复问题" "Gray"
