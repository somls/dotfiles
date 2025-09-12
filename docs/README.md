# 📚 文档中心

欢迎来到Windows Dotfiles管理系统v2.0的精简文档中心！

## 🎯 文档架构 (v2.0)

### 📁 根目录文档 (主要文档)
位于项目根目录，面向所有用户的核心文档：

| 文档 | 说明 | 适合用户 |
|------|------|----------|
| **[README.md](../README.md)** | 项目概述、快速开始、核心特性 | 所有用户 |
| **[USAGE_GUIDE.md](../USAGE_GUIDE.md)** | 详细使用指南和最佳实践 | 日常用户 |
| **[ARCHITECTURE.md](../ARCHITECTURE.md)** | 完整架构文档和设计原理 | 开发者、架构师 |

### 📂 docs/ 目录 (专业文档)
位于 `docs/` 目录，面向高级用户和问题解决：

| 文档 | 说明 | 适合用户 |
|------|------|----------|
| **[API_REFERENCE.md](API_REFERENCE.md)** | 完整API接口文档和参数说明 | 开发者、高级用户 |
| **[FAQ.md](FAQ.md)** | 常见问题解答和使用技巧 | 所有用户 |
| **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** | 故障排除指南和诊断方法 | 遇到问题的用户 |
| **[OPTIMIZATION_REPORT.md](OPTIMIZATION_REPORT.md)** | v2.0优化报告和改进详情 | 项目维护者 |
| **[PROJECT_STATUS.md](PROJECT_STATUS.md)** | 项目状态总结和完成情况 | 项目管理者 |

---

## 🚀 快速导航

### 👥 按用户类型查找

| 用户类型 | 推荐文档路径 |
|----------|-------------|
| 🆕 **新用户** | [README.md](../README.md) → [USAGE_GUIDE.md](../USAGE_GUIDE.md) → [FAQ.md](FAQ.md) |
| 🔧 **开发者** | [ARCHITECTURE.md](../ARCHITECTURE.md) → [API_REFERENCE.md](API_REFERENCE.md) |
| 🛠️ **维护者** | [OPTIMIZATION_REPORT.md](OPTIMIZATION_REPORT.md) → [PROJECT_STATUS.md](PROJECT_STATUS.md) |
| ❓ **问题解决** | [FAQ.md](FAQ.md) → [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |

### 📋 按使用场景查找

| 场景 | 文档 |
|------|------|
| **首次安装** | [README.md](../README.md) → [USAGE_GUIDE.md](../USAGE_GUIDE.md) |
| **日常使用** | [USAGE_GUIDE.md](../USAGE_GUIDE.md) → [FAQ.md](FAQ.md) |
| **故障排除** | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) → [FAQ.md](FAQ.md) |
| **深度定制** | [API_REFERENCE.md](API_REFERENCE.md) → [ARCHITECTURE.md](../ARCHITECTURE.md) |
| **项目贡献** | [ARCHITECTURE.md](../ARCHITECTURE.md) → [OPTIMIZATION_REPORT.md](OPTIMIZATION_REPORT.md) |

---

## ⚡ 新用户快速开始

```powershell
# 1. 完整安装 (推荐)
.\manage.ps1 setup

# 2. 检查状态
.\manage.ps1 status

# 3. 获取帮助
.\manage.ps1 help
```

**学习路径**: [项目概述](../README.md) → [使用指南](../USAGE_GUIDE.md) → [常见问题](FAQ.md)

---

## 🔍 v2.0 架构亮点

### 统一管理接口
- **单一入口**: `manage.ps1` 替代4个分散脚本
- **75%命令简化**: 从多个命令到统一接口
- **智能路径**: 自动适应各种安装方式

### 基础设施升级
- **集中日志**: `.dotfiles/logs/` 统一日志管理
- **自动备份**: `.dotfiles/backups/` 安全备份系统  
- **智能缓存**: `.dotfiles/cache/` 性能优化

### 文档精简
- **去除冗余**: 删除重复和过时文档
- **按需分层**: 根目录基础文档 + docs/专业文档
- **持续更新**: 与v2.0架构同步更新

---

## 📊 文档统计

### v2.0 精简成果

| 项目 | v1.x | v2.0 | 改进 |
|------|------|------|------|
| **文档总数** | 10+ | 9个 | 10%精简 |
| **核心文档** | 分散 | 根目录集中 | 100%优化 |
| **专业文档** | 混杂 | docs/独立（6个） | 清晰分离 |
| **重复内容** | 存在 | 消除 | 100%去重 |

### 文档质量
- ✅ **准确性**: 与v2.0代码架构100%同步
- ✅ **完整性**: 覆盖所有功能和使用场景  
- ✅ **可用性**: 分层设计，适合不同用户群体
- ✅ **维护性**: 精简结构，易于更新维护

---

## 🤝 文档贡献

### 改进建议
- **Issue报告**: [GitHub Issues](https://github.com/somls/dotfiles/issues)
- **功能讨论**: [GitHub Discussions](https://github.com/somls/dotfiles/discussions)
- **文档PR**: 直接提交文档改进

### 贡献指南
1. 确认改进点 (错误修正、内容补充、结构优化)
2. 遵循现有文档风格和格式
3. 确保内容与v2.0架构同步
4. 提交PR并描述改进内容

---

## 🔗 快速链接

### 主要功能
- **[🎮 统一管理](../README.md#快速开始)** - manage.ps1 使用指南
- **[📦 应用安装](../USAGE_GUIDE.md)** - 18+精选应用程序
- **[⚙️ 配置管理](API_REFERENCE.md#核心脚本-api)** - 智能配置部署
- **[🏥 健康检查](TROUBLESHOOTING.md)** - 自动诊断修复

### 问题解决
- **[❓ 常见问题](FAQ.md)** - 使用中的常见疑问
- **[🔧 故障排除](TROUBLESHOOTING.md)** - 系统性问题解决
- **[📚 API文档](API_REFERENCE.md)** - 详细技术参考

---

<div align="center">

## 🎯 开始使用

**[📖 阅读概述](../README.md)** • **[⚡ 快速开始](../USAGE_GUIDE.md)** • **[❓ 常见问题](FAQ.md)**

**[🔧 故障排除](TROUBLESHOOTING.md)** • **[📚 API参考](API_REFERENCE.md)** • **[🏗️ 架构文档](../ARCHITECTURE.md)**

---

### ⭐ 如果这个项目对您有帮助，请给我们一个Star！

[![GitHub stars](https://img.shields.io/github/stars/somls/dotfiles?style=social)](https://github.com/somls/dotfiles)

**版本**: v2.0.0 | **状态**: ✅ 生产就绪 | **文档**: 📚 完整更新

</div>