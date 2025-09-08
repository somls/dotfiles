# 📖 Dotfiles 使用指南

**更新时间**: 2025-09-08

> 💡 **提示**: 完整的用户指南请查看 [docs/USER_GUIDE.md](docs/USER_GUIDE.md)

## 🚀 快速开始

### 新用户安装
```powershell
# 分步安装（推荐）- 现在包含自动环境检查
.\detect-environment.ps1    # 检测环境（22+ 应用程序）
.\install_apps.ps1          # 安装应用（自动环境兼容性检查）
.\install.ps1               # 部署配置（智能路径检测）
.\health-check.ps1          # 验证安装（全面健康检查）
```

### 🆕 环境适配增强
- ✅ **自动环境检查**: 安装前检查 PowerShell 版本、执行策略、网络连接、磁盘空间
- ✅ **智能路径检测**: 自动适配不同的软件安装方式和用户环境
- ✅ **扩展应用支持**: 新增 Python、NodeJS、Zoxide、LazyGit 等应用检测
- ✅ **增强错误处理**: 提供详细的问题说明和解决建议

### 开发者模式
```powershell
# 创建所有符号链接
.\dev-link.ps1 -Action Create

# 检查链接状态
.\dev-link.ps1 -Action Status

# 运行健康检查
.\health-check.ps1 -Category SymLinks
```

## 🔧 dev-link.ps1 脚本详解

### 基本语法
```powershell
.\dev-link.ps1 -Action <Create|Remove|Status> [-Component <ComponentName>] [-Force] [-Quiet]
```

### 支持的组件 (9个)
| 组件 | 说明 | 目标位置 |
|------|------|----------|
| `Git` | Git主配置文件 | `~\.gitconfig` |
| `GitExtras` | Git扩展配置 | `~\.gitignore_global`, `~\.gitmessage` |
| `PowerShell` | PowerShell主配置 | `$PROFILE` |
| `PowerShellExtras` | PowerShell扩展配置 | `~\.powershell\` |
| `PowerShellModule` | DotfilesUtilities模块 | PowerShell模块目录 |
| `Neovim` | Neovim编辑器配置 | `%LOCALAPPDATA%\nvim` |
| `Starship` | 终端提示符配置 | `~\.config\starship.toml` |
| `WindowsTerminal` | Windows Terminal配置 | Windows Terminal目录 |
| `Scoop` | Scoop包管理器配置 | Scoop安装目录 |

### 常用命令示例

#### 创建符号链接
```powershell
# 创建所有符号链接
.\dev-link.ps1 -Action Create

# 创建特定组件
.\dev-link.ps1 -Action Create -Component Git,PowerShell

# 强制覆盖现有文件
.\dev-link.ps1 -Action Create -Force
```

#### 检查状态
```powershell
# 检查所有状态
.\dev-link.ps1 -Action Status

# 检查特定组件
.\dev-link.ps1 -Action Status -Component GitExtras
```

#### 移除链接
```powershell
# 移除所有符号链接
.\dev-link.ps1 -Action Remove

# 移除特定组件
.\dev-link.ps1 -Action Remove -Component Scoop -Force
```

## 🏥 health-check.ps1 脚本详解

### 基本语法
```powershell
.\health-check.ps1 [-Fix] [-Detailed] [-OutputFormat <Console|JSON|Both>] [-Category <System|Applications|ConfigFiles|SymLinks|All>]
```

### 常用命令
```powershell
# 基本健康检查
.\health-check.ps1

# 详细检查
.\health-check.ps1 -Detailed

# 只检查符号链接
.\health-check.ps1 -Category SymLinks

# 🆕 系统环境兼容性检查
.\health-check.ps1 -Category System

# 自动修复问题
.\health-check.ps1 -Fix

# JSON格式输出
.\health-check.ps1 -OutputFormat JSON
```

### 🆕 新增检查项目
| 检查项目 | 说明 | 自动修复 |
|----------|------|----------|
| **磁盘空间** | 检查可用空间（推荐2GB+） | ❌ |
| **网络连接** | 测试关键下载源连通性 | ❌ |
| **用户权限** | 检查管理员权限状态 | ❌ |
| **开发者模式** | 检查符号链接支持 | ❌ |
| **执行策略** | 检查脚本执行权限 | ✅ |

## 🛠️ 高级用法

### 批处理操作
```powershell
# 重新链接所有配置
.\dev-link.ps1 -Action Remove -Force
.\dev-link.ps1 -Action Create -Force

# 备份后链接特定组件
Copy-Item $PROFILE "$PROFILE.backup.$(Get-Date -Format 'yyyyMMdd')"
.\dev-link.ps1 -Action Create -Component PowerShell -Force
```

### 自定义配置
如需添加新组件，请修改 `dev-link.ps1` 中的相关函数：
- `Get-ComponentMappings()`: 添加组件映射
- `Get-ComponentPaths()`: 添加目标路径

## 🔍 故障排除

### 常见问题
1. **权限不足**: 以管理员身份运行 PowerShell
2. **符号链接失败**: 启用开发者模式或使用管理员权限
3. **模块加载失败**: 检查 `$env:PSModulePath` 或手动导入模块
4. **Scoop路径错误**: 检查 `$env:SCOOP` 环境变量

### 🆕 自动问题检测
现在脚本会自动检测并提示解决方案：
```powershell
# 环境兼容性问题示例
[WARN] Environment compatibility issues found:
  - Low disk space: 1.2GB available (minimum 2GB recommended)
  - Internet connectivity issue - may affect package downloads
Do you want to continue anyway? [Continue/Exit]
```

### 调试命令
```powershell
# 详细输出
.\dev-link.ps1 -Action Status -Verbose

# 查看日志
Get-Content .\dev-link.log -Tail 20
Get-Content .\health-check.log -Tail 20
```

---

**📚 完整文档**: 查看 [docs/USER_GUIDE.md](docs/USER_GUIDE.md) 获取详细的用户指南