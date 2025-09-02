[Root Directory](../../CLAUDE.md) > [scripts](../) > **cmd**

# CMD 脚本文档

## 模块职责

CMD 脚本模块负责管理 Windows 命令提示符的别名和配置，提供类似于 Unix/Linux 系统的便捷命令。

## 入门和启动

主配置文件为 `aliases.cmd`，它包含了 DOSKEY 宏定义，通过 AutoRun 机制在 CMD 启动时自动加载。

## 外部接口

CMD 配置模块提供了一系列 DOSKEY 宏来增强命令提示符使用体验：

### 核心别名
- `..` - 返回上级目录
- `...` - 返回上两级目录
- `cdd` - 切换到指定目录
- `ls` - 列出目录内容（简洁模式）
- `ll` - 列出目录内容（详细模式）
- `la` - 列出所有文件（包括隐藏文件）
- `n` - 启动记事本
- `e` - 启动资源管理器
- `c` - 启动 VS Code（如果已安装）
- `grep` - 使用 ripgrep 搜索
- `cat` - 显示文件内容
- `findstr` - 字符串搜索

### Git 别名
- `gst` - Git 状态查看
- `gl` - Git 日志查看
- `gco` - Git 切换分支
- `ga` - Git 添加文件
- `gc` - Git 提交
- `gp` - Git 推送

## 关键依赖和配置

### 依赖工具
- **DOSKEY** - Windows 命令别名工具
- **ripgrep (rg)** - 搜索工具（用于 grep 别名）
- **Git** - 版本控制工具（用于 Git 别名）
- **Visual Studio Code** - 代码编辑器（用于 c 别名，可选）

### 配置文件
- `aliases.cmd` - 主别名配置文件
- `aliases.mac` - macOS 兼容别名（备用）

## 数据模型

CMD 配置使用 DOSKEY 宏定义格式：

```cmd
:: 导航命令
DOSKEY ..=cd ..
DOSKEY ...=cd ..\..
DOSKEY cdd=cd /d $*

:: 列表命令
DOSKEY ls=dir /b $*
DOSKEY ll=dir $*
DOSKEY la=dir /a $*

:: 编辑器和工具
DOSKEY n=notepad $*
DOSKEY e=explorer $*
DOSKEY c=code $*

:: 实用工具
DOSKEY grep=rg $*
DOSKEY cat=type $*
DOSKEY findstr=findstr $*
```

## 测试和质量

CMD 配置模块通过以下方式确保质量：

1. **语法验证**: 验证 DOSKEY 宏语法正确性
2. **功能测试**: 手动测试别名功能是否正常工作
3. **兼容性检查**: 确保别名在不同 Windows 版本上正常工作

## 常见问题解答 (FAQ)

### 1. 如何加载 CMD 别名？

别名通过 `install.ps1` 脚本自动配置 AutoRun 机制加载：
```cmd
# 手动加载别名
.\scripts\cmd\aliases.cmd
```

### 2. 如何添加新的 CMD 别名？

编辑 `aliases.cmd` 文件添加新的 DOSKEY 宏：
```cmd
DOSKEY myalias=echo Hello World
```

### 3. 如何查看当前定义的别名？

使用 DOSKEY 命令查看当前定义的宏：
```cmd
DOSKEY
```

### 4. 如何删除别名？

使用 DOSKEY 删除特定别名：
```cmd
DOSKEY myalias=
```

## 相关文件列表

- [aliases.cmd](aliases.cmd) - 主别名配置文件
- [aliases.mac](aliases.mac) - macOS 兼容别名

## 变更日志

### 2025-09-02
- 创建 CMD 脚本 CLAUDE.md 文档
- 记录别名配置和使用方法

### 历史版本
- 初始版本包含常用的导航、列表、编辑器和 Git 别名