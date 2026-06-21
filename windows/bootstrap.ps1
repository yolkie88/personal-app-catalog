[CmdletBinding()]
param(
    [ValidateSet("default", "core", "agentic-dev", "daily", "media", "gaming", "optional-oss", "proxy-core", "backup", "network", "automation", "communication", "dev-extra", "desktop-enhance", "media-toolkit", "local-ai", "all")]
    [string[]] $Profile = @("default"),

    [switch] $WithScoop,
    [switch] $Plan,
    [switch] $Report
)

$ErrorActionPreference = "Stop"

$ScriptRootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ManifestDir = Join-Path $ScriptRootPath "manifests"
$ReportDir = Join-Path $ScriptRootPath "reports"
$RunResults = New-Object System.Collections.Generic.List[object]

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

function Add-RunResult {
    param(
        [string] $Type,
        [string] $Name,
        [string] $Status,
        [string[]] $Packages = @(),
        [string] $Message = ""
    )

    $RunResults.Add([pscustomobject]@{
        Type = $Type
        Name = $Name
        Status = $Status
        Packages = @($Packages)
        Message = $Message
    }) | Out-Null
}

function Get-WingetManifestPath {
    param([string] $Name)

    Join-Path $ManifestDir "winget-$Name.json"
}

function Get-WingetManifestPackages {
    param([string] $Name)

    $path = Get-WingetManifestPath -Name $Name
    if (-not (Test-Path $path)) {
        return @()
    }

    $manifest = Get-Content -Path $path -Raw | ConvertFrom-Json
    $packages = New-Object System.Collections.Generic.List[string]

    foreach ($source in @($manifest.Sources)) {
        foreach ($package in @($source.Packages)) {
            if ($package.PackageIdentifier) {
                $packages.Add([string] $package.PackageIdentifier)
            }
        }
    }

    $packages.ToArray()
}

function Import-WingetManifest {
    param(
        [string] $Name,
        [switch] $PlanMode
    )

    $path = Get-WingetManifestPath -Name $Name
    if (-not (Test-Path $path)) {
        Write-Warning "Manifest not found: $path"
        Add-RunResult -Type "winget" -Name $Name -Status "missing" -Message "Manifest not found: $path"
        return
    }

    $packages = @(Get-WingetManifestPackages -Name $Name)

    if ($PlanMode) {
        Write-Host "==> Plan: winget manifest: $Name"
        foreach ($package in $packages) {
            Write-Host "    $package"
        }
        Add-RunResult -Type "winget" -Name $Name -Status "planned" -Packages $packages
        return
    }

    Write-Host "==> Importing winget manifest: $Name"
    & winget import -i $path `
        --ignore-unavailable `
        --accept-package-agreements `
        --accept-source-agreements `
        --disable-interactivity

    if ($LASTEXITCODE -ne 0) {
        Add-RunResult -Type "winget" -Name $Name -Status "failed" -Packages $packages -Message "winget import exited with code $LASTEXITCODE"
        throw "winget import failed for profile '$Name' with exit code $LASTEXITCODE."
    }

    Add-RunResult -Type "winget" -Name $Name -Status "imported" -Packages $packages
}

