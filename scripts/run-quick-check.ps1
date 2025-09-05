# run-quick-check.ps1
# 快速检查脚本 - 优化版本，支持缓存和并行执行
# 专为快速验证项目状态而设计

[CmdletBinding()]
param(
    [switch]$UseCache,
    [int]$CacheExpiryMinutes = 30,
    [switch]$Parallel,
    [switch]$Quiet,
    [switch]$Fix,
    [ValidateSet("Critical", "Standard", "Full")]
    [string]$Level = "Standard",
    [switch]$ExportResults,
    [string]$ExportPath = "quick-check-results.json"
)

# 严格模式
Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

# 全局变量
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:CacheFile = Join-Path $script:ProjectRoot ".quick-check-cache.json"
$script:StartTime = Get-Date
$script:CheckResults = @{
    Core = @()
    Files = @()
    Config = @()
    Performance = @{}
    Summary = @{}
}

# 快速检查结果类
class QuickCheckResult {
    [string]$Category
    [string]$Item
    [string]$Status
    [string]$Message
    [timespan]$Duration
    [bool]$Cached
    [hashtable]$Metadata

    QuickCheckResult([string]$category, [string]$item) {
        $this.Category = $category
        $this.Item = $item
        $this.Status = "Unknown"
        $this.Message = ""
        $this.Duration = [timespan]::Zero
        $this.Cached = $false
        $this.Metadata = @{}
    }
}

# 输出函数
function Write-QuickMessage {
    param(
        [string]$Message,
        [string]$Type = "Info",
        [switch]$NoTimestamp
    )

    if ($Quiet -and $Type -eq "Info") { return }

    $color = switch ($Type) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Info" { "Cyan" }
        default { "White" }
    }

    $prefix = switch ($Type) {
        "Success" { "✓" }
        "Warning" { "!" }
        "Error" { "✗" }
        "Info" { "·" }
        default { "·" }
    }

    $timestamp = if ($NoTimestamp) { "" } else { "[$(Get-Date -Format 'HH:mm:ss')] " }
    Write-Host "$timestamp$prefix $Message" -ForegroundColor $color
}

# 缓存管理
function Get-CachedResult {
    param([string]$Key)

    if (-not $UseCache -or -not (Test-Path $script:CacheFile)) {
        return $null
    }

    try {
        $cache = Get-Content $script:CacheFile -Raw | ConvertFrom-Json -AsHashtable
        if ($cache.ContainsKey($Key)) {
            $cachedItem = $cache[$Key]
            $cacheTime = [DateTime]::Parse($cachedItem.Timestamp)
            $expiryTime = $cacheTime.AddMinutes($CacheExpiryMinutes)

            if ((Get-Date) -lt $expiryTime) {
                return $cachedItem.Result
            }
        }
    } catch {
        # 缓存文件损坏，忽略
    }

    return $null
}

function Set-CachedResult {
    param([string]$Key, [object]$Result)

    if (-not $UseCache) { return }

    try {
        $cache = @{}
        if (Test-Path $script:CacheFile) {
            $cache = Get-Content $script:CacheFile -Raw | ConvertFrom-Json -AsHashtable
        }

        $cache[$Key] = @{
            Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
            Result = $Result
        }

        $cache | ConvertTo-Json -Depth 5 | Out-File $script:CacheFile -Encoding UTF8
    } catch {
        # 缓存失败不影响主流程
    }
}

