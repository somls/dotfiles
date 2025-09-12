<#
.SYNOPSIS
    Git 初始化设置脚本

.DESCRIPTION
    配置 Git 用户信息和常用设置，为新仓库设置初始化模板

.PARAMETER UserName
    Git 用户名

.PARAMETER UserEmail
    Git 用户邮箱

.PARAMETER DefaultBranch
    默认分支名称 (默认: main)

.PARAMETER Editor
    默认编辑器 (默认: code --wait)

.PARAMETER InitRepo
    是否初始化新仓库 (默认: $false)

.PARAMETER SetupHooks
    是否设置 Git 钩子 (默认: $false)

.PARAMETER Force
    强制执行操作，不提示确认 (默认: $false)

.EXAMPLE
    .\git-setup.ps1 -UserName "Your Name" -UserEmail "your.email@example.com"

.EXAMPLE
    .\git-setup.ps1 -UserName "Your Name" -UserEmail "your.email@example.com" -InitRepo -SetupHooks

.EXAMPLE
    .\git-setup.ps1 -DefaultBranch "develop" -Editor "notepad"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$UserName,

    [Parameter(Mandatory = $false)]
    [string]$UserEmail,

    [Parameter(Mandatory = $false)]
    [string]$DefaultBranch = "main",

    [Parameter(Mandatory = $false)]
    [string]$Editor = "code --wait",

    [Parameter(Mandatory = $false)]
    [switch]$InitRepo = $false,

    [Parameter(Mandatory = $false)]
    [switch]$SetupHooks = $false,

    [Parameter(Mandatory = $false)]
    [switch]$Force = $false
)

# 颜色定义
$colorInfo = "Cyan"
$colorSuccess = "Green"
$colorWarning = "Yellow"
$colorError = "Red"
$colorCommand = "Magenta"

# 检查 Git 是否已安装
function Test-GitInstalled {
    try {
        $gitVersion = git --version
        return $true
    }
    catch {
        return $false
    }
}

# 检查当前目录是否是 Git 仓库
function Test-GitRepository {
    try {
        $gitStatus = git rev-parse --is-inside-work-tree 2>$null
        return $gitStatus -eq "true"
    }
    catch {
        return $false
    }
}

# 获取当前 Git 配置
function Get-GitConfig {
    param (
        [string]$Key,
        [string]$Scope = "--global"
    )

    try {
        $value = git config $Scope --get $Key 2>$null
        return $value
    }
    catch {
        return $null
    }
}

# 设置 Git 配置
function Set-GitConfig {
    param (
        [string]$Key,
        [string]$Value,
        [string]$Scope = "--global"
    )

    try {
        git config $Scope $Key "$Value"
        return $true
    }
    catch {
        return $false
    }
}

