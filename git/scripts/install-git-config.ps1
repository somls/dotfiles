<#
.SYNOPSIS
    安装 Git 配置文件到用户目录（默认复制安装，符号链接可选）

.DESCRIPTION
    将 dotfiles 仓库中的 Git 配置文件复制到用户目录，实现 Git 配置的自动化部署；
    可选开启符号链接模式，但在 Windows 上可能受权限/策略限制。

.PARAMETER Force
    强制覆盖现有文件，不提示确认 (默认: $false)

.PARAMETER UseSymlink
    使用符号链接而不是复制文件 (默认: $false)

.PARAMETER BackupExisting
    备份现有配置文件 (默认: $true)

.EXAMPLE
    .\install-git-config.ps1
    以默认方式（复制）安装 Git 配置

.EXAMPLE
    .\install-git-config.ps1 -UseSymlink $true
    以符号链接方式安装（可能需要管理员或启用开发者模式）

.NOTES
    本地偏好（不会提交到仓库）：
    - 环境变量：DOTFILES_PREFER_SYMLINK=1|true|yes
    - 标记文件：~/.dotfiles.use-symlink 存在
    若未显式传入 -UseSymlink，这两个本地偏好将使脚本默认为符号链接模式；
    远程/其他机器默认仍为复制模式。
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $false)]
    [switch]$Force = $false,

    [Parameter(Mandatory = $false)]
    [bool]$UseSymlink = $false,

    [Parameter(Mandatory = $false)]
    [bool]$BackupExisting = $true,

    [Parameter(Mandatory = $false)]
    [switch]$NoPrompt = $false,

    # Optionally configure Git identity
    [Parameter(Mandatory = $false)]
    [string]$UserName,

    [Parameter(Mandatory = $false)]
    [string]$UserEmail,

    # If specified, set user.name/email only when currently missing. Use -Force together to overwrite existing values.
    [Parameter(Mandatory = $false)]
    [switch]$SetUserIfMissing = $false,

    # Watch mode: monitor repo git/ sources and auto-copy to home on change
    [Parameter(Mandatory = $false)]
    [switch]$Watch = $false,

    # Debounce interval for watch events (milliseconds)
    [Parameter(Mandatory = $false)]
    [ValidateRange(50, 10000)]
    [int]$WatchDebounceMs = 300
    ,
    # Move existing ~/.gitconfig.local into repo and then link back
    [Parameter(Mandatory = $false)]
    [switch]$MigrateLocal = $false
)

# 颜色定义
$colorInfo = "Cyan"
$colorSuccess = "Green"
$colorWarning = "Yellow"
$colorError = "Red"
$colorCommand = "Magenta"

# 获取脚本目录和 dotfiles 目录
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$gitDir = Split-Path -Parent $scriptDir
$dotfilesDir = Split-Path -Parent $gitDir

# 获取用户主目录（优先 $HOME 以提升兼容性） - 避免在 PS 5.1 中将 if 当作表达式
$userHome = $HOME
if (-not $userHome) {
    $userHome = $env:USERPROFILE
}

# 读取本机“符号链接偏好”（仅当未显式传入 -UseSymlink 时生效）
try {
    $preferSymlink = $false
    if ($env:DOTFILES_PREFER_SYMLINK) {
        $val = $env:DOTFILES_PREFER_SYMLINK.ToString().ToLowerInvariant()
        if (@('1','true','yes') -contains $val) { $preferSymlink = $true }
    }
    $flagFile = Join-Path $userHome '.dotfiles.use-symlink'
    if (Test-Path $flagFile) { $preferSymlink = $true }
    if (-not $PSBoundParameters.ContainsKey('UseSymlink') -and $preferSymlink) {
        $UseSymlink = $true
    }
} catch {
    Write-Host "读取本地符号链接偏好失败: $_" -ForegroundColor $colorWarning
}

