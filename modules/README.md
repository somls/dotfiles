# Modules 文件夹

本文件夹包含 dotfiles 项目的 PowerShell 模块，提供通用的工具函数和类库支持。

## 📁 模块概览

### `DotfilesUtilities.psm1`
**综合工具模块** - 整合了UI管理和验证功能的单一模块

#### 🎨 UI 和输出功能
- `Write-DotfilesMessage` - 统一的彩色消息输出
- `Write-DotfilesHeader` - 格式化标题显示
- `Show-DotfilesProgress` - 进度条管理
- `Write-DotfilesSummary` - 操作结果摘要

#### 🔍 验证功能
- `Test-DotfilesPath` - 路径存在性和类型验证
- `Test-DotfilesJson` - JSON文件格式验证
- `Test-DotfilesPowerShell` - PowerShell脚本语法检查
- `Get-DotfilesValidationResult` - 统一验证结果创建

#### 🛠️ 文件操作
- `Backup-DotfilesFile` - 创建文件备份
- `Get-DotfilesEnvironment` - 获取系统环境信息

#### 📋 类和数据结构
- `ValidationResult` - 验证结果数据类

## 🚀 使用方法

### 基本导入
```powershell
# 导入模块
Import-Module .\modules\DotfilesUtilities.psm1

# 或者强制重新加载
Import-Module .\modules\DotfilesUtilities.psm1 -Force
```

### UI 功能示例
```powershell
# 彩色消息输出
Write-DotfilesMessage "操作成功完成" -Type Success
Write-DotfilesMessage "发现潜在问题" -Type Warning
Write-DotfilesMessage "严重错误" -Type Error

# 显示标题
Write-DotfilesHeader -Title "系统检查" -Subtitle "正在验证配置文件"

# 进度管理
Show-DotfilesProgress -Activity "处理文件" -Status "正在验证..." -PercentComplete 50
Show-DotfilesProgress -Activity "处理文件" -Completed

# 显示摘要
$summary = @{
    "成功项目" = 10
    "警告项目" = 2
    "错误项目" = 1
}
Write-DotfilesSummary -Summary $summary
```

### 验证功能示例
```powershell
# 路径验证
$pathResult = Test-DotfilesPath -Path "scoop\config.json.example" -Type File
if ($pathResult.IsValid) {
    Write-Host "文件存在且有效"
}

# JSON 验证
$jsonResult = Test-DotfilesJson -Path "WindowsTerminal\settings.json"
if ($jsonResult.IsValid) {
    Write-Host "JSON格式正确"
    $configObject = $jsonResult.Object
}

# PowerShell 脚本验证
$psResult = Test-DotfilesPowerShell -Path "install.ps1"
if ($psResult.IsValid) {
    Write-Host "脚本语法正确，包含 $($psResult.TokenCount) 个令牌"
}

# 统一验证结果
$result = Get-DotfilesValidationResult -Component "ConfigFile" -Path "starship\starship.toml"
Write-Host "验证结果: $($result.Status) - $($result.Message)"
```

### 文件操作示例
```powershell
# 创建备份
$backup = Backup-DotfilesFile -Path "important-config.json"
if ($backup.Success) {
    Write-Host "备份创建于: $($backup.BackupPath)"
}

# 获取环境信息
$env = Get-DotfilesEnvironment
Write-Host "运行于: $($env.ComputerName) ($($env.OSVersion))"
Write-Host "PowerShell版本: $($env.PowerShellVersion)"
```

## 🎯 设计原则

### 统一性
- 所有函数使用 `DotfilesXxx` 命名约定
- 统一的参数命名和返回值格式
- 一致的错误处理和日志记录

### 模块化
- 功能按逻辑分组（UI、验证、文件操作）
- 清晰的公共接口和内部实现分离
- 最小化外部依赖

### 性能优化
- 轻量级设计，快速加载
- 支持批量操作和流水线处理
- 内置缓存机制（适用场景）

## 📊 输出格式

### 消息类型
- `Success` ✓ 绿色 - 成功操作
- `Error` ✗ 红色 - 错误信息
- `Warning` ! 黄色 - 警告提示
- `Info` · 青色 - 一般信息
- `Debug` - 灰色 - 调试信息

### 验证结果结构
```powershell
[ValidationResult] @{
    Component = "组件名称"
    IsValid = $true/$false
    Status = "Success/Warning/Error"
    Message = "状态描述"
    Details = "详细信息"
    Suggestion = "改进建议"
    Metadata = @{ /* 元数据 */ }
    Duration = [timespan]
}
```

## 🔧 高级使用

### 批量验证
```powershell
$files = @("config1.json", "config2.json", "script.ps1")
$results = foreach ($file in $files) {
    Get-DotfilesValidationResult -Component $file -Path $file
}

# 统计结果
$summary = @{
    "总文件数" = $results.Count
    "成功验证" = ($results | Where-Object IsValid).Count
    "验证失败" = ($results | Where-Object { -not $_.IsValid }).Count
}
Write-DotfilesSummary -Summary $summary
```

### 自定义验证流程
```powershell
function Test-CustomConfig {
    param([string]$ConfigPath)
    
    # 使用模块功能进行验证
    Write-DotfilesHeader -Title "自定义配置验证"
    
    $pathCheck = Test-DotfilesPath -Path $ConfigPath -Type File
    if (-not $pathCheck.IsValid) {
        Write-DotfilesMessage "配置文件不存在: $ConfigPath" -Type Error
        return $false
    }
    
    $jsonCheck = Test-DotfilesJson -Path $ConfigPath
    if (-not $jsonCheck.IsValid) {
        Write-DotfilesMessage "JSON格式错误: $($jsonCheck.Message)" -Type Error
        return $false
    }
    
    Write-DotfilesMessage "配置验证通过" -Type Success
    return $true
}
```

## 🐛 故障排除

### 常见问题

1. **模块加载失败**
   ```powershell
   # 检查执行策略
   Get-ExecutionPolicy
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   
   # 强制重新导入
   Remove-Module DotfilesUtilities -ErrorAction SilentlyContinue
   Import-Module .\modules\DotfilesUtilities.psm1 -Force
   ```

2. **函数不可用**
   ```powershell
   # 检查导出的函数
   Get-Module DotfilesUtilities | Select-Object -ExpandProperty ExportedFunctions
   ```

3. **颜色显示问题**
   ```powershell
   # 检查终端颜色支持
   $Host.UI.RawUI.ForegroundColor = "Green"
   Write-Host "测试颜色输出" -ForegroundColor Green
   ```

### 调试模式
```powershell
# 启用详细模式查看模块加载信息
Import-Module .\modules\DotfilesUtilities.psm1 -Verbose

# 使用调试信息
Write-DotfilesMessage "调试信息" -Type Debug
```

## 📈 扩展开发

### 添加新功能
1. 在模块文件中添加新函数
2. 更新 `Export-ModuleMember` 导出列表
3. 添加相应的使用示例和文档
4. 运行测试确保兼容性

### 贡献指南
- 保持函数命名一致性（`DotfilesXxx`）
- 包含适当的错误处理
- 添加详细的注释和帮助文档
- 遵循现有的代码风格

## 🔗 相关文档

- [脚本使用指南](../scripts/README.md)


---

💡 **提示**: 该模块是项目的核心组件，为所有脚本提供统一的工具函数。建议在开发新功能时优先使用模块提供的标准化接口。