# ~/.powershell/tools.ps1
# 第三方工具集成

# 快速模式检查
if ($env:POWERSHELL_FAST_MODE -eq "1") { return }

# Starship 提示符 (延迟初始化)
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

# fzf 模糊搜索
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
}

# zoxide 智能跳转
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
# 精简版：只包含核心的第三方工具集成

# --- Starship (跨平台提示符) ---
# Starship 在主配置文件中初始化

# --- Zoxide (智能目录跳转) ---
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    try {
        Invoke-Expression ((&zoxide init powershell --no-aliases) -join "`n")
        function global:z { param($Path) zoxide query --interactive $Path }
    } catch {
        Write-Warning "Zoxide initialization failed"
    }
}

# --- FZF (模糊搜索) ---
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    $env:FZF_DEFAULT_OPTS = '--height 40% --layout=reverse --border'
}

# --- Bat (增强版 cat) ---
if (Get-Command bat -ErrorAction SilentlyContinue) {
    $env:BAT_THEME = "Dracula"
    $env:BAT_STYLE = "numbers,changes,header"
}

# --- Terminal Icons ---
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module -Name Terminal-Icons -ErrorAction SilentlyContinue
}

# --- 工具状态检查 ---
function Show-ToolsStatus {
    <#
    .SYNOPSIS
    显示已安装的工具状态
    #>
    Write-Host "`n🛠️  Tools Status" -ForegroundColor Cyan
    Write-Host "=" * 20 -ForegroundColor Gray

    $tools = @{
        "Starship" = (Get-Command starship -ErrorAction SilentlyContinue) -ne $null
        "Zoxide" = (Get-Command zoxide -ErrorAction SilentlyContinue) -ne $null
        "FZF" = (Get-Command fzf -ErrorAction SilentlyContinue) -ne $null
        "Bat" = (Get-Command bat -ErrorAction SilentlyContinue) -ne $null
        "Ripgrep" = (Get-Command rg -ErrorAction SilentlyContinue) -ne $null
        "Fd" = (Get-Command fd -ErrorAction SilentlyContinue) -ne $null
        "JQ" = (Get-Command jq -ErrorAction SilentlyContinue) -ne $null
        "Wget" = (Get-Command wget -ErrorAction SilentlyContinue) -ne $null
        "Btop" = (Get-Command btop -ErrorAction SilentlyContinue) -ne $null
        "Dust" = (Get-Command dust -ErrorAction SilentlyContinue) -ne $null
        "Procs" = (Get-Command procs -ErrorAction SilentlyContinue) -ne $null
        "SD" = (Get-Command sd -ErrorAction SilentlyContinue) -ne $null
        "Tokei" = (Get-Command tokei -ErrorAction SilentlyContinue) -ne $null
        "Hyperfine" = (Get-Command hyperfine -ErrorAction SilentlyContinue) -ne $null
        "JID" = (Get-Command jid -ErrorAction SilentlyContinue) -ne $null
        "GitHub CLI" = (Get-Command gh -ErrorAction SilentlyContinue) -ne $null
    }

    foreach ($tool in $tools.Keys) {
        $status = if ($tools[$tool]) { "✅" } else { "❌" }
        $color = if ($tools[$tool]) { "Green" } else { "Red" }
        Write-Host "$status $tool" -ForegroundColor $color
    }
    Write-Host ""
}

# 添加别名
Set-Alias -Name "tools" -Value "Show-ToolsStatus" -Option AllScope
