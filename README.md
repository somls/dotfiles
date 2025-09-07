# Windows 10/11 Dotfiles

<div align="center">

## 🎯 高效 • 简洁 • 实用

**专为 Windows 设计的现代化 dotfiles 管理系统**

[![PowerShell](https://img.shields.io/badge/PowerShell-7.0+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Windows](https://img.shields.io/badge/Windows-11-blue.svg)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-2.1-orange.svg)](CHANGELOG.md)

</div>

---

### ✨ 核心理念

🚀 **高效** - 一键部署，智能检测，自动修复
🎯 **简洁** - 模块化设计，清晰结构，精简依赖
🛠️ **实用** - 开发友好，日常必备，性能优化

### 🌟 主要特性

| 特性 | 描述 | 状态 |
|------|------|------|
| 🚀 **一键部署** | 30秒完成所有配置安装 | ✅ |
| ⚡ **快速启动** | PowerShell 1-2秒加载（支持快速模式） | ✅ |
| 🔧 **智能修复** | 自动检测和修复配置问题 | ✅ |
| 📦 **精简工具集** | 28个核心包，覆盖90%使用场景 | ✅ |
| 🔒 **安全存储** | 敏感配置加密保护 | ✅ |
| 🎨 **个性化配置** | 支持自定义主题和配色 | ✅ |
| 🔄 **智能同步** | 自动处理本地远程配置同步 | ✅ |
| 🩺 **健康检查** | 全面的配置验证系统 | ✅ |
| 📊 **性能优化** | Scoop包精简，减少55%的包数量 | ✅ |

## 📁 项目结构

> 📖 详细结构说明请参考 [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)

### 🚀 核心脚本
- **`install.ps1`**: 智能配置安装脚本（主要安装工具）
- **`setup.ps1`**: 快速设置向导（推荐新用户）
- **`install_apps.ps1`**: Scoop包管理安装脚本
- **`detect-environment.ps1`**: 智能环境检测脚本
- **`health-check.ps1`**: 配置健康检查和验证

### 📂 配置目录
- **`git/`**: Git 全局配置和模板
- **`powershell/`**: PowerShell 配置文件和模块
- **`WindowsTerminal/`**: Windows Terminal 配置
- **`Alacritty/`**: Alacritty 终端配置
- **`WezTerm/`**: WezTerm 终端配置
- **`starship/`**: Starship 提示符配置
- **`scoop/`**: Scoop 包管理器配置
- **`neovim/`**: Neovim 编辑器配置和插件管理

### 📚 文档
- **`QUICK_REFERENCE.md`**: 快速参考卡
- **`TOOLS_GUIDE.md`**: 🛠️ 工具使用详细指南
- **`TOOLS_CHEATSHEET.md`**: 🚀 工具快速参考卡
- **`QUICKSTART.md`**: 5分钟快速开始指南
- **`TROUBLESHOOTING.md`**: 故障排除文档
- **`SECURITY.md`**: 安全配置指南和个人信息保护

## 🚀 快速开始

### 📋 系统要求

- **操作系统**: Windows 10/11 (自动适配版本差异)
- **PowerShell**: 5.1+ (推荐 PowerShell 7+)
- **权限**: 普通用户权限即可
- **网络**: 互联网连接（用于下载工具）

### 🔄 跨版本兼容性

本项目支持 Windows 10 和 Windows 11 的自动适配：

- **自动检测**: 智能识别 Windows 版本和应用安装方式
- **路径适配**: 自动适配不同版本的配置目录路径
- **多安装支持**: 支持应用的用户安装、系统安装、便携版等多种方式

### ⚡ 一键安装（推荐）

```powershell
# 1. 克隆仓库到本地
git clone https://github.com/somls/dotfiles.git C:\dotfiles
cd C:\dotfiles

# 2. 快速设置向导（推荐新用户）
.\setup.ps1

# 3. 或直接安装（智能选择组件）
.\install.ps1
# 默认安装：Scoop, CMD, PowerShell, Starship, Git, WindowsTerminal

# 4. 选择特定配置
.\install.ps1 -Profile optimized    # 优化配置（精简包）
.\install.ps1 -Profile standard      # 标准配置
.\install.ps1 -Profile developer     # 开发者配置
.\install.ps1 -Profile minimal       # 最小配置
```

### 🎯 安装配置选项

| 配置 | 描述 | 包数量 | 适用场景 |
|------|------|---------|----------|
| **Essential** | 核心开发工具 | 13个 | 基础必需工具，覆盖90%日常场景 |
| **Development** | 开发工具扩展 | +2个 | 代码检查和GitHub集成 |
| **GitEnhanced** | Git可视化 | +1个 | Git终端界面管理 |
| **Programming** | 编程语言 | +2个 | Python和Node.js运行时 |
| **All** | ⭐ 完整配置 | 18个 | **推荐**，精选优化包集合 |

### 📦 优化配置特点

**All** 配置是我们的推荐选项（基于 scoop/packages.txt）：

- ✅ **精选包集合**: 经过优化的18个核心开发工具
- ✅ **分类管理**: Essential(13) + Development(2) + GitEnhanced(1) + Programming(2)
- ✅ **高效安装**: 支持按分类选择性安装
- ✅ **完整覆盖**: 涵盖版本控制、文本处理、代码编辑、语言运行时
- ✅ **快速启动**: 轻量化配置，优化的启动性能

### 🔧 应用程序安装

```powershell
# 安装核心工具（推荐，13个包）
.\install_apps.ps1

# 安装所有工具（18个包）
.\install_apps.ps1 -All

# 按分类安装
.\install_apps.ps1 -Essential -Programming
.\install_apps.ps1 -Development -GitEnhanced

# 预览安装（不实际执行）
.\install_apps.ps1 -DryRun -All

# 更新已安装的包
.\install_apps.ps1 -Update
```

### 🔧 手动配置安装（可选）

```powershell
# 指定组件安装
.\install.ps1 -Type PowerShell,Git,Neovim

# 预览安装（不实际执行）
.\install.ps1 -DryRun

# 仅安装配置文件
.\install.ps1 -Type Scoop
```

### 📦 组件说明

#### 🔧 默认组件（自动安装）
| 组件 | 描述 | 配置内容 |
|------|------|----------|
| **Scoop** | 包管理器 | 软件源、配置选项 |
| **CMD** | 命令提示符 | 别名、快捷命令 |
| **PowerShell** | 命令行终端 | 配置文件、函数、别名 |
| **Starship** | 命令提示符 | 主题配置、模块设置 |
| **Git** | 版本控制系统 | 全局配置、别名、模板 |
| **WindowsTerminal** | 现代终端 | 主题、配置文件 |

#### 🎨 可选组件（用户选择）
| 组件 | 描述 | 配置内容 |
|------|------|----------|
| **Alacritty** | GPU 加速终端 | 配置文件、主题 |
| **WezTerm** | GPU 加速终端 | 配置文件、主题 |
| **Neovim** | 文本编辑器 | 插件、配置、主题 |

### 🔧 智能配置安装

#### 🤖 智能安装（推荐）
```powershell
# 智能安装所有配置
.\install.ps1

# 预览安装计划
.\install.ps1 -DryRun

# 选择性安装组件
.\install.ps1 -Type PowerShell,Git,Neovim

# 交互式安装
.\install.ps1 -Interactive
```

#### 🔧 高级功能
```powershell
# 指定组件安装
.\install.ps1 -Type PowerShell,Git,Neovim -Force

# 回滚到备份
.\install.ps1 -Rollback

# 环境检测
.\detect-environment.ps1 -Detailed

# 安装软件包
.\install_apps.ps1 -Category Essential,Development

# 验证安装
.\health-check.ps1 -Detailed
```

### 🎯 使用场景指南

| 使用场景 | 推荐命令 | 特点 |
|----------|----------|------|
| 🚀 **首次安装** | `.\setup.ps1` | 快速设置向导 |
| 🔧 **日常使用** | `.\install.ps1` | 智能安装，自动选择组件 |
| ⚡ **快速更新** | `.\install.ps1 -Type PowerShell,Git` | 指定组件更新 |
| 🔍 **问题排查** | `.\install.ps1 -DryRun` | 预览模式，诊断问题 |

### 🔒 安全配置

```powershell
# 设置个人配置文件
.\setup-personal-configs.ps1

# 预览将要创建的配置
.\setup-personal-configs.ps1 -DryRun

# 强制覆盖现有配置
.\setup-personal-configs.ps1 -Force
```

### 🎯 快速验证

```powershell
# 快速健康检查
.\health-check.ps1

# 详细检查报告
.\health-check.ps1 -Detailed

# 检查特定组件
.\health-check.ps1 -Component PowerShell
.\health-check.ps1 -Component Neovim

# 自动修复问题
.\health-check.ps1 -Fix
```

## 📚 使用指南

### 🎮 日常命令

<details>
<summary><strong>Git 操作</strong></summary>

```powershell
# 快速提交推送
ngc "update config"    # 智能提交并推送
gst                    # Git 状态
glog                   # 美化的 Git 日志
gd                     # Git 差异对比
gb                     # Git 分支列表
```
</details>

<details>
<summary><strong>代理管理</strong></summary>

```powershell
px                     # 查看代理状态
px system              # 使用系统代理（默认推荐）
px clash               # 切换到 Clash 代理 (7890)
px v2ray               # 切换到 V2Ray 代理 (10808)
px singbox             # 切换到 SingBox 代理 (7890)
px off                 # 禁用所有代理
px-auto                # 智能代理检测（优先系统代理）
px-test                # 测试代理连接
```
</details>

<details>
<summary><strong>系统管理</strong></summary>

```powershell
sys-update            # 更新所有包管理器
swp                   # 清理系统缓存
sysinfo              # 显示系统信息
reload               # 重新加载 PowerShell 配置
profile-perf         # 查看配置性能报告
```
</details>

<details>
<summary><strong>仓库更新</strong></summary>

```powershell
# 更新仓库配置
git pull origin main           # 拉取最新配置
.\install.ps1                  # 重新安装配置
.\health-check.ps1 -Fix        # 验证并修复配置
```
</details>

<details>
<summary><strong>目录导航</strong></summary>

```powershell
mkcd project         # 创建并进入目录
..                   # 返回上级目录
~                    # 进入用户目录
z project            # 智能目录跳转（需要 zoxide）
```
</details>

### ⚙️ 配置管理

```powershell
# 环境检测
.\detect-environment.ps1 -Detailed           # 详细环境检测

# 智能配置安装（推荐）
.\install.ps1                                # 智能安装所有配置
.\install.ps1 -Type Git,Neovim              # 安装特定组件
.\install.ps1 -DryRun                        # 预览安装计划
.\install.ps1 -Interactive                   # 交互式安装

# 配置安装（完整版 - 高级功能）
.\install.ps1                               # 完整安装（自动检测环境）
.\install.ps1 -Interactive                  # 交互式安装
.\install.ps1 -Type PowerShell,Git -Force   # 强制安装特定组件

# 软件包管理
.\install_apps.ps1                           # 安装基础软件
.\install_apps.ps1 -Category Development     # 安装开发工具
.\install_apps.ps1 -Update                   # 更新已安装软件

# 健康检查
.\health-check.ps1                           # 快速检查
.\health-check.ps1 -Detailed                 # 详细检查
.\health-check.ps1 -Component PowerShell     # 检查特定组件
.\health-check.ps1 -Fix                      # 自动修复问题
```

### 🔧 高级功能

```powershell
# Neovim 配置管理
# Neovim 配置（通过主安装脚本管理）
.\install.ps1 -Type Neovim              # 安装 Neovim 配置
.\install.ps1 -Type Neovim -DryRun       # 预览安装操作
.\install.ps1 -Type Neovim -Force        # 强制重新安装

# Neovim 验证
nvim --headless -c "checkhealth" -c "qa" # 检查 Neovim 健康状态

# 环境管理
.\install_apps.ps1                      # 安装依赖工具
.\detect-environment.ps1 -Detailed      # 检测环境状态

# 仓库更新
git pull origin main                    # 拉取最新配置
.\install.ps1                           # 重新安装配置
.\health-check.ps1 -Fix                 # 验证并修复配置
```

## ⚡ 优化特性

### 高效部署
- 🚀 **30秒一键安装** - 零配置快速部署
- ⚡ **快速启动** - PowerShell < 1秒加载（快速模式）
- 🎯 **智能检测** - 自动识别和修复配置问题
- 🔄 **按需加载** - 模块化配置，减少启动时间
- 🔍 **自适应路径** - 自动检测 Windows 版本和应用安装方式

### 简洁设计
- 📁 **清晰结构** - 核心脚本 + 配置目录
- 🎯 **核心功能** - 专注日常开发必需功能
- 📝 **精简配置** - 去除冗余，保留实用
- 🔧 **一键操作** - 复杂操作简化为单个命令

### 实用工具
- 🛠️ **开发工具集** - Git、Windows Terminal、Starship 等
- 📦 **包管理** - Scoop 自动化管理
- 🔒 **安全存储** - 敏感配置加密保护
- 🩺 **健康检查** - 自动诊断和修复
- 🔄 **智能同步** - 自动处理本地和远程配置同步

## 🔄 仓库更新

当远程仓库有新的配置更新时，您可以通过以下步骤更新本地配置：

### 📥 更新步骤

```powershell
# 1. 进入 dotfiles 目录
cd C:\dotfiles

# 2. 拉取最新配置
git pull origin main

# 3. 重新安装配置（可选择特定组件）
.\install.ps1

# 4. 验证配置是否正确
.\health-check.ps1 -Detailed

# 5. 如有问题，自动修复
.\health-check.ps1 -Fix
```

### 🎯 选择性更新

```powershell
# 只更新特定组件
.\install.ps1 -Type PowerShell,Git

# 预览更新内容
.\install.ps1 -DryRun
```

### ⚠️ 注意事项

- **备份重要配置**: 更新前建议备份个人自定义配置
- **检查冲突**: 如有本地修改，请先处理 Git 冲突
- **验证功能**: 更新后运行健康检查确保配置正常
- **重启终端**: 某些配置可能需要重启 PowerShell 生效

## 🆘 常见问题

### 快速解决
- **执行策略错误**: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`
- **权限不足**: 以管理员身份运行
- **Git 用户未配置**: 复制 `git\.gitconfig.local.example` 为 `~\.gitconfig.local`
- **应用未检测到**: 运行 `.\detect-environment.ps1 -Detailed`
- **配置未生效**: 运行 `.\health-check.ps1 -Fix`

### 诊断工具
```powershell
.\health-check.ps1 -Detailed    # 全面健康检查
.\detect-environment.ps1        # 环境检测
.\install.ps1 -DryRun           # 预览安装
```

💡 **快速参考**: 查看 [QUICK_REFERENCE.md](QUICK_REFERENCE.md) | **详细故障排除**: 查看 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## 性能调优

### PowerShell 性能
```powershell
# 查看性能报告
profile-perf

# 查看模块状态
profile-status

# 启用调试模式
$env:POWERSHELL_PROFILE_DEBUG=1

# 启用快速模式
$env:POWERSHELL_PROFILE_FAST=1

# 重新加载配置
reload
```

### 环境变量
- `POWERSHELL_PROFILE_DEBUG=1`：启用详细调试信息
- `POWERSHELL_PROFILE_FAST=1`：启用快速模式（最小配置）
- `POWERSHELL_PROFILE_DIR=path`：自定义配置目录路径

## 贡献与自定义

- 欢迎 fork 并自定义自己的 dotfiles。
- 可根据需要扩展脚本支持更多平台或包管理器。
- 支持自定义主题和配置模板。
- 如有建议或问题，欢迎提 issue。

## 快速开始

如果您是第一次使用，建议查看 [QUICKSTART.md](QUICKSTART.md) 进行5分钟快速部署。

## 支持的应用程序

| 应用程序 | 配置支持 | 主题支持 | 扩展同步 | 备份/恢复 |
|----------|----------|----------|----------|-----------|
| PowerShell | ✅ | ✅ | ✅ | ✅ |
| Windows Terminal | ✅ | ✅ | N/A | ✅ |
| Git | ✅ | N/A | N/A | ✅ |
| Starship | ✅ | ✅ | N/A | ✅ |
| Neovim | ✅ | ✅ | ✅ | ✅ |

> ✅ 完全支持 | 🔄 计划中 | N/A 不适用

## 更新日志

---

> 本项目持续完善中，欢迎提出宝贵意见！
>
> **最新版本特性**：编辑器配置同步、配置加密存储、简化项目结构
>
> **快速体验**：查看 [QUICKSTART.md](QUICKSTART.md) | **遇到问题**：查看 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)