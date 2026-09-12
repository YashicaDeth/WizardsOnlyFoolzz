# The gore sandbox, straight in. No menu, no save, no run-up to it.
$ErrorActionPreference = 'Stop'
$toolState = Get-Content -LiteralPath 'P:\GameDev\setup-state.json' -Raw | ConvertFrom-Json
$env:TEMP = 'P:\GameDev\Temp'
$env:TMP = $env:TEMP
$gamePath = Join-Path $PSScriptRoot 'game'
& $toolState.godot --path $gamePath res://gore_demo.tscn
