#Requires -Version 7.0

<#
.SYNOPSIS
    自动化项目维护脚本 - 定期清理、验证和优化 dotfiles 项目

.DESCRIPTION
    这个脚本提供了全面的自动化维护功能：
    - 清理临时文件和日志
    - 运行健康检查和测试验证
    - 更新软件包和依赖项
    - 生成维护报告
    - Git 仓库优化

.PARAMETER Level
    维护级别：Basic(基础), Standard(标准), Deep(深度), Custom(自定义)

.PARAMETER DryRun
    预览模式，显示将要执行的操作但不实际执行

.PARAMETER Silent
    静默模式，最小化输出

.PARAMETER IncludePackageUpdate
    包含软件包更新操作

.PARAMETER GenerateReport
    生成详细的维护报告

.PARAMETER ScheduleTask
    创建定期维护的计划任务

.EXAMPLE
    .\auto-maintenance.ps1
    运行标准级别的维护

.EXAMPLE
    .\auto-maintenance.ps1 -Level Deep -GenerateReport
    运行深度维护并生成报告

.EXAMPLE
    .\auto-maintenance.ps1 -DryRun
    预览维护操作

.NOTES
    文件名: auto-maintenance.ps1
    作者: Dotfiles项目
    版本: 1.0.0
    最后更新: 2025-01-07
#>

[CmdletBinding()]
param(
    [ValidateSet('Basic', 'Standard', 'Deep', 'Custom')]
    [string]$Level = 'Standard',

    [switch]$DryRun,
    [switch]$Silent,
    [switch]$IncludePackageUpdate,
    [switch]$GenerateReport,
    [switch]$ScheduleTask
)

# 导入实用工具模块
$ModulePath = Join-Path $PSScriptRoot "..\modules\DotfilesUtilities.psm1"
if (Test-Path $ModulePath) {
    Import-Module $ModulePath -Force
}

# 全局变量
$Script:MaintenanceStartTime = Get-Date
$Script:MaintenanceLog = @()
$Script:Stats = @{
    FilesDeleted = 0
    SpaceSaved = 0
    TestsRun = 0
    TestsPassed = 0
    PackagesUpdated = 0
    IssuesFound = 0
    IssuesFixed = 0
}

#region Helper Functions

function Write-MaintenanceLog {
    param(
        [string]$Message,
        [string]$Level = 'INFO'
    )

    $LogEntry = @{
        Timestamp = Get-Date
        Level = $Level
        Message = $Message
    }

    $Script:MaintenanceLog += $LogEntry

    if (-not $Silent) {
        switch ($Level) {
            'ERROR' { Write-Host "❌ $Message" -ForegroundColor Red }
            'WARN' { Write-Host "⚠️ $Message" -ForegroundColor Yellow }
            'SUCCESS' { Write-Host "✅ $Message" -ForegroundColor Green }
            'INFO' { Write-Host "ℹ️ $Message" -ForegroundColor Cyan }
            default { Write-Host "📝 $Message" }
        }
    }
}

function Get-DirectorySize {
    param([string]$Path)

    if (-not (Test-Path $Path)) { return 0 }

    try {
        $Size = (Get-ChildItem -Path $Path -Recurse -Force -File |
                Measure-Object -Property Length -Sum).Sum
        return [math]::Max($Size, 0)
    }
    catch {
        return 0
    }
}

function Format-FileSize {
    param([long]$Bytes)

    $Units = @('B', 'KB', 'MB', 'GB', 'TB')
    $Index = 0
    $Size = $Bytes

    while ($Size -ge 1024 -and $Index -lt $Units.Length - 1) {
        $Size = $Size / 1024
        $Index++
    }

    return "{0:N2} {1}" -f $Size, $Units[$Index]
}

#endregion

#region Maintenance Functions

function Invoke-BasicMaintenance {
    Write-MaintenanceLog "开始基础维护..." "INFO"

    # 清理临时文件
    Clear-TemporaryFiles

    # 验证JSON配置
    Test-JsonConfigurations

    # 运行快速健康检查
    Invoke-HealthCheck -Quick
}

