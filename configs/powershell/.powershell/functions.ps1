# ~/.powershell/functions.ps1
# Core utility functions

# Git quick operations
function ngc {
    param([string]$msg = "update")
    git add .
    git commit -m $msg
    git push
}

function gst { git status --short }
function glog { git log --oneline -10 }

# Directory operations
function mkcd {
    param([string]$path)
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    Set-Location $path
}

function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function ~ { Set-Location $env:USERPROFILE }

# System management
function sys-update {
    Write-Host "系统更新开始..." -ForegroundColor Cyan

    # Scoop更新
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "正在更新 Scoop 包..." -ForegroundColor Yellow
        scoop update *
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Scoop 包更新完成" -ForegroundColor Green
        } else {
            Write-Warning "Scoop 更新过程中出现问题"
        }
    } else {
        Write-Host "⚠ Scoop 未安装，跳过" -ForegroundColor Gray
    }

    # Winget更新
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "正在更新 Winget 包..." -ForegroundColor Yellow
        $wingetResult = winget upgrade --all --silent 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Winget 包更新完成" -ForegroundColor Green
        } elseif ($wingetResult -like "*找不到与输入条件匹配*" -or $wingetResult -like "*No applicable updates*") {
            Write-Host "✓ Winget 包都是最新版本" -ForegroundColor Green
        } else {
            Write-Warning "Winget 更新过程中出现问题"
        }
    } else {
        Write-Host "⚠ Winget 未安装，跳过" -ForegroundColor Gray
    }

    Write-Host "系统更新完成！" -ForegroundColor Green
}

function swp {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop cleanup *
        scoop cache rm *
    }
}

# Utility tools
function which { param($cmd) (Get-Command $cmd).Source }
function reload { . $PROFILE }
function edit-profile { code $PROFILE }

# Quick system information
function sysinfo {
    $os = (Get-CimInstance Win32_OperatingSystem).Caption
    $cpu = (Get-CimInstance Win32_Processor).Name
    $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)

    Write-Host "System Information" -ForegroundColor Cyan
    Write-Host "OS: $os" -ForegroundColor White
    Write-Host "CPU: $cpu" -ForegroundColor White
    Write-Host "RAM: ${ram}GB" -ForegroundColor White
}

# Configuration information
function config-info {
    Write-Host "Dotfiles Configuration Information" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host "Configuration Directory: $(Split-Path $PROFILE -Parent)" -ForegroundColor White
    Write-Host "Profile Mode: Standard" -ForegroundColor White
    Write-Host ""
    Write-Host "Core Commands:" -ForegroundColor Yellow
    Write-Host "  Git: ngc, gst, glog" -ForegroundColor Gray
    Write-Host "  System: sys-update, swp, sysinfo" -ForegroundColor Gray
    Write-Host "  Navigation: mkcd, .., ..., ~" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Usage Help: Get-Help <command-name>" -ForegroundColor Green
}

# Configuration performance analysis
function profile-perf {
    Write-Host "PowerShell Configuration Performance Report" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan

    # Intelligent configuration directory detection
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

    Write-Host "Configuration File Analysis:" -ForegroundColor Yellow
    Write-Host "  Main Profile: $profilePath" -ForegroundColor Gray
    Write-Host "  Config Directory: $configDir" -ForegroundColor Gray
    Write-Host ""

    # Check each configuration file
    $configFiles = @("functions", "aliases", "history", "keybindings", "tools", "theme", "extra")
    $totalSize = 0

    Write-Host "Configuration File Status:" -ForegroundColor Yellow
    foreach ($config in $configFiles) {
        $configPath = Join-Path $configDir "$config.ps1"
        if (Test-Path $configPath) {
            $size = (Get-Item $configPath).Length
            $totalSize += $size
            $sizeKB = [math]::Round($size / 1KB, 2)
            Write-Host "  OK $config.ps1 (${sizeKB}KB)" -ForegroundColor Green
        } else {
            Write-Host "  ERROR $config.ps1 (missing)" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "Performance Metrics:" -ForegroundColor Yellow
    Write-Host "  Total Config Size: $([math]::Round($totalSize / 1KB, 2))KB" -ForegroundColor White
    Write-Host "  Profile Mode: Standard" -ForegroundColor White

    # Module loading status
    $loadedModules = Get-Module | Where-Object { $_.ModuleType -eq 'Script' -or $_.Name -like '*profile*' }
    Write-Host "  Loaded Modules: $($loadedModules.Count)" -ForegroundColor White

    # Startup suggestions
    Write-Host ""
    Write-Host "Performance Optimization Suggestions:" -ForegroundColor Green
    if ($totalSize -gt 50KB) {
        Write-Host "  • Configuration files are large, consider trimming unnecessary features" -ForegroundColor Gray
    }
    Write-Host "  • Use 'reload' to reload configuration" -ForegroundColor Gray
}

# Missing utility functions
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

        # Format file size
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
        # If no command specified, start new PowerShell session as administrator
        Start-Process pwsh -Verb RunAs
    } else {
        # Run specified command as administrator
        $argumentList = if ($Arguments.Count -gt 0) { $Arguments -join ' ' } else { '' }
        Start-Process $Command -ArgumentList $argumentList -Verb RunAs
    }
}

