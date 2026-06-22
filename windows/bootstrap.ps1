[CmdletBinding()]
param(
    [ValidateSet("default", "core", "agentic-dev", "daily", "daily-extra", "media", "gaming", "optional-oss", "proxy-core", "backup", "backup-cli", "network", "automation", "communication", "dev-extra", "k8s-toolkit", "maintenance", "sync-storage", "security-toolkit", "desktop-enhance", "media-toolkit", "creative", "local-ai", "all")]
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
                $resolved.Add("core") | Out-Null
                $resolved.Add("agentic-dev") | Out-Null
            }
            "all" {
                $resolved.Add("core") | Out-Null
                $resolved.Add("agentic-dev") | Out-Null
                $resolved.Add("daily") | Out-Null
                $resolved.Add("media") | Out-Null
                $resolved.Add("gaming") | Out-Null
            }
            default {
                $resolved.Add($item) | Out-Null
            }
        }
    }

    @($resolved.ToArray() | Select-Object -Unique)
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
                $packages.Add([string] $package.PackageIdentifier) | Out-Null
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

    if ($PlanMode.IsPresent) {
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

function Get-MsstoreManifestPath {
    param([string] $Name)

    Join-Path $ManifestDir "msstore-$Name.txt"
}

function Get-ListPackages {
    param([string] $Path)

    if (-not (Test-Path $Path)) {
        return @()
    }

    Get-Content $Path |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") }
}

function Install-MsstorePackages {
    param(
        [string] $Name,
        [switch] $PlanMode
    )

    $path = Get-MsstoreManifestPath -Name $Name
    if (-not (Test-Path $path)) {
        return
    }

    $packages = @(Get-ListPackages -Path $path)
    if ($packages.Count -eq 0) {
        Add-RunResult -Type "msstore" -Name $Name -Status "empty" -Message "No active package IDs in $path"
        return
    }

    if ($PlanMode.IsPresent) {
        Write-Host "==> Plan: Microsoft Store packages: $Name"
        foreach ($package in $packages) {
            Write-Host "    $package"
        }
        Add-RunResult -Type "msstore" -Name $Name -Status "planned" -Packages $packages
        return
    }

    foreach ($package in $packages) {
        Write-Host "==> Installing Microsoft Store package: $package"
        & winget install --id $package -s msstore `
            --accept-package-agreements `
            --accept-source-agreements `
            --disable-interactivity

        if ($LASTEXITCODE -ne 0) {
            Add-RunResult -Type "msstore" -Name $package -Status "failed" -Packages @($package) -Message "winget install msstore exited with code $LASTEXITCODE"
            throw "Microsoft Store package '$package' failed with exit code $LASTEXITCODE."
        }

        Add-RunResult -Type "msstore" -Name $package -Status "installed" -Packages @($package)
    }
}

function Ensure-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        return
    }

    throw "Scoop is not installed. Install Scoop first, then rerun this command with -WithScoop."
}

function Get-ScoopPackages {
    $listPath = Join-Path $ManifestDir "scoop-cli.txt"
    @(Get-ListPackages -Path $listPath)
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

    if ($PlanMode.IsPresent) {
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
    param([object[]] $ResolvedProfiles)

    if (-not $Report.IsPresent) {
        return
    }

    $resolvedProfileNames = @($ResolvedProfiles | ForEach-Object { [string] $_ })
    $inputProfileNames = @($Profile | ForEach-Object { [string] $_ })
    $resultItems = @($RunResults.ToArray())

    New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $jsonPath = Join-Path $ReportDir "bootstrap-report-$timestamp.json"
    $txtPath = Join-Path $ReportDir "bootstrap-report-$timestamp.txt"

    $payload = [pscustomobject]@{
        Timestamp = (Get-Date).ToString("o")
        InputProfiles = $inputProfileNames
        ResolvedProfiles = $resolvedProfileNames
        WithScoop = $WithScoop.IsPresent
        Plan = $Plan.IsPresent
        Results = $resultItems
    }

    ConvertTo-Json -InputObject $payload -Depth 8 | Out-File -FilePath $jsonPath -Encoding utf8

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Bootstrap report") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("Timestamp: $($payload.Timestamp)") | Out-Null
    $lines.Add("Input profiles: $($inputProfileNames -join ', ')") | Out-Null
    $lines.Add("Resolved profiles: $($resolvedProfileNames -join ', ')") | Out-Null
    $lines.Add("With Scoop: $($WithScoop.IsPresent)") | Out-Null
    $lines.Add("Plan mode: $($Plan.IsPresent)") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## Results") | Out-Null

    foreach ($result in $resultItems) {
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
    if ($Plan.IsPresent) {
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
        Import-WingetManifest -Name $profileName -PlanMode:$Plan.IsPresent
        Install-MsstorePackages -Name $profileName -PlanMode:$Plan.IsPresent
    }

    if ($WithScoop.IsPresent) {
        Install-ScoopPackages -PlanMode:$Plan.IsPresent
    }

    if ($Plan.IsPresent) {
        Write-Host "==> Plan completed."
    } else {
        Write-Host "==> Bootstrap completed."
    }
} finally {
    Write-RunReport -ResolvedProfiles $profilesToInstall
}
