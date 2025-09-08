# 跨用户兼容性指南

## 概述

`dev-link.ps1` 脚本已经过优化，确保在不同用户环境中都能正常工作，无论应用安装路径或配置路径如何变化。

## 主要改进

### 1. 动态路径检测

#### Scoop 安装路径检测
- ✅ 使用 `$env:SCOOP` 环境变量（优先）
- ✅ 使用 `$env:SCOOP_GLOBAL` 环境变量
- ✅ 检测 `$env:SystemDrive\Scoop`（避免硬编码驱动器）
- ✅ 检测 `$env:ProgramData\scoop`
- ✅ 回退到 `$env:USERPROFILE\scoop`（默认位置）

#### Windows Terminal 路径检测
- ✅ 动态搜索 `Microsoft.WindowsTerminal*` 包
- ✅ 支持正式版和预览版
- ✅ 自动检测 LocalState 目录
- ✅ 智能回退机制

#### PowerShell 配置路径
- ✅ 使用 `[Environment]::GetFolderPath('MyDocuments')` 获取文档路径
- ✅ 根据 PowerShell 版本自动选择正确目录
- ✅ 支持自定义文档路径（如 E:\Documents）

### 2. 环境变量优先策略

所有路径检测都优先使用环境变量，避免硬编码：

```powershell
# 好的做法 ✅
$env:USERPROFILE
$env:LOCALAPPDATA  
$env:SystemDrive
[Environment]::GetFolderPath('MyDocuments')

# 避免的做法 ❌
"C:\Users\Username"
"G:\Scoop"  
"C:\Scoop"
```

### 3. 智能检测和验证

#### 目录自动创建
- 自动创建缺失的父目录
- 记录创建过程到日志
- 优雅处理权限错误

#### 环境报告功能
运行 `.\dev-link.ps1 -Action Status` 可获得完整的环境检测报告：

- 系统信息（OS、用户、PowerShell 版本）
- 检测到的所有路径及其状态
- 应用程序检测结果
- 环境变量状态

### 4. 兼容性测试

使用 `test-cross-user-compatibility.ps1` 进行兼容性测试：

```powershell
# 基本测试
.\test-cross-user-compatibility.ps1

# 详细测试
.\test-cross-user-compatibility.ps1 -TestScoop -TestWindowsTerminal
```

## 支持的环境

### 操作系统
- ✅ Windows 10/11
- ✅ Windows Server 2019/2022

### PowerShell 版本
- ✅ Windows PowerShell 5.1
- ✅ PowerShell 7.x

### 安装方式
- ✅ Scoop（用户安装）
- ✅ Scoop（全局安装）
- ✅ 官方安装程序
- ✅ Chocolatey
- ✅ 便携版本

### 用户环境
- ✅ 标准用户账户
- ✅ 管理员账户
- ✅ 域用户账户
- ✅ 自定义文档路径
- ✅ 非标准驱动器布局

## 最佳实践

### 1. 环境变量设置

确保正确设置相关环境变量：

```powershell
# Scoop 用户安装
$env:SCOOP = "D:\Scoop"  # 自定义位置

# Scoop 全局安装  
$env:SCOOP_GLOBAL = "C:\ProgramData\scoop"
```

### 2. 权限管理

创建符号链接需要管理员权限：

```powershell
# 检查权限
if (-not (Test-Administrator)) {
    Write-Warning "需要管理员权限创建符号链接"
    # 自动提升权限或提示用户
}
```

### 3. 错误处理

脚本包含完善的错误处理：

- 路径不存在时的优雅降级
- 权限不足时的清晰提示
- 应用程序未安装时的智能跳过

## 故障排除

### 常见问题

1. **Scoop 路径检测失败**
   - 检查 `$env:SCOOP` 环境变量
   - 确认 Scoop 正确安装
   - 运行环境检测报告

2. **Windows Terminal 配置失败**
   - 确认 Windows Terminal 已安装
   - 检查包名是否正确
   - 验证 LocalState 目录权限

3. **PowerShell 配置路径错误**
   - 检查文档文件夹重定向设置
   - 确认 PowerShell 版本检测正确
   - 验证目录创建权限

### 调试命令

```powershell
# 完整环境报告
.\dev-link.ps1 -Action Status

# 特定组件状态
.\dev-link.ps1 -Action Status -Component PowerShell

# 兼容性测试
.\test-cross-user-compatibility.ps1 -TestScoop -TestWindowsTerminal
```

## 总结

通过这些改进，`dev-link.ps1` 现在具备了出色的跨用户兼容性：

- 🎯 **智能检测**：自动适应不同的安装和配置路径
- 🔧 **灵活配置**：支持各种安装方式和用户环境  
- 🛡️ **错误处理**：优雅处理各种异常情况
- 📊 **详细报告**：提供完整的环境检测信息
- 🧪 **测试工具**：包含专门的兼容性测试脚本

无论在哪个用户环境中使用，都能确保 dotfiles 配置正确链接和工作。