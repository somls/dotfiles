# Symbolic Links Verification Report

## Overview

This document provides a comprehensive summary of the symbolic links verification and management system for the dotfiles repository. All symbolic links have been successfully verified and are now properly pointing to the correct repository configurations.

## Current Status

✅ **All symbolic links are valid and operational**

- **Total Links Verified**: 8
- **Valid Links**: 8 ✅
- **Invalid Links**: 0 ❌
- **Missing Links**: 0 ⚠️

## Symbolic Links Configuration

The following symbolic links have been established between the repository configurations and system locations:

### Git Configuration
- **Repository**: `configs/git/gitconfig` → **System**: `~/.gitconfig`
- **Repository**: `configs/git/gitignore_global` → **System**: `~/.gitignore_global`
- **Repository**: `configs/git/gitmessage` → **System**: `~/.gitmessage`
- **Repository**: `configs/git/gitconfig.d` → **System**: `~/.gitconfig.d`

### PowerShell Configuration
- **Repository**: `configs/powershell/Microsoft.PowerShell_profile.ps1` → **System**: `~/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1`

### Windows Terminal Configuration
- **Repository**: `configs/WindowsTerminal/settings.json` → **System**: `~/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json`

### Starship Configuration
- **Repository**: `configs/starship/starship.toml` → **System**: `~/.config/starship.toml`

### Neovim Configuration
- **Repository**: `configs/neovim` → **System**: `~/AppData/Local/nvim`

## Management Commands

### Using the Main Management Script

```powershell
# Verify all symbolic links
.\manage.ps1 verify-links

# Verify with detailed output
.\manage.ps1 verify-links -Detailed

# Force recreate all symbolic links
.\manage.ps1 force-links

# Force recreate specific configuration types
.\manage.ps1 force-links -Type Git,PowerShell

# Preview changes without making them
.\manage.ps1 force-links -DryRun

# Interactive mode with confirmations
.\manage.ps1 force-links -Interactive
```

### Using the Direct Verification Script

```powershell
# Verify existing symbolic links
.\verify-links.ps1 -Verify

# Verify with detailed information
.\verify-links.ps1 -Verify -Detailed

# Force create/recreate symbolic links
.\verify-links.ps1 -ForceLink

# Force create without backup
.\verify-links.ps1 -ForceLink -NoBackup

# Target specific configuration types
.\verify-links.ps1 -ForceLink -Type Git,PowerShell

# Dry run mode
.\verify-links.ps1 -ForceLink -DryRun
```

## Key Features

### 🔄 Automatic Path Detection
The system automatically detects the correct paths for different applications:
- PowerShell version-dependent paths (PowerShell 5.x vs 6+)
- Windows Terminal installation locations
- Neovim configuration directories

### 🛡️ Force Symbolic Links for Critical Configs
Certain configurations are marked as "ForceSymlink" to ensure repository sync:
- Git configurations (to maintain consistent version control settings)
- Neovim configuration (entire directory structure)

### 💾 Backup System
- Automatic backup of existing configurations before making changes
- Backups stored in `~/.dotfiles-backup-links` with timestamps
- Can be disabled with `-NoBackup` parameter

### 🎯 Selective Management
- Target specific configuration types with `-Type` parameter
- Available types: PowerShell, Git, Starship, Scoop, Neovim, CMD, WindowsTerminal

## Developer Mode

The system operates in **Developer Mode** when:
- Environment variable `DOTFILES_DEV_MODE=true/1/yes/on` is set, OR
- Marker file `.dotfiles.dev-mode` exists in the repository root

In Developer Mode:
- Symbolic links are the default installation method
- Changes to repository files immediately affect system configurations
- Ideal for active development and customization

## Troubleshooting

### Common Issues

1. **"Access Denied" errors**
   - Run PowerShell as Administrator
   - Enable Developer Mode in Windows 10/11 Settings

2. **Invalid link targets**
   - Run `.\manage.ps1 force-links` to recreate all links
   - Use `.\manage.ps1 verify-links -Detailed` to see specific issues

3. **Missing source configurations**
   - Ensure all configuration files exist in the `configs/` directory
   - Check git repository integrity

### Verification Commands

```powershell
# Quick status check
.\manage.ps1 verify-links

# Detailed diagnosis
.\manage.ps1 verify-links -Detailed

# Check specific configurations
.\manage.ps1 verify-links -Type Git -Detailed

# Verify using native PowerShell
Get-Item ~/.gitconfig | Select-Object FullName, LinkType, Target
```

## Maintenance

### Regular Maintenance
- Run verification after major system updates
- Check links after moving repository location
- Verify after Windows Terminal or PowerShell updates

### After Repository Changes
If you modify the repository structure:
1. Update configuration mappings in `verify-links.ps1`
2. Run `.\manage.ps1 force-links` to recreate links
3. Verify with `.\manage.ps1 verify-links -Detailed`

## Benefits of Symbolic Links

1. **Real-time Synchronization**: Changes to repository files immediately affect system behavior
2. **Version Control**: All configuration changes are tracked in git
3. **Easy Backup**: Entire configuration state is preserved in repository
4. **Consistency**: Same configurations across multiple machines
5. **Development Workflow**: Test and iterate on configurations seamlessly

## Last Verified

- **Date**: December 12, 2024
- **System**: Windows 10/11
- **PowerShell**: 5.1+ compatible
- **Repository Structure**: `configs/` based organization
- **Status**: ✅ All links operational

---

For questions or issues with symbolic link management, refer to the main project documentation or run `.\manage.ps1 help` for available commands.