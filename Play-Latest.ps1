param([switch]$Overworld)
$ErrorActionPreference = 'Stop'
# Greg, 26 September: "stop making zip files, it's pointless."
# Plays the newest integration branch straight from source. No zips, no parts.
# It keeps its own checkout at P:\GameDev\playtest (a git worktree, detached),
# so it never switches branches or touches uncommitted work in this folder,
# where Codex and OpenCode run.
$branch = 'claude/dust-to-bones-look'
$play = 'P:\GameDev\playtest'
$toolState = Get-Content -LiteralPath 'P:\GameDev\setup-state.json' -Raw | ConvertFrom-Json
$env:TEMP = 'P:\GameDev\Temp'
$env:TMP = $env:TEMP

Write-Host "Fetching $branch..."
git -C $PSScriptRoot fetch origin $branch
if ($LASTEXITCODE -ne 0) { throw "git fetch failed (exit $LASTEXITCODE). Check the network or GitHub login." }
if (-not (Test-Path (Join-Path $play '.git'))) {
    git -C $PSScriptRoot worktree add --detach $play "origin/$branch"
} else {
    git -C $play checkout --detach --force "origin/$branch"
}
if ($LASTEXITCODE -ne 0) { throw "Could not update $play (exit $LASTEXITCODE)." }
$commit = git -C $play rev-parse --short HEAD
Write-Host "Playing $commit. Importing first (a few minutes the first time, seconds after)..."
# A fresh checkout has no import cache, so the game's named scripts are not
# registered yet and the title screen's own script fails to run (bare menu, no
# DEMO button). The editor normally does this; a headless import does it here.
& $toolState.godot --headless --path (Join-Path $play 'game') --import | Out-Null
if ($Overworld) {
    # Straight into the Hunt (the overworld) at 13:00, daylight.
    & $toolState.godot --path (Join-Path $play 'game') 'res://bone_yard_hunt.tscn' -- --daytime
} else {
    & $toolState.godot --path (Join-Path $play 'game')
}
