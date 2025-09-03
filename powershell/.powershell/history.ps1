# ~/.powershell/history.ps1
# PowerShell 历史记录配置

# 历史记录设置
$MaximumHistoryCount = 4096

# PSReadLine 配置 (如果可用)
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine -Force
    
    # 历史记录搜索
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Windows
    
    # 历史记录保存
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -MaximumHistoryCount $MaximumHistoryCount
    
    # 键绑定
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function Complete
    
    # 智能历史记录
    Set-PSReadLineOption -AddToHistoryHandler {
        param($line)
        # 过滤掉简单命令和敏感信息
        if ($line.Length -lt 3 -or 
            $line -match '^\s*(ls|dir|pwd|cd|exit|clear|cls)\s*$' -or
            $line -match 'password|secret|token|key') {
            return $false
        }
        return $true
    }
}

# 历史记录实用函数
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
    
    if ($Force -or (Read-Host "确定要清除历史记录吗? (y/N)") -eq 'y') {
        Clear-History
        if (Get-Module PSReadLine) {
            [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory()
        }
        Write-Host "✅ 历史记录已清除" -ForegroundColor Green
    }
}

# 别名
Set-Alias -Name hist -Value Get-CommandHistory
Set-Alias -Name clear-hist -Value Clear-CommandHistory