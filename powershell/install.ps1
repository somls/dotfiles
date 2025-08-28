# Script parameters must appear before any functions
[CmdletBinding()]
param(
    [switch]$CreateLinks,
    [switch]$InstallTools,
    [switch]$Backup,
    [switch]$Force,
    [string]$SyncPath = $null,
    [switch]$SetupCmd,
    [switch]$UnregisterCmd
)

# 配置 CMD 的 AutoRun 别名（可选）
function Set-CmdAutorunAliases {
    param(
        [switch]$Remove
    )

    # 使用 HKCU\Software\Microsoft\Command Processor\AutoRun
    $regPath = 'HKCU:\\Software\\Microsoft\\Command Processor'
    $name = 'AutoRun'
    # 优先使用纯宏文件 (.mac)，避免 DOSKEY 前缀与注释导致的解析错误
    $macPath = Join-Path (Join-Path $ScriptRoot '..') 'scripts/cmd/aliases.mac'
    $cmdPath = Join-Path (Join-Path $ScriptRoot '..') 'scripts/cmd/aliases.cmd'
    $cmdAliasFile = if (Test-Path $macPath) { $macPath } elseif (Test-Path $cmdPath) { $cmdPath } else { $macPath }
    $cmdAliasFile = [IO.Path]::GetFullPath($cmdAliasFile)

    if ($Remove) {
        try {
            if (Test-Path $regPath) {
                $current = (Get-ItemProperty -Path $regPath -Name $name -ErrorAction SilentlyContinue).$name
                if ($current) {
                    Remove-ItemProperty -Path $regPath -Name $name -ErrorAction Stop
                    Write-Success "已取消 CMD AutoRun 别名注册"
                } else {
                    Write-ColorMessage "CMD AutoRun 未设置，跳过" "Gray"
                }
            }
        } catch {
            Write-Warning "取消 CMD AutoRun 失败: $($_.Exception.Message)"
        }
        return
    }

    if (-not (Test-Path $cmdAliasFile)) {
        Write-Warning "未找到 CMD 别名文件: $cmdAliasFile"
        return
    }

    try {
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        $value = ('doskey /macrofile="{0}"' -f $cmdAliasFile)
        Set-ItemProperty -Path $regPath -Name $name -Value $value -Force
        Write-Success "已为 CMD 注册 AutoRun 别名 ($cmdAliasFile)"
    } catch {
        Write-Warning "设置 CMD AutoRun 失败: $($_.Exception.Message)"
    }
}

# =============================================================================
# PowerShell Configuration Installation Script
#
# 专注于配置同步备份的PowerShell环境安装脚本
# 支持符号链接实现实时同步，适用于系统重装和多设备部署
# Last Modified: 2025-07-29
# =============================================================================

# 配置路径
$ScriptRoot = $PSScriptRoot
$ProfilePath = $PROFILE
$ProfileDir = Split-Path $ProfilePath -Parent
# 同时准备 Windows PowerShell 5 的 Profile 路径
$WinPSProfilePath = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
$WinPSProfileDir  = Split-Path $WinPSProfilePath -Parent
$BackupDir = Join-Path $ProfileDir "backup"

# 自动检测同步目录
if (-not $SyncPath) {
    $SyncPath = $ScriptRoot
}

$SourceProfile = Join-Path $SyncPath "Microsoft.PowerShell_profile.ps1"
$SourceConfigDir = Join-Path $SyncPath ".powershell"
$TargetConfigDir = Join-Path $env:USERPROFILE ".powershell"

# 颜色输出函数
function Write-ColorMessage {
    param([string]$Message, [string]$Color = 'White')
    Write-Host $Message -ForegroundColor $Color
}

function Write-Step {
    param([string]$StepNumber, [string]$Description)
    Write-ColorMessage "`n[$StepNumber] $Description" "Cyan"
}

function Write-Success {
    param([string]$Message)
    Write-ColorMessage "✅ $Message" "Green"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorMessage "⚠️  $Message" "Yellow"
}

