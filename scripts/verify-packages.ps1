$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
foreach ($name in @('DepthVideo-Desktop-v1.1-lite.zip','DepthVideo-Desktop-v1.1-Windows-x64.zip')) {
 $path=Join-Path $root ('dist/'+$name)
 $hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
 if ((Get-Content -LiteralPath "$path.sha256" -Raw).Trim() -ne "$hash  $name") {throw "Checksum mismatch: $name"}
 $zip=[IO.Compression.ZipFile]::OpenRead($path)
 try {
  $files=@($zip.Entries | ForEach-Object {$_.FullName.Replace('\','/')})
  foreach ($required in @('DepthVideo.exe','ui/index.html','engine/depth_video.py','engine/run.ps1','WebView2Loader.dll','LICENSE','QUICKSTART.md')) {
   if ($files -notcontains "DepthVideo-Desktop/$required") {throw "Missing $required in $name"}
  }
  if ($files | Where-Object {$_ -match '/(runtime|results|\.git)/|\.log$|\.mp4$|\.env$'}) {throw "Unexpected private/runtime files in $name"}
  $model=$zip.GetEntry('DepthVideo-Desktop/engine/models/video_depth_anything_vits.pth')
  if ($name -like '*Windows-x64*') {
   if ($null -eq $model) {throw 'Model missing from recommended package'}
   $stream=$model.Open();$sha=[Security.Cryptography.SHA256]::Create()
   try {$actual=([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant()} finally {$stream.Dispose();$sha.Dispose()}
   if ($actual -ne '13379300b739e659f076a59d52e9801bd8d38c541a7e71f73bbca4dcfb013609') {throw 'Packaged model checksum mismatch'}
  } elseif ($null -ne $model) {throw 'Lite package unexpectedly includes model'}
 } finally {$zip.Dispose()}
 Write-Host "Verified $name"
}
