# 🚀 Dotfiles 配置管理项目

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-green.svg)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-2.0.0-red.svg)](#)

一个专为 Windows 环境设计的现代化 dotfiles 配置管理解决方案，坚守**简洁**、**高效**、**实用**的设计原则，照顾不同用户在不同使用环境下的个性化需求。

## ✨ 核心特性

- 🔍 **智能环境检测** - 自动识别系统版本、已安装软件和配置路径（22+ 应用程序）
- 📦 **一键应用安装** - 基于 Scoop 的分类安装系统，支持 18+ 精选应用
- ⚙️ **配置智能部署** - 支持生产模式（复制）和开发模式（符号链接）
- 🔗 **开发者符号链接** - 专用的符号链接管理工具，保持配置同步
- 🏥 **系统健康检查** - 全面的配置完整性检查和自动修复
- 📋 **模板管理系统** - 支持配置文件模板和个性化定制
- 📚 **完整文档体系** - 详细的用户指南和开发者文档
- 🛡️ **环境兼容性检查** - 自动检测和适配不同用户环境，提高安装成功率

## 🎯 五脚本体系

### 用户核心脚本

| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| **`detect-environment.ps1`** | 环境检测 | 了解系统状态，检查兼容性 |
| **`install_apps.ps1`** | 应用安装 | 批量安装开发工具和常用软件 |
| **`install.ps1`** | 配置部署 | 将项目配置安装到用户环境 |

### 开发者专用脚本

| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| **`dev-link.ps1`** | 符号链接管理 | 开发模式下的配置文件链接 |
| **`health-check.ps1`** | 系统健康检查 | 验证配置完整性，诊断问题 |

### 辅助工具

| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| **`auto-sync.ps1`** | 自动同步 | 定期同步配置文件 |

## 🚀 快速开始

### 新用户推荐流程

```powershell
# 1. 克隆项目
git clone https://github.com/username/dotfiles.git
cd dotfiles

# 2. 分步安装（推荐）- 现在包含自动环境检查
.\detect-environment.ps1           # 检测环境（22+ 应用程序）
.\install_apps.ps1 -Category Essential  # 安装应用程序（自动环境兼容性检查）
.\install.ps1                      # 部署配置文件（智能路径检测）
.\health-check.ps1                 # 验证安装（全面健康检查）
```

### 🆕 环境适配增强
- ✅ **预防性检查**: 安装前自动检查 PowerShell 版本、执行策略、网络连接、磁盘空间
- ✅ **智能路径适配**: 自动检测和适配不同的软件安装方式（Scoop、系统安装、Microsoft Store）
- ✅ **用户友好提示**: 发现问题时提供详细说明和解决建议
- ✅ **向后兼容**: 保持原有使用方式不变，增强功能透明集成

### 开发者工作流程

```powershell
# 1. 使用符号链接模式（开发推荐）
.\dev-link.ps1 -Create

# 2. 验证符号链接状态
.\dev-link.ps1 -Verify

# 3. 定期健康检查
.\health-check.ps1 -Detailed -Fix

# 4. 自动同步配置
.\auto-sync.ps1
```

## 📁 项目结构

```
dotfiles/
├── 📄 核心脚本 (5个)
│   ├── detect-environment.ps1    # 环境检测
│   ├── install_apps.ps1          # 应用安装  
│   ├── install.ps1               # 配置部署
│   ├── dev-link.ps1              # 符号链接管理
│   └── health-check.ps1          # 健康检查
├── ⚙️ 配置模块 (10+个)
│   ├── git/                      # Git 配置
│   ├── powershell/               # PowerShell 配置
│   ├── neovim/                   # Neovim 配置
│   ├── starship/                 # Starship 提示符
│   └── WindowsTerminal/          # Windows Terminal
└── 📚 完整文档
    └── docs/                     # 用户和开发者文档
```

## 🎨 支持的应用配置

**开发工具**: Git, PowerShell, Neovim, Windows Terminal, Starship  
**系统工具**: Scoop, 环境变量, 注册表优化

## 📚 文档导航

- **[📖 文档中心](docs/README.md)** - 完整文档导航
- **[👤 用户指南](docs/USER_GUIDE.md)** - 详细使用说明
- **[🔧 使用指南](USAGE_GUIDE.md)** - 快速开始和常用命令
- **[🎉 新功能说明](WHATS_NEW.md)** - 最新功能更新和改进
- **[🛠️ 环境增强说明](ENVIRONMENT_ENHANCEMENTS.md)** - 技术实现详情
- **[📊 测试报告](TEST_RESULTS.md)** - 功能测试验证结果

## 🔧 系统要求

### 最低要求
- **操作系统**: Windows 10 1903+ 或 Windows 11
- **PowerShell**: 5.1+ （推荐 PowerShell 7+）
- **网络连接**: 用于下载应用程序和更新
- **磁盘空间**: 至少 2GB 可用空间

### 推荐配置
- **PowerShell 7+**: 更好的性能和功能支持
- **开发者模式**: 启用符号链接权限
- **管理员权限**: 某些配置可能需要提升权限

## 🛡️ 安全特性

- ✅ **脚本签名验证** - 确保脚本完整性
- ✅ **权限最小化** - 仅请求必要的系统权限
- ✅ **配置备份** - 自动备份原有配置
- ✅ **回滚机制** - 支持配置恢复和撤销
- ✅ **安全扫描** - 定期检查配置文件安全性

## 🤝 贡献指南

我们欢迎社区贡献！

### 快速贡献
1. Fork 项目仓库
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

### 报告问题
- 查看 [常见问题](docs/FAQ.md) 和 [故障排除指南](docs/TROUBLESHOOTING.md)
- 搜索现有的 [GitHub Issues](https://github.com/username/dotfiles/issues)
- 创建新的 Issue，提供详细的问题描述

## 🏆 项目特色

- **🎯 5个核心脚本** - 覆盖完整配置管理流程
- **📦 18+精选应用** - 开发、媒体、生产力工具
- **⚙️ 10+配置模块** - 主流开发工具配置
- **🛠️ 智能路径检测** - 自适应不同环境和安装方式
- **🔄 完善错误恢复** - 异常处理和自动修复
- **🌍 环境兼容性** - 支持不同用户环境，提高安装成功率
- **📊 全面状态检查** - 22+ 应用程序检测，详细的系统健康报告

## 📞 支持与反馈

### 获取帮助
- 📖 查看 [用户指南](docs/USER_GUIDE.md) 和 [FAQ](docs/FAQ.md)
- 🔍 使用 [故障排除指南](docs/TROUBLESHOOTING.md) 诊断问题
- 💬 在 [GitHub Discussions](https://github.com/username/dotfiles/discussions) 参与讨论
- 🐛 在 [GitHub Issues](https://github.com/username/dotfiles/issues) 报告问题

### 联系方式
- **项目主页**: https://github.com/username/dotfiles
- **文档网站**: https://username.github.io/dotfiles
- **社区论坛**: https://github.com/username/dotfiles/discussions

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE) - 查看 LICENSE 文件了解详细信息。

## 🙏 致谢

感谢所有为项目做出贡献的开发者和用户！

特别感谢：
- [PowerShell](https://github.com/PowerShell/PowerShell) 社区
- [Scoop](https://scoop.sh/) 包管理器项目
- [Starship](https://starship.rs/) 提示符项目
- 所有提供反馈和建议的用户

---

<div align="center">

**⭐ 如果这个项目对您有帮助，请给我们一个 Star！**

[🚀 快速开始](#-快速开始) • [📚 文档](docs/README.md) • [📞 支持](#-支持与反馈)

</div>