# Run-AllTests.ps1 测试脚本
# 验证测试运行器本身的功能

Describe "Test Runner Functionality" {
    Context "测试运行器脚本" {
        It "应该存在 Run-AllTests.ps1 脚本" {
            $scriptPath = "$PSScriptRoot/../scripts/Run-AllTests.ps1"
            Test-Path $scriptPath | Should Be $true
        }

        It "应该能够验证 Run-AllTests.ps1 脚本语法" {
            $tokens = $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile("$PSScriptRoot/../scripts/Run-AllTests.ps1", [ref]$tokens, [ref]$errors)
            $errors.Count | Should Be 0
        }
    }

    Context "测试结果类" {
        It "应该定义 TestSuiteResult 类" {
            $type = 'TestSuiteResult' -as [type]
            $type | Should Not BeNullOrEmpty
        }

        It "应该定义 TestResult 类" {
            $type = 'TestResult' -as [type]
            $type | Should Not BeNullOrEmpty
        }
    }

    Context "测试运行器函数" {
        It "应该定义 Initialize-TestEnvironment 函数" {
            Get-Command Initialize-TestEnvironment -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "应该定义 Write-TestMessage 函数" {
            Get-Command Write-TestMessage -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "应该定义 Find-TestFiles 函数" {
            Get-Command Find-TestFiles -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "应该定义 Invoke-TestFile 函数" {
            Get-Command Invoke-TestFile -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "应该定义 Invoke-TestSuite 函数" {
            Get-Command Invoke-TestSuite -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "应该定义 New-TestReport 函数" {
            Get-Command New-TestReport -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "应该定义 Show-TestSummary 函数" {
            Get-Command Show-TestSummary -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }
    }
}