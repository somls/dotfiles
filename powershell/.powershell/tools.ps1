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
    # Set Tab key completion
    if (Get-Command Invoke-FzfTabCompletion -ErrorAction SilentlyContinue) {
        Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
    }
}

# --- Bat (enhanced cat) ---
if (Get-Command bat -ErrorAction SilentlyContinue) {
    $env:BAT_THEME = "Dracula"
    $env:BAT_STYLE = "numbers,changes,header"
}

# --- Terminal Icons ---
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module -Name Terminal-Icons -ErrorAction SilentlyContinue
}

# --- Tool status check ---
function Show-ToolsStatus {
    <#
    .SYNOPSIS
    Display installed tool status
    #>
    Write-Host "`nTools Status" -ForegroundColor Cyan
    Write-Host "=" * 20 -ForegroundColor Gray

    $tools = @{
        "Starship" = (Get-Command starship -ErrorAction SilentlyContinue) -ne $null
        "Zoxide" = (Get-Command zoxide -ErrorAction SilentlyContinue) -ne $null
        "FZF" = (Get-Command fzf -ErrorAction SilentlyContinue) -ne $null
        "Bat" = (Get-Command bat -ErrorAction SilentlyContinue) -ne $null
        "Ripgrep" = (Get-Command rg -ErrorAction SilentlyContinue) -ne $null
        "Fd" = (Get-Command fd -ErrorAction SilentlyContinue) -ne $null
        "JQ" = (Get-Command jq -ErrorAction SilentlyContinue) -ne $null
        "Btop" = (Get-Command btop -ErrorAction SilentlyContinue) -ne $null
        "Dust" = (Get-Command dust -ErrorAction SilentlyContinue) -ne $null
        "Procs" = (Get-Command procs -ErrorAction SilentlyContinue) -ne $null
        "GitHub CLI" = (Get-Command gh -ErrorAction SilentlyContinue) -ne $null
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