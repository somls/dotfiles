# Validate-JsonConfigs.ps1
# 增强的JSON配置验证脚本 - 支持模式验证、修复建议、批量处理
# 高效/严谨/实用原则

[CmdletBinding()]
param(
    [string[]]$Path = @(),
    [switch]$Recursive,
    [switch]$Fix,
    [switch]$Detailed,
    [switch]$UseSchema,
    [string]$SchemaPath = "",
    [switch]$ExportReport,
    [string]$ReportPath = "json-validation-report.json",
    [switch]$Quiet,
    [ValidateSet("Error", "Warning", "Info", "All")]
    [string]$Level = "All",
    [switch]$IncludeExamples
)

# 严格模式
Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

# 全局变量
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:ValidationResults = @()
$script:SchemaCache = @{}
$script:StartTime = Get-Date

# JSON验证结果类
class JsonValidationResult {
    [string]$FilePath
    [bool]$IsValid
    [string]$Status
    [string]$Message
    [array]$Errors
    [array]$Warnings
    [hashtable]$Metadata
    [string]$Suggestion
    [timespan]$ValidationDuration

    JsonValidationResult([string]$filePath) {
        $this.FilePath = $filePath
        $this.IsValid = $false
        $this.Status = "Unknown"
        $this.Message = ""
        $this.Errors = @()
        $this.Warnings = @()
        $this.Metadata = @{}
        $this.Suggestion = ""
        $this.ValidationDuration = [timespan]::Zero
    }
}

# 输出函数
function Write-ValidationMessage {
    param(
        [string]$Message,
        [string]$Type = "Info",
        [switch]$NoNewLine
    )

    if ($Quiet) { return }

    $color = switch ($Type) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Info" { "Cyan" }
        default { "White" }
    }

    $prefix = switch ($Type) {
        "Success" { "✅" }
        "Warning" { "⚠️ " }
        "Error" { "❌" }
        "Info" { "ℹ️ " }
        default { "•" }
    }

    if ($NoNewLine) {
        Write-Host "$prefix $Message" -ForegroundColor $color -NoNewline
    } else {
        Write-Host "$prefix $Message" -ForegroundColor $color
    }
}

# 获取JSON文件列表
function Get-JsonFiles {
    param([string[]]$Paths, [switch]$Recursive)

    $jsonFiles = @()

    if ($Paths.Count -eq 0) {
        # 如果没有指定路径，搜索项目根目录
        $Paths = @($script:ProjectRoot)
        $Recursive = $true
    }

    foreach ($path in $Paths) {
        $resolvedPath = if ([System.IO.Path]::IsPathRooted($path)) {
            $path
        } else {
            Join-Path $script:ProjectRoot $path
        }

        if (Test-Path $resolvedPath) {
            if ((Get-Item $resolvedPath).PSIsContainer) {
                # 目录
                if ($Recursive) {
                    $jsonFiles += Get-ChildItem $resolvedPath -Filter "*.json" -Recurse -File
                } else {
                    $jsonFiles += Get-ChildItem $resolvedPath -Filter "*.json" -File
                }
            } else {
                # 文件
                if ($resolvedPath -like "*.json") {
                    $jsonFiles += Get-Item $resolvedPath
                }
            }
        } else {
            Write-ValidationMessage "路径不存在: $resolvedPath" "Warning"
        }
    }

    return $jsonFiles
}

# 加载JSON架构
function Get-JsonSchema {
    param([string]$SchemaPath)

    if ($script:SchemaCache.ContainsKey($SchemaPath)) {
        return $script:SchemaCache[$SchemaPath]
    }

    try {
        $schemaContent = Get-Content $SchemaPath -Raw -ErrorAction Stop
        $schema = $schemaContent | ConvertFrom-Json -ErrorAction Stop
        $script:SchemaCache[$SchemaPath] = $schema
        return $schema
    } catch {
        Write-ValidationMessage "无法加载架构文件: $SchemaPath - $($_.Exception.Message)" "Error"
        return $null
    }
}

