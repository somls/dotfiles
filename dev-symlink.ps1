# =============================================================================
# 开发用符号链接脚本 (dev-symlink.ps1)
# 实时同步展现配置修改效果 - 仅供开发使用
# =============================================================================

param(
    [ValidateSet("create", "remove", "status", "refresh")]
    [string]$Action = "create",
    [string[]]$ConfigType = @(),
    [switch]$Force,
    [switch]$DryRun,
    [switch]$All
)

# 检查管理员权限
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 检查开发者模式
function Test-DeveloperMode {
    try {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
        $devMode = Get-ItemProperty -Path $regPath -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
        return $devMode.AllowDevelopmentWithoutDevLicense -eq 1
    } catch {
        return $false
    }
}

# 脚本配置
$ConfigsDir = Join-Path $PSScriptRoot "configs"
$BackupDir = Join-Path $PSScriptRoot ".dev-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# 符号链接映射表 - 开发用实时同步配置
$SymlinkMappings = @{
    "powershell" = @{
        Source = "powershell"
        Links = @(
            @{
                SourceFile = "Microsoft.PowerShell_profile.ps1"
                Target = $PROFILE
                Type = "File"
                Description = "PowerShell 7 Profile"
            },
            @{
                SourceFile = "Microsoft.PowerShell_profile.ps1"
                Target = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
                Type = "File"
                Description = "PowerShell 5.1 Profile"
            },
            @{
                SourceFile = ".powershell"
                Target = Join-Path (Split-Path $PROFILE) ".powershell"
                Type = "Directory"
                Description = "PowerShell Modules"
            }
        )
    }
    "git" = @{
        Source = "git"
        Links = @(
            @{
                SourceFile = "gitconfig"
                Target = "$env:USERPROFILE\.gitconfig"
                Type = "File"
                Description = "Git Global Config"
            },
            @{
                SourceFile = "gitignore_global"
                Target = "$env:USERPROFILE\.gitignore_global"
                Type = "File"
                Description = "Git Global Ignore"
            },
            @{
                SourceFile = "gitmessage"
                Target = "$env:USERPROFILE\.gitmessage"
                Type = "File"
                Description = "Git Commit Template"
            }
        )
    }
    "starship" = @{
        Source = "starship"
        Links = @(
            @{
                SourceFile = "starship.toml"
                Target = "$env:USERPROFILE\.config\starship.toml"
                Type = "File"
                Description = "Starship Config"
            }
        )
    }
    "terminal" = @{
        Source = "WindowsTerminal"
        Links = @(
            @{
                SourceFile = "settings.json"
                Target = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
                Type = "File"
                Description = "Windows Terminal Config"
            }
        )
    }
    "neovim" = @{
        Source = "neovim"
        Links = @(
            @{
                SourceFile = "."  # 整个目录
                Target = "$env:LOCALAPPDATA\nvim"
                Type = "Directory"
                Description = "Neovim Config Directory"
            }
        )
    }
}

# 颜色输出函数
function Write-Status { param($Message, $Color = "White") Write-Host $Message -ForegroundColor $Color }
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }

Write-Status "🔗 开发用符号链接管理" "Cyan"
Write-Status "===================" "Cyan"

# 权限检查
$isAdmin = Test-Administrator
$isDeveloperMode = Test-DeveloperMode

Write-Status ""
Write-Status "🛡️ 权限检查" "Yellow"
Write-Status "管理员权限: $(if ($isAdmin) { '✅' } else { '❌' })" $(if ($isAdmin) { "Green" } else { "Red" })
Write-Status "开发者模式: $(if ($isDeveloperMode) { '✅' } else { '❌' })" $(if ($isDeveloperMode) { "Green" } else { "Yellow" })

if (-not $isAdmin -and -not $isDeveloperMode) {
    Write-Error ""
    Write-Error "需要管理员权限或开发者模式才能创建符号链接！"
    Write-Error ""
    Write-Error "解决方案："
    Write-Error "1. 以管理员身份运行PowerShell"
    Write-Error "2. 或者启用开发者模式：设置 > 更新和安全 > 开发者选项 > 开发人员模式"
    exit 1
}

