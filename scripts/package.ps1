$ErrorActionPreference='Stop'
$projectDir=Split-Path $PSScriptRoot -Parent
& (Join-Path $projectDir 'build.ps1')
if ($LASTEXITCODE -ne 0) {throw 'Build failed'}
$stage=Join-Path $projectDir ('.build/package-'+[guid]::NewGuid().ToString('N')+'/DepthVideo-Desktop')
New-Item -ItemType Directory -Path $stage -Force | Out-Null
foreach ($name in @('DepthVideo.exe','Microsoft.Web.WebView2.Core.dll','Microsoft.Web.WebView2.WinForms.dll','WebView2Loader.dll','WebView2-LICENSE.txt','README.md','LICENSE','DepthVideo.cs','app.manifest','build.ps1')) {
 Copy-Item -LiteralPath (Join-Path $projectDir $name) -Destination $stage
}
foreach ($name in @('ui','scripts')) {Copy-Item -LiteralPath (Join-Path $projectDir $name) -Destination $stage -Recurse}
New-Item -ItemType Directory -Path (Join-Path $stage 'engine') -Force | Out-Null
foreach ($name in @('depth_video.py','run.ps1','requirements.txt','THIRD_PARTY_NOTICES.md','vendor')) {
 Copy-Item -LiteralPath (Join-Path $projectDir ('engine/'+$name)) -Destination (Join-Path $stage 'engine') -Recurse
}
$dist=Join-Path $projectDir 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$zip=Join-Path $dist 'DepthVideo-Desktop-v1.1-source-build.zip'
Compress-Archive -LiteralPath $stage -DestinationPath $zip -Force
Write-Host "Package: $zip"
