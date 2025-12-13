# PowerShell 5.1 keybindings configuration

if (Get-Module -ListAvailable -Name PSReadLine) {
    try {
        Import-Module PSReadLine -ErrorAction Stop
        Set-PSReadLineOption -EditMode Windows
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd
        Set-PSReadLineOption -MaximumHistoryCount 4096
        Set-PSReadLineOption -Colors @{
            Command = 'Yellow'
            Parameter = 'Green'
            String = 'DarkCyan'
        }
    } catch {
    }
}

if (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue) {
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory
    Set-PSReadLineKeyHandler -Key Tab -Function Complete
    Set-PSReadLineKeyHandler -Key Ctrl+z -Function Undo
    Set-PSReadLineKeyHandler -Key Ctrl+Backspace -Function BackwardKillWord
    Set-PSReadLineKeyHandler -Key Ctrl+Spacebar -Function MenuComplete
}
