[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$ScriptRootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptRootPath
$ManifestDir = Join-Path $ScriptRootPath "manifests"
$BootstrapPath = Join-Path $ScriptRootPath "bootstrap.ps1"
$CatalogPath = Join-Path $ScriptRootPath "docs/catalog.md"
$ReadmePath = Join-Path $RepoRoot "README.md"
$GitignorePath = Join-Path $RepoRoot ".gitignore"

$Failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string] $Message)
    $Failures.Add($Message) | Out-Null
}

function Get-BootstrapProfiles {
    if (-not (Test-Path $BootstrapPath)) {
        Add-Failure "Missing bootstrap.ps1."
        return @()
    }

    $content = Get-Content -Path $BootstrapPath -Raw
    $match = [regex]::Match($content, '\[ValidateSet\((?<items>.*?)\)\]', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) {
        Add-Failure "bootstrap.ps1 has no ValidateSet for -Profile."
        return @()
    }

    $profiles = New-Object System.Collections.Generic.List[string]
    foreach ($item in [regex]::Matches($match.Groups["items"].Value, '"([^"]+)"')) {
        $profiles.Add($item.Groups[1].Value) | Out-Null
    }

    $profiles.ToArray()
}

function Get-ManifestProfiles {
    if (-not (Test-Path $ManifestDir)) {
        Add-Failure "Missing manifests directory."
        return @()
    }

    Get-ChildItem -Path $ManifestDir -Filter "winget-*.json" |
        ForEach-Object { $_.BaseName -replace '^winget-', '' } |
        Sort-Object -Unique
}

function Test-WingetManifests {
    $seen = @{}

    foreach ($file in Get-ChildItem -Path $ManifestDir -Filter "winget-*.json") {
        try {
            $manifest = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
        } catch {
            Add-Failure "Invalid JSON: $($file.Name)"
            continue
        }

        $packages = New-Object System.Collections.Generic.List[string]
        foreach ($source in @($manifest.Sources)) {
            foreach ($package in @($source.Packages)) {
                if ($package.PackageIdentifier) {
                    $packages.Add([string] $package.PackageIdentifier) | Out-Null
                }
            }
        }

        if ($packages.Count -eq 0) {
            Add-Failure "No PackageIdentifier entries: $($file.Name)"
        }

        foreach ($package in $packages) {
            if ($seen.ContainsKey($package)) {
                Add-Failure "Duplicate package '$package' in $($seen[$package]) and $($file.Name)"
            } else {
                $seen[$package] = $file.Name
            }
        }
    }
}

function Test-ProfileMapping {
    param(
        [string[]] $BootstrapProfiles,
        [string[]] $ManifestProfiles
    )

    $specialProfiles = @("default", "all")

    foreach ($profile in $BootstrapProfiles) {
        if ($specialProfiles -contains $profile) {
            continue
        }

        if ($ManifestProfiles -notcontains $profile) {
            Add-Failure "Profile '$profile' has no winget-$profile.json."
        }
    }

    foreach ($profile in $ManifestProfiles) {
        if ($BootstrapProfiles -notcontains $profile) {
            Add-Failure "Manifest winget-$profile.json has no matching bootstrap profile."
        }
    }
}

function Get-ProfileTokensFromMarkdown {
    param([string] $Path)

    if (-not (Test-Path $Path)) {
        Add-Failure "Missing markdown file: $Path"
        return @()
    }

    $content = Get-Content -Path $Path -Raw
    $tokens = New-Object System.Collections.Generic.List[string]
    foreach ($match in [regex]::Matches($content, '`([^`]+)`')) {
        $value = $match.Groups[1].Value
        if ($value -match '^[a-z0-9][a-z0-9-]*$') {
            $tokens.Add($value) | Out-Null
        }
    }

    $tokens.ToArray() | Sort-Object -Unique
}

function Test-DocumentedProfiles {
    param([string[]] $BootstrapProfiles)

    $ignored = @("windows", "manifests", "scoop-cli")
    $tokens = @((Get-ProfileTokensFromMarkdown -Path $CatalogPath) + (Get-ProfileTokensFromMarkdown -Path $ReadmePath)) | Sort-Object -Unique

    foreach ($token in $tokens) {
        if ($ignored -contains $token) {
            continue
        }

        if ($BootstrapProfiles -notcontains $token) {
            Add-Failure "Documented token '$token' is not a bootstrap profile."
        }
    }
}

function Test-ScoopList {
    $path = Join-Path $ManifestDir "scoop-cli.txt"
    if (-not (Test-Path $path)) {
        Add-Failure "Missing scoop-cli.txt."
        return
    }

    $packages = Get-Content $path |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") }

    if (@($packages).Count -eq 0) {
        Add-Failure "scoop-cli.txt has no active packages."
    }
}

function Test-Gitignore {
    if (-not (Test-Path $GitignorePath)) {
        Add-Failure "Missing .gitignore."
        return
    }

    $gitignore = Get-Content -Path $GitignorePath -Raw
    foreach ($pattern in @("windows/exports/", "windows/reports/", "**/*.key", "**/*.pem")) {
        if ($gitignore -notmatch [regex]::Escape($pattern)) {
            Add-Failure ".gitignore missing pattern: $pattern"
        }
    }
}

$bootstrapProfiles = @(Get-BootstrapProfiles)
$manifestProfiles = @(Get-ManifestProfiles)

Test-WingetManifests
Test-ProfileMapping -BootstrapProfiles $bootstrapProfiles -ManifestProfiles $manifestProfiles
Test-DocumentedProfiles -BootstrapProfiles $bootstrapProfiles
Test-ScoopList
Test-Gitignore

if ($Failures.Count -gt 0) {
    Write-Host "Validation failed:"
    foreach ($failure in $Failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host "Validation passed."