function Write-Error {
    param([string]$Message)
    Write-ColorMessage "❌ $Message" "Red"
}

# 检查管理员权限
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 备份现有配置
function Backup-ExistingConfig {
    if (-not $Backup) {
        return
    }

    Write-Step "Backup" "备份现有配置"

    if (-not (Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

    # 备份主配置文件
    if (Test-Path $ProfilePath) {
        $backupFile = Join-Path $BackupDir "profile_backup_$timestamp.ps1"
        Copy-Item $ProfilePath $backupFile -Force
        Write-Success "配置文件已备份到: $backupFile"
    }

    # 备份配置目录
    if (Test-Path $TargetConfigDir) {
        $backupDirPath = Join-Path $BackupDir "powershell_backup_$timestamp"
        Copy-Item $TargetConfigDir $backupDirPath -Recurse -Force
        Write-Success "配置目录已备份到: $backupDirPath"
    }
}

# 检查源文件
function Test-SourceFiles {
    Write-Step "Check" "检查源配置文件"

    $missing = @()

    if (-not (Test-Path $SourceProfile)) {
        $missing += "主配置文件: $SourceProfile"
    }

    if (-not (Test-Path $SourceConfigDir)) {
        $missing += "配置目录: $SourceConfigDir"
    }

    if ($missing.Count -gt 0) {
        Write-Error "缺少必需的源文件:"
        foreach ($item in $missing) {
            Write-ColorMessage "  • $item" "Red"
        }
        return $false
    }

    Write-Success "所有源文件检查通过"
    return $true
}

# 创建符号链接
function New-SymbolicLink {
    param(
        [string]$SourcePath,
        [string]$TargetPath,
        [string]$Description,
        [switch]$IsDirectory
    )

    # 检查目标是否已存在
    if (Test-Path $TargetPath) {
        $item = Get-Item $TargetPath
        if ($item.LinkType -eq "SymbolicLink") {
            if ($Force) {
                Remove-Item $TargetPath -Force -Recurse
                Write-ColorMessage "  已删除现有符号链接: $TargetPath" "Yellow"
            } else {
                Write-Warning "$Description 的符号链接已存在，使用 -Force 参数覆盖"
                return $false
            }
        } else {
            if ($Force) {
                if ($Backup) {
                    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                    $backupPath = "$TargetPath.backup.$timestamp"
                    Move-Item $TargetPath $backupPath -Force
                    Write-ColorMessage "  已备份现有文件到: $backupPath" "Yellow"
                } else {
                    Remove-Item $TargetPath -Force -Recurse
                }
            } else {
                Write-Warning "$Description 已存在，使用 -Force 参数覆盖"
                return $false
            }
        }
    }

    # 确保目标目录存在
    $targetDir = Split-Path $TargetPath -Parent
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    try {
        if ($IsDirectory) {
            New-Item -ItemType SymbolicLink -Path $TargetPath -Target $SourcePath -Force | Out-Null
        } else {
            New-Item -ItemType SymbolicLink -Path $TargetPath -Target $SourcePath -Force | Out-Null
        }
        Write-Success "$Description 符号链接创建成功"
        Write-ColorMessage "  $TargetPath -> $SourcePath" "Gray"
        return $true
    } catch {
        Write-Error "$Description 符号链接创建失败: $($_.Exception.Message)"
        return $false
    }
}

# 复制配置文件
function Copy-ConfigFiles {
    param(
        [string]$SourcePath,
        [string]$TargetPath,
        [string]$Description,
        [switch]$IsDirectory
    )

    try {
        # 确保目标目录存在
        $targetDir = if ($IsDirectory) { Split-Path $TargetPath -Parent } else { Split-Path $TargetPath -Parent }
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }

        # 处理现有文件
        if (Test-Path $TargetPath) {
            if ($Force) {
                Remove-Item $TargetPath -Recurse -Force
            } else {
                Write-Warning "$Description 已存在，使用 -Force 参数覆盖"
                return $false
            }
        }

        if ($IsDirectory) {
            Copy-Item $SourcePath $TargetPath -Recurse -Force
        } else {
            Copy-Item $SourcePath $TargetPath -Force
        }

        Write-Success "$Description 复制成功"
        return $true
    } catch {
        Write-Error "$Description 复制失败: $($_.Exception.Message)"
        return $false
    }
}

# 安装推荐工具
function Install-RecommendedTools {
    if (-not $InstallTools) {
        return
    }

    Write-Step "Tools" "安装推荐的命令行工具"

    # 检查 Scoop
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Warning "未检测到 Scoop，跳过工具安装"
        Write-ColorMessage "安装 Scoop: https://scoop.sh/" "Gray"
        return
    }

    $tools = @(
        "starship",
        "fzf",
        "bat",
        "ripgrep",
        "fd",
        "zoxide"
    )

    foreach ($tool in $tools) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            Write-ColorMessage "正在安装 $tool..." "Yellow"
            try {
                scoop install $tool | Out-Null
                Write-Success "$tool 安装成功"
            } catch {
                Write-Warning "$tool 安装失败"
            }
        } else {
            Write-ColorMessage "$tool 已安装" "Gray"
        }
    }

    # 安装 PowerShell 模块
    $modules = @(
        "PSFzf",
        "Terminal-Icons"
    )

    foreach ($module in $modules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-ColorMessage "正在安装模块 $module..." "Yellow"
            try {
                Install-Module -Name $module -Force -Scope CurrentUser -AllowClobber
                Write-Success "模块 $module 安装成功"
            } catch {
                Write-Warning "模块 $module 安装失败"
            }
        } else {
            Write-ColorMessage "模块 $module 已安装" "Gray"
        }
    }
}