# 基础JSON语法验证
function Test-JsonSyntax {
    param([string]$FilePath, [JsonValidationResult]$Result)

    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $content = Get-Content $FilePath -Raw -ErrorAction Stop

        if ([string]::IsNullOrWhiteSpace($content)) {
            $Result.Status = "Warning"
            $Result.Message = "文件为空"
            $Result.Warnings += "JSON文件内容为空"
            $Result.Suggestion = "添加有效的JSON内容"
            return $Result
        }

        # 尝试解析JSON
        $jsonObject = $content | ConvertFrom-Json -ErrorAction Stop

        $Result.IsValid = $true
        $Result.Status = "Success"
        $Result.Message = "JSON语法正确"

        # 收集元数据
        $Result.Metadata.Size = (Get-Item $FilePath).Length
        $Result.Metadata.LineCount = ($content -split "`n").Count
        $Result.Metadata.CharCount = $content.Length

        # 分析JSON结构
        $Result.Metadata.ObjectType = $jsonObject.GetType().Name

        if ($jsonObject -is [PSCustomObject]) {
            $properties = $jsonObject.PSObject.Properties
            $Result.Metadata.PropertyCount = $properties.Count
            $Result.Metadata.Properties = $properties.Name -join ", "
        } elseif ($jsonObject -is [Array]) {
            $Result.Metadata.ArrayLength = $jsonObject.Count
            $Result.Metadata.ElementTypes = ($jsonObject | ForEach-Object { $_.GetType().Name } | Sort-Object -Unique) -join ", "
        }

        # 检查常见的JSON最佳实践
        $warnings = @()

        # 检查是否有注释（JSON标准不支持）
        if ($content -match '//|/\*.*\*/') {
            $warnings += "检测到注释，JSON标准不支持注释"
        }

        # 检查尾随逗号
        if ($content -match ',\s*[}\]]') {
            $warnings += "检测到尾随逗号，可能导致某些解析器失败"
        }

        # 检查单引号
        if ($content -match "'[^']*':\s*|:\s*'[^']*'") {
            $warnings += "检测到单引号，JSON标准要求使用双引号"
        }

        if ($warnings.Count -gt 0) {
            $Result.Status = "Warning"
            $Result.Warnings = $warnings
            $Result.Suggestion = "遵循JSON最佳实践以确保兼容性"
        }

    } catch {
        $Result.IsValid = $false
        $Result.Status = "Error"
        $Result.Message = "JSON语法错误"
        $Result.Errors += $_.Exception.Message

        # 尝试提供更详细的错误信息
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "line (\d+)") {
            $lineNumber = $matches[1]
            $Result.Suggestion = "检查第 $lineNumber 行的JSON语法错误"
        } elseif ($errorMessage -match "position (\d+)") {
            $position = $matches[1]
            $Result.Suggestion = "检查位置 $position 处的JSON语法错误"
        } else {
            $Result.Suggestion = "使用JSON验证工具检查语法错误"
        }
    } finally {
        $timer.Stop()
        $Result.ValidationDuration = $timer.Elapsed
    }

    return $Result
}

# 架构验证（基础实现）
function Test-JsonSchema {
    param(
        [string]$FilePath,
        [object]$Schema,
        [JsonValidationResult]$Result
    )

    if (-not $Schema) {
        return $Result
    }

    try {
        $content = Get-Content $FilePath -Raw
        $jsonObject = $content | ConvertFrom-Json

        # 基础架构验证
        $schemaErrors = @()
        $schemaWarnings = @()

        # 检查必需属性
        if ($Schema.required -and $Schema.required -is [Array]) {
            foreach ($requiredProp in $Schema.required) {
                if (-not $jsonObject.PSObject.Properties.Name.Contains($requiredProp)) {
                    $schemaErrors += "缺少必需属性: $requiredProp"
                }
            }
        }

        # 检查属性类型（简化实现）
        if ($Schema.properties) {
            foreach ($propName in $jsonObject.PSObject.Properties.Name) {
                if ($Schema.properties.PSObject.Properties.Name.Contains($propName)) {
                    $propSchema = $Schema.properties.$propName
                    $propValue = $jsonObject.$propName

                    # 类型检查
                    if ($propSchema.type) {
                        $expectedType = $propSchema.type
                        $actualType = switch ($propValue.GetType().Name) {
                            "String" { "string" }
                            "Int32" { "integer" }
                            "Int64" { "integer" }
                            "Double" { "number" }
                            "Boolean" { "boolean" }
                            "Object[]" { "array" }
                            "PSCustomObject" { "object" }
                            default { "unknown" }
                        }

                        if ($actualType -ne $expectedType -and $expectedType -ne "unknown") {
                            $schemaWarnings += "属性 '$propName' 类型不匹配: 期望 $expectedType，实际 $actualType"
                        }
                    }
                }
            }
        }

        # 更新结果
        if ($schemaErrors.Count -gt 0) {
            $Result.Status = "Error"
            $Result.IsValid = $false
            $Result.Errors += $schemaErrors
            $Result.Suggestion = "修复架构验证错误以符合定义的JSON架构"
        } elseif ($schemaWarnings.Count -gt 0) {
            if ($Result.Status -eq "Success") {
                $Result.Status = "Warning"
            }
            $Result.Warnings += $schemaWarnings
            if (-not $Result.Suggestion) {
                $Result.Suggestion = "检查架构警告以改善JSON结构"
            }
        }

        $Result.Metadata.SchemaValidation = $true
        $Result.Metadata.SchemaErrors = $schemaErrors.Count
        $Result.Metadata.SchemaWarnings = $schemaWarnings.Count

    } catch {
        $Result.Errors += "架构验证失败: $($_.Exception.Message)"
        if ($Result.Status -eq "Success") {
            $Result.Status = "Warning"
        }
    }

    return $Result
}

