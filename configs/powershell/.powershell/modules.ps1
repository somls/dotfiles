# ~/.powershell/modules.ps1
#
# 此文件负责所有额外 PowerShell 模块的导入和配置。

# --- PowerShellGet 模块配置 ---
if (Get-Module -ListAvailable -Name PowerShellGet) {
    try {
        # PowerShellGet 通常是核心模块，这里确保最佳配置
        $PowerShellGet = Import-Module PowerShellGet -PassThru -ErrorAction Stop

        # 设置 PSGallery 为受信任的源（如果尚未设置）
        try {
            $psGallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
            if ($psGallery -and -not $psGallery.Trusted) {
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
                Write-Verbose "PSGallery marked as trusted"
            }
        } catch {
            Write-Verbose "Could not configure PSGallery trust: $($_.Exception.Message)"
        }

        Write-Verbose "PowerShellGet module loaded and configured"
    } catch {
        Write-Warning "Failed to configure PowerShellGet: $($_.Exception.Message)"
    }
}

# --- 模块管理工具函数 ---
function Update-InstalledModules {
    <#
    .SYNOPSIS
    更新所有已安装的模块
    #>
    try {
        Write-Host "检查模块更新..." -ForegroundColor Yellow

        $modulesToUpdate = @(
            'PSReadLine'
            'Terminal-Icons'
            'PowerShellGet'
        )

        foreach ($module in $modulesToUpdate) {
            if (Get-Module -ListAvailable -Name $module) {
                Write-Host "检查 $module 更新..." -ForegroundColor Cyan
                try {
                    Update-Module -Name $module -ErrorAction SilentlyContinue
                    Write-Host "$module 更新完成" -ForegroundColor Green
                } catch {
                    Write-Warning "$module 更新失败: $($_.Exception.Message)"
                }
            }
        }

        Write-Host "模块更新检查完成" -ForegroundColor Green
    } catch {
        Write-Warning "模块更新过程出错: $($_.Exception.Message)"
    }
}

function Show-InstalledModules {
    <#
    .SYNOPSIS
    显示已安装的重要模块及其版本
    #>
    Write-Host "`n已安装的 PowerShell 模块" -ForegroundColor Cyan
    Write-Host "=" * 30 -ForegroundColor Gray

    $importantModules = @(
        'PSReadLine'
        'Terminal-Icons'
        'PowerShellGet'
    )

    foreach ($moduleName in $importantModules) {
        $moduleInfo = Get-Module -ListAvailable -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1

        if ($moduleInfo) {
            Write-Host "$moduleName $($moduleInfo.Version)" -ForegroundColor Green

            # 显示导出的命令数量
            $exportedCount = $moduleInfo.ExportedCommands.Count
            if ($exportedCount -gt 0) {
                Write-Host "  └─ 导出 $exportedCount 个命令" -ForegroundColor Gray
            }
        } else {
            Write-Host "$moduleName 未安装" -ForegroundColor Red
        }
    }

    Write-Host ""
}

# 添加别名
Set-Alias -Name "update-modules" -Value "Update-InstalledModules" -Option AllScope
Set-Alias -Name "modules" -Value "Show-InstalledModules" -Option AllScope

Write-Verbose "PowerShell modules configuration loaded"