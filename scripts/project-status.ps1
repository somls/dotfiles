# project-status.ps1
# 项目状态检查脚本 - 优化版本
# 支持并行检查、缓存结果、详细报告

[CmdletBinding()]
param(
    [switch]$Detailed,
    [switch]$FixIssues,
    [switch]$ExportJson,
    [string]$ExportPath = "project-status.json",
    [switch]$Parallel,
    [switch]$Quiet,
    [ValidateSet("All", "Scripts", "Modules", "Configs", "Docs", "Tests")]
    [string]$Category = "All",
    [int]$TimeoutSeconds = 30
)

# 严格模式和错误处理
Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

# 全局变量
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:StartTime = Get-Date
$script:CheckResults = @{
    Scripts = @()
    Modules = @()
    Configs = @()
    Docs = @()
    Tests = @()
    Summary = @{}
}

# 结果类定义
class CheckResult {
    [string]$Category
    [string]$Name
    [string]$Status
    [string]$Message
    [string]$Details
    [string]$Suggestion
    [hashtable]$Metadata
    [timespan]$Duration

    CheckResult([string]$category, [string]$name, [string]$status, [string]$message) {
        $this.Category = $category
        $this.Name = $name
        $this.Status = $status
        $this.Message = $message
        $this.Details = ""
        $this.Suggestion = ""
        $this.Metadata = @{}
        $this.Duration = [timespan]::Zero
    }
}

# 性能计时器
function Start-Timer {
    return [System.Diagnostics.Stopwatch]::StartNew()
}

function Stop-Timer {
    param([System.Diagnostics.Stopwatch]$Timer)
    $Timer.Stop()
    return $Timer.Elapsed
}

