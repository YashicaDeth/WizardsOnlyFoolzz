param(
    [string]$Godot = "",
    [string]$Project = "game",
    [string]$InputLog = "",
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"

function Get-ProjectDiagnostics {
    param([string[]]$Lines)
    $found = [System.Collections.Generic.List[string]]::new()
    for ($index = 0; $index -lt $Lines.Count; $index++) {
        if ($Lines[$index] -notmatch '^(SCRIPT )?(WARNING|ERROR):') {
            continue
        }
        $block = [System.Collections.Generic.List[string]]::new()
        $block.Add($Lines[$index])
        for ($look = $index + 1; $look -lt [Math]::Min($index + 9, $Lines.Count); $look++) {
            if ($Lines[$look] -match '^(SCRIPT )?(WARNING|ERROR):') { break }
            $block.Add($Lines[$look])
        }
        $joined = $block -join "`n"
        # Addons have their own release cadence. J5 guards code owned by this
        # project; engine shutdown/leak messages have no res:// source at all.
        if ($joined -match 'res://(?!addons/)[^\s:)]+\.gd(?::\d+)?') {
            $found.Add($joined)
        }
    }
    return $found.ToArray()
}

if ($SelfTest) {
    $clean = @(
        'WARNING: 510 ObjectDB instances were leaked at exit.',
        '   at: cleanup (core/object/object.cpp:2536)'
    )
    $regression = @(
        'SCRIPT WARNING: The local variable "thing" is never used.',
        '   at: GDScript::reload (res://systems/example.gd:12)'
    )
    if ((Get-ProjectDiagnostics -Lines $clean).Count -ne 0) {
        Write-Error 'Diagnostic guard self-test counted engine shutdown noise.'
        exit 1
    }
    if ((Get-ProjectDiagnostics -Lines $regression).Count -ne 1) {
        Write-Error 'Diagnostic guard self-test did not fail on a new project warning.'
        exit 1
    }
    Write-Output 'DIAGNOSTIC_GUARD_SELF_TEST passed (clean=0, synthetic_regression=1)'
    exit 0
}

$lines = @()
if ($InputLog) {
    $lines = Get-Content -LiteralPath $InputLog
} else {
    if (-not $Godot) {
        foreach ($candidate in @('godot4', 'godot')) {
            $command = Get-Command $candidate -ErrorAction SilentlyContinue
            if ($command) {
                $Godot = $command.Source
                break
            }
        }
    }
    if (-not $Godot -or -not (Test-Path -LiteralPath $Godot)) {
        Write-Error 'Godot was not found. Pass -Godot with the editor executable path.'
        exit 2
    }
    $raw = & $Godot --editor --headless --path $Project --quit-after 8 2>&1
    $lines = @($raw | ForEach-Object { [string]$_ -replace "`e\[[0-9;]*[A-Za-z]", '' })
}

$diagnostics = @(Get-ProjectDiagnostics -Lines $lines)
if ($diagnostics.Count -gt 0) {
    Write-Output "GODOT_DIAGNOSTIC_BUDGET failed: $($diagnostics.Count) project diagnostic(s), budget 0"
    foreach ($diagnostic in $diagnostics) {
        Write-Output $diagnostic
    }
    exit 1
}

Write-Output 'GODOT_DIAGNOSTIC_BUDGET passed: 0 project script warnings/errors (budget 0)'
exit 0
