# Managed by personal-app-catalog. Sanitized template only - no secrets, no identity.
# configure.ps1 copies this next to $PROFILE as catalog.profile.ps1 and dot-sources it
# from $PROFILE through a guarded line. Your own $PROFILE body is never overwritten.

# --- PSReadLine: history-aware predictions and richer editing -----------------
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}

# --- Optional modules: load only when present ---------------------------------
if (Get-Module -ListAvailable -Name posh-git)        { Import-Module posh-git }
if (Get-Module -ListAvailable -Name Terminal-Icons)  { Import-Module Terminal-Icons }
if (Get-Module -ListAvailable -Name PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# --- Prompt: starship if available --------------------------------------------
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}

# --- Aliases / shortcuts ------------------------------------------------------
function ll { Get-ChildItem -Force @args }
function la { Get-ChildItem -Force -Hidden @args }
Set-Alias g git
if (Get-Command lazygit -ErrorAction SilentlyContinue) { Set-Alias lg lazygit }
if (Get-Command bat -ErrorAction SilentlyContinue)     { Set-Alias cat bat }