# 输出函数
function Write-StatusMessage {
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

# 脚本检查函数
function Test-Scripts {
    param([switch]$UseJobs)

    Write-StatusMessage "检查核心脚本..." "Info"
    $timer = Start-Timer
    $results = @()

    $coreScripts = @(
        @{ Name = "install.ps1"; Required = $true; Critical = $true }
        @{ Name = "health-check.ps1"; Required = $true; Critical = $true }
        @{ Name = "detect-environment.ps1"; Required = $true; Critical = $false }
        @{ Name = "setup.ps1"; Required = $true; Critical = $false }
        @{ Name = "auto-sync.ps1"; Required = $false; Critical = $false }
        @{ Name = "cleanup-project.ps1"; Required = $false; Critical = $false }
    )

    $scriptJobs = @()

    foreach ($scriptInfo in $coreScripts) {
        $scriptPath = Join-Path $script:ProjectRoot $scriptInfo.Name

        if ($UseJobs) {
            $scriptJobs += Start-Job -ScriptBlock {
                param($Path, $Name, $Required, $Critical)

                $result = [PSCustomObject]@{
                    Name = $Name
                    Required = $Required
                    Critical = $Critical
                    Exists = Test-Path $Path
                    SyntaxValid = $false
                    Size = 0
                    LastModified = $null
                    Error = $null
                }

                if ($result.Exists) {
                    try {
                        $fileInfo = Get-Item $Path
                        $result.Size = $fileInfo.Length
                        $result.LastModified = $fileInfo.LastWriteTime

                        # 语法检查
                        $tokens = $errors = $null
                        [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
                        $result.SyntaxValid = ($errors.Count -eq 0)

                        if ($errors.Count -gt 0) {
                            $result.Error = $errors[0].Message
                        }
                    } catch {
                        $result.Error = $_.Exception.Message
                    }
                }

                return $result
            } -ArgumentList $scriptPath, $scriptInfo.Name, $scriptInfo.Required, $scriptInfo.Critical
        } else {
            # 同步检查
            $checkResult = [CheckResult]::new("Scripts", $scriptInfo.Name, "", "")
            $itemTimer = Start-Timer

            if (Test-Path $scriptPath) {
                try {
                    $fileInfo = Get-Item $scriptPath
                    $checkResult.Metadata.Size = $fileInfo.Length
                    $checkResult.Metadata.LastModified = $fileInfo.LastWriteTime

                    # 语法检查
                    $tokens = $errors = $null
                    [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)

                    if ($errors.Count -eq 0) {
                        $checkResult.Status = "Success"
                        $checkResult.Message = "语法正确 ($([math]::Round($fileInfo.Length/1KB, 1)) KB)"
                        Write-StatusMessage "  ✅ $($scriptInfo.Name) - 语法正确" "Success"
                    } else {
                        $checkResult.Status = "Error"
                        $checkResult.Message = "语法错误"
                        $checkResult.Details = $errors[0].Message
                        $checkResult.Suggestion = "检查脚本语法错误并修复"
                        Write-StatusMessage "  ❌ $($scriptInfo.Name) - 语法错误" "Error"

                        if ($Detailed) {
                            Write-StatusMessage "     错误: $($errors[0].Message)" "Error"
                        }
                    }
                } catch {
                    $checkResult.Status = "Error"
                    $checkResult.Message = "无法分析文件"
                    $checkResult.Details = $_.Exception.Message
                    Write-StatusMessage "  ❌ $($scriptInfo.Name) - 无法分析" "Error"
                }
            } else {
                $status = if ($scriptInfo.Required) { "Error" } else { "Warning" }
                $checkResult.Status = $status
                $checkResult.Message = "文件不存在"
                $checkResult.Suggestion = if ($scriptInfo.Required) { "创建必需的脚本文件" } else { "考虑添加此可选脚本" }

                $statusType = if ($scriptInfo.Required) { "Error" } else { "Warning" }
                Write-StatusMessage "  $(if ($scriptInfo.Required) { '❌' } else { '⚠️ ' }) $($scriptInfo.Name) - 文件不存在" $statusType
            }

            $checkResult.Duration = Stop-Timer $itemTimer
            $results += $checkResult
        }
    }

    if ($UseJobs) {
        # 等待并收集作业结果
        $scriptJobs | Wait-Job -Timeout $TimeoutSeconds | ForEach-Object {
            $jobResult = Receive-Job $_
            Remove-Job $_

            $checkResult = [CheckResult]::new("Scripts", $jobResult.Name, "", "")

            if ($jobResult.Exists) {
                if ($jobResult.SyntaxValid) {
                    $checkResult.Status = "Success"
                    $checkResult.Message = "语法正确 ($([math]::Round($jobResult.Size/1KB, 1)) KB)"
                    Write-StatusMessage "  ✅ $($jobResult.Name) - 语法正确" "Success"
                } else {
                    $checkResult.Status = "Error"
                    $checkResult.Message = "语法错误"
                    $checkResult.Details = $jobResult.Error
                    Write-StatusMessage "  ❌ $($jobResult.Name) - 语法错误" "Error"
                }
            } else {
                $status = if ($jobResult.Required) { "Error" } else { "Warning" }
                $checkResult.Status = $status
                $checkResult.Message = "文件不存在"

                $statusType = if ($jobResult.Required) { "Error" } else { "Warning" }
                Write-StatusMessage "  $(if ($jobResult.Required) { '❌' } else { '⚠️ ' }) $($jobResult.Name) - 文件不存在" $statusType
            }

            $results += $checkResult
        }

        # 清理超时的作业
        $scriptJobs | Where-Object { $_.State -eq "Running" } | ForEach-Object {
            Stop-Job $_
            Remove-Job $_
        }
    }

    $duration = Stop-Timer $timer
    $script:CheckResults.Scripts = $results

    Write-StatusMessage "脚本检查完成 (用时: $([math]::Round($duration.TotalSeconds, 2))s)" "Info"
    return $results
}

# 模块检查函数
function Test-Modules {
    Write-StatusMessage "检查PowerShell模块..." "Info"
    $timer = Start-Timer
    $results = @()

    $modulesPath = Join-Path $script:ProjectRoot "modules"
    if (-not (Test-Path $modulesPath)) {
        $checkResult = [CheckResult]::new("Modules", "ModulesDirectory", "Error", "模块目录不存在")
        $checkResult.Suggestion = "创建modules目录并添加PowerShell模块"
        $results += $checkResult
        Write-StatusMessage "  ❌ 模块目录不存在" "Error"
    } else {
        $modules = Get-ChildItem $modulesPath -Filter "*.psm1" -ErrorAction SilentlyContinue

        if ($modules.Count -eq 0) {
            $checkResult = [CheckResult]::new("Modules", "NoModules", "Warning", "未找到PowerShell模块")
            $checkResult.Suggestion = "考虑添加PowerShell模块以扩展功能"
            $results += $checkResult
            Write-StatusMessage "  ⚠️  未找到PowerShell模块" "Warning"
        } else {
            foreach ($module in $modules) {
                $checkResult = [CheckResult]::new("Modules", $module.Name, "", "")
                $itemTimer = Start-Timer

                try {
                    # 尝试导入模块
                    $originalModules = Get-Module
                    Import-Module $module.FullName -Force -ErrorAction Stop

                    # 获取导出的函数数量
                    $moduleInfo = Get-Module $module.BaseName
                    $exportedFunctions = if ($moduleInfo.ExportedFunctions) { $moduleInfo.ExportedFunctions.Count } else { 0 }

                    $checkResult.Status = "Success"
                    $checkResult.Message = "加载成功 ($exportedFunctions 个导出函数)"
                    $checkResult.Metadata.ExportedFunctions = $exportedFunctions
                    $checkResult.Metadata.Version = $moduleInfo.Version

                    Write-StatusMessage "  ✅ $($module.Name) - 加载成功 ($exportedFunctions 函数)" "Success"

                    # 清理导入的模块
                    Remove-Module $module.BaseName -ErrorAction SilentlyContinue
                } catch {
                    $checkResult.Status = "Warning"
                    $checkResult.Message = "加载警告"
                    $checkResult.Details = $_.Exception.Message
                    $checkResult.Suggestion = "检查模块语法和依赖项"

                    Write-StatusMessage "  ⚠️  $($module.Name) - 加载警告" "Warning"

                    if ($Detailed) {
                        Write-StatusMessage "     警告: $($_.Exception.Message)" "Warning"
                    }
                }

                $checkResult.Duration = Stop-Timer $itemTimer
                $results += $checkResult
            }
        }
    }

    $duration = Stop-Timer $timer
    $script:CheckResults.Modules = $results

    Write-StatusMessage "模块检查完成 (用时: $([math]::Round($duration.TotalSeconds, 2))s)" "Info"
    return $results
}

# 配置文件检查函数
function Test-Configs {
    Write-StatusMessage "检查配置文件..." "Info"
    $timer = Start-Timer
    $results = @()

    $configDirs = @{
        "powershell" = @{ Required = $true; Description = "PowerShell配置" }
        "git" = @{ Required = $true; Description = "Git配置" }
        "WindowsTerminal" = @{ Required = $false; Description = "Windows Terminal配置" }
        "Alacritty" = @{ Required = $false; Description = "Alacritty配置" }
        "starship" = @{ Required = $false; Description = "Starship配置" }
        "scoop" = @{ Required = $false; Description = "Scoop配置" }
        "config" = @{ Required = $true; Description = "项目配置" }
    }

    foreach ($dirName in $configDirs.Keys) {
        $dirInfo = $configDirs[$dirName]
        $dirPath = Join-Path $script:ProjectRoot $dirName
        $checkResult = [CheckResult]::new("Configs", $dirName, "", $dirInfo.Description)
        $itemTimer = Start-Timer

        if (Test-Path $dirPath) {
            $files = Get-ChildItem $dirPath -File -Recurse -ErrorAction SilentlyContinue
            $fileCount = $files.Count

            if ($fileCount -gt 0) {
                $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
                $checkResult.Status = "Success"
                $checkResult.Message = "$fileCount 个配置文件 ($([math]::Round($totalSize/1KB, 1)) KB)"
                $checkResult.Metadata.FileCount = $fileCount
                $checkResult.Metadata.TotalSize = $totalSize

                # 检查特殊文件类型
                $jsonFiles = $files | Where-Object { $_.Extension -eq ".json" }
                $tomlFiles = $files | Where-Object { $_.Extension -eq ".toml" }

                if ($jsonFiles) {
                    $validJson = 0
                    $invalidJson = 0

                    foreach ($jsonFile in $jsonFiles) {
                        try {
                            Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json | Out-Null
                            $validJson++
                        } catch {
                            $invalidJson++
                        }
                    }

                    $checkResult.Metadata.ValidJson = $validJson
                    $checkResult.Metadata.InvalidJson = $invalidJson

                    if ($invalidJson -gt 0) {
                        $checkResult.Status = "Warning"
                        $checkResult.Details += "包含 $invalidJson 个无效JSON文件"
                    }
                }

                Write-StatusMessage "  ✅ $dirName - $fileCount 个配置文件" "Success"
            } else {
                $status = if ($dirInfo.Required) { "Warning" } else { "Info" }
                $checkResult.Status = $status
                $checkResult.Message = "目录为空"
                $checkResult.Suggestion = "添加$($dirInfo.Description)文件"

                Write-StatusMessage "  ⚠️  $dirName - 目录为空" "Warning"
            }
        } else {
            $status = if ($dirInfo.Required) { "Error" } else { "Warning" }
            $checkResult.Status = $status
            $checkResult.Message = "目录不存在"
            $checkResult.Suggestion = if ($dirInfo.Required) { "创建必需的配置目录" } else { "考虑添加$($dirInfo.Description)" }

            $statusType = if ($dirInfo.Required) { "Error" } else { "Warning" }
            Write-StatusMessage "  $(if ($dirInfo.Required) { '❌' } else { '⚠️ ' }) $dirName - 目录不存在" $statusType
        }

        $checkResult.Duration = Stop-Timer $itemTimer
        $results += $checkResult
    }

    # 特别检查JSON配置文件
    $jsonFiles = Get-ChildItem $script:ProjectRoot -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
    $jsonCheckResult = [CheckResult]::new("Configs", "JsonValidation", "", "JSON格式验证")
    $jsonTimer = Start-Timer

    $validJson = 0
    $invalidJson = 0
    $jsonErrors = @()

    foreach ($jsonFile in $jsonFiles) {
        try {
            Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json | Out-Null
            $validJson++
        } catch {
            $invalidJson++
            $jsonErrors += @{
                File = $jsonFile.FullName
                Error = $_.Exception.Message
            }
        }
    }

    if ($invalidJson -eq 0) {
        $jsonCheckResult.Status = "Success"
        $jsonCheckResult.Message = "所有JSON文件格式正确 ($validJson 个文件)"
    } else {
        $jsonCheckResult.Status = "Error"
        $jsonCheckResult.Message = "$invalidJson 个JSON文件格式错误"
        $jsonCheckResult.Details = ($jsonErrors | ForEach-Object { "$($_.File): $($_.Error)" }) -join "; "
        $jsonCheckResult.Suggestion = "修复JSON格式错误"
    }

    $jsonCheckResult.Metadata.ValidJson = $validJson
    $jsonCheckResult.Metadata.InvalidJson = $invalidJson
    $jsonCheckResult.Duration = Stop-Timer $jsonTimer
    $results += $jsonCheckResult

    Write-StatusMessage "  📊 JSON文件: $validJson 有效, $invalidJson 无效" $(if ($invalidJson -eq 0) { "Success" } else { "Error" })

    $duration = Stop-Timer $timer
    $script:CheckResults.Configs = $results

    Write-StatusMessage "配置检查完成 (用时: $([math]::Round($duration.TotalSeconds, 2))s)" "Info"
    return $results
}

# 文档检查函数
function Test-Docs {
    Write-StatusMessage "检查项目文档..." "Info"
    $timer = Start-Timer
    $results = @()

    $docs = @{
        "README.md" = @{ Required = $true; MinSize = 1000; Description = "项目说明" }
        "CHANGELOG.md" = @{ Required = $true; MinSize = 100; Description = "变更日志" }
        "QUICKSTART.md" = @{ Required = $false; MinSize = 500; Description = "快速开始指南" }
        "TROUBLESHOOTING.md" = @{ Required = $false; MinSize = 300; Description = "故障排除" }
        "SECURITY.md" = @{ Required = $false; MinSize = 200; Description = "安全指南" }
        "PROJECT_STRUCTURE.md" = @{ Required = $false; MinSize = 300; Description = "项目结构说明" }
        "QUICK_REFERENCE.md" = @{ Required = $false; MinSize = 200; Description = "快速参考" }
    }

    foreach ($docName in $docs.Keys) {
        $docInfo = $docs[$docName]
        $docPath = Join-Path $script:ProjectRoot $docName
        $checkResult = [CheckResult]::new("Docs", $docName, "", $docInfo.Description)
        $itemTimer = Start-Timer

        if (Test-Path $docPath) {
            $fileInfo = Get-Item $docPath
            $size = $fileInfo.Length
            $sizeKB = [math]::Round($size / 1KB, 1)

            $checkResult.Metadata.Size = $size
            $checkResult.Metadata.LastModified = $fileInfo.LastWriteTime

            if ($size -ge $docInfo.MinSize) {
                $checkResult.Status = "Success"
                $checkResult.Message = "文档完整 ($sizeKB KB)"
                Write-StatusMessage "  ✅ $docName - $sizeKB KB" "Success"

                # 检查基本内容结构
                try {
                    $content = Get-Content $docPath -Raw -ErrorAction SilentlyContinue
                    if ($content) {
                        $headers = ([regex]'#{1,6}\s+(.+)').Matches($content)
                        $checkResult.Metadata.HeaderCount = $headers.Count

                        if ($headers.Count -eq 0) {
                            $checkResult.Status = "Warning"
                            $checkResult.Details = "缺少Markdown标题结构"
                        }
                    }
                } catch {
                    # 忽略内容分析错误
                }
            } else {
                $checkResult.Status = "Warning"
                $checkResult.Message = "文档过小 ($sizeKB KB)"
                $checkResult.Suggestion = "扩展文档内容以提供更完整的信息"
                Write-StatusMessage "  ⚠️  $docName - 文档过小 ($sizeKB KB)" "Warning"
            }
        } else {
            $status = if ($docInfo.Required) { "Error" } else { "Warning" }
            $checkResult.Status = $status
            $checkResult.Message = "文档不存在"
            $checkResult.Suggestion = if ($docInfo.Required) { "创建必需的项目文档" } else { "考虑添加$($docInfo.Description)" }

            $statusType = if ($docInfo.Required) { "Error" } else { "Warning" }
            Write-StatusMessage "  $(if ($docInfo.Required) { '❌' } else { '⚠️ ' }) $docName - 文档不存在" $statusType
        }

        $checkResult.Duration = Stop-Timer $itemTimer
        $results += $checkResult
    }

    $duration = Stop-Timer $timer
    $script:CheckResults.Docs = $results

    Write-StatusMessage "文档检查完成 (用时: $([math]::Round($duration.TotalSeconds, 2))s)" "Info"
    return $results
}

# 测试文件检查函数
function Test-TestFiles {
    Write-StatusMessage "检查测试文件..." "Info"
    $timer = Start-Timer
    $results = @()

    $testDirs = @("tests", "scripts")
    $testFiles = @()

    foreach ($dir in $testDirs) {
        $dirPath = Join-Path $script:ProjectRoot $dir
        if (Test-Path $dirPath) {
            $tests = Get-ChildItem $dirPath -Filter "*test*.ps1" -Recurse -ErrorAction SilentlyContinue
            $testFiles += $tests
        }
    }

    $checkResult = [CheckResult]::new("Tests", "TestFiles", "", "测试文件覆盖度")
    $itemTimer = Start-Timer

    if ($testFiles.Count -gt 0) {
        $totalSize = ($testFiles | Measure-Object -Property Length -Sum).Sum
        $checkResult.Status = "Success"
        $checkResult.Message = "找到 $($testFiles.Count) 个测试文件 ($([math]::Round($totalSize/1KB, 1)) KB)"
        $checkResult.Metadata.TestFileCount = $testFiles.Count
        $checkResult.Metadata.TotalSize = $totalSize

        Write-StatusMessage "  ✅ 找到 $($testFiles.Count) 个测试文件" "Success"

        if ($Detailed) {
            foreach ($test in $testFiles | Select-Object -First 5) {
                Write-StatusMessage "    • $($test.Name)" "Info"
            }
            if ($testFiles.Count -gt 5) {
                Write-StatusMessage "    ... 以及其他 $($testFiles.Count - 5) 个文件" "Info"
            }
        }

        # 检查测试文件的实际内容
        $validTests = 0
        $emptyTests = 0

        foreach ($testFile in $testFiles) {
            try {
                $content = Get-Content $testFile.FullName -Raw -ErrorAction SilentlyContinue
                if ($content -and $content.Length -gt 100) {
                    $validTests++
                } else {
                    $emptyTests++
                }
            } catch {
                $emptyTests++
            }
        }

        $checkResult.Metadata.ValidTests = $validTests
        $checkResult.Metadata.EmptyTests = $emptyTests

        if ($emptyTests -gt 0) {
            $checkResult.Status = "Warning"
            $checkResult.Details = "$emptyTests 个测试文件可能为空或过小"
        }
    } else {
        $checkResult.Status = "Warning"
        $checkResult.Message = "未找到测试文件"
        $checkResult.Suggestion = "添加单元测试和集成测试以确保代码质量"
        Write-StatusMessage "  ⚠️  未找到测试文件" "Warning"
    }

    $checkResult.Duration = Stop-Timer $itemTimer
    $results += $checkResult

    $duration = Stop-Timer $timer
    $script:CheckResults.Tests = $results

    Write-StatusMessage "测试检查完成 (用时: $([math]::Round($duration.TotalSeconds, 2))s)" "Info"
    return $results
}

# 计算健康度分数
function Get-HealthScore {
    $allResults = @()
    $allResults += $script:CheckResults.Scripts
    $allResults += $script:CheckResults.Modules
    $allResults += $script:CheckResults.Configs
    $allResults += $script:CheckResults.Docs
    $allResults += $script:CheckResults.Tests

    if ($allResults.Count -eq 0) {
        return @{
            Score = 0
            Grade = "F"
            Successes = 0
            Warnings = 0
            Errors = 0
            Total = 0
        }
    }

    $successes = ($allResults | Where-Object { $_.Status -eq "Success" }).Count
    $warnings = ($allResults | Where-Object { $_.Status -eq "Warning" }).Count
    $errors = ($allResults | Where-Object { $_.Status -eq "Error" }).Count

    $score = [math]::Round((($successes + $warnings * 0.5) / $allResults.Count) * 100, 1)

    $grade = switch ($score) {
        { $_ -ge 95 } { "A+" }
        { $_ -ge 90 } { "A" }
        { $_ -ge 85 } { "A-" }
        { $_ -ge 80 } { "B+" }
        { $_ -ge 75 } { "B" }
        { $_ -ge 70 } { "B-" }
        { $_ -ge 65 } { "C+" }
        { $_ -ge 60 } { "C" }
        { $_ -ge 55 } { "C-" }
        { $_ -ge 50 } { "D" }
        default { "F" }
    }

    return @{
        Score = $score
        Grade = $grade
        Successes = $successes
        Warnings = $warnings
        Errors = $errors
        Total = $allResults.Count
    }
}

# 生成建议
function Get-Recommendations {
    $recommendations = @()
    $healthScore = Get-HealthScore

    # 基于健康度的建议
    if ($healthScore.Score -lt 70) {
        $recommendations += "项目健康度较低，建议优先修复错误项目"
        $recommendations += "运行 .\health-check.ps1 -Fix 进行自动修复"
    }

    if ($healthScore.Errors -gt 0) {
        $recommendations += "修复所有错误项目以提高项目稳定性"
    }

    if ($healthScore.Warnings -gt 3) {
        $recommendations += "处理警告项目以改善项目质量"
    }

    # 基于特定检查结果的建议
    $testResults = $script:CheckResults.Tests
    if ($testResults -and ($testResults | Where-Object { $_.Status -ne "Success" })) {
        $recommendations += "增加测试覆盖度以确保代码质量"
        $recommendations += "运行 .\scripts\Run-AllTests.ps1 执行完整测试"
    }

    $docResults = $script:CheckResults.Docs
    $missingDocs = $docResults | Where-Object { $_.Status -eq "Error" }
    if ($missingDocs) {
        $recommendations += "完善项目文档，特别是缺失的必需文档"
    }

    $configResults = $script:CheckResults.Configs
    $invalidConfigs = $configResults | Where-Object { $_.Status -eq "Error" -and $_.Name -eq "JsonValidation" }
    if ($invalidConfigs) {
        $recommendations += "修复JSON配置文件格式错误"
        $recommendations += "运行 .\scripts\Validate-JsonConfigs.ps1 进行详细验证"
    }

    return $recommendations
}

# 显示摘要报告
function Show-Summary {
    if ($Quiet) { return }

    $healthScore = Get-HealthScore
    $totalDuration = (Get-Date) - $script:StartTime

    Write-Host ""
    Write-StatusMessage "📊 项目状态总结" "Info"
    Write-StatusMessage "===============" "Info"
    Write-Host ""

    Write-StatusMessage "✅ 成功项目: $($healthScore.Successes)" "Success"
    Write-StatusMessage "⚠️  警告项目: $($healthScore.Warnings)" "Warning"
    Write-StatusMessage "❌ 错误项目: $($healthScore.Errors)" "Error"
    Write-Host ""

    # 健康度显示
    $healthColor = switch ($healthScore.Score) {
        { $_ -ge 90 } { "Success" }
        { $_ -ge 70 } { "Warning" }
        default { "Error" }
    }
    Write-StatusMessage "🏥 项目健康度: $($healthScore.Score)% (等级: $($healthScore.Grade))" $healthColor
    Write-StatusMessage "⏱️  检查用时: $([math]::Round($totalDuration.TotalSeconds, 2))秒" "Info"
    Write-Host ""

    # 显示详细问题
    $errorResults = @()
    $warningResults = @()

    foreach ($category in @("Scripts", "Modules", "Configs", "Docs", "Tests")) {
        $categoryResults = $script:CheckResults[$category]
        $errorResults += $categoryResults | Where-Object { $_.Status -eq "Error" }
        $warningResults += $categoryResults | Where-Object { $_.Status -eq "Warning" }
    }

    if ($errorResults.Count -gt 0) {
        Write-StatusMessage "❌ 需要修复的错误:" "Error"
        foreach ($result in $errorResults) {
            Write-StatusMessage "  • [$($result.Category)] $($result.Name): $($result.Message)" "Error"
            if ($Detailed -and $result.Suggestion) {
                Write-StatusMessage "    建议: $($result.Suggestion)" "Info"
            }
        }
        Write-Host ""
    }

    if ($warningResults.Count -gt 0 -and ($Detailed -or $warningResults.Count -le 5)) {
        Write-StatusMessage "⚠️  需要注意的警告:" "Warning"
        foreach ($result in $warningResults | Select-Object -First 5) {
            Write-StatusMessage "  • [$($result.Category)] $($result.Name): $($result.Message)" "Warning"
        }
        if ($warningResults.Count -gt 5) {
            Write-StatusMessage "  ... 以及其他 $($warningResults.Count - 5) 个警告" "Warning"
        }
        Write-Host ""
    }

    # 显示建议
    $recommendations = Get-Recommendations
    if ($recommendations.Count -gt 0) {
        Write-StatusMessage "💡 改进建议:" "Info"
        foreach ($rec in $recommendations) {
            Write-StatusMessage "  • $rec" "Info"
        }
        Write-Host ""
    }

    # 保存结果到全局变量供其他脚本使用
    $script:CheckResults.Summary = @{
        HealthScore = $healthScore
        Duration = $totalDuration
        Recommendations = $recommendations
        Timestamp = Get-Date
    }
}

# 导出JSON报告
function Export-JsonReport {
    param([string]$Path)

    $report = @{
        timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        version = "2.0.0"
        summary = $script:CheckResults.Summary
        results = @{
            scripts = $script:CheckResults.Scripts
            modules = $script:CheckResults.Modules
            configs = $script:CheckResults.Configs
            docs = $script:CheckResults.Docs
            tests = $script:CheckResults.Tests
        }
        environment = @{
            computerName = $env:COMPUTERNAME
            userName = $env:USERNAME
            powershellVersion = $PSVersionTable.PSVersion.ToString()
            osVersion = [System.Environment]::OSVersion.VersionString
        }
    }

    try {
        $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $Path -Encoding UTF8
        Write-StatusMessage "📄 报告已导出到: $Path" "Success"
    } catch {
        Write-StatusMessage "❌ 导出报告失败: $($_.Exception.Message)" "Error"
    }
}

# 自动修复功能
function Invoke-AutoFix {
    if (-not $FixIssues) { return }

    Write-StatusMessage "🔧 开始自动修复..." "Info"
    $fixCount = 0

    # 修复缺失的目录
    $configErrors = $script:CheckResults.Configs | Where-Object { $_.Status -eq "Error" -and $_.Message -eq "目录不存在" }
    foreach ($result in $configErrors) {
        $dirPath = Join-Path $script:ProjectRoot $result.Name
        try {
            New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
            Write-StatusMessage "  ✅ 创建目录: $($result.Name)" "Success"
            $fixCount++
        } catch {
            Write-StatusMessage "  ❌ 无法创建目录: $($result.Name)" "Error"
        }
    }

    # 修复JSON格式错误（基础修复）
    $jsonErrors = $script:CheckResults.Configs | Where-Object { $_.Status -eq "Error" -and $_.Name -eq "JsonValidation" }
    if ($jsonErrors -and $jsonErrors.Metadata.InvalidJson -gt 0) {
        Write-StatusMessage "  ℹ️  发现JSON格式错误，建议手动修复或运行 .\scripts\Validate-JsonConfigs.ps1" "Info"
    }

    if ($fixCount -gt 0) {
        Write-StatusMessage "🎉 自动修复完成，修复了 $fixCount 个问题" "Success"
        Write-StatusMessage "建议重新运行检查以验证修复结果" "Info"
    } else {
        Write-StatusMessage "ℹ️  没有找到可自动修复的问题" "Info"
    }
}

# 主执行函数
function Invoke-ProjectStatusCheck {
    # 显示标题
    if (-not $Quiet) {
        Write-Host ""
        Write-StatusMessage "🔍 DOTFILES 项目状态检查 v2.0" "Info"
        Write-StatusMessage "================================" "Info"
        Write-Host ""
    }

    try {
        # 根据类别参数决定执行哪些检查
        switch ($Category) {
            "Scripts" { Test-Scripts -UseJobs:$Parallel }
            "Modules" { Test-Modules }
            "Configs" { Test-Configs }
            "Docs" { Test-Docs }
            "Tests" { Test-TestFiles }
            "All" {
                Test-Scripts -UseJobs:$Parallel
                if (-not $Quiet) { Write-Host "" }
                Test-Modules
                if (-not $Quiet) { Write-Host "" }
                Test-Configs
                if (-not $Quiet) { Write-Host "" }
                Test-Docs
                if (-not $Quiet) { Write-Host "" }
                Test-TestFiles
            }
        }

        # 显示摘要
        Show-Summary

        # 自动修复
        if ($FixIssues) {
            Write-Host ""
            Invoke-AutoFix
        }

        # 导出JSON报告
        if ($ExportJson) {
            Write-Host ""
            Export-JsonReport -Path $ExportPath
        }

        # 返回健康度分数用于脚本退出码
        $healthScore = Get-HealthScore
        return $healthScore

    } catch {
        Write-StatusMessage "❌ 检查过程中发生错误: $($_.Exception.Message)" "Error"
        if ($Detailed) {
            Write-StatusMessage "错误详情: $($_.Exception.StackTrace)" "Error"
        }
        return @{ Score = 0; Errors = 1 }
    }
}

# 主执行逻辑
if ($MyInvocation.InvocationName -ne '.') {
    # 验证参数
    if ($TimeoutSeconds -lt 5 -or $TimeoutSeconds -gt 300) {
        Write-Error "超时时间必须在5-300秒之间"
        exit 1
    }

    if ($ExportJson -and -not $ExportPath) {
        $ExportPath = "project-status-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    }

    # 执行检查
    $result = Invoke-ProjectStatusCheck

    # 设置退出代码
    $exitCode = if ($result.Errors -gt 0) {
        1
    } elseif ($result.Warnings -gt 0) {
        2
    } else {
        0
    }

    exit $exitCode
}
