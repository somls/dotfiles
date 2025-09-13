# =============================================================================
# 应用安装脚本 (install-apps.ps1)
# 基于configs/scoop/packages.txt的自动化应用安装
# =============================================================================

param(
    [string]$Category = "",
    [string[]]$Apps = @(),
    [switch]$List,
    [switch]$DryRun,
    [switch]$Force,
    [switch]$SkipScoop
)

# 脚本配置
$PackagesFile = Join-Path $PSScriptRoot "configs\scoop\packages.txt"
$ScoopConfigDir = Join-Path $PSScriptRoot "configs\scoop"

# 颜色输出函数
function Write-Status { param($Message, $Color = "White") Write-Host $Message -ForegroundColor $Color }
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }

Write-Status "📦 应用程序安装管理" "Cyan"
Write-Status "==================" "Cyan"

# 检查包列表文件
if (-not (Test-Path $PackagesFile)) {
    Write-Error "包列表文件不存在: $PackagesFile"
    exit 1
}

# 解析packages.txt
function Get-PackageCategories {
    $content = Get-Content $PackagesFile -Raw
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

# 列出可用包类别
if ($List) {
    Write-Status "📋 可用应用类别:" "Yellow"
    Write-Status "=================" "Yellow"
    foreach ($cat in $PackageCategories.Keys) {
        $count = $PackageCategories[$cat].Count
        Write-Status "• $cat ($count 个应用)" "Green"
        foreach ($app in $PackageCategories[$cat]) {
            $installed = if (Get-Command $app -ErrorAction SilentlyContinue) { "✓" } else { "✗" }
            Write-Status "  $installed $app" "Gray"
        }
        Write-Status ""
    }
    exit 0
}

# Scoop安装和配置
function Install-Scoop {
    if (-not $SkipScoop -and -not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Info "安装 Scoop 包管理器..."

        if ($DryRun) {
            Write-Info "[预览] 将安装 Scoop"
            return $true
        }

        try {
            # 设置执行策略
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

            # 安装Scoop
            Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

            # 添加常用bucket
            scoop bucket add extras
            scoop bucket add versions
            scoop bucket add nerd-fonts

            Write-Success "Scoop 安装完成"
            return $true
        } catch {
            Write-Error "Scoop 安装失败: $($_.Exception.Message)"
            return $false
        }
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Info "Scoop 已安装，正在更新..."
        if (-not $DryRun) {
            scoop update
        }
        return $true
    } else {
        Write-Info "跳过 Scoop 安装"
        return $false
    }
}

# 安装应用函数
function Install-Applications {
    param($AppList, $CategoryName = "")

    if ($AppList.Count -eq 0) { return }

    $displayName = if ($CategoryName) { "$CategoryName 类别" } else { "指定应用" }
    Write-Status "📥 安装 $displayName ($($AppList.Count) 个应用)" "Yellow"

    $installed = 0
    $skipped = 0
    $failed = 0

    foreach ($app in $AppList) {
        Write-Status "  处理: $app" "Gray"

        # 检查是否已安装
        $isInstalled = $false
        try {
            # 检查Scoop是否已安装该应用
            $scoopList = if (Get-Command scoop -ErrorAction SilentlyContinue) {
                scoop list 2>$null | Where-Object { $_ -match $app }
            }

            # 检查系统命令
            $systemCommand = Get-Command $app -ErrorAction SilentlyContinue

            $isInstalled = $scoopList -or $systemCommand
        } catch {
            $isInstalled = $false
        }

        if ($isInstalled -and -not $Force) {
            Write-Success "    已安装，跳过"
            $skipped++
            continue
        }

        # 执行安装
        if ($DryRun) {
            Write-Info "    [预览] scoop install $app"
        } else {
            try {
                $result = scoop install $app 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "    安装完成"
                    $installed++
                } else {
                    Write-Warning "    安装可能有问题: $result"
                    $failed++
                }
            } catch {
                Write-Error "    安装失败: $($_.Exception.Message)"
                $failed++
            }
        }
    }

    Write-Status "  结果: 安装 $installed, 跳过 $skipped, 失败 $failed" "Cyan"
}

