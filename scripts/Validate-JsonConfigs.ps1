# Validate-JsonConfigs.ps1
# JSON配置文件验证脚本 - 重写版本，修复编码和语法问题

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
$ErrorActionPreference = 'Continue'

# 全局变量
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:ValidationResults = @()
$script:StartTime = Get-Date

# JSON验证结果类
function New-ValidationResult {
    param(
        [string]$FilePath,
        [bool]$IsValid = $false,
        [string]$Status = "Unknown",
        [string]$Message = "",
        [array]$Errors = @(),
        [array]$Warnings = @(),
        [hashtable]$Metadata = @{},
        [string]$Suggestion = ""
    )

    return @{
        FilePath = $FilePath
        IsValid = $IsValid
        Status = $Status
        Message = $Message
        Errors = $Errors
        Warnings = $Warnings
        Metadata = $Metadata
        Suggestion = $Suggestion
        ValidationDuration = [timespan]::Zero
        Timestamp = Get-Date
    }
}

# 输出函数
function Write-ValidationMessage {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info",
        [switch]$NoNewline
    )

    if ($Quiet -and $Type -eq "Info") { return }

    $color = switch ($Type) {
        "Success" { "Green" }
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Info" { "Cyan" }
    }

    $prefix = switch ($Type) {
        "Success" { "✅" }
        "Error" { "❌" }
        "Warning" { "⚠️" }
        "Info" { "ℹ️" }
    }

    if ($NoNewline) {
        Write-Host " $prefix" -ForegroundColor $color -NoNewline
    } else {
        Write-Host "$prefix $Message" -ForegroundColor $color
    }
}

# 验证JSON语法
function Test-JsonSyntax {
    param([string]$FilePath)

    $result = New-ValidationResult -FilePath $FilePath
    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        # 读取文件内容
        if (-not (Test-Path $FilePath)) {
            $result.Status = "Error"
            $result.Message = "文件不存在"
            $result.Errors += "指定的文件路径不存在"
            return $result
        }

        $content = Get-Content $FilePath -Raw -Encoding UTF8 -ErrorAction Stop

        # 检查空文件
        if ([string]::IsNullOrWhiteSpace($content)) {
            $result.Status = "Warning"
            $result.Message = "文件为空"
            $result.Warnings += "JSON文件内容为空"
            $result.Suggestion = "添加有效的JSON内容"
            return $result
        }

        # 尝试解析JSON
        $null = $content | ConvertFrom-Json -ErrorAction Stop

        $result.IsValid = $true
        $result.Status = "Success"
        $result.Message = "JSON语法正确"

        # 检查最佳实践
        $warnings = @()

        # 检查注释（JSON标准不支持）
        if ($content -match '//.*|/\*[\s\S]*?\*/') {
            $warnings += "检测到注释，JSON标准不支持注释"
        }

        # 检查尾随逗号
        if ($content -match ',\s*[\}\]]') {
            $warnings += "检测到尾随逗号，可能导致某些解析器失败"
        }

        # 检查单引号
        if ($content -match "'[^']*':\s*|:\s*'[^']*'") {
            $warnings += "检测到单引号，JSON标准要求使用双引号"
        }

        if ($warnings -and $warnings.Count -gt 0) {
            $result.Status = "Warning"
            $result.Warnings = $warnings
            $result.Suggestion = "遵循JSON最佳实践以确保兼容性"
        }

    } catch {
        $result.IsValid = $false
        $result.Status = "Error"
        $result.Message = "JSON语法错误"
        $result.Errors += $_.Exception.Message

        # 尝试提供更详细的错误信息
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "line (\d+)") {
            $lineNumber = $matches[1]
            $result.Suggestion = "检查第 $lineNumber 行的JSON语法错误"
        } elseif ($errorMessage -match "position (\d+)") {
            $position = $matches[1]
            $result.Suggestion = "检查位置 $position 处的JSON语法错误"
        } else {
            $result.Suggestion = "检查JSON语法，确保所有括号匹配且语法正确"
        }
    } finally {
        $timer.Stop()
        $result.ValidationDuration = $timer.Elapsed
    }

    return $result
}

