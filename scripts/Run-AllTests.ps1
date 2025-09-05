# Run-AllTests.ps1
# 增强的测试运行器 - 运行项目中的所有测试，支持并行执行和多种测试类型

[CmdletBinding()]
param(
    [switch]$Detailed,
    [switch]$Quiet,
    [string]$Filter = "*",
    [ValidateSet("Unit", "Integration", "All")]
    [string]$TestType = "All",
    [switch]$Parallel,
    [int]$MaxParallelJobs = [Environment]::ProcessorCount,
    [int]$TimeoutMinutes = 10,
    [switch]$ContinueOnError,
    [string]$OutputFormat = "NUnitXml",
    [string]$OutputFile = "TestResults.xml",
    [ValidateSet("Quiet", "Normal", "Detailed", "Diagnostic")]
    [string]$Verbosity = "Normal"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = if ($ContinueOnError) { 'Continue' } else { 'Stop' }

$ProjectRoot = Split-Path $PSScriptRoot -Parent

# 颜色输出函数
function Write-TestMessage {
    param(
        [string]$Message,
        [string]$Type = 'Info',
        [string]$Level = 'Normal'
    )

    # 根据详细程度过滤消息
    $shouldOutput = switch ($Verbosity) {
        'Quiet' { $Type -in @('Error', 'Success') }
        'Normal' { $Type -in @('Error', 'Warning', 'Success', 'Info') }
        'Detailed' { $true }
        'Diagnostic' { $true }
        default { $Type -in @('Error', 'Warning', 'Success', 'Info') }
    }

    if (-not $shouldOutput) { return }
    if ($Quiet -and $Type -eq 'Info') { return }

    $color = switch ($Type) {
        'Success' { 'Green' }
        'Error' { 'Red' }
        'Warning' { 'Yellow' }
        'Info' { 'Cyan' }
        'Debug' { 'Magenta' }
        default { 'White' }
    }

    $prefix = switch ($Type) {
        'Success' { '✅' }
        'Error' { '❌' }
        'Warning' { '⚠️' }
        'Info' { 'ℹ️' }
        'Debug' { '🔍' }
        default { '' }
    }

    $timestamp = if ($Verbosity -eq 'Diagnostic') { "[$(Get-Date -Format 'HH:mm:ss')] " } else { "" }
    Write-Host "$timestamp$prefix $Message" -ForegroundColor $color
}

# 获取测试文件
function Get-TestFiles {
    param([string]$TestTypeFilter, [string]$NameFilter)

    $testDir = Join-Path $ProjectRoot "scripts"
    $testFiles = @()

    # 根据测试类型过滤
    switch ($TestTypeFilter) {
        'Unit' {
            $testFiles += Get-ChildItem $testDir -Filter "*.Tests.ps1" | Where-Object { $_.Name -notlike "*Integration*" -and $_.Name -like $NameFilter }
        }
        'Integration' {
            $testFiles += Get-ChildItem $testDir -Filter "*Integration*.Tests.ps1" | Where-Object { $_.Name -like $NameFilter }
        }
        'All' {
            $testFiles += Get-ChildItem $testDir -Filter "*.Tests.ps1" | Where-Object { $_.Name -like $NameFilter }
        }
    }

    # 查找其他测试目录
    $otherTestDirs = @("tests", "test", "Tests")
    foreach ($dir in $otherTestDirs) {
        $testPath = Join-Path $ProjectRoot $dir
        if (Test-Path $testPath) {
            switch ($TestTypeFilter) {
                'Unit' {
                    $testFiles += Get-ChildItem $testPath -Filter "*.Tests.ps1" -Recurse | Where-Object { $_.Name -notlike "*Integration*" -and $_.Name -like $NameFilter }
                }
                'Integration' {
                    $testFiles += Get-ChildItem $testPath -Filter "*Integration*.Tests.ps1" -Recurse | Where-Object { $_.Name -like $NameFilter }
                }
                'All' {
                    $testFiles += Get-ChildItem $testPath -Filter "*.Tests.ps1" -Recurse | Where-Object { $_.Name -like $NameFilter }
                }
            }
        }
    }

    return $testFiles
}

# 运行单个测试文件
function Invoke-SingleTest {
    param([System.IO.FileInfo]$TestFile)

    $result = [PSCustomObject]@{
        TestFile = $TestFile.Name
        FilePath = $TestFile.FullName
        TotalCount = 0
        PassedCount = 0
        FailedCount = 0
        SkippedCount = 0
        Duration = [TimeSpan]::Zero
        Success = $false
        Output = ""
        Errors = @()
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        Write-TestMessage "运行测试: $($TestFile.Name)" "Info" "Normal"

        # 检查是否需要 Pester
        $content = Get-Content $TestFile.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -match "Describe|Context|It") {
            # Pester 测试
            if (-not (Get-Module -ListAvailable -Name Pester)) {
                $result.Errors += "需要 Pester 模块: Install-Module Pester -Force"
                Write-TestMessage "需要 Pester 模块来运行测试，请安装: Install-Module Pester -Force" "Warning"
                return $result
            }

            Import-Module Pester -Force -ErrorAction SilentlyContinue

            # 兼容不同版本的 Pester
            $pesterVersion = (Get-Module Pester).Version
            if ($pesterVersion -and $pesterVersion.Major -ge 5) {
                # Pester 5.x+ 使用配置对象
                $pesterConfig = New-PesterConfiguration
                $pesterConfig.Run.Path = $TestFile.FullName
                $pesterConfig.Run.PassThru = $true
                $pesterConfig.Output.Verbosity = if ($Verbosity -eq 'Quiet') { 'None' } elseif ($Verbosity -eq 'Diagnostic') { 'Detailed' } else { 'Normal' }
                $pesterResult = Invoke-Pester -Configuration $pesterConfig
            } else {
                # Pester 4.x 及更早版本使用参数
                $pesterParams = @{
                    Script = $TestFile.FullName
                    PassThru = $true
                    Quiet = ($Verbosity -eq 'Quiet')
                }
                $pesterResult = Invoke-Pester @pesterParams
            }

            $result.TotalCount = $pesterResult.TotalCount
            $result.PassedCount = $pesterResult.PassedCount
            $result.FailedCount = $pesterResult.FailedCount
            $result.SkippedCount = $pesterResult.SkippedCount
            $result.Success = $pesterResult.FailedCount -eq 0

            if ($pesterResult.FailedCount -gt 0) {
                $result.Errors += $pesterResult.Failed | ForEach-Object { $_.ErrorRecord.Exception.Message }
            }

        } else {
            # 原生 PowerShell 测试
            $testJob = Start-Job -ScriptBlock {
                param($TestPath)
                try {
                    & $TestPath
                    return @{ ExitCode = $LASTEXITCODE; Output = "Test completed" }
                } catch {
                    return @{ ExitCode = 1; Output = $_.Exception.Message }
                }
            } -ArgumentList $TestFile.FullName

            $timeout = New-TimeSpan -Minutes $TimeoutMinutes
            if (Wait-Job $testJob -Timeout $timeout) {
                $jobResult = Receive-Job $testJob
                $result.Success = $jobResult.ExitCode -eq 0
                $result.TotalCount = 1
                if ($result.Success) {
                    $result.PassedCount = 1
                } else {
                    $result.FailedCount = 1
                    $result.Errors += $jobResult.Output
                }
                $result.Output = $jobResult.Output
            } else {
                $result.Success = $false
                $result.FailedCount = 1
                $result.Errors += "测试超时 ($TimeoutMinutes 分钟)"
                Stop-Job $testJob
            }

            Remove-Job $testJob -Force
        }

    } catch {
        $result.Success = $false
        $result.FailedCount = 1
        $result.Errors += $_.Exception.Message
        Write-TestMessage "测试执行异常: $($_.Exception.Message)" "Error"
    } finally {
        $stopwatch.Stop()
        $result.Duration = $stopwatch.Elapsed
    }

    # 输出结果
    if ($result.Success) {
        Write-TestMessage "✅ 测试通过: $($TestFile.Name) ($($result.PassedCount)/$($result.TotalCount)) - $($result.Duration.TotalSeconds.ToString('F2'))s" "Success"
    } else {
        Write-TestMessage "❌ 测试失败: $($TestFile.Name) ($($result.FailedCount) 个失败) - $($result.Duration.TotalSeconds.ToString('F2'))s" "Error"
        if ($Verbosity -in @('Detailed', 'Diagnostic') -and $result.Errors.Count -gt 0) {
            foreach ($error in $result.Errors) {
                Write-TestMessage "  错误: $error" "Error"
            }
        }
    }

    return $result
}

