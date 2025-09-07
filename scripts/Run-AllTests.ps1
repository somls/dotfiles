# Run-AllTests.ps1
# Enhanced test runner - runs all tests in the project with parallel execution and multiple test types

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

# Color output function
function Write-TestMessage {
    param(
        [string]$Message,
        [string]$Type = 'Info',
        [string]$Level = 'Normal'
    )

    # Filter messages based on verbosity
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
        'Success' { 'OK' }
        'Error' { 'ERROR' }
        'Warning' { 'WARN' }
        'Info' { 'INFO' }
        'Debug' { 'DEBUG' }
        default { '' }
    }

    $timestamp = if ($Verbosity -eq 'Diagnostic') { "[$(Get-Date -Format 'HH:mm:ss')] " } else { "" }
    Write-Host "$timestamp$prefix $Message" -ForegroundColor $color
}

# Get test files
function Get-TestFiles {
    param([string]$TestTypeFilter, [string]$NameFilter)

    $testDir = Join-Path $ProjectRoot "scripts"
    $testFiles = @()

    # Filter by test type
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

    # Look for other test directories
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

# Run single test file
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
        Write-TestMessage "Running test: $($TestFile.Name)" "Info" "Normal"

        # Check if Pester is needed
        $content = Get-Content $TestFile.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -match "Describe|Context|It") {
            # Pester test
            if (-not (Get-Module -ListAvailable -Name Pester)) {
                $result.Errors += "Pester module required: Install-Module Pester -Force"
                Write-TestMessage "Pester module required to run tests, please install: Install-Module Pester -Force" "Warning"
                return $result
            }

            Import-Module Pester -Force -ErrorAction SilentlyContinue

            # Compatible with different versions of Pester
            $pesterVersion = (Get-Module Pester).Version
            if ($pesterVersion -and $pesterVersion.Major -ge 5) {
                # Pester 5.x+ uses configuration object
                $pesterConfig = New-PesterConfiguration
                $pesterConfig.Run.Path = $TestFile.FullName
                $pesterConfig.Run.PassThru = $true
                $pesterConfig.Output.Verbosity = if ($Verbosity -eq 'Quiet') { 'None' } elseif ($Verbosity -eq 'Diagnostic') { 'Detailed' } else { 'Normal' }
                $pesterResult = Invoke-Pester -Configuration $pesterConfig
            } else {
                # Pester 4.x and earlier use parameters
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
            # Native PowerShell test
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
                $result.Errors += "Test timeout ($TimeoutMinutes minutes)"
                Stop-Job $testJob
            }

            Remove-Job $testJob -Force
        }

    } catch {
        $result.Success = $false
        $result.FailedCount = 1
        $result.Errors += $_.Exception.Message
        Write-TestMessage "Test execution exception: $($_.Exception.Message)" "Error"
    } finally {
        $stopwatch.Stop()
        $result.Duration = $stopwatch.Elapsed
    }

    # Output result
    if ($result.Success) {
        Write-TestMessage "OK Test passed: $($TestFile.Name) ($($result.PassedCount)/$($result.TotalCount)) - $($result.Duration.TotalSeconds.ToString('F2'))s" "Success"
    } else {
        Write-TestMessage "ERROR Test failed: $($TestFile.Name) ($($result.FailedCount) failures) - $($result.Duration.TotalSeconds.ToString('F2'))s" "Error"
        if ($Verbosity -in @('Detailed', 'Diagnostic') -and $result.Errors.Count -gt 0) {
            foreach ($error in $result.Errors) {
                Write-TestMessage "  Error: $error" "Error"
            }
        }
    }

    return $result
}

