# Git 配置管理

这个目录包含了完整的 Git 配置文件结构，设计用于 Windows 环境，但也兼容其他平台。采用模块化设计，便于管理和自定义不同方面的 Git 行为。

## 目录结构

```
git/
├── gitconfig               # 主配置文件 (安装后成为 ~/.gitconfig)
├── gitconfig.d/            # 模块化配置目录
│   ├── core.gitconfig      # 核心设置
│   ├── aliases.gitconfig   # 命令别名
│   ├── color.gitconfig     # 颜色配置
│   ├── diff.gitconfig      # 差异比较设置
│   └── windows.gitconfig   # Windows 特定设置
├── gitignore_global        # 全局忽略规则 (安装后成为 ~/.gitignore_global)
├── gitmessage              # 提交消息模板 (安装后成为 ~/.gitmessage)
├── .gitconfig.local.example # 本地配置示例（用户信息、代理等）
├── hooks/                  # Git 钩子模板
└── scripts/                # 实用的 Git 脚本工具
```

## 安装说明

使用提供的 PowerShell 安装脚本：

```powershell
# 标准安装（复制文件）
.\install.ps1

# 开发模式（使用符号链接）
.\install.ps1 -Symlink

# 强制覆盖现有配置
.\install.ps1 -Force

# 预览安装（不实际更改任何内容）
.\install.ps1 -WhatIf
```

## 配置说明

### 主配置文件 (gitconfig)

主配置文件采用模块化设计，通过 `include` 指令引入各个功能模块，简化了维护和更新。

### 模块化配置 (gitconfig.d/)

- **core.gitconfig**: 基本工作环境设置，包括默认编辑器、行尾处理等
- **aliases.gitconfig**: 实用的 Git 命令别名集合，提高工作效率
- **color.gitconfig**: 终端输出的颜色主题设置
- **diff.gitconfig**: 差异比较和合并工具配置
- **windows.gitconfig**: 针对 Windows 平台的特定优化

### 全局忽略 (gitignore_global)

包含常见临时文件、编译产物和敏感信息的全局忽略规则，避免意外提交不应包含在版本控制中的文件。

### 本地配置 (.gitconfig.local)

用于存储个人信息（如用户名、邮箱）和环境特定设置（如代理），不包含在版本控制中，确保敏感信息安全。请复制 `.gitconfig.local.example` 到 `~/.gitconfig.local` 并按需修改。

## 使用技巧

### 常用别名

```bash
# 状态简写
git st

# 更好的日志视图
git lg

# 快速添加和提交
git wip  # 将已跟踪文件标记为"正在进行"
git save  # 保存所有更改的临时检查点

# 撤销操作
git undo  # 撤销上一次提交
git discard  # 丢弃工作区更改
```

### 配置分离

核心配置文件 (`~/.gitconfig`) 位于版本控制中，而个人/敏感信息保存在 `~/.gitconfig.local` 中，这样可以安全地共享配置，同时保持个人信息私密。

## 自定义

1. 复制 `.gitconfig.local.example` 到 `~/.gitconfig.local`
2. 根据个人喜好修改任何配置文件
3. 对于临时更改，可直接编辑 `~/.gitconfig.local`
4. 对于永久性更改，请考虑编辑存储库中的相应配置文件并重新运行安装脚本

## 安全考虑

- 敏感信息（如令牌、密码、个人电子邮件）存储在 `~/.gitconfig.local` 中
- 全局忽略文件包含常见的敏感文件模式
- 确保 `.git-credentials` 文件不会被误提交

## 故障排除

如果遇到配置问题：

1. 使用 `git config --list --show-origin` 检查配置来源
2. 检查 `~/.gitconfig` 和 `~/.gitconfig.local` 是否有语法错误
3. 确保模块化配置文件路径正确
4. 运行 `git config --list` 查看所有当前设置

## 维护

定期更新此配置，以获取最新的 Git 最佳实践和安全优化。考虑每季度检查一次更新，或在遇到 Git 相关问题时检查。