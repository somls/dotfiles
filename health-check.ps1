#Requires -Version 5.1

<#
.SYNOPSIS
    Dotfiles 项目健康检查脚本 - 验证工具安装和配置状态

.DESCRIPTION
    这个脚本提供全面的健康检查功能，包括：
    - 验证核心配置文件完整性
    - 检查工具安装状态（基于packages.txt）
    - 分类显示工具状态
    - 提供安装建议和修复方案
    - 支持详细报告输出

.PARAMETER Detailed
    启用详细模式，显示更多诊断信息

.PARAMETER Fix
    自动尝试修复发现的问题

.PARAMETER Component
    检查特定组件，可选值：configs, tools, all

.PARAMETER OutputFormat
    输出格式，可选值：console, json, markdown

.PARAMETER OutFile
    将结果保存到指定文件

.EXAMPLE
    .\health-check.ps1
    运行基本健康检查

.EXAMPLE
    .\health-check.ps1 -Detailed
    运行详细健康检查

.EXAMPLE
    .\health-check.ps1 -Fix
    检查并自动修复问题

.EXAMPLE
    .\health-check.ps1 -OutputFormat json -OutFile report.json
    生成JSON格式报告

.NOTES
    文件名: health-check.ps1
    作者: Dotfiles项目
    版本: 3.0.0
    最后更新: 2025-01-07
#>

[CmdletBinding()]
param(
    [switch]$Detailed,
    [switch]$Fix,
    [ValidateSet('configs', 'tools', 'all')]
    [string]$Component = 'all',
    [ValidateSet('console', 'json', 'markdown')]
    [string]$OutputFormat = 'console',
    [string]$OutFile
)

# 全局变量
$Script:HealthResults = @{
    ConfigFiles = @()
    Tools = @()
    Issues = @()
    Recommendations = @()
    Stats = @{
        TotalConfigs = 0
        ValidConfigs = 0
        TotalTools = 0
        InstalledTools = 0
        MissingTools = 0
        IssuesFound = 0
        IssuesFixed = 0
    }
    Timestamp = Get-Date
}

# 工具分类配置 - 严格基于 scoop/packages.txt 文件
$Script:ToolCategories = @{
    Essential = @{
        Description = "核心开发工具 (Essential) - 基础必需工具"
        Tools = @(
            @{ Name = 'Git'; Command = 'git'; Description = '版本控制系统'; Critical = $true }
            @{ Name = 'Ripgrep'; Command = 'rg'; Description = '快速文本搜索'; Critical = $true }
            @{ Name = 'Zoxide'; Command = 'zoxide'; Description = '智能目录跳转'; Critical = $true }
            @{ Name = 'FZF'; Command = 'fzf'; Description = '模糊搜索工具'; Critical = $true }
            @{ Name = 'Bat'; Command = 'bat'; Description = '语法高亮文件查看器'; Critical = $true }
            @{ Name = 'Fd'; Command = 'fd'; Description = '快速文件搜索'; Critical = $true }
            @{ Name = 'JQ'; Command = 'jq'; Description = 'JSON处理器'; Critical = $true }
            @{ Name = 'Neovim'; Command = 'nvim'; Description = '现代文本编辑器'; Critical = $false }
            @{ Name = 'Starship'; Command = 'starship'; Description = '跨Shell提示符'; Critical = $true }
            @{ Name = 'VS Code'; Command = 'code'; Description = '代码编辑器'; Critical = $false }
            @{ Name = 'Sudo'; Command = 'sudo'; Description = '权限提升工具'; Critical = $false }
            @{ Name = 'Curl'; Command = 'curl'; Description = 'HTTP客户端'; Critical = $true }
            @{ Name = '7zip'; Command = '7z'; Description = '压缩工具'; Critical = $true }
        )
        Priority = 'High'
        Notes = "覆盖90%日常开发场景的基础工具"
    }
    Development = @{
        Description = "开发工具 (Development) - 代码开发和检查工具"
        Tools = @(
            @{ Name = 'ShellCheck'; Command = 'shellcheck'; Description = 'Shell脚本检查器'; Critical = $false }
            @{ Name = 'GitHub CLI'; Command = 'gh'; Description = 'GitHub命令行工具'; Critical = $true }
        )
        Priority = 'Medium'
        Notes = "代码质量检查和GitHub集成工具"
    }
    GitEnhanced = @{
        Description = "Git增强工具 (GitEnhanced) - Git可视化管理"
        Tools = @(
            @{ Name = 'Lazygit'; Command = 'lazygit'; Description = 'Git终端界面'; Critical = $true }
        )
        Priority = 'Medium'
        Notes = "Git可视化管理工具"
    }
    Programming = @{
        Description = "编程语言支持 (Programming) - 核心编程语言运行时"
        Tools = @(
            @{ Name = 'Python'; Command = 'python'; Description = 'Python解释器'; Critical = $true }
            @{ Name = 'Node.js'; Command = 'node'; Description = 'Node.js运行时'; Critical = $true }
        )
        Priority = 'High'
        Notes = "Python和Node.js核心运行时环境"
    }
    CoreSystem = @{
        Description = "核心系统工具 - 系统基础组件"
        Tools = @(
            @{ Name = 'PowerShell 7'; Command = 'pwsh'; Description = 'PowerShell 7+'; Critical = $true }
            @{ Name = 'Windows Terminal'; Command = 'wt'; Description = '现代终端应用'; Critical = $true }
        )
        Priority = 'High'
        Notes = "系统核心组件，必须安装"
    }
}

