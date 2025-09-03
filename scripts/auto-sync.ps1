#Requires -Version 5.1

<#
.SYNOPSIS
    智能自动提交和同步脚本

.DESCRIPTION
    提供智能的 Git 配置同步功能，自动处理本地和远程的差异：
    1. 检测本地未提交更改，自动提交
    2. 对比本地和远程分支状态
    3. 根据情况执行推送、拉取或合并操作
    4. 保持配置在多设备间同步

.PARAMETER Push
    是否推送到远程仓库（仅在非 Auto 模式下有效）

.PARAMETER DryRun
    预览模式，显示将要执行的操作但不实际执行

.PARAMETER Message
    自定义提交消息

.PARAMETER Auto
    智能自动同步模式：
    - 自动提交本地未提交的更改
    - 对比本地与远程分支状态
    - 本地领先：推送到远程
    - 远程领先：拉取远程更改
    - 双方都有更新：使用 rebase 合并

.EXAMPLE
    .\auto-sync.ps1 -Auto
    执行智能自动同步

.EXAMPLE
    .\auto-sync.ps1 -Auto -DryRun
    预览同步操作

.EXAMPLE
    .\auto-sync.ps1 -Message "更新配置" -Push
    手动提交并推送

.NOTES
    建议使用 -Auto 参数进行智能同步，脚本会自动处理各种情况
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

    # 强制执行详细的 fetch（含 --force），用于排查远程可见性问题
    [Parameter(Mandatory = $false)]
    [switch]$ForceFetch,

    # 推送时使用 --force-with-lease（更安全的强制推送）
    [Parameter(Mandatory = $false)]
    [switch]$ForceWithLease
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
 
 # Log level used for safety-push messages (e.g., after a commit but divergence shows 0/0)
 # Options: "INFO" | "WARN" | "ERROR"
 $SafetyPushLogLevel = "INFO"

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
        Write-Log "获取Git变更失败: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Get-CurrentBranch {
    try {
        $name = git rev-parse --abbrev-ref HEAD 2>$null
        return $name
    } catch { return $null }
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
    Write-Log "未检测到上游分支，设置: origin/$branch" -Level "WARN"
    git push -u origin $branch 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Get-Divergence {
    # 返回 @{ Ahead = <int>; Behind = <int> }
    try {
        # 首先尝试 fetch 获取最新的远程状态
        Write-Log "正在获取远程最新状态..." -Level "INFO"
        
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
                    if ($fetchOutput) { Write-Verbose ("fetch 输出:`n" + ($fetchOutput -join "`n")) }
                } else {
                    & git fetch @fetchArgs 2>$null
                }
                $success = ($LASTEXITCODE -eq 0)
            }
            catch {
                $success = $false
            }
            
            if (-not $success -and $i -lt $maxRetries) {
                Write-Log "git fetch 失败，重试 $($i+1)/$maxRetries..." -Level "WARN"
                Start-Sleep -Seconds 1
            }
        }
        
        if (-not $success) {
            Write-Log "git fetch 失败，使用本地缓存的远程状态" -Level "WARN"
        }
        
        # 检查是否有上游分支
        if (-not (Test-BranchHasUpstream)) {
            Write-Log "未检测到上游分支，尝试自动设置..." -Level "WARN"
            $branch = Get-CurrentBranch
            if ($branch) {
                # 尝试设置上游分支
                git push -u origin $branch 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "已设置上游分支: origin/$branch" -Level "INFO"
                } else {
                    Write-Log "无法设置上游分支，返回默认分歧状态" -Level "WARN"
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
                Write-Verbose ("rev-list 输出: '$counts'")
            }
        }
        catch {
            $counts = $null
        }
        
        if (-not $counts -or $counts.Trim() -eq '') {
            Write-Log "无法获取分歧计数，可能分支完全同步" -Level "INFO"
            return @{ Ahead = 0; Behind = 0 }
        }
        
        # 解析分歧计数
        $parts = @($counts.Trim() -split '\s+') | Where-Object { $_ -ne '' -and $_ -match '^\d+$' }
        if ($parts.Count -lt 2) {
            Write-Log "分歧计数格式异常: '$counts'，假设同步状态" -Level "WARN"
            return @{ Ahead = 0; Behind = 0 }
        }
        
        $ahead = [int]$parts[0]
        $behind = [int]$parts[1]
        
        Write-Log "分歧状态：本地领先 $ahead 个提交，远程领先 $behind 个提交" -Level "INFO"
        return @{ Ahead = $ahead; Behind = $behind }
        
    } catch {
        Write-Log "获取分歧信息时发生异常: $($_.Exception.Message)" -Level "ERROR"
        return @{ Ahead = 0; Behind = 0 }
    }
}