function Ensure-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        return
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "==> Installing Git before Scoop..."
        & winget install -e --id Git.Git --source winget `
            --accept-package-agreements `
            --accept-source-agreements `
            --disable-interactivity

        if ($LASTEXITCODE -ne 0) {
            throw "Git installation failed with exit code $LASTEXITCODE."
        }
    }

    Write-Host "==> Installing Scoop..."
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
}

function Get-ScoopPackages {
    $listPath = Join-Path $ManifestDir "scoop-cli.txt"
    if (-not (Test-Path $listPath)) {
        return @()
    }

    Get-Content $listPath |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") }
}

function Install-ScoopPackages {
    param([switch] $PlanMode)

    $listPath = Join-Path $ManifestDir "scoop-cli.txt"
    if (-not (Test-Path $listPath)) {
        Write-Warning "Scoop package list not found: $listPath"
        Add-RunResult -Type "scoop" -Name "scoop-cli" -Status "missing" -Message "Scoop package list not found: $listPath"
        return
    }

    $packages = @(Get-ScoopPackages)

    if ($PlanMode) {
        Write-Host "==> Plan: Scoop packages"
        foreach ($package in $packages) {
            Write-Host "    $package"
        }
        Add-RunResult -Type "scoop" -Name "scoop-cli" -Status "planned" -Packages $packages
        return
    }

    Ensure-Scoop

    Write-Host "==> Updating Scoop..."
    & scoop update
    if ($LASTEXITCODE -ne 0) {
        throw "Scoop update failed with exit code $LASTEXITCODE."
    }

    & scoop bucket add extras 2>$null

    foreach ($package in $packages) {
        Write-Host "==> Installing Scoop package: $package"
        & scoop install $package
        if ($LASTEXITCODE -ne 0) {
            Add-RunResult -Type "scoop" -Name $package -Status "failed" -Packages @($package) -Message "scoop install exited with code $LASTEXITCODE"
            throw "Scoop package '$package' failed with exit code $LASTEXITCODE."
        }

        Add-RunResult -Type "scoop" -Name $package -Status "installed" -Packages @($package)
    }
}

function Write-RunReport {
    param([string[]] $ResolvedProfiles)

    if (-not $Report) {
        return
    }

    New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $jsonPath = Join-Path $ReportDir "bootstrap-report-$timestamp.json"
    $txtPath = Join-Path $ReportDir "bootstrap-report-$timestamp.txt"

    $payload = [pscustomobject]@{
        Timestamp = (Get-Date).ToString("o")
        InputProfiles = @($Profile)
        ResolvedProfiles = @($ResolvedProfiles)
        WithScoop = [bool] $WithScoop
        Plan = [bool] $Plan
        Results = @($RunResults)
    }

    $payload | ConvertTo-Json -Depth 8 | Out-File -FilePath $jsonPath -Encoding utf8

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Bootstrap report") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("Timestamp: $($payload.Timestamp)") | Out-Null
    $lines.Add("Input profiles: $($Profile -join ', ')") | Out-Null
    $lines.Add("Resolved profiles: $($ResolvedProfiles -join ', ')") | Out-Null
    $lines.Add("With Scoop: $([bool] $WithScoop)") | Out-Null
    $lines.Add("Plan mode: $([bool] $Plan)") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## Results") | Out-Null

    foreach ($result in $RunResults) {
        $packages = @($result.Packages) -join ", "
        if ([string]::IsNullOrWhiteSpace($packages)) {
            $packages = "-"
        }
        $lines.Add("- [$($result.Status)] $($result.Type): $($result.Name) | packages: $packages | $($result.Message)") | Out-Null
    }

    $lines | Out-File -FilePath $txtPath -Encoding utf8
    Write-Host "==> Report written: $jsonPath"
    Write-Host "==> Report written: $txtPath"
}

$profilesToInstall = @(Resolve-Profiles -InputProfiles $Profile)

try {
    if ($Plan) {
        Write-Host "==> Plan mode enabled. No packages will be installed."
    } else {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            throw "winget is not available. Install or update App Installer from Microsoft Store first."
        }

        Write-Host "==> Updating winget sources..."
        & winget source update
        if ($LASTEXITCODE -ne 0) {
            throw "winget source update failed with exit code $LASTEXITCODE."
        }
    }

    foreach ($profileName in $profilesToInstall) {
        Import-WingetManifest -Name $profileName -PlanMode:$Plan
    }

    if ($WithScoop) {
        Install-ScoopPackages -PlanMode:$Plan
    }

    if ($Plan) {
        Write-Host "==> Plan completed."
    } else {
        Write-Host "==> Bootstrap completed."
    }
} finally {
    Write-RunReport -ResolvedProfiles $profilesToInstall
}