# 监听仓库 git/ 目录的变更并自动复制到用户目录
function Start-Watch {
    Write-Host "`n===== 进入 Watch 模式（自动复制） =====" -ForegroundColor $colorInfo
    Write-Host "监控目录: $gitDir" -ForegroundColor $colorInfo
    Write-Host "按 Ctrl + C 停止" -ForegroundColor $colorInfo

    # 将需要在事件处理器中访问的参数提升为脚本作用域变量
    $script:WatchDebounceMs = $WatchDebounceMs
    $script:fileMapping = $fileMapping

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $gitDir
    $watcher.Filter = "*"
    $watcher.IncludeSubdirectories = $true
    $watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size, LastAccess'

    # 简单去抖：记录上次处理时间
    $script:lastHandled = @{}

    $action = {
        param($SourceEventArgs)
        try {
            $full = $SourceEventArgs.FullPath
            $now = Get-Date

            # 忽略临时/编辑器文件
            if ($full -match "\\\\\.git\\" -or $full -match "~$" -or $full -match "\.tmp$" -or $full -match "\.swp$" -or $full -match "\.swx$") { return }

            # 去抖：同一路径在短时间内多次事件，跳过
            if ($script:lastHandled.ContainsKey($full)) {
                $delta = ($now - $script:lastHandled[$full]).TotalMilliseconds
                if ($delta -lt $script:WatchDebounceMs) { return }
            }
            $script:lastHandled[$full] = $now

            # 计算受影响的映射键
            $changedKeys = @()
            foreach ($kv in $script:fileMapping.GetEnumerator()) {
                $src = $kv.Key
                if ($full -ieq $src) { $changedKeys += $kv; continue }
                # 若是目录映射（如 gitconfig.d），子项变化也触发
                if (Test-Path $src -PathType Container) {
                    if ($full.StartsWith($src, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $changedKeys += $kv
                    }
                }
            }

            if ($changedKeys.Count -eq 0) { return }

            foreach ($kv in $changedKeys) {
                $src = $kv.Key
                $dst = $kv.Value
                Write-Host "检测到变更: $src -> 复制到 -> $dst" -ForegroundColor $script:colorInfo
                # Watch 模式下一律复制（不尝试符号链接）
                $orig = $script:UseSymlink
                try {
                    Set-Variable -Name UseSymlink -Scope Script -Value $false -Force
                    Install-ConfigFile -Source $src -Target $dst | Out-Null
                } finally {
                    Set-Variable -Name UseSymlink -Scope Script -Value $orig -Force
                }
            }
        } catch {
            Write-Host "Watch 处理异常: $_" -ForegroundColor $script:colorError
        }
    }

    $handlers = @()
    $handlers += Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $action
    $handlers += Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action
    $handlers += Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $action
    $handlers += Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action $action

    $watcher.EnableRaisingEvents = $true

    try {
        while ($true) {
            Start-Sleep -Seconds 1
        }
    } finally {
        $watcher.EnableRaisingEvents = $false
        foreach ($h in $handlers) { Unregister-Event -SourceIdentifier $h.Name -ErrorAction SilentlyContinue }
        $watcher.Dispose()
        Write-Host "Watch 已停止" -ForegroundColor $colorInfo
    }
}

# 定义源文件和目标文件的映射（使用 Join-Path）
$fileMapping = @{}
# 优先使用仓库中的 '.gitconfig'，若不存在则回退到 'gitconfig'
$gitConfigSourceDot = (Join-Path $gitDir '.gitconfig')
$gitConfigSourceNoDot = (Join-Path $gitDir 'gitconfig')
$gitConfigSource = $gitConfigSourceDot
if (-not (Test-Path $gitConfigSourceDot)) { $gitConfigSource = $gitConfigSourceNoDot }
if (-not (Test-Path $gitConfigSource)) {
    Write-Host "警告: 未在 '$gitDir' 下找到 '.gitconfig' 或 'gitconfig' 源文件，跳过该项。" -ForegroundColor $colorWarning
} else {
    $fileMapping[$gitConfigSource] = (Join-Path $userHome '.gitconfig')
}
$fileMapping[(Join-Path $gitDir 'gitignore_global')] = (Join-Path $userHome '.gitignore_global')
$fileMapping[(Join-Path $gitDir 'gitmessage')]       = (Join-Path $userHome '.gitmessage')
$fileMapping[(Join-Path $gitDir 'gitconfig.d')]      = (Join-Path $userHome '.gitconfig.d')

# 可选的本地配置（保存在仓库中但通过 .gitignore 忽略）
$repoLocal = (Join-Path $gitDir '.gitconfig.local')
if (Test-Path $repoLocal) {
    $fileMapping[$repoLocal] = (Join-Path $userHome '.gitconfig.local')
}

# 检查管理员权限
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    $principal = New-Object Security.Principal.WindowsPrincipal $user
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 创建符号链接
function New-SymbolicLink {
    param (
        [string]$Source,
        [string]$Target
    )

    try {
        # 检查目标是否为目录
        $isDirectory = Test-Path -Path $Source -PathType Container
        
        # 优先尝试 PowerShell 的原生命令（在具备权限/开发者模式时可用）
        try {
            New-Item -ItemType SymbolicLink -Path $Target -Target $Source -Force -ErrorAction Stop | Out-Null
            return $true
        } catch {
            # 回退到 mklink
            if ($isDirectory) {
                # 创建目录符号链接
                $result = cmd /c mklink /D "$Target" "$Source" 2>&1
            }
            else {
                # 创建文件符号链接
                $result = cmd /c mklink "$Target" "$Source" 2>&1
            }
            if ($LASTEXITCODE -eq 0) {
                return $true
            } else {
                Write-Host "创建符号链接失败: $result" -ForegroundColor $colorError
                return $false
            }
        }
    }
    catch {
        Write-Host "创建符号链接时出错: $_" -ForegroundColor $colorError
        return $false
    }
}

# 备份文件
function Backup-File {
    param (
        [string]$Path
    )

    if (Test-Path $Path) {
        $backupPath = "$Path.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        try {
            Copy-Item -Path $Path -Destination $backupPath -Recurse -Force
            Write-Host "已备份 '$Path' 到 '$backupPath'" -ForegroundColor $colorSuccess
            return $true
        }
        catch {
            Write-Host "备份 '$Path' 时出错: $_" -ForegroundColor $colorError
            return $false
        }
    }
    return $true  # 如果文件不存在，视为备份成功
}

