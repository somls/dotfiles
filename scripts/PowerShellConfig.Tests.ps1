# PowerShell 配置测试脚本
# 验证 PowerShell 配置文件和功能

Describe "PowerShell Profile Configuration" {
    BeforeAll {
        # 导入模块
        Import-Module "$PSScriptRoot/../modules/DotfilesUtilities.psm1" -Force
        
        # 检测配置模式（符号链接 vs 复制）
        $script:IsSymlinkMode = $false
        $profilePath = $PROFILE
        if (Test-Path $profilePath) {
            try {
                $item = Get-Item $profilePath -Force
                $script:IsSymlinkMode = $item.LinkType -eq "SymbolicLink"
            } catch {
                $script:IsSymlinkMode = $false
            }
        }
        
        # 检查 PowerShell 配置目录
        $powershellConfigPath = Join-Path $env:USERPROFILE ".powershell"
        if (Test-Path $powershellConfigPath) {
            try {
                $item = Get-Item $powershellConfigPath -Force
                $script:IsPowershellDirSymlink = $item.LinkType -eq "SymbolicLink"
            } catch {
                $script:IsPowershellDirSymlink = $false
            }
        }
    }

    AfterAll {
        # 移除模块
        Remove-Module DotfilesUtilities -Force
    }

    Context "配置文件结构" {
        It "应该存在 PowerShell 配置目录或源目录" {
            if ($script:IsPowershellDirSymlink) {
                # 符号链接模式：检查源目录
                $sourceDir = "$PSScriptRoot/../powershell/.powershell"
                Test-Path $sourceDir | Should Be $true
            } else {
                # 复制模式：检查目标目录
                $profileDir = Join-Path $env:USERPROFILE ".powershell"
                Test-Path $profileDir | Should Be $true
            }
        }

        It "应该存在主配置文件" {
            $profileFile = "$PSScriptRoot/../powershell/Microsoft.PowerShell_profile.ps1"
            Test-Path $profileFile | Should Be $true
        }
    }

    Context "核心功能测试" {
        It "应该定义 Reload-Profile 函数" {
            Get-Command Reload-Profile -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "应该定义 Show-ConfigInfo 函数" {
            Get-Command Show-ConfigInfo -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "应该定义 Clean-ScoopCache 函数" {
            Get-Command Clean-ScoopCache -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "应该定义 Update-System 函数" {
            Get-Command Update-System -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }
    }

    Context "别名测试" {
        It "应该设置 swp 别名" {
            $alias = Get-Alias swp -ErrorAction SilentlyContinue
            $alias | Should Not BeNullOrEmpty
            $alias.Definition | Should Be "Clean-ScoopCache"
        }

        It "应该设置 update 别名" {
            $alias = Get-Alias update -ErrorAction SilentlyContinue
            $alias | Should Not BeNullOrEmpty
            $alias.Definition | Should Be "Update-System"
        }

        It "应该设置 reload 别名" {
            $alias = Get-Alias reload -ErrorAction SilentlyContinue
            $alias | Should Not BeNullOrEmpty
            $alias.Definition | Should Be "Reload-Profile"
        }

        It "应该设置 config-info 别名" {
            $alias = Get-Alias "config-info" -ErrorAction SilentlyContinue
            $alias | Should Not BeNullOrEmpty
            $alias.Definition | Should Be "Show-ConfigInfo"
        }
    }

    Context "代理功能测试" {
        It "应该定义 Enable-Proxy 函数" {
            Get-Command Enable-Proxy -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "应该定义 Disable-Proxy 函数" {
            Get-Command Disable-Proxy -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "应该定义 Show-ProxyStatus 函数" {
            Get-Command Show-ProxyStatus -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "应该定义 Switch-ProxyPort 函数" {
            Get-Command Switch-ProxyPort -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }
    }

    Context "工具集成测试" {
        It "应该能够找到 Starship" {
            Get-Command starship -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "应该能够找到 FZF" {
            Get-Command fzf -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "应该能够找到 Bat" {
            Get-Command bat -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "应该能够找到 Ripgrep" {
            Get-Command rg -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "应该能够找到 Fd" {
            Get-Command fd -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "应该能够找到 Zoxide" {
            Get-Command zoxide -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }
    }
}