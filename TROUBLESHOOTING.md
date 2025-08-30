# 🔧 故障排除指南

## 🚨 常见问题

### 1. 安装问题

#### PowerShell 执行策略错误
```
无法加载文件，因为在此系统上禁止运行脚本
```

**解决方案：**
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### 权限不足错误
```
拒绝访问路径 'xxx'
```

**解决方案：**
1. 以管理员身份运行 PowerShell
2. 或使用复制模式：`.\install.ps1 -Mode Copy`

#### Git 用户信息未配置
```
Please tell me who you are
```

**解决方案：**
```powershell
# 复制配置模板
copy git\.gitconfig.local.example %USERPROFILE%\.gitconfig.local

# 编辑个人信息
notepad %USERPROFILE%\.gitconfig.local
```

### 2. 环境检测问题

#### 应用程序未检测到
**解决方案：**
```powershell
# 重新检测环境
.\detect-environment.ps1 -Detailed

# 手动安装应用
.\install_apps.ps1 -Category Essential
```

#### 配置路径错误
**解决方案：**
```powershell
# 检查环境检测结果
.\detect-environment.ps1 -Json

# 手动指定组件
.\install.ps1 -Type PowerShell,Git
```

### 3. 配置问题

#### PowerShell 配置未生效
**解决方案：**
```powershell
# 检查配置文件是否存在
Test-Path $PROFILE

# 重新安装 PowerShell 配置
.\install.ps1 -Type PowerShell -Force

# 重新加载配置
. $PROFILE
```

#### 编辑器设置未同步
**解决方案：**
```powershell
# 检查终端安装
.\detect-environment.ps1 -Detailed

# 重新安装终端配置
.\install.ps1 -Type WindowsTerminal -Force
```

## 🔍 诊断工具

### 健康检查
```powershell
# 全面检查
.\health-check.ps1 -Detailed

# 检查特定组件
.\health-check.ps1 -Component Git

# 自动修复
.\health-check.ps1 -Fix
```

### 环境检测
```powershell
# 详细环境信息
.\detect-environment.ps1 -Detailed

# JSON 格式输出
.\detect-environment.ps1 -Json
```

### 预览模式
```powershell
# 预览安装操作
.\install.ps1 -DryRun

# 预览软件包安装
.\install_apps.ps1 -DryRun
```

## 🛠️ 手动修复

### 重置配置
```powershell
# 重新安装
.\setup.ps1
```

### 手动配置路径
如果自动检测失败，可以手动配置：

```powershell
# PowerShell 配置
$profilePath = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
Copy-Item "powershell\Microsoft.PowerShell_profile.ps1" $profilePath -Force

# Git 配置
Copy-Item "git\.gitconfig" "$env:USERPROFILE\.gitconfig" -Force

# Windows Terminal 配置
$wtConfig = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
Copy-Item "WindowsTerminal\settings.json" "$wtConfig\settings.json" -Force
```

## 📞 获取帮助

### 生成诊断报告
```powershell
# 生成完整诊断报告
$report = @"
=== Dotfiles 诊断报告 ===
生成时间: $(Get-Date)
PowerShell 版本: $($PSVersionTable.PSVersion)
操作系统: $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption)

环境检测:
$(.\detect-environment.ps1 -Json)

健康检查:
$(.\health-check.ps1 -Json)
"@

$report | Out-File "diagnostic-report.txt" -Encoding UTF8
Write-Host "诊断报告已保存到: diagnostic-report.txt"
```

### 常用检查命令
```powershell
# 检查 PowerShell 版本
$PSVersionTable

# 检查执行策略
Get-ExecutionPolicy -List

# 检查环境变量
Get-ChildItem Env: | Where-Object Name -match "PATH|PROFILE"

# 检查已安装应用
Get-Command git, code, pwsh -ErrorAction SilentlyContinue
```

## 💡 最佳实践

1. **定期检查**: 运行 `.\health-check.ps1` 定期检查配置状态
2. **备份配置**: 在修改前备份重要配置文件
3. **使用预览**: 使用 `-DryRun` 参数预览操作
4. **逐步安装**: 先安装基础组件，再安装可选组件
5. **查看日志**: 检查脚本输出和错误信息

---

如果问题仍然存在，请：
1. 运行诊断报告生成完整信息
2. 查看项目 Issues 或创建新的 Issue
3. 提供详细的错误信息和系统环境