# 🚀 工具快速参考

## 📋 常用命令速查

### 🔍 搜索和查找
```bash
rg "pattern"              # 搜索文本内容
fd filename               # 查找文件名
fzf                       # 交互式模糊搜索
z dirname                 # 智能目录跳转
```

### 📁 文件操作
```bash
bat file.txt              # 语法高亮查看文件
dust                      # 磁盘使用分析
sd 'old' 'new' file.txt   # 文本替换
tokei                     # 代码统计
```

### 🖥️ 系统监控
```bash
btop                      # 系统监控器
procs                     # 进程查看器
procs firefox             # 搜索特定进程
```

### 🌐 网络和API
```bash
wget https://url/file     # 下载文件
curl -s api.url | jq      # API请求+JSON处理
jid                       # 交互式JSON浏览
```

### ⚡ 性能测试
```bash
hyperfine 'cmd1' 'cmd2'   # 命令性能对比
hyperfine --warmup 3 'cmd' # 预热测试
```

### 🔧 Git和GitHub
```bash
gh repo clone user/repo   # 克隆仓库
gh pr create              # 创建PR
gh issue list             # 列出issues
```

---

## 🎯 别名速查

| 别名 | 实际命令 | 用途 |
|------|----------|------|
| `cat` | `bat` | 语法高亮查看文件 |
| `grep` | `rg` | 快速文本搜索 |
| `find` | `fd` | 快速文件查找 |
| `du` | `dust` | 磁盘使用分析 |
| `ps` | `procs` | 进程查看 |
| `top` | `btop` | 系统监控 |
| `json` | `jq` | JSON处理 |

---

## 🔄 常用组合

### 搜索+查看
```bash
rg "pattern" | bat        # 搜索结果高亮显示
fd -e js | fzf | xargs bat # 选择JS文件并查看
```

### 分析+跳转
```bash
dust                      # 查看磁盘使用
z large-folder            # 跳转到大文件夹
```

### API+JSON
```bash
curl -s api.url | jq '.data' | jid  # API数据交互式浏览
```

### 性能+监控
```bash
btop &                    # 后台启动监控
hyperfine 'command'       # 测试命令性能
```

---

## 🛠️ 工具管理

```powershell
# 检查工具状态
tools

# 系统健康检查  
.\health-check.ps1

# 安装工具类别
.\install_apps.ps1 -Category SystemTools

# 更新所有工具
scoop update *
```

---

## 💡 快速技巧

1. **Ctrl+R** - FZF历史命令搜索
2. **Tab** - 自动补全
3. **|** - 管道连接工具
4. **--help** - 查看帮助
5. **-p** - 大多数工具的预览模式

---

*💾 保存此文件到桌面或收藏夹，随时查阅！*