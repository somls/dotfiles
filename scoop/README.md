# Scoop 配置

## 概述
Scoop 是 Windows 下的用户级包管理器。本目录包含 `config.json` 与 `packages.txt`。

## 安装
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex
```

## 配置
- 全局配置示例：`scoop/config.json`
- 软件清单：`scoop/packages.txt`（一行一个包）

## 使用
- 添加常用 bucket：
```powershell
scoop bucket add main
scoop bucket add extras
scoop bucket add versions
```
- 批量安装：
```powershell
Get-Content .\scoop\packages.txt | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object { scoop install $_ }
```

## 参考
- 官网：`https://scoop.sh/`