# 配置文件检查列表 - 与install.json组件配置保持一致
$Script:ConfigFiles = @(
    @{
        Name = 'Scoop Config'
        Path = 'scoop'
        Description = 'Scoop 包管理器配置'
        Required = $true
        Component = 'scoop'
        Priority = 1
    }
    @{
        Name = 'PowerShell Profile'
        Path = 'powershell\Microsoft.PowerShell_profile.ps1'
        Description = 'PowerShell配置文件和模块'
        Required = $true
        Component = 'powershell'
        Priority = 2
    }
    @{
        Name = 'Git Config'
        Path = 'git\gitconfig'
        Description = 'Git全局配置'
        Required = $true
        Component = 'git'
        Priority = 3
    }
    @{
        Name = 'Starship Config'
        Path = 'starship\starship.toml'
        Description = 'Starship提示符配置'
        Required = $true
        Component = 'starship'
        Priority = 4
    }
    @{
        Name = 'Windows Terminal'
        Path = 'WindowsTerminal\settings.json'
        Description = 'Windows Terminal配置'
        Required = $true
        Component = 'windowsTerminal'
        Priority = 5
    }
    @{
        Name = 'Neovim Config'
        Path = 'neovim\init.lua'
        Description = 'Neovim编辑器配置'
        Required = $false
        Component = 'neovim'
        Priority = 8
        Optional = $true
    }
    @{
        Name = 'CMD Scripts'
        Path = 'scripts\cmd'
        Description = 'CMD批处理脚本和工具'
        Required = $true
        Component = 'cmd'
        Priority = 9
    }

    @{
        Name = 'Install Config'
        Path = 'config\install.json'
        Description = '安装配置文件'
        Required = $true
    }
    @{
        Name = 'User Profiles'
        Path = 'config\user-profiles.json'
        Description = '用户配置档案'
        Required = $true
    }
)

#region Helper Functions

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )

    $colors = @{
        'Info' = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
    }

    $icons = @{
        'Info' = 'Info'
        'Success' = 'OK'
        'Warning' = 'Warning'
        'Error' = 'ERROR'
    }

    if ($OutputFormat -eq 'console') {
        Write-Host "$($icons[$Type]) $Message" -ForegroundColor $colors[$Type]
    }
}

