# cleanup-project.ps1
# 项目清理脚本 - 增强版，支持多种清理模式和安全选项

<#
.SYNOPSIS
    清理项目中的临时文件、日志文件和备份文件

.DESCRIPTION
    清理 dotfiles 项目中的临时文件、安装日志、备份文件等，
    保持项目目录整洁。提供多种清理级别和安全选项。

.PARAMETER DryRun
    预览模式，显示将要删除的文件但不实际删除

.PARAMETER IncludeLogs
    包含日志文件清理

.PARAMETER Force
    强制清理无需确认

.PARAMETER Level
    清理级别：Basic（基础）、Standard（标准）、Deep（深度）

.PARAMETER KeepDays
    保留最近N天的文件（仅适用于日志和缓存）

.PARAMETER ExportReport
    导出清理报告

.EXAMPLE
    .\cleanup-project.ps1
    基础清理项目临时文件

.EXAMPLE
    .\cleanup-project.ps1 -DryRun -Level Deep
    预览深度清理模式

.EXAMPLE
    .\cleanup-project.ps1 -IncludeLogs -Force -Level Standard
    标准清理模式，包含日志，无需确认

.EXAMPLE
    .\cleanup-project.ps1 -KeepDays 7 -ExportReport
    清理7天前的文件并导出报告
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$DryRun,
    [switch]$IncludeLogs,
    [switch]$Force,
    [ValidateSet("Basic", "Standard", "Deep")]
    [string]$Level = "Basic",
    [int]$KeepDays = 0,
    [switch]$ExportReport,
    [string]$ReportPath = "cleanup-report.json",
    [switch]$Quiet
)

# 严格模式
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# 全局变量
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:CleanupResults = @()
$script:StartTime = Get-Date
$script:TotalSize = 0
$script:TotalFiles = 0

# 清理结果类
class CleanupResult {
    [string]$Path
    [string]$Type
    [string]$Action
    [long]$Size
    [datetime]$LastModified
    [bool]$Success
    [string]$Error

    CleanupResult([string]$path, [string]$type) {
        $this.Path = $path
        $this.Type = $type
        $this.Action = "Unknown"
        $this.Size = 0
        $this.Success = $false
        $this.Error = ""
    }
}

# 颜色输出函数
function Write-CleanupMessage {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error", "Debug")]
        [string]$Type = "Info"
    )

    if ($Quiet -and $Type -in @("Info", "Debug")) { return }

    $color = switch ($Type) {
        "Success" { "Green" }
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Info" { "Cyan" }
        "Debug" { "Magenta" }
        default { "White" }
    }

    $prefix = switch ($Type) {
        "Success" { "✅" }
        "Error" { "❌" }
        "Warning" { "⚠️" }
        "Info" { "ℹ️" }
        "Debug" { "🔍" }
        default { "" }
    }

    Write-Host "$prefix $Message" -ForegroundColor $color
}

# 格式化文件大小
function Format-FileSize {
    param([long]$SizeInBytes)

    if ($SizeInBytes -eq 0) { return "0 B" }

    $sizes = @("B", "KB", "MB", "GB", "TB")
    $order = [Math]::Floor([Math]::Log($SizeInBytes, 1024))
    $num = [Math]::Round($SizeInBytes / [Math]::Pow(1024, $order), 2)

    return "$num $($sizes[$order])"
}