# 配置 Git 用户信息
function Set-GitUserInfo {
    param (
        [string]$Name,
        [string]$Email
    )

    Write-Host "\n配置 Git 用户信息..." -ForegroundColor $colorInfo

    # 获取当前配置
    $currentName = Get-GitConfig -Key "user.name"
    $currentEmail = Get-GitConfig -Key "user.email"

    # 如果未提供用户名，使用当前配置或请求输入
    if ([string]::IsNullOrEmpty($Name)) {
        if ([string]::IsNullOrEmpty($currentName)) {
            $Name = Read-Host "请输入您的 Git 用户名"
            if ([string]::IsNullOrEmpty($Name)) {
                Write-Host "错误: 未提供用户名，无法继续。" -ForegroundColor $colorError
                return $false
            }
        }
        else {
            $Name = $currentName
            Write-Host "使用现有用户名: $Name" -ForegroundColor $colorInfo
        }
    }
    elseif ($Name -ne $currentName) {
        Write-Host "将用户名从 '$currentName' 更改为 '$Name'" -ForegroundColor $colorInfo
    }
    else {
        Write-Host "用户名保持不变: $Name" -ForegroundColor $colorInfo
    }

    # 如果未提供邮箱，使用当前配置或请求输入
    if ([string]::IsNullOrEmpty($Email)) {
        if ([string]::IsNullOrEmpty($currentEmail)) {
            $Email = Read-Host "请输入您的 Git 邮箱"
            if ([string]::IsNullOrEmpty($Email)) {
                Write-Host "错误: 未提供邮箱，无法继续。" -ForegroundColor $colorError
                return $false
            }
        }
        else {
            $Email = $currentEmail
            Write-Host "使用现有邮箱: $Email" -ForegroundColor $colorInfo
        }
    }
    elseif ($Email -ne $currentEmail) {
        Write-Host "将邮箱从 '$currentEmail' 更改为 '$Email'" -ForegroundColor $colorInfo
    }
    else {
        Write-Host "邮箱保持不变: $Email" -ForegroundColor $colorInfo
    }

    # 设置用户名和邮箱
    $nameResult = Set-GitConfig -Key "user.name" -Value $Name
    $emailResult = Set-GitConfig -Key "user.email" -Value $Email

    if ($nameResult -and $emailResult) {
        Write-Host "Git 用户信息已配置:" -ForegroundColor $colorSuccess
        Write-Host "  用户名: $Name" -ForegroundColor $colorSuccess
        Write-Host "  邮箱: $Email" -ForegroundColor $colorSuccess
        return $true
    }
    else {
        Write-Host "配置 Git 用户信息时出错。" -ForegroundColor $colorError
        return $false
    }
}

# 配置 Git 核心设置
function Set-GitCoreSettings {
    param (
        [string]$DefaultBranch,
        [string]$Editor
    )

    Write-Host "\n配置 Git 核心设置..." -ForegroundColor $colorInfo

    # 设置默认分支
    $currentDefaultBranch = Get-GitConfig -Key "init.defaultBranch"
    if ([string]::IsNullOrEmpty($currentDefaultBranch) -or $currentDefaultBranch -ne $DefaultBranch) {
        Set-GitConfig -Key "init.defaultBranch" -Value $DefaultBranch
        Write-Host "默认分支已设置为: $DefaultBranch" -ForegroundColor $colorSuccess
    }
    else {
        Write-Host "默认分支保持不变: $DefaultBranch" -ForegroundColor $colorInfo
    }

    # 设置默认编辑器
    $currentEditor = Get-GitConfig -Key "core.editor"
    if ([string]::IsNullOrEmpty($currentEditor) -or $currentEditor -ne $Editor) {
        Set-GitConfig -Key "core.editor" -Value $Editor
        Write-Host "默认编辑器已设置为: $Editor" -ForegroundColor $colorSuccess
    }
    else {
        Write-Host "默认编辑器保持不变: $Editor" -ForegroundColor $colorInfo
    }

    # 设置其他常用配置
    $coreSettings = @{
        "core.autocrlf" = "input";
        "core.safecrlf" = "warn";
        "pull.rebase" = "true";
        "push.default" = "simple";
        "push.autoSetupRemote" = "true";
        "color.ui" = "auto";
        "core.longpaths" = "true";
    }

    foreach ($setting in $coreSettings.GetEnumerator()) {
        $currentValue = Get-GitConfig -Key $setting.Key
        if ([string]::IsNullOrEmpty($currentValue) -or $currentValue -ne $setting.Value) {
            Set-GitConfig -Key $setting.Key -Value $setting.Value
            Write-Host "$($setting.Key) 已设置为: $($setting.Value)" -ForegroundColor $colorSuccess
        }
        else {
            Write-Host "$($setting.Key) 保持不变: $($setting.Value)" -ForegroundColor $colorInfo
        }
    }

    return $true
}

