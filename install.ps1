<#
.SYNOPSIS
    以“复制安装”为默认方式（可选符号链接），将本仓库中的 dotfiles 部署到系统中

.DESCRIPTION
    这个脚本提供了完整的 dotfiles 配置部署功能，包括：
    - 复制文件到系统配置目录（默认）
    - 可选创建符号链接到系统配置目录（在具备权限/启用开发者模式时）
    - 备份现有配置文件
    - 支持选择性安装特定类型的配置
    - 提供回滚和验证功能
    - 交互式安装模式

.PARAMETER DryRun
    预览模式，显示将要执行的操作但不实际执行

.PARAMETER Type
    只安装指定类型的配置（如 PowerShell, Git 等）
    如果不指定，将配置默认组件（Scoop, CMD, PowerShell, Starship, Git）并询问是否配置其他组件

.PARAMETER Force
    强制覆盖现有文件和链接，即使目标已存在

.PARAMETER Rollback
    回滚到备份状态，恢复之前的配置

.PARAMETER Validate
    验证现有符号链接的正确性

.PARAMETER Interactive
    交互式模式，逐个确认每个操作

.PARAMETER BackupDir
    备份目录路径，默认为用户目录下的 .dotfiles-backup

.PARAMETER SetDevMode
    启用开发模式，后续安装将默认使用符号链接

.PARAMETER UnsetDevMode
    禁用开发模式，后续安装将默认使用复制模式

.EXAMPLE
    .\install.ps1
    配置默认组件（Scoop, CMD, PowerShell, Starship, Git）并询问是否配置其他组件

.EXAMPLE
    .\install.ps1 -Type PowerShell,Git,Neovim -Force
    强制安装指定的配置

.EXAMPLE
    .\install.ps1 -Mode Symlink
    使用符号链接模式安装（开发模式）

.EXAMPLE
    .\install.ps1 -DryRun -Verbose
    预览模式查看将要执行的操作

.EXAMPLE
    .\install.ps1 -Rollback
    回滚到备份状态

.EXAMPLE
    .\install.ps1 -SetDevMode
    启用开发模式，后续安装将默认使用符号链接

.EXAMPLE
    .\install.ps1 -UnsetDevMode
    禁用开发模式，后续安装将默认使用复制模式

.NOTES
    Author: Windows 11 Dotfiles Project
    Version: 2.0
    Requires: PowerShell 5.1+

.LINK
    https://github.com/somls/dotfiles
#>

[CmdletBinding(DefaultParameterSetName = 'Install')]
param(
    [Parameter(ParameterSetName = 'Install')]
    [switch]$DryRun,

    [Parameter(ParameterSetName = 'Install')]
    [ValidateSet('PowerShell', 'Git', 'WezTerm', 'Alacritty', 'Starship', 'Scoop', 'Neovim', 'CMD', 'WindowsTerminal')]
    [string[]]$Type,

    [Parameter(ParameterSetName = 'Install')]
    [ValidateSet('Copy','Symlink')]
    [string]$Mode = 'Copy',

    [Parameter(ParameterSetName = 'Install')]
    [switch]$Force,

    [Parameter(ParameterSetName = 'Rollback', Mandatory)]
    [switch]$Rollback,

    [Parameter(ParameterSetName = 'Validate', Mandatory)]
    [switch]$Validate,

    [Parameter(ParameterSetName = 'Install')]
    [switch]$Interactive,

    [Parameter(ParameterSetName = 'Install')]
    [ValidateScript({
        if (-not (Test-Path $_ -IsValid)) {
            throw "备份目录路径无效: $_"
        }
        $true
    })]
    [string]$BackupDir = "$env:USERPROFILE\.dotfiles-backup",

    [Parameter(ParameterSetName = 'SetDevMode', Mandatory)]
    [switch]$SetDevMode,

    [Parameter(ParameterSetName = 'UnsetDevMode', Mandatory)]
    [switch]$UnsetDevMode
)

# 定义默认安装的应用（核心工具）
$script:DefaultComponents = @('Scoop', 'CMD', 'PowerShell', 'Starship', 'Git', 'WindowsTerminal')

# 优先读取用户配置文件（当未显式传入参数时生效）
try {
    $configPath = Join-Path $PSScriptRoot 'config/install.json'
    if (Test-Path $configPath) {
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        # 仅在未通过 CLI 指定时应用配置中的默认 Mode/Type
        if (-not $PSBoundParameters.ContainsKey('Mode') -and $cfg.DefaultMode) {
            if ($cfg.DefaultMode -in @('Copy','Symlink')) { $Mode = $cfg.DefaultMode }
        }
        if (-not $PSBoundParameters.ContainsKey('Type') -and $cfg.Components) {
            $enabled = @()
            foreach ($k in $cfg.Components.PSObject.Properties.Name) {
                if ($cfg.Components.$k -eq $true) { $enabled += $k }
            }
            if (@($enabled).Count -gt 0) { $Type = $enabled }
        }
    }
} catch {
    Write-Warning "读取 config/install.json 失败: $($_.Exception.Message)"
}

# 如果未指定Type参数，使用默认组件并询问是否配置其他组件
if (-not $PSBoundParameters.ContainsKey('Type')) {
    $Type = $script:DefaultComponents
    Write-Host "[INFO] 将配置默认组件: $($Type -join ', ')" -ForegroundColor Cyan

    # 在非DryRun和非Interactive模式下，询问是否配置其他组件
    if (-not $DryRun -and -not $Interactive) {
                    $allComponents = @('WezTerm', 'Alacritty', 'Neovim')
        $optionalComponents = $allComponents | Where-Object { $_ -notin $Type }

        if ($optionalComponents.Count -gt 0) {
            Write-Host "`n🔧 可选组件安装" -ForegroundColor Yellow
            Write-Host "除了默认组件外，您还可以选择安装以下应用的配置：" -ForegroundColor Gray

            # 显示可选组件列表
            Write-Host "`n可选组件列表：" -ForegroundColor Cyan
            for ($i = 0; $i -lt $optionalComponents.Count; $i++) {
                $component = $optionalComponents[$i]
                $description = switch ($component) {
                    'WezTerm' { 'WezTerm 终端' }
                    'Alacritty' { 'Alacritty 终端' }
                    'Neovim' { 'Neovim 编辑器' }
                    default { $component }
                }
                Write-Host "  $($i + 1). $component - $description" -ForegroundColor Gray
            }

            Write-Host "`n选择方式：" -ForegroundColor Yellow
            Write-Host "  a/A - 全选所有可选组件" -ForegroundColor Green
            Write-Host "  n/N - 全不选（跳过所有可选组件）" -ForegroundColor Red
            Write-Host "  i/I - 逐个选择（交互模式）" -ForegroundColor Cyan
            Write-Host "  直接回车 - 跳过所有可选组件" -ForegroundColor Gray

            $batchChoice = Read-Host "`n请选择安装方式 (a/n/i/Enter)"
            $selectedComponents = @()

            switch ($batchChoice.ToLower()) {
                'a' {
                    # 全选
                    $selectedComponents = $optionalComponents
                    Write-Host "✅ 已选择配置所有可选组件: $($selectedComponents -join ', ')" -ForegroundColor Green
                }
                'n' {
                    # 全不选
                    Write-Host "⏭️  跳过所有可选组件" -ForegroundColor Yellow
                }
                'i' {
                    # 交互模式
                    Write-Host "`n🔄 进入交互选择模式：" -ForegroundColor Cyan
                    foreach ($component in $optionalComponents) {
                        $description = switch ($component) {
                            'WezTerm' { 'WezTerm 终端' }
                            'Alacritty' { 'Alacritty 终端' }
                            'Neovim' { 'Neovim 编辑器' }
                            default { $component }
                        }

                        $response = Read-Host "是否安装 $component ($description)? (y/N)"
                        if ($response -eq 'y' -or $response -eq 'Y') {
                            $selectedComponents += $component
                        }
                    }
                }
                default {
                    # 默认跳过
                    Write-Host "⏭️  跳过所有可选组件" -ForegroundColor Yellow
                }
            }

            if ($selectedComponents.Count -gt 0) {
                $Type += $selectedComponents
                Write-Host "[INFO] 用户选择配置额外组件: $($selectedComponents -join ', ')" -ForegroundColor Cyan
            } else {
                Write-Host "[INFO] 用户未选择额外组件，仅配置默认组件" -ForegroundColor Cyan
            }
        }
    }
}

