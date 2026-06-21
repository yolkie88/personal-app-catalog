[CmdletBinding()]
param(
    [ValidateSet("default", "core", "agentic-dev", "daily", "media", "gaming", "optional-oss", "proxy-core", "backup", "network", "automation", "communication", "dev-extra", "desktop-enhance", "media-toolkit", "local-ai", "all")]
    [string[]] $Profile = @("default"),

    [switch] $WithScoop
)

$ErrorActionPreference = "Stop"

$ScriptRootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ManifestDir = Join-Path $ScriptRootPath "manifests"

function Resolve-Profiles {
    param([string[]] $InputProfiles)

    $resolved = New-Object System.Collections.Generic.List[string]

    foreach ($item in $InputProfiles) {
        switch ($item) {
            "default" {
                $resolved.Add("core")
                $resolved.Add("agentic-dev")
            }
            "all" {
                $resolved.Add("core")
                $resolved.Add("agentic-dev")
                $resolved.Add("daily")
                $resolved.Add("media")
                $resolved.Add("gaming")
                $resolved.Add("optional-oss")
            }
            default {
                $resolved.Add($item)
            }
        }
    }

    $resolved | Select-Object -Unique
}

function Import-WingetManifest {
    param([string] $Name)

    $path = Join-Path $ManifestDir "winget-$Name.json"
    if (-not (Test-Path $path)) {
        Write-Warning "Manifest not found: $path"
        return
    }

    Write-Host "==> Importing winget manifest: $Name"
    winget import -i $path `
        --ignore-unavailable `
        --accept-package-agreements `
        --accept-source-agreements `
        --disable-interactivity
}

function Ensure-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        return
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "==> Installing Git before Scoop..."
        winget install -e --id Git.Git --source winget `
            --accept-package-agreements `
            --accept-source-agreements `
            --disable-interactivity
    }

    Write-Host "==> Installing Scoop..."
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
}

function Install-ScoopPackages {
    $listPath = Join-Path $ManifestDir "scoop-cli.txt"
    if (-not (Test-Path $listPath)) {
        Write-Warning "Scoop package list not found: $listPath"
        return
    }

    Ensure-Scoop

    Write-Host "==> Updating Scoop..."
    scoop update
    scoop bucket add extras 2>$null

    $packages = Get-Content $listPath |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") }

    foreach ($package in $packages) {
        Write-Host "==> Installing Scoop package: $package"
        scoop install $package
    }
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget is not available. Install or update App Installer from Microsoft Store first."
}

Write-Host "==> Updating winget sources..."
winget source update

$profilesToInstall = Resolve-Profiles -InputProfiles $Profile
foreach ($profileName in $profilesToInstall) {
    Import-WingetManifest -Name $profileName
}

if ($WithScoop) {
    Install-ScoopPackages
}

Write-Host "==> Bootstrap completed."
