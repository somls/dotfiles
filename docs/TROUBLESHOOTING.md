# 故障排除指南

本指南提供了系统性的问题诊断和解决方法，帮助您快速定位和解决 Dotfiles 项目中遇到的各种问题。

## 📋 目录

- [诊断工具](#诊断工具)
- [系统级问题](#系统级问题)
- [网络连接问题](#网络连接问题)
- [权限和安全问题](#权限和安全问题)
- [配置文件问题](#配置文件问题)
- [应用程序问题](#应用程序问题)
- [性能问题](#性能问题)
- [高级故障排除](#高级故障排除)

## 🔍 诊断工具

### 自动诊断

```powershell
# 1. 运行完整健康检查
.\health-check.ps1 -Detailed -Fix

# 2. 生成诊断报告
.\health-check.ps1 -Json -LogFile "diagnosis-$(Get-Date -Format 'yyyyMMddHHmm').log"

# 3. 检查环境配置
.\detect-environment.ps1 -Detailed

# 4. 验证符号链接状态
.\dev-link.ps1 -Verify
```

### 手动诊断步骤

#### 第一步：基础环境检查

```powershell
# 检查 PowerShell 版本
$PSVersionTable

# 检查执行策略
Get-ExecutionPolicy -List

# 检查当前位置
Get-Location

# 检查磁盘空间
Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, @{Name="Size(GB)";Expression={[math]::Round($_.Size/1GB,2)}}, @{Name="FreeSpace(GB)";Expression={[math]::Round($_.FreeSpace/1GB,2)}}
```

#### 第二步：网络连接检查

```powershell
# 检查基础网络连接
Test-NetConnection github.com -Port 443
Test-NetConnection raw.githubusercontent.com -Port 443

# 检查 DNS 解析
Resolve-DnsName github.com
Resolve-DnsName get.scoop.sh

# 检查代理设置
[System.Net.WebRequest]::DefaultWebProxy
$env:HTTP_PROXY
$env:HTTPS_PROXY
```

#### 第三步：权限检查

```powershell
# 检查当前用户权限
whoami /groups
whoami /priv

# 检查是否为管理员
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

# 检查文件系统权限
Get-Acl $env:USERPROFILE | Format-List
```

## 🖥️ 系统级问题

### 问题：PowerShell 版本过低

**症状**:
- 脚本运行时出现语法错误
- 某些 cmdlet 不可用
- 功能表现异常

**诊断**:
```powershell
# 检查 PowerShell 版本
$PSVersionTable.PSVersion

# 检查可用的 PowerShell 版本
Get-ChildItem -Path $PSHOME
```

**解决方案**:
```powershell
# 方法1: 使用 winget 安装 PowerShell 7+
winget install Microsoft.PowerShell

# 方法2: 使用 MSI 安装包
# 下载地址: https://github.com/PowerShell/PowerShell/releases

# 方法3: 使用 Chocolatey
choco install powershell-core

# 验证安装
pwsh --version
```

### 问题：Windows 版本兼容性

**症状**:
- 某些功能在旧版本 Windows 上不工作
- 路径解析错误
- 应用程序无法启动

**诊断**:
```powershell
# 检查 Windows 版本
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, WindowsBuildLabEx

# 检查系统架构
$env:PROCESSOR_ARCHITECTURE

# 检查 .NET Framework 版本
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name version -EA 0 | Where-Object { $_.PSChildName -Match '^(?!S)\p{L}'} | Select-Object PSChildName, version
```

**解决方案**:
```powershell
# 1. 升级到支持的 Windows 版本（Windows 10 1903+）
# 2. 使用兼容模式
$env:DOTFILES_COMPAT_MODE = "true"

# 3. 禁用不兼容的功能
.\install.ps1 -Type Git,PowerShell  # 仅安装基础配置
```

### 问题：执行策略限制

**症状**:
- 脚本无法运行
- 提示"禁止运行脚本"
- 模块加载失败

**诊断**:
```powershell
# 检查执行策略
Get-ExecutionPolicy -List

# 检查组策略设置
gpresult /r | findstr "执行策略\|Execution Policy"
```

**解决方案**:
```powershell
# 方法1: 设置用户级执行策略
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 方法2: 临时绕过（单次使用）
PowerShell -ExecutionPolicy Bypass -File .\install.ps1

# 方法3: 使用 Unblock-File 解除文件阻止
Get-ChildItem -Path . -Recurse | Unblock-File

# 方法4: 企业环境解决方案
# 联系 IT 管理员修改组策略设置
```

## 🌐 网络连接问题

### 问题：无法下载 Scoop 或应用程序

**症状**:
- 下载超时或失败
- SSL/TLS 连接错误
- DNS 解析失败

**诊断**:
```powershell
# 测试网络连接
Test-NetConnection github.com -Port 443 -InformationLevel Detailed
Test-NetConnection get.scoop.sh -Port 443

# 检查 TLS 设置
[Net.ServicePointManager]::SecurityProtocol

# 测试下载
try {
    Invoke-WebRequest -Uri "https://get.scoop.sh" -UseBasicParsing
    Write-Host "网络连接正常" -ForegroundColor Green
} catch {
    Write-Host "网络连接失败: $($_.Exception.Message)" -ForegroundColor Red
}
```

**解决方案**:
```powershell
# 1. 启用 TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2. 配置代理（如果需要）
$proxy = New-Object System.Net.WebProxy("http://proxy.company.com:8080")
$proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
[System.Net.WebRequest]::DefaultWebProxy = $proxy

# 3. 使用环境变量设置代理
$env:HTTP_PROXY = "http://proxy.company.com:8080"
$env:HTTPS_PROXY = "http://proxy.company.com:8080"

# 4. 配置 Scoop 代理
scoop config proxy http://proxy.company.com:8080

# 5. 使用国内镜像
scoop config SCOOP_REPO https://gitee.com/scoop-installer/scoop
scoop bucket add extras https://gitee.com/scoop-bucket/extras
```

### 问题：Git 克隆或推送失败

**症状**:
- Git 操作超时
- 认证失败
- SSL 证书错误

**诊断**:
```powershell
# 测试 Git 连接
git ls-remote https://github.com/git/git.git

# 检查 Git 配置
git config --list --show-origin

# 检查 SSH 密钥
ssh -T git@github.com
```

**解决方案**:
```powershell
# 1. 配置 Git 代理
git config --global http.proxy http://proxy.company.com:8080
git config --global https.proxy http://proxy.company.com:8080

# 2. 配置 Git 凭据
git config --global credential.helper manager-core

# 3. 跳过 SSL 验证（不推荐，仅用于测试）
git config --global http.sslVerify false

# 4. 使用 SSH 替代 HTTPS
git remote set-url origin git@github.com:username/dotfiles.git

# 5. 配置 SSH 代理
# 在 ~/.ssh/config 中添加：
# Host github.com
#     ProxyCommand connect -H proxy.company.com:8080 %h %p
```

## 🔐 权限和安全问题

### 问题：符号链接创建失败

**症状**:
- 提示"权限不足"
- 符号链接创建后无效
- 需要管理员权限

**诊断**:
```powershell
# 检查符号链接权限
whoami /priv | findstr SeCreateSymbolicLinkPrivilege

# 测试符号链接创建
$testTarget = "$env:TEMP\test-target.txt"
$testLink = "$env:TEMP\test-link.txt"
"test" | Out-File $testTarget
try {
    New-Item -ItemType SymbolicLink -Path $testLink -Target $testTarget
    Write-Host "符号链接权限正常" -ForegroundColor Green
    Remove-Item $testLink, $testTarget
} catch {
    Write-Host "符号链接权限不足: $($_.Exception.Message)" -ForegroundColor Red
}
```

**解决方案**:
```powershell
# 方法1: 启用开发者模式（Windows 10/11）
# 设置 > 更新和安全 > 开发者选项 > 开发者模式

# 方法2: 以管理员身份运行
Start-Process pwsh -Verb RunAs -ArgumentList "-File", "$PWD\dev-link.ps1"

# 方法3: 使用组策略启用权限
# gpedit.msc > 计算机配置 > Windows 设置 > 安全设置 > 本地策略 > 用户权限分配
# "创建符号链接" 添加当前用户或 Users 组

# 方法4: 使用复制模式替代
.\install.ps1 -Mode Copy

# 方法5: 使用 mklink 命令
cmd /c mklink "C:\Users\User\.gitconfig" "G:\Sync\dotfiles\git\gitconfig"
```

### 问题：文件访问被拒绝

**症状**:
- 无法读取或写入配置文件
- 权限错误
- 文件被锁定

**诊断**:
```powershell
# 检查文件权限
Get-Acl $env:USERPROFILE\.gitconfig | Format-List

# 检查文件是否被占用
Get-Process | Where-Object {$_.Path -like "*git*"}

# 检查文件属性
Get-ItemProperty $env:USERPROFILE\.gitconfig | Select-Object Attributes, IsReadOnly
```

**解决方案**:
```powershell
# 1. 修改文件权限
$acl = Get-Acl $env:USERPROFILE\.gitconfig
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, "FullControl", "Allow")
$acl.SetAccessRule($accessRule)
Set-Acl $env:USERPROFILE\.gitconfig $acl

# 2. 移除只读属性
Set-ItemProperty $env:USERPROFILE\.gitconfig -Name IsReadOnly -Value $false

# 3. 结束占用进程
Get-Process | Where-Object {$_.ProcessName -eq "git"} | Stop-Process -Force

# 4. 使用管理员权限
Start-Process pwsh -Verb RunAs -ArgumentList "-Command", "& {Set-ItemProperty '$env:USERPROFILE\.gitconfig' -Name IsReadOnly -Value `$false}"
```

## ⚙️ 配置文件问题

### 问题：配置文件语法错误

**症状**:
- 应用程序启动失败
- 配置不生效
- 解析错误

**诊断**:
```powershell
# JSON 文件语法检查
try {
    Get-Content ~/.config/app/config.json -Raw | ConvertFrom-Json | Out-Null
    Write-Host "JSON 语法正确" -ForegroundColor Green
} catch {
    Write-Host "JSON 语法错误: $($_.Exception.Message)" -ForegroundColor Red
}

# TOML 文件检查（Starship）
starship config 2>&1

# PowerShell 配置文件检查
try {
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $PROFILE -Raw), [ref]$null)
    Write-Host "PowerShell 配置语法正确" -ForegroundColor Green
} catch {
    Write-Host "PowerShell 配置语法错误: $($_.Exception.Message)" -ForegroundColor Red
}
```

**解决方案**:
```powershell
# 1. 使用在线工具验证语法
# JSON: https://jsonlint.com/
# TOML: https://www.toml-lint.com/

# 2. 恢复备份配置
.\install.ps1 -Restore -Type PowerShell

# 3. 重新生成配置
.\install.ps1 -Force -Type PowerShell

# 4. 使用默认配置
Copy-Item "templates\default-config.json" "~\.config\app\config.json"

# 5. 逐步调试配置
# 注释掉配置文件的部分内容，逐步启用
```

### 问题：配置路径错误

**症状**:
- 配置文件部署到错误位置
- 应用程序找不到配置
- 路径解析失败

**诊断**:
```powershell
# 检查应用程序配置路径
.\detect-environment.ps1 -Detailed | Select-String "配置路径"

# 手动检查常见配置路径
$paths = @(
    "$env:USERPROFILE\.gitconfig",
    "$env:APPDATA\Code\User\settings.json",
    "$env:LOCALAPPDATA\nvim\init.lua",
    "$env:USERPROFILE\.config\starship.toml"
)

foreach ($path in $paths) {
    if (Test-Path $path) {
        Write-Host "✓ $path" -ForegroundColor Green
    } else {
        Write-Host "✗ $path" -ForegroundColor Red
    }
}
```

**解决方案**:
```powershell
# 1. 使用自适应路径检测
$adaptivePaths = Get-AdaptiveConfigPaths
$adaptivePaths | Format-Table

# 2. 手动指定配置路径
.\install.ps1 -ConfigPath "C:\CustomPath\config"

# 3. 创建缺失的目录
New-Item -ItemType Directory -Path "$env:LOCALAPPDATA\nvim" -Force

# 4. 使用环境变量
$env:XDG_CONFIG_HOME = "$env:USERPROFILE\.config"

# 5. 检查应用程序文档
# 查看应用程序官方文档确认正确的配置路径
```

## 📦 应用程序问题

### 问题：Scoop 安装或更新失败

**症状**:
- 包下载失败
- 安装过程中断
- 依赖关系错误

**诊断**:
```powershell
# 检查 Scoop 状态
scoop status

# 检查 Scoop 健康状态
scoop checkup

# 检查特定包的信息
scoop info git

# 查看安装日志
Get-Content "$env:USERPROFILE\scoop\apps\scoop\current\install.log" -Tail 20
```

**解决方案**:
```powershell
# 1. 清理缓存重试
scoop cache rm *
scoop install git

# 2. 重置 Scoop
scoop reset *

# 3. 更新 Scoop 和 bucket
scoop update
scoop bucket rm main
scoop bucket add main

# 4. 手动下载安装
$url = "https://github.com/git-for-windows/git/releases/download/v2.41.0.windows.3/PortableGit-2.41.0.3-64-bit.7z.exe"
Invoke-WebRequest -Uri $url -OutFile "$env:TEMP\git-portable.exe"

# 5. 使用替代安装方法
winget install Git.Git
choco install git
```

### 问题：应用程序版本冲突

**症状**:
- 命令指向错误版本
- 功能不一致
- PATH 环境变量混乱

**诊断**:
```powershell
# 检查命令来源
Get-Command git -All | Select-Object Name, Source, Version

# 检查 PATH 环境变量
$env:PATH -split ';' | Where-Object {$_ -like "*git*"}

# 检查已安装版本
git --version
scoop list git
winget list --id Git.Git
```

**解决方案**:
```powershell
# 1. 调整 PATH 优先级
$scoopPath = "$env:USERPROFILE\scoop\shims"
$env:PATH = "$scoopPath;$($env:PATH -replace [regex]::Escape($scoopPath + ';'), '')"

# 2. 卸载冲突版本
winget uninstall Git.Git
# 或
scoop uninstall git

# 3. 使用 scoop reset 重置
scoop reset git

# 4. 清理注册表（谨慎操作）
# 删除旧版本的注册表项

# 5. 重新安装首选版本
scoop install git
scoop reset git
```

## 🚀 性能问题

### 问题：脚本执行缓慢

**症状**:
- 安装过程耗时过长
- 健康检查缓慢
- 系统响应迟缓

**诊断**:
```powershell
# 测量脚本执行时间
Measure-Command { .\health-check.ps1 }

# 检查系统资源使用
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10
Get-WmiObject -Class Win32_Processor | Select-Object LoadPercentage

# 检查磁盘性能
Get-Counter "\PhysicalDisk(_Total)\Disk Read Bytes/sec", "\PhysicalDisk(_Total)\Disk Write Bytes/sec"
```

**解决方案**:
```powershell
# 1. 禁用进度显示
$ProgressPreference = 'SilentlyContinue'

# 2. 使用并行处理（PowerShell 7+）
$packages | ForEach-Object -Parallel {
    scoop install $_
} -ThrottleLimit 4

# 3. 优化网络设置
[Net.ServicePointManager]::DefaultConnectionLimit = 100

# 4. 使用本地缓存
$env:SCOOP_CACHE = "$env:USERPROFILE\scoop\cache"

# 5. 分批处理
.\install_apps.ps1 -Category Essential
Start-Sleep 5
.\install_apps.ps1 -Category Development
```

### 问题：磁盘空间不足

**症状**:
- 安装失败
- 临时文件堆积
- 系统运行缓慢

**诊断**:
```powershell
# 检查磁盘空间
Get-WmiObject -Class Win32_LogicalDisk | 
    Select-Object DeviceID, 
    @{Name="Size(GB)";Expression={[math]::Round($_.Size/1GB,2)}}, 
    @{Name="FreeSpace(GB)";Expression={[math]::Round($_.FreeSpace/1GB,2)}}, 
    @{Name="PercentFree";Expression={[math]::Round(($_.FreeSpace/$_.Size)*100,2)}}

# 检查大文件
Get-ChildItem C:\ -Recurse -ErrorAction SilentlyContinue | 
    Sort-Object Length -Descending | 
    Select-Object -First 20 | 
    Select-Object FullName, @{Name="Size(MB)";Expression={[math]::Round($_.Length/1MB,2)}}
```

**解决方案**:
```powershell
# 1. 清理 Scoop 缓存
scoop cache rm *

# 2. 清理临时文件
Remove-Item $env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue

# 3. 清理系统垃圾
cleanmgr /sagerun:1

# 4. 移动 Scoop 到其他驱动器
scoop config SCOOP_GLOBAL D:\scoop

# 5. 使用磁盘清理工具
# 运行磁盘清理向导
```

## 🔬 高级故障排除

### 启用详细日志记录

```powershell
# 1. 启用 PowerShell 脚本块日志记录
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1 -PropertyType DWORD

# 2. 启用 PowerShell 模块日志记录
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Name "EnableModuleLogging" -Value 1 -PropertyType DWORD

# 3. 查看 PowerShell 事件日志
Get-WinEvent -LogName "Microsoft-Windows-PowerShell/Operational" -MaxEvents 50

# 4. 启用脚本详细输出
$VerbosePreference = "Continue"
$DebugPreference = "Continue"
```

### 使用 Process Monitor 跟踪文件操作

```powershell
# 1. 下载并运行 Process Monitor
# https://docs.microsoft.com/en-us/sysinternals/downloads/procmon

# 2. 设置过滤器
# Process Name contains: powershell
# Path contains: .gitconfig

# 3. 运行脚本并观察文件操作
.\install.ps1 -DryRun

# 4. 分析结果
# 查看文件访问、创建、删除操作
```

### 网络流量分析

```powershell
# 1. 使用 netstat 查看网络连接
netstat -an | findstr :443

# 2. 使用 Wireshark 捕获网络包
# 过滤器: host github.com or host get.scoop.sh

# 3. 使用 PowerShell 监控网络
Get-NetTCPConnection | Where-Object {$_.RemotePort -eq 443}
```

### 创建最小复现环境

```powershell
# 1. 创建干净的测试环境
$testDir = New-Item -ItemType Directory -Path "$env:TEMP\dotfiles-debug-$(Get-Random)"
Set-Location $testDir

# 2. 复制必要文件
Copy-Item "C:\dotfiles\*.ps1" -Destination $testDir

# 3. 设置最小配置
$env:SCOOP_DEBUG = "true"
$env:DOTFILES_DEBUG = "true"

# 4. 逐步测试功能
.\detect-environment.ps1
.\install_apps.ps1 -DryRun -Category Essential
```

### 性能分析

```powershell
# 1. 使用 PowerShell 性能分析
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
.\health-check.ps1
$stopwatch.Stop()
Write-Host "执行时间: $($stopwatch.ElapsedMilliseconds) ms"

# 2. 内存使用分析
$before = Get-Process -Id $PID | Select-Object WorkingSet64
.\install.ps1 -DryRun
$after = Get-Process -Id $PID | Select-Object WorkingSet64
Write-Host "内存增长: $([math]::Round(($after.WorkingSet64 - $before.WorkingSet64)/1MB, 2)) MB"

# 3. 使用 PowerShell 分析器
Install-Module PSProfiler
Start-PSProfiler
.\install.ps1
Stop-PSProfiler
Get-PSProfilerReport
```

## 📞 获取专业支持

### 收集完整诊断信息

```powershell
# 创建诊断包
$diagPath = "$env:TEMP\dotfiles-diagnosis-$(Get-Date -Format 'yyyyMMddHHmm')"
New-Item -ItemType Directory -Path $diagPath -Force

# 收集系统信息
Get-ComputerInfo | ConvertTo-Json | Out-File "$diagPath\system-info.json"
$PSVersionTable | ConvertTo-Json | Out-File "$diagPath\powershell-info.json"

# 收集环境信息
.\detect-environment.ps1 -Json | Out-File "$diagPath\environment-info.json"

# 收集健康检查报告
.\health-check.ps1 -Detailed -Json | Out-File "$diagPath\health-report.json"

# 收集错误日志
Get-WinEvent -LogName Application -MaxEvents 100 | 
    Where-Object {$_.LevelDisplayName -eq "Error" -and $_.TimeCreated -gt (Get-Date).AddDays(-1)} | 
    ConvertTo-Json | Out-File "$diagPath\error-logs.json"

# 打包诊断信息
Compress-Archive -Path $diagPath -DestinationPath "$diagPath.zip"
Write-Host "诊断包已创建: $diagPath.zip"
```

### 联系支持渠道

1. **GitHub Issues**: 创建详细的问题报告，附上诊断包
2. **社区论坛**: 在相关技术社区寻求帮助
3. **官方文档**: 查看最新的文档和更新
4. **专业服务**: 考虑寻求专业的技术支持服务

---

**⚠️ 重要提示**: 在进行高级故障排除时，请确保备份重要数据。某些操作可能会影响系统稳定性，建议在测试环境中先行验证。