# Scoop 配置

## 概述
Scoop 是 Windows 下的用户级包管理器。本目录包含 `config.json.example` 配置模板与 `packages.txt` 软件清单。

## 安装
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex
```

## 配置
- 全局配置示例：`scoop/config.json.example`（请复制为 `config.json` 并根据需要修改）
- 软件清单：`scoop/packages.txt`（一行一个包）

### 配置步骤
1. 复制配置模板：
```powershell
Copy-Item .\scoop\config.json.example .\scoop\config.json
```
2. 根据需要修改 `config.json` 中的配置项

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