# 确定要处理的配置类型
$ConfigsToProcess = if ($All) {
    $SymlinkMappings.Keys
} elseif ($ConfigType.Count -gt 0) {
    $ConfigType | Where-Object { $SymlinkMappings.ContainsKey($_) }
} else {
    $SymlinkMappings.Keys
}

if ($ConfigsToProcess.Count -eq 0) {
    Write-Error "没有有效的配置类型。可用选项: $($SymlinkMappings.Keys -join ', ')"
    exit 1
}

# 检查符号链接状态
function Get-SymlinkStatus {
    param($TargetPath)

    if (-not (Test-Path $TargetPath)) {
        return "不存在"
    }

    try {
        $item = Get-Item $TargetPath -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            return "符号链接"
        } else {
            return "普通文件"
        }
    } catch {
        return "未知"
    }
}

# 创建符号链接
function New-Symlink {
    param($SourcePath, $TargetPath, $Type)

    # 确保源存在
    if (-not (Test-Path $SourcePath)) {
        Write-Error "源路径不存在: $SourcePath"
        return $false
    }

    # 确保目标目录存在
    $targetDir = Split-Path $TargetPath
    if ($targetDir -and -not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    # 备份现有文件
    if (Test-Path $TargetPath) {
        $status = Get-SymlinkStatus $TargetPath
        if ($status -ne "符号链接") {
            if (-not (Test-Path $BackupDir)) {
                New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
            }
            $backupName = "$(Split-Path $TargetPath -Leaf)_$(Get-Date -Format 'HHmmss')"
            $backupPath = Join-Path $BackupDir $backupName

            if ($Type -eq "Directory") {
                Copy-Item $TargetPath $backupPath -Recurse -Force
            } else {
                Copy-Item $TargetPath $backupPath -Force
            }
            Write-Info "    已备份到: $backupPath"
        }

        Remove-Item $TargetPath -Recurse -Force
    }

    # 创建符号链接
    try {
        if ($Type -eq "Directory") {
            $result = cmd /c "mklink /D `"$TargetPath`" `"$SourcePath`"" 2>&1
        } else {
            $result = cmd /c "mklink `"$TargetPath`" `"$SourcePath`"" 2>&1
        }

        if ($LASTEXITCODE -eq 0) {
            return $true
        } else {
            Write-Error "    创建失败: $result"
            return $false
        }
    } catch {
        Write-Error "    创建失败: $($_.Exception.Message)"
        return $false
    }
}

# 移除符号链接
function Remove-Symlink {
    param($TargetPath, $Type)

    if (-not (Test-Path $TargetPath)) {
        Write-Warning "    目标不存在: $TargetPath"
        return $true
    }

    $status = Get-SymlinkStatus $TargetPath
    if ($status -ne "符号链接") {
        Write-Warning "    不是符号链接，跳过: $TargetPath"
        return $false
    }

    try {
        Remove-Item $TargetPath -Force
        return $true
    } catch {
        Write-Error "    移除失败: $($_.Exception.Message)"
        return $false
    }
}

# 主要操作函数
switch ($Action) {
    "status" {
        Write-Status ""
        Write-Status "📊 符号链接状态" "Yellow"

        foreach ($configName in $ConfigsToProcess) {
            $mapping = $SymlinkMappings[$configName]
            $sourceDir = Join-Path $ConfigsDir $mapping.Source

            Write-Status ""
            Write-Status "配置: $configName" "Green"

            foreach ($link in $mapping.Links) {
                $sourcePath = if ($link.SourceFile -eq ".") {
                    $sourceDir
                } else {
                    Join-Path $sourceDir $link.SourceFile
                }
                $targetPath = $link.Target
                $status = Get-SymlinkStatus $targetPath

                $statusColor = switch ($status) {
                    "符号链接" { "Green" }
                    "普通文件" { "Yellow" }
                    "不存在" { "Red" }
                    default { "Gray" }
                }

                Write-Status "  $($link.Description)" "Gray"
                Write-Status "    状态: $status" $statusColor
                Write-Status "    目标: $targetPath" "DarkGray"
                if ($status -eq "符号链接") {
                    Write-Status "    源: $sourcePath" "DarkGray"
                }
            }
        }
    }

    "create" {
        Write-Status ""
        Write-Status "🔗 创建符号链接" "Yellow"

        $created = 0
        $failed = 0

        foreach ($configName in $ConfigsToProcess) {
            $mapping = $SymlinkMappings[$configName]
            $sourceDir = Join-Path $ConfigsDir $mapping.Source

            Write-Status ""
            Write-Status "配置: $configName" "Green"

            if (-not (Test-Path $sourceDir)) {
                Write-Error "  源目录不存在: $sourceDir"
                continue
            }

            foreach ($link in $mapping.Links) {
                $sourcePath = if ($link.SourceFile -eq ".") {
                    $sourceDir
                } else {
                    Join-Path $sourceDir $link.SourceFile
                }
                $targetPath = $link.Target
                $description = $link.Description

                Write-Status "  → $description" "Gray"

                if ($DryRun) {
                    Write-Info "    [预览] 将创建符号链接: $targetPath → $sourcePath"
                } else {
                    $currentStatus = Get-SymlinkStatus $targetPath
                    if ($currentStatus -eq "符号链接" -and -not $Force) {
                        Write-Info "    已存在符号链接，跳过"
                        $created++
                    } else {
                        if (New-Symlink $sourcePath $targetPath $link.Type) {
                            Write-Success "    符号链接创建成功"
                            $created++
                        } else {
                            $failed++
                        }
                    }
                }
            }
        }

        if (-not $DryRun) {
            Write-Status ""
            Write-Status "结果: 成功 $created, 失败 $failed" "Cyan"
            if ($created -gt 0) {
                Write-Success "符号链接创建完成！配置文件修改将实时同步。"
            }
        }
    }

    "remove" {
        Write-Status ""
        Write-Status "🗑️ 移除符号链接" "Yellow"

        $removed = 0
        $failed = 0

        foreach ($configName in $ConfigsToProcess) {
            $mapping = $SymlinkMappings[$configName]

            Write-Status ""
            Write-Status "配置: $configName" "Green"

            foreach ($link in $mapping.Links) {
                $targetPath = $link.Target
                $description = $link.Description

                Write-Status "  → $description" "Gray"

                if ($DryRun) {
                    Write-Info "    [预览] 将移除符号链接: $targetPath"
                } else {
                    if (Remove-Symlink $targetPath $link.Type) {
                        Write-Success "    符号链接已移除"
                        $removed++
                    } else {
                        $failed++
                    }
                }
            }
        }

        if (-not $DryRun) {
            Write-Status ""
            Write-Status "结果: 移除 $removed, 失败 $failed" "Cyan"
        }
    }

    "refresh" {
        Write-Status ""
        Write-Status "🔄 刷新符号链接" "Yellow"

        # 先移除，再创建
        $oldAction = $Action
        $script:Action = "remove"
        & {
            param($ConfigsToProcess, $SymlinkMappings, $ConfigsDir)
            # 移除逻辑...
        } $ConfigsToProcess $SymlinkMappings $ConfigsDir

        $script:Action = "create"
        & {
            param($ConfigsToProcess, $SymlinkMappings, $ConfigsDir)
            # 创建逻辑...
        } $ConfigsToProcess $SymlinkMappings $ConfigsDir
    }
}

Write-Status ""
Write-Status "💡 开发使用提示:" "Yellow"
Write-Status "• 符号链接模式下，修改configs中的文件会立即影响系统配置" "Gray"
Write-Status "• 使用前请确保已备份重要配置文件" "Gray"
Write-Status "• 开发完成后建议使用 .\deploy-config.ps1 进行普通部署" "Gray"
Write-Status "• 使用 -Action status 查看当前链接状态" "Gray"
Write-Status "• 使用 -Action remove 移除所有开发符号链接" "Gray"

if (Test-Path $BackupDir) {
    Write-Status ""
    Write-Info "备份文件已保存到: $BackupDir"
}
