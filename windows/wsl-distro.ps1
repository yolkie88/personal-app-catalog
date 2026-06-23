[CmdletBinding()]
param(
    [string] $Distro = "Ubuntu-26.04",
    [switch] $Install,
    [switch] $SetDefault,
    [switch] $NoLaunch,
    [switch] $Plan
)

$ErrorActionPreference = "Stop"

function Assert-WslCommand {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        throw "wsl.exe is not available. Enable or install WSL first."
    }
}

function Get-InstalledWslDistros {
    $output = & wsl.exe --list --quiet 2>$null
    if ($LASTEXITCODE -ne 0) {
        return @()
    }

    $output |
        ForEach-Object { ($_ -replace [char]0, "").Trim() } |
        Where-Object { $_ }
}

function Test-WslDistroInstalled {
    param([string] $Name)

    $installed = @(Get-InstalledWslDistros)
    $installed -contains $Name
}

function Invoke-PlanCommand {
    param([string] $Command)

    Write-Host "[plan] $Command"
}

# -Plan is a pure dry run that prints what would run, so it must not require wsl.exe
# (CI executes it on Linux pwsh). Only assert the command for real execution.
if (-not $Plan.IsPresent) {
    Assert-WslCommand
}

if ($Plan.IsPresent) {
    Invoke-PlanCommand "wsl.exe --list --verbose"
    if ($Install.IsPresent) {
        $args = "wsl.exe --install -d $Distro"
        if ($NoLaunch.IsPresent) {
            $args = "$args --no-launch"
        }
        Invoke-PlanCommand $args
    } else {
        Invoke-PlanCommand "check installed distro: $Distro"
    }
    if ($SetDefault.IsPresent) {
        Invoke-PlanCommand "wsl.exe --set-default $Distro"
    }
    exit 0
}

$installed = Test-WslDistroInstalled -Name $Distro

if (-not $installed) {
    if (-not $Install.IsPresent) {
        Write-Host "Installed WSL distributions:"
        @(Get-InstalledWslDistros) | ForEach-Object { Write-Host "  $_" }
        throw "WSL distribution '$Distro' is not installed. Run: .\windows\wsl-distro.ps1 -Install -Distro $Distro"
    }

    Write-Host "==> Installing WSL distribution: $Distro"
    $installArgs = @("--install", "-d", $Distro)
    if ($NoLaunch.IsPresent) {
        $installArgs += "--no-launch"
    }

    & wsl.exe @installArgs
    if ($LASTEXITCODE -ne 0) {
        throw "wsl --install failed for '$Distro' with exit code $LASTEXITCODE. Run 'wsl --list --online' to check available distro names."
    }

    Write-Host "==> WSL distribution install requested: $Distro"
    Write-Host "==> Launch the distribution once to create the Linux user if this is a fresh install."
} else {
    Write-Host "==> WSL distribution already installed: $Distro"
}

if ($SetDefault.IsPresent) {
    Write-Host "==> Setting default WSL distribution: $Distro"
    & wsl.exe --set-default $Distro
    if ($LASTEXITCODE -ne 0) {
        throw "wsl --set-default failed for '$Distro' with exit code $LASTEXITCODE."
    }
}

Write-Host "==> Current WSL distributions:"
& wsl.exe --list --verbose
