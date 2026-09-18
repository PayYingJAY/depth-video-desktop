param([switch]$SetupOnly,[switch]$OriginalFps,[switch]$ChinaMirror,[Parameter(ValueFromRemainingArguments=$true)][string[]]$Videos)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$baseDir=$PSScriptRoot
$runtimeDir=if ($env:DEPTHVIDEO_RUNTIME_DIR) {$env:DEPTHVIDEO_RUNTIME_DIR} else {Join-Path $env:LOCALAPPDATA 'DV/r1'}
$runtimeDir=[IO.Path]::GetFullPath($runtimeDir)
if ($runtimeDir.Length -gt 70) {Write-Host 'Runtime path too long. Use a shorter per-user runtime directory.'; exit 1}
Write-Host "Runtime directory: $runtimeDir"
$pythonExe=Join-Path $runtimeDir 'python.exe'
$env:PYTHONUTF8='1'
$env:PYTHONIOENCODING='utf-8'
$packageIndex=if ($ChinaMirror) {'https://pypi.tuna.tsinghua.edu.cn/simple'} else {'https://pypi.org/simple'}
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
function Fetch([string]$Url,[string]$Target) {
    Write-Host "Downloading $Url"
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile "$Target.part"
    Move-Item -LiteralPath "$Target.part" -Destination $Target -Force
}
try {
    if (-not (Test-Path -LiteralPath $pythonExe)) {
        New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
        $archive=Join-Path $runtimeDir 'python-3.12.10-embed-amd64.zip'
        Fetch 'https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-amd64.zip' $archive
        Expand-Archive -LiteralPath $archive -DestinationPath $runtimeDir -Force
    }
    # Embedded Python is private to this directory; system Python/PATH are unchanged.
    $pth=Join-Path $runtimeDir 'python312._pth'
    Set-Content -LiteralPath $pth -Encoding ASCII -Value @('python312.zip','.','Lib/site-packages','import site')
    $ready=Join-Path $runtimeDir 'depthvideo-v1-isolated.ready'
    if (-not (Test-Path -LiteralPath $ready)) {
        $pipScript=Join-Path $runtimeDir 'get-pip.py'
        if (-not (Test-Path -LiteralPath $pipScript)) { Fetch 'https://bootstrap.pypa.io/get-pip.py' $pipScript }
        & $pythonExe -s $pipScript --disable-pip-version-check --index-url $packageIndex
        if ($LASTEXITCODE -ne 0) { throw 'pip setup failed; check network and retry.' }
        & $pythonExe -s -m pip install --disable-pip-version-check --timeout 45 --retries 2 --no-deps torch==2.5.1 torchvision==0.20.1 --index-url https://download.pytorch.org/whl/cpu
        if ($LASTEXITCODE -ne 0) { throw 'PyTorch installation failed. Check the preceding error for path length, disk space, permissions or download issues.' }
        & $pythonExe -s -m pip install --disable-pip-version-check --timeout 45 --retries 2 -r (Join-Path $baseDir 'requirements.txt') torch==2.5.1 torchvision==0.20.1 --index-url $packageIndex
        if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed; check network and retry.' }
        & $pythonExe -s -c 'import torch, torchvision, cv2, numpy, einops, easydict, imageio_ffmpeg, tqdm'
        if ($LASTEXITCODE -ne 0) { throw 'Dependency check failed. If DLL errors occur, install Microsoft Visual C++ x64 Redistributable.' }
        Set-Content -LiteralPath $ready -Value '1'
    }
    if ($SetupOnly) {
        & $pythonExe -s (Join-Path $baseDir 'depth_video.py') --download-only
        if ($LASTEXITCODE -ne 0) { throw 'Model download failed; check network and retry.' }
    } else {
        if (-not $Videos) { $Videos=@((Read-Host 'Paste the full video path, then press Enter').Trim('"')) }
        $fps=if ($OriginalFps) {'0'} else {'15'}
        & $pythonExe -s (Join-Path $baseDir 'depth_video.py') --fps $fps @Videos
        if ($LASTEXITCODE -ne 0) { throw 'Processing failed. Read the error above; original video was not modified.' }
    }
    Write-Host 'Done. Output videos are in the results folder.'
    exit 0
} catch {
    Write-Host $_ -ForegroundColor Red
    exit 1
}