# 设置严格模式和错误处理
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# 导入必需模块
try {
    $ModulePath = Join-Path $PSScriptRoot "modules"
    if (Test-Path $ModulePath) {
        Import-Module (Join-Path $ModulePath "DotfilesUtilities.psm1") -Force -ErrorAction Stop
        Write-Verbose "模块加载成功: DotfilesUtilities"
        $script:UseEnhancedUI = $true
        # 如果增强UI所需类型不可用，则禁用增强UI
        if (-not ("ProgressManager" -as [type])) { $script:UseEnhancedUI = $false }
    }
} catch {
    Write-Warning "无法加载增强模块，将使用基础功能: $($_.Exception.Message)"
    $script:UseEnhancedUI = $false
}

# 预先声明脚本范围变量以满足 StrictMode（在 DryRun 下仍会被引用）
$script:ProgressManager = $null

# --- 配置 ---
$script:SourceDir = $PSScriptRoot
$script:TargetDir = $HOME
$script:InstallResults = @{
    Success = @()
    Failed = @()
    Skipped = @()
    Backed = @()
}
$script:LogFile = Join-Path $script:SourceDir "install.log"

# --- 安装模式解析（默认复制，开发者可选符号链接） ---
# 规则：
# 1) 显式 -Mode 参数最高优先级
# 2) 否则如果环境变量 DOTFILES_DEV_MODE=true/1/yes 或存在 ~/.dotfiles.dev-mode 标记文件，则使用 Symlink（开发模式）
# 3) 否则默认 Copy（生产模式）
$script:EffectiveMode = 'Copy'
$script:IsDevMode = $false
try {
    if ($PSBoundParameters.ContainsKey('Mode')) {
        $script:EffectiveMode = $Mode
        $script:IsDevMode = ($Mode -eq 'Symlink')
    } else {
        # 检查开发模式标记
        $devEnv = ($env:DOTFILES_DEV_MODE ?? '').ToString().Trim()
        $devFlag = Test-Path (Join-Path $HOME '.dotfiles.dev-mode')

        if ($devFlag -or ($devEnv -match '^(1|true|yes|on)$')) {
            $script:EffectiveMode = 'Symlink'
            $script:IsDevMode = $true
            Write-Host "[INFO] 检测到开发模式，将使用符号链接配置" -ForegroundColor Cyan
        } else {
            $script:EffectiveMode = 'Copy'
            Write-Host "[INFO] 生产模式，将使用复制配置" -ForegroundColor Cyan
        }
    }

    $modeDesc = if ($script:IsDevMode) { "开发模式 (符号链接)" } else { "生产模式 (复制文件)" }
    Write-Host "[INFO] 配置模式: $script:EffectiveMode - $modeDesc" -ForegroundColor Cyan
}
catch {
    Write-Host "[WARN] 解析配置模式失败，回退到 Copy: $($_.Exception.Message)" -ForegroundColor Yellow
    $script:EffectiveMode = 'Copy'
    $script:IsDevMode = $false
}

# --- 日志和输出函数 ---
function Write-Banner {
    <#
    .SYNOPSIS
        在控制台输出一个格式化的标题横幅

    .DESCRIPTION
        使用Unicode字符和颜色在控制台创建醒目的标题横幅

    .PARAMETER Title
        主标题文本

    .PARAMETER Subtitle
        副标题文本（可选）

    .PARAMETER Color
        横幅颜色，默认为青色
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,

        [string]$Subtitle,

        [System.ConsoleColor]$Color = 'Cyan'
    )

    $width = 60
    $divider = '=' * $width

    Write-Host "`n$divider" -ForegroundColor $Color
    Write-Host $Title.PadLeft(($width + $Title.Length) / 2) -ForegroundColor $Color

    if ($Subtitle) {
        Write-Host $Subtitle.PadLeft(($width + $Subtitle.Length) / 2) -ForegroundColor $Color
    }

    Write-Host $divider -ForegroundColor $Color
    Write-Host ""
}

