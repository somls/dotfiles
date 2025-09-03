# DotfilesUtilities 模块测试脚本
# 验证 DotfilesUtilities 模块功能

Describe "DotfilesUtilities Module" {
    BeforeAll {
        # 导入模块
        Import-Module "$PSScriptRoot/../modules/DotfilesUtilities.psm1" -Force
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
            $result = Get-DotfilesValidationResult -Component "TestComponent" -Path $PSScriptRoot -Type "Directory"
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

Describe "PowerShell 配置模块测试" {
    BeforeAll {
        # 导入模块
        Import-Module "$PSScriptRoot/../modules/DotfilesUtilities.psm1" -Force
        
        # 检测配置模式（符号链接 vs 复制）
        $script:IsSymlinkMode = $false
        $powershellConfigPath = Join-Path $env:USERPROFILE ".powershell"
        if (Test-Path $powershellConfigPath) {
            try {
                $item = Get-Item $powershellConfigPath -Force
                $script:IsSymlinkMode = $item.LinkType -eq "SymbolicLink"
            } catch {
                $script:IsSymlinkMode = $false
            }
        }
    }

    AfterAll {
        # 移除模块
        Remove-Module DotfilesUtilities -Force
    }

    Context "配置文件测试" {
        It "应该存在主配置文件或源文件" {
            if ($script:IsSymlinkMode) {
                # 符号链接模式：检查源文件
                $sourcePath = "$PSScriptRoot/../powershell/.powershell"
                Test-Path $sourcePath | Should Be $true
            } else {
                # 复制模式：检查目标文件
                $profilePath = "$env:USERPROFILE/.powershell"
                Test-Path $profilePath | Should Be $true
            }
        }

        It "应该能够验证 PowerShell 脚本语法" {
            # 总是测试源文件的语法
            $sourceScript = "$PSScriptRoot/../powershell/Microsoft.PowerShell_profile.ps1"
            if (Test-Path $sourceScript) {
                $result = Test-DotfilesPowerShell -Path $sourceScript
                $result.IsValid | Should Be $true
            }
        }
        
        It "应该存在配置验证脚本" {
            $verifyScript = "$PSScriptRoot/../powershell/verify-config.ps1"
            Test-Path $verifyScript | Should Be $true
        }
    }
    
    if ($script:IsSymlinkMode) {
        Context "符号链接模式测试" {
            It "PowerShell 配置应该是符号链接" {
                $powershellConfigPath = Join-Path $env:USERPROFILE ".powershell"
                if (Test-Path $powershellConfigPath) {
                    $item = Get-Item $powershellConfigPath -Force
                    $item.LinkType | Should Be "SymbolicLink"
                }
            }
        }
    }
}