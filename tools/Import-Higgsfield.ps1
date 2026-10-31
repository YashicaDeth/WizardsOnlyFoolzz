# Copies Greg's Higgsfield downloads into the repo so the cloud sessions can
# use them: every hf_*.png/.wav/.mp4 plus the named plates (seal, die,
# examiner, xray) from Downloads, and the code-only part of the newest
# hf_code_pack zip. Browser duplicates ("... (1).png") are skipped. The zip is
# extracted under P:\GameDev (large files live there), never inside the repo.
# Commits on its own branch and pushes, so no other worktree is touched.
param(
	[string]$Downloads = (Join-Path $env:USERPROFILE 'Downloads'),
	[string]$Branch = 'greg/higgsfield-art'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

git fetch origin claude/dust-to-bones-look
git checkout -B $Branch origin/claude/dust-to-bones-look

$art = Join-Path $repo 'game\art\higgsfield\incoming'
$sound = Join-Path $repo 'game\art\higgsfield\sounds'
$video = Join-Path $repo 'game\art\higgsfield\video'
New-Item -ItemType Directory -Force $art, $sound, $video | Out-Null

$named = 'seal.png', 'die.png', 'examiner.png', 'xray.png', 'xray_1024x2048.png', '1a_wizards_seal.png'
$files = Get-ChildItem -LiteralPath $Downloads -File | Where-Object {
	$_.Name -notmatch ' \(\d+\)\.' -and (
		($_.Name -like 'hf_*' -and $_.Extension -in '.png', '.wav', '.mp4') -or
		($named -contains $_.Name))
}
foreach ($f in $files) {
	$to = switch ($f.Extension) { '.wav' { $sound } '.mp4' { $video } default { $art } }
	Copy-Item -LiteralPath $f.FullName -Destination $to -Force
}
Write-Host ("copied {0} files" -f $files.Count)

$zip = Get-ChildItem -LiteralPath $Downloads -Filter 'hf_code_pack*.zip' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($zip) {
	$out = 'P:\GameDev\hf_code_pack'
	if (Test-Path $out) { Remove-Item -Recurse -Force $out }
	Expand-Archive -LiteralPath $zip.FullName -DestinationPath $out
	$code = Join-Path $repo 'reference\hf_code_pack'
	New-Item -ItemType Directory -Force $code | Out-Null
	# Code and docs only: shaders, scripts, manifest, tools, markdown.
	Get-ChildItem -LiteralPath $out -Recurse -File | Where-Object {
		$_.Extension -in '.gd', '.gdshader', '.json', '.md', '.py', '.tscn', '.godot', '.txt' -and
		$_.FullName -notmatch '\\assets\\raw\\' -and $_.FullName -notmatch '\\reference\\'
	} | ForEach-Object {
		$rel = $_.FullName.Substring($out.Length).TrimStart('\')
		$dest = Join-Path $code $rel
		New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
		Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
	}
	# Keep Godot from importing the pack as part of the game.
	New-Item -ItemType File -Force (Join-Path $repo 'reference\.gdignore') | Out-Null
	Write-Host "code pack from $($zip.Name)"
}

git add -- game/art/higgsfield reference/hf_code_pack reference/.gdignore
git commit -m "Art: Greg's Higgsfield downloads (plates, sounds, video) and the code-only hf_code_pack"
git push -u origin $Branch
