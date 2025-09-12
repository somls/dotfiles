# Neovim 配置

## 概述
本目录提供一份最小化且即用的 Neovim 配置，使用 `lazy.nvim` 管理插件，开箱即用的 Treesitter/LSP/补全与主题。

## 安装
- Scoop：`scoop install neovim`
- Chocolatey：`choco install neovim`

## 配置安装
- 自动：`./install.ps1 -Type Neovim`
- 手动：复制本目录到 `%LOCALAPPDATA%\nvim`，确保 `init.lua` 和 `lua/plugins.lua` 就位。

## 功能
- 插件管理：`lazy.nvim`
- 语法解析：`nvim-treesitter`（已配置使用 zig 编译器，避免 OOM）
- LSP：`mason.nvim` + `mason-lspconfig.nvim` + `nvim-lspconfig`（内置 `lua_ls`）
- 补全：`nvim-cmp` + `LuaSnip`
- 主题与状态栏：`tokyonight`、`lualine`

## 常用命令
- 打开插件面板：`:Lazy`
- 更新 Treesitter：`:TSUpdate`（必要时逐个安装如 `:TSInstall vim`）
- 检查健康：`:checkhealth`

## 故障排除
- Treesitter 编译器：推荐安装 `zig`（`scoop install zig`）
- Node/Python Provider：本配置默认禁用，如需启用请删除 `init.lua` 中对应行并安装 `neovim`/`pynvim` 包。
