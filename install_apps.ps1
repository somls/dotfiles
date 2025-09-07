<#
.SYNOPSIS
    应用安装脚本 - 使用 Scoop 安装推荐软件包，支持交互式路径选择

.DESCRIPTION
    这个脚本提供了自动化的软件包安装功能，包括：
    - 自动检测并安装 Scoop 包管理器
    - 交互式选择 Scoop 安装路径
    - 分类管理软件包（Essential, Development, SystemTools, Editors）
    - 智能检测已安装软件，避免重复安装
    - 批量更新已安装软件包
    - 预览模式支持

.PARAMETER Category
    指定要安装的软件包类别，可选值：
    - Essential: 基础工具（git, pwsh, starship, 7zip, curl, sudo, jq）
    - Development: 核心开发工具（nodejs, python, gh, ripgrep, bat, fd, fzf, zoxide）
    - VersionManagers: 版本管理器（fnm, pyenv-win）
    - ModernTools: 现代开发工具（prettier, shellcheck）
    - FileTools: 文件管理工具（eza, tre）
    - SystemTools: 系统监控工具（btop, dust, procs）
    - NetworkTools: 网络工具（bandwhich）
    - ProductivityTools: 效率工具（just, choose, duf）
    - GitEnhanced: Git 增强工具（delta, lazygit）
    - Optional: 可选专业工具（sd, tokei, hyperfine, jid, tealdeer）
    - Editors: 编辑器（neovim）
    默认安装 Essential 类别

.PARAMETER Profile
    使用预定义的用户配置文件，可选值：
    - minimalist: 极简配置，仅核心工具
    - developer: 开发者配置，完整开发环境 
    - poweruser: 高级用户配置，包含所有工具
    - researcher: 研究配置，专注数据处理
    - sysadmin: 系统管理员配置，专注系统监控
    - help/list: 显示所有可用配置文件
    使用 -Profile 会覆盖 -Category 参数

.PARAMETER DryRun
    预览模式，显示将要执行的操作但不实际安装

.PARAMETER Update
    更新已安装的软件包

.PARAMETER ScoopDir
    指定 Scoop 的安装目录，跳过交互式选择

.PARAMETER Interactive
    启用交互式安装模式（默认启用）
    设置为 $false 可跳过所有交互提示

.EXAMPLE
    .\install_apps.ps1
    使用默认设置安装基础软件包，交互式选择 Scoop 路径

.EXAMPLE
    .\install_apps.ps1 -Profile developer
    使用开发者配置文件安装完整开发环境

.EXAMPLE
    .\install_apps.ps1 -Profile list
    显示所有可用的用户配置文件

.EXAMPLE
    .\install_apps.ps1 -Profile poweruser -DryRun
    预览高级用户配置的安装内容

.EXAMPLE
    .\install_apps.ps1 -Category Essential,Development,VersionManagers
    安装基础、开发工具和版本管理器三个类别的软件包

.EXAMPLE
    .\install_apps.ps1 -Category ModernTools,FileTools -DryRun
    预览模式查看现代工具和文件工具的安装

.EXAMPLE
    .\install_apps.ps1 -ScoopDir "D:\Tools\Scoop"
    指定 Scoop 安装到 D:\Tools\Scoop 目录

.EXAMPLE
    .\install_apps.ps1 -DryRun
    预览模式，查看将要安装的软件包

.EXAMPLE
    .\install_apps.ps1 -Update
    更新已安装的软件包

.EXAMPLE
    .\install_apps.ps1 -Interactive:$false
    非交互模式，使用默认设置

.NOTES
    - 需要 PowerShell 5.1+ 版本
    - 首次安装 Scoop 时会自动设置执行策略
    - 自定义安装路径需要手动设置永久环境变量以保持设置
    - 建议在安装完成后重启终端

.LINK
    https://scoop.sh/
#>

[CmdletBinding()]
param(
    [switch]$DryRun,       # 预览模式，不实际安装
    [string[]]$Category = @('Essential'),   # 安装指定类别
    [string]$Profile,      # 使用预定义的用户配置文件
    [switch]$Update,       # 更新已安装的包
    [string]$ScoopDir,     # 自定义 Scoop 安装目录
    [switch]$Interactive = $true  # 交互式安装（默认启用）
)

