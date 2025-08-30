# setup-personal-configs.ps1
# 个人配置设置脚本 - 帮助用户安全地配置个人信息

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Force
)

function Write-Status {
    param([string]$Message, [string]$Type = 'Info')
    $color = switch ($Type) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        default { 'Cyan' }
    }
    Write-Host "[$Type] $Message" -ForegroundColor $color
}

function Copy-ConfigTemplate {
    param(
        [string]$SourceTemplate,
        [string]$TargetPath,
        [string]$Description
    )
    
    if (-not (Test-Path $SourceTemplate)) {
        Write-Status "模板文件不存在: $SourceTemplate" 'Error'
        return $false
    }
    
    $targetDir = Split-Path $TargetPath -Parent
    if ($targetDir -and -not (Test-Path $targetDir)) {
        if ($DryRun) {
            Write-Status "将创建目录: $targetDir" 'Info'
        } else {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
    }
    
    if (Test-Path $TargetPath) {
        if (-not $Force) {
            Write-Status "配置文件已存在，跳过: $TargetPath" 'Warning'
            return $true
        } else {
            Write-Status "强制覆盖现有文件: $TargetPath" 'Warning'
        }
    }
    
    if ($DryRun) {
        Write-Status "将复制: $SourceTemplate -> $TargetPath ($Description)" 'Info'
    } else {
        try {
            Copy-Item $SourceTemplate $TargetPath -Force
            Write-Status "已创建: $TargetPath ($Description)" 'Success'
            return $true
        } catch {
            Write-Status "复制失败: $($_.Exception.Message)" 'Error'
            return $false
        }
    }
    return $true
}

# 配置文件映射
$ConfigMappings = @(
    @{
        Template = "git\.gitconfig.local.example"
        Target = "$env:USERPROFILE\.gitconfig.local"
        Description = "Git 用户配置"
        Required = $true
    },

    @{
        Template = "scoop\config.json.example"
        Target = "scoop\config.json"
        Description = "Scoop 包管理器配置"
        Required = $false
    }
)

Write-Host "🔒 个人配置设置向导" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor DarkCyan

if ($DryRun) {
    Write-Host "🔍 预览模式 - 不会实际创建文件" -ForegroundColor Yellow
}

$results = @{
    Success = @()
    Failed = @()
    Skipped = @()
}

foreach ($config in $ConfigMappings) {
    Write-Host "`n📁 处理: $($config.Description)" -ForegroundColor Yellow
    
    $success = Copy-ConfigTemplate -SourceTemplate $config.Template -TargetPath $config.Target -Description $config.Description
    
    if ($success) {
        if ((Test-Path $config.Target) -or $DryRun) {
            $results.Success += $config.Description
        } else {
            $results.Skipped += $config.Description
        }
    } else {
        $results.Failed += $config.Description
    }
}

# 显示结果摘要
Write-Host "`n" + "=" * 50 -ForegroundColor DarkCyan
Write-Host "配置设置完成" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor DarkCyan

if ($results.Success.Count -gt 0) {
    Write-Host "✅ 成功: $($results.Success.Count) 个配置" -ForegroundColor Green
    $results.Success | ForEach-Object { Write-Host "   - $_" -ForegroundColor Gray }
}

if ($results.Skipped.Count -gt 0) {
    Write-Host "⏭️  跳过: $($results.Skipped.Count) 个配置" -ForegroundColor Yellow
    $results.Skipped | ForEach-Object { Write-Host "   - $_" -ForegroundColor Gray }
}

if ($results.Failed.Count -gt 0) {
    Write-Host "❌ 失败: $($results.Failed.Count) 个配置" -ForegroundColor Red
    $results.Failed | ForEach-Object { Write-Host "   - $_" -ForegroundColor Gray }
}

# 后续步骤提示
if (-not $DryRun -and $results.Success.Count -gt 0) {
    Write-Host "`n💡 后续步骤:" -ForegroundColor Yellow
    Write-Host "1. 编辑 ~/.gitconfig.local 填入您的 Git 用户信息" -ForegroundColor Gray
    Write-Host "2. 根据需要修改其他配置文件中的个人信息" -ForegroundColor Gray
    Write-Host "3. 查看 SECURITY.md 了解详细的安全配置指南" -ForegroundColor Gray
    Write-Host "4. 运行 .\health-check.ps1 验证配置" -ForegroundColor Gray
}

Write-Host "`n📚 更多信息请查看: SECURITY.md" -ForegroundColor Cyan