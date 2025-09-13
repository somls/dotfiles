# PowerShell 配置管理

这个目录包含了完整的 PowerShell 配置系统，采用模块化设计，支持 PowerShell 5.1 和 PowerShell 7+，针对 Windows 环境进行了优化。配置系统注重启动性能和功能完整性的平衡。

## 📁 目录结构

```
powershell/
├── Microsoft.PowerShell_profile.ps1    # 主配置文件 (PowerShell 7 配置文件)
└── .powershell/                         # 模块化配置目录
    ├── aliases.ps1                      # 命令别名定义
    ├── functions.ps1                    # 自定义函数 (PowerShell 7)
    ├── functions.winps.ps1              # 自定义函数 (Windows PowerShell 5.1)
    ├── history.ps1                      # 历史记录配置
    ├── keybindings.ps1                  # 快捷键绑定
    ├── theme.ps1                        # 主题和外观配置
    ├── tools.ps1                        # 工具和实用程序配置
    ├── extra.ps1                        # 额外的个性化配置
    └── pshistory.txt                    # PowerShell 历史记录文件
```

## 🚀 安装说明

### 自动安装（推荐）

使用部署脚本安装 PowerShell 配置：

```powershell
# 从项目根目录运行：

# 安装所有配置（包括 PowerShell）
.\deploy-config.ps1

# 只安装 PowerShell 配置
.\deploy-config.ps1 -ConfigType powershell

# 预览安装效果（不实际更改）
.\deploy-config.ps1 -ConfigType powershell -DryRun

# 强制覆盖现有配置
.\deploy-config.ps1 -ConfigType powershell -Force
```

### 手动安装

如果需要手动安装，配置文件会被复制到以下位置：

- **PowerShell 7**: `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`
- **Windows PowerShell 5.1**: `~/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1`
- **配置目录**: `~/.powershell/`（所有配置模块）

## ⚙️ 配置说明

### 🔧 主配置文件 (Microsoft.PowerShell_profile.ps1)

主配置文件采用智能加载策略：

- **版本检测**: 自动识别 PowerShell 版本并加载对应配置
- **性能优化**: 优先加载核心功能，延迟加载可选功能
- **错误处理**: 单个模块加载失败不影响其他模块
- **编码设置**: 统一使用 UTF-8 编码

### 📦 模块化配置系统

#### 核心配置（优先加载）
- **functions.ps1** / **functions.winps.ps1**: 自定义函数库
- **aliases.ps1**: 命令别名和快捷方式

#### 可选配置（按需加载）
- **history.ps1**: 历史记录增强功能
- **keybindings.ps1**: 自定义快捷键
- **tools.ps1**: 开发工具集成
- **theme.ps1**: 外观和颜色主题
- **extra.ps1**: 个人定制配置

## ✨ 主要特性

### 🎯 智能版本适配
- 自动检测 PowerShell 版本
- Windows PowerShell 5.1 和 PowerShell 7+ 分别优化
- 跨版本兼容的函数和别名

### ⚡ 性能优化
- 分层加载策略，核心功能优先
- 避免重复初始化
- 最小化启动时间影响

### 🛠️ 开发者友好
- 丰富的别名和函数库
- 增强的历史记录功能
- 智能补全和快捷键
- Git 和开发工具集成

### 🎨 个性化定制
- 模块化配置，易于修改
- 主题和颜色自定义
- 个人配置文件支持

## 📋 常用功能

### 增强的别名系统
```powershell
# 常用别名示例
ls        # Get-ChildItem 增强版
ll        # 详细列表显示
la        # 显示隐藏文件
..        # 上级目录
...       # 上上级目录
grep      # Select-String
which     # Get-Command
```

### 实用函数库
```powershell
# 实用函数示例
Get-Weather          # 获取天气信息
Test-Port           # 端口连通性测试
Get-PublicIP        # 获取公网IP
Invoke-GitClone     # 增强的 Git 克隆
New-ProjectFolder   # 创建项目目录结构
```

### 增强的历史记录
- 跨会话历史记录持久化
- 智能历史搜索
- 重复命令去重
- 历史记录统计

## 🔧 自定义配置

### 添加个人配置
在 `extra.ps1` 中添加个人定制：

```powershell
# 个人别名
Set-Alias -Name myapp -Value "C:\MyApp\app.exe"

# 个人函数
function Get-MyStatus {
    # 你的自定义逻辑
}

# 环境变量
$env:MY_CUSTOM_PATH = "C:\MyCustomPath"
```

### 主题定制
在 `theme.ps1` 中自定义外观：

```powershell
# 自定义颜色
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"

# PSReadLine 颜色设置
Set-PSReadLineOption -Colors @{
    Command = 'Yellow'
    Parameter = 'Green'
    String = 'DarkCyan'
}
```

## ⚠️ 注意事项

### 执行策略
确保 PowerShell 执行策略允许运行脚本：

```powershell
# 检查当前策略
Get-ExecutionPolicy

# 如果需要，设置合适的策略（管理员权限）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 模块依赖
某些功能可能需要额外模块：

```powershell
# 安装常用模块
Install-Module PSReadLine -Force
Install-Module Terminal-Icons -Force
Install-Module z -Force  # 目录跳转增强
```

### 性能考虑
- 配置系统经过性能优化，但大量自定义可能影响启动速度
- 可以通过注释不需要的模块来提高启动速度
- 使用 `Measure-Command` 测试启动时间

## 🔄 更新和维护

### 配置更新
```powershell
# 重新安装最新配置
.\deploy-config.ps1 -ConfigType powershell -Force

# 重新加载配置（无需重启）
. $PROFILE
```

### 备份和恢复
部署脚本会自动备份现有配置到 `.dotfiles-backup` 目录，如需恢复：

```powershell
# 手动恢复备份文件
# 备份位置：~/.dotfiles-backup/
```

## 📚 相关链接

- [PowerShell 官方文档](https://docs.microsoft.com/powershell/)
- [PSReadLine 模块](https://github.com/PowerShell/PSReadLine)
- [PowerShell Gallery](https://www.powershellgallery.com/)
- [Windows Terminal](https://github.com/microsoft/terminal)

## 🐛 故障排除

### 配置不生效
1. 检查配置文件路径是否正确
2. 确认执行策略允许运行脚本
3. 检查是否有语法错误：`PowerShell -NoProfile -File $PROFILE`

### 启动速度慢
1. 注释掉 `extra.ps1` 中的非必要配置
2. 检查网络相关的初始化代码
3. 使用 `Measure-Command { . $PROFILE }` 测试加载时间

### 函数或别名不可用
1. 检查对应的配置文件是否存在
2. 确认模块加载没有错误
3. 重新加载配置：`. $PROFILE`
