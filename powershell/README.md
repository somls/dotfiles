# PowerShell 配置

## 概述
本目录包含 PowerShell 配置与安装脚本，包括 `Microsoft.PowerShell_profile.ps1`、安装/链接脚本等。

## 安装
- PowerShell 7：Microsoft Store 或 `winget install --id Microsoft.PowerShell -e`

## 配置安装
- 自动：`./install.ps1 -Type PowerShell`
- 链接用户 Profile：`powershell/link-profile.ps1`

## 关键文件
- `powershell/Microsoft.PowerShell_profile.ps1`：用户 profile 入口
- `powershell/install.ps1`：安装/复制配置
- 其他辅助脚本：`powershell/test-config.ps1`

## 提示
- 本仓库建议在 Alacritty/Windows Terminal 中使用 `pwsh.exe` 作为默认 shell，以获得一致体验。