function Write-InstallLog {
    <#
    .SYNOPSIS
        写入安装日志并显示控制台输出

    .DESCRIPTION
        统一的日志记录函数，支持多种日志级别和格式化输出

    .PARAMETER Message
        要记录的日志消息

    .PARAMETER Level
        日志级别：INFO, WARN, ERROR, SUCCESS

    .PARAMETER Exception
        可选的异常对象，用于记录详细错误信息

    .EXAMPLE
        Write-InstallLog "开始安装" "INFO"
        Write-InstallLog "发现警告" "WARN"
        Write-InstallLog "安装失败" "ERROR" -Exception $_.Exception
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO",

        [Parameter()]
        [System.Exception]$Exception
    )

    begin {
        # 确保日志文件路径有效
        if (-not $script:LogFile) {
            $script:LogFile = Join-Path $PSScriptRoot "install.log"
        }
    }

    process {
        try {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logEntry = "[$timestamp] [$Level] $Message"

            # 添加异常信息
            if ($Exception) {
                $logEntry += "`n    Exception: $($Exception.Message)"
                if ($Exception.InnerException) {
                    $logEntry += "`n    Inner Exception: $($Exception.InnerException.Message)"
                }
            }

            # 确保日志目录存在
            $logDir = Split-Path $script:LogFile -Parent
            if (-not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }

            # 写入日志文件
            Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue

            # 使用增强UI输出（如果可用）
            if ($script:UseEnhancedUI) {
                $uiLevel = switch ($Level) {
                    "INFO" { "Info" }
                    "WARN" { "Warning" }
                    "ERROR" { "Error" }
                    "SUCCESS" { "Success" }
                    "DEBUG" { "Info" }
                }

                Write-ColoredOutput -Message $Message -Level $uiLevel

                # 显示异常详情
                if ($Exception -and $VerbosePreference -ne 'SilentlyContinue') {
                    Write-ColoredOutput -Message "详细错误: $($Exception.Message)" -Level "Error" -Indent 1
                }
            } else {
                # 回退到基础输出
                $shouldDisplay = switch ($Level) {
                    "DEBUG" { $VerbosePreference -ne 'SilentlyContinue' }
                    "INFO" { $VerbosePreference -ne 'SilentlyContinue' -or $InformationPreference -ne 'SilentlyContinue' }
                    default { $true }
                }

                if ($shouldDisplay) {
                    $icon = switch ($Level) {
                        "INFO"    { "ℹ️ " }
                        "WARN"    { "⚠️ " }
                        "ERROR"   { "❌" }
                        "SUCCESS" { "✅" }
                        "DEBUG"   { "🔍" }
                    }

                    $color = switch ($Level) {
                        "INFO"    { "Cyan" }
                        "WARN"    { "Yellow" }
                        "ERROR"   { "Red" }
                        "SUCCESS" { "Green" }
                        "DEBUG"   { "Gray" }
                    }

                    Write-Host "$icon $Message" -ForegroundColor $color

                    # 显示异常详情
                    if ($Exception -and $VerbosePreference -ne 'SilentlyContinue') {
                        Write-Host "   详细错误: $($Exception.Message)" -ForegroundColor DarkRed
                    }
                }
            }
        }
        catch {
            # 日志记录失败时的备用处理
            Write-Warning "日志记录失败: $($_.Exception.Message)"
            Write-Host "[$Level] $Message" -ForegroundColor $(
                switch ($Level) {
                    "ERROR" { "Red" }
                    "WARN" { "Yellow" }
                    "SUCCESS" { "Green" }
                    default { "White" }
                }
            )
        }
    }
}

# --- 平台兼容性检查 ---
function Test-Platform {
    <#
    .SYNOPSIS
        检查平台兼容性和系统要求

    .DESCRIPTION
        验证当前系统是否满足 dotfiles 安装的基本要求

    .OUTPUTS
        [bool] 如果平台兼容返回 $true，否则抛出异常

    .EXAMPLE
        Test-Platform
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    begin {
        Write-Verbose "开始平台兼容性检查"
    }

    process {
        try {
            # 检查PowerShell版本
            $psVersion = $PSVersionTable.PSVersion
            $minVersion = [version]"5.1"

            if ($psVersion -lt $minVersion) {
                throw "PowerShell版本过低。当前版本: $psVersion，最低要求: $minVersion"
            }

            # 检查操作系统
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                # PowerShell Core/7+
                if (-not $IsWindows) {
                    throw "此脚本仅支持 Windows 平台。当前平台: $($PSVersionTable.OS)"
                }

                # 检查Windows版本
                $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
                if ($osInfo) {
                    $osVersion = [version]$osInfo.Version
                    $minOSVersion = [version]"10.0"  # Windows 10

                    if ($osVersion -lt $minOSVersion) {
                        Write-InstallLog "Windows版本较低，某些功能可能不可用。当前版本: $($osInfo.Caption)" "WARN"
                    }
                }
            } else {
                # Windows PowerShell 5.x (默认为Windows)
                if ($PSVersionTable.PSVersion.Major -lt 5) {
                    throw "PowerShell版本过低。当前版本: $($PSVersionTable.PSVersion)，最低要求: 5.1"
                }
            }

            # 检查.NET Framework版本（Windows PowerShell）
            if ($PSVersionTable.PSEdition -eq 'Desktop') {
                try {
                    $netVersion = Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -Name Release -ErrorAction SilentlyContinue
                    if ($netVersion -and $netVersion.Release -lt 461808) {  # .NET Framework 4.7.2
                        Write-InstallLog ".NET Framework版本较低，建议升级到4.7.2或更高版本" "WARN"
                    }
                } catch {
                    Write-InstallLog "无法检查.NET Framework版本" "WARN"
                }
            }

            # 检查执行策略
            $executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
            $restrictivePolicies = @('Restricted', 'AllSigned')

            if ($executionPolicy -in $restrictivePolicies) {
                Write-InstallLog "当前执行策略可能阻止脚本运行: $executionPolicy" "WARN"
                Write-InstallLog "建议运行: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" "INFO"
            }

            Write-InstallLog "平台兼容性检查通过: Windows PowerShell $($PSVersionTable.PSVersion)" "SUCCESS"
            return $true
        }
        catch {
            Write-InstallLog "平台兼容性检查失败" "ERROR" -Exception $_.Exception
            throw
        }
    }
}

# 执行平台检查
try {
    Test-Platform
}
catch {
    Write-InstallLog $_.Exception.Message "ERROR"
    exit 1
}

# --- 检查管理员权限 ---
function Test-AdminPrivileges {
    <#
    .SYNOPSIS
        检查当前用户是否具有管理员权限

    .DESCRIPTION
        检查当前PowerShell会话是否以管理员身份运行，
        如果没有管理员权限，提供提升权限的选项

    .PARAMETER AllowElevation
        是否允许自动提升权限

    .OUTPUTS
        [bool] 如果具有管理员权限返回 $true，否则返回 $false

    .EXAMPLE
        $isAdmin = Test-AdminPrivileges
        if (-not $isAdmin) { Write-Warning "需要管理员权限" }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [switch]$AllowElevation
    )

    begin {
        Write-Verbose "检查管理员权限"
    }

    process {
        try {
            # 检查当前用户权限
            $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
            $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

            if ($isAdmin) {
                Write-InstallLog "管理员权限检查通过" "SUCCESS"
                return $true
            }

            # 非管理员权限的处理
            Write-InstallLog "当前以普通用户权限运行" "WARN"
            Write-InstallLog "符号链接创建可能需要管理员权限" "INFO"

            # 在非DryRun模式下询问是否提升权限
            if (-not $DryRun -and $AllowElevation -and -not $Interactive) {
                $title = "权限提升"
                $message = "是否要以管理员身份重新运行此脚本？"
                $choices = @(
                    [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "以管理员身份重新运行")
                    [System.Management.Automation.Host.ChoiceDescription]::new("&No", "继续以当前权限运行")
                )

                $decision = $Host.UI.PromptForChoice($title, $message, $choices, 1)

                if ($decision -eq 0) {
                    try {
                        # 构建参数字符串
                        $argList = @("-File", "`"$PSCommandPath`"")

                        # 重建参数
                        foreach ($param in $PSBoundParameters.GetEnumerator()) {
                            if ($param.Value -is [switch] -and $param.Value) {
                                $argList += "-$($param.Key)"
                            } elseif ($param.Value -isnot [switch] -and $param.Value -ne $null) {
                                $argList += "-$($param.Key)"
                                if ($param.Value -is [array]) {
                                    $argList += ($param.Value -join ',')
                                } else {
                                    $argList += "`"$($param.Value)`""
                                }
                            }
                        }

                        Write-InstallLog "正在以管理员身份重新启动..." "INFO"

                        # 启动新的管理员进程
                        # 检查可用的PowerShell可执行文件
                        $psExecutable = if (Get-Command "pwsh" -ErrorAction SilentlyContinue) {
                            "pwsh"
                        } elseif (Get-Command "powershell" -ErrorAction SilentlyContinue) {
                            "powershell"
                        } else {
                            "powershell"  # 默认回退
                        }

                        $processInfo = @{
                            FilePath = $psExecutable
                            ArgumentList = $argList
                            Verb = "RunAs"
                            WindowStyle = "Normal"
                        }

                        Start-Process @processInfo
                        Write-InstallLog "已启动管理员进程，当前进程将退出" "INFO"
                        exit 0
                    }
                    catch {
                        Write-InstallLog "权限提升失败: $($_.Exception.Message)" "ERROR" -Exception $_.Exception
                        Write-InstallLog "继续以当前权限运行" "WARN"
                    }
                } else {
                    Write-InstallLog "用户选择继续以当前权限运行" "INFO"
                }
            } elseif ($Interactive) {
                Write-InstallLog "交互模式下将在需要时提示权限问题" "INFO"
            }

            return $false
        }
        catch {
            Write-InstallLog "权限检查过程中发生异常" "ERROR" -Exception $_.Exception
            return $false
        }
    }
}

