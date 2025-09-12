# ~/.powershell/theme.ps1
# 精简版：基础的主题和提示符配置

# --- Terminal Icons ---
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module -Name Terminal-Icons -ErrorAction SilentlyContinue
}

# --- 简单备用提示符 ---
function Enable-SimplePrompt {
    <#
    .SYNOPSIS
    启用简单的提示符
    #>
    function global:prompt {
        $location = Get-Location
        $shortPath = $location.Path.Replace($env:USERPROFILE, '~')
        "PS $shortPath> "
    }
    Write-Host "✅ Simple prompt enabled" -ForegroundColor Green
}

# --- 彩色提示符 ---
function Enable-ColorPrompt {
    <#
    .SYNOPSIS
    启用彩色提示符
    #>
    function global:prompt {
        $location = Get-Location
        $shortPath = $location.Path.Replace($env:USERPROFILE, '~')

        # 检查 Git 分支
        $gitBranch = ""
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $branch = git branch --show-current 2>$null
            if ($branch) {
                $gitBranch = " ($branch)"
            }
        }

        Write-Host "PS " -NoNewline -ForegroundColor Green
        Write-Host $shortPath -NoNewline -ForegroundColor Blue
        Write-Host $gitBranch -NoNewline -ForegroundColor Yellow
        Write-Host "> " -NoNewline -ForegroundColor Green
        return " "
    }
    Write-Host "✅ Color prompt enabled" -ForegroundColor Green
}

# --- 主题切换 ---
function Switch-Theme {
    param(
        [Parameter(Position=0)]
        [ValidateSet('starship', 'simple', 'color')]
        [string]$Theme = 'starship'
    )

    switch ($Theme) {
        'starship' {
            if (Get-Command starship -ErrorAction SilentlyContinue) {
                Invoke-Expression (&starship init powershell)
                Write-Host "✅ Starship theme enabled" -ForegroundColor Green
            } else {
                Write-Warning "Starship not found, using simple theme"
                Enable-SimplePrompt
            }
        }
        'simple' {
            Enable-SimplePrompt
        }
        'color' {
            Enable-ColorPrompt
        }
    }
}

# 添加别名
Set-Alias -Name "theme" -Value "Switch-Theme" -Option AllScope
