# Managed by personal-app-catalog. Sanitized template only - no secrets, no identity.
# configure.ps1 copies this next to $PROFILE as catalog.profile.ps1 and dot-sources it
# from $PROFILE through a guarded line. Your own $PROFILE body is never overwritten.

# --- PSReadLine: history-aware predictions and richer editing -----------------
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Prediction view/source need PSReadLine 2.2.2+ (e.g. newer than the inbox
    # module on Windows PowerShell 5.1); guard so an old version doesn't error on startup.
    if ((Get-Module PSReadLine).Version -ge [version]"2.2.2") {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
        Set-PSReadLineOption -PredictionViewStyle ListView
    }
}

# --- Optional modules: load only when present ---------------------------------
if (Get-Module -ListAvailable -Name posh-git)        { Import-Module posh-git }
if (Get-Module -ListAvailable -Name Terminal-Icons)  { Import-Module Terminal-Icons }
if (Get-Module -ListAvailable -Name PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# --- Prompt: starship if available --------------------------------------------
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}

# --- Session-only proxy helpers ------------------------------------------------
# These helpers assume mihomo listens on 127.0.0.1:7890. They only affect the
# current PowerShell process and child processes; they do not change Windows
# system proxy, WinHTTP, registry, or persisted tool config.
function proxy-on {
    param(
        [string] $HostName = "127.0.0.1",
        [int] $Port = 7890
    )

    $http = "http://${HostName}:${Port}"
    $socks = "socks5h://${HostName}:${Port}"
    $bypass = "localhost,127.0.0.1,::1,.local,.internal"

    $env:http_proxy = $http
    $env:https_proxy = $http
    $env:HTTP_PROXY = $http
    $env:HTTPS_PROXY = $http
    $env:all_proxy = $socks
    $env:ALL_PROXY = $socks
    $env:no_proxy = $bypass
    $env:NO_PROXY = $bypass

    Write-Host "proxy on: $http"
}

function proxy-off {
    foreach ($name in @("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "all_proxy", "ALL_PROXY", "no_proxy", "NO_PROXY")) {
        Remove-Item "Env:$name" -ErrorAction SilentlyContinue
    }
    Write-Host "proxy off"
}

function proxy-status {
    Get-ChildItem Env: | Where-Object { $_.Name -match '^(http|https|all|no)_proxy$' } | Sort-Object Name
}

# Quick connectivity + egress check. Uses the shell proxy env (set by proxy-on)
# when present; otherwise relies on the Windows system proxy default. Helps tell
# apart "proxy down" from "proxy up but not selected".
function proxy-test {
    param(
        [string] $Url = "https://www.gstatic.com/generate_204",
        [string] $IpUrl = "https://api.ipify.org"
    )

    $common = @{ TimeoutSec = 8; UseBasicParsing = $true; ErrorAction = "Stop" }
    if ($env:https_proxy) {
        $common.Proxy = $env:https_proxy
        Write-Host "shell proxy: $($env:https_proxy)"
    } else {
        Write-Host "shell proxy: none (using Windows system proxy default)"
    }

    try {
        $resp = Invoke-WebRequest -Uri $Url -MaximumRedirection 0 @common
        Write-Host "connectivity: ok ($($resp.StatusCode))"
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        if ($code) { Write-Host "connectivity: ok ($code)" }
        else { Write-Host "connectivity: FAILED -> $($_.Exception.Message)" }
    }

    try {
        $ip = (Invoke-WebRequest -Uri $IpUrl @common).Content.Trim()
        Write-Host "egress ip: $ip"
    } catch {
        Write-Host "egress ip: unavailable"
    }
}

# --- Aliases / shortcuts ------------------------------------------------------
function ll { Get-ChildItem -Force @args }
function la { Get-ChildItem -Force -Hidden @args }
Set-Alias g git
if (Get-Command lazygit -ErrorAction SilentlyContinue) { Set-Alias lg lazygit }
if (Get-Command bat -ErrorAction SilentlyContinue)     { Set-Alias cat bat }