$script:IsAdmin = Test-AdminPrivileges

# --- 初始化环境 ---
# 创建备份目录
if (-not (Test-Path $BackupDir)) {
    try {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        Write-InstallLog "创建备份目录: $BackupDir" "INFO"
    }
    catch {
        Write-InstallLog "无法创建备份目录 $BackupDir`: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

# 初始化日志
try {
    if (Test-Path $script:LogFile) {
        Add-Content -Path $script:LogFile -Value "`n--- New Installation Session: $(Get-Date) ---" -Encoding UTF8
    } else {
        "--- PowerShell Dotfiles Installation Log ---" | Out-File -FilePath $script:LogFile -Encoding UTF8
    }
    Write-InstallLog "日志初始化完成: $script:LogFile" "INFO"
}
catch {
    Write-Warning "日志初始化失败: $($_.Exception.Message)"
}

# --- 符号链接创建函数 ---
function New-SymbolicLinkSafe {
    <#
    .SYNOPSIS
        安全地创建符号链接

    .DESCRIPTION
        使用多种方法尝试创建符号链接，包括PowerShell原生方法和CMD备用方法

    .PARAMETER SourcePath
        源文件或目录的完整路径

    .PARAMETER TargetPath
        目标符号链接的完整路径

    .PARAMETER ConfigType
        配置类型（日志用）

    .PARAMETER Force
        是否强制覆盖现有文件

    .OUTPUTS
        [PSCustomObject] 包含Success和ErrorMessage属性的结果对象

    .EXAMPLE
        $result = New-SymbolicLinkSafe -SourcePath "C:\Source\file.txt" -TargetPath "C:\Target\file.txt" -ConfigType "Config"
        if ($result.Success) { Write-Host "链接创建成功" }
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "源路径不存在: $_"
            }
            $true
        })]
        [string]$SourcePath,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetPath,

        [Parameter(Mandatory, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigType,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-Verbose "开始创建符号链接: $SourcePath -> $TargetPath"

        # 初始化结果对象
        $result = [PSCustomObject]@{
            Success = $false
            ErrorMessage = ""
            Method = ""
            LinkType = ""
        }
    }

    process {
        try {
            # 规范化路径
            $SourcePath = Resolve-Path $SourcePath -ErrorAction Stop
            $TargetPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TargetPath)

            # 检查目标是否已存在
            if (Test-Path $TargetPath) {
                if (-not $Force) {
                    $result.ErrorMessage = "目标路径已存在且未指定Force参数: $TargetPath"
                    return $result
                }

                Write-Verbose "目标已存在，将被覆盖: $TargetPath"
                Remove-Item $TargetPath -Force -Recurse -ErrorAction SilentlyContinue
            }

            # 确保目标目录存在
            $targetDir = Split-Path $TargetPath -Parent
            if (-not (Test-Path $targetDir)) {
                if ($PSCmdlet.ShouldProcess($targetDir, "创建目录")) {
                    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                    Write-Verbose "创建目标目录: $targetDir"
                }
            }

            # 检查源是否为目录
            $isDirectory = Test-Path -Path $SourcePath -PathType Container
            $result.LinkType = if ($isDirectory) { "Directory" } else { "File" }

            # 方法1: 使用PowerShell原生New-Item
            if ($PSCmdlet.ShouldProcess($TargetPath, "创建符号链接")) {
                try {
                    Write-Verbose "尝试使用PowerShell New-Item创建符号链接"

                    $linkItem = New-Item -ItemType SymbolicLink -Path $TargetPath -Target $SourcePath -Force -ErrorAction Stop

                    # 验证链接
                    if ($linkItem -and $linkItem.LinkType -eq "SymbolicLink") {
                        $actualTarget = $linkItem.Target
                        if ($actualTarget -eq $SourcePath) {
                            $result.Success = $true
                            $result.Method = "PowerShell New-Item"
                            Write-Verbose "PowerShell方法成功创建符号链接"
                            return $result
                        } else {
                            Write-Verbose "链接目标验证失败: 期望 $SourcePath, 实际 $actualTarget"
                        }
                    }
                }
                catch {
                    Write-Verbose "PowerShell方法失败: $($_.Exception.Message)"
                }

                # 方法2: 使用CMD mklink作为备用方法
                try {
                    Write-Verbose "尝试使用CMD mklink创建符号链接"

                    $mklinkArgs = if ($isDirectory) { "/D" } else { "" }
                    $cmdCommand = "mklink $mklinkArgs `"$TargetPath`" `"$SourcePath`""

                    Write-Verbose "执行命令: cmd /c $cmdCommand"
                    $cmdOutput = cmd /c $cmdCommand 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        # 验证链接是否创建成功
                        if (Test-Path $TargetPath) {
                            $item = Get-Item $TargetPath -ErrorAction SilentlyContinue
                            if ($item -and $item.LinkType -eq "SymbolicLink") {
                                $result.Success = $true
                                $result.Method = "CMD mklink"
                                Write-Verbose "CMD方法成功创建符号链接"
                                return $result
                            }
                        }
                        $result.ErrorMessage = "CMD mklink执行成功但链接验证失败"
                    } else {
                        $result.ErrorMessage = "CMD mklink失败 (退出码: $LASTEXITCODE): $cmdOutput"
                    }
                }
                catch {
                    $result.ErrorMessage = "CMD方法异常: $($_.Exception.Message)"
                }

                # 方法3: 尝试复制文件作为最后的备用方案
                if (-not $isDirectory) {
                    try {
                        Write-Verbose "符号链接创建失败，尝试复制文件作为备用方案"
                        Copy-Item $SourcePath $TargetPath -Force -ErrorAction Stop
                        $result.Success = $true
                        $result.Method = "File Copy (Fallback)"
                        $result.ErrorMessage = "符号链接创建失败，已复制文件"
                        Write-Verbose "文件复制成功"
                        return $result
                    }
                    catch {
                        Write-Verbose "文件复制也失败: $($_.Exception.Message)"
                    }
                }
            }

            # 所有方法都失败
            if (-not $result.Success -and -not $result.ErrorMessage) {
                $result.ErrorMessage = "所有符号链接创建方法都失败"
            }

        }
        catch {
            $result.ErrorMessage = "符号链接创建过程中发生异常: $($_.Exception.Message)"
            Write-Verbose "异常详情: $($_.Exception.ToString())"
        }

        return $result
    }
}

