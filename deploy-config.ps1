# =============================================================================
# 用户配置部署脚本 (deploy-config.ps1)
# 以configs文件夹为核心的配置部署系统
# =============================================================================

param(
    [string[]]$ConfigType = @(),
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Backup = $true,
    [switch]$List
)

# 脚本配置
$ConfigsDir = Join-Path $PSScriptRoot "configs"
$BackupDir = Join-Path $PSScriptRoot ".dotfiles-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# 配置映射表 - 定义每种配置的源目录和目标位置
$ConfigMappings = @{
    "powershell" = @{
        Source = "powershell"
        Targets = @(
            @{ Path = $PROFILE; IsFile = $true; Name = "PowerShell 7 Profile" },
            @{ Path = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"; IsFile = $true; Name = "PowerShell 5.1 Profile" },
            @{ Path = Join-Path (Split-Path $PROFILE) ".powershell"; IsFile = $false; Name = "PowerShell Modules" }
        )
    }
    "git" = @{
        Source = "git"
        Targets = @(
            @{ Path = "$env:USERPROFILE\.gitconfig"; IsFile = $true; Name = "Git Global Config" },
            @{ Path = "$env:USERPROFILE\.gitignore_global"; IsFile = $true; Name = "Git Global Ignore" },
            @{ Path = "$env:USERPROFILE\.gitmessage"; IsFile = $true; Name = "Git Commit Template" }
        )
    }
    "starship" = @{
        Source = "starship"
        Targets = @(
            @{ Path = "$env:USERPROFILE\.config\starship.toml"; IsFile = $true; Name = "Starship Config" }
        )
    }
    "terminal" = @{
        Source = "WindowsTerminal"
        Targets = @(
            @{ Path = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"; IsFile = $true; Name = "Windows Terminal" }
        )
    }
    "neovim" = @{
        Source = "neovim"
        Targets = @(
            @{ Path = "$env:LOCALAPPDATA\nvim"; IsFile = $false; Name = "Neovim Config" }
        )
    }
}

# 颜色输出函数
function Write-Status { param($Message, $Color = "White") Write-Host $Message -ForegroundColor $Color }
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }

# 列出可用配置
if ($List) {
    Write-Status "📋 可用配置类型:" "Cyan"
    Write-Status "==================" "Cyan"
    foreach ($config in $ConfigMappings.Keys) {
        $mapping = $ConfigMappings[$config]
        Write-Status "• $config" "Yellow"
        Write-Status "  源目录: configs\$($mapping.Source)" "Gray"
        Write-Status "  目标数量: $($mapping.Targets.Count)" "Gray"
        foreach ($target in $mapping.Targets) {
            $status = if (Test-Path $target.Path) { "✓" } else { "✗" }
            Write-Status "    $status $($target.Name): $($target.Path)" "Gray"
        }
        Write-Status ""
    }
    exit 0
}

Write-Status "🚀 Dotfiles 配置部署" "Cyan"
Write-Status "===================" "Cyan"

# 验证configs目录
if (-not (Test-Path $ConfigsDir)) {
    Write-Error "configs目录不存在: $ConfigsDir"
    exit 1
}

# 确定要部署的配置类型
$ConfigsToDeploy = if ($ConfigType.Count -gt 0) {
    $ConfigType | Where-Object { $ConfigMappings.ContainsKey($_) }
} else {
    $ConfigMappings.Keys
}

if ($ConfigsToDeploy.Count -eq 0) {
    Write-Error "没有有效的配置类型。使用 -List 查看可用选项。"
    exit 1
}

Write-Info "将部署配置: $($ConfigsToDeploy -join ', ')"

# 创建备份目录
if ($Backup -and -not $DryRun) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    Write-Info "备份目录: $BackupDir"
}

# 部署函数
function Deploy-Config {
    param($ConfigName, $Mapping)

    $sourceDir = Join-Path $ConfigsDir $Mapping.Source

    Write-Status ""
    Write-Status "📦 部署配置: $ConfigName" "Yellow"

    if (-not (Test-Path $sourceDir)) {
        Write-Warning "源目录不存在: $sourceDir"
        return
    }

    foreach ($target in $Mapping.Targets) {
        $targetPath = $target.Path
        $isFile = $target.IsFile
        $name = $target.Name

        Write-Status "  → $name" "Gray"
        Write-Status "    目标: $targetPath" "DarkGray"

        # 确保目标目录存在
        $targetDir = if ($isFile) { Split-Path $targetPath } else { Split-Path $targetPath }
        if ($targetDir -and -not (Test-Path $targetDir)) {
            if ($DryRun) {
                Write-Info "    [预览] 创建目录: $targetDir"
            } else {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                Write-Info "    创建目录: $targetDir"
            }
        }

        # 备份现有配置
        if ((Test-Path $targetPath) -and $Backup -and -not $DryRun) {
            $backupPath = Join-Path $BackupDir (Split-Path $targetPath -Leaf)
            if ($isFile) {
                Copy-Item $targetPath $backupPath -Force
            } else {
                Copy-Item $targetPath $backupPath -Recurse -Force
            }
            Write-Info "    已备份到: $backupPath"
        }

        # 确定源文件/目录
        $sourcePath = if ($isFile) {
            $fileName = Split-Path $targetPath -Leaf
            # 特殊处理某些配置文件名映射
            $actualFileName = switch ($fileName) {
                "Microsoft.PowerShell_profile.ps1" { "Microsoft.PowerShell_profile.ps1" }
                ".gitconfig" { "gitconfig" }
                ".gitignore_global" { "gitignore_global" }
                ".gitmessage" { "gitmessage" }
                "settings.json" { "settings.json" }
                "starship.toml" { "starship.toml" }
                default { $fileName }
            }
            Join-Path $sourceDir $actualFileName
        } else {
            $sourceDir
        }

        if (-not (Test-Path $sourcePath)) {
            Write-Warning "    源文件不存在: $sourcePath"
            continue
        }

        # 执行部署
        try {
            if ($DryRun) {
                Write-Info "    [预览] 复制: $sourcePath → $targetPath"
            } else {
                if ($isFile) {
                    Copy-Item $sourcePath $targetPath -Force
                } else {
                    # 对于目录，先删除目标再复制
                    if (Test-Path $targetPath) {
                        Remove-Item $targetPath -Recurse -Force
                    }
                    Copy-Item $sourcePath $targetPath -Recurse -Force
                }
                Write-Success "    已部署"
            }
        } catch {
            Write-Error "    部署失败: $($_.Exception.Message)"
        }
    }
}

# 执行部署
foreach ($configName in $ConfigsToDeploy) {
    Deploy-Config $configName $ConfigMappings[$configName]
}

Write-Status ""
Write-Status "📊 部署完成报告" "Cyan"
Write-Status "===============" "Cyan"

if ($DryRun) {
    Write-Info "这是预览模式，没有实际修改任何文件"
    Write-Info "移除 -DryRun 参数以执行实际部署"
} else {
    Write-Success "配置部署完成！"
    if ($Backup -and (Test-Path $BackupDir)) {
        Write-Info "原有配置已备份到: $BackupDir"
    }
}

Write-Status ""
Write-Status "💡 使用提示:" "Yellow"
Write-Status "• 使用 -List 查看所有可用配置类型" "Gray"
Write-Status "• 使用 -ConfigType powershell,git 部署特定配置" "Gray"
Write-Status "• 使用 -DryRun 预览操作而不实际执行" "Gray"
Write-Status "• 使用 -Force 强制覆盖现有配置" "Gray"
Write-Status ""
Write-Info "建议接下来运行: .\install-apps.ps1 安装相关应用程序"