# 安装配置文件
function Install-ConfigFile {
    param (
        [string]$Source,
        [string]$Target
    )

    # 检查源文件是否存在
    if (-not (Test-Path $Source)) {
        Write-Host "错误: 源文件 '$Source' 不存在。" -ForegroundColor $colorError
        return $false
    }

    # 检查目标文件是否已存在
    $targetExists = Test-Path $Target
    if ($targetExists) {
        # 如果目标是符号链接，检查它是否已经指向源文件
        if (Test-Path -PathType Container $Target) {
            $attrs = (Get-Item -Force $Target).Attributes
            $targetIsSymlink = ($attrs -band [IO.FileAttributes]::ReparsePoint) -ne 0
            if ($targetIsSymlink) {
                $targetPath = (Get-Item $Target -Force).Target
                if ($targetPath -eq $Source) {
                    Write-Host "'$Target' 已经链接到 '$Source'" -ForegroundColor $colorInfo
                    return $true
                }
            }
        }
        elseif (Test-Path -PathType Leaf $Target) {
            $attrs = (Get-Item -Force $Target).Attributes
            $targetIsSymlink = ($attrs -band [IO.FileAttributes]::ReparsePoint) -ne 0
            if ($targetIsSymlink) {
                $targetPath = (Get-Item $Target -Force).Target
                if ($targetPath -eq $Source) {
                    Write-Host "'$Target' 已经链接到 '$Source'" -ForegroundColor $colorInfo
                    return $true
                }
            }
        }

        # 如果不是强制模式，请求确认（允许非交互跳过）
        if (-not $Force) {
            if ($NoPrompt) {
                Write-Host "跳过 '$Target'（NoPrompt）" -ForegroundColor $colorInfo
                return $false
            } else {
                $confirmation = Read-Host "'$Target' 已存在。是否覆盖? (y/N)"
                if ($confirmation -ne "y" -and $confirmation -ne "Y") {
                    Write-Host "跳过 '$Target'" -ForegroundColor $colorInfo
                    return $false
                }
            }
        }

        # 备份现有文件
        if ($BackupExisting) {
            if (-not (Backup-File -Path $Target)) {
                return $false
            }
        }

        # 删除现有文件或目录
        try {
            if ($PSCmdlet.ShouldProcess($Target, 'Remove existing target')) {
                if (Test-Path -PathType Container $Target) {
                    Remove-Item -Path $Target -Recurse -Force
                }
                else {
                    Remove-Item -Path $Target -Force
                }
            }
        }
        catch {
            Write-Host "删除现有文件 '$Target' 时出错: $_" -ForegroundColor $colorError
            return $false
        }
    }

    # 确保目标目录存在
    $targetDir = Split-Path -Parent $Target
    if (-not (Test-Path $targetDir)) {
        try {
            New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            Write-Host "已创建目录 '$targetDir'" -ForegroundColor $colorSuccess
        }
        catch {
            Write-Host "创建目录 '$targetDir' 时出错: $_" -ForegroundColor $colorError
            return $false
        }
    }

    # 创建符号链接或复制文件
    if ($UseSymlink) {
        $result = $false
        if ($PSCmdlet.ShouldProcess($Target, 'Create symbolic link')) {
            $result = New-SymbolicLink -Source $Source -Target $Target
        }
        if ($result) {
            Write-Host "已创建符号链接: '$Target' -> '$Source'" -ForegroundColor $colorSuccess
            return $true
        }
        else {
            Write-Host "创建符号链接失败（可能需要管理员权限或未启用开发者模式），将改为复制文件。" -ForegroundColor $colorWarning
            $UseSymlink = $false
        }
    }

    if (-not $UseSymlink) {
        try {
            if ($PSCmdlet.ShouldProcess($Target, 'Copy from source')) {
                if (Test-Path -PathType Container $Source) {
                    Copy-Item -Path $Source -Destination $Target -Recurse -Force
                }
                else {
                    Copy-Item -Path $Source -Destination $Target -Force
                }
            }
            Write-Host "已复制 '$Source' 到 '$Target'" -ForegroundColor $colorSuccess
            return $true
        }
        catch {
            Write-Host "复制 '$Source' 到 '$Target' 时出错: $_" -ForegroundColor $colorError
            return $false
        }
    }

    return $false
}

