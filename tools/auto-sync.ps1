#Requires -Version 5.1

<#
.SYNOPSIS
    Intelligent auto-commit and sync script

.DESCRIPTION
    Provides intelligent Git configuration sync functionality, automatically handling local and remote differences:
    1. Detect local uncommitted changes and auto-commit
    2. Compare local and remote branch status
    3. Execute push, pull, or merge operations based on situation
    4. Keep configurations synchronized across multiple devices

.PARAMETER Push
    Whether to push to remote repository (only effective in non-Auto mode)

.PARAMETER DryRun
    Preview mode, shows operations to be executed but doesn't actually execute them

.PARAMETER Message
    Custom commit message

.PARAMETER Auto
    Intelligent auto-sync mode:
    - Auto-commit local uncommitted changes
    - Compare local and remote branch status
    - Local ahead: push to remote
    - Remote ahead: pull remote changes
    - Both have updates: use rebase merge

.PARAMETER BackupFirst
    Create backup before syncing

.PARAMETER ForceFetch
    Force detailed fetch (with --force) for troubleshooting remote visibility issues

.PARAMETER ForceWithLease
    Use --force-with-lease when pushing (safer force push)

.PARAMETER RemoteNames
    Array of remote repository names to push to (default: @("origin", "gitcode"))

.EXAMPLE
    .\auto-sync.ps1 -Auto
    Execute intelligent auto-sync

.EXAMPLE
    .\auto-sync.ps1 -Auto -DryRun
    Preview sync operations

.EXAMPLE
    .\auto-sync.ps1 -Message "Update configs" -Push
    Manual commit and push

.EXAMPLE
    .\auto-sync.ps1 -BackupFirst -Auto
    Safe sync (backup first)

.EXAMPLE
    .\auto-sync.ps1 -Auto -RemoteNames @("origin", "gitcode", "backup")
    Sync to specific remotes

.EXAMPLE
    .\auto-sync.ps1 -Auto -RemoteNames @("origin")
    Sync to GitHub only

.NOTES
    Recommend using -Auto parameter for intelligent sync, script will handle various situations automatically
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Message,

    [Parameter(Mandatory = $false)]
    [switch]$Push,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Auto,

    [Parameter(Mandatory = $false)]
    [switch]$BackupFirst,

    [Parameter(Mandatory = $false)]
    [switch]$ForceFetch,

    [Parameter(Mandatory = $false)]
    [switch]$ForceWithLease,

    [Parameter(Mandatory = $false)]
    [string[]]$RemoteNames = @("origin", "gitcode")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Log level used for safety-push messages
$SafetyPushLogLevel = "INFO"

# 创建备份函数
function New-ProjectBackup {
    param([string]$BackupReason = "Auto-sync backup")

    try {
        $BackupDir = Join-Path $env:USERPROFILE ".dotfiles-backup"
        $Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $BackupPath = Join-Path $BackupDir "backup-$Timestamp"

        Write-Log "Creating project backup: $BackupPath" -Level "INFO"

        # 创建备份目录
        if (-not (Test-Path $BackupDir)) {
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        }

        # 获取项目根目录
        $ProjectRoot = git rev-parse --show-toplevel 2>$null
        if (-not $ProjectRoot -or $LASTEXITCODE -ne 0) {
            $ProjectRoot = Get-Location
        }

        # 创建备份
        Copy-Item -Path $ProjectRoot -Destination $BackupPath -Recurse -Force

        # 清理Git目录（减少备份大小）
        $GitDir = Join-Path $BackupPath ".git"
        if (Test-Path $GitDir) {
            Remove-Item $GitDir -Recurse -Force
        }

        # 创建备份信息文件
        $BackupInfo = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Reason = $BackupReason
            OriginalPath = $ProjectRoot
            GitBranch = git branch --show-current 2>$null
            GitCommit = git rev-parse HEAD 2>$null
        }

        $BackupInfo | ConvertTo-Json | Out-File (Join-Path $BackupPath "backup-info.json") -Encoding UTF8

        Write-Log "Backup created successfully: $BackupPath" -Level "INFO"
        return $true
    }
    catch {
        Write-Log "Failed to create backup: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"

    switch ($Level) {
        "INFO" { Write-Host $LogEntry -ForegroundColor Green }
        "WARN" { Write-Host $LogEntry -ForegroundColor Yellow }
        "ERROR" { Write-Host $LogEntry -ForegroundColor Red }
    }
}

