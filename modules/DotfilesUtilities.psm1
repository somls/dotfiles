# DotfilesUtilities.psm1
# 整合的工具模块 - 合并UI管理和验证功能
# 精简高效的单一模块设计

#Requires -Version 5.1

# 严格模式
Set-StrictMode -Version Latest

# ==================== 配置和常量 ====================

# 颜色主题
$script:Colors = @{
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "Cyan"
    Debug = "Gray"
    Accent = "Magenta"
}

# 图标集合
$script:Icons = @{
    Success = "✓"
    Error = "✗"
    Warning = "!"
    Info = "·"
    Check = "?"
    Fix = "+"
    Time = "⏱"
}

# 验证结果类
class ValidationResult {
    [string]$Component
    [bool]$IsValid
    [string]$Status
    [string]$Message
    [string]$Details
    [string]$Suggestion
    [hashtable]$Metadata
    [timespan]$Duration

    ValidationResult([string]$component) {
        $this.Component = $component
        $this.IsValid = $false
        $this.Status = "Unknown"
        $this.Message = ""
        $this.Details = ""
        $this.Suggestion = ""
        $this.Metadata = @{}
        $this.Duration = [timespan]::Zero
    }
}

# ==================== 输出和UI函数 ====================

function Write-DotfilesMessage {
    <#
    .SYNOPSIS
        统一的消息输出函数，支持颜色和图标
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("Success", "Error", "Warning", "Info", "Debug")]
        [string]$Type = "Info",

        [switch]$NoNewLine,
        [switch]$NoIcon,
        [switch]$NoTimestamp
    )

    $color = $script:Colors[$Type]
    $icon = if ($NoIcon) { "" } else { "$($script:Icons[$Type]) " }
    $timestamp = if ($NoTimestamp) { "" } else { "[$(Get-Date -Format 'HH:mm:ss')] " }

    $output = "$timestamp$icon$Message"

    if ($NoNewLine) {
        Write-Host $output -ForegroundColor $color -NoNewline
    } else {
        Write-Host $output -ForegroundColor $color
    }
}

function Write-DotfilesHeader {
    <#
    .SYNOPSIS
        显示格式化的标题
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [string]$Subtitle = "",
        [string]$Separator = "="
    )

    $titleLength = $Title.Length
    $separatorLine = $Separator * [math]::Max($titleLength, 40)

    Write-Host ""
    Write-Host $separatorLine -ForegroundColor $script:Colors.Accent
    Write-Host $Title -ForegroundColor $script:Colors.Accent
    if ($Subtitle) {
        Write-Host $Subtitle -ForegroundColor $script:Colors.Info
    }
    Write-Host $separatorLine -ForegroundColor $script:Colors.Accent
    Write-Host ""
}

function Show-DotfilesProgress {
    <#
    .SYNOPSIS
        显示进度条
    #>
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete = -1,
        [switch]$Completed
    )

    if ($Completed) {
        Write-Progress -Activity $Activity -Completed
    } else {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
    }
}

function Write-DotfilesSummary {
    <#
    .SYNOPSIS
        显示操作总结
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Summary
    )

    Write-DotfilesHeader -Title "操作总结"

    foreach ($key in $Summary.Keys) {
        $value = $Summary[$key]
        $type = switch ($key) {
            { $_ -match "Error|Failed|问题" } { "Error" }
            { $_ -match "Warning|警告" } { "Warning" }
            { $_ -match "Success|成功|通过" } { "Success" }
            default { "Info" }
        }

        Write-DotfilesMessage -Message "$key`: $value" -Type $type -NoTimestamp
    }
}

# ==================== 验证功能 ====================

function Test-DotfilesPath {
    <#
    .SYNOPSIS
        验证路径是否存在且可访问
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Type = "Any" # File, Directory, Any
    )

    try {
        if (-not (Test-Path $Path)) {
            return @{ IsValid = $false; Message = "路径不存在" }
        }

        $item = Get-Item $Path -ErrorAction Stop

        switch ($Type) {
            "File" {
                if ($item.PSIsContainer) {
                    return @{ IsValid = $false; Message = "期望文件但找到目录" }
                }
            }
            "Directory" {
                if (-not $item.PSIsContainer) {
                    return @{ IsValid = $false; Message = "期望目录但找到文件" }
                }
            }
        }

        return @{
            IsValid = $true
            Message = "路径有效"
            Item = $item
        }
    }
    catch {
        return @{ IsValid = $false; Message = "无法访问路径: $($_.Exception.Message)" }
    }
}

