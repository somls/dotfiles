# PowerShell 配置

## 概述
本目录包含 PowerShell 配置与安装脚本，包括 `Microsoft.PowerShell_profile.ps1`、安装/链接脚本等。

## 安装
- PowerShell 7：Microsoft Store 或 `winget install --id Microsoft.PowerShell -e`

## 配置安装
- 标准安装：`./install.ps1 -Type PowerShell`
- 开发模式：`./install.ps1 -SetDevMode` 然后 `./install.ps1 -Type PowerShell` (自动使用符号链接)
- 交互式安装：`./setup.ps1` (选择 PowerShell 组件)

## 关键文件
- `powershell/Microsoft.PowerShell_profile.ps1`：用户 profile 入口
- `powershell/verify-config.ps1`：用户手动验证配置工具
- `powershell/PowerShellConfig.Tests.ps1`：Pester 自动化测试套件
- `powershell/.powershell/`：配置模块目录

## 安装说明
使用主安装脚本进行配置：
- **生产模式**：`./install.ps1 -Type PowerShell` (复制文件)
- **开发模式**：`./install.ps1 -SetDevMode && ./install.ps1 -Type PowerShell` (符号链接)

## 提示
- 本仓库建议在 Alacritty/Windows Terminal 中使用 `pwsh.exe` 作为默认 shell，以获得一致体验。
