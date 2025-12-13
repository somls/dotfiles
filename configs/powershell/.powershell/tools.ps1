# ~/.powershell/tools.ps1
# Third-party tool integration - complete functionality version

# Fast mode check
if ($env:POWERSHELL_FAST_MODE -eq "1") { return }

# --- Starship (cross-platform prompt) ---
# Starship is initialized in main configuration file

# --- Zoxide (smart directory jump) ---
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    try {
        Invoke-Expression ((&zoxide init powershell --no-aliases) -join "`n")
        function global:z { param($Path) zoxide query --interactive $Path }
    } catch {
        Write-Warning "Zoxide initialization failed"
    }
}

# --- FZF (fuzzy search) ---
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    $env:FZF_DEFAULT_OPTS = '--height 40% --layout=reverse --border'
    # Set Tab key completion - only if PSReadLine is available and supports it
    if ((Get-Module -ListAvailable -Name PSReadLine) -and (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue) -and (Get-Command Invoke-FzfTabCompletion -ErrorAction SilentlyContinue)) {
        try {
            Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
        } catch {
            # Silently ignore if PSReadLine doesn't support this operation
        }
    }
}

# --- Bat (enhanced cat) ---
if (Get-Command bat -ErrorAction SilentlyContinue) {
    $env:BAT_THEME = "Dracula"
    $env:BAT_STYLE = "numbers,changes,header"
}

# --- Terminal Icons ---
function Import-TerminalIcons {
    if (Get-Module -ListAvailable -Name Terminal-Icons) {
        try {
            Import-Module -Name Terminal-Icons -ErrorAction Stop
            Write-Verbose "Terminal-Icons module loaded successfully"
        } catch {
            Write-Warning "Failed to import Terminal-Icons: $($_.Exception.Message)"
        }
    }
}
Import-TerminalIcons

# --- Tool status check ---
function Show-ToolsStatus {
    <#
    .SYNOPSIS
    Display installed tool status based on packages.txt
    #>
    Write-Host "`nTools Status" -ForegroundColor Cyan
    Write-Host "=" * 20 -ForegroundColor Gray

    # 基于packages.txt的实际工具列表 - PowerShell 5.1兼容格式
    $tools = @{
        "Starship" = (Get-Command starship -ErrorAction SilentlyContinue) -ne $null;
        "Zoxide" = (Get-Command zoxide -ErrorAction SilentlyContinue) -ne $null;
        "FZF" = (Get-Command fzf -ErrorAction SilentlyContinue) -ne $null;
        "Bat" = (Get-Command bat -ErrorAction SilentlyContinue) -ne $null;
        "Ripgrep" = (Get-Command rg -ErrorAction SilentlyContinue) -ne $null;
        "Fd" = (Get-Command fd -ErrorAction SilentlyContinue) -ne $null;
        "JQ" = (Get-Command jq -ErrorAction SilentlyContinue) -ne $null;
        "Git" = (Get-Command git -ErrorAction SilentlyContinue) -ne $null;
        "Neovim" = (Get-Command nvim -ErrorAction SilentlyContinue) -ne $null;
        "7zip" = (Get-Command 7z -ErrorAction SilentlyContinue) -ne $null;
        "Sudo" = (Get-Command sudo -ErrorAction SilentlyContinue) -ne $null;
        "Curl" = (Get-Command curl -ErrorAction SilentlyContinue) -ne $null;
        "GitHubCLI" = (Get-Command gh -ErrorAction SilentlyContinue) -ne $null;
        "Shellcheck" = (Get-Command shellcheck -ErrorAction SilentlyContinue) -ne $null;
        "LazyGit" = (Get-Command lazygit -ErrorAction SilentlyContinue) -ne $null;
        "NodeJS" = (Get-Command node -ErrorAction SilentlyContinue) -ne $null;
        "Python" = (Get-Command python -ErrorAction SilentlyContinue) -ne $null;
        "VSCode" = (Get-Command code -ErrorAction SilentlyContinue) -ne $null
    }

    foreach ($tool in $tools.Keys) {
        $status = if ($tools[$tool]) { "OK" } else { "ERROR" }
        $color = if ($tools[$tool]) { "Green" } else { "Red" }
        Write-Host "$status $tool" -ForegroundColor $color
    }
    Write-Host ""
}

# Add alias
Set-Alias -Name "tools" -Value "Show-ToolsStatus" -Option AllScope

# --- Eza (modern ls) ---
if (Get-Command eza -ErrorAction SilentlyContinue) {
    # 创建eza别名函数（覆盖默认的ll/la）
    function global:ll { eza -l --icons --git @args }
    function global:la { eza -la --icons --git @args }
    function global:lt { eza -T --icons --git-ignore @args }
    function global:llt { eza -lT --icons --git @args }
    
    Write-Verbose "Eza (modern ls) configured"
}

# --- Delta (enhanced git diff) ---
if (Get-Command delta -ErrorAction SilentlyContinue) {
    # Git将自动使用delta（需要在.gitconfig配置）
    $env:DELTA_FEATURES = "+side-by-side"
    Write-Verbose "Delta (enhanced git diff) configured"
}

# --- 编辑器环境变量 ---
if (Get-Command nvim -ErrorAction SilentlyContinue) {
    $env:EDITOR = 'nvim'
    $env:VISUAL = 'nvim'
    Write-Verbose "Editor set to neovim"
} elseif (Get-Command code -ErrorAction SilentlyContinue) {
    $env:EDITOR = 'code --wait'
    $env:VISUAL = 'code --wait'
    Write-Verbose "Editor set to VSCode"
}

# --- Dust (disk usage) ---
if (Get-Command dust -ErrorAction SilentlyContinue) {
    function global:diskusage { dust @args }
    Write-Verbose "Dust (disk usage) configured"
}

# --- Procs (modern ps) ---
if (Get-Command procs -ErrorAction SilentlyContinue) {
    function global:pss { procs @args }
    Write-Verbose "Procs (modern ps) configured"
}

# --- Tokei (code statistics) ---
if (Get-Command tokei -ErrorAction SilentlyContinue) {
    function global:codecount { tokei @args }
    Write-Verbose "Tokei (code statistics) configured"
}

# --- Glow (markdown renderer) ---
if (Get-Command glow -ErrorAction SilentlyContinue) {
    function global:mdview { glow @args }
    Write-Verbose "Glow (markdown renderer) configured"
}

# --- Duf (disk usage/free) ---
if (Get-Command duf -ErrorAction SilentlyContinue) {
    function global:df { duf @args }
    Write-Verbose "Duf (disk usage/free) configured"
}

# --- Gsudo (Windows sudo) ---
if (Get-Command gsudo -ErrorAction SilentlyContinue) {
    # gsudo已通过scoop自动配置
    Write-Verbose "Gsudo (Windows sudo) available"
}