# 主函数
function Main {
    Write-TestMessage "🧪 运行 Dotfiles 测试套件" "Info"
    Write-TestMessage ("=" * 50) "Info"
    Write-TestMessage "测试类型: $TestType | 过滤器: $Filter | 并行: $Parallel" "Info"

    if ($Verbosity -eq 'Diagnostic') {
        Write-TestMessage "PowerShell 版本: $($PSVersionTable.PSVersion)" "Debug"
        Write-TestMessage "处理器核心数: $([Environment]::ProcessorCount)" "Debug"
        Write-TestMessage "最大并行任务: $MaxParallelJobs" "Debug"
    }

    $testFiles = Get-TestFiles -TestTypeFilter $TestType -NameFilter $Filter

    if (@($testFiles).Count -eq 0) {
        Write-TestMessage "没有找到匹配的测试文件 (类型: $TestType, 过滤器: $Filter)" "Warning"
        return 0
    }

    Write-TestMessage "找到 $(@($testFiles).Count) 个测试文件" "Info"

    $overallStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $allResults = @()

    if ($Parallel -and @($testFiles).Count -gt 1) {
        Write-TestMessage "使用并行执行 (最大 $MaxParallelJobs 个并发任务)" "Info"

        # 并行执行需要将函数定义传递
        $invokeTestScript = {
            param($TestFileInfo, $TimeoutMin, $VerbosityLevel, $OutputFmt)

            $result = [PSCustomObject]@{
                TestFile = $TestFileInfo.Name
                FilePath = $TestFileInfo.FullName
                TotalCount = 0
                PassedCount = 0
                FailedCount = 0
                SkippedCount = 0
                Duration = [TimeSpan]::Zero
                Success = $false
                Output = ""
                Errors = @()
            }

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            try {
                # 检查是否需要 Pester
                $content = Get-Content $TestFileInfo.FullName -Raw -ErrorAction SilentlyContinue
                if ($content -match "Describe|Context|It") {
                    # Pester 测试
                    if (-not (Get-Module -ListAvailable -Name Pester)) {
                        $result.Errors += "需要 Pester 模块: Install-Module Pester -Force"
                        return $result
                    }

                    Import-Module Pester -Force -ErrorAction SilentlyContinue

                    # 兼容不同版本的 Pester
                    $pesterVersion = (Get-Module Pester).Version
                    if ($pesterVersion -and $pesterVersion.Major -ge 5) {
                        # Pester 5.x+ 使用配置对象
                        $pesterConfig = New-PesterConfiguration
                        $pesterConfig.Run.Path = $TestFileInfo.FullName
                        $pesterConfig.Run.PassThru = $true
                        $pesterConfig.Output.Verbosity = if ($VerbosityLevel -eq 'Quiet') { 'None' } elseif ($VerbosityLevel -eq 'Diagnostic') { 'Detailed' } else { 'Normal' }
                        $pesterResult = Invoke-Pester -Configuration $pesterConfig
                    } else {
                        # Pester 4.x 及更早版本使用参数
                        $pesterParams = @{
                            Script = $TestFileInfo.FullName
                            PassThru = $true
                            Quiet = ($VerbosityLevel -eq 'Quiet')
                        }
                        $pesterResult = Invoke-Pester @pesterParams
                    }

                    $result.TotalCount = $pesterResult.TotalCount
                    $result.PassedCount = $pesterResult.PassedCount
                    $result.FailedCount = $pesterResult.FailedCount
                    $result.SkippedCount = $pesterResult.SkippedCount
                    $result.Success = $pesterResult.FailedCount -eq 0

                    if ($pesterResult.FailedCount -gt 0) {
                        $result.Errors += $pesterResult.Failed | ForEach-Object { $_.ErrorRecord.Exception.Message }
                    }

                } else {
                    # 原生 PowerShell 测试
                    $testJob = Start-Job -ScriptBlock {
                        param($TestPath)
                        try {
                            & $TestPath
                            return @{ ExitCode = $LASTEXITCODE; Output = "Test completed" }
                        } catch {
                            return @{ ExitCode = 1; Output = $_.Exception.Message }
                        }
                    } -ArgumentList $TestFileInfo.FullName

                    $timeout = New-TimeSpan -Minutes $TimeoutMin
                    if (Wait-Job $testJob -Timeout $timeout) {
                        $jobResult = Receive-Job $testJob
                        $result.Success = $jobResult.ExitCode -eq 0
                        $result.TotalCount = 1
                        if ($result.Success) {
                            $result.PassedCount = 1
                        } else {
                            $result.FailedCount = 1
                            $result.Errors += $jobResult.Output
                        }
                        $result.Output = $jobResult.Output
                    } else {
                        $result.Success = $false
                        $result.FailedCount = 1
                        $result.Errors += "测试超时 ($TimeoutMin 分钟)"
                        Stop-Job $testJob
                    }

                    Remove-Job $testJob -Force
                }

            } catch {
                $result.Success = $false
                $result.FailedCount = 1
                $result.Errors += $_.Exception.Message
            } finally {
                $stopwatch.Stop()
                $result.Duration = $stopwatch.Elapsed
            }

            return $result
        }

        $testFiles | ForEach-Object -Parallel $invokeTestScript -ArgumentList $_, $TimeoutMinutes, $Verbosity, $OutputFormat -ThrottleLimit $MaxParallelJobs | ForEach-Object {
            $allResults += $_

            # 输出结果
            if ($_.Success) {
                Write-Host "✅ 测试通过: $($_.TestFile) ($($_.PassedCount)/$($_.TotalCount)) - $($_.Duration.TotalSeconds.ToString('F2'))s" -ForegroundColor Green
            } else {
                Write-Host "❌ 测试失败: $($_.TestFile) ($($_.FailedCount) 个失败) - $($_.Duration.TotalSeconds.ToString('F2'))s" -ForegroundColor Red
            }
        }
    } else {
        # 顺序执行
        foreach ($testFile in $testFiles) {
            $result = Invoke-SingleTest -TestFile $testFile
            $allResults += $result

            if (-not $result.Success -and -not $ContinueOnError) {
                Write-TestMessage "测试失败，停止执行 (使用 -ContinueOnError 继续)" "Error"
                break
            }
        }
    }

    $overallStopwatch.Stop()

    # 计算总结统计
    $totalTests = (@($allResults) | Measure-Object -Property TotalCount -Sum).Sum
    $totalPassed = (@($allResults) | Measure-Object -Property PassedCount -Sum).Sum
    $totalFailed = (@($allResults) | Measure-Object -Property FailedCount -Sum).Sum
    $totalSkipped = (@($allResults) | Measure-Object -Property SkippedCount -Sum).Sum
    $successRate = if ($totalTests -gt 0) { ($totalPassed / $totalTests * 100) } else { 0 }

    # 显示总结
    Write-TestMessage "" "Info"
    Write-TestMessage ("=" * 50) "Info"
    Write-TestMessage "🏆 测试执行总结" "Info"
    Write-TestMessage ("=" * 50) "Info"
    Write-TestMessage "测试文件: $(@($allResults).Count)" "Info"
    Write-TestMessage "总计测试: $totalTests" "Info"
    Write-TestMessage "通过: $totalPassed" "Success"
    Write-TestMessage "失败: $totalFailed" "Error"
    if ($totalSkipped -gt 0) {
        Write-TestMessage "跳过: $totalSkipped" "Warning"
    }
    Write-TestMessage "成功率: $($successRate.ToString('F1'))%" "Info"
    Write-TestMessage "执行时间: $($overallStopwatch.Elapsed.ToString('mm\:ss\.ff'))" "Info"

    # 失败的测试详情
    if ($totalFailed -gt 0 -and $Verbosity -ne 'Quiet') {
        Write-TestMessage "" "Info"
        Write-TestMessage "失败的测试:" "Error"
        $failedTests = @($allResults | Where-Object { -not $_.Success })
        foreach ($failed in $failedTests) {
            Write-TestMessage "  ❌ $($failed.TestFile)" "Error"
        }
    }

    # 性能统计
    if ($Verbosity -in @('Detailed', 'Diagnostic')) {
        Write-TestMessage "" "Info"
        Write-TestMessage "性能统计:" "Info"
        $avgDuration = (@($allResults) | Measure-Object -Property Duration -Average).Average.TotalSeconds
        $slowestTest = @($allResults) | Sort-Object Duration -Descending | Select-Object -First 1
        Write-TestMessage "平均执行时间: $($avgDuration.ToString('F2'))s" "Info"
        Write-TestMessage "最慢的测试: $($slowestTest.TestFile) ($($slowestTest.Duration.TotalSeconds.ToString('F2'))s)" "Info"
    }

    # 导出结果
    if ($OutputFile -and @($allResults).Count -gt 0) {
        try {
            $outputPath = Join-Path $ProjectRoot $OutputFile
            $allResults | ConvertTo-Json -Depth 3 | Out-File $outputPath -Encoding UTF8
            Write-TestMessage "结果已导出到: $outputPath" "Info"
        } catch {
            Write-TestMessage "导出结果失败: $($_.Exception.Message)" "Warning"
        }
    }

    if ($totalFailed -eq 0) {
        Write-TestMessage "🎉 所有测试通过！" "Success"
        return 0
    } else {
        Write-TestMessage "💥 有 $totalFailed 个测试失败" "Error"
        return 1
    }
}

# 运行主函数
try {
    $exitCode = Main
    exit $exitCode
} catch {
    Write-TestMessage "测试运行器发生致命错误: $($_.Exception.Message)" "Error"
    if ($Verbosity -eq 'Diagnostic') {
        Write-TestMessage "堆栈跟踪: $($_.ScriptStackTrace)" "Debug"
    }
    exit 1
}
