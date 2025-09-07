# 🚀 快速开始指南

这是一个简化的快速开始指南，帮助您在 **5 分钟内** 完成 dotfiles 的基本配置。

## 📋 前置要求

- Windows 10/11 系统（自动适配版本差异）
- 管理员权限
- 网络连接

## 🔄 兼容性说明

本项目已优化支持 Windows 10 和 Windows 11：
- **自动检测**：智能识别系统版本和应用安装方式
- **路径适配**：自动适配不同版本的配置目录
- **多安装支持**：支持应用的各种安装方式（用户/系统/便携版）

## 🎯 推荐配置选择

| 配置 | 描述 | 适用场景 |
|------|------|----------|
| **optimized** | ⭐ 优化配置（精简包） | **推荐**，性能与功能平衡 |
| **standard** | 标准配置 | 日常使用，办公环境 |
| **developer** | 开发者配置 | 开发工作，完整功能 |
| **minimal** | 最小配置 | 服务器环境，最小化需求 |

## ⚡ 三步快速部署

### 1️⃣ 克隆仓库
```powershell
git clone https://github.com/somls/dotfiles.git C:\dotfiles
cd C:\dotfiles
```

### 2️⃣ 快速安装（推荐）
```powershell
# 快速设置向导（推荐）
.\setup.ps1

# 或直接安装优化配置（推荐）
.\install.ps1 -Profile optimized

# 或者直接安装
.\install.ps1                     # 智能安装配置
```

### 3️⃣ 配置个人信息
```powershell
# 复制Git配置模板
copy git\.gitconfig.local.example %USERPROFILE%\.gitconfig.local

# 编辑个人信息（用记事本或其他编辑器）
notepad %USERPROFILE%\.gitconfig.local
```

## ✅ 验证安装

运行健康检查确保一切正常：
```powershell
.\health-check.ps1
```

## 🎯 后续操作

### 安装推荐软件
```powershell
# 安装基础工具
.\install_apps.ps1

# 安装开发工具
.\install_apps.ps1 -Category Development

# 安装可选工具
.\install_apps.ps1 -Category Optional
```

### 配置可选组件（可选）
```powershell
# 根据需要配置可选组件
.\install.ps1 -Type Neovim
```

## 🔧 常用命令

| 命令 | 功能 | 示例 |
|------|------|------|
| `reload` | 重新加载 PowerShell 配置 | `reload` |
| `profile-perf` | 查看配置加载性能 | `profile-perf` |
| `sys-update` | 更新所有软件包 | `sys-update` |
| `swp` | 清理 Scoop 缓存 | `swp` |
| `ngc` | 快速 Git 提交 | `ngc "update config"` |

## 🆘 遇到问题？

1. **权限问题**：确保以管理员身份运行 PowerShell
2. **网络问题**：检查代理设置或网络连接
3. **符号链接失败**：运行 `.\install.ps1 -Force`
4. **配置不生效**：运行 `.\health-check.ps1 -Fix`

## 📚 更多信息

- 📖 [完整文档](README.md)
- 🔍 [故障排除](TROUBLESHOOTING.md)
- 🛠️ [高级配置](README.md#配置档案)

---

💡 **提示**：如果您是首次使用，建议先阅读 [README.md](README.md) 了解完整功能。