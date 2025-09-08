# API 参考文档

本文档提供了 Dotfiles 项目中所有脚本的详细参数说明和使用示例。

## 📋 目录

- [核心脚本 API](#核心脚本-api)
- [辅助脚本 API](#辅助脚本-api)
- [公共函数库](#公共函数库)
- [配置文件格式](#配置文件格式)
- [返回值规范](#返回值规范)

## 🔧 核心脚本 API

### 1. detect-environment.ps1

**功能**: 检测系统环境和已安装应用程序

#### 语法
```powershell
.\detect-environment.ps1 [-Detailed] [-Json] [-LogFile <String>] [-WhatIf] [-Confirm]
```

#### 参数

| 参数 | 类型 | 必需 | 默认值 | 描述 |
|------|------|------|--------|------|
| `-Detailed` | Switch | 否 | False | 显示详细的检测信息 |
| `-Json` | Switch | 否 | False | 以 JSON 格式输出结果 |
| `-LogFile` | String | 否 | null | 指定日志文件路径 |
| `-WhatIf` | Switch | 否 | False | 显示将要执行的操作但不实际执行 |
| `-Confirm` | Switch | 否 | False | 在执行操作前请求确认 |

#### 返回值
- **成功**: 退出代码 0，输出环境检测报告
- **失败**: 退出代码 1，输出错误信息

#### 输出格式

**标准输出**:
```
=== 系统环境检测报告 ===
Windows 版本: Windows 11 Pro (10.0.22621)
PowerShell 版本: 7.3.6
已安装应用程序:
  ✓ Git: 2.41.0 (C:\Program Files\Git\bin\git.exe)
  ✓ Visual Studio Code: 1.81.0 (Scoop)
  ✗ Neovim: 未安装
```

**JSON 输出**:
```json
{
  "timestamp": "2025-01-08T12:00:00Z",
  "system": {
    "os": "Windows 11 Pro",
    "version": "10.0.22621",
    "architecture": "x64"
  },
  "powershell": {
    "version": "7.3.6",
    "edition": "Core"
  },
  "applications": [
    {
      "name": "git",
      "installed": true,
      "version": "2.41.0",
      "path": "C:\\Program Files\\Git\\bin\\git.exe",
      "installMethod": "System"
    }
  ],
  "recommendations": [
    "安装 Neovim 以获得更好的编辑体验"
  ]
}
```

#### 使用示例

```powershell
# 基本检测
.\detect-environment.ps1

# 详细检测并保存日志
.\detect-environment.ps1 -Detailed -LogFile "detection.log"

# JSON 格式输出到文件
.\detect-environment.ps1 -Json > environment.json

# 预览模式
.\detect-environment.ps1 -WhatIf
```

### 2. install_apps.ps1

**功能**: 基于 Scoop 的应用程序批量安装

#### 语法
```powershell
.\install_apps.ps1 [-Category <String[]>] [-All] [-DryRun] [-Update] [-Force] [-LogFile <String>]
```

#### 参数

| 参数 | 类型 | 必需 | 默认值 | 描述 |
|------|------|------|--------|------|
| `-Category` | String[] | 否 | @("Essential") | 要安装的包分类 |
| `-All` | Switch | 否 | False | 安装所有分类的包 |
| `-DryRun` | Switch | 否 | False | 预览模式，不实际安装 |
| `-Update` | Switch | 否 | False | 更新已安装的包 |
| `-Force` | Switch | 否 | False | 强制重新安装 |
| `-LogFile` | String | 否 | null | 指定日志文件路径 |

#### 包分类

| 分类 | 包数量 | 描述 | 包含应用 |
|------|--------|------|----------|
| `Essential` | 13 | 核心开发工具 | git, ripgrep, zoxide, fzf, bat, fd, jq, neovim, starship, vscode, sudo, curl, 7zip |
| `Development` | 2 | 开发辅助工具 | shellcheck, gh |
| `GitEnhanced` | 1 | Git 增强工具 | lazygit |
| `Programming` | 2 | 编程语言运行时 | python, nodejs |

#### 返回值
- **成功**: 退出代码 0
- **部分失败**: 退出代码 1
- **完全失败**: 退出代码 2

#### 使用示例

```powershell
# 安装核心工具
.\install_apps.ps1

# 安装所有工具
.\install_apps.ps1 -All

# 安装特定分类
.\install_apps.ps1 -Category Development,Programming

# 预览安装
.\install_apps.ps1 -All -DryRun

# 更新已安装包
.\install_apps.ps1 -Update

# 强制重新安装核心工具
.\install_apps.ps1 -Force -LogFile "install.log"
```

### 3. install.ps1

**功能**: 配置文件智能部署和管理

#### 语法
```powershell
.\install.ps1 [-Mode <String>] [-Type <String[]>] [-DryRun] [-Force] [-Restore] [-SetDevMode] [-LogFile <String>]
```

#### 参数

| 参数 | 类型 | 必需 | 默认值 | 描述 |
|------|------|------|--------|------|
| `-Mode` | String | 否 | "Copy" | 部署模式：Copy 或 Symlink |
| `-Type` | String[] | 否 | @() | 指定要部署的配置类型 |
| `-DryRun` | Switch | 否 | False | 预览模式，不实际部署 |
| `-Force` | Switch | 否 | False | 强制覆盖现有配置 |
| `-Restore` | Switch | 否 | False | 从备份恢复配置 |
| `-SetDevMode` | Switch | 否 | False | 启用开发模式 |
| `-LogFile` | String | 否 | null | 指定日志文件路径 |

#### 配置类型

| 类型 | 描述 | 包含文件 |
|------|------|----------|
| `Git` | Git 配置 | gitconfig, gitignore_global, gitmessage |
| `PowerShell` | PowerShell 配置 | Microsoft.PowerShell_profile.ps1 |
| `Neovim` | Neovim 配置 | init.lua, 插件配置 |
| `Starship` | 命令行提示符 | starship.toml |
| `WindowsTerminal` | Windows Terminal | settings.json |


#### 返回值
- **成功**: 退出代码 0
- **部分失败**: 退出代码 1
- **完全失败**: 退出代码 2

#### 使用示例

```powershell
# 默认部署（复制模式）
.\install.ps1

# 符号链接模式
.\install.ps1 -Mode Symlink

# 部署特定配置
.\install.ps1 -Type Git,PowerShell,Neovim

# 预览部署
.\install.ps1 -DryRun -Type All

# 强制覆盖
.\install.ps1 -Force

# 恢复备份
.\install.ps1 -Restore -Type PowerShell

# 启用开发模式
.\install.ps1 -SetDevMode
```

### 4. dev-link.ps1

**功能**: 开发者专用符号链接管理

#### 语法
```powershell
.\dev-link.ps1 [-Action <String>] [-Type <String[]>] [-Verify] [-List] [-Remove] [-DryRun] [-Force] [-LogFile <String>]
```

#### 参数

| 参数 | 类型 | 必需 | 默认值 | 描述 |
|------|------|------|--------|------|
| `-Action` | String | 否 | "Create" | 操作类型：Create, Verify, List, Remove |
| `-Type` | String[] | 否 | @() | 指定配置类型 |
| `-Verify` | Switch | 否 | False | 验证符号链接状态 |
| `-List` | Switch | 否 | False | 列出所有符号链接 |
| `-Remove` | Switch | 否 | False | 删除符号链接 |
| `-DryRun` | Switch | 否 | False | 预览模式 |
| `-Force` | Switch | 否 | False | 强制操作 |
| `-LogFile` | String | 否 | null | 指定日志文件路径 |

#### 返回值
- **成功**: 退出代码 0
- **部分失败**: 退出代码 1
- **完全失败**: 退出代码 2

#### 使用示例

```powershell
# 创建所有符号链接
.\dev-link.ps1

# 验证符号链接状态
.\dev-link.ps1 -Verify

# 列出符号链接状态
.\dev-link.ps1 -List

# 删除特定符号链接
.\dev-link.ps1 -Remove -Type Neovim

# 预览创建操作
.\dev-link.ps1 -DryRun

# 强制重新创建
.\dev-link.ps1 -Force
```

### 5. health-check.ps1

**功能**: 系统健康状态检查和修复

#### 语法
```powershell
.\health-check.ps1 [-Detailed] [-Fix] [-ConfigOnly] [-Json] [-LogFile <String>]
```

#### 参数

| 参数 | 类型 | 必需 | 默认值 | 描述 |
|------|------|------|--------|------|
| `-Detailed` | Switch | 否 | False | 显示详细检查报告 |
| `-Fix` | Switch | 否 | False | 自动修复发现的问题 |
| `-ConfigOnly` | Switch | 否 | False | 仅检查配置文件 |
| `-Json` | Switch | 否 | False | JSON 格式输出 |
| `-LogFile` | String | 否 | null | 指定日志文件路径 |

#### 检查类别

| 类别 | 描述 | 检查项目 |
|------|------|----------|
| `ConfigFiles` | 配置文件完整性 | 文件存在性、语法正确性、权限检查 |
| `SymbolicLinks` | 符号链接状态 | 链接有效性、目标正确性、孤立链接 |
| `Applications` | 应用程序状态 | Scoop 健康、包安装状态、关键应用 |
| `SystemCompatibility` | 系统兼容性 | PowerShell 版本、Windows 版本、执行策略 |
| `BackupFiles` | 备份文件管理 | 备份文件数量、旧文件清理 |
| `Templates` | 模板文件验证 | 模板语法、变量占位符 |

#### 返回值
- **健康**: 退出代码 0
- **发现问题**: 退出代码 1
- **检查失败**: 退出代码 2

#### 输出格式

**标准输出**:
```
============================================================
Dotfiles 系统健康检查报告
============================================================
检查时间: 2025-01-08 12:00:00
检查耗时: 2.3 秒
总体状态: Good
健康评分: 85 / 100 (85.0%)

分类状态:
  ✓ ConfigFiles: Healthy (10/10, 100%)
  ⚠ SymbolicLinks: Warning (8/10, 80%)
  ✓ Applications: Healthy (15/15, 100%)
  ✓ SystemCompatibility: Healthy (5/5, 100%)
  ✓ BackupFiles: Healthy (1/1, 100%)
  ✓ Templates: Healthy (3/3, 100%)

发现的问题:
  中优先级 (2):
    • 符号链接目标错误: C:\Users\User\.gitconfig
    • 孤立符号链接: C:\Users\User\.old-config

建议:
  • 重新创建损坏的符号链接
  • 清理孤立的符号链接
============================================================
```

#### 使用示例

```powershell
# 基本健康检查
.\health-check.ps1

# 详细检查
.\health-check.ps1 -Detailed

# 自动修复问题
.\health-check.ps1 -Fix

# 仅检查配置文件
.\health-check.ps1 -ConfigOnly

# 生成 JSON 报告
.\health-check.ps1 -Json -LogFile "health-$(Get-Date -Format 'yyyyMMdd').log"
```

## 🛠️ 辅助脚本 API

### 1. auto-sync.ps1

**功能**: 自动同步配置文件

#### 语法
```powershell
.\auto-sync.ps1 [-Mode <String>] [-DryRun] [-Force]
```

#### 参数

| 参数 | 类型 | 必需 | 默认值 | 描述 |
|------|------|------|--------|------|
| `-Mode` | String | 否 | "Incremental" | 同步模式：Incremental, Full |
| `-DryRun` | Switch | 否 | False | 预览模式，不实际执行 |
| `-Force` | Switch | 否 | False | 强制覆盖现有配置 |

## 📚 公共函数库

### 日志记录函数

```powershell
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO",
        [string]$LogFile = $null
    )
}
```

### 路径检测函数

```powershell
function Get-ConfigPath {
    param(
        [string]$Application,
        [string]$ConfigType = "Config"
    )
}
```

### 备份管理函数

```powershell
function New-ConfigBackup {
    param(
        [string]$FilePath,
        [string]$BackupSuffix = ".backup"
    )
}

function Restore-ConfigBackup {
    param(
        [string]$FilePath,
        [string]$BackupSuffix = ".backup"
    )
}
```

### 符号链接管理函数

```powershell
function New-SymbolicLinkSafe {
    param(
        [string]$Path,
        [string]$Target,
        [switch]$Force
    )
}

function Test-SymbolicLink {
    param(
        [string]$Path
    )
}
```

## 📄 配置文件格式

### 包配置文件 (scoop/packages.txt)

```
# 核心开发工具 (Essential)
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

# 开发辅助工具 (Development)
shellcheck
gh

# Git 增强工具 (GitEnhanced)
lazygit

# 编程语言运行时 (Programming)
python
nodejs
```

### 项目配置文件 (config/project.json)

```json
{
  "version": "1.0.0",
  "name": "dotfiles",
  "description": "Windows 开发环境配置管理",
  "author": "Project Team",
  "repository": "https://github.com/username/dotfiles",
  "settings": {
    "defaultMode": "Copy",
    "backupEnabled": true,
    "logLevel": "INFO",
    "healthCheckInterval": "weekly"
  },
  "features": {
    "autoUpdate": false,
    "telemetry": false,
    "experimentalFeatures": false
  }
}
```

### 模板变量文件 (templates/variables.json)

```json
{
  "user": {
    "name": "{{USER_NAME}}",
    "email": "{{USER_EMAIL}}",
    "github": "{{GITHUB_USERNAME}}"
  },
  "system": {
    "hostname": "{{HOSTNAME}}",
    "username": "{{USERNAME}}",
    "home": "{{HOME_PATH}}"
  },
  "preferences": {
    "theme": "{{THEME}}",
    "editor": "{{EDITOR}}",
    "shell": "{{SHELL}}"
  }
}
```

## 📊 返回值规范

### 退出代码

| 代码 | 含义 | 描述 |
|------|------|------|
| 0 | 成功 | 操作完全成功 |
| 1 | 部分失败 | 部分操作失败，但主要功能正常 |
| 2 | 完全失败 | 操作完全失败 |
| 3 | 用户取消 | 用户主动取消操作 |
| 4 | 权限不足 | 缺少必要的权限 |
| 5 | 依赖缺失 | 缺少必要的依赖项 |

### 标准输出格式

#### 成功消息
```
✓ 操作成功: 具体描述
```

#### 警告消息
```
⚠ 警告: 具体描述
```

#### 错误消息
```
✗ 错误: 具体描述
```

#### 信息消息
```
ℹ 信息: 具体描述
```

### JSON 输出格式

```json
{
  "timestamp": "2025-01-08T12:00:00Z",
  "script": "script-name.ps1",
  "version": "1.0.0",
  "success": true,
  "exitCode": 0,
  "duration": 2.5,
  "data": {
    // 具体数据
  },
  "warnings": [
    "警告信息1",
    "警告信息2"
  ],
  "errors": [
    "错误信息1"
  ]
}
```

## 🔍 错误处理

### 常见错误代码

| 错误代码 | 描述 | 解决方案 |
|----------|------|----------|
| `DOTFILES_001` | PowerShell 版本过低 | 升级 PowerShell 到 5.1+ |
| `DOTFILES_002` | 执行策略限制 | 设置执行策略为 RemoteSigned |
| `DOTFILES_003` | 权限不足 | 以管理员身份运行 |
| `DOTFILES_004` | Scoop 未安装 | 运行 install_apps.ps1 安装 Scoop |
| `DOTFILES_005` | 配置文件冲突 | 使用 -Force 参数或手动解决冲突 |
| `DOTFILES_006` | 网络连接失败 | 检查网络连接或配置代理 |
| `DOTFILES_007` | 磁盘空间不足 | 清理磁盘空间 |
| `DOTFILES_008` | 符号链接创建失败 | 启用开发者模式或以管理员身份运行 |

### 错误处理示例

```powershell
try {
    $result = Invoke-SomeOperation
    Write-Log "操作成功" "SUCCESS"
}
catch [System.UnauthorizedAccessException] {
    Write-Log "权限不足 (DOTFILES_003): $($_.Exception.Message)" "ERROR"
    exit 4
}
catch [System.IO.FileNotFoundException] {
    Write-Log "文件未找到: $($_.Exception.Message)" "ERROR"
    exit 2
}
catch {
    Write-Log "未知错误: $($_.Exception.Message)" "ERROR"
    exit 2
}
```

---

**📝 注意**: 本文档会随着项目更新而持续维护。如有疑问，请参考脚本内置的帮助信息：`Get-Help .\script-name.ps1 -Full`