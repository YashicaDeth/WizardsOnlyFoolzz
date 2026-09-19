# Orca worktree setup -- Wizards Only Fools
#
# Point Orca's "setup script" at this file. It runs once, in each new worktree,
# before an agent starts. Everything in here exists because of something that
# actually cost this project hours.
#
#   Orca -> project settings -> setup script:
#     powershell -ExecutionPolicy Bypass -File .\setup\orca_worktree_setup.ps1
#
# It is deliberately loud. An agent that starts in a worktree where the class
# cache has not been built will be handed false "function not found" and
# "Could not find type" errors for code that is perfectly fine, and will spend
# its first hour fixing a bug that does not exist. That happened repeatedly.

$ErrorActionPreference = "Continue"
$godot = "P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
$root  = Split-Path -Parent $PSScriptRoot
$game  = Join-Path $root "game"

Write-Host ""
Write-Host "=== Wizards Only Fools :: worktree setup ===" -ForegroundColor Cyan
Write-Host "worktree: $root"

if (-not (Test-Path $godot)) {
    Write-Host "!! Godot not found at $godot -- nothing here will work." -ForegroundColor Red
    exit 1
}

# --- 1a. Copy gitignored addons the project expects on disk -------------------
# game/addons/{limboai,terrain_3d}/ are in .gitignore (large compiled binaries)
# so a fresh `git worktree add` never brings them along.
#   - limboai: rival_tactics.gd hard-`preload()`s it, and bone_yard_hunt.gd
#     hard-`preload()`s rival_tactics.gd -- so a worktree missing this addon
#     fails to compile the Hunt scene, the core of the whole demo, while still
#     printing PASS on tests that do not happen to instantiate it directly.
#     Chased as a phantom bug once already; do not repeat it.
#   - terrain_3d: listed in project.godot's `enabled` plugins, so its absence
#     does not break compilation but does spam a plugin-load warning on every
#     editor/import invocation.
Write-Host ""
Write-Host "[1/4] Checking for gitignored addons the worktree does not bring along..." -ForegroundColor Yellow
$addonSrcRoot = "P:/GameDev/AllusionsTooGrandeur/game/addons"
foreach ($addon in @(
    @{ Name = "limboai"; Marker = "bin/limboai.gdextension" },
    @{ Name = "terrain_3d"; Marker = "plugin.cfg" }
)) {
    $dest = Join-Path $game "addons/$($addon.Name)"
    $marker = Join-Path $dest $addon.Marker
    if (-not (Test-Path $marker)) {
        $src = Join-Path $addonSrcRoot $addon.Name
        $srcMarker = Join-Path $src $addon.Marker
        if (Test-Path $srcMarker) {
            Write-Host "      $($addon.Name) missing -- copying from $src ..." -ForegroundColor Yellow
            Copy-Item -Path $src -Destination $dest -Recurse -Force
            Write-Host "      done." -ForegroundColor Green
        } else {
            Write-Host "      !! $($addon.Name) missing here AND at $src." -ForegroundColor Red
        }
    } else {
        Write-Host "      $($addon.Name) already present." -ForegroundColor Green
    }
}

# --- 1. Build the class cache -------------------------------------------------
# A fresh worktree has no .godot/ cache. Until this runs, every global class_name
# in the project is invisible: `--check-only` reports missing types, and a stale
# cache reports "function not found" for functions that plainly exist. Both were
# chased as real bugs today. This takes a couple of minutes and saves hours.
Write-Host ""
Write-Host "[2/4] Building the class cache (this is the one that prevents phantom parse errors)..." -ForegroundColor Yellow
$env:TEMP = "P:/GameDev/Temp"
$env:TMP  = "P:/GameDev/Temp"
& $godot --headless --path $game --import 2>&1 | Out-Null
Write-Host "      done."

# --- 2. Report the known-broken file -----------------------------------------
# substance_objects.gd is mid-write and does not compile. It produces parse
# errors in an otherwise clean import, and -- the dangerous part -- it makes
# UNRELATED test suites print nothing at all, which reads exactly like a pass.
# A baseline measured with this file broken is not a baseline.
Write-Host ""
Write-Host "[3/4] Checking the known-broken file..." -ForegroundColor Yellow
$substance = Join-Path $game "systems/substance_objects.gd"
$broken = $false
foreach ($fn in @("_blob", "_taper", "_build_graft", "_build_cone")) {
    if (-not (Select-String -Path $substance -Pattern "func $fn" -Quiet)) { $broken = $true }
}
if ($broken) {
    Write-Host "      !! substance_objects.gd DOES NOT COMPILE (helpers still missing)." -ForegroundColor Red
    Write-Host "      !! It will make unrelated tests print NOTHING and look like they passed." -ForegroundColor Red
    Write-Host "      !! To measure or build anything:" -ForegroundColor Red
    Write-Host "         cp game/systems/substance_objects.gd SAFE_COPY.gd" -ForegroundColor DarkGray
    Write-Host "         git checkout -- game/systems/substance_objects.gd" -ForegroundColor DarkGray
    Write-Host "         ...measure/build..." -ForegroundColor DarkGray
    Write-Host "         cp SAFE_COPY.gd back            # ALWAYS. Never commit over it." -ForegroundColor DarkGray
} else {
    Write-Host "      substance_objects.gd looks complete -- this warning can be deleted." -ForegroundColor Green
}

# --- 3. Remind the agent whose files these are -------------------------------
Write-Host ""
Write-Host "[4/4] Ownership" -ForegroundColor Yellow
Write-Host "      Read AGENT_SPLIT_6.md and AGENT_BRIEF_CURRENT.md before touching anything."
Write-Host "      NEVER run 'git add -A'. ~140 .import/.uid files churn constantly, and two" -ForegroundColor Red
Write-Host "      blanket adds today swept other agents' uncommitted work into unrelated commits." -ForegroundColor Red
Write-Host "      Stage by explicit path. Always."
Write-Host ""
Write-Host "Run a test:" -ForegroundColor Cyan
Write-Host ('  $env:ATG_TEST_MODE=1; & "' + $godot + '" --headless --path game res://tests/X.tscn')
Write-Host ""
