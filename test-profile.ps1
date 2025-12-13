# PowerShell 双版本配置测试脚本
# 测试 PowerShell 5.1 和 PowerShell 7+ 配置加载

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "PowerShell Configuration Test" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# 检测当前版本
$version = $PSVersionTable.PSVersion.Major
$edition = $PSVersionTable.PSEdition
$isWinPS = ($edition -eq 'Desktop' -or $version -lt 6)

Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
Write-Host "Edition: $edition" -ForegroundColor Yellow
Write-Host "Is Windows PS 5.1: $isWinPS" -ForegroundColor Yellow
Write-Host ""

# 测试配置文件
Write-Host "Testing Configuration Loading..." -ForegroundColor Cyan
Write-Host "--------------------------------" -ForegroundColor Gray

$testResults = @()

# 测试 keybindings
$keybindingsFile = if ($isWinPS) { "keybindings.winps.ps1" } else { "keybindings.ps1" }
$keybindingsPath = Join-Path (Split-Path $PROFILE -Parent) ".powershell\$keybindingsFile"

if (Test-Path $keybindingsPath) {
    try {
        . $keybindingsPath
        Write-Host "[OK] $keybindingsFile loaded" -ForegroundColor Green
        $testResults += @{ File = $keybindingsFile; Status = "OK" }
    } catch {
        Write-Host "[FAIL] $keybindingsFile error: $($_.Exception.Message)" -ForegroundColor Red
        $testResults += @{ File = $keybindingsFile; Status = "FAIL" }
    }
} else {
    Write-Host "[SKIP] $keybindingsFile not found" -ForegroundColor Yellow
    $testResults += @{ File = $keybindingsFile; Status = "SKIP" }
}

# 测试 lazy-load
$lazyLoadFile = if ($isWinPS) { "lazy-load.winps.ps1" } else { "lazy-load.ps1" }
$lazyLoadPath = Join-Path (Split-Path $PROFILE -Parent) ".powershell\$lazyLoadFile"

if (Test-Path $lazyLoadPath) {
    try {
        . $lazyLoadPath
        Write-Host "[OK] $lazyLoadFile loaded" -ForegroundColor Green
        $testResults += @{ File = $lazyLoadFile; Status = "OK" }
    } catch {
        Write-Host "[FAIL] $lazyLoadFile error: $($_.Exception.Message)" -ForegroundColor Red
        $testResults += @{ File = $lazyLoadFile; Status = "FAIL" }
    }
} else {
    Write-Host "[SKIP] $lazyLoadFile not found" -ForegroundColor Yellow
    $testResults += @{ File = $lazyLoadFile; Status = "SKIP" }
}

Write-Host ""

# 测试命令可用性
Write-Host "Testing Command Availability..." -ForegroundColor Cyan
Write-Host "--------------------------------" -ForegroundColor Gray

$commands = @("lazy-status", "hist", "lazy-clear", "clear-hist")

foreach ($cmd in $commands) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        Write-Host "[OK] Command '$cmd' available" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Command '$cmd' not found" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Test completed!" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Cyan