# 创建本地配置文件模板
function Create-LocalConfigTemplate {
    $localConfigPath = (Join-Path $userHome '.gitconfig.local')
    
    if (-not (Test-Path $localConfigPath)) {
        $localConfigContent = @'
# 本地 Git 配置 - 不会被版本控制跟踪
# 此文件用于存储特定于此机器的 Git 配置

[user]
    # 覆盖全局用户设置（如果需要）
    # name = Your Name
    # email = your.email@example.com
    # signingkey = YOUR_SIGNING_KEY_ID

[github]
    # GitHub 特定配置
    # user = your-github-username

[credential]
    # 凭据助手配置
    # helper = wincred
    # helper = manager

# 其他特定于此机器的设置
'@

        try {
            Set-Content -Path $localConfigPath -Value $localConfigContent -Encoding UTF8
            Write-Host "已创建本地配置模板: '$localConfigPath'" -ForegroundColor $colorSuccess
            return $true
        }
        catch {
            Write-Host "创建本地配置模板时出错: $_" -ForegroundColor $colorError
            return $false
        }
    }
    else {
        Write-Host "本地配置文件已存在: '$localConfigPath'" -ForegroundColor $colorInfo
        return $true
    }
}

# 主函数
function Main {
    Write-Host "`n===== 安装 Git 配置文件 =====" -ForegroundColor $colorInfo
    
    # 显示安装信息
    Write-Host "源目录: $gitDir" -ForegroundColor $colorInfo
    Write-Host "目标目录: $userHome" -ForegroundColor $colorInfo
    Write-Host "使用符号链接: $UseSymlink" -ForegroundColor $colorInfo
    Write-Host "备份现有文件: $BackupExisting" -ForegroundColor $colorInfo
    Write-Host "强制模式: $Force" -ForegroundColor $colorInfo

    # 迁移现有本地配置到仓库（可选）
    if ($MigrateLocal) {
        try {
            $homeLocal = (Join-Path $userHome '.gitconfig.local')
            $repoLocal = (Join-Path $gitDir '.gitconfig.local')

            if ((Test-Path $homeLocal) -and -not (Test-Path $repoLocal)) {
                Copy-Item -Path $homeLocal -Destination $repoLocal -Force
                Write-Host "已迁移 ~/.gitconfig.local 到 仓库: $repoLocal" -ForegroundColor $colorSuccess
                $fileMapping[$repoLocal] = $homeLocal
            }
        } catch {
            Write-Host "迁移本地 Git 配置失败: $_" -ForegroundColor $colorWarning
        }
    }

    # 安装配置文件
    $successCount = 0
    $totalCount = $fileMapping.Count

    foreach ($mapping in $fileMapping.GetEnumerator()) {
        Write-Host "`n处理: $($mapping.Key) -> $($mapping.Value)" -ForegroundColor $colorInfo
        if (Install-ConfigFile -Source $mapping.Key -Target $mapping.Value) {
            $successCount++
        }
    }

    # 创建本地配置文件模板
    Create-LocalConfigTemplate

    # 显示安装摘要
    Write-Host "`n安装摘要:" -ForegroundColor $colorInfo
    # PowerShell 5.1 does not support ternary operator; avoid inline if in parameter
    $summaryColor = $colorWarning
    if ($successCount -eq $totalCount) { $summaryColor = $colorSuccess }
    Write-Host "成功: $successCount / $totalCount" -ForegroundColor $summaryColor

    if ($successCount -eq $totalCount) {
        Write-Host "`nGit 配置文件安装完成！" -ForegroundColor $colorSuccess
    }
    else {
        Write-Host "`nGit 配置文件安装部分完成。请检查上述错误。" -ForegroundColor $colorWarning
    }

    # 配置 Git 用户身份（可选）
    try {
        $gitCmd = Get-Command git -ErrorAction SilentlyContinue
        if ($gitCmd) {
            $currentName = git config --global user.name 2>$null
            $currentEmail = git config --global user.email 2>$null

            $shouldSetName = $false
            $shouldSetEmail = $false

            if ($SetUserIfMissing) {
                if (-not $currentName -and $UserName) { $shouldSetName = $true }
                if (-not $currentEmail -and $UserEmail) { $shouldSetEmail = $true }
            } elseif ($Force) {
                if ($UserName) { $shouldSetName = $true }
                if ($UserEmail) { $shouldSetEmail = $true }
            }

            if ($shouldSetName -and $PSCmdlet.ShouldProcess("git global user.name", "Set to '$UserName'")) {
                git config --global user.name "$UserName" | Out-Null
                Write-Host "已设置 Git 用户名: $UserName" -ForegroundColor $colorSuccess
            }
            if ($shouldSetEmail -and $PSCmdlet.ShouldProcess("git global user.email", "Set to '$UserEmail'")) {
                git config --global user.email "$UserEmail" | Out-Null
                Write-Host "已设置 Git 邮箱: $UserEmail" -ForegroundColor $colorSuccess
            }

            if (-not $UserName -and -not $UserEmail -and $SetUserIfMissing -and -not $NoPrompt -and -not $Force) {
                # 仅在允许提示时，指导用户如何设置
                if (-not $currentName) { Write-Host "提示: 当前未检测到 Git 用户名。可使用参数 -UserName 设置，或稍后手动设置。" -ForegroundColor $colorWarning }
                if (-not $currentEmail) { Write-Host "提示: 当前未检测到 Git 邮箱。可使用参数 -UserEmail 设置，或稍后手动设置。" -ForegroundColor $colorWarning }
            }
        } else {
            Write-Host "提示: 未检测到 git 命令，跳过 Git 身份配置。" -ForegroundColor $colorWarning
        }
    } catch {
        Write-Host "配置 Git 身份时出错: $_" -ForegroundColor $colorError
    }

    # 提示用户下一步操作
    Write-Host "`n提示:" -ForegroundColor $colorInfo
    Write-Host "1. 编辑 '$userHome\.gitconfig.local' 设置特定于此机器的配置" -ForegroundColor $colorInfo
    Write-Host "2. 运行 'git config --list' 查看当前 Git 配置" -ForegroundColor $colorInfo
    Write-Host "3. 如需自定义用户信息，请运行:" -ForegroundColor $colorInfo
    Write-Host "   git config --global user.name \"Your Name\"" -ForegroundColor $colorCommand
    Write-Host "   git config --global user.email \"your.email@example.com\"" -ForegroundColor $colorCommand
    }

    # 执行主函数
    Main

    # Watch 模式：持续监听并自动复制
    if ($Watch) { Start-Watch }