# DotfilesUtilities Module Test Script
# Validate DotfilesUtilities module functionality

Describe "DotfilesUtilities Module" {
    BeforeAll {
        # Import module
        Import-Module "$PSScriptRoot/../modules/DotfilesUtilities.psm1" -Force
    }

    AfterAll {
        # Remove module
        Remove-Module DotfilesUtilities -Force
    }

    Context "Output Function Tests" {
        It "Should be able to display success message" {
            { Write-DotfilesMessage -Message "Test success message" -Type "Success" } | Should Not Throw
        }

        It "Should be able to display error message" {
            { Write-DotfilesMessage -Message "Test error message" -Type "Error" } | Should Not Throw
        }

        It "Should be able to display warning message" {
            { Write-DotfilesMessage -Message "Test warning message" -Type "Warning" } | Should Not Throw
        }

        It "Should be able to display info message" {
            { Write-DotfilesMessage -Message "Test info message" -Type "Info" } | Should Not Throw
        }
    }

    Context "Validation Function Tests" {
        It "Should be able to validate existing path" {
            $result = Test-DotfilesPath -Path $PSScriptRoot
            $result.IsValid | Should Be $true
        }

        It "Should be able to validate non-existent path" {
            $result = Test-DotfilesPath -Path "C:\NonExistentPath12345"
            $result.IsValid | Should Be $false
        }

        It "Should be able to create validation result object" {
            $result = Get-DotfilesValidationResult -Component "TestComponent" -Path $PSScriptRoot -Type "Directory"
            $result.Component | Should Be "TestComponent"
            $result.IsValid | Should Be $true
        }
    }

    Context "Environment Function Tests" {
        It "Should be able to get environment information" {
            $envInfo = Get-DotfilesEnvironment
            $envInfo.ComputerName | Should Not BeNullOrEmpty
            $envInfo.UserName | Should Not BeNullOrEmpty
            $envInfo.PowerShellVersion | Should Not BeNullOrEmpty
        }
    }
}

Describe "PowerShell Configuration Module Tests" {
    BeforeAll {
        # Import module
        Import-Module "$PSScriptRoot/../modules/DotfilesUtilities.psm1" -Force
        
        # Detect configuration mode (symbolic link vs copy)
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
        # Remove module
        Remove-Module DotfilesUtilities -Force
    }

    Context "Configuration File Tests" {
        It "Should have main configuration file or source file" {
            if ($script:IsSymlinkMode) {
                # Symbolic link mode: check source file
                $sourcePath = "$PSScriptRoot/../powershell/.powershell"
                Test-Path $sourcePath | Should Be $true
            } else {
                # Copy mode: check target file
                $profilePath = "$env:USERPROFILE/.powershell"
                Test-Path $profilePath | Should Be $true
            }
        }

        It "Should be able to validate PowerShell script syntax" {
            # Always test source file syntax
            $sourceScript = "$PSScriptRoot/../powershell/Microsoft.PowerShell_profile.ps1"
            if (Test-Path $sourceScript) {
                $result = Test-DotfilesPowerShell -Path $sourceScript
                $result.IsValid | Should Be $true
            }
        }
        
        It "Should have configuration verification script" {
            $verifyScript = "$PSScriptRoot/../powershell/verify-config.ps1"
            Test-Path $verifyScript | Should Be $true
        }
    }
    
    if ($script:IsSymlinkMode) {
        Context "Symbolic Link Mode Tests" {
            It "PowerShell configuration should be symbolic link" {
                $powershellConfigPath = Join-Path $env:USERPROFILE ".powershell"
                if (Test-Path $powershellConfigPath) {
                    $item = Get-Item $powershellConfigPath -Force
                    $item.LinkType | Should Be "SymbolicLink"
                }
            }
        }
    }
}