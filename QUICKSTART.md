# 开始使用 v1.1

1. 完整解压压缩包到一个文件夹，不要只拖出 EXE。
2. 双击 DepthVideo.exe。
3. 点击「选择视频」，保留默认「快速处理」，点击「开始处理」。
4. 首次保持联网，应用会自动准备运行环境；这一步可能需要数分钟。
5. 显示「处理完成」后，可预览结果或点击「打开结果文件夹」取出 MP4。

结果在当前用户的「视频 / 深度视频」目录。原视频不会修改，视频不上传，无需 API Key、Codex 或手动安装 Python。

## 两种下载包

- Windows-x64.zip：推荐，已含 Small 模型，约 108 MB。首次仍需下载 Python 和推理依赖。
- lite.zip：较小，不含模型；首次还要下载约 116 MB 模型。
- GitHub 自动生成的 Source code.zip 是源码，不是可直接运行的软件包。

## 常见问题

- 运行环境安装在 `%LOCALAPPDATA%\DV\r1`，不再受微信下载文件夹层级影响。
- `not on PATH` 和 `xFormers not available` 通常是提示；CPU 版无需额外处理。以本次任务的最终状态为准，日志可能含旧任务记录。
- 安装失败时查看日志中的具体错误：下载中断、磁盘不足、系统依赖等原因应分别处理。
- 缺少 WebView2：安装微软官方运行时 https://developer.microsoft.com/microsoft-edge/webview2/ 。
- DLL 加载失败：检查是否缺少 Microsoft Visual C++ 2015–2022 x64 运行库。
- 使用 Windows 10/11 64 位；建议至少 8 GB 内存和 3 GB 可用磁盘。

当前为便携式 ZIP，不是安装向导，也不是首次即可断网使用的完整离线包。应用未做代码签名。
