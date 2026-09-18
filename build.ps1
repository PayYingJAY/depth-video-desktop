param([string]$OutputName='DepthVideo.exe')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
 $sdkVersion='1.0.4191.47'
 $sdkSha='F492BBF547D0DA329553B6727435B677579B1E9F91CC9E4A1AD029366D5F23D0'
 $cache=Join-Path $PSScriptRoot '.build'
 $archive=Join-Path $cache 'webview2-sdk.zip'
 New-Item -ItemType Directory -Path $cache -Force | Out-Null
 if (-not (Test-Path -LiteralPath $archive)) {
  [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -UseBasicParsing -Uri "https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/$sdkVersion/microsoft.web.webview2.$sdkVersion.nupkg" -OutFile "$archive.part"
  Move-Item -LiteralPath "$archive.part" -Destination $archive -Force
 }
 if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $sdkSha) {throw 'WebView2 SDK checksum mismatch. Remove .build/webview2-sdk.zip and retry.'}
 $sdk=Join-Path $cache 'webview2-sdk'
 Expand-Archive -LiteralPath $archive -DestinationPath $sdk -Force
 foreach ($name in @('Microsoft.Web.WebView2.Core.dll','Microsoft.Web.WebView2.WinForms.dll')) {Copy-Item -LiteralPath (Join-Path $sdk "lib/net462/$name") -Destination $PSScriptRoot -Force}
 Copy-Item -LiteralPath (Join-Path $sdk 'runtimes/win-x64/native/WebView2Loader.dll') -Destination $PSScriptRoot -Force
 Copy-Item -LiteralPath (Join-Path $sdk 'LICENSE.txt') -Destination (Join-Path $PSScriptRoot 'WebView2-LICENSE.txt') -Force
 & "$env:WINDIR/Microsoft.NET/Framework64/v4.0.30319/csc.exe" /nologo /target:winexe /platform:x64 "/out:$OutputName" /win32manifest:app.manifest /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:Microsoft.Web.WebView2.Core.dll /r:Microsoft.Web.WebView2.WinForms.dll DepthVideo.cs
 if ($LASTEXITCODE -ne 0) {throw 'Build failed'}
} finally {Pop-Location}
