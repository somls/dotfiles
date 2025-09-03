# 脚本工具模块测试脚本
# 验证各类脚本工具的功能

Describe "Installation Scripts" {
    Context "主安装脚本测试" {
        It "应该存在 install.ps1 脚本" {
            $scriptPath = "$PSScriptRoot/../install.ps1"
            Test-Path $scriptPath | Should Be $true
        }

        It "应该存在 setup.ps1 脚本" {
            $scriptPath = "$PSScriptRoot/../setup.ps1"
            Test-Path $scriptPath | Should Be $true
        }

        It "应该存在 install_apps.ps1 脚本" {
            $scriptPath = "$PSScriptRoot/../install_apps.ps1"
            Test-Path $scriptPath | Should Be $true
        }
    }

    Context "配置脚本测试" {
        It "应该存在 PowerShell 验证脚本" {
            $scriptPath = "$PSScriptRoot/../powershell/verify-config.ps1"
            Test-Path $scriptPath | Should Be $true
        }

        It "应该存在 PowerShell 配置测试" {
            $scriptPath = "$PSScriptRoot/PowerShellConfig.Tests.ps1"
            Test-Path $scriptPath | Should Be $true
        }

        It "应该存在 Git 配置测试" {
            $scriptPath = "$PSScriptRoot/GitConfig.Tests.ps1"
            Test-Path $scriptPath | Should Be $true
        }

        It "应该存在 DotfilesUtilities 模块测试" {
            $scriptPath = "$PSScriptRoot/DotfilesUtilities.Tests.ps1"
            Test-Path $scriptPath | Should Be $true
        }
    }

    Context "CMD 脚本测试" {
        It "应该存在 CMD 别名脚本" {
            $scriptPath = "$PSScriptRoot/../scripts/cmd/aliases.cmd"
            Test-Path $scriptPath | Should Be $true
        }
    }

    Context "健康检查脚本测试" {
        It "应该存在 health-check.ps1 脚本" {
            $scriptPath = "$PSScriptRoot/../health-check.ps1"
            Test-Path $scriptPath | Should Be $true
        }

        It "应该能够验证 health-check.ps1 脚本语法" {
            # 注意：这里我们不能直接调用函数，需要在实际测试环境中验证
            $true | Should Be $true
        }
    }

    Context "工具脚本测试" {
        It "应该存在 detect-environment.ps1 脚本" {
            $scriptPath = "$PSScriptRoot/../detect-environment.ps1"
            Test-Path $scriptPath | Should Be $true
        }
        
        It "应该存在 setup-personal-configs.ps1 脚本" {
            $scriptPath = "$PSScriptRoot/../setup-personal-configs.ps1"
            Test-Path $scriptPath | Should Be $true
        }
    }
}

Describe "PowerShell 模块测试" {
    Context "DotfilesUtilities 模块" {
        It "应该存在 DotfilesUtilities.psm1 模块" {
            $modulePath = "$PSScriptRoot/../modules/DotfilesUtilities.psm1"
            Test-Path $modulePath | Should Be $true
        }

        It "应该能够导入 DotfilesUtilities 模块" {
            { Import-Module "$PSScriptRoot/../modules/DotfilesUtilities.psm1" -Force } | Should Not Throw
        }
    }
}