# WezTerm 终端配置

## 概述

WezTerm 是一款现代、跨平台、GPU 加速的终端模拟器，具备：

- 🚀 GPU 加速渲染，滚动/绘制顺滑
- ⚙️ 高度可配置，使用 Lua 进行配置
- 🧩 丰富的特性：多标签、分屏、SSH 域、Mux、多种渲染后端
- 🌍 跨平台：Windows、macOS、Linux、BSD

本仓库提供一份简洁现代的 WezTerm 配置，默认使用 PowerShell 7 作为 shell、JetBrainsMono Nerd Font 字体、Monokai Pro 主题及常用快捷键。

## 配置特性

- **默认 Shell**: PowerShell 7 (`pwsh.exe`)
- **字体**: JetBrainsMono Nerd Font（带 Nerd 字体图标）
- **主题**: Monokai Pro (Filter Octagon)
- **透明度**: `window_background_opacity = 0.9`
- **窗口装饰**: 仅保留 Resize（`window_decorations = 'RESIZE'`）
- **快捷键**:
  - Ctrl+Shift+N: 新建窗口
  - Ctrl+Shift+T: 新建标签页
  - Ctrl+Shift+W: 关闭当前标签页（确认）
  - Ctrl+Tab / Ctrl+Shift+Tab: 标签页切换

## 安装说明

### 1. 安装 WezTerm

#### 使用 Scoop（推荐）
```powershell
scoop bucket add extras
scoop install wezterm
```

#### 使用 Chocolatey
```powershell
choco install wezterm
```

#### 手动安装
1. 访问 `https://wezfurlong.org/wezterm/` 下载适用于 Windows 的安装包
2. 安装并确保 `wezterm.exe` 加入 PATH

### 2. 配置安装

#### 自动安装（若你的根目录脚本支持）
```powershell
.# 安装所有配置
./install.ps1

.# 仅安装 WezTerm 配置（示例）
./install.ps1 -Type WezTerm
```

#### 手动安装
1. 创建配置目录：
   ```powershell
   $dir = Join-Path $env:USERPROFILE ".wezterm"
   mkdir $dir -Force | Out-Null
   ```
2. 复制配置文件：
   ```powershell
   copy "WezTerm\wezterm.lua" "$env:USERPROFILE\.wezterm\wezterm.lua"
   ```

## 配置说明

本仓库的主配置文件：`WezTerm/wezterm.lua`

关键片段如下（摘录）：

```lua
local wezterm = require('wezterm')

return {
  -- 默认 shell
  default_prog = { 'pwsh.exe' },

  -- 字体与大小
  font = wezterm.font_with_fallback({ 'JetBrainsMono Nerd Font', '微软雅黑' }),
  font_size = 12.0,

  -- 外观
  window_background_opacity = 0.9,
  color_scheme = 'Monokai Pro (Filter Octagon)',
  window_decorations = 'RESIZE',

  -- 快捷键
  keys = {
    { key = 'N', mods = 'CTRL|SHIFT', action = wezterm.action.SpawnWindow },
    { key = 'T', mods = 'CTRL|SHIFT', action = wezterm.action.SpawnTab('DefaultDomain') },
    { key = 'W', mods = 'CTRL|SHIFT', action = wezterm.action.CloseCurrentTab({ confirm = true }) },
    { key = 'Tab', mods = 'CTRL',       action = wezterm.action.ActivateTabRelative(1) },
    { key = 'Tab', mods = 'CTRL|SHIFT', action = wezterm.action.ActivateTabRelative(-1) },
  },
}
```

### 自定义内容

- 更改默认主题：将 `color_scheme` 修改为内置或自定义主题名称
- 更换字体：将 `font_with_fallback` 中的字体替换为已安装的字体
- 修改透明度：调整 `window_background_opacity`（取值 0.0 ~ 1.0）
- 添加快捷键：在 `keys` 中追加更多映射

## 故障排除

1) 字体图标显示异常
- 确认已安装 JetBrainsMono Nerd Font
- 或改为系统现有的 Nerd 字体（例如 CascadiaCode NF、FiraCode Nerd Font 等）

2) PowerShell 配置未加载
- WezTerm 默认以 `default_prog = { 'pwsh.exe' }` 启动，会读取你的 `Microsoft.PowerShell_profile.ps1`
- 若未生效，请在外部运行 `pwsh -NoLogo` 检查 Profile 路径与内容

3) 透明度或窗口装饰无效
- 某些 Windows 桌面主题或显卡驱动可能影响呈现；尝试升级显卡驱动或调整系统设置

## 参考链接

- WezTerm 官网与文档: `https://wezfurlong.org/wezterm/`
- WezTerm GitHub: `https://github.com/wez/wezterm`
- 字体：JetBrainsMono Nerd Font: `https://www.nerdfonts.com/font-downloads`