function Invoke-StandardMaintenance {
    Write-MaintenanceLog "开始标准维护..." "INFO"

    # 执行基础维护
    Invoke-BasicMaintenance

    # 运行所有测试
    Invoke-ProjectTests

    # 检查Git状态
    Test-GitRepository

    # 清理备份文件
    Clear-BackupFiles
}

function Invoke-DeepMaintenance {
    Write-MaintenanceLog "开始深度维护..." "INFO"

    # 执行标准维护
    Invoke-StandardMaintenance

    # 更新软件包（如果启用）
    if ($IncludePackageUpdate) {
        Update-Packages
    }

    # Git仓库优化
    Optimize-GitRepository

    # 检查项目结构完整性
    Test-ProjectIntegrity

    # 性能分析
    Invoke-PerformanceAnalysis
}

function Clear-TemporaryFiles {
    Write-MaintenanceLog "清理临时文件..." "INFO"

    $TempPatterns = @(
        "*.tmp", "*.temp", "*.log", "*.bak", "*~",
        "*.swp", "*.swo", "TestResults.xml", "*.coverage"
    )

    $InitialSize = Get-DirectorySize -Path $PWD
    $FilesDeleted = 0

    foreach ($Pattern in $TempPatterns) {
        $Files = Get-ChildItem -Path $PWD -Recurse -Force -Include $Pattern -ErrorAction SilentlyContinue

        foreach ($File in $Files) {
            try {
                if ($DryRun) {
                    Write-MaintenanceLog "将删除: $($File.FullName)" "INFO"
                } else {
                    Remove-Item -Path $File.FullName -Force
                    $FilesDeleted++
                }
            }
            catch {
                Write-MaintenanceLog "删除失败: $($File.FullName) - $($_.Exception.Message)" "WARN"
            }
        }
    }

    $FinalSize = Get-DirectorySize -Path $PWD
    $SpaceSaved = $InitialSize - $FinalSize

    $Script:Stats.FilesDeleted += $FilesDeleted
    $Script:Stats.SpaceSaved += $SpaceSaved

    Write-MaintenanceLog "临时文件清理完成: 删除 $FilesDeleted 个文件, 节省 $(Format-FileSize $SpaceSaved)" "SUCCESS"
}

function Test-JsonConfigurations {
    Write-MaintenanceLog "验证JSON配置文件..." "INFO"

    $ValidateScript = Join-Path $PSScriptRoot "Validate-JsonConfigs.ps1"

    if (Test-Path $ValidateScript) {
        try {
            if ($DryRun) {
                Write-MaintenanceLog "将验证JSON配置文件" "INFO"
            } else {
                $Result = & $ValidateScript 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-MaintenanceLog "JSON配置验证通过" "SUCCESS"
                } else {
                    Write-MaintenanceLog "JSON配置验证发现问题" "WARN"
                    $Script:Stats.IssuesFound++
                }
            }
        }
        catch {
            Write-MaintenanceLog "JSON验证失败: $($_.Exception.Message)" "ERROR"
            $Script:Stats.IssuesFound++
        }
    }
}

function Invoke-HealthCheck {
    param([switch]$Quick)

    Write-MaintenanceLog "执行健康检查..." "INFO"

    $HealthScript = Join-Path (Split-Path $PSScriptRoot -Parent) "health-check.ps1"

    if (Test-Path $HealthScript) {
        try {
            if ($DryRun) {
                Write-MaintenanceLog "将运行健康检查" "INFO"
            } else {
                $Params = if ($Quick) { @() } else { @("-Detailed") }
                $Result = & $HealthScript @Params 2>&1

                if ($Result -match "总体状态: Success") {
                    Write-MaintenanceLog "健康检查通过" "SUCCESS"
                } else {
                    Write-MaintenanceLog "健康检查发现问题" "WARN"
                    $Script:Stats.IssuesFound++
                }
            }
        }
        catch {
            Write-MaintenanceLog "健康检查失败: $($_.Exception.Message)" "ERROR"
            $Script:Stats.IssuesFound++
        }
    }
}

