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
$WslDir = Join-Path $RepoRoot "wsl"
$WslPackagesDir = Join-Path $WslDir "packages"

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

function Get-AllSetFromBootstrap {
    if (-not (Test-Path $BootstrapPath)) {
        return @()
    }

    $content = Get-Content -Path $BootstrapPath -Raw
    $match = [regex]::Match($content, '"all"\s*\{(?<body>.*?)\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) {
        Add-Failure "bootstrap.ps1 has no 'all' resolution block."
        return @()
    }

    $set = New-Object System.Collections.Generic.List[string]
    foreach ($entry in [regex]::Matches($match.Groups["body"].Value, '\.Add\("([^"]+)"\)')) {
        $set.Add($entry.Groups[1].Value) | Out-Null
    }

    $set.ToArray() | Sort-Object -Unique
}

function Get-AllSetFromCatalog {
    if (-not (Test-Path $CatalogPath)) {
        return @()
    }

    $content = Get-Content -Path $CatalogPath -Raw
    $match = [regex]::Match($content, '只包含[：:](?<body>.*?)不包含', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) {
        Add-Failure "catalog.md has no 'all' inclusion section."
        return @()
    }

    $set = New-Object System.Collections.Generic.List[string]
    foreach ($entry in [regex]::Matches($match.Groups["body"].Value, '`([a-z0-9][a-z0-9-]*)`')) {
        $value = $entry.Groups[1].Value
        if ($value -ne "all") {
            $set.Add($value) | Out-Null
        }
    }

    $set.ToArray() | Sort-Object -Unique
}

function Test-AllProfileSet {
    $fromBootstrap = @(Get-AllSetFromBootstrap)
    $fromCatalog = @(Get-AllSetFromCatalog)

    if ($fromBootstrap.Count -eq 0 -or $fromCatalog.Count -eq 0) {
        return
    }

    if (Compare-Object -ReferenceObject $fromBootstrap -DifferenceObject $fromCatalog) {
        Add-Failure "'all' set differs: bootstrap.ps1 = [$($fromBootstrap -join ', ')], catalog.md = [$($fromCatalog -join ', ')]."
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

    $documented = @((Get-ProfileTokensFromMarkdown -Path $CatalogPath) + (Get-ProfileTokensFromMarkdown -Path $ReadmePath)) | Sort-Object -Unique

    foreach ($profile in $BootstrapProfiles) {
        if ($documented -notcontains $profile) {
            Add-Failure "Bootstrap profile '$profile' is not documented in catalog.md or README.md."
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

function Get-ActiveListItems {
    param([string] $Path)

    if (-not (Test-Path $Path)) {
        return @()
    }

    Get-Content -Path $Path |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") }
}

function Test-ListFile {
    param(
        [string] $Path,
        [string] $Name,
        [bool] $RequireMiseSelector = $false
    )

    if (-not (Test-Path $Path)) {
        Add-Failure "Missing WSL list file: $Name"
        return @()
    }

    $items = @(Get-ActiveListItems -Path $Path)
    if ($items.Count -eq 0) {
        Add-Failure "$Name has no active entries."
        return @()
    }

    $seen = @{}
    foreach ($item in $items) {
        if ($seen.ContainsKey($item)) {
            Add-Failure "Duplicate WSL entry '$item' in $Name."
        } else {
            $seen[$item] = $true
        }

        if ($RequireMiseSelector -and $item -notmatch '@') {
            Add-Failure "$Name entry '$item' should include a mise selector such as @latest, @lts, or an exact version."
        }
    }

    $items
}

function Test-WslFiles {
    $required = @(
        "wsl/bootstrap.sh",
        "wsl/validate.sh",
        "wsl/packages/apt-base.txt",
        "wsl/packages/cli.txt",
        "wsl/packages/k8s.txt",
        "wsl/packages/docker.txt",
        "wsl/docs/wsl.md",
        "wsl/docs/tools.md",
        "wsl/docs/wsl-boundaries.md"
    )

    foreach ($relative in $required) {
        $path = Join-Path $RepoRoot $relative
        if (-not (Test-Path $path)) {
            Add-Failure "Missing WSL file: $relative"
        }
    }
}

function Test-WslPackageLists {
    $aptBase = Test-ListFile -Path (Join-Path $WslPackagesDir "apt-base.txt") -Name "wsl/packages/apt-base.txt"
    $cli = Test-ListFile -Path (Join-Path $WslPackagesDir "cli.txt") -Name "wsl/packages/cli.txt" -RequireMiseSelector $true
    $k8s = Test-ListFile -Path (Join-Path $WslPackagesDir "k8s.txt") -Name "wsl/packages/k8s.txt" -RequireMiseSelector $true
    $docker = Test-ListFile -Path (Join-Path $WslPackagesDir "docker.txt") -Name "wsl/packages/docker.txt"

    $requiredDockerPackages = @("docker-ce", "docker-ce-cli", "containerd.io", "docker-buildx-plugin", "docker-compose-plugin")
    foreach ($package in $requiredDockerPackages) {
        if ($docker -notcontains $package) {
            Add-Failure "wsl/packages/docker.txt missing required Docker package: $package"
        }
    }
}

function Test-WslFirstBoundaries {
    $agenticManifest = Join-Path $ManifestDir "winget-agentic-dev.json"
    if (-not (Test-Path $agenticManifest)) {
        Add-Failure "Missing winget-agentic-dev.json."
        return
    }

    $agenticContent = Get-Content -Path $agenticManifest -Raw
    foreach ($forbidden in @("Docker.DockerDesktop", "OpenJS.NodeJS.LTS")) {
        if ($agenticContent -match [regex]::Escape($forbidden)) {
            Add-Failure "$forbidden should not be in agentic-dev; it is WSL-first in this catalog."
        }
    }

    foreach ($file in Get-ChildItem -Path $ManifestDir -Filter "winget-*.json") {
        $content = Get-Content -Path $file.FullName -Raw
        if ($content -match [regex]::Escape("Docker.DockerDesktop")) {
            Add-Failure "Docker.DockerDesktop should not be in Windows winget manifests; Docker Engine is installed through WSL. Found in $($file.Name)."
        }
    }
}

$bootstrapProfiles = @(Get-BootstrapProfiles)
$manifestProfiles = @(Get-ManifestProfiles)

Test-WingetManifests
Test-ProfileMapping -BootstrapProfiles $bootstrapProfiles -ManifestProfiles $manifestProfiles
Test-DocumentedProfiles -BootstrapProfiles $bootstrapProfiles
Test-AllProfileSet
Test-ScoopList
Test-Gitignore
Test-WslFiles
Test-WslPackageLists
Test-WslFirstBoundaries

if ($Failures.Count -gt 0) {
    foreach ($failure in $Failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host "Validation passed."
