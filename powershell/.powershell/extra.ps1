# ~/.powershell/extra.ps1
# 智能代理管理 - 默认系统代理，支持快速切换本地代理

# 代理配置 - 本地代理端口映射
$global:ProxyPorts = @{
    "clash" = 7890
    "v2ray" = 10808
    "singbox" = 7890
    "sing" = 7890  # singbox 别名
}

# 获取系统代理设置
function Get-SystemProxy {
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        $proxyEnable = Get-ItemProperty -Path $regPath -Name "ProxyEnable" -ErrorAction SilentlyContinue
        $proxyServer = Get-ItemProperty -Path $regPath -Name "ProxyServer" -ErrorAction SilentlyContinue

        if ($proxyEnable.ProxyEnable -eq 1 -and $proxyServer.ProxyServer) {
            return $proxyServer.ProxyServer
        }
    } catch {
        # 忽略错误，返回 null
    }
    return $null
}

# 启用系统代理
function px-system {
    $systemProxy = Get-SystemProxy
    if ($systemProxy) {
        # 解析系统代理地址
        if ($systemProxy -match "^([^:]+):(\d+)$") {
            $proxyHost = $matches[1]
            $proxyPort = $matches[2]
            $proxyUrl = "http://${proxyHost}:${proxyPort}"
        } else {
            $proxyUrl = "http://$systemProxy"
        }

        $env:HTTP_PROXY = $proxyUrl
        $env:HTTPS_PROXY = $proxyUrl
        $env:ALL_PROXY = $systemProxy

        # Git代理通过环境变量设置，避免修改全局配置文件
        # Git会自动使用 HTTP_PROXY 和 HTTPS_PROXY 环境变量

        Write-Host "🌐 系统代理已启用: $proxyUrl" -ForegroundColor Green
        return $true
    } else {
        Write-Host "⚠️  未检测到系统代理设置" -ForegroundColor Yellow
        return $false
    }
}

# 启用本地代理
function px-local {
    param([int]$Port)

    $proxyUrl = "http://127.0.0.1:$Port"
    $env:HTTP_PROXY = $proxyUrl
    $env:HTTPS_PROXY = $proxyUrl
    $env:ALL_PROXY = "127.0.0.1:$Port"

    # Git代理通过环境变量设置，避免修改全局配置文件
    # Git会自动使用 HTTP_PROXY 和 HTTPS_PROXY 环境变量

    Write-Host "🚀 本地代理已启用: $proxyUrl" -ForegroundColor Green
}

# 快速禁用代理
function px-off {
    Remove-Item Env:HTTP_PROXY,Env:HTTPS_PROXY,Env:ALL_PROXY -ErrorAction SilentlyContinue

    # 清除环境变量即可，不需要修改Git配置文件
    # 如果之前有全局配置，可手动清理：
    # git config --global --unset http.proxy
    # git config --global --unset https.proxy

    Write-Host "⏹️  代理已禁用" -ForegroundColor Yellow
}

# 主代理切换函数
function px {
    param([string]$Target = "status")

    switch ($Target.ToLower()) {
        "clash" { px-local -Port $global:ProxyPorts.clash }
        "v2ray" { px-local -Port $global:ProxyPorts.v2ray }
        "singbox" { px-local -Port $global:ProxyPorts.singbox }
        "sing" { px-local -Port $global:ProxyPorts.sing }
        "system" { px-system }
        "off" { px-off }
        "status" {
            Write-Host "🌐 代理状态:" -ForegroundColor Cyan
            if ($env:HTTP_PROXY) {
                $proxyType = if ($env:HTTP_PROXY -match "127\.0\.0\.1") { "本地代理" } else { "系统代理" }
                Write-Host "  ✅ 已启用 ($proxyType): $env:HTTP_PROXY" -ForegroundColor Green
            } else {
                Write-Host "  ❌ 已禁用" -ForegroundColor Red
            }

            # 显示系统代理状态
            $systemProxy = Get-SystemProxy
            if ($systemProxy) {
                Write-Host "  🌐 系统代理: $systemProxy" -ForegroundColor Blue
            } else {
                Write-Host "  🌐 系统代理: 未设置" -ForegroundColor Gray
            }

            Write-Host ""
            Write-Host "📋 可用选项:" -ForegroundColor Gray
            Write-Host "  system        - 使用系统代理设置" -ForegroundColor Gray
            Write-Host "  clash         - Clash (7890)" -ForegroundColor Gray
            Write-Host "  v2ray         - V2Ray (10808)" -ForegroundColor Gray
            Write-Host "  singbox       - SingBox (7890)" -ForegroundColor Gray
            Write-Host "  off           - 禁用代理" -ForegroundColor Gray
            Write-Host "  <端口号>      - 自定义本地端口" -ForegroundColor Gray
            Write-Host ""
            Write-Host "💡 默认策略: 优先使用系统代理，支持快速切换本地代理" -ForegroundColor DarkGray
        }
        default {
            if ($Target -match '^\d+$') {
                px-local -Port ([int]$Target)
            } else {
                Write-Host "❌ 无效选项: $Target" -ForegroundColor Red
                Write-Host "💡 使用 'px status' 查看可用选项" -ForegroundColor Yellow
            }
        }
    }
}