# --- Windows版本和路径自适应函数 ---
function Get-AdaptiveConfigPaths {
    <#
    .SYNOPSIS
        根据Windows版本和环境自动检测配置文件路径

    .DESCRIPTION
        检测Windows版本、应用安装方式等，返回适合当前环境的配置文件路径

    .OUTPUTS
        [hashtable] 包含各应用配置路径的哈希表
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    begin {
        Write-Verbose "开始检测Windows版本和配置路径"
    }

    process {
        try {
            # 检测Windows版本
            $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
            $windowsVersion = if ($osInfo) {
                [version]$osInfo.Version
            } else {
                [version]"10.0.19041"  # 默认Windows 10
            }

            $isWindows11 = $windowsVersion.Build -ge 22000
            $windowsVersionName = if ($isWindows11) { "Windows 11" } else { "Windows 10" }

            Write-InstallLog "检测到系统版本: $windowsVersionName (Build $($windowsVersion.Build))" "INFO"

            # 初始化路径配置
            $paths = @{}

            # Windows Terminal 路径检测
            $wtPaths = @(
                "AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
                "AppData\Local\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
                "AppData\Local\Microsoft\Windows Terminal\settings.json"
            )

            $wtPath = $null
            foreach ($path in $wtPaths) {
                $fullPath = Join-Path $env:USERPROFILE $path
                $parentDir = Split-Path $fullPath -Parent
                if (Test-Path $parentDir) {
                    $wtPath = $path
                    Write-Verbose "找到Windows Terminal路径: $path"
                    break
                }
            }

            if (-not $wtPath) {
                $wtPath = $wtPaths[0]  # 默认使用第一个路径
                Write-InstallLog "未找到Windows Terminal安装，将使用默认路径: $wtPath" "WARN"
            }

            $paths["WindowsTerminal"] = $wtPath

            # WezTerm 路径检测
            # 优先使用 LocalAppData 目录下的配置文件，其次回退到用户主目录下的 .wezterm.lua
            $weztermRel = $null
            $wezLocal = Join-Path $env:LOCALAPPDATA 'wezterm'
            $wezLocalFile = Join-Path $wezLocal 'wezterm.lua'
            if ($env:LOCALAPPDATA -and (Test-Path $wezLocal)) {
                $weztermRel = 'AppData\Local\wezterm\wezterm.lua'
                Write-Verbose "找到WezTerm目录: $weztermRel"
            } elseif (Test-Path (Join-Path $env:USERPROFILE '.wezterm.lua')) {
                $weztermRel = '.wezterm.lua'
                Write-Verbose "检测到用户主目录下的 .wezterm.lua"
            } else {
                # 默认优先放置到 LocalAppData 路径
                $weztermRel = 'AppData\Local\wezterm\wezterm.lua'
                Write-InstallLog "未检测到WezTerm现有配置，将使用默认路径: $weztermRel" "WARN"
            }
            $paths['WezTerm'] = $weztermRel







            # PowerShell 路径检测
            $psVersion = $PSVersionTable.PSVersion.Major
            $psPath = if ($psVersion -ge 6) {
                "Documents\PowerShell"  # PowerShell Core/7+
            } else {
                "Documents\WindowsPowerShell"  # Windows PowerShell 5.x
            }

            $paths["PowerShell"] = $psPath
            Write-InstallLog "PowerShell版本: $($PSVersionTable.PSVersion), 配置路径: $psPath" "INFO"


            # Scoop 配置路径检测
            $scoopPath = if ($env:SCOOP) {
                # 若 SCOOP 位于用户目录下，返回相对 USERPROFILE 的路径；否则返回绝对路径
                $scoopFull = $env:SCOOP
                if ($env:USERPROFILE -and $scoopFull -like "${env:USERPROFILE}\*") {
                    $relativePath = $scoopFull.Substring($env:USERPROFILE.Length + 1)
                    "$relativePath\.config\scoop"
                } else {
                    # 绝对路径，后续不要与 $HOME 再拼接
                    (Join-Path $scoopFull ".config\scoop")
                }
            } elseif (Test-Path "$env:USERPROFILE\scoop") {
                "scoop\.config\scoop"
            } else {
                ".config\scoop"  # 默认路径
            }

            $paths["Scoop"] = $scoopPath

            # Starship 配置路径
            $paths["Starship"] = ".config"

            # Neovim 配置路径
            $paths["Neovim"] = "AppData\Local\nvim"

            # Alacritty 配置路径
            $paths["Alacritty"] = "AppData\Roaming\alacritty"

            return $paths
        }
        catch {
            Write-InstallLog "路径检测过程中发生异常: $($_.Exception.Message)" "ERROR" -Exception $_.Exception
            # 返回默认路径配置
            return @{
                "WindowsTerminal" = "AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
                "PowerShell" = "Documents\PowerShell"
                "WezTerm" = "AppData\Local\wezterm\wezterm.lua"
                "Scoop" = ".config\scoop"
                "Starship" = ".config"
                "Neovim" = "AppData\Local\nvim"
                "Alacritty" = "AppData\Roaming\alacritty"
            }
        }
    }
}

# 获取自适应路径配置
$adaptivePaths = Get-AdaptiveConfigPaths

