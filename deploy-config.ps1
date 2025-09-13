# =============================================================================
# 用户配置部署脚本 (deploy-config.ps1)
# 简化版本 - 基于复制而非符号链接的配置部署
# =============================================================================

param(
    [string[]]$ConfigType = @(),
    [switch]$DryRun,
    [switch]$Force,
    [switch]$List
)

# 脚本配置
$ConfigsDir = Join-Path $PSScriptRoot "configs"

# 配置映射 - 简化版本
$ConfigMappings = @{
    "powershell" = @{
        Source = "powershell"
        Files = @(
            @{ From = "Microsoft.PowerShell_profile.ps1"; To = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" }
            @{ From = "Microsoft.PowerShell_profile.ps1"; To = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" }
            @{ From = ".powershell"; To = "$env:USERPROFILE\Documents\PowerShell\.powershell"; IsDir = $true }
            @{ From = ".powershell"; To = "$env:USERPROFILE\Documents\WindowsPowerShell\.powershell"; IsDir = $true }
        )
    }
    "git" = @{
        Source = "git"
        Files = @(
            @{ From = "gitconfig"; To = "$env:USERPROFILE\.gitconfig" }
            @{ From = "gitconfig.local"; To = "$env:USERPROFILE\.gitconfig.local" }
            @{ From = "gitignore_global"; To = "$env:USERPROFILE\.gitignore_global" }
            @{ From = "gitmessage"; To = "$env:USERPROFILE\.gitmessage" }
        )
    }
    "starship" = @{
        Source = "starship"
        Files = @(
            @{ From = "starship.toml"; To = "$env:USERPROFILE\.config\starship.toml" }
        )
    }
    "neovim" = @{
        Source = "neovim"
        Files = @(
            @{ From = "init.lua"; To = "$env:LOCALAPPDATA\nvim\init.lua" }
            @{ From = "lazy-lock.json"; To = "$env:LOCALAPPDATA\nvim\lazy-lock.json" }
            @{ From = "lua"; To = "$env:LOCALAPPDATA\nvim\lua"; IsDir = $true }
        )
    }
    "terminal" = @{
        Source = "WindowsTerminal"
        Files = @(
            @{ From = "settings.json"; To = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" }
        )
    }
    "scoop" = @{
        Source = "scoop"
        Files = @(
            @{ From = "config.json"; To = "$env:USERPROFILE\scoop\config.json" }
        )
    }
}

# 颜色输出函数
function Write-Success { param($Message) Write-Host "OK $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "WARNING $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "ERROR $Message" -ForegroundColor Red }
function Write-Info { param($Message) Write-Host "INFO $Message" -ForegroundColor Cyan }

# 列出可用配置
if ($List) {
    Write-Host "Available Configuration Types:" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    foreach ($config in $ConfigMappings.Keys) {
        $mapping = $ConfigMappings[$config]
        Write-Host "• $config" -ForegroundColor Yellow
        Write-Host "  Source: configs\$($mapping.Source)" -ForegroundColor Gray
        Write-Host "  Files: $($mapping.Files.Count)" -ForegroundColor Gray
        foreach ($file in $mapping.Files) {
            $status = if (Test-Path $file.To) { "EXISTS" } else { "MISSING" }
            Write-Host "    [$status] $($file.To)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    exit 0
}

Write-Host "Dotfiles Configuration Deployment" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

# 验证configs目录
if (-not (Test-Path $ConfigsDir)) {
    Write-Error "configs directory not found: $ConfigsDir"
    exit 1
}

# 确定要部署的配置类型
$ConfigsToDeploy = if ($ConfigType.Count -gt 0) {
    $ConfigType | Where-Object { $ConfigMappings.ContainsKey($_) }
} else {
    $ConfigMappings.Keys
}

if ($ConfigsToDeploy.Count -eq 0) {
    Write-Error "No valid configuration types. Use -List to see available options."
    exit 1
}

Write-Info "Deploying configurations: $($ConfigsToDeploy -join ', ')"

# 部署配置
foreach ($configName in $ConfigsToDeploy) {
    $mapping = $ConfigMappings[$configName]
    $sourceDir = Join-Path $ConfigsDir $mapping.Source

    Write-Host ""
    Write-Host "Deploying config: $configName" -ForegroundColor Yellow

    if (-not (Test-Path $sourceDir)) {
        Write-Warning "Source directory not found: $sourceDir"
        continue
    }

    foreach ($file in $mapping.Files) {
        $sourcePath = Join-Path $sourceDir $file.From
        $targetPath = $file.To
        $isDirectory = $file.IsDir -eq $true

        Write-Host "  Processing: $($file.From)" -ForegroundColor Gray

        if (-not (Test-Path $sourcePath)) {
            Write-Warning "  Source not found: $sourcePath"
            continue
        }

        # 创建目标目录
        $targetDir = Split-Path $targetPath -Parent
        if (-not (Test-Path $targetDir)) {
            if ($DryRun) {
                Write-Info "  [DryRun] Would create directory: $targetDir"
            } else {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                Write-Info "  Created directory: $targetDir"
            }
        }

        # 部署文件或目录
        try {
            if ($DryRun) {
                Write-Info "  [DryRun] Would copy: $sourcePath -> $targetPath"
            } else {
                if ($isDirectory) {
                    if (Test-Path $targetPath) {
                        Remove-Item $targetPath -Recurse -Force
                    }
                    Copy-Item $sourcePath $targetPath -Recurse -Force
                } else {
                    Copy-Item $sourcePath $targetPath -Force
                }
                Write-Success "  Deployed: $targetPath"
            }
        } catch {
            Write-Error "  Deployment failed: $($_.Exception.Message)"
        }
    }
}

Write-Host ""
Write-Host "Deployment Complete" -ForegroundColor Cyan
if ($DryRun) {
    Write-Info "This was a dry run. Remove -DryRun to execute actual deployment"
} else {
    Write-Success "Configuration deployment completed!"
}

Write-Host ""
Write-Host "Usage Tips:" -ForegroundColor Yellow
Write-Host "• Use -List to see all available configuration types" -ForegroundColor Gray
Write-Host "• Use -ConfigType powershell,git to deploy specific configs" -ForegroundColor Gray
Write-Host "• Use -DryRun to preview operations" -ForegroundColor Gray
Write-Host ""
Write-Info "Recommended: Use .\dev-symlink.ps1 for symbolic links (better for development)"
