[CmdletBinding()]
param(
    [switch] $Pwsh,
    [switch] $Terminal,
    [switch] $Git,
    [switch] $VSCode,
    [switch] $All,
    [switch] $Plan
)

$ErrorActionPreference = "Stop"

$ScriptRootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigDir = Join-Path $ScriptRootPath "config"
$Marker = "# personal-app-catalog"

function Show-Usage {
    Write-Host "Usage: .\windows\configure.ps1 [-Pwsh] [-Terminal] [-Git] [-VSCode] [-All] [-Plan]"
    Write-Host ""
    Write-Host "  -Pwsh      Install PowerShell modules and a managed profile"
    Write-Host "  -Terminal  Merge Windows Terminal defaults (font, color scheme)"
    Write-Host "  -Git       Reference the shared Git config via include.path"
    Write-Host "  -VSCode    Install recommended extensions and merge user settings"
    Write-Host "  -All       Apply all of the above"
    Write-Host "  -Plan      Print what would change without writing anything"
    Write-Host ""
    Write-Host "Identity (user.name/email), SSH/GPG keys, and secrets stay manual."
}

function Get-ListItems {
    param([string] $Path)

    if (-not (Test-Path $Path)) {
        return @()
    }

    Get-Content $Path |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") }
}

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

function Copy-Template {
    param(
        [string] $Source,
        [string] $Destination
    )

    if (-not (Test-Path $Source)) {
        Write-Warning "Template not found: $Source"
        return
    }

    if ((Test-Path $Destination) -and
        ((Get-FileHash $Source).Hash -eq (Get-FileHash $Destination).Hash)) {
        Write-Host "    unchanged: $Destination"
        return
    }

    Backup-File -Path $Destination

    if ($Plan.IsPresent) {
        Write-Host "    [plan] copy $Source -> $Destination"
        return
    }

    $parent = Split-Path -Parent $Destination
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Copy-Item -Path $Source -Destination $Destination -Force
    Write-Host "    wrote $Destination"
}

function Add-GuardedLine {
    param(
        [string] $Path,
        [string] $Line
    )

    if ((Test-Path $Path) -and (Select-String -Path $Path -SimpleMatch $Marker -Quiet)) {
        Write-Host "    guarded line already present in $Path"
        return
    }

    if ($Plan.IsPresent) {
        Write-Host "    [plan] append guarded line to $Path"
        return
    }

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Add-Content -Path $Path -Value ""
    Add-Content -Path $Path -Value $Line
    Write-Host "    appended guarded line to $Path"
}

function Invoke-PwshConfig {
    Write-Host "==> PowerShell profile and modules"

    $modules = @(Get-ListItems -Path (Join-Path $ConfigDir "pwsh/modules.txt"))
    foreach ($module in $modules) {
        if (Get-Module -ListAvailable -Name $module) {
            Write-Host "    module present: $module"
            continue
        }
        if ($Plan.IsPresent) {
            Write-Host "    [plan] Install-Module $module -Scope CurrentUser"
            continue
        }
        Write-Host "    installing module: $module"
        Install-Module -Name $module -Scope CurrentUser -Force -AcceptLicense -ErrorAction Stop
    }

    # The managed profile lives next to $PROFILE and is dot-sourced from it so the
    # user's own profile body is preserved.
    if ([string]::IsNullOrWhiteSpace($PROFILE)) {
        Write-Host "    [skip] \$PROFILE path is not available in this host."
        return
    }

    $profileDir = Split-Path -Parent $PROFILE
    $managed = Join-Path $profileDir "catalog.profile.ps1"
    Copy-Template -Source (Join-Path $ConfigDir "pwsh/profile.ps1") -Destination $managed
    Add-GuardedLine -Path $PROFILE -Line ". `"$managed`"  $Marker"
}

function Get-TerminalSettingsPath {
    $localAppData = $env:LOCALAPPDATA
    if ([string]::IsNullOrWhiteSpace($localAppData)) {
        return $null
    }

    $candidates = @(
        (Join-Path $localAppData "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"),
        (Join-Path $localAppData "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json")
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }
    return $null
}

function Merge-Object {
    param($Base, $Overlay)

    foreach ($property in $Overlay.PSObject.Properties) {
        $name = $property.Name
        $value = $property.Value
        $existing = $Base.PSObject.Properties[$name]

        if ($existing -and
            ($existing.Value -is [pscustomobject]) -and
            ($value -is [pscustomobject])) {
            Merge-Object -Base $existing.Value -Overlay $value
        } elseif ($existing) {
            $existing.Value = $value
        } else {
            $Base | Add-Member -NotePropertyName $name -NotePropertyValue $value
        }
    }
}

function Invoke-TerminalConfig {
    Write-Host "==> Windows Terminal defaults"

    $settingsPath = Get-TerminalSettingsPath
    if (-not $settingsPath) {
        Write-Host "    [skip] Windows Terminal settings.json not found."
        return
    }

    $defaultsPath = Join-Path $ConfigDir "terminal/settings.defaults.json"
    $overlay = Get-Content -Path $defaultsPath -Raw | ConvertFrom-Json

    if ($Plan.IsPresent) {
        Write-Host "    [plan] merge $defaultsPath into $settingsPath"
        return
    }

    Backup-File -Path $settingsPath
    $current = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
    Merge-Object -Base $current -Overlay $overlay
    ConvertTo-Json -InputObject $current -Depth 32 | Out-File -FilePath $settingsPath -Encoding utf8
    Write-Host "    merged Windows Terminal defaults into $settingsPath"
}

function Add-GitInclude {
    param([string] $Path)

    $existing = @()
    try {
        $existing = @(& git config --global --get-all include.path 2>$null)
    } catch {
        $existing = @()
    }

    if ($existing -contains $Path) {
        Write-Host "    include.path already references $Path"
        return
    }

    & git config --global --add include.path $Path
    Write-Host "    added include.path -> $Path"
}

function Invoke-GitConfig {
    Write-Host "==> Git shared config"

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "    [skip] git is not available."
        return
    }

    $shared = Join-Path $ConfigDir "git/gitconfig.shared"
    $target = Join-Path $HOME "catalog.gitconfig"
    Copy-Template -Source $shared -Destination $target

    $deltaSource = Join-Path $ConfigDir "git/gitconfig.delta"
    $deltaTarget = Join-Path $HOME "catalog-delta.gitconfig"
    Copy-Template -Source $deltaSource -Destination $deltaTarget

    # Plan mode performs no external commands, matching bootstrap.ps1's convention.
    if ($Plan.IsPresent) {
        Write-Host "    [plan] add include.path -> $target (if not already present)"
        Write-Host "    [plan] add include.path -> $deltaTarget (only if delta is installed)"
        return
    }

    Add-GitInclude -Path $target

    # delta pager config is only worth wiring up when delta is actually installed.
    if (Get-Command delta -ErrorAction SilentlyContinue) {
        Add-GitInclude -Path $deltaTarget
    } else {
        Write-Host "    [skip] delta not installed; not wiring delta pager (see hint below)"
    }
}

function Get-VSCodeSettingsPath {
    $appData = $env:APPDATA
    if ([string]::IsNullOrWhiteSpace($appData)) {
        return $null
    }
    return (Join-Path $appData "Code\User\settings.json")
}

function Invoke-VSCodeConfig {
    Write-Host "==> VS Code extensions and settings"

    $extensions = @(Get-ListItems -Path (Join-Path $ConfigDir "vscode/extensions.txt"))

    if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
        Write-Host "    [skip] 'code' CLI not found; skipping extension install."
    } elseif ($Plan.IsPresent) {
        Write-Host "    [plan] install $($extensions.Count) extension(s) from extensions.txt (skipping already-installed)"
    } else {
        $installed = @()
        try { $installed = @(& code --list-extensions 2>$null) } catch { $installed = @() }
        foreach ($ext in $extensions) {
            if ($installed -contains $ext) {
                Write-Host "    extension present: $ext"
                continue
            }
            Write-Host "    installing extension: $ext"
            & code --install-extension $ext --force | Out-Null
        }
    }

    # Settings: deep-merge our defaults, preserving any existing user keys.
    $settingsPath = Get-VSCodeSettingsPath
    if (-not $settingsPath) {
        Write-Host "    [skip] VS Code user settings path not available."
        return
    }

    $defaultsPath = Join-Path $ConfigDir "vscode/settings.json"
    $overlay = Get-Content -Path $defaultsPath -Raw | ConvertFrom-Json

    if ($Plan.IsPresent) {
        Write-Host "    [plan] merge $defaultsPath into $settingsPath"
        return
    }

    if (-not (Test-Path $settingsPath)) {
        Backup-File -Path $settingsPath
        $parent = Split-Path -Parent $settingsPath
        if ($parent -and -not (Test-Path $parent)) {
            New-Item -ItemType Directory -Force -Path $parent | Out-Null
        }
        ConvertTo-Json -InputObject $overlay -Depth 32 | Out-File -FilePath $settingsPath -Encoding utf8
        Write-Host "    wrote $settingsPath"
        return
    }

    Backup-File -Path $settingsPath
    $current = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
    Merge-Object -Base $current -Overlay $overlay
    ConvertTo-Json -InputObject $current -Depth 32 | Out-File -FilePath $settingsPath -Encoding utf8
    Write-Host "    merged VS Code settings into $settingsPath"
}

function Write-DependencyHint {
    $optional = @("delta", "fzf", "starship", "lazygit", "bat")
    $missing = @($optional | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) })
    if ($missing.Count -gt 0) {
        Write-Host "==> Optional tools not found: $($missing -join ', ')"
        Write-Host "    These power the profile/Git config. Install via: .\windows\bootstrap.ps1 -WithScoop"
    }
}

if (-not ($Pwsh -or $Terminal -or $Git -or $VSCode -or $All)) {
    Show-Usage
    exit 1
}

if ($Plan.IsPresent) {
    Write-Host "==> Plan mode enabled. No files will be changed."
}

if ($All -or $Pwsh)     { Invoke-PwshConfig }
if ($All -or $Terminal) { Invoke-TerminalConfig }
if ($All -or $Git)      { Invoke-GitConfig }
if ($All -or $VSCode)   { Invoke-VSCodeConfig }

Write-DependencyHint

if ($Plan.IsPresent) {
    Write-Host "==> Plan completed."
} else {
    Write-Host "==> Configure completed."
}