# --- 定义要链接的配置文件 ---
# 使用自适应路径配置
$links = @{
    # Git - 强制使用符号链接以保持仓库配置同步
    "git\gitconfig"        = @{ Target = ".gitconfig";        Type = "Git"; ForceSymlink = $true };
    "git\gitignore_global" = @{ Target = ".gitignore_global"; Type = "Git"; ForceSymlink = $true };
    "git\gitmessage"       = @{ Target = ".gitmessage";       Type = "Git"; ForceSymlink = $true };
    "git\gitconfig.d"      = @{ Target = ".gitconfig.d";      Type = "Git"; ForceSymlink = $true };
    "git\gitconfig.local" = @{ Target = ".gitconfig.local";  Type = "Git"; ForceSymlink = $true };


    # PowerShell
    "powershell\Microsoft.PowerShell_profile.ps1" = @{ Target = "$($adaptivePaths['PowerShell'])\Microsoft.PowerShell_profile.ps1"; Type = "PowerShell" };
    "powershell\.powershell" = @{ Target = "$($adaptivePaths['PowerShell'])\.powershell"; Type = "PowerShell" };

    # Scoop (用户需要从 config.json.example 复制并自定义)
    # "scoop\config.json" = @{ Target = "$($adaptivePaths['Scoop'])\config.json"; Type = "Scoop"; ForceCopy = $true };

    # CMD (命令提示符别名)
    "scripts\cmd\aliases.cmd" = @{ Target = ".cmd\aliases.cmd"; Type = "CMD"; ForceCopy = $true };

    # Windows Terminal
    "WindowsTerminal\settings.json" = @{ Target = "$($adaptivePaths['WindowsTerminal'])"; Type = "WindowsTerminal" };

    # WezTerm
    "WezTerm\wezterm.lua" = @{ Target = "$($adaptivePaths['WezTerm'])"; Type = "WezTerm" };

    # Alacritty
    "Alacritty\alacritty.toml" = @{ Target = "$($adaptivePaths['Alacritty'])\alacritty.toml"; Type = "Alacritty" };





    # Starship
    "starship\starship.toml" = @{ Target = "$($adaptivePaths['Starship'])\starship.toml"; Type = "Starship" };

    # Neovim (强制符号链接整个配置目录)
    "neovim" = @{ Target = "$($adaptivePaths['Neovim'])"; Type = "Neovim"; ForceSymlink = $true };


}

# --- 增强功能脚本列表 ---
$enhancementScripts = @{
}

# --- 回滚功能 ---
function Start-Rollback {
    Write-InstallLog "开始回滚操作..." "INFO"

    if (-not (Test-Path $BackupDir)) {
        Write-InstallLog "备份目录不存在: $BackupDir" "ERROR"
        return $false
    }

    $backupFiles = Get-ChildItem -Path $BackupDir -Recurse -File
    $rolledBack = 0

    foreach ($backupFile in $backupFiles) {
        $relativePath = $backupFile.FullName.Substring($BackupDir.Length + 1)
        $originalPath = Join-Path $script:TargetDir $relativePath

        if (Test-Path $originalPath) {
            Remove-Item $originalPath -Force -Recurse
        }

        $originalDir = Split-Path $originalPath -Parent
        if (-not (Test-Path $originalDir)) {
            New-Item -ItemType Directory -Path $originalDir -Force | Out-Null
        }

        Copy-Item $backupFile.FullName $originalPath -Force
        Write-InstallLog "已恢复: $relativePath" "SUCCESS"
        $rolledBack++
    }

    Write-InstallLog "回滚完成，已恢复 $rolledBack 个文件" "SUCCESS"
    return $true
}

# --- 验证符号链接 ---
function Test-SymbolicLinks {
    Write-InstallLog "验证现有符号链接..." "INFO"

    $validLinks = 0
    $invalidLinks = 0

    foreach ($source in $links.Keys) {
        $meta = $links[$source]
        $target = $meta.Target
        $componentType = $meta.Type

        if ($Type -and ($Type -notcontains $componentType)) {
            continue
        }

        $sourcePath = Join-Path $script:SourceDir $source
        $targetPath = Join-Path $script:TargetDir $target

        if (Test-Path $targetPath) {
            $item = Get-Item $targetPath
            if ($item.LinkType -eq "SymbolicLink") {
                $actualTarget = $item.Target
                if ($actualTarget -eq $sourcePath) {
                    Write-InstallLog "✅ $target 正确链接到 $source" "SUCCESS"
                    $validLinks++
                } else {
                    Write-InstallLog "❌ $target 链接目标错误: $actualTarget" "ERROR"
                    $invalidLinks++
                }
            } else {
                Write-InstallLog "⚠️  $target 存在但不是符号链接" "WARN"
                $invalidLinks++
            }
        } else {
            Write-InstallLog "❌ $target 链接不存在" "ERROR"
            $invalidLinks++
        }
    }

    Write-Host "`n验证结果: $validLinks 有效, $invalidLinks 无效" -ForegroundColor $(if ($invalidLinks -eq 0) { "Green" } else { "Yellow" })
    return $invalidLinks -eq 0
}

