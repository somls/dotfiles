# Windows Terminal 配置

## 概述
Windows Terminal 是现代终端，支持标签、分屏、GPU 渲染与丰富自定义。

## 安装
- Microsoft Store（推荐）
- Winget: `winget install --id Microsoft.WindowsTerminal -e`
- Scoop: `scoop bucket add extras && scoop install windows-terminal`

## 配置安装
- 自动：`./install.ps1 -Type WindowsTerminal`
- 手动：设置 → 打开 JSON，将 `WindowsTerminal/settings.json` 合并/替换

## 关键点
- 默认 shell（如 `pwsh.exe`）
- 主题/配色、字体、透明度、Acrylic
- 按键绑定、启动目录、窗口行为

## 故障排除
- 变更未生效：保存 JSON 后重启
- 字体异常：安装并在配置中选择对应字体

## 参考
- 文档：`https://aka.ms/terminal-documentation`
- GitHub：`https://github.com/microsoft/terminal`
