# Starship 配置

## 概述
Starship 是一款跨平台、快速、可定制的命令行提示符。本目录包含 `starship.toml`。

## 安装
- Scoop：`scoop install starship`
- Winget：`winget install starship`

## 配置安装
- 将 `starship/starship.toml` 复制到：
  - Windows：`%USERPROFILE%\.config\starship.toml`
  - 或通过环境变量 `STARSHIP_CONFIG` 指向本文件

## 启用
- PowerShell 配置文件中添加：
```powershell
Invoke-Expression (&starship init powershell)
```

## 参考
- 文档：`https://starship.rs/`