# 推荐软件包配置 - 重组优化版
$PackageCategories = @{
    Essential = @(
        'git',
        'pwsh',
        'starship',
        '7zip',
        'curl',
        'sudo',
        'jq'
    )
    Development = @(
        'nodejs',
        'python',
        'gh',
        'ripgrep',
        'bat',
        'fd',
        'fzf',
        'zoxide'
    )
    VersionManagers = @(
        'fnm',         # 快速 Node.js 版本管理器
        'pyenv-win'    # Python 版本管理器
    )
    ModernTools = @(
        'prettier',    # 代码格式化工具
        'shellcheck'   # Shell 脚本检查器
    )
    FileTools = @(
        'eza',         # 现代 ls 替代
        'tre'          # 现代 tree 命令
    )
    SystemTools = @(
        'btop',
        'dust',
        'procs'
    )
    NetworkTools = @(
        'bandwhich'    # 网络使用监控
    )
    Optional = @(
        'sd',          # 现代 sed 替代
        'tokei',       # 代码行数统计
        'hyperfine',   # 基准测试工具
        'jid',         # JSON 增量解析器
        'tealdeer'     # 删除 tldr - tealdeer 更快，无 Node.js 依赖
    )
    ProductivityTools = @(
        'just',        # 现代命令运行器，Makefile 替代
        'choose',      # 现代 cut/awk 替代
        'duf'          # 现代 df 替代，磁盘使用可视化
    )
    GitEnhanced = @(
        'delta',       # Git diff 美化（从 Development 移过来）
        'lazygit'      # 可视化 Git TUI 界面
    )
    Editors = @(
        'neovim'       # 现代编辑器
    )
}

function Write-Status {
    param([string]$Message, [string]$Type = 'Info')
    $color = switch ($Type) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        default { 'Cyan' }
    }
    $icon = switch ($Type) {
        'Success' { '✅' }
        'Warning' { '⚠️' }
        'Error' { '❌' }
        default { 'ℹ️' }
    }
    Write-Host "$icon $Message" -ForegroundColor $color
}

function Get-UserProfile {
    <#
    .SYNOPSIS
        加载用户配置文件
    #>
    param(
        [string]$ProfileName,
        [string]$ConfigPath = "$PSScriptRoot\config\user-profiles.json"
    )
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Status "用户配置文件不存在: $ConfigPath" 'Warning'
        return $null
    }
    
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        if ($ProfileName -and $config.profiles.PSObject.Properties.Name -contains $ProfileName) {
            return $config.profiles.$ProfileName
        } elseif (-not $ProfileName -and $config.defaultProfile) {
            Write-Status "使用默认配置文件: $($config.defaultProfile)" 'Info'
            return $config.profiles.($config.defaultProfile)
        } else {
            Write-Status "配置文件不存在或未指定: $ProfileName" 'Warning'
            return $null
        }
    } catch {
        Write-Status "解析用户配置文件失败: $($_.Exception.Message)" 'Error'
        return $null
    }
}

function Show-AvailableProfiles {
    <#
    .SYNOPSIS
        显示可用的用户配置文件
    #>
    param(
        [string]$ConfigPath = "$PSScriptRoot\config\user-profiles.json"
    )
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Status "用户配置文件不存在，将使用默认分类" 'Warning'
        return
    }
    
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        Write-Host "`n🎯 可用的用户配置文件:" -ForegroundColor Cyan
        Write-Host "=" * 50 -ForegroundColor Cyan
        
        foreach ($profileName in $config.profiles.PSObject.Properties.Name) {
            $profile = $config.profiles.$profileName
            $isDefault = $profileName -eq $config.defaultProfile
            $marker = if ($isDefault) { " (默认)" } else { "" }
            
            Write-Host "`n📋 $($profile.name)$marker" -ForegroundColor Yellow
            Write-Host "   描述: $($profile.description)" -ForegroundColor Gray
            Write-Host "   包含: $($profile.categories -join ', ')" -ForegroundColor Green
            Write-Host "   预计时间: $($profile.estimatedInstallTime)" -ForegroundColor Blue
            Write-Host "   磁盘空间: $($profile.diskSpace)" -ForegroundColor Magenta
        }
        
        Write-Host "`n使用方法: .\install_apps.ps1 -Profile <配置文件名>" -ForegroundColor Cyan
    } catch {
        Write-Status "显示配置文件失败: $($_.Exception.Message)" 'Error'
    }
}

