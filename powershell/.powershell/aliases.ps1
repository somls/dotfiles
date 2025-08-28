# ~/.powershell/aliases.ps1
# 核心别名 - 高效/简洁/实用
# Last Modified: 2025-08-13

<#
说明：
1) 统一采用"存在则跳过"的方式设置别名，避免重复定义导致的加载错误。
2) 默认不抢占常用简写（如 c）以避免冲突。
3) 仅在函数或命令存在时创建别名（如 upd -> sys-update）。
#>

# --- 导航与文件操作别名 ---
if (-not (Get-Alias -Name ls -ErrorAction SilentlyContinue)) {
    Set-Alias -Name ls -Value Get-ChildItem -Option AllScope
}
if (-not (Get-Alias -Name l -ErrorAction SilentlyContinue)) {
    Set-Alias -Name l -Value Get-ChildItem -Option AllScope
}
if (-not (Get-Alias -Name ll -ErrorAction SilentlyContinue)) {
    function ll { Get-ChildItem -Force @args }
}
if (-not (Get-Alias -Name .. -ErrorAction SilentlyContinue)) {
    function .. { Set-Location .. }
}
if (-not (Get-Alias -Name ... -ErrorAction SilentlyContinue)) {
    function ... { Set-Location ..\.. }
}
if (-not (Get-Alias -Name la -ErrorAction SilentlyContinue)) {
    function la { Get-ChildItem -Force @args }
}
if (-not (Get-Alias -Name e -ErrorAction SilentlyContinue) -and (Get-Command explorer -ErrorAction SilentlyContinue)) {
    Set-Alias -Name e -Value explorer -Option AllScope
}
if (-not (Get-Alias -Name n -ErrorAction SilentlyContinue) -and (Get-Command notepad -ErrorAction SilentlyContinue)) {
    Set-Alias -Name n -Value notepad -Option AllScope
}

# --- 文件和目录操作 ---
if (-not (Get-Alias -Name md -ErrorAction SilentlyContinue)) {
    Set-Alias -Name md -Value New-Directory -Option AllScope
}
if (-not (Get-Alias -Name size -ErrorAction SilentlyContinue)) {
    Set-Alias -Name size -Value Get-FileSize -Option AllScope
}

# --- 系统管理 ---
if (-not (Get-Alias -Name sudo -ErrorAction SilentlyContinue)) {
    Set-Alias -Name sudo -Value Start-Elevated -Option AllScope
}
if ((Get-Command sys-update -ErrorAction SilentlyContinue) -and -not (Get-Alias -Name upd -ErrorAction SilentlyContinue)) {
    Set-Alias -Name upd -Value sys-update -Option AllScope
}
if ((Get-Command sysinfo -ErrorAction SilentlyContinue) -and -not (Get-Alias -Name info -ErrorAction SilentlyContinue)) {
    Set-Alias -Name info -Value sysinfo -Option AllScope
}

# --- 编辑器别名（如果存在） ---
# VSCode aliases removed - no longer supported

# --- 工具别名（仅在工具存在时设置） ---
if (Get-Command bat -ErrorAction SilentlyContinue) {
    if (-not (Get-Alias -Name cat -ErrorAction SilentlyContinue)) {
        Set-Alias -Name cat -Value bat -Option AllScope
    }
}

if (Get-Command rg -ErrorAction SilentlyContinue) {
    if (-not (Get-Alias -Name grep -ErrorAction SilentlyContinue)) {
        Set-Alias -Name grep -Value rg -Option AllScope
    }
}
