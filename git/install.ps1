# Git 配置安装脚本
# 用于将 git 配置文件安装到系统中

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [switch]$Symlink = $false,

    [Parameter(Mandatory = $false)]
    [switch]$Force = $false,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf = $false,

    [Parameter(Mandatory = $false)]
    [string]$BackupDir = "$env:USERPROFILE\.dotfiles-backup\git"
)

$ErrorActionPreference = "Stop"

# 设置源目录和目标目录
$SourceDir = $PSScriptRoot
$UserHome = $env:USERPROFILE
$ConfigDir = "$UserHome\.config\git"
$GitconfigDDir = "$UserHome\.gitconfig.d"

# 创建模块导入路径，指向整个项目的 modules 目录
$ModulePath = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath "modules"
$UtilityModule = Join-Path -Path $ModulePath -ChildPath "DotfilesUtilities.psm1"

# 导入公共工具模块
if (Test-Path $UtilityModule) {
    Import-Module $UtilityModule -Force
} else {
    Write-Error "找不到必要的工具模块: $UtilityModule"
    exit 1
}

# 显示标题
Write-DotfilesHeader "Git 配置安装"

# 创建目录结构
function Create-DirectoryStructure {
    if (-not (Test-Path $BackupDir)) {
        Write-Host "创建备份目录: $BackupDir" -ForegroundColor Cyan
        New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
    }

    if (-not (Test-Path $ConfigDir)) {
        Write-Host "创建配置目录: $ConfigDir" -ForegroundColor Cyan
        New-Item -Path $ConfigDir -ItemType Directory -Force | Out-Null
    }

    # 注意：不再创建 .gitconfig.d 目录，因为我们要整体链接该目录
}

# 安装 git 配置文件
function Install-GitConfigurations {
    # 1. 安装主 .gitconfig
    $Source = Join-Path -Path $SourceDir -ChildPath "gitconfig"
    $Target = Join-Path -Path $UserHome -ChildPath ".gitconfig"
    Install-DotFile -Source $Source -Target $Target -Symlink $Symlink -Force $Force -BackupDir $BackupDir -WhatIf:$WhatIf

    # 2. 安装全局 .gitignore_global
    $Source = Join-Path -Path $SourceDir -ChildPath "gitignore_global"
    $Target = Join-Path -Path $UserHome -ChildPath ".gitignore_global"
    Install-DotFile -Source $Source -Target $Target -Symlink $Symlink -Force $Force -BackupDir $BackupDir -WhatIf:$WhatIf

    # 3. 安装 git 提交消息模板
    $Source = Join-Path -Path $SourceDir -ChildPath "gitmessage"
    $Target = Join-Path -Path $UserHome -ChildPath ".gitmessage"
    Install-DotFile -Source $Source -Target $Target -Symlink $Symlink -Force $Force -BackupDir $BackupDir -WhatIf:$WhatIf

    # 4. 安装 .gitconfig.local 文件
    $Source = Join-Path -Path $SourceDir -ChildPath "gitconfig.local"
    $Target = Join-Path -Path $UserHome -ChildPath ".gitconfig.local"

    # 如果目标文件不存在，先从示例文件创建
    if (-not (Test-Path $Target)) {
        $ExampleSource = Join-Path -Path $SourceDir -ChildPath "gitconfig.local.example"
        if (Test-Path $ExampleSource) {
            Write-Host "从示例文件创建 .gitconfig.local: $Target" -ForegroundColor Yellow
            if (-not $WhatIf) {
                Copy-Item -Path $ExampleSource -Destination $Source -Force
            }
        }
    }

    # 安装 gitconfig.local 文件（链接或复制）
    if (Test-Path $Source) {
        Install-DotFile -Source $Source -Target $Target -Symlink $Symlink -Force $Force -BackupDir $BackupDir -WhatIf:$WhatIf
    } else {
        Write-Warning "源文件不存在: $Source"
    }
}

# 安装模块化配置目录
function Install-GitconfigModules {
    $SourceModuleDir = Join-Path -Path $SourceDir -ChildPath "gitconfig.d"
    if (Test-Path $SourceModuleDir) {
        # 整体链接 .gitconfig.d 目录，而不是逐个文件链接
        Install-DotFile -Source $SourceModuleDir -Target $GitconfigDDir -Symlink $Symlink -Force $Force -BackupDir $BackupDir -WhatIf:$WhatIf
    }
}

# 主函数
function Main {
    try {
        Write-Host "开始安装 Git 配置..." -ForegroundColor Blue
        Create-DirectoryStructure
        Install-GitConfigurations
        Install-GitconfigModules

        Write-Host "`n✅ Git 配置安装完成！" -ForegroundColor Green

        if (-not $WhatIf) {
            Write-Host "`n🔍 安装后检查: "
            Write-Host "   1. 请检查 ~/.gitconfig.local 文件并设置您的个人信息" -ForegroundColor Yellow
            Write-Host "   2. 检查代理设置是否适合您的网络环境" -ForegroundColor Yellow
            Write-Host "   3. 尝试运行 'git config --list' 验证配置是否正确" -ForegroundColor Yellow

            Write-Host "`n💡 提示：您可以使用以下命令设置个人信息：" -ForegroundColor Cyan
            Write-Host "   git config --global user.name 'Your Name'"
            Write-Host "   git config --global user.email 'your.email@example.com'"


        }
    }
    catch {
        Write-Error "Git 配置安装失败：$($_.Exception.Message)"
        if ($WhatIf) {
            Write-Warning "以上错误是在 WhatIf 模式下检测到的，未进行实际更改"
        }
        exit 1
    }
}

# 执行主函数
Main