# ============================================================================
# 增强的Git工作流函数
# ============================================================================

# 改进的ngc函数 - 带确认和状态检查
function ngc-enhanced {
    param(
        [string]$msg = "update",
        [switch]$NoPush
    )
    
    # 检查是否有未跟踪或修改的文件
    $status = git status --short 2>$null
    if (-not $status) {
        Write-Host "没有可提交的更改" -ForegroundColor Yellow
        return
    }
    
    # 显示将要提交的文件
    Write-Host "`n将提交以下文件：" -ForegroundColor Cyan
    git status --short
    
    # 添加所有更改
    git add .
    
    # 提交
    git commit -m $msg
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "提交失败"
        return
    }
    
    Write-Host "✓ 提交成功" -ForegroundColor Green
    
    # 推送（除非指定 -NoPush）
    if (-not $NoPush) {
        git push
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ 成功推送到远程仓库" -ForegroundColor Green
        } else {
            Write-Error "推送失败"
        }
    }
}

# 新增实用Git函数
function gaa { git add --all }
function gcm { param($msg) git commit -m $msg }
function gp { git push }
function gpl { git pull }
function gco { param($branch) git checkout $branch }
function gcb { param($branch) git checkout -b $branch }
function gd { git diff }
function gds { git diff --staged }
function gbr { git branch }
function gbd { param($branch) git branch -d $branch }

# ============================================================================
# 实用工具函数
# ============================================================================

# 快速基准测试
function bench {
    <#
    .SYNOPSIS
    对命令或脚本块进行性能基准测试
    
    .PARAMETER Command
    要测试的脚本块
    
    .PARAMETER Count
    运行次数（默认10次）
    
    .EXAMPLE
    bench { Get-ChildItem -Recurse } -Count 5
    #>
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Command, 
        [int]$Count = 10
    )
    
    if (Get-Command hyperfine -ErrorAction SilentlyContinue) {
        $cmd = $Command.ToString()
        hyperfine --warmup 3 --runs $Count "pwsh -NoProfile -Command `"$cmd`""
    } else {
        Write-Host "运行基准测试..." -ForegroundColor Cyan
        $times = @()
        for ($i = 1; $i -le $Count; $i++) {
            $result = Measure-Command { & $Command }
            $times += $result.TotalMilliseconds
            Write-Host "运行 $i/$Count`: $([math]::Round($result.TotalMilliseconds, 2))ms" -ForegroundColor Gray
        }
        
        $avg = ($times | Measure-Object -Average).Average
        $min = ($times | Measure-Object -Minimum).Minimum
        $max = ($times | Measure-Object -Maximum).Maximum
        
        Write-Host "`n结果:" -ForegroundColor Yellow
        Write-Host "  平均: $([math]::Round($avg, 2))ms" -ForegroundColor Green
        Write-Host "  最小: $([math]::Round($min, 2))ms" -ForegroundColor Cyan
        Write-Host "  最大: $([math]::Round($max, 2))ms" -ForegroundColor Cyan
    }
}