function Get-ScoopInstallPath {
    <#
    .SYNOPSIS
        交互式获取 Scoop 安装路径
    #>
    param(
        [string]$DefaultPath = "$env:USERPROFILE\scoop",
        [switch]$NonInteractive
    )

    if ($NonInteractive -or -not $Interactive) {
        return $DefaultPath
    }

    Write-Host "`n🛠️ Scoop 安装路径设置" -ForegroundColor Cyan
    Write-Host "=" * 40 -ForegroundColor Cyan

    $defaultDisplay = $DefaultPath -replace [regex]::Escape($env:USERPROFILE), "~"
    Write-Host "默认安装路径: " -NoNewline -ForegroundColor Gray
    Write-Host $defaultDisplay -ForegroundColor Yellow

    Write-Host "`n选择安装方式:" -ForegroundColor White
    Write-Host "1. 使用默认路径 ($defaultDisplay)" -ForegroundColor Green
    Write-Host "2. 自定义安装路径" -ForegroundColor Cyan
    Write-Host "3. 取消安装" -ForegroundColor Red

    while ($true) {
        $choice = Read-Host "`n请选择 [1-3]"

        switch ($choice) {
            '1' {
                Write-Status "选择默认路径: $defaultDisplay" 'Success'
                return $DefaultPath
            }
            '2' {
                Write-Host "`n请输入 Scoop 安装路径:" -ForegroundColor Cyan
                Write-Host "示例: D:\Tools\Scoop, C:\scoop" -ForegroundColor Gray

                while ($true) {
                    $customPath = Read-Host "安装路径"

                    if ([string]::IsNullOrWhiteSpace($customPath)) {
                        Write-Status "路径不能为空，请重新输入" 'Warning'
                        continue
                    }

                    # 扩展环境变量
                    $expandedPath = [Environment]::ExpandEnvironmentVariables($customPath)

                    # 验证路径格式
                    try {
                        $testPath = [System.IO.Path]::GetFullPath($expandedPath)

                        # 检查父目录是否存在
                        $parentDir = Split-Path $testPath -Parent
                        if (-not (Test-Path $parentDir)) {
                            $createParent = Read-Host "父目录 '$parentDir' 不存在，是否创建? (y/N)"
                            if ($createParent -match '^[yY]') {
                                New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
                                Write-Status "已创建父目录: $parentDir" 'Success'
                            } else {
                                Write-Status "请选择其他路径" 'Warning'
                                continue
                            }
                        }

                        Write-Status "选择自定义路径: $testPath" 'Success'
                        return $testPath

                    } catch {
                        Write-Status "无效的路径格式，请重新输入" 'Error'
                        continue
                    }
                }
            }
            '3' {
                Write-Status "用户取消安装" 'Warning'
                exit 0
            }
            default {
                Write-Status "请输入 1, 2 或 3" 'Warning'
            }
        }
    }
}

# === 用户配置文件处理 ===
if ($Profile -eq 'help' -or $Profile -eq 'list') {
    Show-AvailableProfiles
    exit 0
}

# 如果指定了配置文件，加载配置
if ($Profile) {
    Write-Host "`n🎯 正在加载用户配置文件: $Profile" -ForegroundColor Cyan
    $userProfile = Get-UserProfile -ProfileName $Profile
    
    if ($userProfile) {
        # 使用配置文件中的类别覆盖命令行参数
        $Category = $userProfile.categories
        Write-Status "已加载配置文件: $($userProfile.name)" 'Success'
        Write-Status "包含类别: $($Category -join ', ')" 'Info'
        
        # 应用配置文件设置
        if ($userProfile.settings.verboseOutput -eq $false) {
            $VerbosePreference = 'SilentlyContinue'
        }
    } else {
        Write-Status "无法加载配置文件 '$Profile'，将使用默认设置" 'Warning'
        Write-Host "可用的配置文件:"
        Show-AvailableProfiles
        exit 1
    }
}

# === Scoop 安装检查开始 ===

