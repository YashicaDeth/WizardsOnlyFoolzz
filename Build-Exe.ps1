$ErrorActionPreference = 'Stop'
# Exports a playable Windows build and zips it for handing to somebody.
# Uses the same Godot the other Start-*.ps1 scripts use. Release builds leave
# out tests, captures and the editor bridges (see game/export_presets.cfg).
$toolState = Get-Content -LiteralPath 'P:\GameDev\setup-state.json' -Raw | ConvertFrom-Json
$env:TEMP = 'P:\GameDev\Temp'
$env:TMP = $env:TEMP

$templates = Join-Path $env:APPDATA 'Godot\export_templates\4.7.2.stable'
if (-not (Test-Path (Join-Path $templates 'windows_release_x86_64.exe'))) {
    throw "Godot 4.7.2 export templates are missing from $templates. In the editor: Editor > Manage Export Templates > Download and Install."
}

$out = 'P:\GameDev\build\windows'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$exe = Join-Path $out 'WizardsOnlyFools.exe'

& $toolState.godot --headless --path (Join-Path $PSScriptRoot 'game') --export-release 'Windows Desktop' $exe
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $exe)) { throw "Export failed (exit $LASTEXITCODE)." }

$zip = 'P:\GameDev\build\WizardsOnlyFools-windows.zip'
Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zip -Force
Write-Host "Built $exe"
Write-Host "Zipped $zip"
