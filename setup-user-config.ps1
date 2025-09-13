# =============================================================================
# User Configuration Setup Script
# 为不同用户和环境动态配置个人化设置
# =============================================================================

param(
    [string]$GitUserName,
    [string]$GitUserEmail,
    [switch]$SetupScoop,
    [switch]$Force
)

Write-Host "🔧 用户配置设置向导" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan

# 获取dotfiles根目录
$DotfilesDir = Split-Path $MyInvocation.MyCommand.Path -Parent

# 设置Git用户信息
if (-not $GitUserName) {
    $GitUserName = Read-Host "请输入Git用户名"
}
if (-not $GitUserEmail) {
    $GitUserEmail = Read-Host "请输入Git邮箱地址"
}

if ($GitUserName -and $GitUserEmail) {
    Write-Host "📝 配置Git用户信息..." -ForegroundColor Yellow

    # 创建用户特定的gitconfig.local文件
    $GitConfigLocal = Join-Path $DotfilesDir "configs\git\gitconfig.local"
    $GitConfigContent = @"
# 用户特定的Git配置
# 此文件不会被提交到版本控制

[user]
    name = $GitUserName
    email = $GitUserEmail

[core]
    # 自动设置行尾转换（Windows环境）
    autocrlf = input

# 自定义别名（可选）
[alias]
    st = status --short
    co = checkout
    br = branch
    ci = commit
    unstage = reset HEAD --
    last = log -1 HEAD
    visual = !gitk
    graph = log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit

"@

    if ((Test-Path $GitConfigLocal) -and -not $Force) {
        $overwrite = Read-Host "gitconfig.local已存在，是否覆盖？(y/N)"
        if ($overwrite -eq 'y' -or $overwrite -eq 'Y') {
            Set-Content -Path $GitConfigLocal -Value $GitConfigContent -Encoding UTF8
            Write-Host "✅ Git用户配置已更新" -ForegroundColor Green
        } else {
            Write-Host "⏭  跳过Git配置" -ForegroundColor Gray
        }
    } else {
        Set-Content -Path $GitConfigLocal -Value $GitConfigContent -Encoding UTF8
        Write-Host "✅ Git用户配置已创建" -ForegroundColor Green
    }
}

# 设置Scoop安全目录（如果需要）
if ($SetupScoop -or (Test-Path "$env:USERPROFILE\scoop") -or (Test-Path "C:\ProgramData\scoop")) {
    Write-Host "🔒 配置Scoop Git安全目录..." -ForegroundColor Yellow

    $ScoopPaths = @()

    # 检测用户Scoop安装
    if (Test-Path "$env:USERPROFILE\scoop") {
        $ScoopPaths += "$env:USERPROFILE\scoop"
        $ScoopPaths += "$env:USERPROFILE\scoop\apps\scoop\current"
    }

    # 检测全局Scoop安装
    if (Test-Path "C:\ProgramData\scoop") {
        $ScoopPaths += "C:\ProgramData\scoop"
        $ScoopPaths += "C:\ProgramData\scoop\apps\scoop\current"
    }

    # 检测自定义SCOOP环境变量
    if ($env:SCOOP -and (Test-Path $env:SCOOP)) {
        $ScoopPaths += $env:SCOOP
        $ScoopPaths += Join-Path $env:SCOOP "apps\scoop\current"
    }

    # 添加Git安全目录
    foreach ($path in $ScoopPaths) {
        if (Test-Path $path) {
            $normalizedPath = $path.Replace('\', '/')
            try {
                git config --global --add safe.directory $normalizedPath
                Write-Host "  ✓ 已添加安全目录: $normalizedPath" -ForegroundColor Green
            } catch {
                Write-Warning "  ✗ 添加安全目录失败: $normalizedPath"
            }
        }
    }
}

# 设置PowerShell环境变量（可选）
$SetDotfilesEnv = Read-Host "是否设置DOTFILES_DIR环境变量？这将帮助配置文件自动检测路径 (y/N)"
if ($SetDotfilesEnv -eq 'y' -or $SetDotfilesEnv -eq 'Y') {
    Write-Host "🌐 设置环境变量..." -ForegroundColor Yellow

    # 设置用户级环境变量
    [Environment]::SetEnvironmentVariable("DOTFILES_DIR", $DotfilesDir, "User")
    Write-Host "  ✓ 已设置 DOTFILES_DIR = $DotfilesDir" -ForegroundColor Green
    Write-Host "  ℹ  请重启PowerShell会话以使环境变量生效" -ForegroundColor Gray
}

# 创建Windows Terminal配置的用户特定版本
$WTConfigSource = Join-Path $DotfilesDir "configs\WindowsTerminal\settings.json"
$WTConfigLocal = Join-Path $DotfilesDir "configs\WindowsTerminal\settings.local.json"

if ((Test-Path $WTConfigSource) -and -not (Test-Path $WTConfigLocal)) {
    $CreateWTLocal = Read-Host "是否创建Windows Terminal的本地配置文件？(y/N)"
    if ($CreateWTLocal -eq 'y' -or $CreateWTLocal -eq 'Y') {
        Write-Host "📱 创建Windows Terminal本地配置..." -ForegroundColor Yellow
        Copy-Item $WTConfigSource $WTConfigLocal
        Write-Host "  ✓ 已创建 settings.local.json" -ForegroundColor Green
        Write-Host "  ℹ  可以编辑此文件进行个人定制，不会被同步到Git" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "🎉 用户配置设置完成！" -ForegroundColor Green
Write-Host ""
Write-Host "📋 配置文件位置：" -ForegroundColor Cyan
Write-Host "  Git配置: $DotfilesDir\configs\git\gitconfig.local" -ForegroundColor Gray
if (Test-Path $WTConfigLocal) {
    Write-Host "  终端配置: $DotfilesDir\configs\WindowsTerminal\settings.local.json" -ForegroundColor Gray
}
Write-Host ""
Write-Host "💡 提示：" -ForegroundColor Yellow
Write-Host "  - 这些本地配置文件不会被同步到Git仓库" -ForegroundColor Gray
Write-Host "  - 可以随时重新运行此脚本更新配置" -ForegroundColor Gray
Write-Host "  - 使用 -Force 参数强制覆盖现有配置" -ForegroundColor Gray