# 初始化 Git 仓库
function Initialize-GitRepository {
    Write-Host "\n初始化 Git 仓库..." -ForegroundColor $colorInfo

    # 检查当前目录是否已经是 Git 仓库
    if (Test-GitRepository) {
        Write-Host "当前目录已经是 Git 仓库。" -ForegroundColor $colorWarning
        return $true
    }

    # 如果不是强制模式，请求确认
    if (-not $Force) {
        $confirmation = Read-Host "是否在当前目录初始化 Git 仓库? (y/N)"
        if ($confirmation -ne "y" -and $confirmation -ne "Y") {
            Write-Host "仓库初始化已取消。" -ForegroundColor $colorInfo
            return $false
        }
    }

    # 初始化仓库
    try {
        git init --initial-branch=$DefaultBranch
        Write-Host "Git 仓库已初始化，默认分支: $DefaultBranch" -ForegroundColor $colorSuccess

        # 创建 .gitignore 文件
        if (-not (Test-Path ".gitignore")) {
            Write-Host "创建 .gitignore 文件..." -ForegroundColor $colorInfo
            
            # 基本的 .gitignore 内容
            $gitignoreContent = @"
# 操作系统文件
.DS_Store
Thumbs.db

# 编辑器和 IDE 文件
.vscode/
.idea/
*.suo
*.user
*.userosscache
*.sln.docstates

# 构建输出
bin/
obj/
out/
build/
dist/

# 依赖目录
node_modules/
vendor/
packages/

# 日志和临时文件
*.log
*.tmp
*.temp
*~

# 环境变量和敏感信息
.env
.env.local
.env.*.local

# 项目特定文件
# 添加您的项目特定忽略规则
"@

            Set-Content -Path ".gitignore" -Value $gitignoreContent
            Write-Host ".gitignore 文件已创建。" -ForegroundColor $colorSuccess
        }

        # 创建 README.md 文件
        if (-not (Test-Path "README.md")) {
            Write-Host "创建 README.md 文件..." -ForegroundColor $colorInfo
            
            # 获取当前目录名作为项目名
            $projectName = Split-Path -Leaf (Get-Location)
            
            # 基本的 README.md 内容
            $readmeContent = @"
# $projectName

## 项目简介

简要描述项目的目的和功能。

## 安装

描述如何安装和设置项目。

```bash
# 安装示例
git clone https://github.com/username/$projectName.git
cd $projectName
# 其他安装步骤...
```

## 使用方法

提供使用示例。

```bash
# 使用示例
```

## 功能

- 功能 1
- 功能 2
- 功能 3

## 贡献

欢迎贡献！请阅读贡献指南了解如何开始。

## 许可证

[MIT](LICENSE)
"@

            Set-Content -Path "README.md" -Value $readmeContent
            Write-Host "README.md 文件已创建。" -ForegroundColor $colorSuccess
        }

        # 创建初始提交
        git add .
        git commit -m "Initial commit"
        Write-Host "初始提交已创建。" -ForegroundColor $colorSuccess

        return $true
    }
    catch {
        Write-Host "初始化 Git 仓库时出错: $_" -ForegroundColor $colorError
        return $false
    }
}

# 设置 Git 钩子
function Set-GitHooks {
    Write-Host "\n设置 Git 钩子..." -ForegroundColor $colorInfo

    # 检查当前目录是否是 Git 仓库
    if (-not (Test-GitRepository)) {
        Write-Host "错误: 当前目录不是 Git 仓库。请先初始化仓库。" -ForegroundColor $colorError
        return $false
    }

    # 获取钩子目录路径
    $hooksDir = ".git/hooks"
    if (-not (Test-Path $hooksDir)) {
        Write-Host "错误: 找不到钩子目录 '$hooksDir'。" -ForegroundColor $colorError
        return $false
    }

    # 获取脚本目录中的钩子模板
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $hooksTemplateDir = Join-Path (Split-Path -Parent $scriptDir) "hooks"

    if (-not (Test-Path $hooksTemplateDir)) {
        Write-Host "错误: 找不到钩子模板目录 '$hooksTemplateDir'。" -ForegroundColor $colorError
        return $false
    }

    # 复制钩子文件
    $hookFiles = @("pre-commit", "prepare-commit-msg")
    foreach ($hookFile in $hookFiles) {
        $sourcePath = Join-Path $hooksTemplateDir $hookFile
        $destPath = Join-Path $hooksDir $hookFile

        if (Test-Path $sourcePath) {
            try {
                Copy-Item -Path $sourcePath -Destination $destPath -Force
                # 在 Unix 系统上设置可执行权限
                if (-not $IsWindows) {
                    chmod +x $destPath
                }
                Write-Host "钩子 '$hookFile' 已安装。" -ForegroundColor $colorSuccess
            }
            catch {
                Write-Host "安装钩子 '$hookFile' 时出错: $_" -ForegroundColor $colorError
            }
        }
        else {
            Write-Host "警告: 找不到钩子模板 '$sourcePath'。" -ForegroundColor $colorWarning
        }
    }

    return $true
}

