[CmdletBinding()]
param(
    [string] $ToolsRoot = "C:\Tools",
    [switch] $Plan
)

$ErrorActionPreference = "Stop"

$ScriptRootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ManifestPath = Join-Path $ScriptRootPath "manifests/tools-publish.json"
$PackagesRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"

function Backup-File {
    param([string] $Path)

    if (-not (Test-Path $Path)) {
        return
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backup = "$Path.bak.$timestamp"
    if ($Plan.IsPresent) {
        Write-Host "    [plan] backup $Path -> $backup"
        return
    }

    Copy-Item -Path $Path -Destination $backup -Force
    Write-Host "    backed up $Path -> $backup"
}

# winget unzips archive/portable packages under
# %LOCALAPPDATA%\Microsoft\WinGet\Packages\<Id>_<source>\<exe>. The folder suffix
# and exe name can shift across versions, so resolve by glob and take the newest match.
function Resolve-WingetExe {
    param(
        [string] $WingetId,
        [string] $SourceExe
    )

    if ([string]::IsNullOrWhiteSpace($PackagesRoot) -or -not (Test-Path $PackagesRoot)) {
        return $null
    }

    Get-ChildItem -Path (Join-Path $PackagesRoot "${WingetId}_*") -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Get-ChildItem -Path (Join-Path $_.FullName $SourceExe) -File -ErrorAction SilentlyContinue } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

function Publish-Tool {
    param($Tool)

    Write-Host "==> $($Tool.wingetId) -> $($Tool.subdir)\$($Tool.targetExe)"

    $source = Resolve-WingetExe -WingetId $Tool.wingetId -SourceExe $Tool.sourceExe
    if (-not $source) {
        Write-Warning "    source not found: $($Tool.sourceExe) under $($Tool.wingetId). Install it first: .\windows\bootstrap.ps1 -Profile proxy-core"
        return
    }

    $targetDir = Join-Path $ToolsRoot $Tool.subdir
    $target = Join-Path $targetDir $Tool.targetExe

    if ((Test-Path $target) -and
        ((Get-FileHash $source.FullName).Hash -eq (Get-FileHash $target).Hash)) {
        Write-Host "    unchanged: $target"
        return
    }

    Backup-File -Path $target

    if ($Plan.IsPresent) {
        Write-Host "    [plan] copy $($source.FullName) -> $target"
        return
    }

    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    }
    Copy-Item -Path $source.FullName -Destination $target -Force
    Write-Host "    published $target"
}

if (-not (Test-Path $ManifestPath)) {
    throw "Publish manifest not found: $ManifestPath"
}

if ($Plan.IsPresent) {
    Write-Host "==> Plan mode enabled. No files will be changed."
}

$manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json
$tools = @($manifest.tools)
if ($tools.Count -eq 0) {
    throw "No tools listed in $ManifestPath."
}

Write-Host "Publishing to tools root: $ToolsRoot"
foreach ($tool in $tools) {
    Publish-Tool -Tool $tool
}

if ($Plan.IsPresent) {
    Write-Host "==> Plan completed."
} else {
    Write-Host "==> Publish completed."
}

Write-Host ""
Write-Host "Note: the published exe is the binary only. Registering the WinSW service"
Write-Host "      (mihomo-service.exe install) is a one-time, admin, device-specific step."
Write-Host "      See windows/docs/proxy.md -> mihomo as a Windows service."