# 自动修复JSON文件
function Repair-JsonFile {
    param([string]$FilePath, [JsonValidationResult]$Result)

    if (-not $Fix) {
        return $false
    }

    $repaired = $false

    try {
        $content = Get-Content $FilePath -Raw

        # 修复常见问题
        $originalContent = $content

        # 移除注释（简单实现）
        $content = $content -replace '//.*$', '' -replace '/\*.*?\*/', ''

        # 修复单引号为双引号（谨慎处理）
        $content = $content -replace "(?<!\\)'([^']*)'(?=\s*:)", '"$1"'
        $content = $content -replace "(?<!\\):\s*'([^']*)'", ': "$1"'

        # 移除尾随逗号
        $content = $content -replace ',(\s*[}\]])', '$1'

        if ($content -ne $originalContent) {
            # 验证修复后的JSON
            try {
                $content | ConvertFrom-Json | Out-Null

                # 创建备份
                $backupPath = "$FilePath.backup"
                Copy-Item $FilePath $backupPath

                # 保存修复后的内容
                $content | Out-File $FilePath -Encoding UTF8

                $Result.Message += " (已自动修复)"
                $Result.Status = "Success"
                $Result.IsValid = $true
                $Result.Suggestion = "文件已修复，备份保存在: $backupPath"

                $repaired = $true
                Write-ValidationMessage "  🔧 已修复: $FilePath" "Success"

            } catch {
                # 修复失败，恢复原内容
                $Result.Errors += "自动修复失败: $($_.Exception.Message)"
                $Result.Suggestion = "需要手动修复JSON语法错误"
            }
        }

    } catch {
        $Result.Errors += "修复过程出错: $($_.Exception.Message)"
    }

    return $repaired
}

# 验证单个JSON文件
function Test-JsonFile {
    param([System.IO.FileInfo]$File, [object]$Schema = $null)

    $result = [JsonValidationResult]::new($File.FullName)

    Write-ValidationMessage "验证: $($File.Name)" "Info" -NoNewLine

    # 基础语法验证
    $result = Test-JsonSyntax -FilePath $File.FullName -Result $result

    # 架构验证
    if ($Schema -and $result.IsValid) {
        $result = Test-JsonSchema -FilePath $File.FullName -Schema $Schema -Result $result
    }

    # 尝试自动修复
    if (-not $result.IsValid) {
        $repaired = Repair-JsonFile -FilePath $File.FullName -Result $result
    }

    # 输出结果
    $statusSymbol = switch ($result.Status) {
        "Success" { " ✅" }
        "Warning" { " ⚠️" }
        "Error" { " ❌" }
        default { " ❓" }
    }

    Write-Host $statusSymbol -ForegroundColor $(switch ($result.Status) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "Gray" }
    })

    # 详细信息
    if ($Detailed) {
        Write-ValidationMessage "  📁 路径: $($File.FullName)" "Info"
        Write-ValidationMessage "  📊 大小: $([math]::Round($result.Metadata.Size/1KB, 2)) KB" "Info"
        Write-ValidationMessage "  ⏱️  验证用时: $([math]::Round($result.ValidationDuration.TotalMilliseconds, 2)) ms" "Info"

        if ($result.Errors.Count -gt 0) {
            Write-ValidationMessage "  ❌ 错误:" "Error"
            foreach ($error in $result.Errors) {
                Write-ValidationMessage "    • $error" "Error"
            }
        }

        if ($result.Warnings.Count -gt 0) {
            Write-ValidationMessage "  ⚠️  警告:" "Warning"
            foreach ($warning in $result.Warnings) {
                Write-ValidationMessage "    • $warning" "Warning"
            }
        }

        if ($result.Suggestion) {
            Write-ValidationMessage "  💡 建议: $($result.Suggestion)" "Info"
        }

        Write-Host ""
    }

    return $result
}

