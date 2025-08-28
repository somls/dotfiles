[CmdletBinding()]
param(
  [switch]$CreateLink,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Source profile in repo
$repoProfile = Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1'
if (-not (Test-Path $repoProfile)) {
  Write-Error "Source profile not found: $repoProfile"
  exit 1
}

# Targets
$winPsProfile = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
$pwshProfile  = Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'

function Ensure-ParentDir($path) {
  $dir = Split-Path $path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

function Link-Or-Copy($src, $dst) {
  Ensure-ParentDir $dst
  if (Test-Path $dst) {
    if ($Force) { Remove-Item $dst -Force }
    else { Write-Host "Skip (exists): $dst" -ForegroundColor Yellow; return }
  }
  if ($CreateLink) {
    try {
      New-Item -ItemType SymbolicLink -Path $dst -Target $src -Force -ErrorAction Stop | Out-Null
      Write-Host "Linked: $dst -> $src" -ForegroundColor Green
      return
    } catch {
      Write-Host "Link failed, fallback to copy: $($_.Exception.Message)" -ForegroundColor Yellow
    }
  }
  Copy-Item $src $dst -Force
  Write-Host "Copied: $src -> $dst" -ForegroundColor Green
}

Link-Or-Copy $repoProfile $winPsProfile
Link-Or-Copy $repoProfile $pwshProfile
