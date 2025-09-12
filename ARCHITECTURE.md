# 🏗️ Dotfiles Architecture Documentation

**Version**: 2.0.0  
**Last Updated**: 2025-01-15  
**Status**: Optimized Structure Implementation

## 📋 Table of Contents

- [Overview](#-overview)
- [Architecture Principles](#-architecture-principles)
- [Directory Structure](#-directory-structure)
- [Core Components](#-core-components)
- [Configuration Management](#-configuration-management)
- [Migration Guide](#-migration-guide)
- [Development Workflow](#-development-workflow)
- [Best Practices](#-best-practices)

## 🎯 Overview

This document describes the optimized architecture of the Windows Dotfiles Management System. The new structure addresses scalability, maintainability, and user experience challenges identified in the original flat structure.

### Key Improvements in v2.0

- **🗂️ Organized Structure**: Logical separation of concerns with dedicated directories
- **🎮 Unified Interface**: Single entry point (`manage.ps1`) for all operations
- **📊 Configuration Mapping**: JSON-based configuration management system
- **📝 Centralized Logging**: Structured logging with retention policies
- **🔄 Migration Support**: Seamless transition from v1.x structure
- **🧩 Modular Design**: Clear separation between core scripts, tools, and configurations

## 🏛️ Architecture Principles

### 1. Separation of Concerns
- **Core Scripts**: Essential functionality (detect, install, deploy, health)
- **Tools**: Utility scripts and helper functions
- **Configurations**: Application-specific configuration files
- **Infrastructure**: System management (logs, backups, cache)

### 2. Single Responsibility
- Each directory has a specific purpose
- Scripts focus on one primary function
- Clear boundaries between components

### 3. Discoverability
- Intuitive directory names
- Consistent naming conventions
- Comprehensive documentation

### 4. Maintainability
- Modular structure for easy updates
- Version-controlled configuration mapping
- Automated migration support

## 📁 Directory Structure

```
dotfiles/                           # Project root
├── 📋 Core Management Scripts
│   ├── manage.ps1                  # 🎮 Unified management interface
│   ├── detect-environment.ps1      # 🔍 Environment detection
│   ├── install_apps.ps1           # 📦 Application installation
│   ├── install.ps1                # ⚙️ Configuration deployment
│   └── health-check.ps1           # 🏥 System health validation
│
├── 🗂️ Organized Content
│   ├── configs/                   # 📝 Application configurations
│   │   ├── git/                   #     Git configuration
│   │   ├── powershell/            #     PowerShell profiles
│   │   ├── starship/              #     Starship prompt
│   │   ├── neovim/                #     Neovim editor
│   │   ├── WindowsTerminal/       #     Windows Terminal
│   │   └── scoop/                 #     Scoop package manager
│   │
│   ├── tools/                     # 🔧 Utility scripts
│   │   ├── auto-sync.ps1          #     Automatic synchronization
│   │   ├── dev-link.ps1           #     Development linking
│   │   └── environment-adapter.ps1 #     Environment adaptation
│   │
│   ├── modules/                   # 🧩 PowerShell modules
│   │   ├── DotfilesUtilities.psm1 #     Core utilities
│   │   └── EnvironmentAdapter.psm1 #     Environment adaptation
│   │
│   ├── docs/                      # 📚 Documentation
│   │   ├── USER_GUIDE.md          #     User documentation
│   │   ├── API_REFERENCE.md       #     API documentation
│   │   ├── FAQ.md                 #     Frequently asked questions
│   │   └── TROUBLESHOOTING.md     #     Problem resolution
│   │
│   └── bin/                       # 🔗 Binary shortcuts (future use)
│
└── 🔧 Infrastructure
    └── .dotfiles/                 # 📊 System management
        ├── config-mapping.json    #     Configuration mapping
        ├── logs/                  #     Centralized logging
        ├── backups/              #     Configuration backups
        └── cache/                #     Temporary cache files
```

### Directory Purposes

| Directory | Purpose | Contents |
|-----------|---------|-----------|
| `/` | Core management scripts | Main entry points and primary functionality |
| `configs/` | Application configurations | Tool-specific configuration files and templates |
| `tools/` | Utility scripts | Helper scripts and maintenance tools |
| `modules/` | PowerShell modules | Reusable PowerShell functionality |
| `docs/` | Documentation | User guides, technical documentation |
| `bin/` | Binary shortcuts | Future: executable shortcuts and wrappers |
| `.dotfiles/` | Infrastructure | Logs, backups, cache, system configuration |

## 🧩 Core Components

### 1. Unified Management Interface (`manage.ps1`)

**Purpose**: Single entry point for all dotfiles operations

**Features**:
- Consistent command-line interface
- Integrated logging and error handling
- Progress tracking and status reporting
- Help system and usage examples

**Usage**:
```powershell
.\manage.ps1 setup           # Complete setup process
.\manage.ps1 deploy          # Deploy configurations only
.\manage.ps1 health -Fix     # Health check with auto-repair
.\manage.ps1 status          # Current system status
```

### 2. Configuration Mapping System (`config-mapping.json`)

**Purpose**: Centralized configuration metadata and deployment rules

**Features**:
- Version-controlled configuration definitions
- Target path mapping and validation rules
- Category-based organization
- Migration support between structure versions

**Structure**:
```json
{
  "configurations": {
    "git": {
      "name": "Git Version Control",
      "path": "configs/git",
      "category": "essential",
      "targets": [...],
      "validation": {...}
    }
  }
}
```

### 3. Logging Infrastructure (`.dotfiles/logs/`)

**Purpose**: Centralized, structured logging system

**Features**:
- Timestamped log files
- Automatic log rotation
- Structured logging format
- Operation-specific log files

**Log Files**:
- `detect-environment-YYYYMMDD-HHMMSS.log`
- `install-apps-YYYYMMDD-HHMMSS.log`
- `deploy-YYYYMMDD-HHMMSS.log`
- `health-check-YYYYMMDD-HHMMSS.log`

### 4. Backup System (`.dotfiles/backups/`)

**Purpose**: Automatic configuration backup and rollback support

**Features**:
- Pre-deployment backups
- Timestamped backup directories
- Selective restoration
- Configurable retention policies

## ⚙️ Configuration Management

### Configuration Types

| Type | Description | Auto-Install | Examples |
|------|-------------|--------------|----------|
| **Essential** | Core development tools | Yes | Git, PowerShell, Starship |
| **Optional** | Enhancement tools | No | Neovim, Windows Terminal |
| **System** | Package managers | Yes | Scoop |

### Deployment Strategies

1. **Copy Mode** (Default)
   - Files copied to target locations
   - Independent of source repository
   - Suitable for production environments

2. **Symbolic Link Mode** (Developer)
   - Symbolic links to source files
   - Real-time updates from repository
   - Requires developer mode or admin privileges

### Configuration Validation

Each configuration includes validation rules:
- Required applications/executables
- Target file/directory existence
- Configuration syntax validation
- Functional testing commands

## 🔄 Migration Guide

### Automatic Migration (v1.x → v2.0)

The system automatically handles migration through the configuration mapping system:

```json
"migrations": {
  "v1_to_v2": {
    "mappings": {
      "git/": "configs/git/",
      "powershell/": "configs/powershell/",
      "*.log": ".dotfiles/logs/"
    }
  }
}
```

### Migration Process

1. **Detection**: System identifies v1.x structure
2. **Backup**: Current configuration backed up
3. **Migration**: Files moved to new structure
4. **Validation**: New structure validated
5. **Cleanup**: Old structure cleaned up (optional)

### Manual Migration Steps

If automatic migration fails:

```powershell
# 1. Backup current setup
.\manage.ps1 clean
Copy-Item -Recurse . ..\dotfiles-v1-backup

# 2. Update structure
git pull origin main

# 3. Run migration
.\manage.ps1 setup

# 4. Validate
.\manage.ps1 health -Detailed
```

## 🔧 Development Workflow

### For Contributors

1. **Setup Development Environment**:
   ```powershell
   # Enable developer mode
   .\manage.ps1 deploy -Type PowerShell -Interactive
   New-Item .\.dotfiles.dev-mode -ItemType File
   ```

2. **Make Changes**:
   - Modify configurations in `configs/`
   - Update tools in `tools/`
   - Test changes with `.\manage.ps1 health`

3. **Validate Changes**:
   ```powershell
   .\manage.ps1 health -Detailed -CheckSymLinks
   ```

4. **Update Documentation**:
   - Update `config-mapping.json` for new configurations
   - Update relevant documentation in `docs/`

### For End Users

1. **Standard Usage**:
   ```powershell
   .\manage.ps1 setup          # Initial setup
   .\manage.ps1 status         # Check status
   .\manage.ps1 health -Fix    # Maintenance
   ```

2. **Customization**:
   ```powershell
   .\manage.ps1 deploy -Type PowerShell,Git -Interactive
   ```

## 📋 Best Practices

### File Organization

- **Configs**: Group by application, include README.md
- **Tools**: Single-purpose scripts with clear names
- **Docs**: Comprehensive but focused documentation
- **Logs**: Automatic cleanup, structured format

### Naming Conventions

- **Scripts**: `kebab-case.ps1` (e.g., `detect-environment.ps1`)
- **Directories**: `lowercase` or `PascalCase` for apps
- **Config files**: Original application naming
- **Log files**: `operation-timestamp.log`

### Version Management

- **Semantic Versioning**: Major.Minor.Patch
- **Configuration Mapping**: Version-controlled metadata
- **Migration Support**: Backward compatibility
- **Documentation**: Version-specific guides

### Error Handling

- **Graceful Degradation**: Continue on non-critical errors
- **Detailed Logging**: Comprehensive error information
- **Auto-Recovery**: Automatic fixing where possible
- **User Feedback**: Clear status and error messages

## 🔍 Monitoring and Maintenance

### Health Checks

Regular system validation:
- Configuration file integrity
- Application availability
- Symbolic link validation (dev mode)
- System requirements compliance

### Automatic Maintenance

- Log rotation (keep 20 most recent)
- Backup cleanup (90-day retention)
- Cache cleaning
- Broken link detection

### Performance Monitoring

- Operation execution time
- Resource usage tracking
- Success/failure rates
- User experience metrics

---

## 📞 Support and Contribution

### Getting Help

1. **Documentation**: Check `docs/` directory
2. **Health Check**: Run `.\manage.ps1 health -Detailed`
3. **Issues**: Create GitHub issue with diagnostic info
4. **Discussions**: Join community discussions

### Contributing

1. **Follow Architecture**: Respect separation of concerns
2. **Test Changes**: Validate with health checks
3. **Update Docs**: Keep documentation current
4. **Follow Conventions**: Maintain naming and structure standards

---

**Architecture Version**: 2.0.0  
**Document Maintainer**: Dotfiles Architecture Team  
**Last Review**: 2025-01-15