# 验证安装
function Test-Installation {
    Write-Step "Verify" "验证安装结果"

    $success = $true

    # 检查主配置文件
    if (Test-Path $ProfilePath) {
        $item = Get-Item $ProfilePath
        if ($CreateLinks) {
            if ($item.LinkType -eq "SymbolicLink") {
                Write-Success "主配置文件符号链接已创建"
                Write-ColorMessage "  目标: $($item.Target)" "Gray"
            } else {
                Write-Warning "主配置文件不是符号链接"
                $success = $false
            }
        } else {
            Write-Success "主配置文件已安装"
        }
    } else {
        Write-Error "主配置文件未找到"
        $success = $false
    }

    # 检查 Windows PowerShell 5 的配置文件
    if (Test-Path $WinPSProfilePath) {
        $item = Get-Item $WinPSProfilePath
        if ($CreateLinks) {
            if ($item.LinkType -eq "SymbolicLink") {
                Write-Success "WinPS 配置文件符号链接已创建"
                Write-ColorMessage "  目标: $($item.Target)" "Gray"
            } else {
                Write-Warning "WinPS 配置文件不是符号链接"
                $success = $false
            }
        } else {
            Write-Success "WinPS 配置文件已安装"
        }
    } else {
        Write-Error "WinPS 配置文件未找到"
        $success = $false
    }

    # 检查配置目录
    if (Test-Path $TargetConfigDir) {
        $item = Get-Item $TargetConfigDir
        if ($CreateLinks) {
            if ($item.LinkType -eq "SymbolicLink") {
                Write-Success "配置目录符号链接已创建"
                Write-ColorMessage "  目标: $($item.Target)" "Gray"
            } else {
                Write-Warning "配置目录不是符号链接"
                $success = $false
            }
        } else {
            Write-Success "配置目录已安装"
        }

        # 检查核心配置文件
        $coreFiles = @("functions.ps1", "aliases.ps1", "extra.ps1")
        foreach ($file in $coreFiles) {
            $filePath = Join-Path $TargetConfigDir $file
            if (Test-Path $filePath) {
                Write-ColorMessage "  ✅ $file" "Green"
            } else {
                Write-ColorMessage "  ❌ $file" "Red"
                $success = $false
            }
        }
    } else {
        Write-Error "配置目录未找到"
        $success = $false
    }

    return $success
}