function Invoke-ProjectTests {
    Write-MaintenanceLog "运行项目测试..." "INFO"

    $TestScript = Join-Path $PSScriptRoot "Run-AllTests.ps1"

    if (Test-Path $TestScript) {
        try {
            if ($DryRun) {
                Write-MaintenanceLog "将运行所有测试" "INFO"
            } else {
                $Result = & $TestScript 2>&1 | Out-String

                if ($Result -match "Passed: (\d+).*Failed: (\d+)") {
                    $Passed = [int]$Matches[1]
                    $Failed = [int]$Matches[2]

                    $Script:Stats.TestsRun += ($Passed + $Failed)
                    $Script:Stats.TestsPassed += $Passed

                    if ($Failed -eq 0) {
                        Write-MaintenanceLog "所有测试通过 ($Passed/$($Passed + $Failed))" "SUCCESS"
                    } else {
                        Write-MaintenanceLog "测试失败 ($Failed/$($Passed + $Failed))" "ERROR"
                        $Script:Stats.IssuesFound += $Failed
                    }
                }
            }
        }
        catch {
            Write-MaintenanceLog "测试运行失败: $($_.Exception.Message)" "ERROR"
            $Script:Stats.IssuesFound++
        }
    }
}

function Test-GitRepository {
    Write-MaintenanceLog "检查Git仓库状态..." "INFO"

    try {
        if ($DryRun) {
            Write-MaintenanceLog "将检查Git状态" "INFO"
            return
        }

        # 检查是否有未提交的更改
        $Status = git status --porcelain 2>$null
        if ($Status) {
            Write-MaintenanceLog "发现 $($Status.Count) 个未提交的更改" "WARN"
            $Script:Stats.IssuesFound++
        }

        # 检查是否有未推送的提交
        $Ahead = git rev-list --count HEAD ^origin/main 2>$null
        if ($Ahead -and $Ahead -gt 0) {
            Write-MaintenanceLog "有 $Ahead 个未推送的提交" "WARN"
        }

        # 检查远程更新
        git fetch --dry-run 2>$null
        $Behind = git rev-list --count HEAD..origin/main 2>$null
        if ($Behind -and $Behind -gt 0) {
            Write-MaintenanceLog "落后远程 $Behind 个提交" "WARN"
        }

        Write-MaintenanceLog "Git仓库状态检查完成" "SUCCESS"
    }
    catch {
        Write-MaintenanceLog "Git状态检查失败: $($_.Exception.Message)" "ERROR"
        $Script:Stats.IssuesFound++
    }
}

function Clear-BackupFiles {
    Write-MaintenanceLog "清理备份文件..." "INFO"

    $BackupPatterns = @("*.backup", "*.old", "*_backup", "*-backup*")
    $BackupDirs = @(".dotfiles-backup-old", "backup", "*_backup")

    $InitialSize = Get-DirectorySize -Path $PWD
    $FilesDeleted = 0

    # 清理备份文件
    foreach ($Pattern in $BackupPatterns) {
        $Files = Get-ChildItem -Path $PWD -Recurse -Force -Include $Pattern -ErrorAction SilentlyContinue
        foreach ($File in $Files) {
            if ($File.LastWriteTime -lt (Get-Date).AddDays(-30)) {
                if ($DryRun) {
                    Write-MaintenanceLog "将删除旧备份: $($File.FullName)" "INFO"
                } else {
                    Remove-Item -Path $File.FullName -Force -Recurse
                    $FilesDeleted++
                }
            }
        }
    }

    $FinalSize = Get-DirectorySize -Path $PWD
    $SpaceSaved = $InitialSize - $FinalSize

    $Script:Stats.FilesDeleted += $FilesDeleted
    $Script:Stats.SpaceSaved += $SpaceSaved

    Write-MaintenanceLog "备份清理完成: 删除 $FilesDeleted 个文件" "SUCCESS"
}

