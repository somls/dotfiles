# ~/.powershell/history.ps1
# PowerShell history utility functions
# Note: PSReadLine configuration is handled in keybindings.ps1

# History settings
$MaximumHistoryCount = 4096

# History utility functions
function Get-CommandHistory {
    <#
    .SYNOPSIS
    Display command history with optional filtering

    .PARAMETER Count
    Number of recent commands to display (default: 20)

    .PARAMETER Pattern
    Filter commands by pattern (default: *)

    .EXAMPLE
    Get-CommandHistory -Count 10
    Get-CommandHistory -Pattern "*git*"
    #>
    param(
        [int]$Count = 20,
        [string]$Pattern = "*"
    )

    Get-History | Where-Object { $_.CommandLine -like $Pattern } |
        Select-Object -Last $Count |
        Format-Table Id, @{Name="Command"; Expression={$_.CommandLine}; Width=80}, StartExecutionTime
}

function Clear-CommandHistory {
    <#
    .SYNOPSIS
    Clear PowerShell command history

    .PARAMETER Force
    Skip confirmation prompt

    .EXAMPLE
    Clear-CommandHistory
    Clear-CommandHistory -Force
    #>
    param([switch]$Force)

    if ($Force -or (Read-Host "Clear history? (y/N)") -eq 'y') {
        Clear-History
        if (Get-Module PSReadLine) {
            [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory()
        }
        Write-Host "History cleared" -ForegroundColor Green
    }
}

# Aliases
Set-Alias -Name hist -Value Get-CommandHistory -Option AllScope
Set-Alias -Name clear-hist -Value Clear-CommandHistory -Option AllScope