# --- 处理开发模式设置 ---
if ($SetDevMode -or $UnsetDevMode) {
    $devModeFile = Join-Path $HOME '.dotfiles.dev-mode'

    if ($SetDevMode) {
        try {
            New-Item -Path $devModeFile -ItemType File -Force | Out-Null
            $env:DOTFILES_DEV_MODE = 'true'
            Write-Host "✅ 开发模式已启用" -ForegroundColor Green
            Write-Host "   - 创建标记文件: $devModeFile" -ForegroundColor Gray
            Write-Host "   - 后续安装将默认使用符号链接模式" -ForegroundColor Gray
            Write-Host "   - 可以使用 -UnsetDevMode 参数禁用" -ForegroundColor Gray
        }
        catch {
            Write-Host "❌ 启用开发模式失败: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }

    if ($UnsetDevMode) {
        try {
            if (Test-Path $devModeFile) {
                Remove-Item $devModeFile -Force
            }
            $env:DOTFILES_DEV_MODE = ''
            Write-Host "✅ 开发模式已禁用" -ForegroundColor Green
            Write-Host "   - 删除标记文件: $devModeFile" -ForegroundColor Gray
            Write-Host "   - 后续安装将默认使用复制模式" -ForegroundColor Gray
        }
        catch {
            Write-Host "❌ 禁用开发模式失败: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }

    exit 0
}

# --- 处理回滚和验证选项 ---
if ($Rollback) {
    Start-Rollback
    exit 0
}

if ($Validate) {
    Test-SymbolicLinks
    exit 0
}

# 显示安装开始信息
if ($script:UseEnhancedUI) {
    $subtitle = if ($script:EffectiveMode -eq 'Symlink') { '通过符号链接部署配置文件' } else { '复制部署配置文件' }
    Write-Banner -Title "DOTFILES 配置部署" -Subtitle $subtitle

    if ($DryRun) {
        $dryMsg = if ($script:EffectiveMode -eq 'Symlink') { '🔍 预览模式 - 不会实际创建链接' } else { '🔍 预览模式 - 不会实际复制文件' }
        Write-WarningMessage $dryMsg
    }
    if ($Interactive) {
        Write-InfoMessage "🤝 交互模式 - 将逐个确认操作"
    }
} else {
    $startMsg = if ($script:EffectiveMode -eq 'Symlink') { '开始创建符号链接...' } else { '开始复制配置文件...' }
    Write-InstallLog $startMsg "INFO"
    if ($DryRun) {
        $dryMsg = if ($script:EffectiveMode -eq 'Symlink') { '🔍 预览模式 - 不会实际创建链接' } else { '🔍 预览模式 - 不会实际复制文件' }
        Write-Host $dryMsg -ForegroundColor Yellow
    }
    if ($Interactive) {
        Write-Host "🤝 交互模式 - 将逐个确认操作" -ForegroundColor Yellow
    }
}

$targetTypes = @()
# 规范化传入的 Type 参数，确保为字符串数组且过滤空值
if ($PSBoundParameters.ContainsKey('Type') -and $null -ne $Type) {
    $targetTypes = @($Type) | Where-Object { $_ -and $_.ToString().Trim().Length -gt 0 }
}
$totalLinks = @(
    $links.Keys |
    Where-Object {
        if (@($targetTypes).Count -eq 0) { return $true }
        $targetTypes -contains $links[$_].Type
    }
).Count
$currentLink = 0

# 初始化进度管理器
if ($script:UseEnhancedUI -and -not $DryRun) {
    $script:ProgressManager = [ProgressManager]::new("部署配置文件", $totalLinks)
}

foreach ($source in $links.Keys) {
    $meta = $links[$source]
    $target = $meta.Target
    $componentType = $meta.Type

    # 如果指定了 Type 参数，只处理匹配类型
    $targetTypes = @()
    if ($PSBoundParameters.ContainsKey('Type') -and $null -ne $Type) {
        $targetTypes = @($Type) | Where-Object { $_ -and $_.ToString().Trim().Length -gt 0 }
    }
    if (@($targetTypes).Count -gt 0 -and ($targetTypes -notcontains $componentType)) { continue }

    $currentLink++
    $sourcePath = Join-Path $script:SourceDir $source
    if ([System.IO.Path]::IsPathRooted($target)) {
        # 目标为绝对路径时，直接使用，避免与 $HOME 重复拼接
        $targetPath = $target
    } else {
        $targetPath = Join-Path $script:TargetDir $target
    }

    # 更新进度
    if ($script:UseEnhancedUI -and $script:ProgressManager) {
        $script:ProgressManager.NextStep("处理 $componentType 配置")
        Write-Section -Title "处理 $componentType 配置" -Icon "⚙️"
    } else {
        Write-Host "`n[$currentLink/$totalLinks] 处理 $componentType 配置..." -ForegroundColor Cyan
    }

    # 确保源文件存在
    if (-not (Test-Path $sourcePath)) {
        Write-InstallLog "源文件不存在: $sourcePath" "WARN"
        $script:InstallResults.Skipped += "$componentType - 源文件不存在"
        continue
    }

    # 交互式确认
    if ($Interactive -and -not $DryRun) {
        if ($script:UseEnhancedUI) {
            $options = @("是，创建符号链接", "否，跳过此配置", "全部自动处理")
            $choice = Read-UserChoice -Title "是否创建 $componentType 的符号链接？" -Options $options -DefaultIndex 0

            switch ($choice) {
                0 { # 是
                    # 继续处理
                }
                1 { # 否
                    Write-InstallLog "用户跳过: $componentType" "INFO"
                    $script:InstallResults.Skipped += "$componentType - 用户跳过"
                    continue
                }
                2 { # 全部自动处理
                    $Interactive = $false
                }
            }
        } else {
            $response = Read-Host "是否创建 $componentType 的符号链接？(y/N/a=all)"
            if ($response -eq 'a' -or $response -eq 'A') {
                $Interactive = $false  # 后续全部自动处理
            } elseif ($response -ne 'y' -and $response -ne 'Y') {
                Write-InstallLog "用户跳过: $componentType" "INFO"
                $script:InstallResults.Skipped += "$componentType - 用户跳过"
                continue
            }
        }
    }

    # 确保目标目录存在
    $targetParentDir = Split-Path -Path $targetPath -Parent
    if (-not (Test-Path $targetParentDir)) {
        if ($DryRun) {
            Write-Host "[预览] 将创建目标目录: $targetParentDir" -ForegroundColor DarkCyan
        } else {
            Write-InstallLog "创建目标目录: $targetParentDir" "INFO"
            New-Item -ItemType Directory -Path $targetParentDir -Force | Out-Null
        }
    }

    # 处理现有文件或链接
    if (Test-Path $targetPath) {
        $item = Get-Item $targetPath
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

        if ($item.LinkType -eq "SymbolicLink") {
            if ($item.Target -eq $sourcePath) {
                Write-InstallLog "$componentType 链接已存在且正确" "SUCCESS"
                $script:InstallResults.Success += "$componentType - 已存在"
                continue
            } else {
                Write-InstallLog "$componentType 链接存在但目标错误" "WARN"
            }
        }

        # 创建备份
        $backupPath = Join-Path $BackupDir "$componentType-$timestamp-$(Split-Path $targetPath -Leaf)"

        if ($Force -or $DryRun) {
            if ($DryRun) {
                Write-Host "[预览] 将备份到: $backupPath" -ForegroundColor DarkYellow
            } else {
                $backupParentDir = Split-Path $backupPath -Parent
                if (-not (Test-Path $backupParentDir)) {
                    New-Item -ItemType Directory -Path $backupParentDir -Force | Out-Null
                }

                if ($item.LinkType -eq "SymbolicLink") {
                    Remove-Item $targetPath -Force
                    Write-InstallLog "删除旧符号链接: $targetPath" "INFO"
                } else {
                    Move-Item -Path $targetPath -Destination $backupPath -Force
                    Write-InstallLog "备份现有文件到: $backupPath" "INFO"
                    $script:InstallResults.Backed += "$componentType -> $backupPath"
                }
            }
        } else {
            Write-InstallLog "$componentType 目标已存在，使用 -Force 参数强制覆盖" "ERROR"
            $script:InstallResults.Failed += "$componentType - 目标已存在"
            continue
        }
    }

    # 检查是否强制复制/强制符号链接模式
    $forceCopy = $meta.ContainsKey('ForceCopy') -and $meta.ForceCopy -eq $true
    $forceSymlink = $meta.ContainsKey('ForceSymlink') -and $meta.ForceSymlink -eq $true
    $actualMode = if ($forceCopy) { 'Copy' } elseif ($forceSymlink) { 'Symlink' } else { $script:EffectiveMode }

    # 执行复制或符号链接
    if ($DryRun) {
        $op = if ($actualMode -eq 'Symlink') { '链接' } else { '复制' }
        if ($forceCopy) {
            Write-Host "[预览] ($op) $sourcePath -> $targetPath ($componentType) [强制复制]" -ForegroundColor Gray
        } elseif ($forceSymlink) {
            Write-Host "[预览] ($op) $sourcePath -> $targetPath ($componentType) [强制符号链接]" -ForegroundColor Gray
        } else {
            Write-Host "[预览] ($op) $sourcePath -> $targetPath ($componentType)" -ForegroundColor Gray
        }
        $script:InstallResults.Success += "$componentType - 预览"
        continue
    }

    if ($actualMode -eq 'Copy') {
        try {
            $isDir = Test-Path $sourcePath -PathType Container
            if ($isDir) {
                Write-InstallLog "复制目录: $sourcePath -> $targetPath" "INFO"
                Copy-Item -Path $sourcePath -Destination $targetPath -Recurse -Force
            } else {
                Write-InstallLog "复制文件: $sourcePath -> $targetPath" "INFO"
                Copy-Item -Path $sourcePath -Destination $targetPath -Force
            }
            Write-InstallLog "$componentType 复制成功" "SUCCESS"
            $script:InstallResults.Success += "$componentType"
        }
        catch {
            Write-InstallLog "$componentType 复制失败: $($_.Exception.Message)" "ERROR" -Exception $_.Exception
            $script:InstallResults.Failed += "$componentType - $($_.Exception.Message)"
        }
        continue
    }
    else {
        if ($forceCopy) {
            Write-InstallLog "$componentType 配置被设置为强制复制模式，跳过符号链接创建" "WARN"
            $script:InstallResults.Skipped += "$componentType - 强制复制模式"
            continue
        }
        Write-InstallLog "创建符号链接: $sourcePath -> $targetPath" "INFO"
        try {
            $linkResult = New-SymbolicLinkSafe -SourcePath $sourcePath -TargetPath $targetPath -ConfigType ([string]$componentType)
            if ($linkResult.Success) {
                Write-InstallLog "$componentType 符号链接创建成功" "SUCCESS"
                $script:InstallResults.Success += "$componentType"
            } else {
                Write-InstallLog "$componentType 符号链接创建失败: $($linkResult.ErrorMessage)" "ERROR"
                $script:InstallResults.Failed += "$componentType - $($linkResult.ErrorMessage)"
            }
        } catch {
            Write-InstallLog "$componentType 符号链接创建异常: $($_.Exception.Message)" "ERROR"
            $script:InstallResults.Failed += "$componentType - 异常: $($_.Exception.Message)"
        }
    }
}

# 完成进度管理器
if ($script:UseEnhancedUI -and $script:ProgressManager) {
    $script:ProgressManager.Complete()
}

# --- 安装结果报告 ---
if ($script:UseEnhancedUI) {
    $summaryItems = @{
        "Success" = $script:InstallResults.Success
        "Failed" = $script:InstallResults.Failed
        "Skipped" = $script:InstallResults.Skipped
        "Backed" = $script:InstallResults.Backed
    }

    Write-Summary -Title "DOTFILES 安装结果报告" -Items $summaryItems -ShowCounts

    # 显示下一步操作
    if ($script:InstallResults.Success.Count -gt 0) {
        $nextSteps = @(
            "重启终端以应用新配置",
            "运行 'health-check.ps1' 验证配置",
            "设置Git用户信息（如果尚未设置）",
            "查看 README.md 了解更多功能"
        )
        Show-NextSteps -Steps $nextSteps
    }

    # 显示提示
    if ($script:InstallResults.Failed.Count -gt 0) {
        $tips = @(
            "检查是否以管理员身份运行PowerShell",
            "确保目标目录有写入权限",
            "使用 -Force 参数强制覆盖现有文件",
            "查看日志文件了解详细错误信息"
        )
        Show-Tips -Tips $tips -Title "🔧 故障排除提示"
    }
} else {
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "           DOTFILES 安装结果报告" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan

    Write-Host "`n✅ 成功 ($($script:InstallResults.Success.Count)):" -ForegroundColor Green
    foreach ($item in $script:InstallResults.Success) {
        Write-Host "   • $item" -ForegroundColor Gray
    }

    if ($script:InstallResults.Backed.Count -gt 0) {
        Write-Host "`n💾 已备份 ($($script:InstallResults.Backed.Count)):" -ForegroundColor Blue
        foreach ($item in $script:InstallResults.Backed) {
            Write-Host "   • $item" -ForegroundColor Gray
        }
    }

    if ($script:InstallResults.Skipped.Count -gt 0) {
        Write-Host "`n⏭️  跳过 ($($script:InstallResults.Skipped.Count)):" -ForegroundColor Yellow
        foreach ($item in $script:InstallResults.Skipped) {
            Write-Host "   • $item" -ForegroundColor Gray
        }
    }

    if ($script:InstallResults.Failed.Count -gt 0) {
        Write-Host "`n❌ 失败 ($($script:InstallResults.Failed.Count)):" -ForegroundColor Red
        foreach ($item in $script:InstallResults.Failed) {
            Write-Host "   • $item" -ForegroundColor Gray
        }
    }

    Write-Host "`n" + "="*60 -ForegroundColor Cyan
}

# 总结信息
$totalProcessed = $script:InstallResults.Success.Count + $script:InstallResults.Failed.Count + $script:InstallResults.Skipped.Count
$modeInfo = if ($script:IsDevMode) { "开发模式 (符号链接)" } else { "生产模式 (复制文件)" }

if ($script:InstallResults.Failed.Count -eq 0) {
    Write-Host "🎉 安装完成！所有配置都已成功处理。($modeInfo)" -ForegroundColor Green
} else {
    Write-Host "⚠️  安装完成，但有 $($script:InstallResults.Failed.Count) 项失败。($modeInfo)" -ForegroundColor Yellow
}

# 后续建议
Write-Host "`n💡 建议:" -ForegroundColor Cyan
Write-Host "   • 运行 health-check.ps1 验证配置" -ForegroundColor Gray
Write-Host "   • 查看日志: $script:LogFile" -ForegroundColor Gray
if ($script:InstallResults.Backed.Count -gt 0) {
    Write-Host "   • 备份位置: $BackupDir" -ForegroundColor Gray
    Write-Host "   • 如需回滚: .\install.ps1 -Rollback" -ForegroundColor Gray
}

# 开发模式提示
if (-not $script:IsDevMode) {
    Write-Host "`n🔧 开发者提示:" -ForegroundColor Yellow
    Write-Host "   • 如需启用开发模式（符号链接）: .\install.ps1 -SetDevMode" -ForegroundColor Gray
    Write-Host "   • 开发模式便于实时编辑配置文件" -ForegroundColor Gray
} else {
    Write-Host "`n🔧 开发模式已启用:" -ForegroundColor Green
    Write-Host "   • 配置文件通过符号链接安装，可直接编辑源文件" -ForegroundColor Gray
    Write-Host "   • 如需禁用开发模式: .\install.ps1 -UnsetDevMode" -ForegroundColor Gray
}

Write-Host "`n🚀 增强功能:" -ForegroundColor Cyan
foreach ($feature in $enhancementScripts.Keys) {
    $script = $enhancementScripts[$feature]
    Write-Host "   • $feature : .\$($script.Script) $($script.Command)" -ForegroundColor Gray
}

Write-InstallLog "安装会话完成 - 成功: $($script:InstallResults.Success.Count), 失败: $($script:InstallResults.Failed.Count), 跳过: $($script:InstallResults.Skipped.Count)" "INFO"
