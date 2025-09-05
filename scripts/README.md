# Scripts 文件夹

本文件夹包含项目的核心管理脚本，提供自动化的测试、验证、状态检查功能。

## 📁 脚本概览

### 🧪 测试和验证脚本

#### `Run-AllTests.ps1`
**功能**: 简化的测试运行器
- **用途**: 运行项目中的所有测试文件
- **特性**: 支持 Pester 测试框架和原生 PowerShell 测试
- **参数**: 
  - `-Detailed`: 显示详细输出
  - `-Quiet`: 静默模式
  - `-Filter`: 过滤测试文件

```powershell
# 执行所有测试
.\scripts\Run-AllTests.ps1

# 详细模式运行测试
.\scripts\Run-AllTests.ps1 -Detailed

# 运行特定测试
.\scripts\Run-AllTests.ps1 -Filter "*Utilities*"
```

#### `Validate-JsonConfigs.ps1`
**功能**: JSON配置文件验证器
- **用途**: 验证JSON语法、架构合规性、格式规范
- **特性**: 架构验证、自动修复、批量处理
- **参数**:
  - `-UseSchema`: 启用架构验证
  - `-Fix`: 自动修复常见错误
  - `-Recursive`: 递归搜索JSON文件

```powershell
# 验证所有JSON文件
.\scripts\Validate-JsonConfigs.ps1 -Recursive

# 使用架构验证
.\scripts\Validate-JsonConfigs.ps1 -UseSchema -SchemaPath config\schemas\install.schema.json

# 自动修复格式问题
.\scripts\Validate-JsonConfigs.ps1 -Fix -Detailed
```

### 📊 状态检查脚本

#### `project-status.ps1`
**功能**: 项目健康状态检查器
- **用途**: 检查脚本语法、模块状态、配置文件、文档完整性
- **特性**: 并行检查、缓存结果、自动修复、详细报告
- **参数**:
  - `-Category`: 检查特定类别 (Scripts/Modules/Configs/Docs/Tests/All)
  - `-Parallel`: 启用并行检查
  - `-FixIssues`: 自动修复问题
  - `-ExportJson`: 导出JSON报告

```powershell
# 完整项目检查
.\scripts\project-status.ps1

# 检查特定类别
.\scripts\project-status.ps1 -Category Scripts -Detailed

# 自动修复问题
.\scripts\project-status.ps1 -FixIssues

# 并行检查并导出报告
.\scripts\project-status.ps1 -Parallel -ExportJson
```

#### `run-quick-check.ps1`
**功能**: 快速项目状态检查
- **用途**: 快速验证核心文件和配置状态
- **特性**: 智能缓存、并行执行、多级检查、性能优化
- **参数**:
  - `-Level`: 检查级别 (Critical/Standard/Full)
  - `-UseCache`: 启用结果缓存
  - `-Parallel`: 并行执行
  - `-Fix`: 快速修复问题

```powershell
# 快速检查（标准级别）
.\scripts\run-quick-check.ps1

# 使用缓存的快速检查
.\scripts\run-quick-check.ps1 -UseCache

# 完整检查
.\scripts\run-quick-check.ps1 -Level Full -Parallel

# 关键文件检查
.\scripts\run-quick-check.ps1 -Level Critical -Quiet
```

### 🔧 辅助工具

#### `cleanup-project.ps1`
**功能**: 项目清理工具
- **用途**: 清理临时文件、日志文件、备份文件
- **特性**: 预览模式、安全清理、保护重要配置
- **参数**:
  - `-DryRun`: 预览将要删除的文件
  - `-IncludeLogs`: 包含日志文件清理
  - `-Force`: 强制清理无需确认

```powershell
# 预览清理
.\scripts\cleanup-project.ps1 -DryRun

# 清理临时文件
.\scripts\cleanup-project.ps1

# 完整清理包含日志
.\scripts\cleanup-project.ps1 -IncludeLogs -Force
```

#### `auto-sync.ps1`
**功能**: 智能Git同步工具
- **用途**: 自动提交本地更改并与远程同步
- **特性**: 智能冲突检测、自动备份、安全合并
- **参数**:
  - `-Message`: 自定义提交消息
  - `-PushToRemote`: 自动推送到远程
  - `-BackupFirst`: 同步前创建备份

