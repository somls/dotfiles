<#
.SYNOPSIS
    Git 仓库清理脚本

.DESCRIPTION
    清理 Git 仓库中的过时分支、标签和对象，优化仓库大小和性能

.PARAMETER RemoteCleanup
    是否清理远程分支 (默认: $false)

.PARAMETER PruneOrigin
    是否修剪远程跟踪分支 (默认: $true)

.PARAMETER DeleteMergedBranches
    是否删除已合并的本地分支 (默认: $true)

.PARAMETER GarbageCollect
    是否运行垃圾回收 (默认: $true)

.PARAMETER AggressiveGC
    是否运行积极的垃圾回收 (默认: $false)

.PARAMETER Force
    强制执行操作，不提示确认 (默认: $false)

.PARAMETER DryRun
    仅显示将执行的操作，不实际执行 (默认: $false)

.EXAMPLE
    .\git-cleanup.ps1

.EXAMPLE
    .\git-cleanup.ps1 -RemoteCleanup -AggressiveGC

.EXAMPLE
    .\git-cleanup.ps1 -DryRun -DeleteMergedBranches
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [switch]$RemoteCleanup = $false,

    [Parameter(Mandatory = $false)]
    [switch]$PruneOrigin = $true,

    [Parameter(Mandatory = $false)]
    [switch]$DeleteMergedBranches = $true,

    [Parameter(Mandatory = $false)]
    [switch]$GarbageCollect = $true,

    [Parameter(Mandatory = $false)]
    [switch]$AggressiveGC = $false,

    [Parameter(Mandatory = $false)]
    [switch]$Force = $false,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun = $false
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

# 获取当前分支名称
function Get-CurrentBranch {
    try {
        $branch = git symbolic-ref --short HEAD 2>$null
        if (-not $branch) {
            $branch = git rev-parse --short HEAD 2>$null
            return "detached HEAD ($branch)"
        }
        return $branch
    }
    catch {
        return "unknown"
    }
}

# 获取默认分支名称
function Get-DefaultBranch {
    # 尝试从 origin 获取默认分支
    try {
        $remoteBranch = git symbolic-ref refs/remotes/origin/HEAD 2>$null
        if ($remoteBranch) {
            return $remoteBranch -replace "refs/remotes/origin/", ""
        }
    }
    catch {
        # 忽略错误
    }

    # 尝试常见的默认分支名称
    $commonBranches = @("main", "master", "develop", "trunk")
    foreach ($branch in $commonBranches) {
        $exists = git show-ref --verify --quiet refs/heads/$branch 2>$null
        if ($?) {
            return $branch
        }
    }

    # 如果找不到默认分支，返回 null
    return $null
}

# 获取已合并的分支列表
function Get-MergedBranches {
    param (
        [string]$DefaultBranch
    )

    $currentBranch = Get-CurrentBranch
    $branches = @()

    # 如果当前不在默认分支上，尝试切换到默认分支
    $needSwitch = $currentBranch -ne $DefaultBranch
    if ($needSwitch) {
        Write-Host "切换到默认分支 '$DefaultBranch' 以检查已合并的分支..." -ForegroundColor $colorInfo
        if (-not $DryRun) {
            git checkout $DefaultBranch | Out-Null
            if (-not $?) {
                Write-Host "无法切换到默认分支 '$DefaultBranch'，将使用当前分支。" -ForegroundColor $colorWarning
                $needSwitch = $false
                $DefaultBranch = $currentBranch
            }
        }
    }

    # 获取已合并的分支
    $mergedBranches = git branch --merged | ForEach-Object { $_.Trim() } | Where-Object { 
        $_ -ne "* $DefaultBranch" -and 
        $_ -ne "* $currentBranch" -and 
        $_ -ne $DefaultBranch -and 
        $_ -ne $currentBranch -and 
        -not $_.StartsWith("*")
    }

    # 切换回原来的分支
    if ($needSwitch -and -not $DryRun) {
        git checkout $currentBranch | Out-Null
    }

    return $mergedBranches
}