# 查找大文件
function find-large {
    <#
    .SYNOPSIS
    查找大于指定大小的文件
    
    .PARAMETER SizeMB
    文件大小阈值（MB，默认100MB）
    
    .PARAMETER Path
    搜索路径（默认当前目录）
    
    .EXAMPLE
    find-large -SizeMB 50
    find-large -SizeMB 200 -Path "C:\Users"
    #>
    param(
        [int]$SizeMB = 100,
        [string]$Path = "."
    )
    
    $size = $SizeMB * 1MB
    Write-Host "正在搜索大于 ${SizeMB}MB 的文件..." -ForegroundColor Cyan
    
    Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | 
        Where-Object { $_.Length -gt $size } | 
        Sort-Object Length -Descending |
        Select-Object @{N='大小(MB)';E={[math]::Round($_.Length/1MB,2)}}, FullName |
        Format-Table -AutoSize
}

# 快速HTTP服务器
function serve {
    <#
    .SYNOPSIS
    在当前目录启动HTTP服务器
    
    .PARAMETER Port
    端口号（默认8000）
    
    .EXAMPLE
    serve
    serve -Port 3000
    #>
    param([int]$Port = 8000)
    
    if (Get-Command python -ErrorAction SilentlyContinue) {
        Write-Host "启动HTTP服务器: http://localhost:$Port" -ForegroundColor Green
        Write-Host "按 Ctrl+C 停止服务器" -ForegroundColor Yellow
        python -m http.server $Port
    } else {
        Write-Error "Python未安装，无法启动HTTP服务器"
    }
}

# 快速查看JSON文件
function json {
    <#
    .SYNOPSIS
    格式化显示JSON文件或字符串
    
    .PARAMETER InputObject
    JSON文件路径或JSON字符串
    
    .EXAMPLE
    json config.json
    json '{"name":"test"}'
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $InputObject
    )
    
    if (Test-Path $InputObject -ErrorAction SilentlyContinue) {
        # 输入是文件路径
        $content = Get-Content $InputObject -Raw
    } else {
        # 输入是JSON字符串
        $content = $InputObject
    }
    
    try {
        $content | ConvertFrom-Json | ConvertTo-Json -Depth 10 | 
            ForEach-Object { 
                if (Get-Command bat -ErrorAction SilentlyContinue) {
                    $_ | bat -l json
                } else {
                    $_
                }
            }
    } catch {
        Write-Error "无效的JSON格式: $($_.Exception.Message)"
    }
}

# 快速搜索文件内容
function search {
    <#
    .SYNOPSIS
    使用ripgrep搜索文件内容
    
    .PARAMETER Pattern
    搜索模式
    
    .PARAMETER Path
    搜索路径（默认当前目录）
    
    .EXAMPLE
    search "TODO"
    search "function.*test" -Path "src/"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,
        [string]$Path = "."
    )
    
    if (Get-Command rg -ErrorAction SilentlyContinue) {
        rg --color=always --heading --line-number $Pattern $Path
    } else {
        Write-Warning "ripgrep (rg) 未安装，使用Select-String"
        Get-ChildItem -Path $Path -Recurse -File | 
            Select-String -Pattern $Pattern |
            Format-Table -AutoSize
    }
}

# 清理系统临时文件
function cleanup-temp {
    <#
    .SYNOPSIS
    清理Windows临时文件和缓存
    
    .PARAMETER Force
    跳过确认提示
    
    .EXAMPLE
    cleanup-temp
    cleanup-temp -Force
    #>
    param([switch]$Force)
    
    if (-not $Force) {
        $confirm = Read-Host "确认清理临时文件? (y/N)"
        if ($confirm -ne 'y') {
            Write-Host "已取消" -ForegroundColor Yellow
            return
        }
    }
    
    $paths = @(
        "$env:TEMP\*",
        "$env:USERPROFILE\AppData\Local\Temp\*"
    )
    
    foreach ($path in $paths) {
        Write-Host "清理: $path" -ForegroundColor Cyan
        try {
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "无法删除某些文件: $($_.Exception.Message)"
        }
    }
    
    Write-Host "✓ 临时文件清理完成" -ForegroundColor Green
}
