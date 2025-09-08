# Dotfiles 项目架构文档

## 项目概述

这是一个面向Windows环境的dotfiles配置管理项目，遵循简洁、高效、实用的设计原则，支持不同用户在不同使用环境下的个性化需求。

## 核心架构

### 四个核心脚本

根据项目需求，提供四个核心脚本来满足不同用户的使用场景：

#### 1. 环境检测脚本 (`detect-environment.ps1`)
**功能**: 检测用户系统环境和已安装应用程序
- 检测Windows版本和系统信息
- 检测已安装的开发工具（Git、PowerShell、终端等）
- 识别应用程序安装方式（系统安装、便携版、Scoop等）
- 提供配置路径检测
- 生成环境报告和推荐建议

**使用方式**:
```powershell
# 基本检测
.\detect-environment.ps1

# 详细模式
.\detect-environment.ps1 -Detailed

# JSON输出
.\detect-environment.ps1 -Json
```

#### 2. 应用安装脚本 (`install_apps.ps1`)
**功能**: 基于Scoop包管理器的应用程序批量安装
- 自动安装Scoop包管理器
- 分类管理18个精选软件包
- 支持Essential、Development、GitEnhanced、Programming四个分类
- 提供预览模式和更新功能
- 智能依赖管理

**包分类**:
- **Essential (13个包)**: git, ripgrep, zoxide, fzf, bat, fd, jq, neovim, starship, vscode, sudo, curl, 7zip
- **Development (2个包)**: shellcheck, gh
- **GitEnhanced (1个包)**: lazygit
- **Programming (2个包)**: python, nodejs

**使用方式**:
```powershell
# 安装核心工具
.\install_apps.ps1

# 安装所有工具
.\install_apps.ps1 -All

# 预览模式
.\install_apps.ps1 -DryRun -All

# 更新已安装包
.\install_apps.ps1 -Update
```

#### 3. 配置部署脚本 (`install.ps1`)
**功能**: 将项目配置文件部署到用户环境
- 支持生产模式（复制文件）和开发模式（符号链接）
- 自动备份现有配置文件
- 智能路径检测和适配
- 支持选择性安装特定配置
- 提供回滚和验证功能

**支持的配置类型**:
- Git配置（gitconfig、gitignore_global、gitmessage、gitconfig.d）
- PowerShell配置文件
- Windows Terminal设置

- Starship提示符配置
- Neovim编辑器配置
- CMD别名配置

**使用方式**:
```powershell
# 默认安装（生产模式）
.\install.ps1

# 开发模式（符号链接）
.\install.ps1 -Mode Symlink

# 选择性安装
.\install.ps1 -Type PowerShell,Git,Neovim

# 预览模式
.\install.ps1 -DryRun

# 启用开发模式
.\install.ps1 -SetDevMode
```

#### 4. 开发者符号链接脚本 (`dev-link.ps1`) ✨ **新增**
**功能**: 专门为开发者提供符号链接方式的配置管理
- 批量创建、验证和删除符号链接
- 提供详细的链接状态报告
- 支持预览模式和强制模式
- 自动备份现有配置文件
- 独立的开发者工具

**使用方式**:
```powershell
# 创建所有符号链接
.\dev-link.ps1

# 验证符号链接状态
.\dev-link.ps1 -Verify

# 列出链接状态
.\dev-link.ps1 -List

# 删除符号链接
.\dev-link.ps1 -Remove -Type Neovim

# 预览模式
.\dev-link.ps1 -DryRun
```

#### 5. 系统健康检查脚本 (`health-check.ps1`) ✨ **新增**
**功能**: 全面检查dotfiles配置系统的健康状态
- 配置文件完整性检查和语法验证
- 符号链接状态验证和孤立链接检测
- 应用程序安装状态和Scoop健康检查
- 系统兼容性检查（PowerShell版本、Windows版本、执行策略）
- 备份文件状态检查和清理建议
- 配置文件模板验证
- 支持自动修复模式和详细报告
- JSON格式输出和日志记录功能

**使用方式**:
```powershell
# 基本健康检查
.\health-check.ps1

# 详细检查报告
.\health-check.ps1 -Detailed

# 自动修复问题
.\health-check.ps1 -Fix

# 仅检查配置文件
.\health-check.ps1 -ConfigOnly

# JSON格式输出
.\health-check.ps1 -Json -LogFile "health.log"
```

### 辅助脚本

#### 自动同步脚本 (`auto-sync.ps1`)
提供配置文件的自动同步功能：
- 定期同步配置文件更新
- 支持增量同步和完整同步
- 提供冲突检测和解决机制

## 项目结构

