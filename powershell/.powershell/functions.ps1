# ~/.powershell/functions.ps1
# 核心实用函数 

# Git 快速操作
function ngc { 
    param([string]$msg = "update")
    git add . && git commit -m $msg && git push
}

function gst { git status --short }
function glog { git log --oneline -10 }

# 目录操作
function mkcd { 
    param([string]$path)
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    Set-Location $path
}

function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function ~ { Set-Location $env:USERPROFILE }

# 系统管理
function sys-update {
    if (Get-Command scoop -ErrorAction SilentlyContinue) { 
        scoop update *
        if ($LASTEXITCODE -ne 0) { return }
    }
    if (Get-Command winget -ErrorAction SilentlyContinue) { 
        winget upgrade --all
        if ($LASTEXITCODE -ne 0) { return }
    }
}

function swp { 
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop cleanup * && scoop cache rm *
    }
}

# 实用工具
function which { param($cmd) (Get-Command $cmd).Source }
function reload { . $PROFILE }
function edit-profile { code $PROFILE }

# 快速信息
function sysinfo {
    $os = (Get-CimInstance Win32_OperatingSystem).Caption
    $cpu = (Get-CimInstance Win32_Processor).Name
    $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    
    Write-Host "💻 System Info" -ForegroundColor Cyan
    Write-Host "OS: $os" -ForegroundColor White
    Write-Host "CPU: $cpu" -ForegroundColor White
    Write-Host "RAM: ${ram}GB" -ForegroundColor White
}

# 配置信息
function config-info {
    Write-Host "🔧 Dotfiles 配置信息" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Write-Host "📁 配置目录: $(Split-Path $PROFILE -Parent)" -ForegroundColor White
    Write-Host "⚡ 快速模式: $(if ($env:POWERSHELL_FAST_MODE -eq '1') { '启用' } else { '禁用' })" -ForegroundColor White
    Write-Host ""
    Write-Host "🚀 核心命令:" -ForegroundColor Yellow
    Write-Host "  Git: ngc, gst, glog" -ForegroundColor Gray
    Write-Host "  系统: sys-update, swp, sysinfo" -ForegroundColor Gray
    Write-Host "  导航: mkcd, .., ..., ~" -ForegroundColor Gray
    Write-Host "  代理: px [system|clash|v2ray|singbox|off], px-auto, px-test" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📚 使用帮助: Get-Help <命令名>" -ForegroundColor Green
}

# 配置性能分析
function profile-perf {
    Write-Host "⚡ PowerShell 配置性能报告" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    
    # 智能检测配置目录
    $configDir = if ($env:USERPROFILE -and (Test-Path (Join-Path $env:USERPROFILE ".powershell"))) {
        Join-Path $env:USERPROFILE ".powershell"
    } elseif (Test-Path ".\.powershell") {
        Resolve-Path ".\.powershell"
    } elseif (Test-Path ".\powershell\.powershell") {
        Resolve-Path ".\powershell\.powershell"
    } else {
        Split-Path $PROFILE -Parent
    }
    
    $profilePath = if (Test-Path (Join-Path (Split-Path $configDir -Parent) "Microsoft.PowerShell_profile.ps1")) {
        Join-Path (Split-Path $configDir -Parent) "Microsoft.PowerShell_profile.ps1"
    } else {
        $PROFILE
    }
    
    Write-Host "📊 配置文件分析:" -ForegroundColor Yellow
    Write-Host "  主配置: $profilePath" -ForegroundColor Gray
    Write-Host "  配置目录: $configDir" -ForegroundColor Gray
    Write-Host ""
    
    # 检查各个配置文件
    $configFiles = @("functions", "aliases", "history", "keybindings", "tools", "theme", "extra")
    $totalSize = 0
    
    Write-Host "📁 配置文件状态:" -ForegroundColor Yellow
    foreach ($config in $configFiles) {
        $configPath = Join-Path $configDir "$config.ps1"
        if (Test-Path $configPath) {
            $size = (Get-Item $configPath).Length
            $totalSize += $size
            $sizeKB = [math]::Round($size / 1KB, 2)
            Write-Host "  ✅ $config.ps1 (${sizeKB}KB)" -ForegroundColor Green
        } else {
            Write-Host "  ❌ $config.ps1 (缺失)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "📈 性能指标:" -ForegroundColor Yellow
    Write-Host "  总配置大小: $([math]::Round($totalSize / 1KB, 2))KB" -ForegroundColor White
    Write-Host "  快速模式: $(if ($env:POWERSHELL_FAST_MODE -eq '1') { '启用 ⚡' } else { '禁用' })" -ForegroundColor White
    
    # 模块加载状态
    $loadedModules = Get-Module | Where-Object { $_.ModuleType -eq 'Script' -or $_.Name -like '*profile*' }
    Write-Host "  已加载模块: $($loadedModules.Count)" -ForegroundColor White
    
    # 启动建议
    Write-Host ""
    Write-Host "💡 性能优化建议:" -ForegroundColor Green
    if ($env:POWERSHELL_FAST_MODE -ne '1') {
        Write-Host "  • 启用快速模式: `$env:POWERSHELL_FAST_MODE = '1'" -ForegroundColor Gray
    }
    if ($totalSize -gt 50KB) {
        Write-Host "  • 配置文件较大，考虑精简不必要的功能" -ForegroundColor Gray
    }
    Write-Host "  • 使用 'reload' 重新加载配置" -ForegroundColor Gray
}

# 缺失的实用函数
function New-Directory {
    param([string]$Path)
    New-Item -ItemType Directory -Path $Path -Force
}

function Get-FileSize {
    param([string]$Path)
    if (Test-Path $Path) {
        $item = Get-Item $Path
        if ($item.PSIsContainer) {
            $size = (Get-ChildItem $Path -Recurse -File | Measure-Object -Property Length -Sum).Sum
        } else {
            $size = $item.Length
        }
        
        # 格式化文件大小
        if ($size -gt 1GB) {
            "{0:N2} GB" -f ($size / 1GB)
        } elseif ($size -gt 1MB) {
            "{0:N2} MB" -f ($size / 1MB)
        } elseif ($size -gt 1KB) {
            "{0:N2} KB" -f ($size / 1KB)
        } else {
            "$size bytes"
        }
    } else {
        Write-Error "Path not found: $Path"
    }
}

function Start-Elevated {
    param(
        [string]$Command,
        [string[]]$Arguments = @()
    )
    
    if (-not $Command) {
        # 如果没有指定命令，以管理员身份启动新的 PowerShell 会话
        Start-Process pwsh -Verb RunAs
    } else {
        # 以管理员身份运行指定命令
        $argumentList = if ($Arguments.Count -gt 0) { $Arguments -join ' ' } else { '' }
        Start-Process $Command -ArgumentList $argumentList -Verb RunAs
    }
}