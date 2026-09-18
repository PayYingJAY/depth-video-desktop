$ErrorActionPreference='Stop'
$modelDir=Join-Path (Split-Path $PSScriptRoot -Parent) 'engine/models'
New-Item -ItemType Directory -Path $modelDir -Force | Out-Null
$target=Join-Path $modelDir 'video_depth_anything_vits.pth'
$expected='13379300b739e659f076a59d52e9801bd8d38c541a7e71f73bbca4dcfb013609'
if ((Test-Path -LiteralPath $target) -and (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -eq $expected) {Write-Host 'Verified existing Small model'; exit 0}
$url='https://huggingface.co/depth-anything/Video-Depth-Anything-Small/resolve/main/video_depth_anything_vits.pth'
& curl.exe --fail --location --retry 3 --connect-timeout 30 --max-time 600 --output "$target.part" $url
if ($LASTEXITCODE -ne 0) {throw 'Model download failed'}
if ((Get-FileHash -LiteralPath "$target.part" -Algorithm SHA256).Hash -ne $expected) {throw 'Model checksum mismatch; not using downloaded file'}
Move-Item -LiteralPath "$target.part" -Destination $target -Force
Write-Host 'Small model download verified'