# 检查 Scoop 是否安装
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Status "Scoop 未安装，正在安装..." 'Warning'

    # 获取安装路径
    $installPath = if ($ScoopDir) {
        Write-Status "使用指定的 Scoop 安装路径: $ScoopDir" 'Info'
        $ScoopDir
    } else {
        Get-ScoopInstallPath -NonInteractive:(-not $Interactive)
    }

    # 设置 Scoop 安装目录环境变量
    if ($installPath -ne "$env:USERPROFILE\scoop") {
        $env:SCOOP = $installPath
        Write-Status "设置 SCOOP 环境变量: $installPath" 'Info'
    }

    try {
        if ($DryRun) {
            Write-Status "预览: 将安装 Scoop 到 $installPath" 'Info'
            $cacheDir = if ($env:SCOOP_CACHE) { $env:SCOOP_CACHE } else { Join-Path $installPath "cache" }
            Write-Status "预览: 缓存目录为 $cacheDir" 'Info'
        } else {
            Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Invoke-RestMethod get.scoop.sh | Invoke-Expression

            Write-Status "Scoop 安装成功" 'Success'
            Write-Status "安装位置: $installPath" 'Success'

            # 提示用户关于环境变量持久化
            if ($env:SCOOP -and $env:SCOOP -ne "$env:USERPROFILE\scoop") {
                Write-Host "`n💡 重要提示:" -ForegroundColor Yellow
                Write-Host "为了在重启后保持自定义路径，请设置永久环境变量:" -ForegroundColor Gray
                Write-Host "  [Environment]::SetEnvironmentVariable('SCOOP', '$env:SCOOP', 'User')" -ForegroundColor DarkGray
            }
        }
    } catch {
        Write-Status "Scoop 安装失败: $($_.Exception.Message)" 'Error'
        Write-Host "请手动安装 Scoop: https://scoop.sh/" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "📦 应用安装器" -ForegroundColor Cyan
Write-Host "=" * 30 -ForegroundColor Cyan

# 确定要安装的包
$packagesToInstall = @()
foreach ($cat in $Category) {
    if ($PackageCategories.ContainsKey($cat)) {
        $packagesToInstall += $PackageCategories[$cat]
        Write-Status "选择类别: $cat" 'Info'
    } else {
        Write-Status "未知类别: $cat，可用类别: $($PackageCategories.Keys -join ', ')" 'Warning'
    }
}

if ($packagesToInstall.Count -eq 0) {
    Write-Status "没有选择任何软件包" 'Warning'
    exit 0
}

# 获取已安装的包
Write-Status "检查已安装软件..." 'Info'
try {
    $installedPackages = @(scoop list 6>$null | ForEach-Object {
        if ($_ -match '^(\S+)') { $matches[1] }
    })
} catch {
    $installedPackages = @()
}

Write-Host "`n📋 安装计划:" -ForegroundColor Yellow
$toInstall = @()
$toUpdate = @()

foreach ($package in $packagesToInstall) {
    if ($installedPackages -contains $package) {
        $toUpdate += $package
        Write-Host "  ⏭️ $package (已安装)" -ForegroundColor Gray
    } else {
        $toInstall += $package
        Write-Host "  📦 $package (将安装)" -ForegroundColor Green
    }
}

# 确认安装
if ($toInstall.Count -gt 0) {
    Write-Host "`n即将安装 $($toInstall.Count) 个新软件包" -ForegroundColor Yellow
    if (-not $DryRun -and $Interactive) {
        $response = Read-Host "继续安装？(Y/n)"
        if ($response -match '^[nN]') {
            Write-Status "用户取消安装" 'Info'
            exit 0
        }
    }
}

# 更新已安装的包
if ($Update -and $toUpdate.Count -gt 0) {
    Write-Host "`n🔄 更新已安装软件..." -ForegroundColor Yellow
    if ($DryRun) {
        Write-Status "预览: 将更新 $($toUpdate -join ', ')" 'Info'
    } else {
        scoop update $toUpdate
        Write-Status "更新完成" 'Success'
    }
}

# 安装新软件包
if ($toInstall.Count -gt 0) {
    Write-Host "`n📦 开始安装..." -ForegroundColor Yellow

    if ($DryRun) {
        Write-Status "预览: 将安装 $($toInstall -join ', ')" 'Info'
    } else {
        $successCount = 0
        foreach ($package in $toInstall) {
            Write-Status "正在安装 $package..." 'Info'

            try {
                scoop install $package
                if ($LASTEXITCODE -eq 0) {
                    Write-Status "$package 安装成功" 'Success'
                    $successCount++
                } else {
                    Write-Status "$package 安装失败" 'Error'
                }
            } catch {
                Write-Status "$package 安装异常: $($_.Exception.Message)" 'Error'
            }
        }

        Write-Host "`n✅ 安装完成: $successCount/$($toInstall.Count) 个软件包" -ForegroundColor Green

        if ($successCount -gt 0) {
            Write-Host "`n💡 后续步骤:" -ForegroundColor Yellow
            Write-Host "• 重启终端以应用新工具" -ForegroundColor Gray
            Write-Host "• 运行 .\install.ps1 配置应用设置" -ForegroundColor Gray
            Write-Host "• 运行 .\health-check.ps1 验证配置" -ForegroundColor Gray

            # 如果使用了自定义路径，提醒用户设置永久环境变量
            if ($env:SCOOP -and $env:SCOOP -ne "$env:USERPROFILE\scoop") {
                Write-Host "`n🔧 自定义路径提醒:" -ForegroundColor Cyan
                Write-Host "• 如需永久保存路径设置，请运行:" -ForegroundColor Gray
                Write-Host "  [Environment]::SetEnvironmentVariable('SCOOP', '$env:SCOOP', 'User')" -ForegroundColor DarkGray
            }
        }
    }
} else {
    Write-Status "所有软件包都已安装" 'Success'
}
