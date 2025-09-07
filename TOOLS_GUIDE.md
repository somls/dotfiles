# 🛠️ 工具使用指南

本文档介绍 dotfiles 项目中安装的各种命令行工具的使用方法和最佳实践。

## 📋 目录

- [核心工具](#核心工具)
- [开发工具](#开发工具)
- [系统工具](#系统工具)
- [文件处理工具](#文件处理工具)
- [网络工具](#网络工具)
- [Git 工具](#git-工具)
- [别名和快捷方式](#别名和快捷方式)
- [工具组合使用](#工具组合使用)

---

## 🔧 核心工具

### Git
```bash
# 基本操作
git status
git add .
git commit -m "message"
git push

# 使用配置的别名（见 git/gitconfig.d/aliases.gitconfig）
git st          # status
git co          # checkout
git br          # branch
git ci          # commit
git unstage     # reset HEAD
```

### PowerShell 7 (pwsh)
```powershell
# 启动 PowerShell 7
pwsh

# 查看配置
Get-PSReadLineOption
Get-Module -ListAvailable
```

### Starship 提示符
```bash
# 查看配置
starship config

# 重新加载配置
starship init powershell | Invoke-Expression
```

---

## 💻 开发工具

### Ripgrep (rg) - 快速文件搜索
```bash
# 基本搜索
rg "pattern"                    # 在当前目录搜索
rg "pattern" path/              # 在指定目录搜索
rg -i "pattern"                 # 忽略大小写
rg -w "word"                    # 完整单词匹配

# 文件类型过滤
rg "pattern" -t js              # 只搜索 JavaScript 文件
rg "pattern" -T js              # 排除 JavaScript 文件
rg "pattern" -g "*.md"          # 只搜索 Markdown 文件

# 高级用法
rg "pattern" -A 3 -B 3          # 显示匹配行前后3行
rg "pattern" -c                 # 只显示匹配数量
rg "pattern" --files-with-matches # 只显示包含匹配的文件名
```

### Bat - 增强版 cat
```bash
# 基本用法
bat file.txt                    # 语法高亮显示文件
bat -n file.txt                 # 显示行号
bat -A file.txt                 # 显示不可见字符

# 与其他工具结合
rg "pattern" | bat              # 搜索结果语法高亮
git diff | bat                  # Git diff 语法高亮
```

### Fd - 快速文件查找
```bash
# 基本查找
fd filename                     # 查找文件名
fd -e js                        # 查找所有 .js 文件
fd -t f pattern                 # 只查找文件（不包括目录）
fd -t d pattern                 # 只查找目录

# 高级用法
fd -H pattern                   # 包括隐藏文件
fd -I pattern                   # 包括 .gitignore 中的文件
fd pattern -x ls -la            # 对找到的文件执行命令
```

### FZF - 模糊搜索
```bash
# 基本用法
fzf                             # 交互式文件选择
ls | fzf                        # 从列表中选择

# 与其他工具结合
fd -t f | fzf                   # 模糊搜索文件
rg --files | fzf                # 搜索文件名
git branch | fzf                # 选择 Git 分支

# PowerShell 中的快捷键
# Ctrl+R: 历史命令搜索
# Ctrl+T: 文件搜索
```

### Zoxide - 智能目录跳转
```bash
# 基本用法
z dirname                       # 跳转到包含 dirname 的目录
z foo bar                       # 跳转到包含 foo 和 bar 的目录
zi                              # 交互式选择目录

# 查看统计
zoxide query --list             # 显示所有记录的目录
zoxide query --stats            # 显示访问统计
```

### JQ - JSON 处理
```bash
# 基本用法
echo '{"name":"John","age":30}' | jq '.'                    # 格式化 JSON
echo '{"name":"John","age":30}' | jq '.name'                # 提取字段
curl -s api.github.com/users/octocat | jq '.login'         # API 响应处理

# 数组处理
echo '[{"name":"John"},{"name":"Jane"}]' | jq '.[0].name'   # 数组索引
echo '[{"name":"John"},{"name":"Jane"}]' | jq '.[] | .name' # 遍历数组

# 过滤和转换
jq '.[] | select(.age > 25)'                                # 过滤
jq 'map(.name)'                                             # 映射
```

### JID - 交互式 JSON 探索
```bash
# 基本用法
curl -s api.github.com/users/octocat | jid    # 交互式浏览 JSON
cat data.json | jid                            # 浏览本地 JSON 文件

# 在 JID 中的操作：
# Tab: 自动补全
# Ctrl+C: 退出
# Enter: 执行查询
```

### SD - 现代化文本替换
```bash
# 基本用法
sd 'old_text' 'new_text' file.txt              # 替换文件中的文本
sd 'old_text' 'new_text' *.txt                 # 批量替换多个文件

# 正则表达式
sd '\d+' 'NUMBER' file.txt                     # 替换所有数字
sd '(\w+)\s+(\w+)' '$2 $1' file.txt           # 交换单词顺序

# 预览模式
sd -p 'old' 'new' file.txt                     # 预览替换结果
```

### Tokei - 代码统计
```bash
# 基本用法
tokei                                          # 统计当前目录
tokei path/to/project                          # 统计指定目录
tokei --languages                              # 显示支持的语言

# 输出格式
tokei --output json                            # JSON 格式输出
tokei --sort lines                             # 按行数排序
tokei --exclude "*.min.js"                     # 排除特定文件
```

### Hyperfine - 性能基准测试
```bash
# 基本用法
hyperfine 'command1' 'command2'                # 比较两个命令性能
hyperfine --warmup 3 'command'                 # 预热运行
hyperfine --min-runs 10 'command'              # 最小运行次数

# 参数化测试
hyperfine --parameter-list size 1,10,100 'head -n {size} file.txt'

# 导出结果
hyperfine --export-json results.json 'command'
hyperfine --export-markdown results.md 'command'
```

---

## 🖥️ 系统工具

### Btop - 系统监控
```bash
# 启动监控
btop                                           # 启动系统监控器

# 快捷键（在 btop 中）：
# q: 退出
# h: 帮助
# m: 内存视图
# p: 进程视图
# n: 网络视图
# d: 磁盘视图
```

### Dust - 磁盘使用分析
```bash
# 基本用法
dust                                           # 分析当前目录
dust /path/to/directory                        # 分析指定目录
dust -d 3                                      # 限制显示深度

# 输出选项
dust -r                                        # 反向排序（小到大）
dust -n 20                                     # 显示前20个项目
dust -b                                        # 以字节为单位显示
```

### Procs - 进程查看
```bash
# 基本用法
procs                                          # 显示所有进程
procs firefox                                  # 搜索特定进程
procs --tree                                   # 树形显示进程

# 过滤选项
procs --user username                          # 显示特定用户的进程
procs --pid 1234                               # 显示特定 PID
procs --cpu                                    # 按 CPU 使用率排序
procs --memory                                 # 按内存使用率排序
```

---

## 🌐 网络工具

### Curl - HTTP 客户端 (推荐使用系统内置版本)
```bash
# 基本请求
curl https://api.github.com                    # GET 请求
curl -X POST https://api.example.com           # POST 请求
curl -H "Content-Type: application/json" -d '{"key":"value"}' https://api.example.com

# 文件下载 (替代 wget)
curl -O https://example.com/file.zip           # 下载文件，保持原名
curl -o newname.zip https://example.com/file.zip # 指定文件名
curl -C - -O https://example.com/largefile.zip # 断点续传
```

### HTTPie - 现代 HTTP 客户端
```bash
# 基本请求
http GET https://api.github.com                # GET 请求
http POST https://api.example.com key=value    # POST 请求
http https://api.example.com Authorization:"Bearer token" # 带认证

# JSON 数据
http POST https://api.example.com name=John age:=25 # 自动 JSON 格式
http POST https://api.example.com < data.json       # 从文件读取

# 文件下载
http --download https://example.com/file.zip        # 下载文件
http --print=HhBb https://api.example.com          # 显示详细信息
```

---

## 🔀 Git 工具

### GitHub CLI (gh)
```bash
# 仓库操作
gh repo clone owner/repo                       # 克隆仓库
gh repo create my-repo                         # 创建仓库
gh repo view                                   # 查看当前仓库信息

# Pull Request
gh pr create                                   # 创建 PR
gh pr list                                     # 列出 PR
gh pr checkout 123                             # 检出 PR

# Issues
gh issue create                                # 创建 issue
gh issue list                                  # 列出 issues
gh issue view 123                              # 查看 issue

# 认证
gh auth login                                  # 登录 GitHub
gh auth status                                 # 查看认证状态
```

### Delta - Git Diff 美化
```bash
# 基本使用 (配置在 .gitconfig 中)
git diff                                       # 自动使用 delta 美化输出
git log -p                                     # 带 diff 的日志
git show HEAD                                  # 显示最新提交的 diff

# 直接使用 delta
delta file1.txt file2.txt                     # 比较两个文件
git diff | delta                               # 管道输出给 delta
```

### Lazygit - 可视化 Git TUI
```bash
# 启动
lazygit                                        # 在 Git 仓库中启动

# 常用快捷键（在 lazygit 中）：
# j/k: 上下移动
# h/l: 左右切换面板
# enter: 选择/展开
# space: 暂存/取消暂存
# c: 提交
# P: 推送
# p: 拉取
# q: 退出
```

---

## 🚀 效率工具 (ProductivityTools)

### Just - 现代命令运行器
```bash
# 项目根目录创建 justfile
just                                           # 列出所有可用命令
just build                                     # 运行 build 任务
just test                                      # 运行 test 任务

# justfile 示例内容：
# build:
#     cargo build --release
# test:
#     cargo test
# deploy: build test
#     ./deploy.sh
```

### Choose - 现代 cut/awk 替代
```bash
# 选择列
echo "one two three" | choose 1                # 选择第二列 (zero-indexed)
echo "1,2,3,4" | choose -f , 0,2              # 选择第1和第3列 (逗号分隔)
ps aux | choose 1                              # 选择进程列表的用户列

# 范围选择
echo "a b c d e" | choose 1:3                 # 选择第2到第4列
echo "a b c d e" | choose :2                  # 选择前3列
echo "a b c d e" | choose 2:                  # 选择第3列到末尾
```

### Duf - 磁盘使用可视化
```bash
# 基本使用
duf                                            # 显示所有挂载点
duf /home /var                                 # 显示特定路径
duf --only local                               # 只显示本地文件系统

# 输出格式
duf --json                                     # JSON 格式输出
duf --theme dark                               # 使用深色主题
```

### Tealdeer - 快速命令帮助
```bash
# 基本使用
tldr ls                                        # 显示 ls 命令的示例
tldr git                                       # 显示 git 命令的示例
tldr tar                                       # 显示 tar 命令的示例

# 管理
tldr --update                                  # 更新示例数据库
tldr --list                                    # 列出所有可用命令
tldr --random                                  # 显示随机命令示例
```

---

## 🔗 别名和快捷方式

### PowerShell 别名
```powershell
# 系统监控
top                    # → btop
ps                     # → procs
du                     # → dust

# 文件操作
cat                    # → bat
grep                   # → rg
find                   # → fd

# JSON 处理
json                   # → jq

# 权限提升
sudo                   # → Start-Elevated 或 sudo
```

### CMD 别名
```cmd
:: 在 CMD 中使用 DOSKEY 别名
grep                   :: → rg
cat                    :: → bat
du                     :: → dust
ps                     :: → procs
top                    :: → btop
json                   :: → jq
```

---

## 🔄 工具组合使用

### 常用组合示例

#### 1. 代码搜索和查看
```bash
# 搜索代码并用 bat 高亮显示
rg "function" -A 5 -B 5 | bat -l js

# 查找文件并用 fzf 选择，然后用 bat 查看
fd -e js | fzf | xargs bat
```

#### 2. 目录分析
```bash
# 分析磁盘使用并跳转到大目录
dust | head -10
z large-directory
```

#### 3. 性能分析
```bash
# 比较不同搜索工具的性能
hyperfine 'rg "pattern"' 'grep -r "pattern"'

# 监控系统资源
btop &
hyperfine 'heavy-command'
```

#### 4. JSON 数据处理流水线
```bash
# API 数据处理流水线
curl -s https://api.github.com/users/octocat | jq '.repos_url' | xargs curl -s | jq '.[].name' | head -10
```

#### 5. 代码统计和分析
```bash
# 项目代码统计
tokei
fd -e js -e ts | wc -l                         # 统计 JS/TS 文件数量
rg "TODO|FIXME" --count                        # 统计待办事项
```

---

## 📚 更多资源

### 配置文件位置
- PowerShell 配置: `powershell/.powershell/`
- Git 配置: `git/gitconfig.d/`
- Starship 配置: `starship/starship.toml`

### 工具状态检查
```powershell
# 检查所有工具状态
tools

# 系统健康检查
.\health-check.ps1

# PowerShell 配置验证
.\powershell\verify-config.ps1
```

### 安装和更新
```powershell
# 安装特定类别的工具
.\install_apps.ps1 -Category SystemTools

# 更新所有工具
scoop update *

# 查看已安装工具
scoop list
```

---

## 💡 使用技巧

1. **善用 Tab 补全**: 大多数工具都支持 Tab 补全
2. **组合使用管道**: 将多个工具通过管道连接使用
3. **使用别名**: 记住常用的别名可以大大提高效率
4. **查看帮助**: 使用 `tool --help` 查看详细帮助
5. **定期更新**: 使用 `scoop update *` 保持工具最新

---

*本文档会随着工具的更新和使用经验的积累而持续更新。*