# 核心文件检查
function Test-CoreFiles {
    $results = @()
    $coreFiles = @{
        "install.ps1" = @{ Critical = $true; Description = "主安装脚本" }
        "health-check.ps1" = @{ Critical = $true; Description = "健康检查脚本" }
        "setup.ps1" = @{ Critical = $false; Description = "设置脚本" }
        "README.md" = @{ Critical = $true; Description = "项目文档" }
        "config\install.json" = @{ Critical = $true; Description = "安装配置" }
    }

    $checkFunctions = @()

    foreach ($file in $coreFiles.Keys) {
        $checkFunctions += {
            param($FileName, $FileInfo, $ProjectRoot, $UseCache)

            $result = [QuickCheckResult]::new("Core", $FileName)
            $timer = [System.Diagnostics.Stopwatch]::StartNew()

            # 检查缓存
            $cacheKey = "core_$FileName"
            $cached = $null
            if ($UseCache) {
                # 简化缓存检查（在并行作业中）
                $cacheFile = Join-Path $ProjectRoot ".quick-check-cache.json"
                if (Test-Path $cacheFile) {
                    try {
                        $cache = Get-Content $cacheFile -Raw | ConvertFrom-Json -AsHashtable
                        if ($cache.ContainsKey($cacheKey)) {
                            $cachedItem = $cache[$cacheKey]
                            $cacheTime = [DateTime]::Parse($cachedItem.Timestamp)
                            if ((Get-Date) -lt $cacheTime.AddMinutes(30)) {
                                $cached = $cachedItem.Result
                            }
                        }
                    } catch { }
                }
            }

            if ($cached) {
                $result.Status = $cached.Status
                $result.Message = "$($cached.Message) (缓存)"
                $result.Cached = $true
                $result.Metadata = $cached.Metadata
            } else {
                $filePath = Join-Path $ProjectRoot $FileName

                if (Test-Path $filePath) {
                    $fileItem = Get-Item $filePath
                    $result.Status = "Success"
                    $result.Message = "存在 ($([math]::Round($fileItem.Length/1KB, 1)) KB)"
                    $result.Metadata.Size = $fileItem.Length
                    $result.Metadata.LastModified = $fileItem.LastWriteTime

                    # 对脚本文件进行快速语法检查
                    if ($filePath.EndsWith('.ps1')) {
                        try {
                            $tokens = $errors = $null
                            [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$tokens, [ref]$errors)
                            if ($errors -and $errors.Count -gt 0) {
                                $result.Status = "Warning"
                                $result.Message += " (语法警告)"
                            }
                        } catch {
                            $result.Status = "Warning"
                            $result.Message += " (无法验证语法)"
                        }
                    }
                } else {
                    $result.Status = if ($FileInfo.Critical) { "Error" } else { "Warning" }
                    $result.Message = "文件缺失"
                }
            }

            $timer.Stop()
            $result.Duration = $timer.Elapsed
            return $result
        }.GetNewClosure()
    }

    if ($Parallel -and $coreFiles -and $coreFiles.Count -gt 2) {
        Write-QuickMessage "并行检查核心文件..." "Info"

        $jobs = @()
        foreach ($file in $coreFiles.Keys) {
            $fileInfo = $coreFiles[$file]
            $jobs += Start-Job -ScriptBlock $checkFunctions[0] -ArgumentList $file, $fileInfo, $script:ProjectRoot, $UseCache
        }

        $jobs | Wait-Job | ForEach-Object {
            $result = Receive-Job $_
            $results += $result
            Remove-Job $_
        }
    } else {
        Write-QuickMessage "检查核心文件..." "Info"

        foreach ($file in $coreFiles.Keys) {
            $fileInfo = $coreFiles[$file]
            $result = [QuickCheckResult]::new("Core", $file)
            $timer = [System.Diagnostics.Stopwatch]::StartNew()

            # 检查缓存
            $cacheKey = "core_$file"
            $cached = Get-CachedResult -Key $cacheKey

            if ($cached) {
                $result.Status = $cached.Status
                $result.Message = "$($cached.Message) (缓存)"
                $result.Cached = $true
                $result.Metadata = $cached.Metadata
            } else {
                $filePath = Join-Path $script:ProjectRoot $file

                if (Test-Path $filePath) {
                    $fileItem = Get-Item $filePath
                    $result.Status = "Success"
                    $result.Message = "存在 ($([math]::Round($fileItem.Length/1KB, 1)) KB)"
                    $result.Metadata.Size = $fileItem.Length
                    $result.Metadata.LastModified = $fileItem.LastWriteTime

                    # 快速语法检查（仅对PowerShell脚本）
                    if ($filePath.EndsWith('.ps1') -and $Level -ne "Critical") {
                        try {
                            $tokens = $errors = $null
                            [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$tokens, [ref]$errors)
                            if ($errors -and $errors.Count -gt 0) {
                                $result.Status = "Warning"
                                $result.Message += " (语法警告)"
                                $result.Metadata.SyntaxErrors = $errors.Count
                            }
                        } catch {
                            $result.Status = "Warning"
                            $result.Message += " (无法验证语法)"
                        }
                    }

                    # 缓存成功结果
                    Set-CachedResult -Key $cacheKey -Result @{
                        Status = $result.Status
                        Message = $result.Message
                        Metadata = $result.Metadata
                    }
                } else {
                    $result.Status = if ($fileInfo.Critical) { "Error" } else { "Warning" }
                    $result.Message = "文件缺失"
                }
            }

            $timer.Stop()
            $result.Duration = $timer.Elapsed
            $results += $result
        }
    }

    $script:CheckResults.Core = $results
    return $results
}

