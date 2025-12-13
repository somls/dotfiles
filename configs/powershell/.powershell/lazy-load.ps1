# ~/.powershell/lazy-load.ps1
# 延迟加载机制 - 提升 PowerShell 启动性能
# 将重量级工具的初始化延迟到首次使用时

<#
.SYNOPSIS
延迟加载系统 - 按需初始化工具，显著提升启动速度

.DESCRIPTION
此系统将重量级工具（如 conda, fnm, nvm 等）的初始化推迟到首次调用时。
这可以将 PowerShell 启动时间从 2-3 秒减少到 500ms 以下。

.EXAMPLE
# 注册延迟加载命令
Register-LazyLoadCommand -Command 'conda' -Initializer {
    (& conda 'shell.powershell' 'hook') | Out-String | Invoke-Expression
}

# 首次调用 conda 时，会自动初始化并执行命令
conda activate myenv
#>

# 延迟加载命令注册表
$global:__LazyLoadCommands = @{}

function Register-LazyLoadCommand {
    <#
    .SYNOPSIS
    注册需要延迟加载的命令

    .PARAMETER Command
    命令名称（如 'conda', 'fnm', 'nvm'）

    .PARAMETER Initializer
    初始化脚本块，返回初始化命令

    .PARAMETER CheckExistence
    是否检查命令存在性（默认 $true）

    .EXAMPLE
    Register-LazyLoadCommand -Command 'conda' -Initializer {
        (& conda 'shell.powershell' 'hook') | Out-String | Invoke-Expression
    }
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter(Mandatory)]
        [scriptblock]$Initializer,

        [bool]$CheckExistence = $true
    )

    # 如果需要检查存在性，且命令不存在，则跳过
    if ($CheckExistence -and -not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Verbose "Command '$Command' not found, skipping lazy load registration"
        return
    }

    # 存储初始化器
    $global:__LazyLoadCommands[$Command] = $Initializer

    # 创建包装函数
    $wrapper = {
        param($CommandName, $args)

        # 获取初始化器
        $initializer = $global:__LazyLoadCommands[$CommandName]

        if ($initializer) {
            Write-Verbose "Lazy loading '$CommandName'..."

            # 移除延迟加载包装器
            Remove-Item -Path "Function:\$CommandName" -ErrorAction SilentlyContinue
            $global:__LazyLoadCommands.Remove($CommandName)

            # 执行初始化
            try {
                & $initializer
                Write-Verbose "'$CommandName' initialized successfully"
            } catch {
                Write-Warning "Failed to initialize '$CommandName': $($_.Exception.Message)"
                return
            }

            # 重新调用原始命令
            if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
                & $CommandName @args
            } else {
                Write-Error "Command '$CommandName' not available after initialization"
            }
        }
    }.GetNewClosure()

    # 创建函数别名（不是真正的 alias，而是函数）
    $functionDef = "function global:$Command { `$wrapper.Invoke('$Command', `$args) }"
    Invoke-Expression $functionDef
}

# --- 预定义的常用工具延迟加载配置 ---

# Conda 环境管理
if (Get-Command conda -ErrorAction SilentlyContinue) {
    Register-LazyLoadCommand -Command 'conda' -Initializer {
        (& conda 'shell.powershell' 'hook') | Out-String | Invoke-Expression
    }
}

# fnm (Fast Node Manager)
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    Register-LazyLoadCommand -Command 'fnm' -Initializer {
        fnm env --use-on-cd | Out-String | Invoke-Expression
    }
}

# nvm (Node Version Manager) for Windows
if (Get-Command nvm -ErrorAction SilentlyContinue) {
    Register-LazyLoadCommand -Command 'nvm' -Initializer {
        # nvm for Windows doesn't require shell integration
        # Just ensure it's in PATH
        $nvmPath = (Get-Command nvm).Source | Split-Path
        if ($nvmPath -notin $env:PATH.Split(';')) {
            $env:PATH = "$nvmPath;$env:PATH"
        }
    }
}

# pyenv (Python version manager)
if (Get-Command pyenv -ErrorAction SilentlyContinue) {
    Register-LazyLoadCommand -Command 'pyenv' -Initializer {
        # pyenv for Windows initialization
        $env:PYENV_ROOT = "$env:USERPROFILE\.pyenv\pyenv-win"
        $env:PATH = "$env:PYENV_ROOT\bin;$env:PYENV_ROOT\shims;$env:PATH"
    }
}

# rbenv (Ruby version manager)
if (Get-Command rbenv -ErrorAction SilentlyContinue) {
    Register-LazyLoadCommand -Command 'rbenv' -Initializer {
        & rbenv init - | Out-String | Invoke-Expression
    }
}

# --- 实用函数 ---

function Get-LazyLoadStatus {
    <#
    .SYNOPSIS
    显示延迟加载命令的状态

    .DESCRIPTION
    列出所有注册的延迟加载命令及其初始化状态
    #>
    Write-Host "`nLazy Load Status" -ForegroundColor Cyan
    Write-Host ("=" * 40) -ForegroundColor Gray

    if ($global:__LazyLoadCommands.Count -eq 0) {
        Write-Host "No commands registered for lazy loading" -ForegroundColor Yellow
        Write-Host "(All registered commands have been initialized)" -ForegroundColor Gray
    } else {
        Write-Host "Pending lazy load commands:" -ForegroundColor Yellow
        foreach ($cmd in $global:__LazyLoadCommands.Keys) {
            Write-Host "  - $cmd" -ForegroundColor Green
        }
    }
    Write-Host ""
}

function Clear-LazyLoadCache {
    <#
    .SYNOPSIS
    清除延迟加载缓存并重新注册

    .DESCRIPTION
    重置延迟加载系统，移除所有包装器并重新加载此配置文件
    #>
    foreach ($cmd in $global:__LazyLoadCommands.Keys) {
        Remove-Item -Path "Function:\$cmd" -ErrorAction SilentlyContinue
    }
    $global:__LazyLoadCommands.Clear()

    Write-Host "Lazy load cache cleared" -ForegroundColor Green
    Write-Host "Reloading lazy-load.ps1..." -ForegroundColor Cyan

    # 重新加载此文件
    $lazyLoadScript = $PSCommandPath
    if ($lazyLoadScript -and (Test-Path $lazyLoadScript)) {
        . $lazyLoadScript
    }
}

# 添加别名
Set-Alias -Name lazy-status -Value Get-LazyLoadStatus -Option AllScope
Set-Alias -Name lazy-clear -Value Clear-LazyLoadCache -Option AllScope

Write-Verbose "Lazy load system initialized with $($global:__LazyLoadCommands.Count) commands"
