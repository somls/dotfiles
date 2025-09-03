# PowerShell 模块测试脚本
# 验证 DotfilesUtilities 模块功能

Describe "DotfilesUtilities Module" {
    BeforeAll {
        # 导入模块
        Import-Module "$PSScriptRoot/DotfilesUtilities.psm1" -Force
    }

    AfterAll {
        # 移除模块
        Remove-Module DotfilesUtilities -Force
    }

    Context "输出函数测试" {
        It "应该能够显示成功消息" {
            { Write-DotfilesMessage -Message "测试成功消息" -Type "Success" } | Should Not Throw
        }

        It "应该能够显示错误消息" {
            { Write-DotfilesMessage -Message "测试错误消息" -Type "Error" } | Should Not Throw
        }

        It "应该能够显示警告消息" {
            { Write-DotfilesMessage -Message "测试警告消息" -Type "Warning" } | Should Not Throw
        }

        It "应该能够显示信息消息" {
            { Write-DotfilesMessage -Message "测试信息消息" -Type "Info" } | Should Not Throw
        }
    }

    Context "验证函数测试" {
        It "应该能够验证存在的路径" {
            $result = Test-DotfilesPath -Path $PSScriptRoot
            $result.IsValid | Should Be $true
        }

        It "应该能够验证不存在的路径" {
            $result = Test-DotfilesPath -Path "C:\NonExistentPath12345"
            $result.IsValid | Should Be $false
        }

        It "应该能够创建验证结果对象" {
            $result = Get-DotfilesValidationResult -Component "TestComponent" -Path $PSScriptRoot
            $result.Component | Should Be "TestComponent"
            $result.IsValid | Should Be $true
        }
    }

    Context "环境函数测试" {
        It "应该能够获取环境信息" {
            $envInfo = Get-DotfilesEnvironment
            $envInfo.ComputerName | Should Not BeNullOrEmpty
            $envInfo.UserName | Should Not BeNullOrEmpty
            $envInfo.PowerShellVersion | Should Not BeNullOrEmpty
        }
    }
}

Describe "PowerShell 配置测试" {
    BeforeAll {
        # 导入模块
        Import-Module "$PSScriptRoot/DotfilesUtilities.psm1" -Force
    }

    AfterAll {
        # 移除模块
        Remove-Module DotfilesUtilities -Force
    }

    Context "配置文件测试" {
        It "应该存在主配置文件" {
            $profilePath = "$env:USERPROFILE/.powershell"
            Test-Path $profilePath | Should Be $true
        }

        It "应该能够验证 PowerShell 脚本语法" {
            $result = Test-DotfilesPowerShell -Path "$PSScriptRoot/../powershell/test-config.ps1"
            $result.IsValid | Should Be $true
        }
    }
}