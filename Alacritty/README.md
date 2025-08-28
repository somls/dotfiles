# Alacritty 终端配置

## 概述

Alacritty 是一个现代化的 GPU 加速终端模拟器，具有以下特点：

- 🚀 **GPU 加速**: 使用 OpenGL 渲染，性能优异
- 🎨 **现代化界面**: 支持透明度、自定义主题
- 🔧 **高度可配置**: YAML 格式配置文件
- 🌍 **跨平台**: 支持 Windows、macOS、Linux
- ⚡ **快速启动**: 启动速度快，资源占用低

## 配置特性

### 🎨 主题配置
- 基于 GitHub Dark 主题的现代化配色方案
- 支持透明度设置
- 优化的颜色对比度

### 🔤 字体配置
- 使用 Cascadia Code PL 字体
- 支持粗体和斜体样式
- 自动 DPI 缩放

### ⌨️ 快捷键
- `Ctrl+C`: 复制
- `Ctrl+V`: 粘贴
- `Ctrl+A`: 全选
- `Ctrl+T`: 新建标签页
- `Ctrl+W`: 关闭标签页
- `Ctrl+F`: 查找
- `Ctrl+Plus/Minus`: 缩放字体
- `Ctrl+0`: 重置字体大小

### 🖱️ 鼠标支持
- 中键粘贴选择内容
- 支持滚动历史记录

## 安装说明

### 1. 安装 Alacritty

#### 使用 Scoop（推荐）
```powershell
scoop install alacritty
```

#### 使用 Chocolatey
```powershell
choco install alacritty
```

#### 手动安装
1. 访问 [Alacritty 发布页面](https://github.com/alacritty/alacritty/releases)
2. 下载最新的 Windows 版本
3. 解压到合适的位置
4. 将 `alacritty.exe` 添加到系统 PATH

### 2. 配置安装

#### 自动安装（推荐）
```powershell
# 安装所有配置
.\install.ps1

# 仅安装 Alacritty 配置
.\install.ps1 -Type Alacritty
```

#### 手动安装
1. 创建配置目录：
   ```powershell
   mkdir "$env:APPDATA\alacritty"
   ```

2. 复制配置文件：
   ```powershell
   copy "Alacritty\alacritty.yml" "$env:APPDATA\alacritty\alacritty.yml"
   ```

## 配置说明

### 主要配置项

#### 窗口设置
```yaml
window:
  opacity: 0.95          # 透明度
  padding:
    x: 10                # 水平内边距
    y: 10                # 垂直内边距
  decorations: full      # 窗口装饰
  dimensions:
    columns: 120         # 默认列数
    lines: 30            # 默认行数
```

#### 字体设置
```yaml
font:
  normal:
    family: "Cascadia Code PL"  # 字体族
    style: Regular              # 样式
  size: 12.0                   # 字体大小
  scale_with_dpi: true         # DPI 缩放
```

#### 颜色主题
```yaml
colors:
  primary:
    background: '#0d1117'      # 背景色
    foreground: '#c9d1d9'      # 前景色
  normal:
    black:   '#0d1117'         # 黑色
    red:     '#f85149'         # 红色
    green:   '#238636'         # 绿色
    # ... 其他颜色
```

## 自定义配置

### 修改主题
1. 编辑 `alacritty.yml` 文件
2. 修改 `colors` 部分
3. 重启 Alacritty 应用更改

### 添加自定义快捷键
```yaml
key_bindings:
  - { key: F1, mods: Control, action: SpawnNewInstance }
  - { key: F2, mods: Control, action: Quit }
```

### 调整性能设置
```yaml
debug:
  render_timer: false          # 渲染计时器
  persistent_logging: false    # 持久化日志
  log_level: Warn             # 日志级别
```

## 故障排除

### 常见问题

#### 1. 字体显示异常
- 确保安装了 Cascadia Code PL 字体
- 或者修改配置文件中的字体设置

#### 2. 透明度不生效
- 确保 Windows 版本支持透明度
- 检查 `window.opacity` 设置

#### 3. 快捷键冲突
- 检查是否有其他应用程序占用了快捷键
- 修改配置文件中的快捷键设置

#### 4. 性能问题
- 确保显卡驱动是最新的
- 检查 OpenGL 支持

### 获取帮助

- [Alacritty 官方文档](https://github.com/alacritty/alacritty)
- [配置文件参考](https://github.com/alacritty/alacritty/blob/master/alacritty.yml)
- [主题集合](https://github.com/alacritty/alacritty-theme)

## 相关链接

- [Alacritty GitHub](https://github.com/alacritty/alacritty)
- [Cascadia Code 字体](https://github.com/microsoft/cascadia-code)
- [Windows Terminal](https://github.com/microsoft/terminal)
- [WezTerm](https://github.com/wez/wezterm)
