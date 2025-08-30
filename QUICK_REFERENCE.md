# 🚀 快速参考卡

## 智能安装系统

### 🤖 一键安装
```powershell
# 智能安装（推荐）
.\install.ps1

# 预览安装计划
.\install.ps1 -DryRun

# 安装特定组件
.\install.ps1 -Type PowerShell,Git,Neovim

# 交互式安装
.\install.ps1 -Interactive
```

### ⚙️ 开发模式管理
```powershell
# 启用开发模式（符号链接）
.\install.ps1 -SetDevMode

# 禁用开发模式（复制模式）
.\install.ps1 -UnsetDevMode

# 强制使用符号链接模式
.\install.ps1 -Mode Symlink

# 强制使用复制模式
.\install.ps1 -Mode Copy
```

### 🎯 组件分类

#### 🔧 默认组件（自动安装）
- **Scoop**: 包管理器
- **CMD**: 命令提示符增强
- **PowerShell**: PowerShell 7 配置
- **Starship**: 命令提示符主题
- **Git**: 版本控制配置
- **WindowsTerminal**: Windows Terminal

#### 🎨 可选组件（用户选择）
- **Alacritty**: Alacritty
- **WezTerm**: WezTerm 终端
- **Neovim**: Neovim 编辑器

### 🔍 安装模式

**复制模式**（默认）:
- 复制文件到系统配置目录
- 稳定可靠，不依赖源文件
- 适合普通用户

**符号链接模式**（开发模式）:
- 创建符号链接到源文件
- 便于实时编辑和开发
- 适合开发者和配置维护

### 🛠️ 常用命令

```powershell
# 健康检查
.\health-check.ps1
.\health-check.ps1 -Fix

# 环境检测
.\detect-environment.ps1

# 软件安装
.\install_apps.ps1

# 配置更新
git pull origin main
.\install.ps1

# 代理管理
px status         # 查看代理状态
px system         # 使用系统代理
px clash          # 切换到 Clash (7890)
px v2ray          # 切换到 V2Ray (10808)
px singbox        # 切换到 SingBox (7890)
px off            # 禁用代理
px-auto           # 智能代理检测
```

### 🆘 快速故障排除

```powershell
# 权限问题
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 符号链接失败
.\install.ps1 -Mode Copy

# Git 配置问题
Copy-Item "git\.gitconfig.local.example" "$env:USERPROFILE\.gitconfig.local"

# 配置验证
.\health-check.ps1 -Detailed
```

### 📖 详细文档

- [快速开始指南](QUICKSTART.md)
- [故障排除文档](TROUBLESHOOTING.md)
- [完整使用说明](README.md)

---

💡 **提示**: 使用 `.\install.ps1 -DryRun` 预览安装计划