# Git 配置优化：中文、日文、韩文文件名完整支持指南

## 🔍 当前配置分析

### ✅ 已配置的核心设置
- `core.quotepath = false` - 正确显示Unicode字符文件名
- `core.precomposeunicode = true` - Unicode文件名规范化处理
- `i18n.commitencoding = utf-8` - 提交信息编码
- `i18n.logoutputencoding = utf-8` - 日志输出编码
- `core.longpaths = true` - 支持长路径
- `core.autocrlf = input` - 行尾符处理
- `feature.symlinks = true` - 符号链接支持

### 🆕 新增优化配置
通过 `windows.gitconfig` 添加了以下增强配置：

```ini
# NTFS 和 Unicode 支持
[core]
    protectNTFS = false      # 允许NTFS特殊字符（中文、日文）
    protectHFS = false       # 禁用HFS文件系统保护
    checkStat = minimal      # 减少Unicode文件名检查开销

# 完整编码支持
[i18n]
    commitEncoding = utf-8
    logOutputEncoding = utf-8
    inputEncoding = utf-8    # 支持中日文输入
```

## 🎯 配置文件作用域

### 主配置文件 (`gitconfig`)
- **核心Unicode设置**：`quotepath` 和 `precomposeunicode`
- **用户信息**：name, email
- **基本编码**：GUI、commit、log 编码

### Windows专用配置 (`windows.gitconfig`)
- **NTFS优化**：`protectNTFS = false` 允许中日文特殊字符
- **性能优化**：`checkStat = minimal` 减少Unicode检查开销
- **完整编码支持**：新增 `inputEncoding = utf-8`

## 🌐 支持的场景

### ✅ 中文支持
- 简体中文：`项目文件.txt`、`开发计划.md`
- 繁体中文：`專案文檔.txt`、`測試報告.md`

### ✅ 日文支持
- 平假名/片假名：`ファイル.txt`、`プロジェクト.md`
- 汉字：`作業内容.txt`、`仕様書.md`

### ✅ 韩文支持
- 韩文字符：`프로젝트.txt`、`문서.md`

### ✅ 混合语言支持
- 多语言文件名：`中文-日本語-한글.txt`
- 带特殊字符：`项目_v2.0（测试）.md`

## 🔧 配置验证

### 验证命令
```bash
# 检查核心配置
git config --global --get core.quotepath
git config --global --get core.precomposeunicode

# 检查编码配置
git config --global --get i18n.commitencoding
git config --global --get i18n.logoutputencoding

# 验证配置文件包含
git config --global --get include.path
```

### 测试文件名显示
```bash
# 创建测试文件
touch "测试文件.txt" "日本語.md" "한글.txt" "中文-日本語-한글.txt"

# 检查Git状态显示
git status

# 提交测试
git add .
git commit -m "测试Unicode文件名支持"
```

## 🚀 性能优化

### Windows平台优化
1. **符号链接支持**：`feature.symlinks = true`
2. **大文件性能**：`feature.manyFiles = true`
3. **长路径支持**：`core.longpaths = true`
4. **文件系统检查优化**：`core.checkStat = minimal`

### 缓存和内存优化
1. **文件系统缓存**：`core.fscache = true`
2. **打包内存限制**：`pack.windowMemory = 100m`
3. **线程数优化**：`pack.threads = 3`

## ⚠️ 注意事项

### 兼容性考虑
1. **跨平台协作**：确保团队成员都使用UTF-8编码
2. **终端支持**：使用支持Unicode的终端（Windows Terminal推荐）
3. **编辑器配置**：VS Code等编辑器也需要UTF-8编码设置

### 最佳实践
1. **一致性**：所有系统（Git、终端、编辑器）使用UTF-8
2. **备份**：配置更改前备份重要数据
3. **测试**：在测试仓库中验证Unicode文件名处理

## 🔍 故障排除

### 文件名显示问题
```bash
# 临时禁用路径转义
git config --global core.quotepath false

# 检查终端编码
echo $LANG
chcp 65001  # Windows上设置UTF-8
```

### 提交编码问题
```bash
# 设置正确的提交编码
git config --global i18n.commitencoding utf-8
git config --global i18n.logoutputencoding utf-8
```

## 📋 配置清单

- ✅ [x] `core.quotepath = false`
- ✅ [x] `core.precomposeunicode = true`
- ✅ [x] `i18n.commitencoding = utf-8`
- ✅ [x] `i18n.logoutputencoding = utf-8`
- ✅ [x] `i18n.inputEncoding = utf-8`
- ✅ [x] `core.protectNTFS = false`
- ✅ [x] `core.protectHFS = false`
- ✅ [x] `core.checkStat = minimal`
- ✅ [x] `core.longpaths = true`
- ✅ [x] `feature.symlinks = true`

现在您的Git配置已经完全优化，可以在Windows上完美支持中文、日文、韩文等多种语言的文件名！