# 生成验证报告
function New-ValidationReport {
    param([array]$Results)

    $report = @{
        timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        version = "1.0.0"
        summary = @{
            totalFiles = $Results.Count
            validFiles = ($Results | Where-Object { $_.IsValid }).Count
            filesWithErrors = ($Results | Where-Object { $_.Errors.Count -gt 0 }).Count
            filesWithWarnings = ($Results | Where-Object { $_.Warnings.Count -gt 0 }).Count
            totalErrors = ($Results | ForEach-Object { $_.Errors.Count } | Measure-Object -Sum).Sum
            totalWarnings = ($Results | ForEach-Object { $_.Warnings.Count } | Measure-Object -Sum).Sum
            averageValidationTime = [math]::Round(($Results | ForEach-Object { $_.ValidationDuration.TotalMilliseconds } | Measure-Object -Average).Average, 2)
        }
        results = $Results | ForEach-Object {
            @{
                filePath = $_.FilePath
                isValid = $_.IsValid
                status = $_.Status
                message = $_.Message
                errors = $_.Errors
                warnings = $_.Warnings
                metadata = $_.Metadata
                suggestion = $_.Suggestion
                validationDuration = $_.ValidationDuration.TotalMilliseconds
            }
        }
        environment = @{
            computerName = $env:COMPUTERNAME
            userName = $env:USERNAME
            powershellVersion = $PSVersionTable.PSVersion.ToString()
            workingDirectory = (Get-Location).Path
        }
    }

    return $report
}

# 主执行函数
function Invoke-JsonValidation {
    Write-ValidationMessage "🔍 JSON配置文件验证开始" "Info"
    Write-ValidationMessage "=============================" "Info"
    Write-Host ""

    # 获取要验证的JSON文件
    $jsonFiles = Get-JsonFiles -Paths $Path -Recursive:$Recursive

    if ($jsonFiles.Count -eq 0) {
        Write-ValidationMessage "未找到JSON文件进行验证" "Warning"
        return
    }

    Write-ValidationMessage "找到 $($jsonFiles.Count) 个JSON文件进行验证" "Info"

    # 加载架构（如果指定）
    $schema = $null
    if ($UseSchema -and $SchemaPath) {
        $resolvedSchemaPath = if ([System.IO.Path]::IsPathRooted($SchemaPath)) {
            $SchemaPath
        } else {
            Join-Path $script:ProjectRoot $SchemaPath
        }

        $schema = Get-JsonSchema -SchemaPath $resolvedSchemaPath
        if ($schema) {
            Write-ValidationMessage "已加载JSON架构: $SchemaPath" "Success"
        }
    }

    Write-Host ""

    # 验证每个文件
    $results = @()
    $progressCount = 0

    foreach ($file in $jsonFiles) {
        $progressCount++

        if (-not $Quiet -and $jsonFiles.Count -gt 5) {
            $percent = [math]::Round(($progressCount / $jsonFiles.Count) * 100, 1)
            Write-Progress -Activity "验证JSON文件" -Status "处理 $($file.Name)" -PercentComplete $percent
        }

        $result = Test-JsonFile -File $file -Schema $schema
        $results += $result
    }

    if ($jsonFiles.Count -gt 5) {
        Write-Progress -Activity "验证JSON文件" -Completed
    }

    # 保存结果
    $script:ValidationResults = $results

    # 显示总结
    Write-Host ""
    Show-ValidationSummary -Results $results

    # 导出报告
    if ($ExportReport) {
        $report = New-ValidationReport -Results $results
        try {
            $report | ConvertTo-Json -Depth 10 | Out-File $ReportPath -Encoding UTF8
            Write-ValidationMessage "📄 验证报告已导出: $ReportPath" "Success"
        } catch {
            Write-ValidationMessage "❌ 导出报告失败: $($_.Exception.Message)" "Error"
        }
    }

    return $results
}

