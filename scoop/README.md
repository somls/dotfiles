# Scoop 包管理器配置

## 概述

Scoop 是 Windows 下的用户级包管理器，本目录包含精心筛选的 18 个开发工具包配置。基于实际使用场景分类管理，支持按需安装。

## 文件结构

```
scoop/
├── README.md              # 本说明文档
├── packages.txt           # 软件包清单（按分类组织）
└── config.json.example    # Scoop 配置模板
```

## 软件包分类

### 🎯 Essential (核心开发工具) - 13个包
基础必需工具，覆盖 90% 日常开发场景：

```
git          # 版本控制系统
ripgrep      # 快速文本搜索
zoxide       # 智能目录跳转
fzf          # 模糊搜索工具
bat          # 语法高亮文件查看
fd           # 快速文件搜索
jq           # JSON 处理器
neovim       # 现代文本编辑器
starship     # 跨 Shell 提示符
vscode       # 代码编辑器
sudo         # 权限提升工具
curl         # HTTP 客户端
7zip         # 压缩解压工具
```

### 🛠️ Development (开发工具) - 2个包
代码开发和检查工具：

```
shellcheck   # Shell 脚本检查器
gh           # GitHub CLI 工具
```

### 🎨 GitEnhanced (Git增强) - 1个包
Git 可视化管理工具：

```
lazygit      # Git 终端界面
```

### 💻 Programming (编程语言) - 2个包
核心编程语言运行时：

```
python       # Python 解释器
nodejs       # Node.js 运行时
```

## 安装方法

### 方法1：使用安装脚本（推荐）

```powershell
# 安装核心工具（默认）
.\install_apps.ps1

# 安装所有工具
.\install_apps.ps1 -All

# 按分类安装
.\install_apps.ps1 -Essential -Programming

# 预览安装（不实际执行）
.\install_apps.ps1 -DryRun -All

# 更新已安装的包
.\install_apps.ps1 -Update
```

### 方法2：手动安装 Scoop

如果需要手动安装和配置：

```powershell
# 1. 设置执行策略
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 2. 安装 Scoop
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# 3. 添加常用 bucket
scoop bucket add main
scoop bucket add extras
scoop bucket add versions

# 4. 批量安装核心工具
$essential = @('git', 'ripgrep', 'zoxide', 'fzf', 'bat', 'fd', 'jq', 'neovim', 'starship', 'vscode', 'sudo', 'curl', '7zip')
$essential | ForEach-Object { scoop install $_ }
```

### 方法3：从 packages.txt 批量安装

```powershell
# 安装所有包（忽略注释行）
Get-Content .\scoop\packages.txt | 
    Where-Object { $_ -and -not $_.StartsWith('#') } | 
    ForEach-Object { scoop install $_.Trim() }
```

## 配置管理

### 全局配置

1. 复制配置模板：
```powershell
Copy-Item .\scoop\config.json.example .\scoop\config.json
```

2. 根据需要修改配置项：
   - `lastupdate`: 上次更新时间
   - `SCOOP_REPO`: Scoop 仓库地址
   - `SCOOP_BRANCH`: 使用的分支

### 常用配置命令

```powershell
# 查看当前配置
scoop config

# 设置代理（如需要）
scoop config proxy http://proxy.example.com:8080

# 设置全局安装目录
scoop config global_path D:\scoop\global

# 禁用更新检查
scoop config checkver $false
```

## 常用操作

### 包管理
```powershell
# 搜索包
scoop search <package_name>

# 安装包
scoop install <package_name>

# 更新单个包
scoop update <package_name>

# 更新所有包
scoop update *

# 卸载包
scoop uninstall <package_name>

# 列出已安装的包
scoop list

# 查看包信息
scoop info <package_name>
```

### Bucket 管理
```powershell
# 列出已添加的 bucket
scoop bucket list

# 添加 bucket
scoop bucket add <bucket_name>

# 删除 bucket
scoop bucket rm <bucket_name>
```

### 维护命令
```powershell
# 清理缓存
scoop cache rm *

# 清理旧版本
scoop cleanup *

# 检查问题
scoop checkup

# 重置包（重新创建链接）
scoop reset <package_name>
```

## 健康检查

使用项目根目录的健康检查脚本验证安装：

```powershell
# 快速检查
.\health-check.ps1

# 详细检查
.\health-check.ps1 -Detailed

# 自动修复问题
.\health-check.ps1 -Fix
```

## 推荐安装顺序

1. **Essential** - 必装，涵盖基础开发需求
2. **Programming** - 如果需要 Python/Node.js 开发
3. **Development** - 代码质量和 GitHub 集成
4. **GitEnhanced** - Git 可视化管理

## 故障排除

### 常见问题

1. **执行策略限制**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

2. **网络问题**
   ```powershell
   # 配置代理
   scoop config proxy http://proxy.example.com:8080
   
   # 或使用国内镜像
   scoop config SCOOP_REPO https://gitee.com/glsnames/scoop-installer
   ```

3. **权限问题**
   ```powershell
   # Scoop 安装到用户目录，通常不需要管理员权限
   # 如果遇到权限问题，检查用户目录写权限
   ```

4. **包安装失败**
   ```powershell
   # 检查网络连接
   scoop checkup
   
   # 更新 bucket
   scoop update
   
   # 重试安装
   scoop install <package_name>
   ```

## 性能优化

- Scoop 包安装到 `~\scoop` 目录，避免污染系统
- 使用符号链接技术，启动速度快
- 支持并行安装和更新
- 自动环境变量管理

## 参考资源

- [Scoop 官网](https://scoop.sh/)
- [Scoop GitHub](https://github.com/ScoopInstaller/Scoop)
- [Scoop Bucket 搜索](https://scoop.sh/#/buckets)
- [包搜索网站](https://scoop-search.vercel.app/)

---

**最后更新**: 2025-01-09  
**包总数**: 18个（精选优化）  
**兼容性**: Windows 10/11, PowerShell 5.1+