# 架构验证（如果提供了架构文件）
function Test-JsonSchema {
    param(
        [string]$JsonFilePath,
        [string]$SchemaFilePath,
        [object]$Result
    )

    if (-not $UseSchema -or [string]::IsNullOrWhiteSpace($SchemaFilePath)) {
        return $Result
    }

    if (-not (Test-Path $SchemaFilePath)) {
        $Result.Warnings += "架构文件不存在: $SchemaFilePath"
        return $Result
    }

    try {
        # 这里可以添加更复杂的JSON架构验证逻辑
        # 目前只做基本检查
        $schemaContent = Get-Content $SchemaFilePath -Raw -Encoding UTF8
        $null = $schemaContent | ConvertFrom-Json

        # 简单的架构验证示例
        $jsonContent = Get-Content $JsonFilePath -Raw -Encoding UTF8
        $jsonObject = $jsonContent | ConvertFrom-Json

        $schemaErrors = @()
        $schemaWarnings = @()

        # 这里可以根据具体需求添加架构验证规则
        # 例如检查必需字段、数据类型等

        if ($schemaErrors -and $schemaErrors.Count -gt 0) {
            $Result.Status = "Error"
            $Result.IsValid = $false
            $Result.Errors += $schemaErrors
            $Result.Suggestion = "修复架构验证错误以符合定义的JSON架构"
        } elseif ($schemaWarnings -and $schemaWarnings.Count -gt 0) {
            if ($Result.Status -eq "Success") {
                $Result.Status = "Warning"
            }
            $Result.Warnings += $schemaWarnings
        }

    } catch {
        $Result.Errors += "架构验证失败: $($_.Exception.Message)"
        if ($Result.Status -eq "Success") {
            $Result.Status = "Warning"
        }
    }

    return $Result
}

# 自动修复功能
function Repair-JsonFile {
    param(
        [string]$FilePath,
        [object]$Result
    )

    if (-not $Fix) { return $Result }

    try {
        $content = Get-Content $FilePath -Raw -Encoding UTF8

        # 简单的修复：格式化JSON
        if ($Result.IsValid) {
            $jsonObject = $content | ConvertFrom-Json
            $formattedContent = $jsonObject | ConvertTo-Json -Depth 10 -Compress:$false

            if ($content -ne $formattedContent) {
                # 创建备份
                $backupPath = "$FilePath.backup"
                Copy-Item $FilePath $backupPath

                # 保存修复后的内容
                $formattedContent | Out-File $FilePath -Encoding UTF8

                $Result.Message += " (已自动修复格式)"
                $Result.Status = "Success"
                $Result.Metadata.AutoFixed = $true
                $Result.Metadata.BackupPath = $backupPath
            }
        }

    } catch {
        $Result.Warnings += "自动修复失败: $($_.Exception.Message)"
    }

    return $Result
}

# 显示单个验证结果
function Show-ValidationResult {
    param([object]$Result)

    # 过滤日志级别
    $shouldShow = switch ($Level) {
        "Error" { $Result.Status -eq "Error" }
        "Warning" { $Result.Status -in @("Error", "Warning") }
        "Info" { $Result.Status -in @("Error", "Warning", "Success") }
        "All" { $true }
    }

    if (-not $shouldShow) { return }

    # 输出结果
    $statusSymbol = switch ($Result.Status) {
        "Success" { " ✅" }
        "Warning" { " ⚠️" }
        "Error" { " ❌" }
        default { " ❓" }
    }

    Write-Host $statusSymbol -ForegroundColor $(switch ($Result.Status) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "White" }
    }) -NoNewline

    Write-Host " $($Result.FilePath): $($Result.Message)" -ForegroundColor White

    # 显示详细信息
    if ($Detailed) {
        if ($Result.Errors -and $Result.Errors.Count -gt 0) {
            Write-Host "   错误:" -ForegroundColor Red
            foreach ($error in $Result.Errors) {
                Write-Host "     - $error" -ForegroundColor Red
            }
        }

        if ($Result.Warnings -and $Result.Warnings.Count -gt 0) {
            Write-Host "   警告:" -ForegroundColor Yellow
            foreach ($warning in $Result.Warnings) {
                Write-Host "     - $warning" -ForegroundColor Yellow
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($Result.Suggestion)) {
            Write-Host "   建议: $($Result.Suggestion)" -ForegroundColor Cyan
        }

        if ($Result.ValidationDuration.TotalMilliseconds -gt 10) {
            Write-Host "   耗时: $($Result.ValidationDuration.TotalMilliseconds.ToString('F0'))ms" -ForegroundColor Gray
        }
    }
}

# 获取要验证的JSON文件列表
function Get-JsonFiles {
    param([string[]]$InputPaths)

    $jsonFiles = @()

    if ($InputPaths.Count -eq 0) {
        # 如果没有指定路径，使用项目根目录并自动启用递归
        $InputPaths = @($script:ProjectRoot)
        $Recursive = $true
    }

    foreach ($inputPath in $InputPaths) {
        if ([System.IO.Path]::IsPathRooted($inputPath)) {
            $resolvedPath = $inputPath
        } else {
            $resolvedPath = Join-Path $script:ProjectRoot $inputPath
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
                if ($resolvedPath.EndsWith('.json')) {
                    $jsonFiles += Get-Item $resolvedPath
                }
            }
        } else {
            Write-ValidationMessage "路径不存在: $resolvedPath" "Warning"
        }
    }

    # 排除示例文件（除非明确包含）
    if (-not $IncludeExamples) {
        $jsonFiles = $jsonFiles | Where-Object { $_.Name -notmatch '\.example\.json$|\.sample\.json$|\.template\.json$' }
    }

    return $jsonFiles
}