# 显示使用说明
function Show-Usage {
    Write-ColorMessage "`n🎯 PowerShell 配置安装完成！" "Green"
    Write-ColorMessage "=====================================`n" "DarkGreen"

    if ($CreateLinks) {
        Write-ColorMessage "✨ 符号链接模式 - 配置实时同步到:" "Cyan"
        Write-ColorMessage "   $SyncPath" "Gray"
        Write-ColorMessage "`n📝 配置修改:" "Yellow"
        Write-ColorMessage "   • 直接编辑同步目录中的配置文件" "Gray"
        Write-ColorMessage "   • 修改会立即生效并同步到云端" "Gray"
    } else {
        Write-ColorMessage "📁 复制模式 - 配置已安装到本地" "Yellow"
        Write-ColorMessage "`n📝 配置修改:" "Yellow"
        Write-ColorMessage "   • 使用 'ep' 命令编辑配置目录" "Gray"
        Write-ColorMessage "   • 手动同步配置到其他设备" "Gray"
    }

    Write-ColorMessage "`n🚀 快速开始:" "Cyan"
    Write-ColorMessage "   • 重启 PowerShell 或运行 'reload'" "Gray"
    Write-ColorMessage "   • 运行 'config-info' 查看所有功能" "Gray"
    Write-ColorMessage "   • 运行 'proxy' 查看代理管理功能" "Gray"
    Write-ColorMessage "   • 运行 'swp' 清理 Scoop 缓存" "Gray"

    if ($SetupCmd) {
        Write-ColorMessage "\n📟 CMD 别名已启用：在任何 cmd.exe 会话中生效 (doskey)" "Cyan"
    }

    if ($CreateLinks) {
        Write-ColorMessage "`n🔗 符号链接优势:" "Cyan"
        Write-ColorMessage "   • 实时同步配置到云端" "Green"
        Write-ColorMessage "   • 多设备自动保持一致" "Green"
        Write-ColorMessage "   • 版本控制支持" "Green"
        Write-ColorMessage "   • 系统重装快速恢复" "Green"
    }
}

# 主安装逻辑
function Start-Installation {
    Write-ColorMessage "🚀 PowerShell 配置安装向导" "Magenta"
    Write-ColorMessage "==============================" "DarkMagenta"
    Write-ColorMessage "目标: 配置同步备份，多设备一致的 PowerShell 环境`n" "Gray"

    # 检查管理员权限 (符号链接需要)
    if ($CreateLinks -and -not (Test-Administrator)) {
        Write-Error "创建符号链接需要管理员权限"
        Write-ColorMessage "请以管理员身份重新运行此脚本" "Yellow"
        exit 1
    }

    # 显示安装模式
    if ($CreateLinks) {
        Write-ColorMessage "🔗 安装模式: 符号链接 (实时同步)" "Green"
        Write-ColorMessage "   配置源: $SyncPath" "Gray"
    } else {
        Write-ColorMessage "📁 安装模式: 复制文件 (本地配置)" "Yellow"
    }

    # 检查源文件
    if (-not (Test-SourceFiles)) {
        exit 1
    }

    # 备份现有配置
    Backup-ExistingConfig

    # 安装主配置文件 (PowerShell 7)
    Write-Step "Profile" "安装 PowerShell 7 主配置文件"
    if ($CreateLinks) { $profileSuccess = New-SymbolicLink -SourcePath $SourceProfile -TargetPath $ProfilePath -Description "主配置文件" }
    else { $profileSuccess = Copy-ConfigFiles -SourcePath $SourceProfile -TargetPath $ProfilePath -Description "主配置文件" }
    if (-not $profileSuccess) { Write-Error "主配置文件安装失败"; exit 1 }

    # 安装 Windows PowerShell 5 Profile
    Write-Step "WinPS" "安装 Windows PowerShell 5 配置文件"
    if ($CreateLinks) { $winpsSuccess = New-SymbolicLink -SourcePath $SourceProfile -TargetPath $WinPSProfilePath -Description "WinPS 配置文件" }
    else { $winpsSuccess = Copy-ConfigFiles -SourcePath $SourceProfile -TargetPath $WinPSProfilePath -Description "WinPS 配置文件" }
    if (-not $winpsSuccess) { Write-Error "WinPS 配置文件安装失败"; exit 1 }

    # 安装配置目录
    Write-Step "Config" "安装配置模块目录"
    if ($CreateLinks) {
        $configSuccess = New-SymbolicLink -SourcePath $SourceConfigDir -TargetPath $TargetConfigDir -Description "配置目录" -IsDirectory
    } else {
        $configSuccess = Copy-ConfigFiles -SourcePath $SourceConfigDir -TargetPath $TargetConfigDir -Description "配置目录" -IsDirectory
    }

    if (-not $configSuccess) {
        Write-Error "配置目录安装失败"
        exit 1
    }

    # 安装推荐工具
    Install-RecommendedTools

    # 可选：配置 CMD AutoRun 别名
    if ($SetupCmd) { Set-CmdAutorunAliases }
    if ($UnregisterCmd) { Set-CmdAutorunAliases -Remove }

    # 验证安装
    $installSuccess = Test-Installation

    if ($installSuccess) {
        Show-Usage
    } else {
        Write-Error "安装验证失败，请检查上述错误信息"
        exit 1
    }
}