# 获取清理模式配置
function Get-CleanupConfiguration {
    param([string]$CleanupLevel)

    $config = @{
        Basic = @{
            TempFiles = @("*.tmp", "*.temp", "*.bak", "*.old")
            CacheFiles = @(".quick-check-cache.json", "*.cache")
            LogFiles = @()
            BackupDirs = @()
            Description = "清理基本临时文件"
        }
        Standard = @{
            TempFiles = @("*.tmp", "*.temp", "*.bak", "*.old", "*.orig")
            CacheFiles = @(".quick-check-cache.json", "*.cache", "*.cached")
            LogFiles = if ($IncludeLogs) { @("*.log", "install.log", "health-report.json") } else { @() }
            BackupDirs = @(".dotfiles-backup-old")
            Description = "标准清理模式"
        }
        Deep = @{
            TempFiles = @("*.tmp", "*.temp", "*.bak", "*.old", "*.orig", "*.swp", "*~")
            CacheFiles = @(".quick-check-cache.json", "*.cache", "*.cached", ".pester-cache")
            LogFiles = if ($IncludeLogs) { @("*.log", "install.log", "health-report.json", "project-status.json", "quick-check-results.json") } else { @() }
            BackupDirs = @(".dotfiles-backup-old", "backup-*")
            RecursiveDirs = @("node_modules\.cache", "\.vs", "\.vscode\extensions\.obsolete")
            Description = "深度清理模式（包含更多文件类型）"
        }
    }

    return $config[$CleanupLevel]
}

