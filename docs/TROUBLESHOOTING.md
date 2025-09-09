# 🔧 故障排除指南

本指南提供了Windows Dotfiles管理系统常见问题的详细诊断和解决方案。按问题类型分类，每个问题都包含症状识别、诊断方法和解决方案。

## 📋 目录

- [🚨 紧急问题快速解决](#紧急问题快速解决)
- [🔍 诊断工具使用](#诊断工具使用)
- [🖥️ 系统级问题](#系统级问题)
- [🌐 网络和代理问题](#网络和代理问题)
- [🔒 权限和安全问题](#权限和安全问题)
- [📦 应用程序安装问题](#应用程序安装问题)
- [⚙️ 配置文件问题](#配置文件问题)
- [🔗 符号链接问题](#符号链接问题)
- [⚡ 性能问题](#性能问题)
- [🏢 企业环境问题](#企业环境问题)
- [🧪 高级诊断技术](#高级诊断技术)

---

## 🚨 紧急问题快速解决

### 系统完全无法工作

**症状**: 所有dotfiles功能都不工作，PowerShell报错，应用程序无法启动

**快速恢复**:
```powershell
# 1. 紧急回滚到备份状态
cd dotfiles
.\install.ps1 -Rollback

# 2. 如果回滚失败，手动恢复关键配置
Copy-Item "$env:USERPROFILE\.dotfiles-backup\*" "$env:USERPROFILE\" -Recurse -Force

# 3. 重启PowerShell并重新加载配置
exit  # 然后重新打开PowerShell
. $PROFILE
```

### PowerShell完全无法启动

**症状**: PowerShell启动时立即崩溃或卡死

**应急处理**:
```cmd
# 使用CMD临时修复
# 1. 重命名问题配置文件
ren "%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" "Microsoft.PowerShell_profile.ps1.broken"

# 2. 使用无配置模式启动PowerShell
pwsh -NoProfile

# 3. 在无配置模式下重新安装
cd dotfiles
.\install.ps1 -Type PowerShell -Force
```

### 关键应用程序消失

**症状**: Git、PowerShell、终端等关键工具突然无法使用

**立即修复**:
```powershell
# 1. 检查环境变量
$env:PATH -split ';' | Where-Object { $_ }

# 2. 重新注册PATH
refreshenv  # 如果安装了Chocolatey
# 或重启PowerShell

# 3. 重新安装核心应用
.\install_apps.ps1 -Category Essential -Force
```

---

## 🔍 诊断工具使用

### 基础诊断命令

**完整系统诊断**:
```powershell
# 1. 环境状态检查
.\detect-environment.ps1 -Detailed

# 2. 健康状况检查
.\health-check.ps1 -Detailed

# 3. 配置文件完整性检查
.\health-check.ps1 -Category ConfigFiles

# 4. 自动修复配置问题
.\health-check.ps1 -Fix
```

**生成详细诊断报告**:
```powershell
function New-DiagnosticReport {
    $reportDir = "diagnostic-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory $reportDir

    # 系统信息
    Get-ComputerInfo | ConvertTo-Json | Out-File "$reportDir\system-info.json"
    
    # 环境检测
    .\detect-environment.ps1 -Json | Out-File "$reportDir\environment.json"
    
    # 健康检查
    .\health-check.ps1 -OutputFormat JSON | Out-File "$reportDir\health-check.json"
    
    # PowerShell信息
    $PSVersionTable | ConvertTo-Json | Out-File "$reportDir\powershell-info.json"
    
    # 环境变量
    Get-ChildItem Env: | ConvertTo-Json | Out-File "$reportDir\environment-vars.json"
    
    # 已安装应用
    Get-Command | Select-Object Name, Source, Version | ConvertTo-Json | Out-File "$reportDir\commands.json"
    
    Write-Host "诊断报告已生成: $reportDir" -ForegroundColor Green
}

# 使用方法
New-DiagnosticReport
```

### 日志分析工具

**查看系统错误日志**:
```powershell
# PowerShell错误日志
Get-WinEvent -LogName "Windows PowerShell" -MaxEvents 20 | 
    Where-Object LevelDisplayName -eq "Error"

# 应用程序错误日志
Get-WinEvent -LogName Application -MaxEvents 50 | 
    Where-Object {$_.LevelDisplayName -eq "Error" -and $_.TimeCreated -gt (Get-Date).AddHours(-24)}

# Scoop日志（如果存在）
if (Test-Path "$env:USERPROFILE\scoop\logs") {
    Get-ChildItem "$env:USERPROFILE\scoop\logs" -Filter "*.log" | 
        Sort-Object LastWriteTime -Descending | Select-Object -First 5
}
```

---

## 🖥️ 系统级问题

### PowerShell执行策略限制

**症状**: 
- "无法加载文件，因为在此系统上禁止运行脚本"
- "执行策略更改"提示

**诊断**:
```powershell
# 检查当前执行策略
Get-ExecutionPolicy -List
```

**解决方案**:
```powershell
# 方案1: 设置当前用户策略（推荐）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# 方案2: 临时绕过策略
PowerShell -ExecutionPolicy Bypass -File .\install.ps1

# 方案3: 企业环境解决方案
# 如果组策略锁定，联系管理员或使用以下方法：
Set-ExecutionPolicy Bypass -Scope Process -Force  # 仅当前进程
```

### Windows版本兼容性问题

**症状**:
- 某些功能在旧版Windows上不工作
- PowerShell版本不匹配

**诊断**:
```powershell
# 检查Windows版本
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, WindowsBuildLabEx

# 检查PowerShell版本
$PSVersionTable

# 检查.NET版本
Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -Name Release
```

**解决方案**:
```powershell
# Windows 10 1903以下版本升级PowerShell
if ([int](Get-ComputerInfo).WindowsBuildLabEx.Split('.')[0] -lt 18362) {
    Write-Warning "检测到较旧的Windows版本，建议升级PowerShell"
    
    # 安装PowerShell 7
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install Microsoft.PowerShell
    } else {
        # 手动下载安装
        Invoke-WebRequest "https://aka.ms/powershell-release?tag=stable" -OutFile "PowerShell-Win.msi"
        Start-Process msiexec.exe -ArgumentList "/i PowerShell-Win.msi /quiet" -Wait
    }
}

# 启用兼容性模式
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "使用兼容性模式运行" -ForegroundColor Yellow
    # 在脚本中添加兼容性检查
}
```

### 字符编码问题

**症状**:
- 中文字符显示乱码
- 配置文件内容异常

**诊断和解决**:
```powershell
# 检查当前编码
[Console]::OutputEncoding
$OutputEncoding

# 设置UTF-8编码（添加到Profile）
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Windows Terminal字体设置
# 在settings.json中确保使用支持中文的字体
# "fontFace": "Cascadia Code PL" 或 "JetBrains Mono"
```

---

## 🌐 网络和代理问题

### 网络连接失败

**症状**:
- Scoop安装失败
- 无法下载应用程序
- Git clone/push失败

**诊断网络连接**:
```powershell
function Test-NetworkConnectivity {
    $testSites = @(
        @{Name="GitHub"; Host="github.com"; Port=443},
        @{Name="Scoop"; Host="get.scoop.sh"; Port=443},
        @{Name="PowerShell Gallery"; Host="www.powershellgallery.com"; Port=443}
    )
    
    foreach ($site in $testSites) {
        $result = Test-NetConnection $site.Host -Port $site.Port -InformationLevel Quiet
        $status = if ($result) {"✅ 正常"} else {"❌ 失败"}
        Write-Host "$($site.Name): $status" -ForegroundColor $(if ($result) {"Green"} else {"Red"})
    }
}

Test-NetworkConnectivity
```

**解决方案**:
```powershell
# 1. 检查系统代理设置
netsh winhttp show proxy

# 2. 检查防火墙设置
Get-NetFirewallProfile | Select-Object Name, Enabled

# 3. 刷新DNS
ipconfig /flushdns
```

### 企业代理配置

**症状**:
- 在公司网络环境下连接失败
- 证书验证错误

**配置企业代理**:
```powershell
# 1. 检测系统代理
$proxySettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
if ($proxySettings.ProxyEnable) {
    $proxyServer = $proxySettings.ProxyServer
    Write-Host "检测到系统代理: $proxyServer" -ForegroundColor Yellow
}

# 2. 配置Git代理
if ($proxyServer) {
    git config --global http.proxy "http://$proxyServer"
    git config --global https.proxy "http://$proxyServer"
}

# 3. 配置Scoop代理
scoop config proxy $proxyServer

# 4. 配置PowerShell代理
$env:HTTP_PROXY = "http://$proxyServer"
$env:HTTPS_PROXY = "http://$proxyServer"
```

**NTLM认证代理**:
```powershell
# 如果需要认证
$credential = Get-Credential
$proxyUri = [Uri]"http://proxy.company.com:8080"
$proxy = New-Object System.Net.WebProxy($proxyUri, $true)
$proxy.Credentials = $credential
[System.Net.WebRequest]::DefaultWebProxy = $proxy
```

### SSL/TLS证书问题

**症状**:
- "SSL连接无法建立"
- 证书验证失败

**解决方案**:
```powershell
# 临时禁用SSL验证（仅用于诊断）
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# 更新证书存储
certlm.msc  # 手动导入企业证书

# Git SSL配置
git config --global http.sslBackend schannel  # 使用Windows证书存储
# 或
git config --global http.sslVerify false  # 临时禁用（不推荐生产环境）
```

---

## 🔒 权限和安全问题

### 管理员权限问题

**症状**:
- 符号链接创建失败
- 某些配置无法写入
- "拒绝访问"错误

**权限诊断**:
```powershell
function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    Write-Host "管理员权限: $(if($isAdmin){'✅ 已获得'}else{'⚠️ 未获得（某些功能可能需要）'})" -ForegroundColor $(if($isAdmin){'Green'}else{'Yellow'})
    
    # 检查PowerShell执行策略
    $executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
    $policyOk = $executionPolicy -in @('RemoteSigned', 'Unrestricted', 'Bypass')
    Write-Host "执行策略: $(if($policyOk){'✅ 已配置'}else{'❌ 需要设置'})" -ForegroundColor $(if($policyOk){'Green'}else{'Red'})
    
    return @{
        IsAdmin = $isAdmin
        DevModeEnabled = $devEnabled
    }
}

$privileges = Test-AdminPrivileges
```

**解决方案**:
```powershell
# 方案1: 提升到管理员权限
# 检查并修复PowerShell执行策略
$executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($executionPolicy -eq 'Restricted') {
    Write-Host "设置PowerShell执行策略..." -ForegroundColor Yellow
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Host "✅ 执行策略已设置为RemoteSigned" -ForegroundColor Green
    } catch {
        Write-Host "❌ 设置执行策略失败，请手动执行：" -ForegroundColor Red
        Write-Host "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Cyan
    }
}

# 如果需要管理员权限的操作
if (-not $privileges.IsAdmin) {
    Write-Host "某些高级功能需要管理员权限" -ForegroundColor Yellow
    Write-Host "如需使用，请以管理员身份重新运行PowerShell" -ForegroundColor Cyan
}

# 方案3: 使用复制模式替代符号链接
Write-Host "或者使用复制模式: .\install.ps1 -Mode Copy" -ForegroundColor Cyan
```

### 文件系统权限问题

**症状**:
- 无法写入配置目录
- 备份文件创建失败

**诊断和修复**:
```powershell
function Test-DirectoryPermissions {
    param([string]$Path)
    
    try {
        $testFile = Join-Path $Path "test-permissions.tmp"
        "test" | Out-File $testFile
        Remove-Item $testFile
        Write-Host "✅ $Path - 权限正常" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ $Path - 权限不足: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# 检查关键目录权限
$directories = @(
    $env:USERPROFILE,
    "$env:USERPROFILE\Documents",
    "$env:LOCALAPPDATA",
    "$env:APPDATA"
)

foreach ($dir in $directories) {
    Test-DirectoryPermissions $dir
}
```

**修复权限问题**:
```powershell
# 重置用户目录权限
$userProfile = $env:USERPROFILE
$username = $env:USERNAME

# 使用icacls修复权限（需要管理员权限）
icacls $userProfile /grant "${username}:(OI)(CI)F" /T

# 或使用PowerShell方法
$acl = Get-Acl $userProfile
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($username, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.SetAccessRule($accessRule)
Set-Acl $userProfile $acl
```

---

## 📦 应用程序安装问题

### Scoop安装失败

**症状**:
- "无法下载Scoop"
- "Scoop命令不存在"

**Scoop问题诊断**:
```powershell
function Diagnose-Scoop {
    # 检查Scoop是否存在
    $scoopCmd = Get-Command scoop -ErrorAction SilentlyContinue
    if ($scoopCmd) {
        Write-Host "✅ Scoop已安装: $($scoopCmd.Source)" -ForegroundColor Green
        
        # 检查Scoop状态
        try {
            scoop checkup
        } catch {
            Write-Host "❌ Scoop状态异常" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Scoop未安装" -ForegroundColor Red
    }
    
    # 检查Scoop目录
    $scoopPaths = @(
        $env:SCOOP,
        $env:SCOOP_GLOBAL,
        "$env:USERPROFILE\scoop",
        "C:\ProgramData\scoop"
    )
    
    foreach ($path in $scoopPaths) {
        if ($path -and (Test-Path $path)) {
            Write-Host "✅ 发现Scoop目录: $path" -ForegroundColor Green
        }
    }
}

Diagnose-Scoop
```

**重新安装Scoop**:
```powershell
function Install-ScoopSafely {
    # 1. 清理现有安装
    if ($env:SCOOP -and (Test-Path $env:SCOOP)) {
        Write-Host "清理现有Scoop安装..." -ForegroundColor Yellow
        Remove-Item $env:SCOOP -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # 2. 设置安装目录
    if (-not $env:SCOOP) {
        $env:SCOOP = "$env:USERPROFILE\scoop"
        [Environment]::SetEnvironmentVariable('SCOOP', $env:SCOOP, 'User')
    }
    
    # 3. 下载并安装
    try {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-RestMethod get.scoop.sh | Invoke-Expression
        Write-Host "✅ Scoop安装成功" -ForegroundColor Green
    } catch {
        Write-Host "❌ Scoop安装失败: $($_.Exception.Message)" -ForegroundColor Red
        
        # 尝试备用方法
        try {
            Invoke-WebRequest -useb get.scoop.sh | Invoke-Expression
            Write-Host "✅ 使用备用方法安装成功" -ForegroundColor Green
        } catch {
            Write-Host "❌ 所有安装方法都失败" -ForegroundColor Red
            throw
        }
    }
    
    # 4. 验证安装
    refreshenv
    scoop --version
}

Install-ScoopSafely
```

### 应用程序冲突

**症状**:
- 同一应用有多个版本
- 命令指向错误的版本
- PATH环境变量混乱

**解决应用程序冲突**:
```powershell
function Resolve-AppConflicts {
    param([string]$AppName)
    
    Write-Host "检查 $AppName 的冲突..." -ForegroundColor Yellow
    
    # 查找所有版本
    $commands = Get-Command $AppName -All -ErrorAction SilentlyContinue
    if ($commands) {
        Write-Host "发现以下版本:" -ForegroundColor Cyan
        $commands | ForEach-Object {
            Write-Host "  $($_.Source) (版本: $($_.Version))" -ForegroundColor Gray
        }
        
        # 推荐使用Scoop版本
        $scoopVersion = $commands | Where-Object { $_.Source -like "*scoop*" } | Select-Object -First 1
        if ($scoopVersion) {
            Write-Host "推荐使用Scoop版本: $($scoopVersion.Source)" -ForegroundColor Green
            
            # 重置Scoop应用
            scoop reset $AppName
        }
    } else {
        Write-Host "未找到 $AppName" -ForegroundColor Red
    }
}

# 检查常见冲突应用
$commonApps = @('git', 'python', 'node', 'pwsh')
foreach ($app in $commonApps) {
    Resolve-AppConflicts $app
}
```

### 包损坏或不完整

**症状**:
- 应用程序无法启动
- 缺少依赖文件
- 版本信息异常

**修复损坏的包**:
```powershell
function Repair-ScoopApp {
    param([string]$AppName)
    
    Write-Host "修复 $AppName..." -ForegroundColor Yellow
    
    # 1. 检查应用状态
    scoop status $AppName
    
    # 2. 重新安装应用
    scoop uninstall $AppName
    scoop cache rm $AppName
    scoop install $AppName
    
    # 3. 验证修复结果
    $cmd = Get-Command $AppName -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host "✅ $AppName 修复成功" -ForegroundColor Green
        & $AppName --version
    } else {
        Write-Host "❌ $AppName 修复失败" -ForegroundColor Red
    }
}

# 批量修复所有应用
function Repair-AllApps {
    $installedApps = scoop export | ConvertFrom-Json
    foreach ($app in $installedApps.apps) {
        try {
            Repair-ScoopApp $app.Name
        } catch {
            Write-Host "修复 $($app.Name) 时出错: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
```

---

## ⚙️ 配置文件问题

### 配置文件语法错误

**症状**:
- PowerShell启动时报错
- JSON/TOML解析失败
- 应用程序无法读取配置

**语法检查工具**:
```powershell
function Test-ConfigFile {
    param(
        [string]$FilePath,
        [string]$Type = "Auto"
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "❌ 文件不存在: $FilePath" -ForegroundColor Red
        return $false
    }
    
    $extension = [System.IO.Path]::GetExtension($FilePath)
    if ($Type -eq "Auto") {
        $Type = switch ($extension) {
            ".json" { "JSON" }
            ".toml" { "TOML" }
            ".ps1" { "PowerShell" }
            ".xml" { "XML" }
            default { "Text" }
        }
    }
    
    try {
        switch ($Type) {
            "JSON" {
                Get-Content $FilePath -Raw | ConvertFrom-Json | Out-Null
                Write-Host "✅ JSON语法正确: $FilePath" -ForegroundColor Green
            }
            "PowerShell" {
                $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $FilePath -Raw), [ref]$null)
                Write-Host "✅ PowerShell语法正确: $FilePath" -ForegroundColor Green
            }
            "XML" {
                $xml = New-Object System.Xml.XmlDocument
                $xml.Load($FilePath)
                Write-Host "✅ XML语法正确: $FilePath" -ForegroundColor Green
            }
            "TOML" {
                # TOML验证需要外部工具
                if (Get-Command starship -ErrorAction SilentlyContinue) {
                    starship config 2>$null
                    Write-Host "✅ TOML语法正确: $FilePath" -ForegroundColor Green
                } else {
                    Write-Host "⚠️ 无法验证TOML语法（缺少starship）" -ForegroundColor Yellow
                }
            }
            default {
                Write-Host "⚠️ 未知文件类型: $FilePath" -ForegroundColor Yellow
            }
        }
        return $true
    } catch {
        Write-Host "❌ 语法错误: $FilePath" -ForegroundColor Red
        Write-Host "   错误信息: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# 检查所有配置文件
function Test-AllConfigFiles {
    $configFiles = @(
        "$env:USERPROFILE\.gitconfig",
        "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1",
        "$env:USERPROFILE\.config\starship.toml",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json"
    )
    
    foreach ($file in $configFiles) {
        $matches = Get-ChildItem $file -ErrorAction SilentlyContinue
        foreach ($match in $matches) {
            Test-ConfigFile $match.FullName
        }
    }
}

Test-AllConfigFiles
```

### 配置文件路径错误

**症状**:
- 配置未生效
- 应用程序使用默认配置
- 找不到配置文件

**路径诊断和修复**:
```powershell
function Diagnose-ConfigPaths {
    $configs = @{
        "Git" = @{
            Expected = "$env:USERPROFILE\.gitconfig"
            Command = "git config --list --show-origin"
        }
        "PowerShell" = @{
            Expected = $PROFILE
            Command = "Split-Path $PROFILE"
        }
        "Starship" = @{
            Expected = "$env:USERPROFILE\.config\starship.toml"
            Command = "starship config"
        }
        "WindowsTerminal" = @{
            Expected = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json"
            Command = "Get-ChildItem '$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json'"
        }
    }
    
    foreach ($name in $configs.Keys) {
        $config = $configs[$name]
        Write-Host "检查 $name 配置:" -ForegroundColor Cyan
        
        # 检查预期路径
        $expectedFiles = Get-ChildItem $config.Expected -ErrorAction SilentlyContinue
        if ($expectedFiles) {
            foreach ($file in $expectedFiles) {
                Write-Host "  ✅ 找到: $($file.FullName)" -ForegroundColor Green
            }
        } else {
            Write-Host "  ❌ 未找到: $($config.Expected)" -ForegroundColor Red
        }
        
        # 执行检测命令
        try {
            $result = Invoke-Expression $config.Command 2>$null
            if ($result) {
                Write-Host "  📍 实际位置: $result" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  ⚠️ 无法检测实际位置" -ForegroundColor Yellow
        }
        
        Write-Host ""
    }
}

Diagnose-ConfigPaths
```

### 配置文件编码问题

**症状**:
- 中文字符乱码
- 特殊字符显示异常
- 配置解析失败

**编码问题修复**:
```powershell
function Fix-ConfigEncoding {
    param(
        [string]$FilePath,
        [string]$TargetEncoding = "UTF8"
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "文件不存在: $FilePath" -ForegroundColor Red
        return
    }
    
    # 检测当前编码
    $bytes = Get-Content $FilePath -AsByteStream -TotalCount 4
    $encoding = "Unknown"
    
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -an