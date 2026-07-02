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
$MarkdownTick = [char]96

$Failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string] $Message)
    $Failures.Add($Message) | Out-Null
}

function Get-MarkdownCodeTokensFromLine {
    param([string] $Line)

    $tokens = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Line) {
        return @()
    }

    $start = $Line.IndexOf($MarkdownTick)
    while ($start -ge 0) {
        $end = $Line.IndexOf($MarkdownTick, $start + 1)
        if ($end -lt 0) {
            break
        }

        $length = $end - $start - 1
        if ($length -gt 0) {
            $tokens.Add($Line.Substring($start + 1, $length)) | Out-Null
        }

        $start = $Line.IndexOf($MarkdownTick, $end + 1)
    }

    $tokens.ToArray()
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
        Add-Failure "Missing list file: $Name"
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
            Add-Failure "Duplicate entry '$item' in $Name."
        } else {
            $seen[$item] = $true
        }

        if ($RequireMiseSelector -and $item -notmatch '@') {
            Add-Failure "$Name entry '$item' should include a mise selector such as @latest, @lts, or an exact version."
        }
    }

    $items
}

function Get-BootstrapProfiles {
    if (-not (Test-Path $BootstrapPath)) {
        Add-Failure "Missing bootstrap.ps1."
        return @()
    }

    $content = Get-Content -Path $BootstrapPath -Raw
    $match = [regex]::Match($content, '\[ValidateSet\((.*?)\)\]', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) {
        Add-Failure "bootstrap.ps1 has no ValidateSet for -Profile."
        return @()
    }

    $profiles = New-Object System.Collections.Generic.List[string]
    foreach ($item in [regex]::Matches($match.Groups[1].Value, '"([^"]+)"')) {
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

function Test-ToolsPublishManifest {
    $path = Join-Path $ManifestDir "tools-publish.json"
    if (-not (Test-Path $path)) {
        Add-Failure "Missing tools-publish.json."
        return
    }

    try {
        $manifest = Get-Content -Path $path -Raw | ConvertFrom-Json
    } catch {
        Add-Failure "Invalid JSON: tools-publish.json"
        return
    }

    $tools = @($manifest.tools)
    if ($tools.Count -eq 0) {
        Add-Failure "tools-publish.json has no tools entries."
        return
    }

    # Collect every winget package the catalog actually installs.
    $wingetPackages = @{}
    foreach ($file in Get-ChildItem -Path $ManifestDir -Filter "winget-*.json") {
        try {
            $wm = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
        } catch {
            continue
        }
        foreach ($source in @($wm.Sources)) {
            foreach ($package in @($source.Packages)) {
                if ($package.PackageIdentifier) {
                    $wingetPackages[[string] $package.PackageIdentifier] = $true
                }
            }
        }
    }

    foreach ($tool in $tools) {
        foreach ($field in @("wingetId", "sourceExe", "subdir", "targetExe")) {
            if ([string]::IsNullOrWhiteSpace([string] $tool.$field)) {
                Add-Failure "tools-publish.json entry is missing required field '$field'."
            }
        }

        $id = [string] $tool.wingetId
        if ($id -and -not $wingetPackages.ContainsKey($id)) {
            Add-Failure "tools-publish.json references '$id' which no winget-*.json manifest installs."
        }
    }
}

function Test-MsstoreManifests {
    param([string[]] $BootstrapProfiles)

    $seen = @{}
    foreach ($file in Get-ChildItem -Path $ManifestDir -Filter "msstore-*.txt") {
        $profile = $file.BaseName -replace '^msstore-', ''
        if ($BootstrapProfiles -notcontains $profile) {
            Add-Failure "Microsoft Store manifest $($file.Name) has no matching bootstrap profile."
        }

        $items = @(Test-ListFile -Path $file.FullName -Name $file.Name)
        foreach ($item in $items) {
            if ($item -notmatch '^[A-Za-z0-9]+$') {
                Add-Failure "Microsoft Store package ID '$item' in $($file.Name) should be alphanumeric."
            }

            if ($seen.ContainsKey($item)) {
                Add-Failure "Duplicate Microsoft Store package '$item' in $($seen[$item]) and $($file.Name)"
            } else {
                $seen[$item] = $file.Name
            }
        }
    }
}

function Get-AllSetFromBootstrap {
    if (-not (Test-Path $BootstrapPath)) {
        return @()
    }

    $content = Get-Content -Path $BootstrapPath -Raw
    $match = [regex]::Match($content, '"all"\s*\{(.*?)\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) {
        Add-Failure "bootstrap.ps1 has no all resolution block."
        return @()
    }

    $set = New-Object System.Collections.Generic.List[string]
    foreach ($entry in [regex]::Matches($match.Groups[1].Value, '\.Add\("([^"]+)"\)')) {
        $set.Add($entry.Groups[1].Value) | Out-Null
    }

    $set.ToArray() | Sort-Object -Unique
}

function Get-AllSetFromCatalog {
    if (-not (Test-Path $CatalogPath)) {
        return @()
    }

    $lines = Get-Content -Path $CatalogPath
    $set = New-Object System.Collections.Generic.List[string]
    $inAllSection = $false
    $collectingBullets = $false

    foreach ($line in $lines) {
        if (-not $inAllSection) {
            $tokens = @(Get-MarkdownCodeTokensFromLine -Line $line)
            if ($line.TrimStart().StartsWith("##") -and ($tokens -contains "all")) {
                $inAllSection = $true
            }
            continue
        }

        if ($line.TrimStart().StartsWith("##")) {
            break
        }

        if ($line.TrimStart().StartsWith("- ")) {
            $collectingBullets = $true
            foreach ($token in Get-MarkdownCodeTokensFromLine -Line $line) {
                if ($token -match '^[a-z0-9][a-z0-9-]*$') {
                    $set.Add($token) | Out-Null
                }
            }
            continue
        }

        if ($collectingBullets -and $line.Trim().Length -gt 0) {
            break
        }
    }

    if ($set.Count -eq 0) {
        Add-Failure "catalog.md has no all inclusion section."
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
        Add-Failure "all set differs: bootstrap.ps1 = [$($fromBootstrap -join ', ')], catalog.md = [$($fromCatalog -join ', ')]."
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

    $tokens = New-Object System.Collections.Generic.List[string]
    foreach ($line in Get-Content -Path $Path) {
        foreach ($token in Get-MarkdownCodeTokensFromLine -Line $line) {
            if ($token -match '^[a-z0-9][a-z0-9-]*$') {
                $tokens.Add($token) | Out-Null
            }
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

function Test-RequiredFiles {
    $required = @(
        "windows/wsl-distro.ps1",
        "windows/configure.ps1",
        "windows/publish-tools.ps1",
        "windows/schedule-update.ps1",
        "windows/manifests/tools-publish.json",
        "windows/manifests/update-exclude.txt",
        "windows/proxy/mihomo-service.example.xml",
        "windows/config/pwsh/profile.ps1",
        "windows/config/pwsh/modules.txt",
        "windows/config/terminal/settings.defaults.json",
        "windows/config/git/gitconfig.shared",
        "windows/config/git/gitconfig.delta",
        "windows/config/vscode/extensions.txt",
        "windows/config/vscode/settings.json",
        "windows/config/wsl/wslconfig",
        "windows/proxy/sing-box.example.json",
        "windows/proxy/config.example.yaml",
        "windows/docs/config.md",
        "docs/agent-workflows.md",
        "wsl/bootstrap.sh",
        "wsl/validate.sh",
        "wsl/packages/apt-base.txt",
        "wsl/packages/cli.txt",
        "wsl/packages/k8s.txt",
        "wsl/packages/docker.txt",
        "wsl/docs/wsl.md",
        "wsl/docs/tools.md",
        "wsl/docs/wsl-boundaries.md",
        "wsl/docs/config.md"
    )

    foreach ($relative in $required) {
        $path = Join-Path $RepoRoot $relative
        if (-not (Test-Path $path)) {
            Add-Failure "Missing required file: $relative"
        }
    }
}

function Test-WslPackageLists {
    $null = Test-ListFile -Path (Join-Path $WslPackagesDir "apt-base.txt") -Name "wsl/packages/apt-base.txt"
    $null = Test-ListFile -Path (Join-Path $WslPackagesDir "cli.txt") -Name "wsl/packages/cli.txt" -RequireMiseSelector $true
    $null = Test-ListFile -Path (Join-Path $WslPackagesDir "k8s.txt") -Name "wsl/packages/k8s.txt" -RequireMiseSelector $true
    $docker = Test-ListFile -Path (Join-Path $WslPackagesDir "docker.txt") -Name "wsl/packages/docker.txt"

    $requiredDockerPackages = @("docker-ce", "docker-ce-cli", "containerd.io", "docker-buildx-plugin", "docker-compose-plugin")
    foreach ($package in $requiredDockerPackages) {
        if ($docker -notcontains $package) {
            Add-Failure "wsl/packages/docker.txt missing required Docker package: $package"
        }
    }
}

function Test-ConfigTemplates {
    $configDir = Join-Path $ScriptRootPath "config"
    if (-not (Test-Path $configDir)) {
        Add-Failure "Missing windows/config templates directory."
        return
    }

    # List files (no mise selector).
    $null = Test-ListFile -Path (Join-Path $configDir "pwsh/modules.txt") -Name "windows/config/pwsh/modules.txt"
    $null = Test-ListFile -Path (Join-Path $configDir "vscode/extensions.txt") -Name "windows/config/vscode/extensions.txt"

    # JSON templates must parse for their merge steps.
    $jsonTemplates = @(
        "terminal/settings.defaults.json",
        "vscode/settings.json"
    )
    foreach ($rel in $jsonTemplates) {
        $path = Join-Path $configDir $rel
        if (Test-Path $path) {
            try {
                Get-Content -Path $path -Raw | ConvertFrom-Json | Out-Null
            } catch {
                Add-Failure "Invalid JSON: windows/config/$rel"
            }
        }
    }

    # Config templates are tracked but must stay sanitized: no keys, credentials, or
    # real email identity. Identity and secrets are recovered manually per the docs.
    foreach ($file in Get-ChildItem -Path $configDir -Recurse -File) {
        $content = Get-Content -Path $file.FullName -Raw
        if (($content -match 'BEGIN [A-Z ]*PRIVATE KEY') -or
            ($content -match '(?i)(password|secret|api[_-]?key|token)\s*[:=]')) {
            Add-Failure "Config template $($file.Name) contains a secret-like assignment."
        }
        if ($content -match '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}') {
            Add-Failure "Config template $($file.Name) contains an email-like identity string."
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
    foreach ($forbidden in @("Docker.DockerDesktop", "OpenJS.NodeJS.LTS", "OpenAI.Codex")) {
        if ($agenticContent -match [regex]::Escape($forbidden)) {
            Add-Failure "$forbidden should not be in agentic-dev winget manifest."
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
Test-ToolsPublishManifest
Test-MsstoreManifests -BootstrapProfiles $bootstrapProfiles
Test-ProfileMapping -BootstrapProfiles $bootstrapProfiles -ManifestProfiles $manifestProfiles
Test-DocumentedProfiles -BootstrapProfiles $bootstrapProfiles
Test-AllProfileSet
Test-ScoopList
Test-Gitignore
Test-RequiredFiles
Test-ConfigTemplates
Test-WslPackageLists
Test-WslFirstBoundaries

if ($Failures.Count -gt 0) {
    foreach ($failure in $Failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host "Validation passed."