# 显示验证总结
function Show-ValidationSummary {
    param([array]$Results)

    $totalDuration = (Get-Date) - $script:StartTime
    $summary = @{
        Total = $Results.Count
        Valid = ($Results | Where-Object { $_.IsValid }).Count
        WithErrors = ($Results | Where-Object { $_.Errors.Count -gt 0 }).Count
        WithWarnings = ($Results | Where-Object { $_.Warnings.Count -gt 0 }).Count
        TotalErrors = ($Results | ForEach-Object { $_.Errors.Count } | Measure-Object -Sum).Sum
        TotalWarnings = ($Results | ForEach-Object { $_.Warnings.Count } | Measure-Object -Sum).Sum
    }

    Write-ValidationMessage "📊 验证结果总结" "Info"
    Write-ValidationMessage "=================" "Info"
    Write-Host ""

    Write-ValidationMessage "📁 总文件数: $($summary.Total)" "Info"
    Write-ValidationMessage "✅ 有效文件: $($summary.Valid)" "Success"
    Write-ValidationMessage "❌ 错误文件: $($summary.WithErrors)" "Error"
    Write-ValidationMessage "⚠️  警告文件: $($summary.WithWarnings)" "Warning"
    Write-ValidationMessage "🔥 总错误数: $($summary.TotalErrors)" "Error"
    Write-ValidationMessage "⚡ 总警告数: $($summary.TotalWarnings)" "Warning"
    Write-ValidationMessage "⏱️  总用时: $([math]::Round($totalDuration.TotalSeconds, 2)) 秒" "Info"
    Write-Host ""

    # 计算成功率
    $successRate = if ($summary.Total -gt 0) {
        [math]::Round(($summary.Valid / $summary.Total) * 100, 1)
    } else { 0 }

    $rateColor = if ($successRate -eq 100) { "Success" } elseif ($successRate -ge 80) { "Warning" } else { "Error" }
    Write-ValidationMessage "🎯 验证成功率: $successRate%" $rateColor

    # 显示问题文件列表
    if ($summary.WithErrors -gt 0) {
        Write-Host ""
        Write-ValidationMessage "❌ 存在错误的文件:" "Error"
        $errorFiles = $Results | Where-Object { $_.Errors.Count -gt 0 }
        foreach ($file in $errorFiles) {
            $relativePath = $file.FilePath.Replace($script:ProjectRoot, "").TrimStart('\', '/')
            Write-ValidationMessage "  • $relativePath" "Error"
            if ($IncludeExamples -and $file.Errors.Count -gt 0) {
                Write-ValidationMessage "    错误: $($file.Errors[0])" "Error"
            }
        }
    }

    if ($summary.WithWarnings -gt 0 -and ($Detailed -or $summary.WithWarnings -le 3)) {
        Write-Host ""
        Write-ValidationMessage "⚠️  存在警告的文件:" "Warning"
        $warningFiles = $Results | Where-Object { $_.Warnings.Count -gt 0 }
        foreach ($file in $warningFiles | Select-Object -First 3) {
            $relativePath = $file.FilePath.Replace($script:ProjectRoot, "").TrimStart('\', '/')
            Write-ValidationMessage "  • $relativePath" "Warning"
        }
        if ($warningFiles.Count -gt 3) {
            Write-ValidationMessage "  ... 以及其他 $($warningFiles.Count - 3) 个文件" "Warning"
        }
    }

    Write-Host ""
    Write-ValidationMessage "💡 提示: 使用 -Detailed 参数查看详细信息，使用 -Fix 参数尝试自动修复" "Info"
}

# 主执行逻辑
if ($MyInvocation.InvocationName -ne '.') {
    # 参数验证
    if ($UseSchema -and -not $SchemaPath) {
        $defaultSchemaPath = Join-Path $script:ProjectRoot "config\schemas\install.schema.json"
        if (Test-Path $defaultSchemaPath) {
            $SchemaPath = $defaultSchemaPath
            Write-ValidationMessage "使用默认架构文件: $SchemaPath" "Info"
        } else {
            Write-ValidationMessage "指定了架构验证但未提供架构文件路径" "Warning"
            $UseSchema = $false
        }
    }

    # 执行验证
    try {
        $results = Invoke-JsonValidation

        # 设置退出代码
        $exitCode = 0
        if ($results) {
            $hasErrors = ($results | Where-Object { $_.Errors.Count -gt 0 }).Count -gt 0
            $hasWarnings = ($results | Where-Object { $_.Warnings.Count -gt 0 }).Count -gt 0

            if ($hasErrors) {
                $exitCode = 1
            } elseif ($hasWarnings) {
                $exitCode = 2
            }
        }

        exit $exitCode
    } catch {
        Write-ValidationMessage "验证过程中发生错误: $($_.Exception.Message)" "Error"
        exit 1
    }
}