# 显示仓库状态
function Show-RepositoryStatus {
    $currentBranch = Get-CurrentBranch
    $defaultBranch = Get-DefaultBranch

    Write-Host "\n仓库状态:" -ForegroundColor $colorInfo
    Write-Host "当前分支: $currentBranch" -ForegroundColor $colorInfo
    Write-Host "默认分支: $defaultBranch" -ForegroundColor $colorInfo

    # 获取本地分支数量
    $localBranches = git branch | Measure-Object | Select-Object -ExpandProperty Count
    Write-Host "本地分支数量: $localBranches" -ForegroundColor $colorInfo

    # 获取远程分支数量
    $remoteBranches = git branch -r | Measure-Object | Select-Object -ExpandProperty Count
    Write-Host "远程跟踪分支数量: $remoteBranches" -ForegroundColor $colorInfo

    # 获取标签数量
    $tags = git tag | Measure-Object | Select-Object -ExpandProperty Count
    Write-Host "标签数量: $tags" -ForegroundColor $colorInfo

    # 获取仓库大小
    $repoSize = git count-objects -v
    $sizeInMB = [math]::Round(($repoSize | Where-Object { $_ -match "size-pack: (\d+)" } | ForEach-Object { $matches[1] }) / 1024, 2)
    Write-Host "仓库大小: $sizeInMB MB" -ForegroundColor $colorInfo

    # 获取松散对象数量
    $looseObjects = $repoSize | Where-Object { $_ -match "count: (\d+)" } | ForEach-Object { $matches[1] }
    Write-Host "松散对象数量: $looseObjects" -ForegroundColor $colorInfo

    # 获取已合并的分支数量
    if ($defaultBranch) {
        $mergedBranches = Get-MergedBranches -DefaultBranch $defaultBranch
        $mergedCount = ($mergedBranches | Measure-Object).Count
        Write-Host "已合并的分支数量: $mergedCount" -ForegroundColor $colorInfo
    }
}

