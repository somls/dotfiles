# 📖 用户使用指南

**更新时间**: 2025-01-15  
**适用对象**: 普通用户、初学者、日常使用者

> 💡 **提示**: 本文档面向日常用户，提供简洁实用的使用指南。技术细节请查看 [docs/](docs/) 目录下的详细文档。

## 🎯 系统特性

本系统采用文件复制方式部署配置，具有以下特点：

- ✅ **稳定可靠**: 配置文件独立存在，不依赖源码
- ✅ **权限友好**: 无需管理员权限，普通用户即可使用
- ✅ **智能适配**: 自动检测应用程序路径和版本差异
- ✅ **安全备份**: 自动备份现有配置，支持一键回滚
- ✅ **广泛兼容**: 支持 Windows 10/11 和 PowerShell 5.1+

## 🚀 快速开始

### 📋 安装前准备

确保您的系统满足基本要求：
- Windows 10 (1903+) 或 Windows 11
- PowerShell 5.1+ （推荐 PowerShell 7+）
- 稳定的网络连接

### ⚡ 标准安装流程（推荐）

```powershell
# 1. 克隆项目
git clone https://github.com/somls/dotfiles.git
cd dotfiles

# 2. 统一管理界面 - 一键完整安装（推荐）
.\manage.ps1 setup          # 🚀 完整安装流程 (检测+安装+部署+验证)

# 或者分步骤执行
.\manage.ps1 detect         # 🔍 检测系统环境 (检测22+应用)
.\manage.ps1 install-apps   # 📦 安装开发工具 (18+精选应用)
.\manage.ps1 deploy         # ⚙️ 部署配置文件 (智能路径映射)
.\manage.ps1 health -Fix    # 🏥 验证安装结果 (完整性检查)
```

### 🏃‍♂️ 快速安装（适合有经验的用户）

```powershell
# 仅部署配置文件
.\manage.ps1 deploy

# 指定组件安装
.\manage.ps1 deploy -Type PowerShell,Git,Starship

# 交互式安装，逐个确认
.\manage.ps1 deploy -Interactive

# 检查当前状态
.\manage.ps1 status
```

## 🎯 常用场景

### 场景1: 新电脑环境搭建

```powershell
# 完整的开发环境搭建
.\manage.ps1 setup -Detailed         # 完整安装流程（详细模式）

# 或者分步骤执行
.\manage.ps1 detect -Detailed        # 详细环境分析（检测22+应用）
.\manage.ps1 install-apps -Category All  # 安装所有应用（18+精选应用）
.\manage.ps1 deploy -Interactive     # 交互式配置部署
.\manage.ps1 health -Fix             # 自动修复问题

# 验证结果
.\manage.ps1 health -Detailed        # 查看详细报告
.\manage.ps1 status                  # 查看系统状态
```

### 场景2: 配置问题诊断

```powershell
# 系统诊断和修复
.\manage.ps1 health -Fix             # 基础诊断和自动修复
.\manage.ps1 health -Detailed        # 查看详细诊断信息

# 查看当前状态
.\manage.ps1 status                  # 快速状态检查

# 清理日志和缓存
.\manage.ps1 clean                   # 清理旧日志和临时文件
```

### 场景3: 配置更新和维护

```powershell
# 更新配置
git pull                              # 更新源码
.\manage.ps1 deploy -Force           # 强制重新部署
.\manage.ps1 health                  # 验证更新结果
```

### 场景4: 仅配置管理

```powershell
# 只想使用配置文件，不安装应用
.\manage.ps1 deploy -Type PowerShell,Git,Starship
.\manage.ps1 health
```

### 场景3: 企业环境部署

```powershell
# 企业网络环境（可能有代理限制）
.\detect-environment.ps1 -Json > environment-audit.json
.\install_apps.ps1 -Category Essential -DryRun  # 预览安装
.\install.ps1 -Mode Copy -Force                # 确保使用复制模式
```

## 🛠️ 配置管理

### 支持的配置类型

