# 🔒 安全配置指南

## 📋 概述

本项目包含多种应用程序的配置文件。为了保护您的隐私和安全，某些配置文件包含个人信息，不应直接使用，需要根据您的环境进行自定义。

## ⚠️ 需要个人化配置的文件

### 🔑 **身份认证相关**

#### Git 配置
```bash
# 复制模板文件
cp git/.gitconfig.user.example ~/.gitconfig.local

# 编辑个人信息
[user]
    name = Your Name
    email = your.email@example.com
```

### 🌐 **网络配置相关**

#### 代理配置
```bash
# 根据需要在各应用程序中配置代理设置
# 建议使用环境变量或应用程序原生配置方式
```

#### Scoop 配置
```bash
# 复制模板文件
cp scoop/config.json.example scoop/config.json

# 根据需要调整下载设置
```

### 🤖 **AI 助手配置**

#### 编辑器配置
在编辑器配置文件中，需要注意个人信息：

```json
{
  "baidu.comate.username": "YOUR_USERNAME",
  "baidu.comate.license": "YOUR_LICENSE_KEY"
}
```

## 🛡️ 安全最佳实践

### ✅ **推荐做法**

1. **使用模板文件** - 从 `.example` 文件复制并自定义
2. **检查 .gitignore** - 确保个人配置不会被提交
3. **定期审查** - 检查配置文件是否包含敏感信息
4. **使用环境变量** - 对于密钥和令牌，优先使用环境变量

### ❌ **避免的做法**

1. **直接提交个人信息** - 用户名、邮箱、密钥等
2. **硬编码路径** - 避免包含特定的磁盘路径
3. **明文存储密码** - 使用密钥管理器或环境变量
4. **忽略代理设置** - 代理配置通常是个人特定的

## 📁 文件分类

### 🟢 **安全文件** (可直接使用)
- `powershell/Microsoft.PowerShell_profile.ps1`
- `starship/starship.toml`
- `WindowsTerminal/settings.json`
- `Alacritty/alacritty.toml`

### 🟡 **需要检查的文件** (可能包含个人偏好)
- `git/.gitconfig` (已移除用户信息)

### 🔴 **敏感文件** (需要个人化配置)
- `git/.gitconfig.local` (用户信息)
- `scoop/config.json` (个人偏好)

## 🚀 快速配置

运行以下命令快速设置个人配置：

```powershell
# 创建必要的个人配置文件
.\setup-personal-configs.ps1

# 或手动复制模板文件
Copy-Item git\.gitconfig.user.example ~\.gitconfig.local
Copy-Item scoop\config.json.example scoop\config.json
```

## 📞 支持

如果您发现任何安全问题或有疑问，请：

1. 检查本文档的相关章节
2. 查看 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
3. 在项目中提交 Issue

---

> **重要提醒**: 在提交任何配置更改之前，请务必检查是否包含个人敏感信息！