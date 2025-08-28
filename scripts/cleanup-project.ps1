# cleanup-project.ps1
# 项目清理脚本 - 移除临时文件和日志

<#
.SYNOPSIS
    清理项目中的临时文件、日志文件和备份文件

.DESCRIPTION
    清理 dotfiles 项目中的临时文件、安装日志、备份文件等，
    保持项目目录整洁。不会删除重要的配置文件。

.PARAMETER DryRun
    预览模式，显示将要删除的文件但不实际删除

.EXAMPLE
    .\cleanup-project.ps1
    清理项目临时文件

.EXAMPLE
    .\cleanup-project.ps1 -DryRun
    预览将要清理的文件
#>

[CmdletBinding()]
param(
    [switch]$DryRun
)

# 要清理的文件模式
$filesToRemove = @(
    # 安装日志
    "install.log",
    "health-report.json",
    
    # 临时文件
    "*.tmp",
    "*.log",
    "*.backup",
    
    # 备份目录
    ".dotfiles-backup"
)

Write-Host "🧹 项目清理工具" -ForegroundColor Cyan
Write-Host "=" * 30 -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "🔍 预览模式 - 不会实际删除文件" -ForegroundColor Yellow
    Write-Host ""
}

$cleanedCount = 0

# 清理文件和目录
foreach ($pattern in $filesToRemove) {
    $items = Get-ChildItem -Path $pattern -Recurse -Force -ErrorAction SilentlyContinue
    
    foreach ($item in $items) {
        if ($DryRun) {
            Write-Host "将删除: $($item.FullName)" -ForegroundColor Yellow
        } else {
            try {
                Remove-Item $item.FullName -Recurse -Force -ErrorAction Stop
                Write-Host "已删除: $($item.FullName)" -ForegroundColor Green
                $cleanedCount++
            } catch {
                Write-Host "删除失败: $($item.FullName) - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

# 显示结果
if ($DryRun) {
    Write-Host "`n✨ 预览完成" -ForegroundColor Green
    Write-Host "💡 运行 .\cleanup-project.ps1 执行实际清理" -ForegroundColor Cyan
} else {
    Write-Host "`n✨ 清理完成！已清理 $cleanedCount 个文件/目录" -ForegroundColor Green
    Write-Host "💡 建议：运行 git status 检查更改" -ForegroundColor Cyan
}