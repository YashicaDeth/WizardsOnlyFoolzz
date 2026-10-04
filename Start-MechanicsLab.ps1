# The mechanics lab (job 1): the world's mechanics, one station each, on the
# normal player body. Development only; the game never opens it.
$ErrorActionPreference = 'Stop'
$toolState = Get-Content -LiteralPath 'P:\GameDev\setup-state.json' -Raw | ConvertFrom-Json
$env:TEMP = 'P:\GameDev\Temp'
$env:TMP = $env:TEMP
$gamePath = Join-Path $PSScriptRoot 'game'
& $toolState.godot --path $gamePath res://lab/mechanics_lab.tscn
