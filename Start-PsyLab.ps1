# The gore sandbox with TouchDesigner wired into its look (FINAL_V section 16,
# Path C). Start this, then run tools/touchdesigner/build_psy_dials.py in TD's
# Textport. Development only - the bridge refuses to open a port in an export.
$ErrorActionPreference = 'Stop'
$toolState = Get-Content -LiteralPath 'P:\GameDev\setup-state.json' -Raw | ConvertFrom-Json
$env:TEMP = 'P:\GameDev\Temp'
$env:TMP = $env:TEMP
$gamePath = Join-Path $PSScriptRoot 'game'
& $toolState.godot --path $gamePath res://psy_lab.tscn -- "--osc-port=9000"
