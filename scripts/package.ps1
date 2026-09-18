param([switch]$WithModel)
$ErrorActionPreference='Stop'
$projectDir=Split-Path $PSScriptRoot -Parent
& (Join-Path $projectDir 'build.ps1')
if ($LASTEXITCODE -ne 0) {throw 'Build failed'}
$stage=Join-Path $projectDir ('.build/package-'+[guid]::NewGuid().ToString('N')+'/DepthVideo-Desktop')
New-Item -ItemType Directory -Path $stage -Force | Out-Null
foreach ($name in @('DepthVideo.exe','Microsoft.Web.WebView2.Core.dll','Microsoft.Web.WebView2.WinForms.dll','WebView2Loader.dll','WebView2-LICENSE.txt','README.md','QUICKSTART.md','CHANGELOG.md','LICENSE','DepthVideo.cs','app.manifest','build.ps1')) {
 Copy-Item -LiteralPath (Join-Path $projectDir $name) -Destination $stage
}
foreach ($name in @('ui','scripts')) {Copy-Item -LiteralPath (Join-Path $projectDir $name) -Destination $stage -Recurse}
New-Item -ItemType Directory -Path (Join-Path $stage 'engine') -Force | Out-Null
foreach ($name in @('depth_video.py','run.ps1','requirements.txt','THIRD_PARTY_NOTICES.md','vendor')) {
 Copy-Item -LiteralPath (Join-Path $projectDir ('engine/'+$name)) -Destination (Join-Path $stage 'engine') -Recurse
}
$dist=Join-Path $projectDir 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
if ($WithModel) {
 $model=Join-Path $projectDir 'engine/models/video_depth_anything_vits.pth'
 if (-not (Test-Path -LiteralPath $model)) {throw 'Model missing: run scripts/download-model.ps1 first.'}
 if ((Get-FileHash -LiteralPath $model -Algorithm SHA256).Hash -ne '13379300b739e659f076a59d52e9801bd8d38c541a7e71f73bbca4dcfb013609') {throw 'Model checksum mismatch'}
 New-Item -ItemType Directory -Path (Join-Path $stage 'engine/models') -Force | Out-Null
 Copy-Item -LiteralPath $model -Destination (Join-Path $stage 'engine/models')
}
$filename=if ($WithModel) {'DepthVideo-Desktop-v1.1-Windows-x64.zip'} else {'DepthVideo-Desktop-v1.1-lite.zip'}
$zip=Join-Path $dist $filename
Compress-Archive -LiteralPath $stage -DestinationPath $zip -Force
$hash=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText("$zip.sha256", "$hash  $filename`n", (New-Object Text.UTF8Encoding($false)))
Write-Host "Package: $zip"
