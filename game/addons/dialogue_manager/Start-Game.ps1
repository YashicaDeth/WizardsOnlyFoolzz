$ErrorActionPreference = 'Stop'
$toolState = Get-Content -LiteralPath 'P:\GameDev\setup-state.json' -Raw | ConvertFrom-Json
$env:TEMP = 'P:\GameDev\Temp'
$env:TMP = $env:TEMP
& $toolState.godot --path (Join-Path $PSScriptRoot 'game')
