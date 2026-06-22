[CmdletBinding()]
param(
    [switch] $All,
    [switch] $IncludeScoop
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget is not available."
}

Write-Host "==> Updating winget sources..."
winget source update
if ($LASTEXITCODE -ne 0) {
    throw "winget source update failed with exit code $LASTEXITCODE."
}

if ($All) {
    Write-Host "==> Upgrading all winget-managed/matched apps..."
    winget upgrade --all `
        --accept-package-agreements `
        --accept-source-agreements `
        --disable-interactivity
} else {
    Write-Host "==> Listing winget upgrades. Re-run with -All to apply."
    winget upgrade
}

if ($IncludeScoop -and (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "==> Updating Scoop apps..."
    scoop update
    scoop update *
    scoop cleanup *
}

Write-Host "==> Update step completed."

