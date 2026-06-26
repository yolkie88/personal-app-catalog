[CmdletBinding()]
param(
    [switch] $All,
    [switch] $IncludeScoop,
    [switch] $Exclude,
    [string] $ExcludeFile
)

$ErrorActionPreference = "Stop"

$ScriptRootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ExcludeFile)) {
    $ExcludeFile = Join-Path $ScriptRootPath "manifests/update-exclude.txt"
}

# Read winget package IDs that must NOT be batch-upgraded (proxy core, remote
# control, drivers, licensed apps). Same list-file convention as the manifests:
# one ID per line, '#' comments and blank lines ignored.
function Get-ExcludeIds {
    param([string] $Path)

    if (-not (Test-Path $Path)) {
        Write-Warning "Exclude file not found: $Path (nothing will be held back)."
        return @()
    }

    Get-Content -Path $Path |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") } |
        Sort-Object -Unique
}

# True when $Id already has a winget pin, so we don't try to pin it again.
function Test-WingetPinned {
    param(
        [string] $PinListText,
        [string] $Id
    )

    if ([string]::IsNullOrEmpty($PinListText)) {
        return $false
    }

    # Match the ID as its own table cell (whitespace/line bounded) to avoid a
    # prefix ID matching a longer one (e.g. Foo.Bar vs Foo.BarBaz).
    return [bool]([regex]::IsMatch($PinListText, "(^|\s)$([regex]::Escape($Id))(\s|$)",
        [System.Text.RegularExpressions.RegexOptions]::Multiline))
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget is not available."
}

$excludeIds = @()
if ($Exclude.IsPresent) {
    $excludeIds = @(Get-ExcludeIds -Path $ExcludeFile)
    if ($excludeIds.Count -gt 0) {
        Write-Host "==> Hold list ($($excludeIds.Count)): $($excludeIds -join ', ')"
    } else {
        Write-Host "==> Exclude enabled, but no active entries in $ExcludeFile."
    }
}

Write-Host "==> Updating winget sources..."
winget source update
if ($LASTEXITCODE -ne 0) {
    throw "winget source update failed with exit code $LASTEXITCODE."
}

if ($All -and $excludeIds.Count -gt 0) {
    # Hold excluded packages back with winget pins so 'upgrade --all' skips them.
    # A default ('Pinning') pin gates --all but still allows an explicit
    # 'winget upgrade <id>', which is exactly the "don't auto-update" semantic.
    Write-Host "==> Holding excluded packages (winget pin)..."
    $pinList = ""
    try { $pinList = (winget pin list 2>$null | Out-String) } catch { $pinList = "" }

    foreach ($id in $excludeIds) {
        if (Test-WingetPinned -PinListText $pinList -Id $id) {
            Write-Host "    already held: $id"
            continue
        }

        Write-Host "    holding: $id"
        winget pin add --id $id --exact --accept-source-agreements | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "    could not pin $id (not installed yet?). It simply won't be upgraded."
        }
    }
}

if ($All) {
    Write-Host "==> Upgrading all winget-managed/matched apps (held/pinned apps are skipped)..."
    winget upgrade --all `
        --accept-package-agreements `
        --accept-source-agreements `
        --disable-interactivity
} else {
    Write-Host "==> Listing winget upgrades. Re-run with -All to apply."
    if ($excludeIds.Count -gt 0) {
        Write-Host "    (with -All these would be held: $($excludeIds -join ', '))"
    }
    winget upgrade
}

if ($IncludeScoop -and (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "==> Updating Scoop apps..."
    scoop update
    scoop update *
    scoop cleanup *
}

Write-Host "==> Update step completed."
if ($excludeIds.Count -gt 0) {
    Write-Host "    Held apps stay pinned. Inspect with 'winget pin list';"
    Write-Host "    release one with 'winget pin remove --id <id>'."
}
