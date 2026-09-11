$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$setupRoot = 'P:\GameDev'
$env:TEMP = Join-Path $setupRoot 'Temp'
$env:TMP = $env:TEMP
foreach ($folder in @('Tools', 'Downloads', 'Cache', 'Temp', 'AllusionsTooGrandeur')) {
    New-Item -ItemType Directory -Path (Join-Path $setupRoot $folder) -Force | Out-Null
}

function Get-VerifiedDownload {
    param([string]$Url, [string]$Destination, [string]$Sha256)
    if (-not (Test-Path -LiteralPath $Destination)) {
        Write-Output ('Downloading ' + [IO.Path]::GetFileName($Destination))
        Invoke-WebRequest -Uri $Url -OutFile $Destination
    }
    $actualHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    if ($actualHash -ne $Sha256) { throw ('Checksum mismatch: ' + $Destination) }
    Write-Output ('Verified ' + [IO.Path]::GetFileName($Destination))
}

$godotTag = '4.7.2-stable'
$release = Invoke-RestMethod -Uri ('https://api.github.com/repos/godotengine/godot-builds/releases/tags/' + $godotTag)
$godotAsset = @($release.assets | Where-Object { $_.name -eq 'Godot_v4.7.2-stable_win64.exe.zip' })
if ($godotAsset.Count -ne 1 -or $godotAsset[0].digest -notmatch '^sha256:([a-fA-F0-9]{64})$') {
    throw 'Official Godot release did not provide the expected Windows archive and digest.'
}
$godotHash = $Matches[1]
$godotArchive = Join-Path $setupRoot ('Downloads\' + $godotAsset[0].name)
Get-VerifiedDownload -Url $godotAsset[0].browser_download_url -Destination $godotArchive -Sha256 $godotHash
$godotFolder = Join-Path $setupRoot 'Tools\Godot-4.7.2'
if (-not (Test-Path -LiteralPath (Join-Path $godotFolder 'Godot_v4.7.2-stable_win64.exe'))) {
    Expand-Archive -LiteralPath $godotArchive -DestinationPath $godotFolder
}
# Godot's supported portable mode keeps editor settings and caches beside it on P:.
New-Item -ItemType File -Path (Join-Path $godotFolder '_sc_') -Force | Out-Null

$nodeVersion = 'v24.20.0'
$nodeArchiveName = 'node-v24.20.0-win-x64.zip'
$nodeBaseUrl = 'https://nodejs.org/dist/' + $nodeVersion + '/'
$nodeChecksums = (Invoke-WebRequest -Uri ($nodeBaseUrl + 'SHASUMS256.txt')).Content
$nodeChecksumLine = @($nodeChecksums -split "`n" | Where-Object { $_.Trim().EndsWith($nodeArchiveName) })
if ($nodeChecksumLine.Count -ne 1) { throw 'Missing official Node checksum.' }
$nodeHash = ($nodeChecksumLine[0].Trim() -split '\s+')[0]
$nodeArchive = Join-Path $setupRoot ('Downloads\' + $nodeArchiveName)
Get-VerifiedDownload -Url ($nodeBaseUrl + $nodeArchiveName) -Destination $nodeArchive -Sha256 $nodeHash
$nodeFolder = Join-Path $setupRoot 'Tools\node-v24.20.0-win-x64'
if (-not (Test-Path -LiteralPath (Join-Path $nodeFolder 'node.exe'))) {
    Expand-Archive -LiteralPath $nodeArchive -DestinationPath (Join-Path $setupRoot 'Tools')
}

$godotExe = Join-Path $godotFolder 'Godot_v4.7.2-stable_win64.exe'
$nodeExe = Join-Path $nodeFolder 'node.exe'
foreach ($executable in @($godotExe, $nodeExe)) {
    $signature = Get-AuthenticodeSignature -LiteralPath $executable
    if ($signature.Status -ne 'Valid') { throw ('Executable signature is not valid: ' + $executable) }
    Write-Output ('Signed: ' + $signature.SignerCertificate.Subject)
    $checkExecutable = $executable
    if ($executable -eq $godotExe) {
        $checkExecutable = Join-Path $godotFolder 'Godot_v4.7.2-stable_win64_console.exe'
    }
    $versionOutput = & $checkExecutable --version
    if ($LASTEXITCODE -ne 0) { throw ('Version check failed: ' + $checkExecutable) }
    Write-Output $versionOutput
}

[pscustomobject]@{
    project = 'P:\GameDev\AllusionsTooGrandeur'
    godot = $godotExe
    godot_version = $godotTag
    node = $nodeExe
    node_version = $nodeVersion
    npm_cli = (Join-Path $nodeFolder 'node_modules\npm\bin\npm-cli.js')
    verified_at = [DateTime]::UtcNow.ToString('o')
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $setupRoot 'setup-state.json') -Encoding utf8
Write-Output 'Portable tools installed and verified on P:.'