# 参数帮助
if ($args -contains '-h' -or $args -contains '--help') {
    Write-ColorMessage "PowerShell 配置安装脚本" "Cyan"
    Write-ColorMessage "========================" "DarkCyan"
    Write-ColorMessage "`n专注于配置同步备份的 PowerShell 环境安装" "Gray"
    Write-ColorMessage "`n用法:" "Yellow"
    Write-ColorMessage "  .\install.ps1                    # 复制配置文件到本地" "Gray"
    Write-ColorMessage "  .\install.ps1 -CreateLinks       # 创建符号链接实现实时同步 (推荐)" "Gray"
    Write-ColorMessage "  .\install.ps1 -CreateLinks -InstallTools -Backup" "Gray"
    Write-ColorMessage "  .\install.ps1 -CreateLinks -SetupCmd        # 额外为 cmd.exe 启用 doskey 别名" "Gray"
    Write-ColorMessage "`n选项:" "Yellow"
    Write-ColorMessage "  -CreateLinks    创建符号链接实现配置实时同步 (需要管理员权限)" "Gray"
    Write-ColorMessage "  -InstallTools   安装推荐的命令行工具 (starship, fzf, bat等)" "Gray"
    Write-ColorMessage "  -Backup         安装前备份现有配置" "Gray"
    Write-ColorMessage "  -Force          强制覆盖现有配置文件" "Gray"
    Write-ColorMessage "  -SyncPath       指定配置源目录 (默认为脚本所在目录)" "Gray"
    Write-ColorMessage "  -SetupCmd       为 cmd.exe 注册 doskey 别名 (AutoRun)" "Gray"
    Write-ColorMessage "  -UnregisterCmd  取消 cmd.exe 的 AutoRun 别名注册" "Gray"
    Write-ColorMessage "`n符号链接优势:" "Yellow"
    Write-ColorMessage "  • 实时同步配置到云端存储" "Green"
    Write-ColorMessage "  • 多设备自动保持配置一致" "Green"
    Write-ColorMessage "  • 支持 Git 版本控制" "Green"
    Write-ColorMessage "  • 系统重装时快速恢复" "Green"
    Write-ColorMessage "`n示例:" "Yellow"
    Write-ColorMessage "  # 新系统部署 (推荐)" "Gray"
    Write-ColorMessage "  .\install.ps1 -CreateLinks -InstallTools -Backup" "Gray"
    Write-ColorMessage "`n  # 现有配置升级" "Gray"
    Write-ColorMessage "  .\install.ps1 -CreateLinks -Force -Backup" "Gray"
    exit 0
}

# 执行安装
try {
    Start-Installation
} catch {
    Write-Error "安装失败: $($_.Exception.Message)"
    exit 1
}
