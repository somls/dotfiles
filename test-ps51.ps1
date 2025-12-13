if (Get-Module -ListAvailable -Name PSReadLine) {
    try {
        Import-Module PSReadLine -ErrorAction Stop
        Write-Host "Imported"
    } catch {
        Write-Host "Failed"
    }
}
