-- 导入 wezterm 模块
local wezterm = require('wezterm')

-- 返回一个配置表
return {
  -- 使用 PowerShell 7 作为默认的 shell
  default_prog = { 'pwsh.exe' },

  -- 设置字体
  font = wezterm.font_with_fallback({
    'JetBrainsMono Nerd Font',
    '微软雅黑',
  }),

  -- 字体大小
  font_size = 12.0,

  -- 窗口透明度 (可选, 0.9 = 90% 不透明)
  window_background_opacity = 0.9,

  -- 颜色主题 (这里使用 Monokai Pro)
  color_scheme = 'Monokai Pro (Filter Octagon)',

  -- 隐藏顶部标题栏
  window_decorations = 'RESIZE',

  -- 终端内边距
  -- 例如: { left = 10, right = 10, top = 5, bottom = 5 }
  -- 或者简单的: 10 (所有边都设置为 10)
  -- padding = {
  --   left = 1,
  --   right = 1,
  --   top = 0,
  --   bottom = 0,
  -- },
  
  -- 快捷键绑定
  keys = {
    -- Ctrl + Shift + N: 新建窗口
    {
      key = 'N',
      mods = 'CTRL|SHIFT',
      action = wezterm.action.SpawnWindow,
    },
    -- Ctrl + Shift + T: 新建标签页
    {
      key = 'T',
      mods = 'CTRL|SHIFT',
      action = wezterm.action.SpawnTab('DefaultDomain'),
    },
    -- Ctrl + Shift + W: 关闭标签页
    {
      key = 'W',
      mods = 'CTRL|SHIFT',
      action = wezterm.action.CloseCurrentTab({ confirm = true }),
    },
    -- Ctrl + Tab: 切换到下一个标签页
    {
      key = 'Tab',
      mods = 'CTRL',
      action = wezterm.action.ActivateTabRelative(1),
    },
    -- Ctrl + Shift + Tab: 切换到上一个标签页
    {
      key = 'Tab',
      mods = 'CTRL|SHIFT',
      action = wezterm.action.ActivateTabRelative(-1),
    },
  },

  -- 选项卡栏位置 (可选)
  -- tab_bar_at_bottom = true,
}