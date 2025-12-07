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