function Update-Packages {
    Write-MaintenanceLog "更新软件包..." "INFO"

    try {
        if ($DryRun) {
            Write-MaintenanceLog "将检查软件包更新" "INFO"
            return
        }

        # 更新Scoop软件包
        if (Get-Command scoop -ErrorAction SilentlyContinue) {
            $UpdateResult = scoop update * 2>&1 | Out-String

            $UpdatedCount = ($UpdateResult | Select-String "was updated").Count
            $Script:Stats.PackagesUpdated += $UpdatedCount

            Write-MaintenanceLog "Scoop更新完成: $UpdatedCount 个软件包" "SUCCESS"
        }

        # 更新PowerShell模块
        $Modules = Get-InstalledModule -ErrorAction SilentlyContinue
        foreach ($Module in $Modules) {
            try {
                $Latest = Find-Module $Module.Name -ErrorAction SilentlyContinue
                if ($Latest -and $Latest.Version -gt $Module.Version) {
                    Update-Module $Module.Name -Force
                    $Script:Stats.PackagesUpdated++
                    Write-MaintenanceLog "更新PowerShell模块: $($Module.Name)" "SUCCESS"
                }
            }
            catch {
                # 忽略模块更新错误
            }
        }
    }
    catch {
        Write-MaintenanceLog "软件包更新失败: $($_.Exception.Message)" "ERROR"
        $Script:Stats.IssuesFound++
    }
}

function Optimize-GitRepository {
    Write-MaintenanceLog "优化Git仓库..." "INFO"

    try {
        if ($DryRun) {
            Write-MaintenanceLog "将优化Git仓库" "INFO"
            return
        }

        # Git垃圾收集
        git gc --aggressive --prune=now 2>$null
        Write-MaintenanceLog "Git垃圾收集完成" "SUCCESS"

        # 清理过期的引用
        git remote prune origin 2>$null
        Write-MaintenanceLog "远程引用清理完成" "SUCCESS"

        $Script:Stats.IssuesFixed++
    }
    catch {
        Write-MaintenanceLog "Git优化失败: $($_.Exception.Message)" "ERROR"
        $Script:Stats.IssuesFound++
    }
}

function Test-ProjectIntegrity {
    Write-MaintenanceLog "检查项目完整性..." "INFO"

    $RequiredFiles = @(
        "README.md",
        "install.ps1",
        "health-check.ps1",
        "config/install.json",
        "modules/DotfilesUtilities.psm1"
    )

    $MissingFiles = @()

    foreach ($File in $RequiredFiles) {
        if (-not (Test-Path $File)) {
            $MissingFiles += $File
        }
    }

    if ($MissingFiles.Count -gt 0) {
        Write-MaintenanceLog "缺少关键文件: $($MissingFiles -join ', ')" "ERROR"
        $Script:Stats.IssuesFound += $MissingFiles.Count
    } else {
        Write-MaintenanceLog "项目完整性检查通过" "SUCCESS"
    }
}

function Invoke-PerformanceAnalysis {
    Write-MaintenanceLog "性能分析..." "INFO"

    try {
        # PowerShell配置文件加载时间
        $ProfilePath = $PROFILE
        if (Test-Path $ProfilePath) {
            $LoadTime = Measure-Command {
                powershell -NoProfile -Command "& '$ProfilePath'"
            }

            if ($LoadTime.TotalSeconds -gt 2) {
                Write-MaintenanceLog "PowerShell配置加载较慢: $($LoadTime.TotalSeconds.ToString('F2'))秒" "WARN"
                $Script:Stats.IssuesFound++
            } else {
                Write-MaintenanceLog "PowerShell配置加载正常: $($LoadTime.TotalSeconds.ToString('F2'))秒" "SUCCESS"
            }
        }
    }
    catch {
        Write-MaintenanceLog "性能分析失败: $($_.Exception.Message)" "WARN"
    }
}

#endregion

#region Report Generation

function New-MaintenanceReport {
    $Duration = (Get-Date) - $Script:MaintenanceStartTime

    $Report = @{
        Timestamp = $Script:MaintenanceStartTime
        Duration = $Duration
        Level = $Level
        Statistics = $Script:Stats
        Log = $Script:MaintenanceLog
        DryRun = $DryRun
    }

    $ReportPath = "maintenance-report-$(Get-Date -Format 'yyyy-MM-dd-HHmm').json"

    try {
        $Report | ConvertTo-Json -Depth 10 | Out-File -Path $ReportPath -Encoding UTF8
        Write-MaintenanceLog "维护报告已生成: $ReportPath" "SUCCESS"
    }
    catch {
        Write-MaintenanceLog "报告生成失败: $($_.Exception.Message)" "ERROR"
    }

    # 显示摘要
    Show-MaintenanceSummary -Report $Report
}

