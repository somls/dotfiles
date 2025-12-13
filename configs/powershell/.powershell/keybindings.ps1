# ~/.powershell/keybindings.ps1
# 此文件负责所有 PSReadLine 的模块导入、配置和快捷键绑定

# --- PSReadLine 模块导入和完整配置 ---
if (Get-Module -ListAvailable -Name PSReadLine) {
    try {
        Import-Module PSReadLine -ErrorAction Stop

        # 基本选项配置
        Set-PSReadLineOption -EditMode Windows

        # 启用高级预测（历史+插件）
        try {
            Set-PSReadLineOption -PredictionSource HistoryAndPlugin
        } catch {
            # 如果不支持插件预测，回退到历史预测
            Set-PSReadLineOption -PredictionSource History
            Write-Verbose "HistoryAndPlugin prediction not supported, using History only"
        }

        Set-PSReadLineOption -HistorySearchCursorMovesToEnd

        # 预测视图样式（兼容性检查）
        try {
            Set-PSReadLineOption -PredictionViewStyle ListView
        } catch {
            Write-Verbose "ListView prediction not supported in this PSReadLine version"
        }

        # 历史记录配置
        Set-PSReadLineOption -MaximumHistoryCount 4096

        # 静音模式（避免beep声）
        Set-PSReadLineOption -BellStyle None

        # 增强补全体验
        try {
            Set-PSReadLineOption -ShowToolTips
            Set-PSReadLineOption -CompletionQueryItems 50
        } catch {
            Write-Verbose "Some PSReadLine options not supported in this version"
        }

        # 智能历史过滤器
        Set-PSReadLineOption -AddToHistoryHandler {
            param($line)
            # 过滤简单命令和敏感信息
            if ($line.Length -lt 3 -or
                $line -match '^\s*(ls|dir|pwd|cd|exit|clear|cls)\s*$' -or
                $line -match 'password|secret|token|key') {
                return $false
            }
            return $true
        }

        # 颜色配置
        Set-PSReadLineOption -Colors @{
            Command = 'Yellow'
            Parameter = 'Green'
            String = 'DarkCyan'
        }
    } catch {
        Write-Warning "Failed to configure PSReadLine: $($_.Exception.Message)"
    }
}

# --- 快捷键绑定 ---
# 通用快捷键（跨平台）
if (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue) {
    # 历史搜索
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory

    # 编辑功能
    Set-PSReadLineKeyHandler -Key Tab -Function Complete
    Set-PSReadLineKeyHandler -Key Shift+Enter -Function AddLine
    Set-PSReadLineKeyHandler -Key Ctrl+z -Function Undo
    Set-PSReadLineKeyHandler -Key Ctrl+Backspace -Function BackwardKillWord
    Set-PSReadLineKeyHandler -Key Alt+. -Function YankLastArg

    # 增强快捷键
    Set-PSReadLineKeyHandler -Key Ctrl+d -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Ctrl+Spacebar -Function MenuComplete

    # 按单词移动（现代终端风格）
    Set-PSReadLineKeyHandler -Key Alt+LeftArrow -Function BackwardWord
    Set-PSReadLineKeyHandler -Key Alt+RightArrow -Function ForwardWord

    # Ctrl+W 删除前一个单词
    Set-PSReadLineKeyHandler -Key Ctrl+w -Function BackwardKillWord

    # F2 切换预测视图（InlineView <-> ListView）
    Set-PSReadLineKeyHandler -Key F2 `
        -BriefDescription "SwitchPredictionView" `
        -LongDescription "Switch between InlineView and ListView" `
        -ScriptBlock {
            $current = (Get-PSReadLineOption).PredictionViewStyle
            if ($current -eq 'InlineView') {
                Set-PSReadLineOption -PredictionViewStyle ListView
            } else {
                Set-PSReadLineOption -PredictionViewStyle InlineView
            }
        }
}

# --- 平台特定快捷键 ---
# 平台检测（兼容 PowerShell 5.1）
$isWindowsPlatform = (-not (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue)) -or $IsWindows
$isMacOSPlatform = (Get-Variable -Name IsMacOS -ErrorAction SilentlyContinue) -and $IsMacOS
$isLinuxPlatform = (Get-Variable -Name IsLinux -ErrorAction SilentlyContinue) -and $IsLinux

if ($isWindowsPlatform) {
    # Windows 特定配置（如果需要可在此添加）
}

if ($isMacOSPlatform) {
    # macOS 特定快捷键
    if (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue) {
        Set-PSReadLineKeyHandler -Key Cmd+d -Function MenuComplete
        Set-PSReadLineKeyHandler -Key Cmd+z -Function Undo
    }
}

if ($isLinuxPlatform) {
    # Linux 特定配置（如果需要可在此添加）
}

# 提示: 使用 `Get-PSReadLineKeyHandler` 命令可以查看所有已绑定的快捷键和可用的函数