# 清理文件
function Remove-CleanupItem {
    param(
        [string]$Path,
        [string]$Type,
        [bool]$IsDirectory = $false
    )

    $result = [CleanupResult]::new($Path, $Type)

    try {
        $item = Get-Item $Path -Force -ErrorAction Stop
        $result.Size = if ($IsDirectory) {
            (Get-ChildItem $Path -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        } else {
            $item.Length
        }
        $result.LastModified = $item.LastWriteTime

        # 检查保留天数
        if ($KeepDays -gt 0 -and $item.LastWriteTime -gt (Get-Date).AddDays(-$KeepDays)) {
            $result.Action = "Skipped (Recent)"
            $result.Success = $true
            if (-not $Quiet) {
                Write-CleanupMessage "跳过（最近修改）: $Path" "Warning"
            }
            return $result
        }

        if ($DryRun) {
            $result.Action = "Would Delete"
            $result.Success = $true
            Write-CleanupMessage "将删除: $Path ($(Format-FileSize $result.Size))" "Warning"
        } else {
            # 确认删除（除非使用 -Force）
            if (-not $Force -and -not $PSCmdlet.ShouldProcess($Path, "删除文件/目录")) {
                $result.Action = "Cancelled"
                $result.Success = $true
                return $result
            }

            if ($IsDirectory) {
                Remove-Item $Path -Recurse -Force -ErrorAction Stop
            } else {
                Remove-Item $Path -Force -ErrorAction Stop
            }

            $result.Action = "Deleted"
            $result.Success = $true
            $script:TotalSize += $result.Size
            $script:TotalFiles++

            Write-CleanupMessage "已删除: $Path ($(Format-FileSize $result.Size))" "Success"
        }
    } catch {
        $result.Success = $false
        $result.Error = $_.Exception.Message
        $result.Action = "Failed"
        Write-CleanupMessage "删除失败: $Path - $($_.Exception.Message)" "Error"
    }

    return $result
}

# 清理指定模式的文件
function Clear-FilesByPattern {
    param(
        [string[]]$Patterns,
        [string]$Type,
        [bool]$Recursive = $false
    )

    foreach ($pattern in $Patterns) {
        $searchPath = Join-Path $script:ProjectRoot $pattern

        # 直接匹配的文件/目录
        $directItems = Get-Item $searchPath -Force -ErrorAction SilentlyContinue
        foreach ($item in $directItems) {
            $isDir = $item -is [System.IO.DirectoryInfo]
            $result = Remove-CleanupItem -Path $item.FullName -Type $Type -IsDirectory $isDir
            $script:CleanupResults += $result
        }

        # 通过通配符查找
        if ($pattern.Contains("*") -or $pattern.Contains("?")) {
            $parentPath = Split-Path $searchPath -Parent
            $fileName = Split-Path $searchPath -Leaf

            if (Test-Path $parentPath) {
                $items = Get-ChildItem $parentPath -Filter $fileName -Force -ErrorAction SilentlyContinue
                if ($Recursive) {
                    $items += Get-ChildItem $parentPath -Filter $fileName -Recurse -Force -ErrorAction SilentlyContinue
                }

                foreach ($item in $items) {
                    $isDir = $item -is [System.IO.DirectoryInfo]
                    $result = Remove-CleanupItem -Path $item.FullName -Type $Type -IsDirectory $isDir
                    $script:CleanupResults += $result
                }
            }
        }
    }
}

# 清理特定目录中的旧文件
function Clear-OldFiles {
    param(
        [string[]]$Directories,
        [int]$DaysOld = 30
    )

    foreach ($dir in $Directories) {
        $fullPath = Join-Path $script:ProjectRoot $dir
        if (Test-Path $fullPath) {
            $cutoffDate = (Get-Date).AddDays(-$DaysOld)
            $oldFiles = Get-ChildItem $fullPath -Recurse -File -Force -ErrorAction SilentlyContinue |
                        Where-Object { $_.LastWriteTime -lt $cutoffDate }

            foreach ($file in $oldFiles) {
                $result = Remove-CleanupItem -Path $file.FullName -Type "Old File"
                $script:CleanupResults += $result
            }
        }
    }
}

# 主清理函数
function Start-ProjectCleanup {
    Write-CleanupMessage "🧹 项目清理工具 - $Level 模式" "Info"
    Write-CleanupMessage ("=" * 50) "Info"

    if ($DryRun) {
        Write-CleanupMessage "🔍 预览模式 - 不会实际删除文件" "Warning"
    }

    if ($KeepDays -gt 0) {
        Write-CleanupMessage "📅 保留最近 $KeepDays 天的文件" "Info"
    }

    Write-CleanupMessage "" "Info"

    # 获取清理配置
    $config = Get-CleanupConfiguration -CleanupLevel $Level
    Write-CleanupMessage "清理模式: $($config.Description)" "Info"

    # 清理临时文件
    if ($config.TempFiles.Count -gt 0) {
        Write-CleanupMessage "🗂️ 清理临时文件..." "Info"
        Clear-FilesByPattern -Patterns $config.TempFiles -Type "Temp File"
    }

    # 清理缓存文件
    if ($config.CacheFiles.Count -gt 0) {
        Write-CleanupMessage "💾 清理缓存文件..." "Info"
        Clear-FilesByPattern -Patterns $config.CacheFiles -Type "Cache File"
    }

    # 清理日志文件
    if ($config.LogFiles.Count -gt 0 -and $IncludeLogs) {
        Write-CleanupMessage "📄 清理日志文件..." "Info"
        Clear-FilesByPattern -Patterns $config.LogFiles -Type "Log File"
    }

    # 清理备份目录
    if ($config.BackupDirs.Count -gt 0) {
        Write-CleanupMessage "📦 清理旧备份目录..." "Info"
        Clear-FilesByPattern -Patterns $config.BackupDirs -Type "Backup Directory"
    }

    # 深度清理模式的额外清理
    if ($Level -eq "Deep" -and $config.RecursiveDirs) {
        Write-CleanupMessage "🔍 深度清理递归目录..." "Info"
        Clear-FilesByPattern -Patterns $config.RecursiveDirs -Type "Recursive Directory" -Recursive $true
    }

    # 清理超过30天的临时文件（深度模式）
    if ($Level -eq "Deep") {
        Write-CleanupMessage "⏰ 清理超过30天的旧文件..." "Info"
        $tempDirs = @("temp", "tmp", ".temp")
        Clear-OldFiles -Directories $tempDirs -DaysOld 30
    }
}

# 生成清理报告
function Export-CleanupReport {
    $report = @{
        Timestamp = $script:StartTime
        Level = $Level
        DryRun = $DryRun.IsPresent
        IncludeLogs = $IncludeLogs.IsPresent
        KeepDays = $KeepDays
        Summary = @{
            TotalFiles = $script:TotalFiles
            TotalSize = $script:TotalSize
            TotalSizeFormatted = Format-FileSize $script:TotalSize
            Duration = (Get-Date) - $script:StartTime
            SuccessfulOperations = ($script:CleanupResults | Where-Object Success).Count
            FailedOperations = ($script:CleanupResults | Where-Object { -not $_.Success }).Count
        }
        Results = $script:CleanupResults
        Statistics = @{
            ByType = $script:CleanupResults | Group-Object Type | ForEach-Object {
                @{
                    Type = $_.Name
                    Count = $_.Count
                    TotalSize = ($_.Group | Measure-Object Size -Sum).Sum
                    TotalSizeFormatted = Format-FileSize (($_.Group | Measure-Object Size -Sum).Sum)
                }
            }
            ByAction = $script:CleanupResults | Group-Object Action | ForEach-Object {
                @{
                    Action = $_.Name
                    Count = $_.Count
                }
            }
        }
    }

    try {
        $reportPath = Join-Path $script:ProjectRoot $ReportPath
        $report | ConvertTo-Json -Depth 4 | Out-File $reportPath -Encoding UTF8
        Write-CleanupMessage "清理报告已导出: $reportPath" "Success"
    } catch {
        Write-CleanupMessage "导出报告失败: $($_.Exception.Message)" "Error"
    }
}

# 显示清理总结
function Show-CleanupSummary {
    $duration = (Get-Date) - $script:StartTime

    Write-CleanupMessage "" "Info"
    Write-CleanupMessage ("=" * 50) "Info"
    Write-CleanupMessage "🏆 清理完成总结" "Info"
    Write-CleanupMessage ("=" * 50) "Info"

    if ($DryRun) {
        Write-CleanupMessage "预览模式完成" "Info"
        Write-CleanupMessage "找到可清理项目: $($script:CleanupResults.Count)" "Info"
        $totalPreviewSize = if ($script:CleanupResults.Count -gt 0) {
            ($script:CleanupResults | Measure-Object Size -Sum).Sum
        } else { 0 }
        Write-CleanupMessage "可节省空间: $(Format-FileSize $totalPreviewSize)" "Info"
        Write-CleanupMessage "💡 运行 .\cleanup-project.ps1 -Level $Level $(if($IncludeLogs){'-IncludeLogs'}) 执行实际清理" "Warning"
    } else {
        Write-CleanupMessage "已删除文件: $script:TotalFiles" "Success"
        Write-CleanupMessage "节省空间: $(Format-FileSize $script:TotalSize)" "Success"
        Write-CleanupMessage "执行时间: $($duration.ToString('mm\:ss\.ff'))" "Info"

        # 失败统计
        $failedCount = ($script:CleanupResults | Where-Object { -not $_.Success }).Count
        if ($failedCount -gt 0) {
            Write-CleanupMessage "失败操作: $failedCount" "Warning"
        }
    }

    # 按类型显示统计
    if ($script:CleanupResults.Count -gt 0 -and -not $Quiet) {
        Write-CleanupMessage "" "Info"
        Write-CleanupMessage "按类型统计:" "Info"
        $script:CleanupResults | Group-Object Type | ForEach-Object {
            $groupSize = if ($_.Group.Count -gt 0) {
                ($_.Group | Measure-Object Size -Sum).Sum
            } else { 0 }
            Write-CleanupMessage "  $($_.Name): $($_.Count) 项 ($(Format-FileSize $groupSize))" "Info"
        }
    }

    Write-CleanupMessage "" "Info"
    Write-CleanupMessage "💡 建议：运行 git status 检查项目状态" "Info"
}

# 主执行逻辑
try {
    # 验证项目根目录
    if (-not (Test-Path $script:ProjectRoot)) {
        throw "无法找到项目根目录: $script:ProjectRoot"
    }

    # 确认操作（深度清理模式且非强制模式）
    if ($Level -eq "Deep" -and -not $Force -and -not $DryRun) {
        $confirmation = Read-Host "深度清理模式会删除更多文件。继续吗？(y/N)"
        if ($confirmation -notmatch '^[Yy]') {
            Write-CleanupMessage "清理已取消" "Warning"
            exit 0
        }
    }

    # 执行清理
    Start-ProjectCleanup

    # 显示总结
    Show-CleanupSummary

    # 导出报告
    if ($ExportReport) {
        Export-CleanupReport
    }

    Write-CleanupMessage "✨ 项目清理完成！" "Success"
    exit 0

} catch {
    Write-CleanupMessage "清理过程发生错误: $($_.Exception.Message)" "Error"
    exit 1
}