| 配置类型 | 说明 | 配置文件 |
|----------|------|----------|
| **PowerShell** | PowerShell配置文件和模块 | Microsoft.PowerShell_profile.ps1 |
| **Git** | Git全局配置和模板 | .gitconfig, .gitignore_global |
| **Starship** | 命令行提示符配置 | starship.toml |
| **Scoop** | 包管理器配置 | config.json |
| **WindowsTerminal** | 终端配置 | settings.json |
| **Neovim** | 编辑器配置（可选） | init.lua, lua/* |

### 选择性安装

```powershell
# 查看支持的配置类型
.\install.ps1 -Type ?

# 安装特定配置
.\install.ps1 -Type PowerShell,Git
.\install.ps1 -Type Starship,WindowsTerminal
.\install.ps1 -Type Neovim  # 可选组件

# 交互式选择
.\install.ps1 -Interactive
```

### 预览模式

```powershell
# 预览安装计划（不实际执行）
.\install.ps1 -DryRun
.\install.ps1 -DryRun -Type PowerShell,Git

# 预览应用安装
.\install_apps.ps1 -Category Essential -DryRun
```

## 📦 应用程序管理

### 应用程序分类

| 分类 | 应用程序 | 适用场景 |
|------|----------|----------|
| **Essential** | git, ripgrep, zoxide, fzf, bat, fd, jq, neovim, starship, vscode, sudo, curl, 7zip | 核心开发工具（13个） |
| **Development** | shellcheck, gh, nodejs, python | 开发增强工具（4个） |
| **GitEnhanced** | lazygit | Git图形化工具（1个） |

### 应用安装命令

```powershell
# 安装核心工具
.\install_apps.ps1 -Category Essential

# 安装开发工具
.\install_apps.ps1 -Category Development

# 安装所有应用
.\install_apps.ps1 -Category All

# 安装特定应用
.\install_apps.ps1 -Apps git,nodejs,python

# 强制重新安装
.\install_apps.ps1 -Category Essential -Force
```

## 🏥 健康检查和维护

### 基本健康检查

```powershell
# 基本健康检查
.\health-check.ps1

# 详细检查报告
.\health-check.ps1 -Detailed

# 自动修复问题
.\health-check.ps1 -Fix

# 检查特定组件
.\health-check.ps1 -Component PowerShell
```

### 日常维护

```powershell
# 定期运行（建议每月一次）
.\health-check.ps1 -Fix
.\detect-environment.ps1 -Detailed

# 更新应用程序
.\install_apps.ps1 -Update

# 重新应用配置
.\install.ps1 -Force
```

## 🔧 自定义配置

### 个人化配置

项目提供了配置模板文件，您可以根据需要自定义：

```powershell
# Git个人配置
copy git\gitconfig.local.example git\gitconfig.local
notepad git\gitconfig.local  # 编辑个人信息

# Scoop配置
copy scoop\config.json.example scoop\config.json
notepad scoop\config.json  # 编辑代理等设置
```

### 环境变量设置

```powershell
# PowerShell配置中添加环境变量
# 编辑 powershell\Microsoft.PowerShell_profile.ps1
$env:CUSTOM_PATH = "C:\YourCustomPath"
```

## 🐛 常见问题解决

### 安装问题

**问题**: 安装失败或中断
```powershell
# 解决方案
.\health-check.ps1 -Fix
.\install.ps1 -Force  # 强制重新安装
```

**问题**: PowerShell执行策略限制
```powershell
# 解决方案
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 配置问题

**问题**: 配置未生效
```powershell
# PowerShell配置
# 重新启动PowerShell或运行:
. $PROFILE

# Windows Terminal配置
# 重新启动Windows Terminal应用
```

**问题**: 找不到配置文件
```powershell
# 检查配置文件位置
.\health-check.ps1 -Component PowerShell -Detailed
```

### 应用程序问题

**问题**: Scoop安装失败
```powershell
# 检查网络连接
Test-NetConnection github.com -Port 443

# 重新安装Scoop
.\install_apps.ps1 -Apps scoop -Force
```

## 📊 系统信息

### 环境检测

```powershell
# 基本环境信息
.\detect-environment.ps1

# 详细环境分析
.\detect-environment.ps1 -Detailed

# 输出JSON格式（用于审计）
.\detect-environment.ps1 -Json > system-info.json
```

### 配置备份

```powershell
# 查看备份位置
# 默认备份目录: %USERPROFILE%\.dotfiles-backup

# 手动备份当前配置
Copy-Item $PROFILE "$env:USERPROFILE\.config-backup\$(Get-Date -Format 'yyyyMMdd')-profile.ps1"
```

## 🆘 获取帮助

### 脚本帮助

```powershell
# 查看脚本帮助信息
Get-Help .\install.ps1 -Full
Get-Help .\install_apps.ps1 -Examples
Get-Help .\health-check.ps1 -Parameter Fix
```

### 文档资源

- **[用户指南](docs/USER_GUIDE.md)** - 详细的用户操作指南
- **[常见问题](docs/FAQ.md)** - 常见问题和解答
- **[故障排除](docs/TROUBLESHOOTING.md)** - 问题诊断和解决
- **[API参考](docs/API_REFERENCE.md)** - 脚本参数和功能详情

### 社区支持

- **问题报告**: [GitHub Issues](https://github.com/somls/dotfiles/issues)
- **功能讨论**: [GitHub Discussions](https://github.com/somls/dotfiles/discussions)

## ⚠️ 注意事项

### 重要提醒

1. **备份**: 安装前会自动备份现有配置，位置在 `%USERPROFILE%\.dotfiles-backup`
2. **权限**: 大部分操作仅需标准用户权限，部分功能可能需要管理员权限
3. **网络**: 应用安装需要网络连接，企业环境请注意代理配置
4. **兼容性**: 支持 Windows 10 (1903+) 和 Windows 11

### 最佳实践

- 定期运行 `.\health-check.ps1` 进行系统检查
- 使用 `-DryRun` 参数预览操作结果
- 保持项目目录整洁，避免手动修改核心文件
- 使用提供的模板文件进行个性化配置

---

> **提示**: 这是简化的用户指南。如需了解更多技术细节或高级功能，请查看 [docs/](docs/) 目录下的详细文档。