function Show-MaintenanceSummary {
    param($Report)

    Write-Host "`n" + "="*60 -ForegroundColor Green
    Write-Host "🔧 维护摘要报告" -ForegroundColor Green
    Write-Host "="*60 -ForegroundColor Green

    Write-Host "⏱️  执行时间: $($Report.Duration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
    Write-Host "📊 维护级别: $($Report.Level)" -ForegroundColor Cyan
    Write-Host "🔍 预览模式: $(if($Report.DryRun){'是'}else{'否'})" -ForegroundColor Cyan

    Write-Host "`n📈 统计信息:" -ForegroundColor Yellow
    Write-Host "  • 删除文件: $($Report.Statistics.FilesDeleted)" -ForegroundColor White
    Write-Host "  • 节省空间: $(Format-FileSize $Report.Statistics.SpaceSaved)" -ForegroundColor White
    Write-Host "  • 运行测试: $($Report.Statistics.TestsRun)" -ForegroundColor White
    Write-Host "  • 测试通过: $($Report.Statistics.TestsPassed)" -ForegroundColor White
    Write-Host "  • 更新软件包: $($Report.Statistics.PackagesUpdated)" -ForegroundColor White
    Write-Host "  • 发现问题: $($Report.Statistics.IssuesFound)" -ForegroundColor White
    Write-Host "  • 修复问题: $($Report.Statistics.IssuesFixed)" -ForegroundColor White

    $SuccessRate = if ($Report.Statistics.IssuesFound -gt 0) {
        [math]::Round(($Report.Statistics.IssuesFixed / $Report.Statistics.IssuesFound) * 100, 2)
    } else { 100 }

    Write-Host "`n🎯 维护状态:" -ForegroundColor Yellow
    if ($Report.Statistics.IssuesFound -eq 0) {
        Write-Host "  ✅ 项目状态优秀，无问题发现" -ForegroundColor Green
    } elseif ($SuccessRate -ge 80) {
        Write-Host "  ✅ 维护成功，修复率: $SuccessRate%" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ 部分问题需要人工处理，修复率: $SuccessRate%" -ForegroundColor Yellow
    }

    Write-Host "="*60 -ForegroundColor Green
}

#endregion

#region Task Scheduling

function New-MaintenanceTask {
    Write-MaintenanceLog "创建计划维护任务..." "INFO"

    $TaskName = "DotfilesMaintenance"
    $ScriptPath = $MyInvocation.MyCommand.Path

    try {
        # 检查是否已存在任务
        $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($ExistingTask) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        }

        # 创建动作
        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File `"$ScriptPath`" -Level Standard -Silent"

        # 创建触发器（每周日凌晨2点）
        $Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2am

        # 创建设置
        $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

        # 注册任务
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "自动化 Dotfiles 项目维护"

        Write-MaintenanceLog "计划任务创建成功: $TaskName" "SUCCESS"
    }
    catch {
        Write-MaintenanceLog "计划任务创建失败: $($_.Exception.Message)" "ERROR"
    }
}

#endregion

#region Main Execution

function Invoke-MaintenanceWorkflow {
    Write-Host "🔧 Dotfiles 自动维护系统" -ForegroundColor Green
    Write-Host "="*50 -ForegroundColor Green

    if ($DryRun) {
        Write-Host "🔍 预览模式 - 不会实际执行操作" -ForegroundColor Yellow
    }

    Write-MaintenanceLog "开始维护流程: $Level 级别" "INFO"

    try {
        switch ($Level) {
            'Basic' { Invoke-BasicMaintenance }
            'Standard' { Invoke-StandardMaintenance }
            'Deep' { Invoke-DeepMaintenance }
            'Custom' {
                # 自定义维护逻辑
                Write-MaintenanceLog "自定义维护模式，请手动指定操作" "WARN"
            }
        }

        Write-MaintenanceLog "维护流程完成" "SUCCESS"
    }
    catch {
        Write-MaintenanceLog "维护流程异常: $($_.Exception.Message)" "ERROR"
    }
    finally {
        if ($GenerateReport) {
            New-MaintenanceReport
        }

        if ($ScheduleTask) {
            New-MaintenanceTask
        }
    }
}

# 主执行入口
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-MaintenanceWorkflow
}

#endregion