# 清理仓库
function Invoke-GitCleanup {
    $currentBranch = Get-CurrentBranch
    $defaultBranch = Get-DefaultBranch

    if (-not $defaultBranch) {
        Write-Host "警告: 无法确定默认分支。" -ForegroundColor $colorWarning
        $defaultBranch = Read-Host "请输入默认分支名称 (例如 main 或 master)"
        if (-not $defaultBranch) {
            Write-Host "错误: 未提供默认分支名称，无法继续。" -ForegroundColor $colorError
            return
        }
    }

    # 显示将执行的操作
    Write-Host "\n将执行以下清理操作:" -ForegroundColor $colorInfo
    
    if ($PruneOrigin) {
        Write-Host "- 修剪远程跟踪分支" -ForegroundColor $colorInfo
    }
    
    if ($DeleteMergedBranches) {
        Write-Host "- 删除已合并的本地分支" -ForegroundColor $colorInfo
    }
    
    if ($RemoteCleanup) {
        Write-Host "- 清理远程分支" -ForegroundColor $colorWarning
    }
    
    if ($GarbageCollect) {
        if ($AggressiveGC) {
            Write-Host "- 运行积极的垃圾回收" -ForegroundColor $colorWarning
        }
        else {
            Write-Host "- 运行标准垃圾回收" -ForegroundColor $colorInfo
        }
    }

    # 如果不是强制模式，请求确认
    if (-not $Force -and -not $DryRun) {
        $confirmation = Read-Host "是否继续? (y/N)"
        if ($confirmation -ne "y" -and $confirmation -ne "Y") {
            Write-Host "操作已取消。" -ForegroundColor $colorInfo
            return
        }
    }

    # 修剪远程跟踪分支
    if ($PruneOrigin) {
        Write-Host "\n修剪远程跟踪分支..." -ForegroundColor $colorInfo
        $command = "git fetch --prune origin"
        Write-Host "> $command" -ForegroundColor $colorCommand
        
        if (-not $DryRun) {
            git fetch --prune origin
            if ($?) {
                Write-Host "远程跟踪分支已修剪。" -ForegroundColor $colorSuccess
            }
            else {
                Write-Host "修剪远程跟踪分支时出错。" -ForegroundColor $colorError
            }
        }
    }

    # 删除已合并的本地分支
    if ($DeleteMergedBranches) {
        Write-Host "\n删除已合并的本地分支..." -ForegroundColor $colorInfo
        $mergedBranches = Get-MergedBranches -DefaultBranch $defaultBranch
        
        if ($mergedBranches.Count -eq 0) {
            Write-Host "没有找到已合并的分支。" -ForegroundColor $colorInfo
        }
        else {
            Write-Host "找到以下已合并的分支:" -ForegroundColor $colorInfo
            $mergedBranches | ForEach-Object { Write-Host "  - $_" -ForegroundColor $colorInfo }
            
            if (-not $DryRun) {
                foreach ($branch in $mergedBranches) {
                    $command = "git branch -d $branch"
                    Write-Host "> $command" -ForegroundColor $colorCommand
                    git branch -d $branch
                }
                Write-Host "已合并的分支已删除。" -ForegroundColor $colorSuccess
            }
        }
    }

    # 清理远程分支
    if ($RemoteCleanup) {
        Write-Host "\n清理远程分支..." -ForegroundColor $colorWarning
        Write-Host "注意: 此操作将删除远程仓库中的分支，请谨慎使用。" -ForegroundColor $colorWarning
        
        if (-not $DryRun -and -not $Force) {
            $confirmation = Read-Host "是否继续清理远程分支? (y/N)"
            if ($confirmation -ne "y" -and $confirmation -ne "Y") {
                Write-Host "远程分支清理已跳过。" -ForegroundColor $colorInfo
            }
            else {
                # 获取已合并到默认分支的远程分支
                $command = "git branch -r --merged origin/$defaultBranch"
                Write-Host "> $command" -ForegroundColor $colorCommand
                $mergedRemoteBranches = git branch -r --merged origin/$defaultBranch | 
                                        Where-Object { $_ -notmatch "origin/$defaultBranch" } | 
                                        ForEach-Object { $_.Trim() -replace "origin/", "" }
                
                if ($mergedRemoteBranches.Count -eq 0) {
                    Write-Host "没有找到已合并的远程分支。" -ForegroundColor $colorInfo
                }
                else {
                    Write-Host "找到以下已合并的远程分支:" -ForegroundColor $colorInfo
                    $mergedRemoteBranches | ForEach-Object { Write-Host "  - $_" -ForegroundColor $colorInfo }
                    
                    $confirmation = Read-Host "是否删除这些远程分支? (y/N)"
                    if ($confirmation -eq "y" -or $confirmation -eq "Y") {
                        foreach ($branch in $mergedRemoteBranches) {
                            $command = "git push origin --delete $branch"
                            Write-Host "> $command" -ForegroundColor $colorCommand
                            git push origin --delete $branch
                        }
                        Write-Host "已合并的远程分支已删除。" -ForegroundColor $colorSuccess
                    }
                    else {
                        Write-Host "远程分支删除已取消。" -ForegroundColor $colorInfo
                    }
                }
            }
        }
        elseif ($DryRun) {
            Write-Host "将列出并删除已合并到 $defaultBranch 的远程分支。" -ForegroundColor $colorInfo
        }
    }

    # 运行垃圾回收
    if ($GarbageCollect) {
        if ($AggressiveGC) {
            Write-Host "\n运行积极的垃圾回收..." -ForegroundColor $colorWarning
            Write-Host "注意: 这可能需要一些时间。" -ForegroundColor $colorWarning
            $command = "git gc --aggressive --prune=now"
            Write-Host "> $command" -ForegroundColor $colorCommand
            
            if (-not $DryRun) {
                git gc --aggressive --prune=now
                if ($?) {
                    Write-Host "积极的垃圾回收已完成。" -ForegroundColor $colorSuccess
                }
                else {
                    Write-Host "运行积极的垃圾回收时出错。" -ForegroundColor $colorError
                }
            }
        }
        else {
            Write-Host "\n运行标准垃圾回收..." -ForegroundColor $colorInfo
            $command = "git gc --prune=now"
            Write-Host "> $command" -ForegroundColor $colorCommand
            
            if (-not $DryRun) {
                git gc --prune=now
                if ($?) {
                    Write-Host "标准垃圾回收已完成。" -ForegroundColor $colorSuccess
                }
                else {
                    Write-Host "运行标准垃圾回收时出错。" -ForegroundColor $colorError
                }
            }
        }
    }

    # 显示清理后的状态
    if (-not $DryRun) {
        Write-Host "\n清理完成！" -ForegroundColor $colorSuccess
        Show-RepositoryStatus
    }
    else {
        Write-Host "\n这是一个演示运行，没有实际执行任何操作。" -ForegroundColor $colorWarning
        Write-Host "要执行实际清理，请移除 -DryRun 参数。" -ForegroundColor $colorWarning
    }
}

# 主函数
function Main {
    # 显示脚本标题
    Write-Host "\n===== Git 仓库清理工具 =====" -ForegroundColor $colorInfo

    # 检查 Git 是否已安装
    if (-not (Test-GitInstalled)) {
        Write-Host "错误: Git 未安装或不在 PATH 中。请先安装 Git。" -ForegroundColor $colorError
        exit 1
    }

    # 检查当前目录是否是 Git 仓库
    if (-not (Test-GitRepository)) {
        Write-Host "错误: 当前目录不是 Git 仓库。请在 Git 仓库中运行此脚本。" -ForegroundColor $colorError
        exit 1
    }

    # 显示当前模式
    if ($DryRun) {
        Write-Host "模式: 演示运行 (不会实际执行操作)" -ForegroundColor $colorWarning
    }
    else {
        Write-Host "模式: 实际执行" -ForegroundColor $colorInfo
    }

    # 显示仓库状态
    Show-RepositoryStatus

    # 执行清理
    Invoke-GitCleanup
}

# 执行主函数
Main