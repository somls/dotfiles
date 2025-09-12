# ~/.powershell/extra.ps1
# Simplified proxy management

# Proxy configuration - local proxy port mapping
$global:ProxyPorts = @{
    "clash" = 7890
    "v2ray" = 10808
    "singbox" = 7890
}

# Get system proxy settings
function Get-SystemProxy {
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        $proxyEnable = Get-ItemProperty -Path $regPath -Name "ProxyEnable" -ErrorAction SilentlyContinue
        $proxyServer = Get-ItemProperty -Path $regPath -Name "ProxyServer" -ErrorAction SilentlyContinue

        if ($proxyEnable.ProxyEnable -eq 1 -and $proxyServer.ProxyServer) {
            return $proxyServer.ProxyServer
        }
    } catch {
        # Ignore errors, return null
    }
    return $null
}

# Enable system proxy
function px-system {
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

        Write-Host "System proxy enabled: $proxyUrl" -ForegroundColor Green
        return $true
    } else {
        Write-Host "No system proxy detected" -ForegroundColor Yellow
        return $false
    }
}

# Enable local proxy
function px-local {
    param([int]$Port)

    $proxyUrl = "http://127.0.0.1:$Port"
    $env:HTTP_PROXY = $proxyUrl
    $env:HTTPS_PROXY = $proxyUrl
    $env:ALL_PROXY = "127.0.0.1:$Port"

    Write-Host "Local proxy enabled: $proxyUrl" -ForegroundColor Green
}

# Disable proxy
function px-off {
    Remove-Item Env:HTTP_PROXY,Env:HTTPS_PROXY,Env:ALL_PROXY -ErrorAction SilentlyContinue
    Write-Host "Proxy disabled" -ForegroundColor Yellow
}

# Main proxy switching function
function px {
    param([string]$Target = "status")

    switch ($Target.ToLower()) {
        "clash" { px-local -Port $global:ProxyPorts.clash }
        "v2ray" { px-local -Port $global:ProxyPorts.v2ray }
        "singbox" { px-local -Port $global:ProxyPorts.singbox }
        "system" { px-system }
        "off" { px-off }
        "status" {
            Write-Host "Proxy status:" -ForegroundColor Cyan
            if ($env:HTTP_PROXY) {
                $proxyType = if ($env:HTTP_PROXY -match "127\.0\.0\.1") { "Local" } else { "System" }
                Write-Host "  Enabled ($proxyType): $env:HTTP_PROXY" -ForegroundColor Green
            } else {
                Write-Host "  Disabled" -ForegroundColor Red
            }

            $systemProxy = Get-SystemProxy
            if ($systemProxy) {
                Write-Host "  System proxy: $systemProxy" -ForegroundColor Blue
            } else {
                Write-Host "  System proxy: Not set" -ForegroundColor Gray
            }

            Write-Host ""
            Write-Host "Available options:" -ForegroundColor Gray
            Write-Host "  system   - Use system proxy" -ForegroundColor Gray
            Write-Host "  clash    - Clash (7890)" -ForegroundColor Gray
            Write-Host "  v2ray    - V2Ray (10808)" -ForegroundColor Gray
            Write-Host "  singbox  - SingBox (7890)" -ForegroundColor Gray
            Write-Host "  off      - Disable proxy" -ForegroundColor Gray
        }
        default {
            if ($Target -match '^\d+$') {
                px-local -Port ([int]$Target)
            } else {
                Write-Host "Invalid option: $Target" -ForegroundColor Red
                Write-Host "Use 'px status' to see available options" -ForegroundColor Yellow
            }
        }
    }
}

# Initialize proxy settings (auto-apply system proxy on startup)
function Initialize-ProxySettings {
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
    }
}

# Auto-initialize proxy settings on startup
Initialize-ProxySettings