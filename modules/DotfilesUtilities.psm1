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

function Install-DotFile {
    <#
    .SYNOPSIS
        安装单个配置文件，支持复制和符号链接两种模式。
    .DESCRIPTION
        将源文件安装到目标位置，可以是复制或创建符号链接。
        如果目标文件已存在，将根据 Force 参数决定是否覆盖。
        在覆盖前，会创建原文件的备份。
    .PARAMETER Source
        源文件的完整路径
    .PARAMETER Target
        目标文件的完整路径
    .PARAMETER Symlink
        如果设置为 $true，创建符号链接而不是复制文件
    .PARAMETER Force
        如果设置为 $true，覆盖已存在的目标文件
    .PARAMETER BackupDir
        备份目录路径，如果目标文件已存在，会在此目录创建备份
    .PARAMETER WhatIf
        如果设置为 $true，只显示将要执行的操作但不实际执行
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Target,

        [Parameter(Mandatory = $false)]
        [bool]$Symlink = $false,

        [Parameter(Mandatory = $false)]
        [bool]$Force = $false,

        [Parameter(Mandatory = $false)]
        [string]$BackupDir = "",

        [Parameter(Mandatory = $false)]
        [switch]$WhatIf
    )

    # 验证源文件存在
    if (-not (Test-Path -Path $Source)) {
        Write-DotfilesMessage -Message "错误: 源文件不存在: $Source" -Type Error
        return $false
    }

    # 确保目标目录存在
    $targetDir = Split-Path -Parent $Target
    if (-not (Test-Path -Path $targetDir)) {
        if ($WhatIf) {
            Write-DotfilesMessage -Message "将创建目录: $targetDir" -Type Info
        } else {
            Write-DotfilesMessage -Message "创建目录: $targetDir" -Type Info
            New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
        }
    }

    # 如果目标文件已存在
    if (Test-Path -Path $Target) {
        # 如果不强制覆盖，则跳过
        if (-not $Force) {
            Write-DotfilesMessage -Message "跳过: 目标已存在且未指定强制覆盖: $Target" -Type Warning
            return $false
        }

        # 创建备份
        if (-not $WhatIf) {
            if ([string]::IsNullOrEmpty($BackupDir)) {
                $BackupDir = Split-Path -Parent $Target
            }

            if (-not (Test-Path $BackupDir)) {
                New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
            }

            $fileName = Split-Path -Leaf $Target
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $backupPath = Join-Path -Path $BackupDir -ChildPath "$fileName.backup.$timestamp"

            Write-DotfilesMessage -Message "备份: $Target -> $backupPath" -Type Info
            Copy-Item -Path $Target -Destination $backupPath -Force
        } else {
            Write-DotfilesMessage -Message "将备份: $Target" -Type Info
        }

        # 移除现有目标
        if ($WhatIf) {
            Write-DotfilesMessage -Message "将删除: $Target" -Type Info
        } else {
            if (Test-Path -Path $Target -PathType Container) {
                Remove-Item -Path $Target -Recurse -Force
            } else {
                Remove-Item -Path $Target -Force
            }
        }
    }

    # 安装文件
    if ($Symlink) {
        if ($WhatIf) {
            Write-DotfilesMessage -Message "将创建符号链接: $Source -> $Target" -Type Info
        } else {
            try {
                if (Test-Path -Path $Source -PathType Container) {
                    # 为目录创建符号链接
                    $command = "New-Item -Path `"$Target`" -ItemType SymbolicLink -Value `"$Source`" -Force"
                    Write-DotfilesMessage -Message "创建目录链接: $Source -> $Target" -Type Info
                    Invoke-Expression $command
                } else {
                    # 为文件创建符号链接
                    $command = "New-Item -Path `"$Target`" -ItemType SymbolicLink -Value `"$Source`" -Force"
                    Write-DotfilesMessage -Message "创建文件链接: $Source -> $Target" -Type Info
                    Invoke-Expression $command
                }
                return $true
            } catch {
                Write-DotfilesMessage -Message "创建符号链接失败: $($_.Exception.Message)" -Type Error
                return $false
            }
        }
    } else {
        if ($WhatIf) {
            Write-DotfilesMessage -Message "将复制: $Source -> $Target" -Type Info
        } else {
            try {
                if (Test-Path -Path $Source -PathType Container) {
                    # 递归复制目录
                    Copy-Item -Path $Source -Destination $Target -Recurse -Force
                    Write-DotfilesMessage -Message "复制目录: $Source -> $Target" -Type Info
                } else {
                    # 复制文件
                    Copy-Item -Path $Source -Destination $Target -Force
                    Write-DotfilesMessage -Message "复制文件: $Source -> $Target" -Type Info
                }
                return $true
            } catch {
                Write-DotfilesMessage -Message "复制失败: $($_.Exception.Message)" -Type Error
                return $false
            }
        }
    }

    return $true
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
    'Get-DotfilesEnvironment',
    'Install-DotFile'
)

# 导出类
Export-ModuleMember -Variable @(
    'ValidationResult'
)

# 模块初始化消息
Write-Verbose "DotfilesUtilities 模块已加载 - 包含UI和验证功能"