# 导出验证报告
function Export-ValidationReport {
    if (-not $ExportReport) { return }

    try {
        $report = @{
            timestamp = $script:StartTime.ToString("yyyy-MM-ddTHH:mm:ss")
            version = "1.0.0"
            summary = @{
                totalFiles = $script:ValidationResults.Count
                validFiles = @($script:ValidationResults | Where-Object { $_.IsValid }).Count
                invalidFiles = @($script:ValidationResults | Where-Object { -not $_.IsValid }).Count
                warningFiles = @($script:ValidationResults | Where-Object { $_.Status -eq "Warning" }).Count
                averageValidationTime = if ($script:ValidationResults.Count -gt 0) {
                    [math]::Round(($script:ValidationResults | ForEach-Object { $_.ValidationDuration.TotalMilliseconds } | Measure-Object -Average).Average, 2)
                } else { 0 }
            }
            results = $script:ValidationResults | ForEach-Object {
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
            configuration = @{
                recursive = $Recursive.IsPresent
                fix = $Fix.IsPresent
                useSchema = $UseSchema.IsPresent
                schemaPath = $SchemaPath
                level = $Level
                includeExamples = $IncludeExamples.IsPresent
            }
        }

        $reportPath = if ([System.IO.Path]::IsPathRooted($ReportPath)) {
            $ReportPath
        } else {
            Join-Path $script:ProjectRoot $ReportPath
        }

        $report | ConvertTo-Json -Depth 5 | Out-File $reportPath -Encoding UTF8
        Write-ValidationMessage "验证报告已导出: $reportPath" "Success"

    } catch {
        Write-ValidationMessage "导出报告失败: $($_.Exception.Message)" "Error"
    }
}

# 主执行逻辑
function Start-JsonValidation {
    Write-ValidationMessage "🔍 开始JSON配置文件验证" "Info"

    # 获取要验证的文件
    $jsonFiles = Get-JsonFiles -InputPaths $Path

    if (-not $jsonFiles -or $jsonFiles.Count -eq 0) {
        Write-ValidationMessage "没有找到JSON文件进行验证" "Warning"
        return
    }

    $fileCount = if ($jsonFiles -is [array]) { $jsonFiles.Count } else { 1 }
    Write-ValidationMessage "找到 $fileCount 个JSON文件" "Info"

    # 验证每个文件
    foreach ($file in $jsonFiles) {
        $result = Test-JsonSyntax -FilePath $file.FullName

        # 架构验证
        if ($UseSchema) {
            $result = Test-JsonSchema -JsonFilePath $file.FullName -SchemaFilePath $SchemaPath -Result $result
        }

        # 自动修复
        if ($Fix) {
            $result = Repair-JsonFile -FilePath $file.FullName -Result $result
        }

        $script:ValidationResults += $result

        # 显示结果
        Show-ValidationResult -Result $result
    }

    # 显示总结
    Write-Host ""
    Write-ValidationMessage "验证完成总结:" "Info"
    Write-ValidationMessage "总计文件: $($script:ValidationResults.Count)" "Info"
    Write-ValidationMessage "有效文件: $(@($script:ValidationResults | Where-Object { $_.IsValid }).Count)" "Success"

    $invalidFiles = @($script:ValidationResults | Where-Object { -not $_.IsValid })
    $invalidCount = $invalidFiles.Count
    if ($invalidCount -gt 0) {
        Write-ValidationMessage "无效文件: $invalidCount" "Error"
    }

    $warningFiles = @($script:ValidationResults | Where-Object { $_.Status -eq "Warning" })
    $warningCount = $warningFiles.Count
    if ($warningCount -gt 0) {
        Write-ValidationMessage "警告文件: $warningCount" "Warning"
    }

    $duration = (Get-Date) - $script:StartTime
    Write-ValidationMessage "总耗时: $($duration.TotalSeconds.ToString('F2'))秒" "Info"

    # 导出报告
    Export-ValidationReport

    # 返回退出码
    if ($invalidCount -gt 0) {
        return 1
    } elseif ($warningCount -gt 0) {
        return 2
    } else {
        return 0
    }
}

# 执行验证
try {
    $exitCode = Start-JsonValidation
    exit $exitCode
} catch {
    Write-ValidationMessage "验证过程发生致命错误: $($_.Exception.Message)" "Error"
    exit 1
}