```powershell
# 自动同步
.\scripts\auto-sync.ps1

# 自定义提交消息
.\scripts\auto-sync.ps1 -Message "更新配置文件" -PushToRemote

# 安全同步（先备份）
.\scripts\auto-sync.ps1 -BackupFirst
```

### `cmd/` 子目录
包含批处理脚本和命令行工具，提供跨平台兼容性支持。

## 📋 使用指南

### 日常检查流程
```powershell
# 1. 快速健康检查
.\scripts\run-quick-check.ps1 -UseCache

# 2. 如有问题，详细诊断
.\scripts\project-status.ps1 -Detailed -Category <问题类别>

# 3. 验证配置文件
.\scripts\Validate-JsonConfigs.ps1 -UseSchema

# 4. 运行测试套件
.\scripts\Run-AllTests.ps1 -TestType All
```

### 持续集成流程
```powershell
# CI/CD 管道中的检查序列
.\scripts\run-quick-check.ps1 -Level Critical -Quiet
.\scripts\Validate-JsonConfigs.ps1 -UseSchema -Quiet
.\scripts\Run-AllTests.ps1 -TestType Unit -Parallel
.\scripts\project-status.ps1 -ExportJson -ExportPath ci-status.json
```

### 开发环境设置
```powershell
# 开发者首次设置检查
.\scripts\project-status.ps1 -Category All -FixIssues
.\scripts\Validate-JsonConfigs.ps1 -Fix
.\scripts\Run-AllTests.ps1 -TestType Integration
```

## ⚡ 性能优化

### 并行执行
所有脚本都支持并行执行以提高性能：
- 使用 `-Parallel` 参数启用
- 自动检测CPU核心数量优化作业数
- 适用于多文件操作和独立检查任务

### 智能缓存
- `run-quick-check.ps1` 支持结果缓存（30分钟有效期）
- 缓存文件：`.quick-check-cache.json`
- 使用 `-UseCache` 参数启用

### 渐进式检查
- `Critical`: 仅检查核心文件（< 5秒）
- `Standard`: 标准检查包括配置验证（< 15秒）
- `Full`: 完整检查包括所有组件（< 30秒）

## 🚨 故障排除

### 常见问题

1. **脚本执行策略错误**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

2. **模块加载失败**
   ```powershell
   Import-Module .\modules\DotfilesUtilities.psm1 -Force
   ```

3. **并行执行超时**
   ```powershell
   # 减少并行作业数或增加超时时间
   .\scripts\Run-AllTests.ps1 -MaxParallelJobs 2 -TimeoutMinutes 120
   ```

4. **缓存问题**
   ```powershell
   # 清除缓存
   Remove-Item .quick-check-cache.json -ErrorAction SilentlyContinue
   ```

### 调试模式
```powershell
# 启用详细输出
.\scripts\project-status.ps1 -Verbosity Diagnostic

# 查看完整错误信息
.\scripts\Run-AllTests.ps1 -Verbosity Detailed -ContinueOnError
```

## 📊 报告和输出

### JSON 报告格式
脚本支持导出结构化的JSON报告：
```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "2.0.0",
  "summary": {
    "totalChecks": 15,
    "successCount": 12,
    "warningCount": 2,
    "errorCount": 1,
    "healthScore": 85.7
  },
  "results": { /* 详细结果 */ }
}
```

### 输出级别
- `Quiet`: 仅显示错误和关键信息
- `Normal`: 标准输出级别
- `Detailed`: 显示详细操作信息
- `Diagnostic`: 完整的调试信息

## 🔗 相关文档

- [项目结构说明](../PROJECT_STRUCTURE.md)
- [快速开始指南](../QUICKSTART.md)
- [配置文件说明](../config/README.md)
- [故障排除指南](../TROUBLESHOOTING.md)

---

💡 **提示**: 建议在开发过程中定期运行 `run-quick-check.ps1` 进行快速状态检查，在发布前运行完整的测试套件确保质量。