# 主安装流程
Write-Status ""

# 1. 安装Scoop
$scoopReady = Install-Scoop

if (-not $scoopReady -and -not $SkipScoop) {
    Write-Error "Scoop未准备就绪，无法继续安装应用"
    exit 1
}

# 2. 确定要安装的应用
$AppsToInstall = @()
$InstallCategory = ""

if ($Apps.Count -gt 0) {
    # 安装指定应用
    $AppsToInstall = $Apps
} elseif ($Category -ne "") {
    # 安装指定类别
    if ($PackageCategories.ContainsKey($Category)) {
        $AppsToInstall = $PackageCategories[$Category]
        $InstallCategory = $Category
    } else {
        Write-Error "类别 '$Category' 不存在。使用 -List 查看可用类别。"
        exit 1
    }
} else {
    # 交互式选择
    Write-Status "可用类别:" "Yellow"
    $categoryList = @($PackageCategories.Keys)
    for ($i = 0; $i -lt $categoryList.Count; $i++) {
        $cat = $categoryList[$i]
        $count = $PackageCategories[$cat].Count
        Write-Status "[$($i+1)] $cat ($count 个应用)" "Green"
    }
    Write-Status "[A] 所有类别" "Green"
    Write-Status "[Q] 退出" "Red"

    $choice = Read-Host "请选择要安装的类别"

    if ($choice -eq "Q" -or $choice -eq "q") {
        Write-Info "取消安装"
        exit 0
    } elseif ($choice -eq "A" -or $choice -eq "a") {
        $AppsToInstall = $PackageCategories.Values | ForEach-Object { $_ } | Sort-Object -Unique
        $InstallCategory = "全部"
    } elseif ($choice -match '^\d+$' -and [int]$choice -le $categoryList.Count -and [int]$choice -gt 0) {
        $selectedCat = $categoryList[[int]$choice - 1]
        $AppsToInstall = $PackageCategories[$selectedCat]
        $InstallCategory = $selectedCat
    } else {
        Write-Error "无效选择"
        exit 1
    }
}

# 3. 执行安装
if ($AppsToInstall.Count -eq 0) {
    Write-Warning "没有应用需要安装"
    exit 0
}

Install-Applications $AppsToInstall $InstallCategory

# 4. 配置Scoop
if (-not $DryRun -and $scoopReady) {
    Write-Status ""
    Write-Status "🔧 配置 Scoop" "Yellow"

    $scoopConfigExample = Join-Path $ScoopConfigDir "config.json.example"
    if (Test-Path $scoopConfigExample) {
        Write-Info "应用Scoop配置示例..."
        $userScoopDir = "$env:USERPROFILE\scoop"
        if (Test-Path $userScoopDir) {
            $userScoopConfig = Join-Path $userScoopDir "config.json"
            Copy-Item $scoopConfigExample $userScoopConfig -Force
            Write-Success "Scoop配置已应用"
        }
    }
}

# 5. 完成报告
Write-Status ""
Write-Status "📊 安装完成报告" "Cyan"
Write-Status "===============" "Cyan"

if ($DryRun) {
    Write-Info "这是预览模式，没有实际安装任何应用"
    Write-Info "移除 -DryRun 参数执行实际安装"
} else {
    Write-Success "应用安装流程完成！"
}

Write-Status ""
Write-Status "💡 使用提示:" "Yellow"
Write-Status "• 使用 -List 查看所有可用应用类别" "Gray"
Write-Status "• 使用 -Category Essential 安装基础应用" "Gray"
Write-Status "• 使用 -Apps git,neovim 安装指定应用" "Gray"
Write-Status "• 使用 -DryRun 预览安装操作" "Gray"
Write-Status ""
Write-Info "建议接下来运行: .\deploy-config.ps1 部署相关配置文件"
