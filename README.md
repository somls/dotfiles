# Windows Dotfiles 管理系统

以 `configs` 目录为核心的现代化 Windows 开发环境配置管理系统。

## 🚀 快速开始

### 新用户安装
```powershell
# 1. 配置用户信息
.\user-setup.ps1

# 2. 安装应用程序
.\install-apps.ps1

# 3. 部署配置文件
.\deploy-config.ps1

# 4. 检查环境状态
.\check-environment.ps1
```

## 📁 项目结构

```
dotfiles/
├── configs/                    # 🎯 核心配置目录
│   ├── powershell/            # PowerShell 配置
│   ├── git/                   # Git 配置
│   ├── starship/              # Starship 提示符
│   ├── WindowsTerminal/       # Windows Terminal
│   ├── neovim/                # Neovim 编辑器
│   └── scoop/                 # Scoop 包管理器
├── deploy-config.ps1          # 📋 配置文件部署
├── install-apps.ps1           # 📦 应用安装管理
├── check-environment.ps1      # 🔍 环境检查验证
├── dev-symlink.ps1            # 🔗 开发符号链接
└── user-setup.ps1             # 👤 用户信息配置
```

## 🛠️ 脚本功能详解

### 1. 用户配置 (`user-setup.ps1`)
配置用户特定信息（Git用户名/邮箱、环境变量等）。

```powershell
# 交互式配置
.\user-setup.ps1

# 直接指定参数
.\user-setup.ps1 -Name "Your Name" -Email "your@email.com"
```

### 2. 应用安装 (`install-apps.ps1`)
基于 `configs/scoop/packages.txt` 的自动化应用安装。

```powershell
# 查看可用应用类别
.\install-apps.ps1 -List

# 安装特定类别
.\install-apps.ps1 -Category Essential

# 安装指定应用
.\install-apps.ps1 -Apps git,neovim,starship

# 预览模式
.\install-apps.ps1 -DryRun
```

### 3. 配置部署 (`deploy-config.ps1`)
将 `configs` 目录中的配置文件部署到系统位置。

```powershell
# 查看可用配置类型
.\deploy-config.ps1 -List

# 部署所有配置
.\deploy-config.ps1

# 部署特定配置
.\deploy-config.ps1 -ConfigType powershell,git

# 预览模式
.\deploy-config.ps1 -DryRun

# 强制覆盖
.\deploy-config.ps1 -Force
```

### 4. 环境检查 (`check-environment.ps1`)
全面检查配置状态、应用安装和环境兼容性。

```powershell
# 完整检查
.\check-environment.ps1

# 仅检查应用程序
.\check-environment.ps1 -Apps

# 仅检查配置文件
.\check-environment.ps1 -Config

# 检查特定配置
.\check-environment.ps1 -ConfigType powershell

# 详细信息
.\check-environment.ps1 -Detailed

# 自动修复
.\check-environment.ps1 -Fix
```

### 5. 符号链接 (`dev-symlink.ps1`)
**符号链接模式** - 创建符号链接实现配置文件的实时同步。

```powershell
# 检查符号链接状态
.\dev-symlink.ps1 -Action status

# 创建符号链接（需要管理员权限或开发者模式）
.\dev-symlink.ps1 -Action create

# 移除符号链接
.\dev-symlink.ps1 -Action remove

# 刷新符号链接
.\dev-symlink.ps1 -Action refresh

# 预览模式
.\dev-symlink.ps1 -Action create -DryRun
```

## 🎯 核心特性

### ✅ 环境无关设计
- **动态路径解析**: 自动适配不同安装位置
- **用户隔离**: 个人配置与共享配置分离
- **跨版本兼容**: 支持 PowerShell 5.1 和 7+

### ✅ 安全保障
- **敏感文件排除**: 自动排除用户特定配置
- **备份机制**: 部署前自动备份现有配置
- **权限检查**: 符号链接操作需要适当权限

### ✅ 开发友好
- **实时同步**: 符号链接模式下配置修改立即生效
- **预览模式**: 所有脚本支持 `-DryRun` 预览
- **详细日志**: 完整的操作日志和错误提示

## 📋 配置类型支持

| 配置类型 | 源目录 | 目标位置 | 功能描述 |
|---------|--------|----------|----------|
| **powershell** | `configs/powershell/` | `$PROFILE` + 模块目录 | PowerShell 配置和扩展 |
| **git** | `configs/git/` | `~/.gitconfig` 等 | Git 全局配置 |
| **starship** | `configs/starship/` | `~/.config/starship.toml` | 命令行提示符 |
| **terminal** | `configs/WindowsTerminal/` | Windows Terminal 配置 | 终端设置 |
| **neovim** | `configs/neovim/` | `$LOCALAPPDATA/nvim/` | 编辑器配置 |

## 🔧 应用类别

基于 `configs/scoop/packages.txt` 的应用分类：

- **Essential**: 基础开发工具
- **Development**: 开发环境工具
- **Programming**: 编程语言和运行时
- **Enhanced**: 增强工具集

## 💡 使用建议

### 普通用户
1. 使用复制模式部署配置（默认）
2. 定期运行 `check-environment.ps1` 检查状态
3. 需要时运行 `user-setup.ps1` 更新个人信息

### 开发者
1. 使用 `dev-symlink.ps1` 创建符号链接进行开发
2. 修改 `configs` 目录中的文件查看实时效果
3. 开发完成后使用 `deploy-config.ps1` 进行正式部署

## 🔒 安全特性

- **敏感文件自动排除**: `.gitignore` 完整覆盖
- **本地配置隔离**: `*.local` 文件不会被同步
- **权限安全检查**: 符号链接需要适当权限
- **备份保护机制**: 自动备份被替换的配置

## 📞 故障排除

### 权限问题
```powershell
# 设置执行策略
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 启用开发者模式（符号链接）
# 设置 > 更新和安全 > 开发者选项 > 开发人员模式
```

### PowerShell Profile 错误
```powershell
# 检查语法错误
.\check-environment.ps1 -Config -Detailed

# 重新部署配置
.\deploy-config.ps1 -ConfigType powershell -Force
```

### Scoop 安装问题
```powershell
# 手动安装 Scoop
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex
```

---

💡 **提示**: 所有脚本都支持 `-help` 参数查看详细使用说明。
# 测试多远程仓库推送