# 显示 Git 配置摘要
function Show-GitConfigSummary {
    Write-Host "\nGit 配置摘要:" -ForegroundColor $colorInfo

    # 用户信息
    $userName = Get-GitConfig -Key "user.name"
    $userEmail = Get-GitConfig -Key "user.email"
    Write-Host "用户信息:" -ForegroundColor $colorInfo
    Write-Host "  用户名: $userName" -ForegroundColor $colorInfo
    Write-Host "  邮箱: $userEmail" -ForegroundColor $colorInfo

    # 核心设置
    $defaultBranch = Get-GitConfig -Key "init.defaultBranch"
    $editor = Get-GitConfig -Key "core.editor"
    $autocrlf = Get-GitConfig -Key "core.autocrlf"
    $pullRebase = Get-GitConfig -Key "pull.rebase"
    Write-Host "核心设置:" -ForegroundColor $colorInfo
    Write-Host "  默认分支: $defaultBranch" -ForegroundColor $colorInfo
    Write-Host "  默认编辑器: $editor" -ForegroundColor $colorInfo
    Write-Host "  自动换行符: $autocrlf" -ForegroundColor $colorInfo
    Write-Host "  拉取策略: $pullRebase" -ForegroundColor $colorInfo

    # 仓库状态
    if (Test-GitRepository) {
        $branch = git symbolic-ref --short HEAD 2>$null
        if (-not $branch) {
            $branch = git rev-parse --short HEAD 2>$null
            $branch = "detached HEAD ($branch)"
        }
        Write-Host "当前仓库:" -ForegroundColor $colorInfo
        Write-Host "  当前分支: $branch" -ForegroundColor $colorInfo
        
        # 检查是否有远程仓库
        $remotes = git remote -v 2>$null
        if ($remotes) {
            Write-Host "  远程仓库:" -ForegroundColor $colorInfo
            $remotes | ForEach-Object { Write-Host "    $_" -ForegroundColor $colorInfo }
        }
        else {
            Write-Host "  远程仓库: 无" -ForegroundColor $colorInfo
        }
    }
}

# 主函数
function Main {
    # 显示脚本标题
    Write-Host "\n===== Git 初始化设置工具 =====" -ForegroundColor $colorInfo

    # 检查 Git 是否已安装
    if (-not (Test-GitInstalled)) {
        Write-Host "错误: Git 未安装或不在 PATH 中。请先安装 Git。" -ForegroundColor $colorError
        exit 1
    }

    # 配置 Git 用户信息
    Set-GitUserInfo -Name $UserName -Email $UserEmail

    # 配置 Git 核心设置
    Set-GitCoreSettings -DefaultBranch $DefaultBranch -Editor $Editor

    # 初始化 Git 仓库（如果需要）
    if ($InitRepo) {
        Initialize-GitRepository
    }

    # 设置 Git 钩子（如果需要）
    if ($SetupHooks) {
        Set-GitHooks
    }

    # 显示配置摘要
    Show-GitConfigSummary

    Write-Host "\nGit 设置完成！" -ForegroundColor $colorSuccess
}

# 执行主函数
Main