```
dotfiles/
├── 📄 核心脚本
│   ├── detect-environment.ps1    # 环境检测
│   ├── install_apps.ps1          # 应用安装
│   ├── install.ps1               # 配置部署
│   ├── dev-link.ps1              # 开发者符号链接 ✨
│   └── health-check.ps1          # 系统健康检查 ✨
├── 🛠️ 辅助脚本
│   └── auto-sync.ps1             # 自动同步脚本
├── ⚙️ 配置文件
│   ├── git/                      # Git配置
│   ├── powershell/               # PowerShell配置
│   ├── neovim/                   # Neovim配置
│   ├── starship/                 # Starship配置
│   └── WindowsTerminal/          # Windows Terminal配置
├── 📦 项目管理
│   ├── config/                   # 项目配置文件
│   ├── modules/                  # PowerShell模块
│   ├── scripts/                  # 工具脚本
│   └── scoop/                    # Scoop配置
├── 📋 模板系统
│   └── templates/                # 配置文件模板 ✨
├── 📚 精简文档体系 ✨
│   ├── README.md                 # 项目总览和导航
│   ├── USER_GUIDE.md             # 用户使用指南
│   ├── API_REFERENCE.md          # API 参考文档
│   ├── FAQ.md                    # 常见问题解答
│   └── TROUBLESHOOTING.md        # 故障排除指南
└── 📖 项目文档
    ├── README.md                 # 项目主页
    ├── QUICKSTART.md             # 快速开始
    ├── SECURITY.md               # 安全指南
    └── PROJECT_ARCHITECTURE.md   # 本架构文档
```

## 设计原则

### 1. 简洁性
- 核心功能集中在四个主要脚本中
- 清晰的参数设计和使用方式
- 最小化用户学习成本

### 2. 高效性
- 智能环境检测和路径适配
- 批量操作和并行处理
- 缓存和增量更新机制

### 3. 实用性
- 支持不同用户使用场景
- 提供生产模式和开发模式
- 完善的错误处理和回滚机制

### 4. 兼容性
- 支持不同Windows版本
- 兼容多种PowerShell版本
- 适配不同应用程序安装方式

## 使用流程

### 新用户快速开始
```powershell
# 1. 检测环境
.\detect-environment.ps1

# 2. 安装应用（可选）
.\install_apps.ps1

# 3. 部署配置文件
.\install.ps1

# 4. 验证安装
.\health-check.ps1

# 5. 验证系统健康状态
.\health-check.ps1
```

### 开发者工作流
```powershell
# 1. 启用开发模式
.\install.ps1 -SetDevMode

# 2. 使用符号链接部署
.\dev-link.ps1

# 3. 验证链接状态
.\dev-link.ps1 -Verify

# 4. 详细健康检查
.\health-check.ps1 -Detailed
```

### 系统维护工作流 ✨ **新增**
```powershell
# 定期健康检查
.\health-check.ps1

# 发现问题时自动修复
.\health-check.ps1 -Fix

# 生成详细报告
.\health-check.ps1 -Detailed -Json -LogFile "health-$(Get-Date -Format 'yyyyMMdd').log"

# 仅检查配置文件（快速检查）
.\health-check.ps1 -ConfigOnly
```

## 技术架构

### 核心技术栈
- **脚本语言**: PowerShell 5.1+
- **包管理器**: Scoop
- **版本控制**: Git
- **配置格式**: JSON/YAML/TOML

### 关键特性
- **模块化设计**: 功能独立，职责清晰
- **路径自适应**: 自动检测和适配不同环境
- **双模式支持**: 生产模式（复制）+ 开发模式（符号链接）
- **完整备份**: 自动备份现有配置
- **错误恢复**: 支持回滚和验证

### 安全考虑
- 敏感信息分离（gitconfig.local）
- 备份机制保护用户数据
- 权限检查和提示
- 预览模式防止误操作

## 最新改进 ✨

### 已完成的优化
1. **创建独立的开发者符号链接脚本** (`dev-link.ps1`)
   - 专门的符号链接管理工具
   - 支持创建、验证、删除、列表操作
   - 完整的状态报告和错误处理

2. **修复配置文件映射问题**
   - 移除不应该被符号链接的gitconfig.local映射
   - 清理不存在的配置文件引用
   - 优化路径映射逻辑

3. **增强脚本错误处理和日志记录**
   - 统一的配置路径检测逻辑
   - 一致的错误处理和日志记录
   - 标准化的参数设计
   - 增强的异常处理和重试机制

4. **创建系统健康检查脚本** (`health-check.ps1`) ✨
   - 全面的系统健康状态检查
   - 配置文件完整性和语法验证
   - 符号链接状态验证和修复
   - 应用程序安装状态检查
   - 系统兼容性检查
   - 自动修复模式和详细报告

5. **精简项目结构**
   - 移除冗余的 setup.ps1、setup-personal-configs.ps1、test-fixes.ps1 和 manage-templates.ps1
   - 简化项目结构，提高维护性
   - 保持核心功能完整，使用现有脚本组合实现所有功能

6. **完善项目文档结构和用户指南**
   - 创建详细的项目架构文档
   - 更新使用流程和工作流程
   - 添加系统维护指南
   - 完善安全考虑和最佳实践

### 项目状态: 🎉 **全面完成**
所有核心功能和优化任务已完成，项目现在是一个成熟、完整的Windows环境dotfiles管理解决方案。

## 总结

本项目已经实现了完整的dotfiles配置管理功能，四个核心脚本各司其职：
- **detect-environment.ps1**: 环境检测和分析
- **install_apps.ps1**: 应用程序批量安装
- **install.ps1**: 配置文件智能部署
- **dev-link.ps1**: 开发者符号链接管理

项目架构清晰，功能完整，支持不同用户的使用需求，是一个成熟的Windows环境dotfiles管理解决方案。