function Test-DotfilesJson {
    <#
    .SYNOPSIS
        验证JSON文件格式
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        if (-not (Test-Path $Path)) {
            return @{ IsValid = $false; Message = "文件不存在" }
        }

        $content = Get-Content $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($content)) {
            return @{ IsValid = $false; Message = "文件为空" }
        }

        $jsonObject = $content | ConvertFrom-Json -ErrorAction Stop

        return @{
            IsValid = $true
            Message = "JSON格式正确"
            Object = $jsonObject
            Size = (Get-Item $Path).Length
        }
    }
    catch {
        return @{
            IsValid = $false
            Message = "JSON格式错误: $($_.Exception.Message)"
        }
    }
}

function Test-DotfilesPowerShell {
    <#
    .SYNOPSIS
        验证PowerShell脚本语法
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        $tokens = $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $Path, [ref]$tokens, [ref]$errors
        )

        if ($errors.Count -eq 0) {
            return @{
                IsValid = $true
                Message = "语法正确"
                TokenCount = $tokens.Count
            }
        } else {
            return @{
                IsValid = $false
                Message = "语法错误: $($errors[0].Message)"
                ErrorCount = $errors.Count
            }
        }
    }
    catch {
        return @{
            IsValid = $false
            Message = "无法解析文件: $($_.Exception.Message)"
        }
    }
}

function Get-DotfilesValidationResult {
    <#
    .SYNOPSIS
        创建统一的验证结果对象
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Component,

        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Type = "File"
    )

    $result = [ValidationResult]::new($Component)
    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        # 路径验证
        $pathResult = Test-DotfilesPath -Path $Path -Type $Type
        if (-not $pathResult.IsValid) {
            $result.Status = "Error"
            $result.Message = $pathResult.Message
            $result.IsValid = $false
            return $result
        }

        $result.Metadata.Path = $Path
        $result.Metadata.Type = $Type

        # 特定类型验证
        if ($Path.EndsWith('.json')) {
            $jsonResult = Test-DotfilesJson -Path $Path
            $result.IsValid = $jsonResult.IsValid
            $result.Status = if ($jsonResult.IsValid) { "Success" } else { "Error" }
            $result.Message = $jsonResult.Message
            if ($jsonResult.Size) { $result.Metadata.Size = $jsonResult.Size }
        }
        elseif ($Path.EndsWith('.ps1')) {
            $psResult = Test-DotfilesPowerShell -Path $Path
            $result.IsValid = $psResult.IsValid
            $result.Status = if ($psResult.IsValid) { "Success" } else { "Error" }
            $result.Message = $psResult.Message
            if ($psResult.TokenCount) { $result.Metadata.TokenCount = $psResult.TokenCount }
        }
        else {
            # 基础文件验证
            $item = $pathResult.Item
            $result.IsValid = $true
            $result.Status = "Success"
            $result.Message = "文件存在"
            $result.Metadata.Size = if (-not $item.PSIsContainer) { $item.Length } else { $null }
            $result.Metadata.LastModified = $item.LastWriteTime
        }
    }
    catch {
        $result.IsValid = $false
        $result.Status = "Error"
        $result.Message = "验证失败: $($_.Exception.Message)"
    }
    finally {
        $timer.Stop()
        $result.Duration = $timer.Elapsed
    }

    return $result
}

# ==================== 文件操作辅助函数 ====================

function Backup-DotfilesFile {
    <#
    .SYNOPSIS
        创建文件备份
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$BackupDir = ""
    )

    try {
        if (-not (Test-Path $Path)) {
            throw "源文件不存在: $Path"
        }

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $fileName = Split-Path $Path -Leaf
        $backupName = "$fileName.backup.$timestamp"

        if ([string]::IsNullOrEmpty($BackupDir)) {
            $BackupDir = Split-Path $Path -Parent
        }

        $backupPath = Join-Path $BackupDir $backupName
        Copy-Item $Path $backupPath -Force

        return @{
            Success = $true
            BackupPath = $backupPath
            Message = "备份创建成功"
        }
    }
    catch {
        return @{
            Success = $false
            Message = "备份失败: $($_.Exception.Message)"
        }
    }
}

function Get-DotfilesEnvironment {
    <#
    .SYNOPSIS
        获取环境信息
    #>
    param()

    return @{
        ComputerName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        OSVersion = [System.Environment]::OSVersion.VersionString
        WorkingDirectory = (Get-Location).Path
        ProcessId = $PID
        Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    }
}

# ==================== 导出成员 ====================

# 导出公共函数
Export-ModuleMember -Function @(
    'Write-DotfilesMessage',
    'Write-DotfilesHeader',
    'Show-DotfilesProgress',
    'Write-DotfilesSummary',
    'Test-DotfilesPath',
    'Test-DotfilesJson',
    'Test-DotfilesPowerShell',
    'Get-DotfilesValidationResult',
    'Backup-DotfilesFile',
    'Get-DotfilesEnvironment'
)

# 导出类
Export-ModuleMember -Variable @(
    'ValidationResult'
)

# 模块初始化消息
Write-Verbose "DotfilesUtilities 模块已加载 - 包含UI和验证功能"
