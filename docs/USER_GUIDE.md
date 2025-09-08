# 用户使用指南

本指南将帮助您快速上手并充分利用 Dotfiles 配置管理项目的所有功能。

## 📋 目录

- [系统要求](#系统要求)
- [安装步骤](#安装步骤)
- [核心功能](#核心功能)
- [使用场景](#使用场景)
- [配置管理](#配置管理)
- [故障排除](#故障排除)
- [最佳实践](#最佳实践)

## 🔧 系统要求

### 最低要求
- **操作系统**: Windows 10 或更高版本
- **PowerShell**: 5.1 或更高版本（推荐 PowerShell 7+）
- **执行策略**: RemoteSigned 或 Unrestricted
- **磁盘空间**: 至少 500MB 可用空间

### 推荐配置
- **操作系统**: Windows 11
- **PowerShell**: PowerShell 7.x
- **终端**: Windows Terminal
- **网络**: 稳定的互联网连接（用于下载应用程序）

### 检查系统要求

```powershell
# 检查 PowerShell 版本
$PSVersionTable.PSVersion

# 检查执行策略
Get-ExecutionPolicy

# 如需修改执行策略
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 🚀 安装步骤

### 方法一：交互式安装（推荐新用户）

```powershell
# 1. 克隆项目到本地
git clone <repository-url> dotfiles
cd dotfiles

# 2. 分步安装
.\detect-environment.ps1    # 检测环境
.\install_apps.ps1          # 安装应用
.\install.ps1               # 部署配置

# 3. 根据提示选择要安装的组件
# 向导会自动执行以下步骤：
# - 环境检测
# - 应用程序安装
# - 配置文件部署
# - 个人信息设置

# 4. 验证安装结果
.\health-check.ps1
```

### 方法二：手动分步安装

```powershell
# 1. 环境检测
.\detect-environment.ps1 -Detailed

# 2. 安装应用程序（可选）
.\install_apps.ps1

# 3. 部署配置文件
.\install.ps1

# 4. 个人配置已在统一向导中完成

# 5. 健康检查
.\health-check.ps1
```

### 方法三：开发者模式安装

```powershell
# 1. 启用开发模式
.\install.ps1 -SetDevMode

# 2. 使用符号链接部署
.\dev-link.ps1

# 3. 验证符号链接
.\dev-link.ps1 -Verify

# 4. 详细健康检查
.\health-check.ps1 -Detailed
```

## 🎯 核心功能

### 1. 环境检测 (`detect-environment.ps1`)

**功能**: 检测系统环境和已安装应用程序

```powershell
# 基本检测
.\detect-environment.ps1

# 详细模式
.\detect-environment.ps1 -Detailed

# JSON 输出
.\detect-environment.ps1 -Json

# 保存到文件
.\detect-environment.ps1 -Json > environment-report.json
```

**输出信息**:
- Windows 版本和系统信息
- PowerShell 版本和配置
- 已安装的开发工具
- 配置文件路径
- 推荐的改进建议

### 2. 应用程序管理 (`install_apps.ps1`)

**功能**: 基于 Scoop 的应用程序批量安装

```powershell
# 安装核心工具（Essential 分类）
.\install_apps.ps1

# 安装所有工具
.\install_apps.ps1 -All

# 预览模式（不实际安装）
.\install_apps.ps1 -DryRun -All

# 更新已安装的包
.\install_apps.ps1 -Update

# 安装特定分类
.\install_apps.ps1 -Category Development,Programming
```

**应用程序分类**:

| 分类 | 包含应用 | 说明 |
|------|----------|------|
| **Essential** | git, ripgrep, zoxide, fzf, bat, fd, jq, neovim, starship, vscode, sudo, curl, 7zip | 核心开发工具 |
| **Development** | shellcheck, gh | 开发辅助工具 |
| **GitEnhanced** | lazygit | Git 增强工具 |
| **Programming** | python, nodejs | 编程语言运行时 |

### 3. 配置文件管理 (`install.ps1`)

**功能**: 智能配置文件部署和管理

```powershell
# 默认安装（复制模式）
.\install.ps1

# 符号链接模式
.\install.ps1 -Mode Symlink

# 安装特定配置
.\install.ps1 -Type Git,PowerShell,Neovim

# 预览模式
.\install.ps1 -DryRun

# 启用开发模式
.\install.ps1 -SetDevMode

# 回滚到备份
.\install.ps1 -Restore
```

**支持的配置类型**:
- **Git**: 全局配置、忽略规则、提交模板
- **PowerShell**: 配置文件和模块
- **Neovim**: 编辑器配置
- **Starship**: 命令行提示符
- **Windows Terminal**: 终端设置


### 4. 符号链接管理 (`dev-link.ps1`)

**功能**: 开发者专用的符号链接管理工具

```powershell
# 创建所有符号链接
.\dev-link.ps1

# 验证符号链接状态
.\dev-link.ps1 -Verify

# 列出链接状态
.\dev-link.ps1 -List

# 删除特定符号链接
.\dev-link.ps1 -Remove -Type Neovim

# 预览模式
.\dev-link.ps1 -DryRun

# 强制重新创建
.\dev-link.ps1 -Force
```

### 5. 系统健康检查 (`health-check.ps1`)

**功能**: 全面的系统健康状态检查和修复

```powershell
# 基本健康检查
.\health-check.ps1

# 详细检查报告
.\health-check.ps1 -Detailed

# 自动修复问题
.\health-check.ps1 -Fix

# 仅检查配置文件
.\health-check.ps1 -ConfigOnly

# 生成 JSON 报告
.\health-check.ps1 -Json -LogFile "health-$(Get-Date -Format 'yyyyMMdd').log"
```

**检查项目**:
- ✅ 配置文件完整性和语法
- ✅ 符号链接状态和有效性
- ✅ 应用程序安装状态
- ✅ 系统兼容性
- ✅ 备份文件管理
- ✅ 模板文件验证

## 📝 使用场景

### 场景1：新电脑环境搭建

```powershell
# 完整的新环境搭建流程
git clone <repository-url> dotfiles
cd dotfiles

# 标准安装流程
.\detect-environment.ps1    # 环境检测
.\install_apps.ps1 -All     # 安装应用
.\install.ps1               # 部署配置
.\health-check.ps1          # 验证安装
```

### 场景2：现有环境配置同步

```powershell
# 仅同步配置文件
.\install.ps1 -Type Git,PowerShell,Starship

# 验证同步结果
.\health-check.ps1 -ConfigOnly
```

### 场景3：开发环境维护

```powershell
# 定期健康检查
.\health-check.ps1

# 发现问题时自动修复
.\health-check.ps1 -Fix

# 更新应用程序
.\install_apps.ps1 -Update
```

### 场景4：多设备配置同步

```powershell
# 在新设备上
git pull origin main
.\install.ps1 -Mode Symlink
.\health-check.ps1 -Detailed
```

## ⚙️ 配置管理

### 个人信息配置

```powershell
# 设置 Git 用户信息（手动复制模板）
Copy-Item git\.gitconfig.local.example ~\.gitconfig.local

# 手动编辑个人配置
notepad git\gitconfig.local
```

### 自定义配置

1. **修改应用程序列表**:
   ```powershell
   notepad scoop\packages.txt
   ```

2. **自定义配置文件**:
   - 直接编辑 `config/` 目录下的配置文件
   - 使用统一向导的配置功能

3. **添加新的配置类型**:
   - 编辑 `install.ps1` 中的 `$links` 哈希表
   - 添加相应的配置文件到项目目录

### 备份和恢复

```powershell
# 查看备份文件
Get-ChildItem ~\ -Filter "*.backup" -Recurse

# 恢复特定配置
.\install.ps1 -Restore -Type PowerShell

# 手动恢复
Copy-Item "~\.gitconfig.backup" "~\.gitconfig"
```

## 🔧 故障排除

### 常见问题

#### 1. PowerShell 执行策略限制

**问题**: `无法加载文件，因为在此系统上禁止运行脚本`

**解决方案**:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### 2. Scoop 安装失败

**问题**: Scoop 安装过程中网络错误

**解决方案**:
```powershell
# 使用代理
$env:SCOOP_PROXY = "http://proxy.example.com:8080"
.\install_apps.ps1

# 或手动安装 Scoop
iwr -useb get.scoop.sh | iex
```

#### 3. 符号链接创建失败

**问题**: `权限不足，无法创建符号链接`

**解决方案**:
```powershell
# 以管理员身份运行 PowerShell
Start-Process pwsh -Verb RunAs

# 或启用开发者模式（Windows 10/11）
# 设置 > 更新和安全 > 开发者选项 > 开发者模式
```

#### 4. 配置文件冲突

**问题**: 现有配置文件与项目配置冲突

**解决方案**:
```powershell
# 查看冲突
.\health-check.ps1 -Detailed

# 备份现有配置
.\install.ps1 -DryRun

# 强制覆盖
.\install.ps1 -Force
```

### 诊断工具

```powershell
# 全面系统诊断
.\health-check.ps1 -Detailed -Json > diagnosis.json

# 检查特定组件
.\detect-environment.ps1 -Detailed
.\dev-link.ps1 -Verify
```

## 💡 最佳实践

### 1. 定期维护

```powershell
# 每周执行一次健康检查
.\health-check.ps1

# 每月更新应用程序
.\install_apps.ps1 -Update

# 定期同步配置
git pull origin main
.\install.ps1
```

### 2. 安全考虑

- **敏感信息分离**: 个人信息存储在 `gitconfig.local` 中，不提交到版本控制
- **备份重要配置**: 安装前自动创建备份文件
- **权限最小化**: 仅在必要时使用管理员权限

### 3. 版本控制

```powershell
# 提交个人配置更改
git add .
git commit -m "Update personal configurations"
git push origin main
```

### 4. 多环境管理

- **工作环境**: 使用复制模式 (`.\install.ps1`)
- **开发环境**: 使用符号链接模式 (`.\dev-link.ps1`)
- **测试环境**: 使用预览模式 (`.\install.ps1 -DryRun`)

## 📞 获取帮助

### 内置帮助

```powershell
# 查看脚本详细帮助
Get-Help .\install.ps1 -Full
Get-Help .\health-check.ps1 -Examples
```

### 社区支持

- **GitHub Issues**: 报告 Bug 和功能请求
- **文档**: 查看 [FAQ](FAQ.md) 和 [故障排除](TROUBLESHOOTING.md)
- **健康检查**: 使用 `.\health-check.ps1 -Detailed` 获取诊断信息

---

**🎉 恭喜！** 您现在已经掌握了 Dotfiles 项目的完整使用方法。建议从简单的配置开始，逐步探索更高级的功能。