# Dotfiles 配置文件夹

本文件夹包含 dotfiles 项目的核心配置文件，提供灵活的组件管理和环境适配功能。

## 📁 文件结构

```
config/
├── README.md              # 本文档
├── install.json           # 主安装配置文件
├── environments.json      # 环境特定配置
└── schemas/               # JSON 配置验证架构
    └── install.schema.json
```

## 🔧 核心配置文件

### `install.json`
主配置文件，定义了：
- **组件管理**: 按类别组织的组件（核心、终端、编辑器等）
- **安装模式**: 支持复制和符号链接两种模式
- **依赖关系**: 组件间的依赖管理
- **验证规则**: 安装后的验证命令
- **配置文件**: 各种预设配置（最小、标准、完整、开发者）

#### 主要结构:
```json
{
  "version": "2.0.0",
  "defaultMode": "copy",
  "components": {
    "core": { /* 核心组件 */ },
    "terminals": { /* 终端配置 */ },
    "editors": { /* 编辑器配置 */ },
    "utilities": { /* 工具脚本 */ }
  },
  "profiles": { /* 安装配置文件 */ },
  "settings": { /* 全局设置 */ }
}
```

### `environments.json`
环境特定配置，支持：
- **环境类型**: 开发、生产、企业、最小、游戏、服务器
- **自动检测**: 基于系统特征的环境自动识别
- **配置覆盖**: 针对不同环境的特定设置
- **先决条件**: 环境相关的系统要求

#### 支持的环境:
- `development` - 开发环境（完整功能，使用符号链接）
- `production` - 生产环境（仅核心组件）
- `minimal` - 最小环境（仅 PowerShell 配置）
- `corporate` - 企业环境（考虑安全策略）
- `gaming` - 游戏环境（性能优化配置）
- `server` - 服务器环境（无 GUI 组件）

## 📋 配置架构验证

### `schemas/install.schema.json`
提供 JSON Schema 验证：
- 配置文件结构验证
- 数据类型和格式检查
- 必需字段和可选字段定义
- 枚举值验证

使用验证：
```powershell
.\scripts\Validate-JsonConfigs.ps1 -UseSchema -SchemaPath "config\schemas\install.schema.json"
```

## 🚀 使用方法

### 基本安装
```powershell
# 使用默认配置
.\install.ps1

# 使用特定配置文件
.\install.ps1 -Profile "developer"
```

### 环境检测
```powershell
# 自动检测环境并应用相应配置
.\install.ps1 -AutoDetectEnvironment

# 强制使用特定环境
.\install.ps1 -Environment "corporate"
```

### 组件选择
```powershell
# 仅安装特定组件
.\install.ps1 -Type PowerShell,Git,Starship

# 交互式选择模式
.\install.ps1 -Interactive
```

## ⚙️ 配置定制

### 1. 修改组件配置
在 `install.json` 中修改组件设置：
```json
{
  "components": {
    "core": {
      "powershell": {
        "enabled": true,
        "installMode": "symlink",
        "paths": {
          "source": "powershell",
          "target": "$env:USERPROFILE\\Documents\\PowerShell"
        }
      }
    }
  }
}
```

### 2. 创建自定义配置文件
添加新的配置文件到 `profiles` 部分：
```json
{
  "profiles": {
    "custom": {
      "description": "我的自定义配置",
      "components": ["powershell", "git", "starship"],
      "settings": {
        "defaultMode": "symlink"
      }
    }
  }
}
```

### 3. 环境特定覆盖
在 `environments.json` 中添加环境特定设置：
```json
{
  "environments": {
    "myenv": {
      "name": "我的环境",
      "overrides": {
        "powershell": {
          "installMode": "copy"
        }
      }
    }
  }
}
```

## 🔍 验证和测试

### 配置验证
```powershell
# 验证所有 JSON 配置
.\scripts\Validate-JsonConfigs.ps1

# 使用架构验证
.\scripts\Validate-JsonConfigs.ps1 -UseSchema
```

### 项目状态检查
```powershell
# 快速检查
.\scripts\run-quick-check.ps1

# 详细状态检查
.\scripts\project-status.ps1 -Detailed
```

## 📝 配置文件版本

- **Version 1.x**: 简单的组件开关配置
- **Version 2.x**: 结构化的组件管理和环境适配

升级时请参考 `CHANGELOG.md` 了解配置格式变更。

## 🛠️ 故障排除

### 常见问题

1. **配置加载失败**
   ```powershell
   .\scripts\Validate-JsonConfigs.ps1 config\install.json
   ```

2. **环境检测错误**
   ```powershell
   .\detect-environment.ps1 -Verbose
   ```

3. **组件安装失败**
   ```powershell
   .\health-check.ps1 -Component <组件名>
   ```

### 配置重置
```powershell
# 重置为默认配置
Copy-Item config\install.json.default config\install.json -Force
```

## 📚 相关文档

- [QUICKSTART.md](../QUICKSTART.md) - 快速开始指南
- [PROJECT_STRUCTURE.md](../PROJECT_STRUCTURE.md) - 项目结构说明
- [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) - 故障排除指南

---

📌 **注意**: 修改配置文件前请先备份原文件，确保能够恢复到工作状态。