# 配置文件检查
function Test-ConfigFiles {
    $results = @()

    Write-QuickMessage "检查配置文件..." "Info"

    $configDirs = @{
        "config" = @{ Required = $true; Description = "项目配置" }
        "powershell" = @{ Required = $true; Description = "PowerShell配置" }
        "git" = @{ Required = $true; Description = "Git配置" }
    }

    if ($Level -eq "Full") {
        $configDirs += @{
            "WindowsTerminal" = @{ Required = $false; Description = "Windows Terminal" }
            "starship" = @{ Required = $false; Description = "Starship提示符" }
        }
    }

    foreach ($dir in $configDirs.Keys) {
        $dirInfo = $configDirs[$dir]
        $result = [QuickCheckResult]::new("Config", $dir)
        $timer = [System.Diagnostics.Stopwatch]::StartNew()

        # 检查缓存
        $cacheKey = "config_$dir"
        $cached = Get-CachedResult -Key $cacheKey

        if ($cached) {
            $result.Status = $cached.Status
            $result.Message = "$($cached.Message) (缓存)"
            $result.Cached = $true
            $result.Metadata = $cached.Metadata
        } else {
            $dirPath = Join-Path $script:ProjectRoot $dir

            if (Test-Path $dirPath) {
                $files = @(Get-ChildItem $dirPath -File -Recurse -ErrorAction SilentlyContinue)
                $fileCount = $files.Count

                if ($fileCount -gt 0) {
                    $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
                    $result.Status = "Success"
                    $result.Message = "$fileCount 文件 ($([math]::Round($totalSize/1KB, 1)) KB)"
                    $result.Metadata.FileCount = $fileCount
                    $result.Metadata.TotalSize = $totalSize

                    # JSON文件快速验证（仅在非Critical级别）
                    if ($Level -ne "Critical") {
                        $jsonFiles = $files | Where-Object { $_.Extension -eq ".json" }
                        if ($jsonFiles) {
                            $invalidJson = 0
                            foreach ($jsonFile in $jsonFiles | Select-Object -First 3) {
                                try {
                                    Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json | Out-Null
                                } catch {
                                    $invalidJson++
                                }
                            }
                            if ($invalidJson -gt 0) {
                                $result.Status = "Warning"
                                $result.Message += " ($invalidJson JSON错误)"
                            }
                        }
                    }
                } else {
                    $result.Status = if ($dirInfo.Required) { "Warning" } else { "Info" }
                    $result.Message = "目录为空"
                }

                # 缓存结果
                Set-CachedResult -Key $cacheKey -Result @{
                    Status = $result.Status
                    Message = $result.Message
                    Metadata = $result.Metadata
                }
            } else {
                $result.Status = if ($dirInfo.Required) { "Error" } else { "Warning" }
                $result.Message = "目录不存在"
            }
        }

        $timer.Stop()
        $result.Duration = $timer.Elapsed
        $results += $result
    }

    $script:CheckResults.Config = $results
    return $results
}

