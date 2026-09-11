$ErrorActionPreference = 'Stop'
$toolState = Get-Content -LiteralPath 'P:\GameDev\setup-state.json' -Raw | ConvertFrom-Json
$env:TEMP = 'P:\GameDev\Temp'
$env:TMP = $env:TEMP
$gamePath = Join-Path $PSScriptRoot 'game'
& $toolState.godot --path $gamePath --editor 'res://prototype_lab/lab.tscn'