function Test-CommandExists {
    param([string]$Command)

    try {
        $null = Get-Command $Command -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Get-CommandPath {
    param([string]$Command)

    try {
        $cmd = Get-Command $Command -ErrorAction Stop
        return $cmd.Source
    }
    catch {
        return $null
    }
}

function Test-ConfigFile {
    param(
        [string]$RelativePath,
        [string]$Name
    )

    $projectRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
    $fullPath = Join-Path $projectRoot $RelativePath



    $result = @{
        Name = $Name
        Path = $RelativePath
        FullPath = $fullPath
        Exists = $false
        Readable = $false
        Size = 0
        LastModified = $null
    }

    if (Test-Path $fullPath) {
        $result.Exists = $true
        try {
            $item = Get-Item $fullPath
            $result.Size = if ($item.PSIsContainer) { 0 } else { $item.Length }
            $result.LastModified = $item.LastWriteTime

            # 测试可读性 - 区分文件和目录
            if ($item.PSIsContainer) {
                # 对于目录，检查是否可以列出内容
                $null = Get-ChildItem $fullPath -ErrorAction Stop
                $result.Readable = $true
            } else {
                # 对于文件，检查是否可以读取内容
                $null = Get-Content $fullPath -TotalCount 1 -ErrorAction Stop
                $result.Readable = $true
            }
        }
        catch {
            $result.Readable = $false
        }
    }

    return $result
}

function Get-ToolInstallStatus {
    param([hashtable]$Tool)

    $result = @{
        Name = $Tool.Name
        Command = $Tool.Command
        Description = $Tool.Description
        Installed = $false
        Path = $null
        Version = $null
        Source = 'Unknown'
    }

    if (Test-CommandExists $Tool.Command) {
        $result.Installed = $true
        $result.Path = Get-CommandPath $Tool.Command

        # 检测安装源
        if ($result.Path -like "*scoop*") {
            $result.Source = "Scoop"
        } elseif ($result.Path -like "*WindowsApps*") {
            $result.Source = "Microsoft Store"
        } elseif ($result.Path -like "*Program Files*") {
            $result.Source = "System Install"
        } else {
            $result.Source = "Portable/Other"
        }

        # 获取版本信息（尝试常见的版本参数）
        try {
            $versionArgs = @('--version', '-V', 'version', '/version')
            foreach ($arg in $versionArgs) {
                try {
                    $versionOutput = & $Tool.Command $arg 2>$null
                    if ($versionOutput -and $versionOutput -match '\d+\.\d+') {
                        $result.Version = $versionOutput[0].Trim()
                        break
                    }
                }
                catch {
                    continue
                }
            }
        }
        catch {
            $result.Version = "Unknown"
        }
    }

    return $result
}

#endregion

#region Check Functions

function Test-ConfigurationFiles {
    Write-Status "检查核心配置文件..." 'Info'

    $projectRoot = $PSScriptRoot

    foreach ($config in $Script:ConfigFiles) {

        $result = Test-ConfigFile -RelativePath $config.Path -Name $config.Name

        $Script:HealthResults.ConfigFiles += $result
        $Script:HealthResults.Stats.TotalConfigs++



        if ($result.Exists -and $result.Readable) {
            Write-Status "[$($config.Name)] 配置文件存在: $($result.FullPath)" 'Success'
            $Script:HealthResults.Stats.ValidConfigs++
        } else {
            $message = if ($config.Required) {
                "[$($config.Name)] 必需配置文件缺失: $($config.Path)"
                $Script:HealthResults.Issues += "缺少必需配置文件: $($config.Name)"
                'Error'
            } else {
                "[$($config.Name)] 可选配置文件缺失: $($config.Path)"
                'Warning'
            }
            Write-Status $message[0] $message[1]
            $Script:HealthResults.Stats.IssuesFound++
        }
    }
}

function Test-ToolInstallation {
    Write-Status "检查应用程序安装状态..." 'Info'

    foreach ($categoryName in $Script:ToolCategories.Keys) {
        $category = $Script:ToolCategories[$categoryName]

        if ($Detailed) {
            Write-Status "检查 $categoryName ($($category.Description))..." 'Info'
        }

        foreach ($tool in $category.Tools) {
            $result = Get-ToolInstallStatus -Tool $tool
            $result.Category = $categoryName
            $result.Priority = $category.Priority

            $Script:HealthResults.Tools += $result
            $Script:HealthResults.Stats.TotalTools++

            if ($result.Installed) {
                $message = "$($result.Name) 已安装: $($result.Path)"
                if ($Detailed -and $result.Version) {
                    $message += " (版本: $($result.Version), 来源: $($result.Source))"
                }
                Write-Status $message 'Success'
                $Script:HealthResults.Stats.InstalledTools++
            } else {
                # 区分Critical和非Critical工具的处理
                if ($tool.Critical) {
                    Write-Status "$($result.Name) 未安装" 'Warning'
                    $Script:HealthResults.Stats.MissingTools++

                    # 根据优先级添加问题
                    if ($result.Priority -eq 'High') {
                        $Script:HealthResults.Issues += "$($result.Name) (高优先级工具) 未安装"
                        $Script:HealthResults.Stats.IssuesFound++
                    }
                } else {
                    # 非Critical工具只显示为Info，不计入MissingTools
                    if ($Detailed) {
                        Write-Status "$($result.Name) 未安装 (可选)" 'Info'
                    }
                }

                # 所有未安装的工具都添加到建议中
                $recommendation = "建议安装 $($result.Name)"
                $Script:HealthResults.Recommendations += $recommendation
            }
        }
    }
}

function Invoke-AutoFix {
    if (-not $Fix) { return }

    Write-Status "尝试自动修复问题..." 'Info'

    # 检查Scoop是否安装
    if (-not (Test-CommandExists 'scoop')) {
        Write-Status "Scoop未安装，建议运行 install_apps.ps1" 'Warning'
        return
    }

    # 尝试安装缺失的高优先级工具
    $missingHighPriorityTools = $Script:HealthResults.Tools |
        Where-Object { -not $_.Installed -and $_.Priority -eq 'High' }

    if ($missingHighPriorityTools) {
        Write-Status "尝试安装高优先级工具..." 'Info'

        foreach ($tool in $missingHighPriorityTools) {
            try {
                Write-Status "正在安装 $($tool.Name)..." 'Info'
                $output = scoop install $tool.Command 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Status "$($tool.Name) 安装成功" 'Success'
                    $tool.Installed = $true
                    $Script:HealthResults.Stats.IssuesFixed++
                } else {
                    Write-Status "$($tool.Name) 安装失败" 'Error'
                }
            }
            catch {
                Write-Status "$($tool.Name) 安装异常: $($_.Exception.Message)" 'Error'
            }
        }
    }
}

#endregion

#region Output Functions

function Get-OverallStatus {
    $configsOk = $Script:HealthResults.Stats.ValidConfigs -eq $Script:HealthResults.Stats.TotalConfigs
    $criticalToolsOk = ($Script:HealthResults.Tools | Where-Object { -not $_.Installed -and $_.Priority -eq 'High' }).Count -eq 0
    $majorIssues = $Script:HealthResults.Stats.IssuesFound

    if ($configsOk -and $criticalToolsOk -and $majorIssues -eq 0) {
        return "Success"
    } elseif ($majorIssues -le 3) {
        return "Warning"
    } else {
        return "Error"
    }
}

function Show-ConsoleSummary {
    $overallStatus = Get-OverallStatus

    Write-Host "`n" + ("=" * 50) -ForegroundColor Green
    Write-Host "健康检查完成" -ForegroundColor Green
    Write-Host ("=" * 50) -ForegroundColor Green

    Write-Status "总体状态: $overallStatus" $(if ($overallStatus -eq 'Success') { 'Success' } elseif ($overallStatus -eq 'Warning') { 'Warning' } else { 'Error' })

    if ($Script:HealthResults.Issues.Count -gt 0) {
        Write-Host "`n发现的问题:" -ForegroundColor Red
        foreach ($issue in $Script:HealthResults.Issues) {
            Write-Host "  • $issue" -ForegroundColor Red
        }
    }

    if ($Script:HealthResults.Recommendations.Count -gt 0) {
        Write-Host "`n建议:" -ForegroundColor Yellow
        foreach ($recommendation in $Script:HealthResults.Recommendations) {
            Write-Host "  • $recommendation" -ForegroundColor Yellow
        }
    }

    if ($Detailed) {
        Write-Host "`n统计信息:" -ForegroundColor Cyan
        Write-Host "  配置文件: $($Script:HealthResults.Stats.ValidConfigs)/$($Script:HealthResults.Stats.TotalConfigs)" -ForegroundColor White
        Write-Host "  已安装工具: $($Script:HealthResults.Stats.InstalledTools)/$($Script:HealthResults.Stats.TotalTools)" -ForegroundColor White
        Write-Host "  发现问题: $($Script:HealthResults.Stats.IssuesFound)" -ForegroundColor White
        if ($Fix) {
            Write-Host "  修复问题: $($Script:HealthResults.Stats.IssuesFixed)" -ForegroundColor White
        }
    }
}

function Export-JsonReport {
    $report = @{
        timestamp = $Script:HealthResults.Timestamp.ToString('yyyy-MM-ddTHH:mm:ssZ')
        overall_status = Get-OverallStatus
        summary = @{
            total_configs = $Script:HealthResults.Stats.TotalConfigs
            valid_configs = $Script:HealthResults.Stats.ValidConfigs
            total_tools = $Script:HealthResults.Stats.TotalTools
            installed_tools = $Script:HealthResults.Stats.InstalledTools
            missing_tools = $Script:HealthResults.Stats.MissingTools
            issues_found = $Script:HealthResults.Stats.IssuesFound
            issues_fixed = $Script:HealthResults.Stats.IssuesFixed
        }
        config_files = $Script:HealthResults.ConfigFiles
        tools = $Script:HealthResults.Tools
        issues = $Script:HealthResults.Issues
        recommendations = $Script:HealthResults.Recommendations
    }

    return $report | ConvertTo-Json -Depth 10
}

function Export-MarkdownReport {
    $overallStatus = Get-OverallStatus
    $timestamp = $Script:HealthResults.Timestamp.ToString('yyyy-MM-dd HH:mm:ss')

    $markdown = @"
# Dotfiles 健康检查报告

**生成时间**: $timestamp
**总体状态**: $overallStatus
**项目路径**: $PSScriptRoot

## 📊 统计摘要

| 项目 | 状态 |
|------|------|
| 配置文件 | $($Script:HealthResults.Stats.ValidConfigs)/$($Script:HealthResults.Stats.TotalConfigs) |
| 已安装工具 | $($Script:HealthResults.Stats.InstalledTools)/$($Script:HealthResults.Stats.TotalTools) |
| 发现问题 | $($Script:HealthResults.Stats.IssuesFound) |
| 修复问题 | $($Script:HealthResults.Stats.IssuesFixed) |

## 🔧 工具安装状态

"@

    foreach ($categoryName in $Script:ToolCategories.Keys) {
        $categoryTools = $Script:HealthResults.Tools | Where-Object { $_.Category -eq $categoryName }
        if ($categoryTools) {
            $markdown += "`n### $categoryName`n`n"
            foreach ($tool in $categoryTools) {
                $status = if ($tool.Installed) { "✅" } else { "❌" }
                $markdown += "- $status **$($tool.Name)**: $($tool.Description)`n"
            }
        }
    }

    if ($Script:HealthResults.Issues.Count -gt 0) {
        $markdown += "`n## ❌ 发现的问题`n`n"
        foreach ($issue in $Script:HealthResults.Issues) {
            $markdown += "- $issue`n"
        }
    }

    if ($Script:HealthResults.Recommendations.Count -gt 0) {
        $markdown += "`n## 💡 建议`n`n"
        foreach ($recommendation in $Script:HealthResults.Recommendations) {
            $markdown += "- $recommendation`n"
        }
    }

    return $markdown
}

#endregion

#region Main Execution

function Invoke-HealthCheck {
    # 显示标题
    if ($OutputFormat -eq 'console') {
        Write-Host "Dotfiles 健康检查" -ForegroundColor Cyan
        Write-Host ("=" * 50) -ForegroundColor Cyan
        Write-Host "项目路径: $PSScriptRoot" -ForegroundColor Gray
        Write-Host ""
    }

    # 执行检查
    if ($Component -eq 'all' -or $Component -eq 'configs') {
        Test-ConfigurationFiles
    }

    if ($Component -eq 'all' -or $Component -eq 'tools') {
        Test-ToolInstallation
    }

    # 尝试自动修复
    Invoke-AutoFix

    # 输出结果
    switch ($OutputFormat) {
        'console' {
            Show-ConsoleSummary
        }
        'json' {
            $jsonResult = Export-JsonReport
            if ($OutFile) {
                $jsonResult | Out-File -Encoding UTF8 -FilePath $OutFile
                Write-Status "报告已保存到: $OutFile" 'Info'
            } else {
                Write-Output $jsonResult
            }
        }
        'markdown' {
            $markdownResult = Export-MarkdownReport
            if ($OutFile) {
                $markdownResult | Out-File -Encoding UTF8 -FilePath $OutFile
                Write-Status "报告已保存到: $OutFile" 'Info'
            } else {
                Write-Output $markdownResult
            }
        }
    }
}

# 主执行入口
try {
    Invoke-HealthCheck
}
catch {
    Write-Status "健康检查过程中发生异常: $($_.Exception.Message)" 'Error'
    if ($Detailed) {
        Write-Status "详细错误信息: $($_.ScriptStackTrace)" 'Error'
    }
    exit 1
}

#endregion