# 模块和脚本检查
function Test-ModulesAndScripts {
    $results = @()

    Write-QuickMessage "检查模块和脚本..." "Info"

    # 检查modules目录
    $modulesResult = [QuickCheckResult]::new("Files", "modules")
    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    $modulesPath = Join-Path $script:ProjectRoot "modules"
    if (Test-Path $modulesPath) {
        $modules = @(Get-ChildItem $modulesPath -Filter "*.psm1" -ErrorAction SilentlyContinue)
        if ($modules.Count -gt 0) {
            $modulesResult.Status = "Success"
            $modulesResult.Message = "$($modules.Count) 模块"
            $modulesResult.Metadata.ModuleCount = $modules.Count
        } else {
            $modulesResult.Status = "Warning"
            $modulesResult.Message = "无PowerShell模块"
        }
    } else {
        $modulesResult.Status = "Warning"
        $modulesResult.Message = "modules目录不存在"
    }

    $timer.Stop()
    $modulesResult.Duration = $timer.Elapsed
    $results += $modulesResult

    # 检查scripts目录（仅在Standard和Full级别）
    if ($Level -ne "Critical") {
        $scriptsResult = [QuickCheckResult]::new("Files", "scripts")
        $timer = [System.Diagnostics.Stopwatch]::StartNew()

        $scriptsPath = Join-Path $script:ProjectRoot "scripts"
        if (Test-Path $scriptsPath) {
            $scripts = @(Get-ChildItem $scriptsPath -Filter "*.ps1" -ErrorAction SilentlyContinue)
            $scriptsResult.Status = "Success"
            $scriptsResult.Message = "$($scripts.Count) 脚本"
            $scriptsResult.Metadata.ScriptCount = $scripts.Count
        } else {
            $scriptsResult.Status = "Info"
            $scriptsResult.Message = "scripts目录不存在"
        }

        $timer.Stop()
        $scriptsResult.Duration = $timer.Elapsed
        $results += $scriptsResult
    }

    $script:CheckResults.Files = $results
    return $results
}

# 性能度量
function Measure-Performance {
    $perfData = @{
        StartTime = $script:StartTime
        EndTime = Get-Date
        TotalDuration = (Get-Date) - $script:StartTime
        CheckCount = 0
        CacheHits = 0
        ParallelExecution = $Parallel
    }

    # 统计检查项目数
    $allResults = @()
    $allResults += $script:CheckResults.Core
    $allResults += $script:CheckResults.Files
    $allResults += $script:CheckResults.Config

    $perfData.CheckCount = @($allResults).Count
    $perfData.CacheHits = @($allResults | Where-Object { $_.Cached }).Count
    $perfData.AverageCheckTime = if (@($allResults).Count -gt 0) {
        [math]::Round(($allResults | ForEach-Object { $_.Duration.TotalMilliseconds } | Measure-Object -Average).Average, 2)
    } else { 0 }

    $script:CheckResults.Performance = $perfData
    return $perfData
}

# 简单的自动修复
function Invoke-QuickFix {
    if (-not $Fix) { return }

    Write-QuickMessage "尝试快速修复..." "Info"
    $fixCount = 0

    # 修复缺失的目录
    $missingDirs = $script:CheckResults.Config | Where-Object { $_.Status -eq "Error" -and $_.Message -eq "目录不存在" }
    foreach ($result in $missingDirs) {
        try {
            $dirPath = Join-Path $script:ProjectRoot $result.Item
            New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
            Write-QuickMessage "  ✓ 创建目录: $($result.Item)" "Success"
            $fixCount++
        } catch {
            Write-QuickMessage "  ✗ 无法创建目录: $($result.Item)" "Error"
        }
    }

    if ($fixCount -gt 0) {
        Write-QuickMessage "快速修复完成: $fixCount 项修复" "Success"
    } else {
        Write-QuickMessage "没有可自动修复的问题" "Info"
    }
}

