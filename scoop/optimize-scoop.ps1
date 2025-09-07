# =============================================================================
# Scoop包精简脚本 - 移除不必要的包以提升启动性能
# 生成于: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# =============================================================================

# 需要移除的包列表 (功能重叠或使用频率低)
$packagesToRemove = @(
    "pyenv-win",     # 与fnm功能重叠
    "httpie",        # curl已够用
    "broot",         # 与tre功能重叠
    "just",          # 专用工具，使用频率低
    "dog",           # 专用工具，使用频率低
    "hexyl",         # 专用工具，使用频率低
    "gping",         # 系统ping已够用
    "sd",            # 专用工具，使用频率低
    "tokei",         # 代码统计，使用频率低
    "hyperfine",     # 基准测试，使用频率低
    "jid",           # JSON查询，使用频率低
    "tealdeer"       # tldr替代品，使用频率低
)

# 需要保留的核心包
$corePackages = @(
    "git", "ripgrep", "zoxide", "fzf", "bat", "fd", "jq", "neovim", 
    "starship", "vscode", "sudo", "curl", "7zip", "fnm", "shellcheck", 
    "prettier", "gh", "delta", "eza", "tre", "choose", "duf", "btop", 
    "dust", "procs", "bandwhich", "lazygit", "python", "nodejs"
)

Write-Host "🔍 检查当前安装的包..." -ForegroundColor Yellow

# 获取当前已安装的包
$installedPackages = scoop list | Where-Object { $_.Name -ne '' } | Select-Object -ExpandProperty Name

# 找出需要移除的已安装包
$packagesToUninstall = $packagesToRemove | Where-Object { $_ -in $installedPackages }

if ($packagesToUninstall.Count -eq 0) {
    Write-Host "✅ 没有找到需要移除的包" -ForegroundColor Green
} else {
    Write-Host "🗑️ 准备移除以下包:" -ForegroundColor Red
    $packagesToUninstall | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    
    Write-Host "`n⚠️ 警告：此操作将移除上述包" -ForegroundColor Yellow
    $confirm = Read-Host "是否继续? (y/N)"
    
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        foreach ($package in $packagesToUninstall) {
            Write-Host "正在移除 $package..." -ForegroundColor Yellow
            try {
                scoop uninstall $package
                Write-Host "✅ $package 已移除" -ForegroundColor Green
            } catch {
                Write-Host "❌ 移除 $package 失败: $_" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "❌ 操作已取消" -ForegroundColor Yellow
    }
}

# 显示最终状态
Write-Host "`n📊 精简后的包状态:" -ForegroundColor Cyan
$finalPackages = scoop list | Where-Object { $_.Name -ne '' } | Select-Object -ExpandProperty Name
Write-Host "总包数: $($finalPackages.Count)" -ForegroundColor Cyan
Write-Host "核心包数: $($corePackages.Count)" -ForegroundColor Cyan

# 检查是否有缺失的核心包
$missingCore = $corePackages | Where-Object { $_ -notin $finalPackages }
if ($missingCore.Count -gt 0) {
    Write-Host "`n⚠️ 缺失的核心包:" -ForegroundColor Yellow
    $missingCore | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}

Write-Host "`n✨ Scoop包精简完成!" -ForegroundColor Green
Write-Host "💡 建议重启PowerShell以获得最佳性能" -ForegroundColor Blue