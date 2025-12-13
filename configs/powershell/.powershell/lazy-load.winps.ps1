# PowerShell 5.1 lazy-load configuration

if (-not (Get-Variable -Name __LazyLoadCommands -Scope Global -ErrorAction SilentlyContinue)) {
    $global:__LazyLoadCommands = @{}
}

function Get-LazyLoadStatus {
    Write-Host ""
    Write-Host "Lazy Load Status (PowerShell 5.1)" -ForegroundColor Cyan
    Write-Host ("=" * 40) -ForegroundColor Gray
    if ($global:__LazyLoadCommands.Count -eq 0) {
        Write-Host "No commands registered for lazy loading" -ForegroundColor Yellow
    } else {
        Write-Host "Pending commands:" -ForegroundColor Yellow
        foreach ($cmd in $global:__LazyLoadCommands.Keys) {
            Write-Host "  - $cmd" -ForegroundColor Green
        }
    }
    Write-Host ""
}

Set-Alias -Name lazy-status -Value Get-LazyLoadStatus -Option AllScope -ErrorAction SilentlyContinue
