# ~/.powershell/keybindings.ps1
#
# 此文件负责所有 PSReadLine 的快捷键绑定。

# --- PSReadLine 模块导入和基本配置 ---
if (Get-Module -ListAvailable -Name PSReadLine) {
    try {
        Import-Module PSReadLine -ErrorAction Stop

        # 基本配置
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd
        Set-PSReadLineOption -Colors @{
            Command = 'Yellow'
            Parameter = 'Green'
            String = 'DarkCyan'
        }
    } catch {
        Write-Warning "Failed to configure PSReadLine: $($_.Exception.Message)"
    }
}

# --- 平台判断（可扩展）---
if ($IsWindows) {
    # Windows 下的快捷键
    Set-PSReadLineKeyHandler -Key Tab -Function Complete
    Set-PSReadLineKeyHandler -Key Shift+Enter -Function AddLine
    Set-PSReadLineKeyHandler -Key Ctrl+d -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Ctrl+Spacebar -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory
    Set-PSReadLineKeyHandler -Key Ctrl+z -Function Undo
    Set-PSReadLineKeyHandler -Key Ctrl+Backspace -Function BackwardKillWord
    Set-PSReadLineKeyHandler -Key Alt+. -Function YankLastArg
}
if ($IsMacOS) {
    # macOS 下的快捷键
    Set-PSReadLineKeyHandler -Key Cmd+d -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Cmd+z -Function Undo
}
if ($IsLinux) {
    # Linux 下的快捷键
    Set-PSReadLineKeyHandler -Key Ctrl+d -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Ctrl+z -Function Undo
}

# 可扩展 macOS/Linux 下的快捷键
# 提示: 使用 `Get-PSReadLineKeyHandler` 命令可以查看所有已绑定的快捷键和可用的函数。