# Main function
function Main {
    Write-TestMessage "Running Dotfiles Test Suite" "Info"
    Write-TestMessage ("=" * 50) "Info"
    Write-TestMessage "Test Type: $TestType | Filter: $Filter | Parallel: $Parallel" "Info"

    if ($Verbosity -eq 'Diagnostic') {
        Write-TestMessage "PowerShell Version: $($PSVersionTable.PSVersion)" "Debug"
        Write-TestMessage "Processor Cores: $([Environment]::ProcessorCount)" "Debug"
        Write-TestMessage "Max Parallel Jobs: $MaxParallelJobs" "Debug"
    }

    $testFiles = Get-TestFiles -TestTypeFilter $TestType -NameFilter $Filter

    if (@($testFiles).Count -eq 0) {
        Write-TestMessage "No matching test files found (Type: $TestType, Filter: $Filter)" "Warning"
        return 0
    }

    Write-TestMessage "Found $(@($testFiles).Count) test files" "Info"

    $overallStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $allResults = @()

    if ($Parallel -and @($testFiles).Count -gt 1) {
        Write-TestMessage "Using parallel execution (max $MaxParallelJobs concurrent jobs)" "Info"

        # Parallel execution needs to pass function definitions
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
                # Check if Pester is needed
                $content = Get-Content $TestFileInfo.FullName -Raw -ErrorAction SilentlyContinue
                if ($content -match "Describe|Context|It") {
                    # Pester test
                    if (-not (Get-Module -ListAvailable -Name Pester)) {
                        $result.Errors += "Pester module required: Install-Module Pester -Force"
                        return $result
                    }

                    Import-Module Pester -Force -ErrorAction SilentlyContinue

                    # Compatible with different versions of Pester
                    $pesterVersion = (Get-Module Pester).Version
                    if ($pesterVersion -and $pesterVersion.Major -ge 5) {
                        # Pester 5.x+ uses configuration object
                        $pesterConfig = New-PesterConfiguration
                        $pesterConfig.Run.Path = $TestFileInfo.FullName
                        $pesterConfig.Run.PassThru = $true
                        $pesterConfig.Output.Verbosity = if ($VerbosityLevel -eq 'Quiet') { 'None' } elseif ($VerbosityLevel -eq 'Diagnostic') { 'Detailed' } else { 'Normal' }
                        $pesterResult = Invoke-Pester -Configuration $pesterConfig
                    } else {
                        # Pester 4.x and earlier use parameters
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
                    # Native PowerShell test
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
                        $result.Errors += "Test timeout ($TimeoutMin minutes)"
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

            # Output result
            if ($_.Success) {
                Write-Host "OK Test passed: $($_.TestFile) ($($_.PassedCount)/$($_.TotalCount)) - $($_.Duration.TotalSeconds.ToString('F2'))s" -ForegroundColor Green
            } else {
                Write-Host "ERROR Test failed: $($_.TestFile) ($($_.FailedCount) failures) - $($_.Duration.TotalSeconds.ToString('F2'))s" -ForegroundColor Red
            }
        }
    } else {
        # Sequential execution
        foreach ($testFile in $testFiles) {
            $result = Invoke-SingleTest -TestFile $testFile
            $allResults += $result

            if (-not $result.Success -and -not $ContinueOnError) {
                Write-TestMessage "Test failed, stopping execution (use -ContinueOnError to continue)" "Error"
                break
            }
        }
    }

    $overallStopwatch.Stop()

    # Calculate summary statistics
    $totalTests = (@($allResults) | Measure-Object -Property TotalCount -Sum).Sum
    $totalPassed = (@($allResults) | Measure-Object -Property PassedCount -Sum).Sum
    $totalFailed = (@($allResults) | Measure-Object -Property FailedCount -Sum).Sum
    $totalSkipped = (@($allResults) | Measure-Object -Property SkippedCount -Sum).Sum
    $successRate = if ($totalTests -gt 0) { ($totalPassed / $totalTests * 100) } else { 0 }

    # Display summary
    Write-TestMessage "" "Info"
    Write-TestMessage ("=" * 50) "Info"
    Write-TestMessage "Test Execution Summary" "Info"
    Write-TestMessage ("=" * 50) "Info"
    Write-TestMessage "Test Files: $(@($allResults).Count)" "Info"
    Write-TestMessage "Total Tests: $totalTests" "Info"
    Write-TestMessage "Passed: $totalPassed" "Success"
    Write-TestMessage "Failed: $totalFailed" "Error"
    if ($totalSkipped -gt 0) {
        Write-TestMessage "Skipped: $totalSkipped" "Warning"
    }
    Write-TestMessage "Success Rate: $($successRate.ToString('F1'))%" "Info"
    Write-TestMessage "Execution Time: $($overallStopwatch.Elapsed.ToString('mm\:ss\.ff'))" "Info"

    # Failed test details
    if ($totalFailed -gt 0 -and $Verbosity -ne 'Quiet') {
        Write-TestMessage "" "Info"
        Write-TestMessage "Failed Tests:" "Error"
        $failedTests = @($allResults | Where-Object { -not $_.Success })
        foreach ($failed in $failedTests) {
            Write-TestMessage "  ERROR $($failed.TestFile)" "Error"
        }
    }

    # Performance statistics
    if ($Verbosity -in @('Detailed', 'Diagnostic')) {
        Write-TestMessage "" "Info"
        Write-TestMessage "Performance Statistics:" "Info"
        $avgDuration = (@($allResults) | Measure-Object -Property Duration -Average).Average.TotalSeconds
        $slowestTest = @($allResults) | Sort-Object Duration -Descending | Select-Object -First 1
        Write-TestMessage "Average Execution Time: $($avgDuration.ToString('F2'))s" "Info"
        Write-TestMessage "Slowest Test: $($slowestTest.TestFile) ($($slowestTest.Duration.TotalSeconds.ToString('F2'))s)" "Info"
    }

    # Export results
    if ($OutputFile -and @($allResults).Count -gt 0) {
        try {
            $outputPath = Join-Path $ProjectRoot $OutputFile
            $allResults | ConvertTo-Json -Depth 3 | Out-File $outputPath -Encoding UTF8
            Write-TestMessage "Results exported to: $outputPath" "Info"
        } catch {
            Write-TestMessage "Failed to export results: $($_.Exception.Message)" "Warning"
        }
    }

    if ($totalFailed -eq 0) {
        Write-TestMessage "All tests passed!" "Success"
        return 0
    } else {
        Write-TestMessage "$totalFailed tests failed" "Error"
        return 1
    }
}

# Run main function
try {
    $exitCode = Main
    exit $exitCode
} catch {
    Write-TestMessage "Fatal error in test runner: $($_.Exception.Message)" "Error"
    if ($Verbosity -eq 'Diagnostic') {
        Write-TestMessage "Stack trace: $($_.ScriptStackTrace)" "Debug"
    }
    exit 1
}