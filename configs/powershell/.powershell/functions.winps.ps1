# ~/.powershell/functions.winps.ps1
# Minimal functions for Windows PowerShell 5 (ASCII output, PS5-safe syntax)

# Git helpers
function ngc {
    param([string]$msg = "update")
    git add .
    if ($LASTEXITCODE -ne 0) { return }
    git commit -m $msg
    if ($LASTEXITCODE -ne 0) { return }
    git push
}

function gst { git status --short }
function glog { git log --oneline -10 }

# Directories
function mkcd {
    param([string]$path)
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    Set-Location $path
}
function .. { Set-Location .. }
function ... { Set-Location ..\.. }

# System maintenance
function sys-update {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop update *
    }
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget upgrade --all
    }
}

function swp {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop cleanup *
        if ($LASTEXITCODE -eq 0) { scoop cache rm * }
    }
}

# Utilities
function which { param($cmd) (Get-Command $cmd).Source }
function reload { . $PROFILE }
function edit-profile { if (Get-Command code -ErrorAction SilentlyContinue) { code $PROFILE } else { notepad $PROFILE } }

# Info
function config-info {
    Write-Host "Dotfiles config" -ForegroundColor Cyan
    Write-Host "================" -ForegroundColor Cyan
    Write-Host ("Profile dir: {0}" -f (Split-Path $PROFILE -Parent)) -ForegroundColor White
    Write-Host "Core commands:" -ForegroundColor Yellow
    Write-Host "  Git: ngc, gst, glog" -ForegroundColor Gray
    Write-Host "  System: sys-update, swp" -ForegroundColor Gray
    Write-Host "  Nav: mkcd, .., ..." -ForegroundColor Gray
}

