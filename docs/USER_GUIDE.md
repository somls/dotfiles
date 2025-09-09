# 📖 用户使用指南

欢迎使用Windows Dotfiles管理系统！本指南将帮助您充分利用这个企业级配置管理解决方案的所有功能。

## 📋 目录

- [系统要求和兼容性](#系统要求和兼容性)
- [五脚本体系详解](#五脚本体系详解)
- [安装部署指南](#安装部署指南)
- [使用场景和最佳实践](#使用场景和最佳实践)
- [配置管理详解](#配置管理详解)
- [环境适应性说明](#环境适应性说明)
- [故障排除和维护](#故障排除和维护)

---

## 🔧 系统要求和兼容性

### 最低系统要求

```powershell
# 检查系统兼容性
.\detect-environment.ps1
```

| 组件 | 最低要求 | 推荐配置 | 说明 |
|------|----------|----------|------|
| **操作系统** | Windows 10 Build 1903+ | Windows 11 22H2+ | 支持符号链接和现代PowerShell |
| **PowerShell** | 5.1+ | PowerShell 7.4+ | 自动适配版本差异 |
| **内存** | 4GB+ | 8GB+ | 用于运行开发工具 |
| **磁盘空间** | 2GB+ | 5GB+ | 应用程序和配置文件 |
| **网络** | 稳定连接 | 高速宽带 | 下载应用程序和更新 |

### 权限要求

```powershell
# 检查当前权限
if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "✅ 管理员权限已获得" -ForegroundColor Green
} else {
    Write-Host "⚠️ 某些功能需要管理员权限" -ForegroundColor Yellow
}

# 检查PowerShell执行策略
$executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($executionPolicy -in @('RemoteSigned', 'Unrestricted', 'Bypass')) {
    Write-Host "✅ PowerShell执行策略已配置" -ForegroundColor Green
} else {
    Write-Host "⚠️ 需要设置PowerShell执行策略" -ForegroundColor Yellow
    Write-Host "运行: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Cyan
}
```

### 环境兼容性

本系统支持以下环境配置：

**用户账户类型**：
- ✅ 标准用户账户
- ✅ 管理员账户  
- ✅ 域用户账户
- ✅ Microsoft账户

**应用安装方式**：
- ✅ Scoop包管理器（推荐）
- ✅ 系统安装程序（MSI/EXE）
- ✅ Microsoft Store应用
- ✅ 便携版本
- ✅ Chocolatey包管理器

**文件系统**：
- ✅ NTFS（推荐）
- ✅ ReFS
- ✅ 自定义文档路径
- ✅ 网络驱动器（有限支持）

---

## 🎯 五脚本体系详解

### 1. 🔍 环境检测脚本 (`detect-environment.ps1`)

**核心功能**：智能分析系统环境和已安装应用程序

**检测能力**：
- 22+应用程序自动识别
- 多种安装方式检测
- 系统信息和兼容性分析
- 配置路径和版本信息

**使用方式**：

```powershell
# 基本环境检测
.\detect-environment.ps1

# 详细模式（推荐）
.\detect-environment.ps1 -Detailed

# JSON格式输出
.\detect-environment.ps1 -Json

# 静默模式（仅日志）
.\detect-environment.ps1 -Quiet
```

**输出示例**：
```
Environment Detection Report
==================================================
Detection Time: 2024-01-15 14:30:25
PowerShell Version: 7.4.1

System Information:
  OS: Microsoft Windows 11 Pro
  Version: 10.0.22631 (Build 22631)
  Architecture: AMD64

Application Statistics:
  Total: 22
  Installed: 15
  Not Installed: 7

Installed Applications:
  • Git (System Install) - Version: 2.43.0
  • PowerShell (Microsoft Store) - Version: 7.4.1
  • Scoop (Scoop) - Version: 0.3.1
  • Visual Studio Code (System Install) - Version: 1.85.2
```

### 2. 📦 应用安装脚本 (`install_apps.ps1`)

**核心功能**：基于Scoop的分类应用安装管理

**应用分类**：

| 分类 | 应用数量 | 包含应用 |
|------|----------|----------|
| **Essential** | 13个 | git, ripgrep, zoxide, fzf, bat, fd, jq, neovim, starship, vscode, sudo, curl, 7zip |
| **Development** | 2个 | shellcheck, gh |
| **GitEnhanced** | 1个 | lazygit |
| **Programming** | 2个 | python, nodejs |

**使用方式**：

```powershell
# 安装核心工具（Essential分类）
.\install_apps.ps1

# 安装所有分类
.\install_apps.ps1 -All

# 安装特定分类
.\install_apps.ps1 -Category Development,Programming

# 预览模式（查看将要安装的应用）
.\install_apps.ps1 -DryRun -All

# 更新已安装的应用
.\install_apps.ps1 -Update

# 静默安装
.\install_apps.ps1 -Quiet

# 跳过已安装的应用
.\install_apps.ps1 -SkipInstalled
```

**安装流程**：
1. 检测Scoop是否安装，如未安装则自动安装
2. 添加必要的bucket（软件源）
3. 检查应用程序是否已安装
4. 批量安装选定分类的应用
5. 验证安装结果并生成报告

### 3. ⚙️ 配置部署脚本 (`install.ps1`)

**核心功能**：智能配置文件部署和管理

**部署模式**：

| 模式 | 适用场景 | 优势 | 限制 |
|------|----------|------|------|
| **Copy模式** | 生产环境、普通用户 | 安全稳定、无依赖 | 需手动同步更新 |
| **Symlink模式** | 开发环境、高级用户 | 实时同步、便于调试 | 需要管理员权限 |

**支持的配置类型**：

```powershell
# 查看支持的配置类型
.\install.ps1 -Type ?

# 支持的类型：
# - PowerShell: PowerShell配置文件和模块
# - Git: Git全局配置和模板
# - Starship: 提示符配置
# - Scoop: 包管理器配置
# - Neovim: 编辑器配置
# - CMD: 命令行工具
# - WindowsTerminal: 终端配置
```

**使用方式**：

```powershell
# 默认安装（Copy模式，自动选择组件）
.\install.ps1

# 指定安装模式
.\install.ps1 -Mode Copy          # 复制模式
.\install.ps1 -Mode Symlink       # 符号链接模式

# 选择性安装
.\install.ps1 -Type PowerShell,Git,Starship

# 强制覆盖现有配置
.\install.ps1 -Force

# 预览模式
.\install.ps1 -DryRun

# 交互式安装
.\install.ps1 -Interactive

# 自定义备份目录
.\install.ps1 -BackupDir "D:\Backup\dotfiles"

# 强制覆盖现有配置
.\install.ps1 -Force

# 回滚到备份状态
.\install.ps1 -Rollback

# 验证现有安装
.\install.ps1 -Validate
```

**安装过程**：
1. 环境检测和兼容性检查
2. 备份现有配置文件
3. 智能路径检测和映射
4. 配置文件部署
5. 验证安装结果
6. 生成安装报告

### 4. 🏥 系统健康检查脚本 (`health-check.ps1`)

**核心功能**：全面的系统健康检查和自动修复工具

**管理功能**：
- 批量创建符号链接
- 验证链接状态和完整性
- 修复损坏的链接
- 清理和删除链接
- 详细状态报告

**使用方式**：

```powershell
# 创建所有符号链接
.\dev-link.ps1

# 创建特定配置的链接
.\dev-link.ps1 -Type PowerShell,Git

# 验证链接状态
.\dev-link.ps1 -Verify

# 列出链接状态
.\dev-link.ps1 -List

# 删除符号链接
.\dev-link.ps1 -Remove

# 修复损坏的链接
.\dev-link.ps1 -Fix

# 预览模式
.\dev-link.ps1 -DryRun

# 强制模式
.\dev-link.ps1 -Force

# 生成详细报告
.\dev-link.ps1 -Report
```

**状态输出示例**：
```
符号链接状态报告
==================================================
总链接数: 12
有效链接: 10
损坏链接: 2
缺失链接: 0

PowerShell配置:
  ✅ Microsoft.PowerShell_profile.ps1 -> D:\sync\dotfiles\powershell\Microsoft.PowerShell_profile.ps1
  ✅ functions.ps1 -> D:\sync\dotfiles\powershell\.powershell\functions.ps1
  ❌ aliases.ps1 -> D:\sync\dotfiles\powershell\.powershell\aliases.ps1 [损坏]

Git配置:
  ✅ .gitconfig -> D:\sync\dotfiles\git\gitconfig
  ✅ .gitmessage -> D:\sync\dotfiles\git\gitmessage
```

### 5. 🏥 系统健康检查脚本 (`health-check.ps1`)

**核心功能**：全面的系统健康状态检查和自动修复

**检查类别**：

| 类别 | 检查内容 | 修复能力 |
|------|----------|----------|
| **System** | PowerShell版本、执行策略、系统兼容性 | 自动修复配置 |
| **Applications** | 必需应用安装状态、版本检查 | 提供安装建议 |
| **ConfigFiles** | 配置文件完整性、语法验证 | 自动修复语法错误 |
| **SymLinks** | 符号链接状态、目标有效性 | 自动重建链接 |

**使用方式**：

```powershell
# 基本健康检查
.\health-check.ps1

# 详细检查报告
.\health-check.ps1 -Detailed

# 自动修复发现的问题
.\health-check.ps1 -Fix

# 指定检查类别
.\health-check.ps1 -Category Applications

# JSON格式输出
.\health-check.ps1 -OutputFormat JSON

# 同时输出到控制台和JSON
.\health-check.ps1 -OutputFormat Both

# 仅检查配置文件
.\health-check.ps1 -ConfigOnly

# 生成详细日志
.\health-check.ps1 -LogFile "health-$(Get-Date -Format 'yyyyMMdd').log"
```

**健康评分系统**：
```
系统健康检查报告
==================================================
检查时间: 2024-01-15 15:45:30
总体状态: 良好 (85/100)

各类别得分:
  系统环境: 95/100 ✅
  应用程序: 80/100 ⚠️ 
  配置文件: 90/100 ✅
  符号链接: 75/100 ⚠️

发现问题:
  • 2个应用程序未安装
  • 1个符号链接损坏

修复建议:
  1. 运行 .\install_apps.ps1 -Category Development
  2. 运行 .\dev-link.ps1 -Fix
```

---

## 🚀 安装部署指南

### 新用户完整安装

**推荐的四步安装流程**：

```powershell
# 克隆项目
git clone https://github.com/somls/dotfiles.git
cd dotfiles

# 步骤1: 环境检测 (了解系统状态)
Write-Host "🔍 第1步: 检测系统环境..." -ForegroundColor Cyan
.\detect-environment.ps1 -Detailed

# 步骤2: 应用安装 (搭建开发环境) 
Write-Host "📦 第2步: 安装开发工具..." -ForegroundColor Cyan
.\install_apps.ps1

# 步骤3: 配置部署 (应用dotfiles配置)
Write-Host "⚙️ 第3步: 部署配置文件..." -ForegroundColor Cyan  
.\install.ps1

# 步骤4: 健康检查 (验证安装结果)
Write-Host "🏥 第4步: 验证安装结果..." -ForegroundColor Cyan
.\health-check.ps1
```

### 快速体验安装

**适合已有开发环境的用户**：

```powershell
# 仅部署配置文件
.\install.ps1 -Type PowerShell,Git,Starship

# 或选择性安装
.\detect-environment.ps1 -Json | ConvertFrom-Json | 
    Select-Object -ExpandProperty Applications |
    Where-Object { $_.Installed -eq $false } |
    ForEach-Object { Write-Host "缺失: $($_.Name)" -ForegroundColor Red }
```

### 企业环境部署

**适合团队和企业用户**：

```powershell
# 企业环境安装脚本
param(
    [string[]]$RequiredApps = @('Git', 'PowerShell', 'VSCode'),
    [string]$ConfigProfile = 'Corporate',
    [switch]$AuditMode
)

# 1. 环境合规性检查
Write-Host "🔒 检查企业环境合规性..." -ForegroundColor Yellow
.\detect-environment.ps1 -Json > "audit-$(Get-Date -Format 'yyyyMMdd').json"

# 2. 安装核心应用
Write-Host "📦 安装企业核心工具..." -ForegroundColor Yellow
.\install_apps.ps1 -Category Essential -SkipInstalled

# 3. 应用企业配置
Write-Host "⚙️ 应用企业配置模板..." -ForegroundColor Yellow
.\install.ps1 -Mode Copy -Type PowerShell,Git -Force

# 4. 合规性验证
Write-Host "✅ 执行合规性验证..." -ForegroundColor Yellow
.\health-check.ps1 -Detailed -LogFile "compliance-report.log"
```

---

## 🎭 使用场景和最佳实践

### 场景1: 新开发者入职

**目标**：快速搭建标准化开发环境

```powershell
# 新员工开发环境设置脚本
Write-Host "🎉 欢迎加入团队！正在设置您的开发环境..." -ForegroundColor Green

# 检查系统基础环境
.\detect-environment.ps1
Read-Host "请检查上述环境信息，按Enter继续"

# 安装完整开发工具链
.\install_apps.ps1 -All -Quiet

# 部署团队标准配置
.\install.ps1 -Type PowerShell,Git,Starship,WindowsTerminal -Force

# 设置Git用户信息模板
if (-not (Test-Path "$env:USERPROFILE\.gitconfig.local")) {
    Copy-Item "git\gitconfig.local.example" "$env:USERPROFILE\.gitconfig.local"
    Write-Host "⚠️ 请编辑 $env:USERPROFILE\.gitconfig.local 设置您的Git用户信息" -ForegroundColor Yellow
}

# 最终验证
.\health-check.ps1
Write-Host "🎯 开发环境设置完成！" -ForegroundColor Green
```

### 场景2: 现有环境迁移

**目标**：迁移现有配置到新系统

```powershell
# 环境迁移脚本
param(
    [string]$BackupPath = "D:\ConfigBackup",
    [switch]$PreserveCurrent
)

# 1. 分析现有环境
Write-Host "🔍 分析现有配置..." -ForegroundColor Cyan
.\detect-environment.ps1 -Detailed > "current-environment.txt"

# 2. 备份现有配置
Write-Host "💾 备份现有配置..." -ForegroundColor Cyan
if (-not (Test-Path $BackupPath)) { New-Item -Path $BackupPath -ItemType Directory }

$configPaths = @(
    "$env:USERPROFILE\.gitconfig",
    "$env:USERPROFILE\Documents\PowerShell",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal*\LocalState\settings.json"
)

foreach ($path in $configPaths) {
    if (Test-Path $path) {
        Copy-Item $path $BackupPath -Recurse -Force
        Write-Host "✅ 已备份: $path" -ForegroundColor Green
    }
}

# 3. 渐进式迁移
Write-Host "🔄 开始渐进式迁移..." -ForegroundColor Cyan
.\install.ps1 -Interactive -BackupDir $BackupPath

# 4. 验证迁移结果  
.\health-check.ps1 -Fix
```

### 场景3: 开发环境维护

**目标**：定期维护和更新配置

```powershell
# 定期维护脚本 (建议每周运行)
Write-Host "🔧 开始定期维护..." -ForegroundColor Magenta

# 1. 健康检查
$healthResult = .\health-check.ps1 -OutputFormat JSON | ConvertFrom-Json
if ($healthResult.OverallStatus -ne 'HEALTHY') {
    Write-Host "⚠️ 发现问题，尝试自动修复..." -ForegroundColor Yellow
    .\health-check.ps1 -Fix
}

# 2. 更新应用程序
Write-Host "📦 更新应用程序..." -ForegroundColor Cyan
.\install_apps.ps1 -Update

# 3. 同步配置文件
Write-Host "🔄 同步配置文件..." -ForegroundColor Cyan
if (Test-Path ".git") {
    git pull origin main
    .\install.ps1 -Type PowerShell,Git -Force
}

# 4. 清理和优化
Write-Host "🧹 清理临时文件..." -ForegroundColor Cyan
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    scoop cleanup *
    scoop cache rm *
}

Write-Host "✅ 维护完成！" -ForegroundColor Green
```

### 场景4: 多设备同步

**目标**：在多台设备间保持配置一致

```powershell
# 多设备同步脚本
param(
    [string]$SyncMethod = 'Git',  # Git, OneDrive, Dropbox
    [string]$RemoteUrl,
    [switch]$PullLatest
)

switch ($SyncMethod) {
    'Git' {
        if ($PullLatest) {
            Write-Host "🔄 从远程仓库拉取最新配置..." -ForegroundColor Cyan
            git pull origin main
        }
        
        # 检查本地修改
        $gitStatus = git status --porcelain
        if ($gitStatus) {
            Write-Host "📝 检测到本地修改:" -ForegroundColor Yellow
            git status --short
            
            $commit = Read-Host "是否提交这些修改？(y/N)"
            if ($commit -eq 'y' -or $commit -eq 'Y') {
                git add .
                git commit -m "Update configs from $(hostname)"
                git push origin main
            }
        }
    }
    
    'OneDrive' {
        # OneDrive同步逻辑
        $oneDrivePath = "$env:USERPROFILE\OneDrive\Dotfiles"
        if (Test-Path $oneDrivePath) {
            robocopy $oneDrivePath . /MIR /XD .git
            Write-Host "✅ 从OneDrive同步完成" -ForegroundColor Green
        }
    }
}

# 重新部署配置
.\install.ps1 -Force
```

---

## ⚙️ 配置管理详解

### 配置文件结构

**主要配置模块**：

```
配置文件组织结构
├── git/                          # Git配置模块
│   ├── gitconfig                 # 主配置文件
│   ├── gitconfig.local.example   # 个人信息模板
│   ├── gitignore_global          # 全局忽略文件
│   ├── gitmessage               # 提交消息模板
│   └── gitconfig.d/             # 模块化配置目录
│       ├── core.gitconfig       # 核心设置
│       ├── aliases.gitconfig    # 命令别名
│       ├── color.gitconfig      # 颜色配置
│       ├── diff.gitconfig       # 差异设置
│       └── windows.gitconfig    # Windows特定设置
├── powershell/                   # PowerShell配置模块
│   ├── Microsoft.PowerShell_profile.ps1  # 主配置文件
│   └── .powershell/             # 子配置目录
│       ├── functions.ps1        # 自定义函数
│       ├── aliases.ps1          # 命令别名
│       ├── history.ps1          # 历史记录配置
│       ├── keybindings.ps1      # 键盘绑定
│       ├── tools.ps1            # 工具集成
│       └── theme.ps1            # 主题配置
├── starship/                     # Starship提示符配置
│   └── starship.toml            # 主题和模块配置
├── neovim/                       # Neovim编辑器配置
│   ├── init.lua                 # 主配置文件
│   └── lua/                     # Lua配置模块
└── WindowsTerminal/              # Windows Terminal配置
    └── settings.json            # 终端配置文件
```

### 配置模板系统

**个人信息模板** (`.example`文件)：

```powershell
# 创建个人配置文件
function New-PersonalConfig {
    param([string]$ConfigType)
    
    $exampleFile = ".\$ConfigType\*.example"
    $targetFile = $exampleFile -replace '\.example$', ''
    
    if (Test-Path $exampleFile) {
        if (-not (Test-Path $targetFile)) {
            Copy-Item $exampleFile $targetFile
            Write-Host "✅ 已创建 $targetFile" -ForegroundColor Green
            Write-Host "请编辑此文件以适配您的环境" -ForegroundColor Yellow
        } else {
            Write-Host "⚠️ $targetFile 已存在，跳过创建" -ForegroundColor Yellow
        }
    }
}

# 使用示例
New-PersonalConfig -ConfigType "git"  # 创建 .gitconfig.local
```

**Git配置模板示例**：

```bash
# .gitconfig.local.example 内容
[user]
    name = Your Name                    # 修改为您的姓名
    email = your.email@company.com      # 修改为您的邮箱

[http]
    proxy = http://127.0.0.1:10808      # 根据实际代理配置修改
    
[includeIf "gitdir:~/work/"]
    path = ~/.gitconfig.work            # 工作项目特定配置
```

### 配置自定义和扩展

**PowerShell配置扩展**：

```powershell
# 在 ~/.powershell/extra.ps1 中添加个人定制
# 此文件会被自动加载，但不包含在版本控制中

# 个人别名
Set-Alias -Name ll -Value Get-ChildItem
Set-Alias -Name .. -Value Set-LocationParent

# 个人函数
function Get-Weather {
    param([string]$City = "Beijing")
    Invoke-RestMethod "http://wttr.in/$City?format=3"
}

# 环境变量
$env:EDITOR = "code"
$env:BROWSER = "chrome"

# 工作项目快速导航
function Work { Set-Location "D:\Projects" }
function Docs { Set-Location "D:\Documents" }
```

**Starship提示符自定义**：

```toml
# starship.toml 自定义示例
[character]
success_symbol = "[➜](bold green)"
error_symbol = "[➜](bold red)"

[git_branch]
symbol = "🌱 "
truncation_length = 8

[directory]
truncation_length = 3
truncation_symbol = "…/"

[time]
disabled = false
format = "🕙[$time]($style) "
time_format = "%H:%M"

[cmd_duration]
min_time = 2_000
format = "took [$duration](bold yellow)"
```

---

## 🌍 环境适应性说明

### 智能路径检测机制

**Scoop路径检测优先级**：

```powershell
function Get-ScoopPath {
    $searchPaths = @(
        $env:SCOOP,                              # 环境变量 (最高优先级)
        $env:SCOOP_GLOBAL,                       # 全局安装路径
        "$env:SystemDrive\Scoop",                # 系统驱动器根目录
        "$env:ProgramData\scoop",                # 系统程序数据目录
        "$env:USERPROFILE\scoop"                 # 用户目录 (默认)
    )
    
    foreach ($path in $searchPaths) {
        if ($path -and (Test-Path $path)) {
            Write-Host "✅ 发现Scoop安装: $path" -ForegroundColor Green
            return $path
        }
    }
    
    Write-Warning "未发现Scoop安装，将使用默认路径"
    return "$env:USERPROFILE\scoop"
}
```

**PowerShell配置路径适应**：

```powershell
function Get-PowerShellConfigPath {
    param([string]$PSVersion)
    
    # 使用.NET方法获取文档路径（支持重定向）
    $documentsPath = [Environment]::GetFolderPath('MyDocuments')
    
    # 根据PowerShell版本确定配置目录
    $configDir = if ($PSVersion -match '^[67]\.') {
        "PowerShell"           # PowerShell 6+
    } else {
        "WindowsPowerShell"    # Windows PowerShell 5.1
    }
    
    $configPath = Join-Path $documentsPath $configDir
    
    # 确保目录存在
    if (-not (Test-Path $configPath)) {
        New-Item -Path $configPath -ItemType Directory -Force | Out-Null
        Write-Host "✅ 创建配置目录: $configPath" -ForegroundColor Green
    }
    
    return $configPath
}
```

**Windows Terminal路径智能搜索**：

```powershell
function Find-WindowsTerminalConfig {
    $packagePaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_