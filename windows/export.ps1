[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$ScriptRootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ExportDir = Join-Path $ScriptRootPath "exports"
New-Item -ItemType Directory -Force -Path $ExportDir | Out-Null

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget is not available."
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "==> Exporting winget snapshot..."
winget export -o (Join-Path $ExportDir "winget-export-$timestamp.json") --accept-source-agreements

Write-Host "==> Exporting readable installed list..."
winget list | Out-File -FilePath (Join-Path $ExportDir "installed-list-$timestamp.txt") -Encoding utf8

if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "==> Exporting Scoop snapshot..."
    scoop export | Out-File -FilePath (Join-Path $ExportDir "scoop-export-$timestamp.json") -Encoding utf8
}

Write-Host "==> Export completed: $ExportDir"

