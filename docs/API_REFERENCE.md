# 📚 API 参考文档

本文档提供了Windows Dotfiles管理系统v2.0所有脚本的详细API接口说明，包括参数、返回值、使用示例和错误处理。

## 📋 目录

- [统一管理接口](#统一管理接口)
  - [manage.ps1](#manageps1)
- [核心脚本 API](#核心脚本-api)
  - [detect-environment.ps1](#detect-environmentps1)
  - [install_apps.ps1](#install_appsps1)
  - [install.ps1](#installps1)
  - [health-check.ps1](#health-checkps1)
- [辅助工具 API](#辅助工具-api)
  - [tools/auto-sync.ps1](#toolsauto-syncps1)
  - [tools/dev-link.ps1](#toolsdev-linkps1)
  - [tools/validate-structure.ps1](#toolsvalidate-structureps1)
- [PowerShell 模块 API](#powershell-模块-api)
  - [DotfilesUtilities](#dotfilesutilities)
  - [EnvironmentAdapter](#environmentadapter)
  - [EnvironmentAdapter](#environmentadapter)
- [配置文件架构](#配置文件架构)
- [新架构说明](#新架构说明)
- [错误代码和异常处理](#错误代码和异常处理)

---

## 🎮 统一管理接口

### `manage.ps1`

**新增功能** - 统一管理接口，提供所有dotfiles操作的单一入口点。

#### 语法

```powershell
.\manage.ps1 <Command>
    [-Type <String[]>]
    [-Category <String>]
    [-Fix]
    [-Force]
    [-Detailed]
    [-DryRun]
    [-Interactive]
    [<CommonParameters>]
```

#### 参数

| 参数 | 类型 | 必需 | 默认值 | 说明 |
|------|------|------|--------|------|
| `Command` | String | 是 | - | 操作命令: detect, install-apps, deploy, health, status, setup, clean, help |
| `-Type` | String[] | 否 | - | 配置类型 (deploy命令使用) |
| `-Category` | String | 否 | - | 应用程序类别 (install-apps命令使用) |
| `-Fix` | Switch | 否 | False | 自动修复问题 (health命令使用) |
| `-Force` | Switch | 否 | False | 强制执行操作 |
| `-Detailed` | Switch | 否 | False | 显示详细输出 |
| `-DryRun` | Switch | 否 | False | 预览操作 |
| `-Interactive` | Switch | 否 | False | 交互式模式 |

#### 命令说明

| 命令 | 功能 | 等价操作 |
|------|------|----------|
| `detect` | 环境检测 | `.\detect-environment.ps1` |
| `install-apps` | 应用安装 | `.\install_apps.ps1` |
| `deploy` | 配置部署 | `.\install.ps1` |
| `health` | 健康检查 | `.\health-check.ps1` |
| `status` | 系统状态 | 新功能 |
| `setup` | 完整安装 | 所有脚本的组合 |
| `clean` | 清理维护 | 新功能 |
| `help` | 帮助信息 | 新功能 |

#### 使用示例

```powershell
# 完整安装流程
.\manage.ps1 setup

# 仅部署特定配置
.\manage.ps1 deploy -Type PowerShell,Git,Starship

# 健康检查并自动修复
.\manage.ps1 health -Fix

# 检查系统状态
.\manage.ps1 status

# 清理日志和缓存
.\manage.ps1 clean
```

#### 日志记录

统一管理接口的日志存储在新的集中化目录：
- **日志目录**: `.dotfiles/logs/`
- **日志格式**: `{operation}-{timestamp}.log`
- **自动清理**: 保留最近20个日志文件

---

## 🎯 核心脚本 API

### `detect-environment.ps1`

智能环境检测脚本，分析系统状态和已安装应用程序。

#### 语法

```powershell
.\detect-environment.ps1 
    [-Json]
    [-Detailed] 
    [-LogFile <String>]
    [-Quiet]
    [<CommonParameters>]
```

#### 参数

| 参数 | 类型 | 必需 | 默认值 | 说明 |
|------|------|------|--------|------|
| `-Json` | Switch | 否 | False | 以JSON格式输出结果 |
| `-Detailed` | Switch | 否 | False | 显示详细信息，包括应用程序版本和路径 |
| `-LogFile` | String | 否 | ".dotfiles/logs/detect-environment-{timestamp}.log" | 日志文件路径 |
| `-Quiet` | Switch | 否 | False | 静默模式，仅输出到日志文件 |

#### 返回值

**控制台输出格式**:
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
```

**JSON输出格式**:
```json
{
  "DetectionTime": "2024-01-15T14:30:25.1234567+08:00",
  "PowerShellVersion": "7.4.1",
  "System": {
    "Name": "Microsoft Windows 11 Pro",
    "Version": "10.0.22631",
    "Build": 22631,
    "Architecture": "AMD64",
    "IsWindows11": true
  },
  "Applications": {
    "Git": {
      "Name": "Git",
      "Installed": true,
      "Version": "2.43.0",
      "Path": "C:\\Program Files\\Git\\cmd\\git.exe",
      "InstallType": "System Install"
    }
  },
  "Recommendations": [
    "Environment detection completed successfully",
    "Found 15 installed applications out of 22 checked"
  ]
}
```

#### 使用示例

```powershell
# 基础环境检测
.\detect-environment.ps1

# 详细模式检测
.\detect-environment.ps1 -Detailed

# JSON格式输出并保存到文件
.\detect-environment.ps1 -Json | Out-File "environment-report.json"

# 静默模式检测
.\detect-environment.ps1 -Quiet -LogFile "silent-detection.log"

# 管道处理JSON数据
$env = .\detect-environment.ps1 -Json | ConvertFrom-Json
$installedApps = $env.Applications | Where-Object { $_.Installed -eq $true }
```

#### 错误处理

| 退出代码 | 含义 | 处理建议 |
|----------|------|----------|
| 0 | 成功完成 | 无需处理 |
| 1 | 权限不足 | 以管理员身份运行 |
| 2 | 系统不兼容 | 检查Windows版本和PowerShell版本 |
| 3 | 网络连接问题 | 检查网络连接或代理设置 |

---

### `install_apps.ps1`

基于Scoop的应用程序批量安装管理脚本。

#### 语法

```powershell
.\install_apps.ps1
    [-Category <String[]>]
    [-All]
    [-DryRun]
    [-Update]
    [-Retry]
    [-SkipInstalled]
    [-Quiet]
    [-CustomList <String>]
    [-Exclude <String[]>]
    [-Force]
    [-LogFile <String>]
    [<CommonParameters>]
```

#### 参数

| 参数 | 类型 | 必需 | 默认值 | 说明 |
|------|------|------|--------|------|
| `-Category` | String[] | 否 | @("Essential") | 要安装的应用程序分类 |
| `-All` | Switch | 否 | False | 安装所有分类的应用程序 |
| `-DryRun` | Switch | 否 | False | 预览模式，显示将要安装的应用但不实际执行 |
| `-Update` | Switch | 否 | False | 更新已安装的应用程序 |
| `-Retry` | Switch | 否 | False | 重试之前失败的安装 |
| `-SkipInstalled` | Switch | 否 | False | 跳过已安装的应用程序 |
| `-Quiet` | Switch | 否 | False | 静默安装模式 |
| `-CustomList` | String | 否 | $null | 自定义应用程序列表文件路径 |
| `-Exclude` | String[] | 否 | @() | 要排除的应用程序或分类 |
| `-Force` | Switch | 否 | False | 强制安装，覆盖现有安装 |
| `-LogFile` | String | 否 | "install-apps.log" | 日志文件路径 |

#### 应用程序分类

| 分类 | 应用数量 | 包含应用程序 |
|------|----------|--------------|
| **Essential** | 13 | git, ripgrep, zoxide, fzf, bat, fd, jq, neovim, starship, vscode, sudo, curl, 7zip |
| **Development** | 2 | shellcheck, gh |
| **GitEnhanced** | 1 | lazygit |
| **Programming** | 2 | python, nodejs |

#### 使用示例

```powershell
# 安装基础工具（默认）
.\install_apps.ps1

# 安装所有分类
.\install_apps.ps1 -All

# 安装特定分类
.\install_apps.ps1 -Category Development,Programming

# 预览安装计划
.\install_apps.ps1 -All -DryRun

# 更新已安装的应用
.\install_apps.ps1 -Update

# 静默安装并跳过已安装
.\install_apps.ps1 -All -Quiet -SkipInstalled

# 使用自定义应用列表
.\install_apps.ps1 -CustomList "my-apps.txt"

# 排除特定应用
.\install_apps.ps1 -All -Exclude git,vscode

# 强制重新安装
.\install_apps.ps1 -Category Essential -Force

# 检查环境兼容性并安装
if (.\detect-environment.ps1 -Json | ConvertFrom-Json | Select-Object -ExpandProperty System | Where-Object IsWindows11) {
    .\install_apps.ps1 -All
}
```

#### 返回对象

安装完成后返回安装报告对象：

```powershell
@{
    StartTime = [DateTime]
    EndTime = [DateTime]
    Duration = [TimeSpan]
    TotalApps = [int]
    SuccessfulInstalls = [int]
    FailedInstalls = [int]
    SkippedApps = [int]
    InstalledApps = [String[]]
    FailedApps = [String[]]
    SkippedApps = [String[]]
    Errors = [String[]]
}
```

---

### `install.ps1`

配置文件智能部署脚本，支持复制模式和符号链接模式。

#### 语法

```powershell
.\install.ps1
    [-DryRun]
    [-Type <String[]>]
    [-Mode <String>]
    [-Force]
    [-Rollback]
    [-Validate]
    [-Interactive]
    [-BackupDir <String>]
    [<CommonParameters>]
```

#### 参数

| 参数 | 类型 | 必需 | 默认值 | 说明 |
|------|------|------|--------|------|
| `-DryRun` | Switch | 否 | False | 预览模式，显示将要执行的操作 |
| `-Type` | String[] | 否 | 自动选择 | 指定要安装的配置类型 |
| `-Mode` | String | 否 | "Copy" | 安装模式：Copy或Symlink |
| `-Force` | Switch | 否 | False | 强制覆盖现有配置 |
| `-Rollback` | Switch | 否 | False | 回滚到备份状态 |
| `-Validate` | Switch | 否 | False | 验证现有安装的正确性 |
| `-Interactive` | Switch | 否 | False | 交互模式，逐步确认操作 |
| `-BackupDir` | String | 否 | "~\.dotfiles-backup" | 自定义备份目录 |


#### 支持的配置类型

| 类型 | 说明 | 配置文件 |
|------|------|----------|
| **PowerShell** | PowerShell配置文件和模块 | Microsoft.PowerShell_profile.ps1, *.ps1 |
| **Git** | Git全局配置和模板 | .gitconfig, .gitignore_global, .gitmessage |
| **Starship** | 命令行提示符配置 | starship.toml |
| **Scoop** | 包管理器配置 | config.json |
| **Neovim** | 编辑器配置 | init.lua, lua/* |
| **CMD** | 命令行工具脚本 | *.cmd, *.bat |
| **WindowsTerminal** | 终端配置 | settings.json |

#### 使用示例

```powershell
# 默认安装（复制模式，自动选择配置）
.\install.ps1

# 指定配置类型安装
.\install.ps1 -Type PowerShell,Git,Starship

# 符号链接模式安装
.\install.ps1 -Mode Symlink

# 强制覆盖现有配置
.\install.ps1 -Type Git -Force

# 预览安装计划
.\install.ps1 -DryRun -Type PowerShell,Git

# 交互模式安装
.\install.ps1 -Interactive

# 自定义备份目录
.\install.ps1 -BackupDir "D:\Backup\dotfiles"

# 强制覆盖现有配置
.\install.ps1 -Force

# 回滚到备份状态
.\install.ps1 -Rollback

# 验证安装结果
.\install.ps1 -Validate

# 企业环境安装
.\install.ps1 -Type PowerShell,Git -Mode Copy -Force -BackupDir "\\server\backup\$env:USERNAME"
```

#### 配置映射表

脚本内部维护的配置文件映射关系：

```powershell
$ConfigMappings = @{
    "Git" = @{
        "git\gitconfig" = "$env:USERPROFILE\.gitconfig"
        "git\gitignore_global" = "$env:USERPROFILE\.gitignore_global"
        "git\gitmessage" = "$env:USERPROFILE\.gitmessage"
        "git\gitconfig.d" = "$env:USERPROFILE\.gitconfig.d"
    }
    "PowerShell" = @{
        "powershell\Microsoft.PowerShell_profile.ps1" = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
        "powershell\.powershell" = "$env:USERPROFILE\.powershell"
    }
    # ... 其他配置类型
}
```

#### 安装报告

```powershell
@{
    InstallTime = [DateTime]
    Mode = [String]           # "Copy" 或 "Symlink"
    ConfigTypes = [String[]]  # 安装的配置类型
    FilesProcessed = [int]    # 处理的文件总数
    FilesSuccess = [int]      # 成功处理的文件数
    FilesFailed = [int]       # 失败的文件数
    BackupLocation = [String] # 备份目录路径
    Errors = [String[]]       # 错误信息列表
}
```

---


#### 状态报告输出

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

---

### `health-check.ps1`

全面的系统健康状态检查和自动修复脚本。

#### 语法

```powershell
.\health-check.ps1
    [-Fix]
    [-Detailed]
    [-OutputFormat <String>]
    [-Category <String>]
    [-LogFile <String>]
    [-ConfigOnly]
    [-Json]
    [<CommonParameters>]
```

#### 参数

| 参数 | 类型 | 必需 | 默认值 | 说明 |
|------|------|------|--------|------|
| `-Fix` | Switch | 否 | False | 自动修复检测到的问题 |
| `-Detailed` | Switch | 否 | False | 显示详细的检查信息 |
| `-OutputFormat` | String | 否 | "Console" | 输出格式：Console, JSON, Both |
| `-Category` | String | 否 | "All" | 检查类别：System, Applications, ConfigFiles, SymLinks, All |
| `-LogFile` | String | 否 | "health-check.log" | 日志文件路径 |
| `-ConfigOnly` | Switch | 否 | False | 仅检查配置文件（快速检查） |
| `-Json` | Switch | 否 | False | JSON格式输出（等同于-OutputFormat JSON） |

#### 检查类别

| 类别 | 检查内容 | 修复能力 |
|------|----------|----------|
| **System** | PowerShell版本、执行策略、系统兼容性、磁盘空间 | ✅ 自动修复配置问题 |
| **Applications** | 必需应用安装状态、版本检查、PATH设置 | ⚠️ 提供安装建议 |
| **ConfigFiles** | 配置文件完整性、语法验证、权限检查 | ✅ 自动修复语法错误 |
| **SymLinks** | 符号链接状态、目标有效性、权限检查 | ✅ 自动重建链接 |

#### 使用示例

```powershell
# 基本健康检查
.\health-check.ps1

# 详细检查并自动修复
.\health-check.ps1 -Detailed -Fix

# 仅检查特定类别
.\health-check.ps1 -Category Applications

# JSON格式输出
.\health-check.ps1 -Json

# 控制台和JSON双输出
.\health-check.ps1 -OutputFormat Both

# 快速配置检查
.\health-check.ps1 -ConfigOnly

# 生成健康报告
.\health-check.ps1 -Detailed -LogFile "health-$(Get-Date -Format 'yyyyMMdd').log"

# 自动化健康维护
$result = .\health-check.ps1 -Json | ConvertFrom-Json
if ($result.OverallStatus -ne "HEALTHY") {
    .\health-check.ps1 -Fix
}
```

#### 健康评分系统

```powershell
# 健康检查结果对象
@{
    Timestamp = [DateTime]
    OverallStatus = [String]        # "HEALTHY", "WARNING", "CRITICAL"
    OverallScore = [int]            # 0-100 总分
    Categories = @{
        System = @{
            Status = [String]       # "HEALTHY", "WARNING", "CRITICAL"
            Score = [int]           # 当前得分
            MaxScore = [int]        # 最大可能得分
            Issues = [String[]]     # 发现的问题
            Fixes = [String[]]      # 应用的修复
        }
        # ... 其他类别
    }
    Summary = @{
        TotalChecks = [int]         # 总检查项数
        PassedChecks = [int]        # 通过的检查数
        FailedChecks = [int]        # 失败的检查数
        FixedIssues = [int]         # 修复的问题数
    }
}
```

#### 控制台输出示例

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
  2. 运行 .\health-check.ps1 -Fix
```

---

## 🛠️ 辅助脚本 API

### `tools/auto-sync.ps1`

**路径更新** - 现位于 `tools/` 目录下。

配置文件自动同步脚本，支持增量同步和完整同步。

#### 语法

```powershell
.\auto-sync.ps1
    [-Mode <String>]
    [-Interval <int>]
    [-RemoteUrl <String>]
    [-AutoCommit]
    [-DryRun]
    [-Force]
    [<CommonParameters>]
```

#### 参数

| 参数 | 类型 | 必需 | 默认值 | 说明 |
|------|------|------|--------|------|
| `-Mode` | String | 否 | "Incremental" | 同步模式：Incremental, Full, OneTime |
| `-Interval` | int | 否 | 300 | 同步间隔（秒） |
| `-RemoteUrl` | String | 否 | origin | 远程仓库URL |
| `-AutoCommit` | Switch | 否 | False | 自动提交本地更改 |
| `-DryRun` | Switch | 否 | False | 预览模式 |
| `-Force` | Switch | 否 | False | 强制同步，忽略冲突 |

#### 使用示例

```powershell
# 一次性同步
.\auto-sync.ps1 -Mode OneTime

# 自动同步守护进程
.\auto-sync.ps1 -Mode Incremental -Interval 600 -AutoCommit

# 完整同步
.\auto-sync.ps1 -Mode Full -Force
```

---

## 📦 PowerShell 模块 API

### DotfilesUtilities

共享的PowerShell工具模块，提供通用功能函数。

#### 主要函数

##### `Write-DotfilesMessage`

统一的消息输出函数，支持颜色和图标。

```powershell
Write-DotfilesMessage
    [-Message] <String>
    [-Type <String>]
    [-NoNewLine]
    [-NoIcon]
    [-NoTimestamp]
```

**参数**:
- `Message`: 要显示的消息内容
- `Type`: 消息类型 (Success, Error, Warning, Info, Debug)
- `NoNewLine`: 不换行
- `NoIcon`: 不显示图标
- `NoTimestamp`: 不显示时间戳

**示例**:
```powershell
Write-DotfilesMessage "操作成功完成" -Type Success
Write-DotfilesMessage "发现潜在问题" -Type Warning
Write-DotfilesMessage "详细调试信息" -Type Debug
```

##### `Test-Administrator`

检查当前是否具有管理员权限。

```powershell
Test-Administrator
```

**返回值**: Boolean

**示例**:
```powershell
if (Test-Administrator) {
    Write-Host "具有管理员权限" -ForegroundColor Green
} else {
    Write-Host "需要管理员权限" -ForegroundColor Red
}
```

##### `Backup-File`

安全备份文件的函数。

```powershell
Backup-File
    [-SourcePath] <String>
    [-BackupDir <String>]
    [-Force]
```

**参数**:
- `SourcePath`: 源文件路径
- `BackupDir`: 备份目录，默认为 `~\.dotfiles-backup`
- `Force`: 覆盖现有备份

**返回值**: 备份文件的完整路径

**示例**:
```powershell
$backupPath = Backup-File -SourcePath "$env:USERPROFILE\.gitconfig"
Write-Host "文件已备份到: $backupPath"
```

##### `Test-SymbolicLink`

测试文件是否为有效的符号链接。

```powershell
Test-SymbolicLink
    [-Path] <String>
    [-Target <String>]
```

**参数**:
- `Path`: 要测试的文件路径
- `Target`: 可选，验证链接目标是否正确

**返回值**: Boolean 或 HashTable (详细信息)

**示例**:
```powershell
$isSymLink = Test-SymbolicLink -Path "$env:USERPROFILE\.gitconfig"
if ($isSymLink) {
    Write-Host "文件是符号链接" -ForegroundColor Green
}
```

---

### `tools/dev-link.ps1`

开发者模式符号链接管理工具。

#### 语法

```powershell
.\tools\dev-link.ps1 -Action <String>
    [-Component <String>]
    [-Force]
    [-Quiet]
    [<CommonParameters>]
```

#### 参数

| 参数 | 类型 | 必需 | 默认值 | 说明 |
|------|------|------|--------|------|
| `-Action` | String | 是 | - | 操作类型: Create, Remove, Status |
| `-Component` | String | 否 | - | 特定组件名称 |
| `-Force` | Switch | 否 | False | 强制操作 |
| `-Quiet` | Switch | 否 | False | 静默模式 |

### `tools/validate-structure.ps1`

**新增工具** - 项目结构验证脚本。

#### 语法

```powershell
.\tools\validate-structure.ps1
    [-Fix]
    [-Detailed]
    [-OutputFormat <String>]
    [<CommonParameters>]
```

#### 参数

| 参数 | 类型 | 必需 | 默认值 | 说明 |
|------|------|------|--------|------|
| `-Fix` | Switch | 否 | False | 自动修复结构问题 |
| `-Detailed` | Switch | 否 | False | 详细验证输出 |
| `-OutputFormat` | String | 否 | "Console" | 输出格式: Console, JSON, Both |

---

### `EnvironmentAdapter`

**新增模块** - 环境适应性功能模块。

#### 主要功能

- 自动路径检测和适配
- 多版本应用程序支持
- 环境变量管理
- 配置路径映射

---

## 🏗️ 新架构说明

### v2.0 架构变更

#### 目录结构

```
dotfiles/
├── manage.ps1              # 🎮 统一管理入口
├── [核心脚本]               # 原有4个核心脚本
├── configs/                # 📁 配置文件 (原根目录配置)
│   ├── git/
│   ├── powershell/
│   └── ...
├── tools/                  # 🔧 工具脚本 (原 scripts/ + 新工具)
├── .dotfiles/              # 🏗️ 基础设施
│   ├── logs/               # 📝 集中日志
│   ├── backups/           # 💾 备份目录
│   ├── cache/             # ⚡ 缓存目录
│   └── config-mapping.json # 📋 配置映射
└── docs/                   # 📚 精简文档
```

#### 主要变更

| 组件 | v1.x | v2.0 | 变更说明 |
|------|------|------|----------|
| **入口点** | 4个独立脚本 | `manage.ps1` + 4个核心脚本 | 统一界面 |
| **配置目录** | 根目录 | `configs/` | 逻辑分组 |
| **工具脚本** | `scripts/` | `tools/` | 重命名 + 扩展 |
| **日志系统** | 分散 | `.dotfiles/logs/` | 集中管理 |
| **基础设施** | 无 | `.dotfiles/` | 新增 |

---

## 📁 配置文件架构

### 应用程序分类配置

应用程序分类在 `scoop/packages.txt` 文件中定义：

```text
# Essential Apps (Core development tools)
git
ripgrep
zoxide
fzf
bat
fd
jq
neovim
starship
vscode
sudo
curl
7zip

# Development Apps (Additional dev tools)
shellcheck
gh

# GitEnhanced Apps (Git workflow tools)
lazygit

# Programming Apps (Language runtimes)
python
nodejs
```

### Git配置模板架构

`.gitconfig.local.example` 的标准架构：

```ini
[user]
    name = Your Name
    email = your.email@example.com

[http]
    proxy = http://127.0.0.1:10808

[https]
    proxy = http://127.0.0.1:10808

[includeIf "gitdir:~/work/"]
    path = ~/.gitconfig.work
```

### Starship配置架构

`starship.toml` 的标准结构：

```toml
[character]
success_symbol = "[➜](bold green)"
error_symbol = "[➜](bold red)"

[directory]
truncation_length = 3
truncation_symbol = "…/"

[git_branch]
symbol = "🌱 "
truncation_length = 8

[time]
disabled = false
format = "🕙[$time]($style) "
```

---

## ❌ 错误代码和异常处理

### 标准退出代码

| 退出代码 | 含义 | 适用脚本 | 处理建议 |
|----------|------|----------|----------|
| **0** | 操作成功 | 所有 | 无需处理 |
| **1** | 一般错误 | 所有 | 检查错误消息和日志 |
| **2** | 参数错误 | 所有 | 检查命令行参数语法 |
| **3** | 权限不足 | install.ps1 | 以管理员身份运行