# 测试代理连接
function px-test {
    param([string]$Url = "https://www.google.com")

    Write-Host "🔍 测试代理连接..." -ForegroundColor Cyan
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 10 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host "✅ 代理连接正常" -ForegroundColor Green
        }
    } catch {
        Write-Host "❌ 代理连接失败: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 智能代理切换 (优先系统代理，然后检测本地代理)
function px-auto {
    Write-Host "🔍 智能代理检测..." -ForegroundColor Cyan

    # 1. 首先尝试系统代理
    Write-Host "1️⃣  检查系统代理..." -ForegroundColor Gray
    if (px-system) {
        return
    }

    # 2. 检测本地代理端口可用性
    Write-Host "2️⃣  检测本地代理端口..." -ForegroundColor Gray
    $availableProxies = @()

    foreach ($proxy in $global:ProxyPorts.GetEnumerator()) {
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $connectTask = $tcpClient.ConnectAsync("127.0.0.1", $proxy.Value)
            if ($connectTask.Wait(1000) -and $tcpClient.Connected) {
                $availableProxies += @{ Name = $proxy.Key; Port = $proxy.Value }
                Write-Host "  ✅ $($proxy.Key) ($($proxy.Value)) 可用" -ForegroundColor Green
                $tcpClient.Close()
            } else {
                Write-Host "  ❌ $($proxy.Key) ($($proxy.Value)) 不可用" -ForegroundColor Red
                $tcpClient.Close()
            }
        } catch {
            Write-Host "  ❌ $($proxy.Key) ($($proxy.Value)) 连接失败" -ForegroundColor Red
        }
    }

    # 3. 使用第一个可用的本地代理
    if ($availableProxies.Count -gt 0) {
        $selectedProxy = $availableProxies[0]
        Write-Host "3️⃣  使用本地代理: $($selectedProxy.Name) ($($selectedProxy.Port))" -ForegroundColor Yellow
        px-local -Port $selectedProxy.Port
    } else {
        Write-Host "⚠️  未发现任何可用代理，建议手动配置" -ForegroundColor Yellow
        Write-Host "💡 使用 'px system' 启用系统代理或 'px <应用名>' 启用特定本地代理" -ForegroundColor Gray
    }
}

# 初始化代理设置 (启动时自动应用系统代理)
function Initialize-ProxySettings {
    # 静默尝试启用系统代理，不显示输出
    $systemProxy = Get-SystemProxy
    if ($systemProxy) {
        if ($systemProxy -match "^([^:]+):(\d+)$") {
            $proxyHost = $matches[1]
            $proxyPort = $matches[2]
            $proxyUrl = "http://${proxyHost}:${proxyPort}"
        } else {
            $proxyUrl = "http://$systemProxy"
        }

        $env:HTTP_PROXY = $proxyUrl
        $env:HTTPS_PROXY = $proxyUrl
        $env:ALL_PROXY = $systemProxy

        # Git代理通过环境变量设置，避免修改全局配置文件
        # Git会自动使用 HTTP_PROXY 和 HTTPS_PROXY 环境变量
    }
}

# 启动时自动初始化代理设置
if (-not $env:POWERSHELL_FAST_MODE) {
    Initialize-ProxySettings
}
