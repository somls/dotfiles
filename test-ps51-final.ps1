Write-Host "==================================" -ForegroundColor Cyan
Write-Host "PowerShell 5.1 Configuration Test" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
Write-Host ""

# Test commands
$commands = @('lazy-status', 'hist', 'clear-hist')
Write-Host "Testing commands:" -ForegroundColor Cyan
foreach ($cmd in $commands) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $cmd" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $cmd" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Running lazy-status:" -ForegroundColor Cyan
lazy-status

Write-Host "==================================" -ForegroundColor Green
Write-Host "Test completed successfully!" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Green