function Test-GitRepository {
    try {
        $null = git rev-parse --git-dir 2>$null
        return $true
    }
    catch {
        return $false
    }
}

function Get-GitChanges {
    try {
        $Changes = @{
            Added = @()
            Modified = @()
            Deleted = @()
            Untracked = @()
        }

        $GitStatus = git status --porcelain 2>$null
        if ($GitStatus) {
            foreach ($Line in $GitStatus) {
                if ($Line.Length -ge 3) {
                    $StatusCode = $Line.Substring(0, 2)
                    $FilePath = $Line.Substring(3)

                    switch ($StatusCode.Trim()) {
                        'A' { $Changes.Added += $FilePath }
                        'M' { $Changes.Modified += $FilePath }
                        'D' { $Changes.Deleted += $FilePath }
                        '??' { $Changes.Untracked += $FilePath }
                        default {
                            if ($StatusCode[1] -eq 'M') { $Changes.Modified += $FilePath }
                            elseif ($StatusCode[1] -eq 'D') { $Changes.Deleted += $FilePath }
                            else { $Changes.Modified += $FilePath }
                        }
                    }
                }
            }
        }

        return $Changes
    }
    catch {
        Write-Log "Failed to get Git changes: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Get-CurrentBranch {
    try {
        $name = git rev-parse --abbrev-ref HEAD 2>$null
        return $name
    } catch { return $null }
}

function Test-RemoteExists {
    param([string]$RemoteName)
    try {
        git remote get-url $RemoteName 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Invoke-MultiRemotePush {
    param(
        [string[]]$Remotes,
        [string[]]$PushArgs = @(),
        [int]$MaxRetries = 3,
        [switch]$DryRunMode
    )

    if ($DryRunMode) {
        Write-Host "[DryRun] Multi-remote push preview:" -ForegroundColor Yellow
        foreach ($remote in $Remotes) {
            if (Test-RemoteExists $remote) {
                $pushCmd = "git push $remote $($PushArgs -join ' ')".Trim()
                Write-Host "  - $pushCmd" -ForegroundColor DarkYellow
            } else {
                Write-Host "  - Skip '$remote' (remote not configured)" -ForegroundColor DarkGray
            }
        }
        return $true
    }

    $allSucceeded = $true
    $validRemotes = @()

    # 验证所有远程仓库
    foreach ($remote in $Remotes) {
        if (Test-RemoteExists $remote) {
            $validRemotes += $remote
            Write-Log "Remote '$remote' verified" -Level "INFO"
        } else {
            Write-Log "Remote '$remote' not configured, skipping" -Level "WARN"
        }
    }

    if ($validRemotes.Count -eq 0) {
        Write-Log "No valid remotes found for pushing" -Level "ERROR"
        return $false
    }

    # 推送到每个有效的远程仓库
    foreach ($remote in $validRemotes) {
        Write-Log "Pushing to remote: $remote" -Level "INFO"

        $pushSuccess = $false
        for ($i = 1; $i -le $MaxRetries -and -not $pushSuccess; $i++) {
            try {
                if ($PushArgs.Count -gt 0) {
                    & git push $remote @PushArgs 2>$null
                } else {
                    & git push $remote 2>$null
                }
                $pushSuccess = ($LASTEXITCODE -eq 0)
            } catch {
                $pushSuccess = $false
            }

            if (-not $pushSuccess -and $i -lt $MaxRetries) {
                Write-Log "Push to '$remote' failed (retry $($i+1)/$MaxRetries)" -Level "WARN"
                Start-Sleep -Seconds 1
            }
        }

        if ($pushSuccess) {
            Write-Log "Push to '$remote' successful" -Level "INFO"
        } else {
            Write-Log "Push to '$remote' failed after $MaxRetries attempts" -Level "ERROR"
            $allSucceeded = $false
        }
    }

    return $allSucceeded
}

function Test-BranchHasUpstream {
    try {
        git rev-parse --abbrev-ref --symbolic-full-name 'HEAD@{u}' 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Ensure-Upstream {
    $branch = Get-CurrentBranch
    if (-not $branch) { return $false }
    if (Test-BranchHasUpstream) { return $true }
    Write-Log "No upstream branch detected, setting: origin/$branch" -Level "WARN"
    git push -u origin $branch 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Get-Divergence {
    # 返回 @{ Ahead = <int>; Behind = <int> }
    try {
        # 首先尝试 fetch 获取最新的远程状态
        Write-Log "Fetching latest remote status..." -Level "INFO"

        # 构建 fetch 参数
        $fetchArgs = @('--all', '--prune')
        if ($ForceFetch) { $fetchArgs += '--force' }

        # 执行 fetch 操作，带重试机制
        $maxRetries = 3
        $success = $false
        for ($i = 1; $i -le $maxRetries -and -not $success; $i++) {
            try {
                if ($VerbosePreference -ne 'SilentlyContinue') {
                    $fetchOutput = & git fetch @fetchArgs 2>&1
                    if ($fetchOutput) { Write-Verbose ("fetch output:`n" + ($fetchOutput -join "`n")) }
                } else {
                    & git fetch @fetchArgs >$null 2>&1
                }
                $success = ($LASTEXITCODE -eq 0)
            }
            catch {
                $success = $false
            }

            if (-not $success -and $i -lt $maxRetries) {
                Write-Log "git fetch failed, retry $($i+1)/$maxRetries..." -Level "WARN"
                Start-Sleep -Seconds 1
            }
        }

        if (-not $success) {
            Write-Log "git fetch failed, using local cached remote status" -Level "WARN"
        }

        # 检查是否有上游分支
        if (-not (Test-BranchHasUpstream)) {
            Write-Log "No upstream branch detected, attempting auto-setup..." -Level "WARN"
            $branch = Get-CurrentBranch
            if ($branch) {
                # 尝试设置上游分支
                git push -u origin $branch 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Upstream branch set: origin/$branch" -Level "INFO"
                } else {
                    Write-Log "Cannot set upstream branch, returning default divergence status" -Level "WARN"
                    return @{ Ahead = 0; Behind = 0 }
                }
            } else {
                return @{ Ahead = 0; Behind = 0 }
            }
        }

        # 获取分歧计数
        try {
            $counts = git rev-list --left-right --count "HEAD...HEAD@{u}" 2>$null
            if ($VerbosePreference -ne 'SilentlyContinue') {
                Write-Verbose ("rev-list output: '$counts'")
            }
        }
        catch {
            $counts = $null
        }

        if (-not $counts -or $counts.Trim() -eq '') {
            Write-Log "Cannot get divergence count, branches may be fully synced" -Level "INFO"
            return @{ Ahead = 0; Behind = 0 }
        }

        # 解析分歧计数
        $parts = @($counts.Trim() -split '\s+') | Where-Object { $_ -ne '' -and $_ -match '^\d+$' }
        if ($parts.Count -lt 2) {
            Write-Log "Divergence count format abnormal: '$counts', assuming synced state" -Level "WARN"
            return @{ Ahead = 0; Behind = 0 }
        }

        $ahead = [int]$parts[0]
        $behind = [int]$parts[1]

        Write-Log "Divergence status: Local ahead $ahead commits, remote ahead $behind commits" -Level "INFO"
        return @{ Ahead = $ahead; Behind = $behind }

    } catch {
        Write-Log "Exception occurred while getting divergence info: $($_.Exception.Message)" -Level "ERROR"
        return @{ Ahead = 0; Behind = 0 }
    }
}

function Invoke-AutoSync {
    param(
        [switch]$DryRunMode
    )
    Write-Host "=== Intelligent Auto-Sync Mode (AutoSync) ===" -ForegroundColor Cyan
    if (-not (Test-GitRepository)) { Write-Log "Current directory is not a Git repository" -Level "ERROR"; return $false }

    $branch = Get-CurrentBranch
    if (-not $branch) { Write-Log "Cannot determine current branch" -Level "ERROR"; return $false }

    if (-not (Ensure-Upstream)) { Write-Log "Cannot set/confirm upstream branch" -Level "ERROR"; return $false }
    $didCommit = $false

    # 先检查本地是否有未提交的更改
    $changes = Get-GitChanges
    $hasLocalChanges = ($changes.Added.Count + $changes.Modified.Count + $changes.Deleted.Count + $changes.Untracked.Count) -gt 0

    # 如果有本地更改，先提交
    if ($hasLocalChanges) {
        Write-Log "Detected local uncommitted changes, committing locally first..." -Level "INFO"
        if ($DryRunMode) {
            Write-Host "[DryRun] Will commit local changes first" -ForegroundColor Yellow
        } else {
            $commitMsg = New-CommitMessage -Changes $changes -CustomMessage $Message
            $commitSuccess = Invoke-GitCommit -Changes $changes -CommitMessage $commitMsg -PushToRemote:$false -DryRunMode:$false -RemoteNames $RemoteNames
            if (-not $commitSuccess) {
                Write-Log "Local commit failed, terminating sync" -Level "ERROR"
                return $false
            }
            Write-Log "Local changes committed" -Level "INFO"
            $didCommit = $true
        }
    }

    # 获取本地和远程的分歧状态
    $div = Get-Divergence
    Write-Log "Branch status: Local ahead $($div.Ahead) commits, remote ahead $($div.Behind) commits" -Level "INFO"

    # 边界情形处理：刚刚提交后需要重新检查分歧状态
    if (-not $DryRunMode -and $didCommit) {
        Write-Log "Just completed local commit, rechecking divergence status..." -Level "INFO"
        # 重新获取分歧状态
        $div = Get-Divergence
        Write-Log "Post-commit branch status: Local ahead $($div.Ahead) commits, remote ahead $($div.Behind) commits" -Level "INFO"

        # 如果本地有领先的提交，推送到所有远程仓库
        if ($div.Ahead -gt 0) {
            Write-Log "Local has new commits, pushing to all remotes..." -Level "INFO"
            $pushArgs = @()
            if ($ForceWithLease) { $pushArgs += '--force-with-lease' }

            $pushResult = Invoke-MultiRemotePush -Remotes $RemoteNames -PushArgs $pushArgs -MaxRetries 3 -DryRunMode:$false
            if (-not $pushResult) {
                Write-Log "Multi-remote push failed" -Level "ERROR"
                return $false
            }
            Write-Log "Multi-remote push successful" -Level "INFO"
            return $true
        }
        # 如果分歧为 0/0，可能是检测问题，尝试保障性推送
        elseif ($div.Ahead -eq 0 -and $div.Behind -eq 0) {
            Write-Log "Divergence detected as 0/0, performing safety push to all remotes..." -Level "WARN"
            $pushResult = Invoke-MultiRemotePush -Remotes $RemoteNames -PushArgs @() -MaxRetries 1 -DryRunMode:$false
            if ($pushResult) {
                Write-Log "Safety push successful" -Level "INFO"
            } else {
                Write-Log "Safety push had no effect (may already be synced)" -Level "INFO"
            }
            return $true
        }
    }

    if ($DryRunMode) {
        Write-Host "[DryRun] Sync strategy preview:" -ForegroundColor Yellow
        if ($div.Behind -gt 0 -and $div.Ahead -gt 0) {
            Write-Host " - Both local and remote have new commits, will perform rebase merge" -ForegroundColor Yellow
            Write-Host " - Commands to execute:" -ForegroundColor DarkYellow
            Write-Host "    git pull --rebase --autostash" -ForegroundColor DarkYellow
            $pushArgs = @()
            if ($ForceWithLease) { $pushArgs += '--force-with-lease' }
            $result = Invoke-MultiRemotePush -Remotes $RemoteNames -PushArgs $pushArgs -DryRunMode:$true
        } elseif ($div.Behind -gt 0) {
            Write-Host " - Remote updates, will pull remote changes" -ForegroundColor Yellow
            Write-Host " - Commands to execute:" -ForegroundColor DarkYellow
            Write-Host "    git pull --rebase --autostash" -ForegroundColor DarkYellow
        } elseif ($div.Ahead -gt 0) {
            Write-Host " - Local updates, will push to all remotes" -ForegroundColor Yellow
            Write-Host " - Commands to execute:" -ForegroundColor DarkYellow
            $pushArgs = @()
            if ($ForceWithLease) { $pushArgs += '--force-with-lease' }
            $result = Invoke-MultiRemotePush -Remotes $RemoteNames -PushArgs $pushArgs -DryRunMode:$true
        } else {
            Write-Host " - Local and remote are synced, no action needed" -ForegroundColor Green
        }
        return $true
    }

    # 执行同步策略
    if ($div.Behind -gt 0 -and $div.Ahead -gt 0) {
        # 本地和远程都有新提交，使用 rebase 保持线性历史
        Write-Log "Both local and remote have new commits, performing rebase merge..." -Level "WARN"
        # 拉取（带重试与退避）
        $maxRetries = 3; $delayMs = 500; $pullOk = $false
        for ($i = 1; $i -le $maxRetries -and -not $pullOk; $i++) {
            git pull --rebase --autostash 2>$null
            $pullOk = ($LASTEXITCODE -eq 0)
            if (-not $pullOk) {
                Write-Log "Pull failed (retry $i/$maxRetries)" -Level "WARN"
                Start-Sleep -Milliseconds $delayMs; $delayMs = [Math]::Min($delayMs * 2, 4000)
            }
        }
        if (-not $pullOk) {
            Write-Log "Rebase failed, conflicts may exist, please resolve manually" -Level "ERROR"
            $conflicts = git diff --name-only --diff-filter=U 2>$null
            if ($conflicts) {
                Write-Host "Files with conflicts:" -ForegroundColor Yellow
                $conflicts | ForEach-Object { Write-Host "  * $_" -ForegroundColor Yellow }
                Write-Host "Resolution steps:" -ForegroundColor Yellow
                Write-Host "  1) Fix conflict markers in files and save" -ForegroundColor Yellow
                Write-Host "  2) git add <file> (after all fixes)" -ForegroundColor Yellow
                Write-Host "  3) git rebase --continue (or git rebase --abort to cancel)" -ForegroundColor Yellow
            }
            return $false
        }
        Write-Log "Rebase successful, now pushing merged commits to all remotes..." -Level "INFO"
        # 推送到所有远程仓库
        $pushArgs = @()
        if ($ForceWithLease) { $pushArgs += '--force-with-lease' }

        $pushResult = Invoke-MultiRemotePush -Remotes $RemoteNames -PushArgs $pushArgs -MaxRetries 3 -DryRunMode:$false
        if (-not $pushResult) {
            Write-Log "Multi-remote push failed" -Level "ERROR"
            return $false
        }
        Write-Log "Sync completed: merged remote changes and pushed local commits to all remotes" -Level "INFO"
    } elseif ($div.Behind -gt 0) {
        # 仅远程有新提交，直接拉取
        Write-Log "Remote has new commits, pulling..." -Level "INFO"
        # 拉取（带重试与退避）
        $maxRetries = 3; $delayMs = 500; $pullOk = $false
        for ($i = 1; $i -le $maxRetries -and -not $pullOk; $i++) {
            git pull --rebase --autostash 2>$null
            $pullOk = ($LASTEXITCODE -eq 0)
            if (-not $pullOk) {
                Write-Log "Pull failed (retry $i/$maxRetries)" -Level "WARN"
                Start-Sleep -Milliseconds $delayMs; $delayMs = [Math]::Min($delayMs * 2, 4000)
            }
        }
        if (-not $pullOk) {
            Write-Log "Pull failed" -Level "ERROR"
            $conflicts = git diff --name-only --diff-filter=U 2>$null
            if ($conflicts) {
                Write-Host "Files with conflicts:" -ForegroundColor Yellow
                $conflicts | ForEach-Object { Write-Host "  * $_" -ForegroundColor Yellow }
                Write-Host "Resolution steps:" -ForegroundColor Yellow
                Write-Host "  1) Fix conflict markers in files and save" -ForegroundColor Yellow
                Write-Host "  2) git add <file> (after all fixes)" -ForegroundColor Yellow
                Write-Host "  3) git rebase --continue (or git rebase --abort to cancel)" -ForegroundColor Yellow
            }
            return $false
        }
        Write-Log "Sync completed: pulled remote changes" -Level "INFO"
    } elseif ($div.Ahead -gt 0) {
        # 仅本地有新提交，推送到所有远程仓库
        Write-Log "Local has new commits, pushing to all remotes..." -Level "INFO"
        $pushArgs = @()
        if ($ForceWithLease) { $pushArgs += '--force-with-lease' }

        $pushResult = Invoke-MultiRemotePush -Remotes $RemoteNames -PushArgs $pushArgs -MaxRetries 3 -DryRunMode:$false
        if (-not $pushResult) {
            Write-Log "Multi-remote push failed" -Level "ERROR"
            return $false
        }
        Write-Log "Sync completed: pushed local commits to all remotes" -Level "INFO"
    } else {
        # 本地和远程已同步
        Write-Log "Local and remote are synced, no action needed" -Level "INFO"
    }

    return $true
}

function New-CommitMessage {
    param(
        [hashtable]$Changes,
        [string]$CustomMessage
    )

    if ($CustomMessage) {
        return $CustomMessage
    }

    $AddedCount = $Changes.Added.Count
    $ModifiedCount = $Changes.Modified.Count
    $DeletedCount = $Changes.Deleted.Count
    $UntrackedCount = $Changes.Untracked.Count

    $Actions = @()
    if ($AddedCount -gt 0) { $Actions += "add $AddedCount files" }
    if ($ModifiedCount -gt 0) { $Actions += "modify $ModifiedCount files" }
    if ($DeletedCount -gt 0) { $Actions += "remove $DeletedCount files" }
    if ($UntrackedCount -gt 0) { $Actions += "add $UntrackedCount new files" }

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    return "Auto commit: " + ($Actions -join ", ") + " - $Timestamp"
}

function Invoke-GitCommit {
    param(
        [hashtable]$Changes,
        [string]$CommitMessage,
        [switch]$PushToRemote,
        [switch]$DryRunMode,
        [string[]]$RemoteNames = @("origin", "gitcode")
    )

    try {
        # 显示变更摘要
        Write-Host "`n=== File Changes Summary ===" -ForegroundColor Cyan

        if ($Changes.Added.Count -gt 0) {
            Write-Host "New files ($($Changes.Added.Count)):" -ForegroundColor Green
            $Changes.Added | ForEach-Object { Write-Host "  + $_" -ForegroundColor Green }
        }

        if ($Changes.Modified.Count -gt 0) {
            Write-Host "Modified files ($($Changes.Modified.Count)):" -ForegroundColor Yellow
            $Changes.Modified | ForEach-Object { Write-Host "  ~ $_" -ForegroundColor Yellow }
        }

        if ($Changes.Deleted.Count -gt 0) {
            Write-Host "Deleted files ($($Changes.Deleted.Count)):" -ForegroundColor Red
            $Changes.Deleted | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        }

        if ($Changes.Untracked.Count -gt 0) {
            Write-Host "Untracked files ($($Changes.Untracked.Count)):" -ForegroundColor Magenta
            $Changes.Untracked | ForEach-Object { Write-Host "  ? $_" -ForegroundColor Magenta }
        }

        Write-Host "`n=== Commit Message ===" -ForegroundColor Cyan
        Write-Host $CommitMessage -ForegroundColor White
        Write-Host ""

        if ($DryRunMode) {
            Write-Host "=== Preview Mode - Will not actually execute commit ===" -ForegroundColor Yellow
            return $true
        }

        # 添加所有变更到暂存区
        Write-Log "Adding files to staging area..." -Level "INFO"
        $addOutput = git add . 2>&1
        # Git warnings about CRLF/LF are not errors, only fail on actual errors
        if ($LASTEXITCODE -ne 0) {
            # Check if it's just warnings
            $isOnlyWarnings = $true
            foreach ($line in $addOutput) {
                if ($line -notmatch "^warning:" -and $line.Trim() -ne "") {
                    $isOnlyWarnings = $false
                    break
                }
            }
            if (-not $isOnlyWarnings) {
                Write-Log "Failed to add files to staging area: $($addOutput -join "`n")" -Level "ERROR"
                return $false
            }
        }

        # 执行提交
        Write-Log "Executing commit..." -Level "INFO"
        git commit -m $CommitMessage 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Commit failed" -Level "ERROR"
            return $false
        }

        Write-Log "Commit successful" -Level "INFO"

        # 推送到远程仓库（如果需要）
        if ($PushToRemote) {
            $branch = Get-CurrentBranch
            if (-not $branch) { Write-Log "Cannot determine current branch, skipping push" -Level "ERROR"; return $false }

            if (-not (Test-BranchHasUpstream)) {
                Write-Log "No upstream branch detected, setting and pushing: origin/$branch" -Level "WARN"
                git push -u origin $branch 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Log "Failed to set upstream branch" -Level "ERROR"
                    return $false
                }
            }

            Write-Log "Pushing to all configured remotes..." -Level "INFO"
            $pushResult = Invoke-MultiRemotePush -Remotes $RemoteNames -PushArgs @() -MaxRetries 3 -DryRunMode:$false
            if (-not $pushResult) {
                Write-Log "Multi-remote push failed" -Level "ERROR"
                return $false
            }
            Write-Log "Multi-remote push successful" -Level "INFO"
        }

        return $true
    }
    catch {
        Write-Log "Error occurred during commit process: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Main {
    try {
        Write-Host "=== Intelligent Auto-Commit and Sync Tool ===" -ForegroundColor Cyan
        Write-Host ""

        # 检查Git仓库
        if (-not (Test-GitRepository)) {
            Write-Log "Current directory is not a Git repository" -Level "ERROR"
            return $false
        }

        # 创建备份（如果需要）
        if ($BackupFirst) {
            Write-Log "Creating pre-sync backup..." -Level "INFO"
            $backupResult = New-ProjectBackup -BackupReason "Pre-sync backup"
            if (-not $backupResult) {
                Write-Log "Backup failed, sync cancelled" -Level "ERROR"
                return $false
            }
        }

        # 默认使用 Auto 模式进行智能同步，除非明确指定了其他参数
        if ($Auto -or (-not $Push -and -not $Message -and -not $DryRun)) {
            Write-Log "Using intelligent sync mode" -Level "INFO"
            return Invoke-AutoSync -DryRunMode:$DryRun
        }

        # 手动模式：获取变更
        $Changes = Get-GitChanges

        # 检查是否有变更
        $TotalChanges = $Changes.Added.Count + $Changes.Modified.Count + $Changes.Deleted.Count + $Changes.Untracked.Count
        if ($TotalChanges -eq 0) {
            Write-Log "No local file changes detected" -Level "INFO"

            # 即使没有本地变更，也检查是否有未推送的提交
            $div = Get-Divergence
            if ($div.Ahead -gt 0) {
                Write-Log "Detected $($div.Ahead) unpushed commits, pushing to all remotes..." -Level "INFO"
                if (-not $DryRun) {
                    $pushArgs = @()
                    if ($ForceWithLease) { $pushArgs += '--force-with-lease' }

                    $pushResult = Invoke-MultiRemotePush -Remotes $RemoteNames -PushArgs $pushArgs -MaxRetries 3 -DryRunMode:$false
                    if (-not $pushResult) {
                        Write-Log "Multi-remote push failed" -Level "ERROR"
                        return $false
                    }
                    Write-Log "Multi-remote push successful" -Level "INFO"
                }
            } else {
                Write-Log "Local and remote are synced" -Level "INFO"
            }
            return $true
        }

        Write-Log "Detected $TotalChanges changed files" -Level "INFO"

        # 生成提交消息
        $CommitMessage = New-CommitMessage -Changes $Changes -CustomMessage $Message

        # 在手动模式下，默认也推送到远程（除非明确指定不推送）
        $ShouldPush = $Push -or (-not $PSBoundParameters.ContainsKey('Push'))

        # 执行提交
        $Success = Invoke-GitCommit -Changes $Changes -CommitMessage $CommitMessage -PushToRemote:$ShouldPush -DryRunMode:$DryRun -RemoteNames $RemoteNames

        if ($Success) {
            Write-Host "Operation completed successfully" -ForegroundColor Green
        } else {
            Write-Host "Operation failed" -ForegroundColor Red
            return $false
        }

        return $true
    }
    catch {
        Write-Log "Exception occurred in Main function: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# 执行主程序
if ($MyInvocation.InvocationName -ne '.') {
    $Success = Main
    if (-not $Success) {
        exit 1
    }
}
