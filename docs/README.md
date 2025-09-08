# 📚 Dotfiles 项目文档

欢迎使用 Dotfiles 配置管理项目文档中心！

## 🚀 快速导航

### 👤 用户文档
- **[用户使用指南](USER_GUIDE.md)** - 完整的使用说明和最佳实践
- **[常见问题](FAQ.md)** - 常见问题解答和解决方案
- **[故障排除](TROUBLESHOOTING.md)** - 系统性的问题诊断和修复指南

### 👨‍💻 开发者文档
- **[API 参考](API_REFERENCE.md)** - 完整的脚本参数和函数文档

## 🎯 项目概述

Dotfiles 是一个功能完整的 Windows 开发环境配置管理工具，提供：

- **🔍 智能环境检测** - 自动识别系统环境和已安装应用
- **📦 应用程序管理** - 基于 Scoop 的批量应用安装
- **⚙️ 配置文件管理** - 智能配置文件部署和同步
- **🔗 符号链接管理** - 开发者友好的符号链接工具
- **🏥 系统健康检查** - 全面的系统状态监控和修复

## 🚀 快速开始

### 新用户（5分钟上手）
```powershell
# 1. 克隆项目
git clone <repository-url> dotfiles
cd dotfiles

# 2. 分步安装
.\detect-environment.ps1
.\install_apps.ps1
.\install.ps1

# 3. 验证安装
.\health-check.ps1
```

### 开发者模式
```powershell
# 1. 启用开发模式
.\install.ps1 -SetDevMode

# 2. 创建符号链接
.\dev-link.ps1

# 3. 验证配置
.\health-check.ps1 -Detailed
```

## 🆘 获取帮助

- **查看脚本帮助**: `Get-Help .\<script-name>.ps1 -Full`
- **运行健康检查**: `.\health-check.ps1 -Detailed`
- **查看常见问题**: [FAQ.md](FAQ.md)
- **报告问题**: 请在项目仓库创建 Issue

---

**💡 提示**: 建议从 [用户使用指南](USER_GUIDE.md) 开始阅读，获取完整的使用体验。