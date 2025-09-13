param(
    [string]$Name,
    [string]$Email,
    [switch]$SetupScoop,
    [switch]$Force
)

Write-Host "User Setup Script" -ForegroundColor Green

# Git configuration
if (-not $Name) { $Name = Read-Host "Git username" }
if (-not $Email) { $Email = Read-Host "Git email" }

if ($Name -and $Email) {
    $configPath = Join-Path $HOME ".gitconfig.local"

    # Check existing file if not forced
    if ((Test-Path $configPath) -and (-not $Force)) {
        Write-Host "Warning: .gitconfig.local already exists" -ForegroundColor Yellow
        $overwrite = Read-Host "Overwrite? (y/N)"
        if ($overwrite -ne 'y' -and $overwrite -ne 'Y') {
            Write-Host "Skipped Git configuration" -ForegroundColor Yellow
            return
        }
    }

    $config = "[user]`n    name = $Name`n    email = $Email"
    $config | Out-File -FilePath $configPath -Encoding UTF8
    Write-Host "Git config created: $configPath" -ForegroundColor Green
}

# Scoop safe directory setup
if ($SetupScoop) {
    Write-Host "Setting up Scoop safe directory..." -ForegroundColor Yellow
    try {
        if (Get-Command scoop -ErrorAction SilentlyContinue) {
            $ScoopDir = scoop prefix scoop
            if ($ScoopDir) {
                git config --global --add safe.directory $ScoopDir
                Write-Host "Scoop directory added to Git safe directories" -ForegroundColor Green
            }
        } else {
            Write-Host "Scoop not installed, skipping" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Failed to setup Scoop safe directory: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Environment variable setup
$dotfilesDir = Split-Path $MyInvocation.MyCommand.Path -Parent
[Environment]::SetEnvironmentVariable("DOTFILES_DIR", $dotfilesDir, "User")
Write-Host "DOTFILES_DIR set to: $dotfilesDir" -ForegroundColor Green

Write-Host ""
Write-Host "Setup complete! Restart terminal for environment variables." -ForegroundColor Cyan