function Invoke-AutoSync {
    param(
        [switch]$DryRunMode
    )
    Write-Host "=== 智能自动同步模式（AutoSync）===" -ForegroundColor Cyan
    if (-not (Test-GitRepository)) { Write-Log "当前目录不是Git仓库" -Level "ERROR"; return $false }

    $branch = Get-CurrentBranch
    if (-not $branch) { Write-Log "无法确定当前分支" -Level "ERROR"; return $false }

    if (-not (Ensure-Upstream)) { Write-Log "无法设置/确认上游分支" -Level "ERROR"; return $false }
    $didCommit = $false

    # 先检查本地是否有未提交的更改
    $changes = Get-GitChanges
    $hasLocalChanges = ($changes.Added.Count + $changes.Modified.Count + $changes.Deleted.Count + $changes.Untracked.Count) -gt 0

    # 如果有本地更改，先提交
    if ($hasLocalChanges) {
        Write-Log "检测到本地未提交更改，先进行本地提交..." -Level "INFO"
        if ($DryRunMode) {
            Write-Host "[DryRun] 将先提交本地更改" -ForegroundColor Yellow
        } else {
            $commitMsg = New-CommitMessage -Changes $changes -CustomMessage $Message
            $commitSuccess = Invoke-GitCommit -Changes $changes -CommitMessage $commitMsg -PushToRemote:$false -DryRunMode:$false
            if (-not $commitSuccess) {
                Write-Log "本地提交失败，终止同步" -Level "ERROR"
                return $false
            }
            Write-Log "本地更改已提交" -Level "INFO"
            $didCommit = $true
        }
    }

    # 获取本地和远程的分歧状态
    $div = Get-Divergence
    Write-Log "分支状态：本地领先 $($div.Ahead) 个提交，远程领先 $($div.Behind) 个提交" -Level "INFO"

    # 边界情形处理：刚刚提交后需要重新检查分歧状态
    if (-not $DryRunMode -and $didCommit) {
        Write-Log "刚完成本地提交，重新检查分歧状态..." -Level "INFO"
        # 重新获取分歧状态
        $div = Get-Divergence
        Write-Log "提交后分支状态：本地领先 $($div.Ahead) 个提交，远程领先 $($div.Behind) 个提交" -Level "INFO"
        
        # 如果本地有领先的提交，直接推送
        if ($div.Ahead -gt 0) {
            Write-Log "本地有新提交，正在推送..." -Level "INFO"
            $pushArgs = @()
            if ($ForceWithLease) { $pushArgs += '--force-with-lease' }
            
            $maxRetries = 3
            $pushOk = $false
            for ($i = 1; $i -le $maxRetries -and -not $pushOk; $i++) {
                if ($pushArgs.Count -gt 0) { 
                    git push @pushArgs 2>$null 
                } else { 
                    git push 2>$null 
                }
                $pushOk = ($LASTEXITCODE -eq 0)
                if (-not $pushOk -and $i -lt $maxRetries) {
                    Write-Log "推送失败，重试 $($i+1)/$maxRetries..." -Level "WARN"
                    Start-Sleep -Seconds 1
                }
            }
            
            if (-not $pushOk) {
                Write-Log "推送失败" -Level "ERROR"
                return $false
            }
            Write-Log "推送成功" -Level "INFO"
            return $true
        }
        # 如果分歧为 0/0，可能是检测问题，尝试保障性推送
        elseif ($div.Ahead -eq 0 -and $div.Behind -eq 0) {
            Write-Log "分歧检测为 0/0，执行保障性推送..." -Level "WARN"
            git push 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Log "保障性推送成功" -Level "INFO"
            } else {
                Write-Log "保障性推送无效果（可能已同步）" -Level "INFO"
            }
            return $true
        }
    }

    if ($DryRunMode) {
        Write-Host "[DryRun] 同步策略预览：" -ForegroundColor Yellow
        if ($div.Behind -gt 0 -and $div.Ahead -gt 0) {
            Write-Host " - 本地和远程都有新提交，将执行 rebase 合并" -ForegroundColor Yellow
            Write-Host " - 将执行的命令：" -ForegroundColor DarkYellow
            Write-Host "    git pull --rebase --autostash" -ForegroundColor DarkYellow
            if ($ForceWithLease) { Write-Host "    git push --force-with-lease" -ForegroundColor DarkYellow } else { Write-Host "    git push" -ForegroundColor DarkYellow }
        } elseif ($div.Behind -gt 0) {
            Write-Host " - 远程更新，将拉取远程更改" -ForegroundColor Yellow
            Write-Host " - 将执行的命令：" -ForegroundColor DarkYellow
            Write-Host "    git pull --rebase --autostash" -ForegroundColor DarkYellow
        } elseif ($div.Ahead -gt 0) {
            Write-Host " - 本地更新，将推送到远程" -ForegroundColor Yellow
            Write-Host " - 将执行的命令：" -ForegroundColor DarkYellow
            if ($ForceWithLease) { Write-Host "    git push --force-with-lease" -ForegroundColor DarkYellow } else { Write-Host "    git push" -ForegroundColor DarkYellow }
        } else {
            Write-Host " - 本地和远程已同步，无需操作" -ForegroundColor Green
        }
        return $true
    }

    # 执行同步策略
    if ($div.Behind -gt 0 -and $div.Ahead -gt 0) {
        # 本地和远程都有新提交，使用 rebase 保持线性历史
        Write-Log "本地和远程都有新提交，执行 rebase 合并..." -Level "WARN"
        # 拉取（带重试与退避）
        $maxRetries = 3; $delayMs = 500; $pullOk = $false
        for ($i = 1; $i -le $maxRetries -and -not $pullOk; $i++) {
            git pull --rebase --autostash 2>$null
            $pullOk = ($LASTEXITCODE -eq 0)
            if (-not $pullOk) {
                Write-Log "拉取失败（重试 $i/$maxRetries）" -Level "WARN"
                Start-Sleep -Milliseconds $delayMs; $delayMs = [Math]::Min($delayMs * 2, 4000)
            }
        }
        if (-not $pullOk) {
            Write-Log "Rebase 失败，可能存在冲突，请手动解决" -Level "ERROR"
            $conflicts = git diff --name-only --diff-filter=U 2>$null
            if ($conflicts) {
                Write-Host "以下文件存在冲突：" -ForegroundColor Yellow
                $conflicts | ForEach-Object { Write-Host "  * $_" -ForegroundColor Yellow }
                Write-Host "解决步骤：" -ForegroundColor Yellow
                Write-Host "  1) 按文件修复冲突标记并保存" -ForegroundColor Yellow
                Write-Host "  2) git add <文件>（全部修复后）" -ForegroundColor Yellow
                Write-Host "  3) git rebase --continue（或 git rebase --abort 放弃）" -ForegroundColor Yellow
            }
            return $false
        }
        Write-Log "Rebase 成功，现在推送合并后的提交..." -Level "INFO"
        # 推送（可选 --force-with-lease + 重试）
        $pushArgs = @()
        if ($ForceWithLease) { $pushArgs += '--force-with-lease' }
        $maxRetries = 3; $delayMs = 500; $pushOk = $false
        for ($i = 1; $i -le $maxRetries -and -not $pushOk; $i++) {
            if ($pushArgs.Count -gt 0) { git push @pushArgs 2>$null } else { git push 2>$null }
            $pushOk = ($LASTEXITCODE -eq 0)
            if (-not $pushOk) {
                Write-Log "推送失败（重试 $i/$maxRetries）" -Level "WARN"
                Start-Sleep -Milliseconds $delayMs; $delayMs = [Math]::Min($delayMs * 2, 4000)
            }
        }
        if (-not $pushOk) {
            Write-Log "推送失败" -Level "ERROR"
            return $false
        }
        Write-Log "同步完成：已合并远程更改并推送本地提交" -Level "INFO"
    } elseif ($div.Behind -gt 0) {
        # 仅远程有新提交，直接拉取
        Write-Log "远程有新提交，正在拉取..." -Level "INFO"
        # 拉取（带重试与退避）
        $maxRetries = 3; $delayMs = 500; $pullOk = $false
        for ($i = 1; $i -le $maxRetries -and -not $pullOk; $i++) {
            git pull --rebase --autostash 2>$null
            $pullOk = ($LASTEXITCODE -eq 0)
            if (-not $pullOk) {
                Write-Log "拉取失败（重试 $i/$maxRetries）" -Level "WARN"
                Start-Sleep -Milliseconds $delayMs; $delayMs = [Math]::Min($delayMs * 2, 4000)
            }
        }
        if (-not $pullOk) {
            Write-Log "拉取失败" -Level "ERROR"
            $conflicts = git diff --name-only --diff-filter=U 2>$null
            if ($conflicts) {
                Write-Host "以下文件存在冲突：" -ForegroundColor Yellow
                $conflicts | ForEach-Object { Write-Host "  * $_" -ForegroundColor Yellow }
                Write-Host "解决步骤：" -ForegroundColor Yellow
                Write-Host "  1) 按文件修复冲突标记并保存" -ForegroundColor Yellow
                Write-Host "  2) git add <文件>（全部修复后）" -ForegroundColor Yellow
                Write-Host "  3) git rebase --continue（或 git rebase --abort 放弃）" -ForegroundColor Yellow
            }
            return $false
        }
        Write-Log "同步完成：已拉取远程更改" -Level "INFO"
    } elseif ($div.Ahead -gt 0) {
        # 仅本地有新提交，直接推送
        Write-Log "本地有新提交，正在推送..." -Level "INFO"
        # 推送（可选 --force-with-lease + 重试）
        $pushArgs = @()
        if ($ForceWithLease) { $pushArgs += '--force-with-lease' }
        $maxRetries = 3; $delayMs = 500; $pushOk = $false
        for ($i = 1; $i -le $maxRetries -and -not $pushOk; $i++) {
            if ($pushArgs.Count -gt 0) { git push @pushArgs 2>$null } else { git push 2>$null }
            $pushOk = ($LASTEXITCODE -eq 0)
            if (-not $pushOk) {
                Write-Log "推送失败（重试 $i/$maxRetries）" -Level "WARN"
                Start-Sleep -Milliseconds $delayMs; $delayMs = [Math]::Min($delayMs * 2, 4000)
            }
        }
        if (-not $pushOk) {
            Write-Log "推送失败" -Level "ERROR"
            return $false
        }
        Write-Log "同步完成：已推送本地提交" -Level "INFO"
    } else {
        # 本地和远程已同步
        Write-Log "本地和远程已同步，无需操作" -Level "INFO"
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
        [switch]$DryRunMode
    )
    
    try {
        # 显示变更摘要
        Write-Host "`n=== 文件变更摘要 ===" -ForegroundColor Cyan
        
        if ($Changes.Added.Count -gt 0) {
            Write-Host "新增文件 ($($Changes.Added.Count)):" -ForegroundColor Green
            $Changes.Added | ForEach-Object { Write-Host "  + $_" -ForegroundColor Green }
        }
        
        if ($Changes.Modified.Count -gt 0) {
            Write-Host "修改文件 ($($Changes.Modified.Count)):" -ForegroundColor Yellow
            $Changes.Modified | ForEach-Object { Write-Host "  ~ $_" -ForegroundColor Yellow }
        }
        
        if ($Changes.Deleted.Count -gt 0) {
            Write-Host "删除文件 ($($Changes.Deleted.Count)):" -ForegroundColor Red
            $Changes.Deleted | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        }
        
        if ($Changes.Untracked.Count -gt 0) {
            Write-Host "未跟踪文件 ($($Changes.Untracked.Count)):" -ForegroundColor Magenta
            $Changes.Untracked | ForEach-Object { Write-Host "  ? $_" -ForegroundColor Magenta }
        }
        
        Write-Host "`n=== 提交消息 ===" -ForegroundColor Cyan
        Write-Host $CommitMessage -ForegroundColor White
        Write-Host ""
        
        if ($DryRunMode) {
            Write-Host "=== 预览模式 - 不会实际执行提交 ===" -ForegroundColor Yellow
            return $true
        }
        
        # 添加所有变更到暂存区
        Write-Log "添加文件到暂存区..." -Level "INFO"
        git add . 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "添加文件到暂存区失败" -Level "ERROR"
            return $false
        }
        
        # 执行提交
        Write-Log "执行提交..." -Level "INFO"
        git commit -m $CommitMessage 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "提交失败" -Level "ERROR"
            return $false
        }
        
        Write-Log "提交成功" -Level "INFO"
        
        # 推送到远程（如果需要）
        if ($PushToRemote) {
            $branch = Get-CurrentBranch
            if (-not $branch) { Write-Log "无法确定当前分支，跳过推送" -Level "ERROR"; return $false }

            if (-not (Test-BranchHasUpstream)) {
                Write-Log "未检测到上游分支，正在设置并推送: origin/$branch" -Level "WARN"
                git push -u origin $branch 2>$null
            } else {
                Write-Log "检测到上游分支，直接推送" -Level "INFO"
                git push 2>$null
            }

            if ($LASTEXITCODE -eq 0) {
                Write-Log "推送成功" -Level "INFO"
            } else {
                Write-Log "推送失败" -Level "ERROR"
                return $false
            }
        }
        
        return $true
    }
    catch {
        Write-Log "提交过程中发生错误: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Main {
    try {
        Write-Host "=== 智能自动提交与同步工具 ===" -ForegroundColor Cyan
        Write-Host ""
        
        # 检查Git仓库
        if (-not (Test-GitRepository)) {
            Write-Log "当前目录不是Git仓库" -Level "ERROR"
            return $false
        }
        
        # 默认使用 Auto 模式进行智能同步，除非明确指定了其他参数
        if ($Auto -or (-not $Push -and -not $Message -and -not $DryRun)) {
            Write-Log "使用智能同步模式" -Level "INFO"
            return (Invoke-AutoSync -DryRunMode:$DryRun)
        }

        # 手动模式：获取变更
        $Changes = Get-GitChanges
        
        # 检查是否有变更
        $TotalChanges = $Changes.Added.Count + $Changes.Modified.Count + $Changes.Deleted.Count + $Changes.Untracked.Count
        if ($TotalChanges -eq 0) {
            Write-Log "没有检测到本地文件变更" -Level "INFO"
            
            # 即使没有本地变更，也检查是否有未推送的提交
            $div = Get-Divergence
            if ($div.Ahead -gt 0) {
                Write-Log "检测到 $($div.Ahead) 个未推送的提交，正在推送..." -Level "INFO"
                if (-not $DryRun) {
                    git push 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "推送成功" -Level "INFO"
                    } else {
                        Write-Log "推送失败" -Level "ERROR"
                        return $false
                    }
                }
            } else {
                Write-Log "本地和远程已同步" -Level "INFO"
            }
            return $true
        }
        
        Write-Log "检测到 $TotalChanges 个变更文件" -Level "INFO"
        
        # 生成提交消息
        $CommitMessage = New-CommitMessage -Changes $Changes -CustomMessage $Message
        
        # 在手动模式下，默认也推送到远程（除非明确指定不推送）
        $ShouldPush = $Push -or (-not $PSBoundParameters.ContainsKey('Push'))
        
        # 执行提交
        $Success = Invoke-GitCommit -Changes $Changes -CommitMessage $CommitMessage -PushToRemote:$ShouldPush -DryRunMode:$DryRun
        
        if ($Success) {
            Write-Host "✅ 操作完成" -ForegroundColor Green
        } else {
            Write-Host "❌ 操作失败" -ForegroundColor Red
            return $false
        }
        
        return $true
    }
    catch {
        Write-Log "程序执行失败: $($_.Exception.Message)" -Level "ERROR"
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