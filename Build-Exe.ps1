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

# `setup-state.json` may point at the GUI Godot executable. Invoking a GUI
# executable with `&` can return control before export has finished, which made
# the old script test for the EXE while Godot was still writing it. An explicit
# process wait makes the artifact check truthful for either GUI or console Godot.
$project = Join-Path $PSScriptRoot 'game'
# Start-Process joins ArgumentList entries into one command line, so values that
# contain spaces must carry their own quotes or Godot sees the preset as merely
# "Windows".
$quotedProject = '"' + $project + '"'
$quotedPreset = '"Windows Desktop"'
$quotedExe = '"' + $exe + '"'
$godotArgs = @('--headless', '--path', $quotedProject, '--export-release', $quotedPreset, $quotedExe)
$export = Start-Process -FilePath $toolState.godot -ArgumentList $godotArgs -Wait -NoNewWindow -PassThru
if ($export.ExitCode -ne 0 -or -not (Test-Path $exe)) { throw "Export failed (exit $($export.ExitCode))." }

# Put the identity beside the executable so a playtest report can always name
# the exact source it came from. A dirty suffix is deliberate: it prevents a
# local experimental build from masquerading as its last committed revision.
$commit = (& git -C $PSScriptRoot rev-parse --short=12 HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($commit)) { throw 'Could not identify the source commit.' }
$dirty = if (& git -C $PSScriptRoot status --porcelain) { '+dirty' } else { '' }
$buildIdentity = "Wizards Only Fools $commit$dirty"
$buildTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'
Set-Content -LiteralPath (Join-Path $out 'BUILD-IDENTITY.txt') -Value @($buildIdentity, "Built $buildTime")

$zip = 'P:\GameDev\build\WizardsOnlyFools-windows.zip'
Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zip -Force
Write-Host "Built $exe"
Write-Host "Zipped $zip"