# 显示结果
function Show-QuickResults {
    param([array]$AllResults)

    $summary = @{
        Total = @($AllResults).Count
        Success = @($AllResults | Where-Object { $_.Status -eq "Success" }).Count
        Warnings = @($AllResults | Where-Object { $_.Status -eq "Warning" }).Count
        Errors = @($AllResults | Where-Object { $_.Status -eq "Error" }).Count
        Cached = @($AllResults | Where-Object { $_.Cached }).Count
    }

    Write-Host ""
    Write-QuickMessage "快速检查结果:" "Info" -NoTimestamp
    Write-QuickMessage "===============" "Info" -NoTimestamp

    # 按类别显示结果
    $categories = $AllResults | Group-Object Category
    foreach ($category in $categories) {
        Write-Host ""
        Write-QuickMessage "$($category.Name):" "Info" -NoTimestamp

        foreach ($result in $category.Group) {
            $icon = switch ($result.Status) {
                "Success" { "✓" }
                "Warning" { "!" }
                "Error" { "✗" }
                default { "·" }
            }

            $color = switch ($result.Status) {
                "Success" { "Green" }
                "Warning" { "Yellow" }
                "Error" { "Red" }
                default { "White" }
            }

            $cacheIndicator = if ($result.Cached) { " (缓存)" } else { "" }
            $duration = if ($result.Duration.TotalMilliseconds -gt 10) {
                " ($([math]::Round($result.Duration.TotalMilliseconds, 0))ms)"
            } else { "" }

            Write-Host "  $icon $($result.Item): $($result.Message)$cacheIndicator$duration" -ForegroundColor $color
        }
    }

    Write-Host ""
    Write-QuickMessage "总结:" "Info" -NoTimestamp
    Write-QuickMessage "✓ 成功: $($summary.Success)  ! 警告: $($summary.Warnings)  ✗ 错误: $($summary.Errors)" "Info" -NoTimestamp

    if ($UseCache -and $summary.Cached -gt 0) {
        Write-QuickMessage "📋 缓存命中: $($summary.Cached)/$($summary.Total)" "Info" -NoTimestamp
    }

    $perfData = $script:CheckResults.Performance
    if ($perfData) {
        Write-QuickMessage "⏱️  总用时: $([math]::Round($perfData.TotalDuration.TotalSeconds, 2))秒 (平均: $($perfData.AverageCheckTime)ms)" "Info" -NoTimestamp
    }

    # 健康度评分
    $healthScore = if ($summary.Total -gt 0) {
        [math]::Round((($summary.Success + $summary.Warnings * 0.5) / $summary.Total) * 100, 1)
    } else { 100 }

    $healthColor = if ($healthScore -eq 100) { "Success" } elseif ($healthScore -ge 80) { "Warning" } else { "Error" }
    Write-QuickMessage "🏥 项目健康度: $healthScore%" $healthColor -NoTimestamp

    $script:CheckResults.Summary = $summary
    $script:CheckResults.Summary.HealthScore = $healthScore

    return $summary
}

# 导出结果
function Export-QuickResults {
    if (-not $ExportResults) { return }

    $exportData = @{
        timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
        version = "1.0.0"
        level = $Level
        useCache = $UseCache
        parallel = $Parallel
        results = $script:CheckResults
        summary = $script:CheckResults.Summary
        performance = $script:CheckResults.Performance
    }

    try {
        $exportData | ConvertTo-Json -Depth 5 | Out-File $ExportPath -Encoding UTF8
        Write-QuickMessage "结果已导出: $ExportPath" "Success"
    } catch {
        Write-QuickMessage "导出失败: $($_.Exception.Message)" "Error"
    }
}

# 主执行函数
function Invoke-QuickCheck {
    Write-QuickMessage "🚀 启动快速检查 (级别: $Level)" "Info"

    if ($UseCache) {
        Write-QuickMessage "📋 使用缓存 (过期时间: $CacheExpiryMinutes 分钟)" "Info"
    }

    if ($Parallel) {
        Write-QuickMessage "⚡ 启用并行执行" "Info"
    }

    $allResults = @()

    try {
        # 执行各项检查
        $allResults += Test-CoreFiles

        if ($Level -ne "Critical") {
            $allResults += Test-ConfigFiles
            $allResults += Test-ModulesAndScripts
        }

        # 度量性能
        Measure-Performance | Out-Null

        # 显示结果
        $summary = Show-QuickResults -AllResults $allResults

        # 自动修复
        if ($Fix) {
            Write-Host ""
            Invoke-QuickFix
        }

        # 导出结果
        if ($ExportResults) {
            Write-Host ""
            Export-QuickResults
        }

        # 返回退出代码
        if ($summary.Errors -gt 0) {
            return 1
        } elseif ($summary.Warnings -gt 0) {
            return 2
        } else {
            return 0
        }

    } catch {
        Write-QuickMessage "快速检查过程中发生错误: $($_.Exception.Message)" "Error"
        return 1
    }
}

# 主执行逻辑
if ($MyInvocation.InvocationName -ne '.') {
    # 参数验证
    if ($CacheExpiryMinutes -lt 1 -or $CacheExpiryMinutes -gt 1440) {
        Write-Error "缓存过期时间必须在1-1440分钟之间"
        exit 1
    }

    # 执行快速检查
    $exitCode = Invoke-QuickCheck

    # 清理并行作业
    Get-Job | Stop-Job -PassThru | Remove-Job -Force -ErrorAction SilentlyContinue

    exit $exitCode
}
