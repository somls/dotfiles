# Git 配置安装与本地开发说明

本仓库提供安全、兼容的 Git 配置部署方案：默认“复制安装”，可选“符号链接开发（本机偏好）”，并支持“监听自动复制（Watch）”。本说明文档仅记录使用方法，脚本实现见 `git/scripts/install-git-config.ps1`。

## 安装模式

- 默认：复制安装（推荐，安全、可控）
- 可选：符号链接安装（仅本机开发时按需启用）
- Watch：监听仓库 `git/` 目录变更并自动复制到用户目录，实现“保存即生效”

目标路径（Windows）：
- `~/.gitconfig`
- `~/.gitconfig.d/`
- `~/.gitignore_global`
- `~/.gitmessage`

## 基本用法

- 复制安装（默认）：
```powershell
.\git\scripts\install-git-config.ps1 -Force
```

- 启用 Watch（保存即生效，仍为复制）：
```powershell
.\git\scripts\install-git-config.ps1 -Force -Watch
```

- 符号链接安装（按需，本机开发）：
```powershell
.\git\scripts\install-git-config.ps1 -UseSymlink $true -Force
```
（在 Windows 上可能需要管理员权限或启用“开发者模式”）

## 本机“符号链接偏好”（不入仓库）

为满足“本机开发使用链接、仓库默认复制”的诉求，脚本支持本地偏好：
- 若未显式传入 `-UseSymlink`，将读取以下本机设置来决定是否使用符号链接：
  - 环境变量：`DOTFILES_PREFER_SYMLINK=1|true|yes`
  - 标记文件：`~/.dotfiles.use-symlink` 存在

这些设置位于用户主目录，不会进入仓库，因而不会影响其他机器或 CI。

### 启用（本机始终偏好符号链接）

- 标记文件（推荐，最简单）
```powershell
New-Item -ItemType File -Path $HOME/.dotfiles.use-symlink -Force | Out-Null
```

- 或者设置环境变量（用户级持久化）
```powershell
[Environment]::SetEnvironmentVariable("DOTFILES_PREFER_SYMLINK", "1", "User")
```

之后直接运行：
```powershell
.\git\scripts\install-git-config.ps1 -Force
```
（若本机偏好生效，将自动使用符号链接）

### 关闭本机偏好

- 删除标记文件：
```powershell
Remove-Item $HOME/.dotfiles.use-symlink -ErrorAction SilentlyContinue
```

- 清理环境变量：
```powershell
[Environment]::SetEnvironmentVariable("DOTFILES_PREFER_SYMLINK", $null, "User")
```

## Watch 模式（复制）

使用 `-Watch` 进入监听：
```powershell
.\git\scripts\install-git-config.ps1 -Force -Watch
```
- 监听 `git/` 目录（含子目录），忽略 `.git/` 与常见临时文件。
- 触发 Changed/Created/Renamed/Deleted 时将对应源重新复制到主目录。
- 退出：在该会话中按 Ctrl + C。

可调整去抖间隔：
```powershell
.\git\scripts\install-git-config.ps1 -Force -Watch -WatchDebounceMs 800
```

## 用户身份与本地覆盖

- 个人身份与机器特定设置建议写入 `~/.gitconfig.local`（不在仓库中，已被主配置 include）。
- 示例快速设置：
```powershell
git config --global user.name  "Your Name"
git config --global user.email "your.email@example.com"
```

## 验证与排错

- 检查是否为符号链接：
```powershell
$paths = @("$HOME/.gitconfig","$HOME/.gitconfig.d","$HOME/.gitignore_global","$HOME/.gitmessage");
foreach ($p in $paths) {
  if (Test-Path $p) { $i=Get-Item -Force $p; $isLink=($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0; "$p => IsSymlink=$isLink Target=$($i.Target)" }
}
```

- 查看 include 生效：
```powershell
git config --global -l | Select-String -Pattern include
```

- 仍想“保存即生效”但不使用链接：使用 `-Watch` 即可。

## 设计原则

- 默认复制安装：安全、兼容、可控；避免仓库更改意外影响所有机器。
- 本机偏好链接：仅在开发机上选择性启用，快速迭代；不影响他人或远端。
- 可选 Watch：在复制模式下也能获得“保存即生效”的体验。
