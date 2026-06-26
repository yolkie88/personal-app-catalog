[CmdletBinding()]
param(
    [ValidateSet("Daily", "Weekly")]
    [string] $Frequency = "Weekly",

    [string] $Time = "03:00",

    [ValidateSet("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")]
    [string] $DayOfWeek = "Sunday",

    [string] $TaskName = "personal-app-catalog-update",

    [switch] $IncludeScoop,
    [switch] $Exclude,
    [switch] $Elevated,
    [switch] $Remove,
    [switch] $Plan
)

$ErrorActionPreference = "Stop"

$ScriptRootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$UpdatePath = Join-Path $ScriptRootPath "update.ps1"

if (-not (Test-Path $UpdatePath)) {
    throw "update.ps1 not found next to this script: $UpdatePath"
}

# Validate the time early (also used for the trigger) so a typo fails before any change.
try {
    $startTime = [datetime]::ParseExact($Time, 'HH:mm', [Globalization.CultureInfo]::InvariantCulture)
} catch {
    throw "Invalid -Time '$Time'. Use 24h HH:mm, e.g. 03:00 or 18:30."
}

# Prefer PowerShell 7 (pwsh) but fall back to Windows PowerShell for the task host.
$pwshCmd = Get-Command pwsh.exe -ErrorAction SilentlyContinue
if (-not $pwshCmd) {
    $pwshCmd = Get-Command powershell.exe -ErrorAction SilentlyContinue
}
if (-not $pwshCmd) {
    throw "Neither pwsh.exe nor powershell.exe found to host the scheduled task."
}
$pwshExe = $pwshCmd.Source

# Arguments passed to the host to run update.ps1 unattended.
$updateArgs = @(
    "-NoProfile",
    "-NonInteractive",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$UpdatePath`"",
    "-All"
)
if ($Exclude.IsPresent)      { $updateArgs += "-Exclude" }
if ($IncludeScoop.IsPresent) { $updateArgs += "-IncludeScoop" }
$argString = $updateArgs -join " "

$scheduleText = if ($Frequency -eq "Daily") { "Daily at $Time" } else { "Weekly on $DayOfWeek at $Time" }

# The ScheduledTasks cmdlets only exist on Windows. Plan mode stays
# side-effect-free and works anywhere; apply/remove require them.
$haveScheduler = [bool](Get-Command Register-ScheduledTask -ErrorAction SilentlyContinue)

if ($Plan.IsPresent) {
    Write-Host "==> Plan mode enabled. No scheduled task will be created or removed."
    if ($Remove.IsPresent) {
        Write-Host "    [plan] would remove scheduled task '$TaskName' (if it exists)."
    } else {
        Write-Host "    [plan] would register scheduled task '$TaskName':"
        Write-Host "           schedule : $scheduleText"
        Write-Host "           run-level: $([string]($(if ($Elevated.IsPresent) { 'Highest (elevated)' } else { 'Limited (current user)' })))"
        Write-Host "           command  : $pwshExe $argString"
    }
    Write-Host "==> Plan completed."
    return
}

if (-not $haveScheduler) {
    throw "schedule-update.ps1 manages a Windows Scheduled Task and must run on Windows. Use -Plan to preview elsewhere."
}

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($Remove.IsPresent) {
    if (-not $existing) {
        Write-Host "==> No scheduled task named '$TaskName'. Nothing to remove."
        return
    }
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "==> Removed scheduled task '$TaskName'."
    return
}

$action = New-ScheduledTaskAction -Execute $pwshExe -Argument $argString -WorkingDirectory $ScriptRootPath

if ($Frequency -eq "Daily") {
    $trigger = New-ScheduledTaskTrigger -Daily -At $startTime
} else {
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At $startTime
}

# Run as the current user, only when logged on (no stored password). Let it catch
# up if the machine was off, and not bail just because we're on battery.
$runLevel = if ($Elevated.IsPresent) { "Highest" } else { "Limited" }
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel $runLevel
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2)

$description = "personal-app-catalog: $scheduleText -> $argString"

# Register-ScheduledTask -Force is idempotent: it replaces an existing task with
# the same name rather than erroring.
Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description $description `
    -Force | Out-Null

$verb = if ($existing) { "Updated" } else { "Registered" }
Write-Host "==> $verb scheduled task '$TaskName'."
Write-Host "    schedule : $scheduleText"
Write-Host "    run-level: $runLevel"
Write-Host "    command  : $pwshExe $argString"
Write-Host ""
Write-Host "Inspect : Get-ScheduledTask -TaskName '$TaskName'"
Write-Host "Run now : Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "Remove  : .\windows\schedule-update.ps1 -Remove"
Write-Host ""
Write-Host "Note: the task runs only when '$($env:USERNAME)' is logged on. Machine-scope"
Write-Host "      upgrades that need elevation may be skipped unless you pass -Elevated."
