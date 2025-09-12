# ~/.powershell/history.ps1
# PowerShell history configuration

# History settings
$MaximumHistoryCount = 4096

# PSReadLine configuration (if available)
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine -Force
    
    # History search (with compatibility check)
    try {
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -PredictionViewStyle ListView
    } catch {
        # Skip prediction features if not supported
        Write-Verbose "Prediction features not available in this environment"
    }
    Set-PSReadLineOption -EditMode Windows
    
    # History save
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -MaximumHistoryCount $MaximumHistoryCount
    
    # Key bindings
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function Complete
    
    # Smart history
    Set-PSReadLineOption -AddToHistoryHandler {
        param($line)
        # Filter out simple commands and sensitive information
        if ($line.Length -lt 3 -or 
            $line -match '^\s*(ls|dir|pwd|cd|exit|clear|cls)\s*$' -or
            $line -match 'password|secret|token|key') {
            return $false
        }
        return $true
    }
}

# History utility functions
function Get-CommandHistory {
    param(
        [int]$Count = 20,
        [string]$Pattern = "*"
    )
    
    Get-History | Where-Object { $_.CommandLine -like $Pattern } | 
        Select-Object -Last $Count | 
        Format-Table Id, @{Name="Command"; Expression={$_.CommandLine}; Width=80}, StartExecutionTime
}

function Clear-CommandHistory {
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
Set-Alias -Name hist -Value Get-CommandHistory
Set-Alias -Name clear-hist -Value Clear-CommandHistory