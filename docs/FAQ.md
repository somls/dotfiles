# 常见问题解答 (FAQ)

本文档收集了用户在使用 Dotfiles 项目时最常遇到的问题和解决方案。

## 📋 目录

- [安装相关问题](#安装相关问题)
- [配置文件问题](#配置文件问题)
- [符号链接问题](#符号链接问题)
- [应用程序问题](#应用程序问题)
- [系统兼容性问题](#系统兼容性问题)
- [性能和维护问题](#性能和维护问题)

## 🚀 安装相关问题

### Q1: 运行脚本时提示"无法加载文件，因为在此系统上禁止运行脚本"

**问题**: PowerShell 执行策略限制导致脚本无法运行。

**解决方案**:
```powershell
# 方法1: 设置当前用户的执行策略
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 方法2: 临时绕过执行策略
PowerShell -ExecutionPolicy Bypass -File .\install.ps1

# 方法3: 检查当前执行策略
Get-ExecutionPolicy -List
```

**相关链接**: [PowerShell 执行策略文档](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies)

### Q2: 安装过程中网络连接失败

**问题**: 下载 Scoop 或应用程序时网络超时或连接失败。

**解决方案**:
```powershell
# 方法1: 配置代理（如果使用代理）
$env:SCOOP_PROXY = "http://proxy.company.com:8080"
.\install_apps.ps1

# 方法2: 使用国内镜像
scoop config SCOOP_REPO https://gitee.com/scoop-installer/scoop

# 方法3: 手动下载并安装 Scoop
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# 方法4: 检查网络连接
Test-NetConnection github.com -Port 443
```

### Q3: 安装向导卡在某个步骤不动

**问题**: 交互式安装向导在某个步骤停止响应。

**解决方案**:
```powershell
# 方法1: 使用批处理模式
.\install_apps.ps1 -All -Quiet

# 方法2: 手动分步执行
.\detect-environment.ps1
.\install_apps.ps1
.\install.ps1

# 方法3: 使用预览模式
.\install.ps1 -DryRun
Get-Content setup.log -Tail 20
```

## ⚙️ 配置文件问题

### Q4: 配置文件部署后应用程序无法识别

**问题**: 配置文件已复制到目标位置，但应用程序仍使用默认配置。

**解决方案**:
```powershell
# 1. 验证配置文件路径
.\health-check.ps1 -ConfigOnly

# 2. 检查配置文件语法
# 对于 JSON 文件
Get-Content ~/.config/app/config.json | ConvertFrom-Json

# 对于 TOML 文件（Starship）
starship config

# 3. 重启应用程序或重新加载配置
# PowerShell 配置
. $PROFILE

# 4. 检查应用程序版本兼容性
.\detect-environment.ps1 -Detailed
```

### Q5: 个人配置信息没有生效

**问题**: 运行统一安装向导后，Git 仍显示默认用户信息。

**解决方案**:
```powershell
# 1. 检查 gitconfig.local 文件是否存在
Test-Path ~\.gitconfig.local

# 2. 查看 Git 配置
git config --list --show-origin

# 3. 手动设置 Git 用户信息
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# 4. 重新复制个人配置模板
Copy-Item git\.gitconfig.local.example ~\.gitconfig.local -Force

# 5. 验证配置
git config user.name
git config user.email
```

### Q6: 配置文件被意外覆盖

**问题**: 原有的个人配置被项目配置覆盖。

**解决方案**:
```powershell
# 1. 查找备份文件
Get-ChildItem ~\ -Filter "*.backup" -Recurse

# 2. 恢复特定配置
.\install.ps1 -Restore -Type PowerShell

# 3. 手动恢复
Copy-Item "~\.gitconfig.backup" "~\.gitconfig"

# 4. 使用预览模式避免覆盖
.\install.ps1 -DryRun

# 5. 启用开发模式使用符号链接
.\install.ps1 -SetDevMode
.\dev-link.ps1
```

## 🔗 符号链接问题

### Q7: 符号链接创建失败，提示权限不足

**问题**: 在 Windows 上创建符号链接需要特殊权限。

**解决方案**:
```powershell
# 方法1: 以管理员身份运行 PowerShell
Start-Process pwsh -Verb RunAs
.\dev-link.ps1

# 方法2: 启用 Windows 开发者模式
# 设置 > 更新和安全 > 开发者选项 > 开发者模式

# 方法3: 使用组策略启用符号链接权限
# gpedit.msc > 计算机配置 > Windows 设置 > 安全设置 > 本地策略 > 用户权限分配
# "创建符号链接" 添加当前用户

# 方法4: 检查当前权限
whoami /priv | findstr SeCreateSymbolicLinkPrivilege
```

### Q8: 符号链接指向错误的目标

**问题**: 符号链接创建成功但指向了错误的文件或目录。

**解决方案**:
```powershell
# 1. 验证符号链接状态
.\dev-link.ps1 -Verify

# 2. 列出所有符号链接
.\dev-link.ps1 -List

# 3. 删除错误的符号链接
.\dev-link.ps1 -Remove -Type Neovim

# 4. 重新创建符号链接
.\dev-link.ps1 -Force

# 5. 手动检查符号链接
Get-Item ~\.gitconfig | Select-Object LinkType, Target
```

### Q9: 符号链接在系统重启后失效

**问题**: 符号链接在重启后变成普通文件或消失。

**解决方案**:
```powershell
# 1. 检查符号链接完整性
.\health-check.ps1 -Detailed

# 2. 验证目标文件是否存在
Test-Path "G:\Sync\dotfiles\git\gitconfig"

# 3. 使用绝对路径重新创建
.\dev-link.ps1 -Force

# 4. 检查磁盘错误
chkdsk C: /f

# 5. 考虑使用复制模式替代
.\install.ps1 -Mode Copy
```

## 📦 应用程序问题

### Q10: Scoop 安装失败或无法找到包

**问题**: 某些应用程序通过 Scoop 安装失败。

**解决方案**:
```powershell
# 1. 更新 Scoop 和 bucket
scoop update
scoop update *

# 2. 添加额外的 bucket
scoop bucket add extras
scoop bucket add versions
scoop bucket add nerd-fonts

# 3. 搜索包的可用版本
scoop search neovim

# 4. 手动安装特定版本
scoop install neovim@0.9.0

# 5. 清理缓存重试
scoop cache rm *
.\install_apps.ps1 -Force

# 6. 检查 Scoop 健康状态
scoop checkup
```

### Q11: 应用程序版本冲突

**问题**: 系统已安装的应用程序与 Scoop 版本冲突。

**解决方案**:
```powershell
# 1. 检查应用程序安装方式
.\detect-environment.ps1 -Detailed

# 2. 卸载系统版本，使用 Scoop 版本
# 例如：卸载系统 Git，使用 Scoop Git
scoop install git
scoop reset git

# 3. 调整 PATH 环境变量优先级
$env:PATH = "$env:USERPROFILE\scoop\shims;$env:PATH"

# 4. 使用 scoop reset 重置应用程序
scoop reset *

# 5. 验证应用程序版本
git --version
Get-Command git | Select-Object Source
```

### Q12: PowerShell 模块加载失败

**问题**: PowerShell 配置文件中的模块无法正常加载。

**解决方案**:
```powershell
# 1. 检查模块路径
$env:PSModulePath -split ';'

# 2. 手动导入模块
Import-Module posh-git -Force

# 3. 检查模块是否已安装
Get-Module -ListAvailable posh-git

# 4. 安装缺失的模块
Install-Module posh-git -Scope CurrentUser -Force

# 5. 重新加载 PowerShell 配置
. $PROFILE

# 6. 检查配置文件语法
Get-Content $PROFILE | Out-String | Invoke-Expression
```

## 🖥️ 系统兼容性问题

### Q13: 在 Windows 11 上某些功能不工作

**问题**: 部分功能在 Windows 11 上表现异常。

**解决方案**:
```powershell
# 1. 检查系统兼容性
.\health-check.ps1 -Detailed

# 2. 更新 PowerShell 到最新版本
winget install Microsoft.PowerShell

# 3. 检查 Windows Terminal 版本
winget upgrade Microsoft.WindowsTerminal

# 4. 验证路径映射
.\detect-environment.ps1 -Json | ConvertFrom-Json | Select-Object -ExpandProperty paths

# 5. 使用兼容模式
.\install.ps1 -Mode Copy  # 避免符号链接问题
```

### Q14: 在企业环境中无法正常工作

**问题**: 企业环境的安全策略限制了某些功能。

**解决方案**:
```powershell
# 1. 检查组策略限制
gpresult /r

# 2. 使用便携版应用程序
# 修改 scoop/packages.txt，选择便携版本

# 3. 配置企业代理
$env:HTTPS_PROXY = "http://proxy.company.com:8080"
$env:HTTP_PROXY = "http://proxy.company.com:8080"

# 4. 使用内网镜像
scoop config SCOOP_REPO https://internal-mirror.company.com/scoop

# 5. 仅安装配置文件，跳过应用程序
.\install.ps1 -Type Git,PowerShell,Starship
```

### Q15: PowerShell 版本兼容性问题

**问题**: 脚本在不同 PowerShell 版本间表现不一致。

**解决方案**:
```powershell
# 1. 检查 PowerShell 版本
$PSVersionTable

# 2. 升级到 PowerShell 7+
winget install Microsoft.PowerShell

# 3. 使用兼容性参数
pwsh -Version 5.1 -File .\install.ps1

# 4. 检查版本特定问题
.\health-check.ps1 -Detailed | Select-String "PowerShell"

# 5. 使用版本检查
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "建议使用 PowerShell 7+"
}
```

## 🔧 性能和维护问题

### Q16: 脚本运行速度很慢

**问题**: 安装或检查脚本执行时间过长。

**解决方案**:
```powershell
# 1. 使用并行处理（PowerShell 7+）
.\install_apps.ps1 -Parallel

# 2. 跳过不必要的检查
.\health-check.ps1 -ConfigOnly

# 3. 使用缓存
$env:SCOOP_CACHE = "$env:USERPROFILE\scoop\cache"

# 4. 禁用进度显示
$ProgressPreference = 'SilentlyContinue'

# 5. 分批处理
.\install_apps.ps1 -Category Essential
.\install_apps.ps1 -Category Development
```

### Q17: 如何定期维护和更新配置

**问题**: 需要定期维护 dotfiles 配置的最佳实践。

**解决方案**:
```powershell
# 1. 创建维护脚本
# maintenance.ps1
.\health-check.ps1
.\install_apps.ps1 -Update
git pull origin main
.\install.ps1

# 2. 设置定时任务
$action = New-ScheduledTaskAction -Execute "pwsh" -Argument "-File C:\dotfiles\maintenance.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 9am
Register-ScheduledTask -TaskName "DotfilesMaintenance" -Action $action -Trigger $trigger

# 3. 定期健康检查
.\health-check.ps1 -Json -LogFile "health-$(Get-Date -Format 'yyyyMMdd').log"

# 4. 备份重要配置
Copy-Item ~\.gitconfig.local "backup\gitconfig.local.$(Get-Date -Format 'yyyyMMdd')"
```

### Q18: 如何在多台电脑间同步配置

**问题**: 需要在多台设备间保持配置同步。

**解决方案**:
```powershell
# 1. 使用 Git 同步
git add .
git commit -m "Update configurations"
git push origin main

# 2. 在新设备上同步
git pull origin main
.\install.ps1

# 3. 使用符号链接模式（开发环境）
.\dev-link.ps1

# 4. 自动同步脚本
# sync.ps1
git pull origin main
if ($LASTEXITCODE -eq 0) {
    .\install.ps1
    .\health-check.ps1
}

# 5. 处理冲突
git status
git diff
git merge
```

## 🆘 获取更多帮助

### 诊断信息收集

如果以上解决方案都无法解决您的问题，请收集以下诊断信息：

```powershell
# 1. 生成完整的健康检查报告
.\health-check.ps1 -Detailed -Json > health-report.json

# 2. 收集环境信息
.\detect-environment.ps1 -Json > environment-info.json

# 3. 收集系统信息
Get-ComputerInfo | ConvertTo-Json > system-info.json

# 4. 收集错误日志
Get-WinEvent -LogName Application -MaxEvents 50 | 
    Where-Object {$_.LevelDisplayName -eq "Error"} | 
    ConvertTo-Json > error-logs.json
```

### 联系支持

- **GitHub Issues**: 在项目仓库创建 Issue，附上诊断信息
- **文档**: 查看 [故障排除指南](TROUBLESHOOTING.md)
- **社区**: 参与项目讨论和交流

### 贡献改进

如果您解决了文档中未涵盖的问题，欢迎：

1. 提交 Pull Request 更新此 FAQ
2. 分享您的解决方案
3. 帮助改进项目文档

---

**💡 提示**: 大多数问题可以通过运行 `.\health-check.ps1 -Fix` 自动解决。如果问题持续存在，请查看详细的健康检查报告。