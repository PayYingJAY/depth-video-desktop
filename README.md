# 深度视频桌面版 · Depth Video Desktop

一个在 Windows 本机运行的视频相对深度转换工具。选择视频，生成灰度深度视频，并在同一个窗口预览原片和结果。

无需 Codex、API Key 或 ComfyUI。首次联网准备运行环境，此后可以离线处理。视频不会上传到服务器。

## 使用

下载发行版，完整解压，双击 `DepthVideo.exe`。选择视频和处理模式，点击「开始处理」。完成后可切换原片 / 深度结果，或打开结果文件夹。

- 快速模式：约 15 fps，按原帧率整步采样。
- 原帧率模式：保留原帧率，耗时更长。
- 支持取消任务，显示处理进度、用时和诊断日志。
- 原视频不会修改。结果在当前用户的「视频 / 深度视频」目录，每次任务单独保存。
- 窗口无法解码预览的格式仍可尝试处理。

需要 Windows 10/11 x64、Microsoft Edge WebView2 运行时，建议至少 8 GB 内存和 3 GB 可用磁盘。缺少 WebView2 时请安装 [微软官方运行时](https://developer.microsoft.com/microsoft-edge/webview2/)。

## 从源码构建

本项目使用 C# WinForms + WebView2，前端为原生 HTML/CSS/JavaScript。推理后端为 Python / PyTorch CPU，基于 [Video Depth Anything](https://github.com/DepthAnything/Video-Depth-Anything) Small。

在 Windows PowerShell 中进入仓库目录并运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

构建脚本下载并校验固定版本 WebView2 SDK，再用 Windows 自带 .NET Framework C# 编译器构建 `DepthVideo.exe`。首次运行处理任务时自动下载运行环境和模型。可将官方 Small 检查点预先放入 `engine/models/video_depth_anything_vits.pth`；程序会验证 SHA256。

要制作可分享的 ZIP：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\package.ps1
```

该 ZIP 不带模型和 Python 运行环境；首次运行需联网下载。源码仓库不包含预编译 DLL、EXE、模型权重、测试视频或用户日志。

## 文件结构

| 文件 | 职责 |
| --- | --- |
| `DepthVideo.cs` | 桌面窗口、文件选择、后台进程、进度与取消 |
| `ui/` | 本地界面和视频预览 |
| `engine/depth_video.py` | 深度推理、视频导出及检查 |
| `engine/run.ps1` | 首次安装和环境检查 |
| `engine/vendor/Video-Depth-Anything/` | 保留许可的上游推理源码 |

## 环境与下载

v1.1 将私有运行环境固定安装到 `%LOCALAPPDATA%\DV\r1`，避免微信长目录导致 PyTorch 安装失败。不修改系统 PATH、注册表或系统 Python。

首次安装来源：Python 官方、bootstrap.pypa.io、PyTorch 官方 CPU wheel 源、清华 PyPI 镜像；模型来自 Hugging Face 官方项目仓库。下载速度受网络影响，安装期间显示准备状态和日志，尚无精确下载百分比。已准备成功的环境会复用。

## 限制

- 输出为相对深度，不是米制距离；不包含自动换脸、换衣或视频生成。
- 推理前将画面缩小，再恢复输出尺寸；细线、发丝和服装边缘可能丢失细节。
- 每段默认最多 1800 个推理帧。可变帧率视频按平均帧率处理，精确音画同步应另行检查。
- 当前桌面版本使用 CPU，未提供自动 GPU 安装或切换。
- 首次依赖下载可能失败，日志保留具体原因；旧任务日志会累积。
- 取消或失败可能留下中间文件；以界面「处理完成」及同名 JSON 报告为准。
- 应用未做代码签名。不同电脑的系统组件、速度和可用内存有差异。

## 验证

已验证中文及空格路径、15 fps 输出、原帧率后端、带音轨/无音轨样片、取消、逐帧解码和短路径环境安装。约 15 秒样片在两台电脑的 CPU 处理耗时约 56–79 秒，仅供参考，不是性能保证。

## 许可与致谢

本项目包装代码采用 [Apache-2.0](LICENSE)。第三方代码仍遵循其原有许可，详见 [第三方说明](engine/THIRD_PARTY_NOTICES.md)。

Video Depth Anything 上游版本固定为 `4f5ae23172ba60fd7bc11ef671cca678842c7072`。只使用 Small 相对深度模型，不代表 Base/Large 等其他模型具有相同许可。

运行环境中的 FFmpeg、PyTorch 等由用户首次运行时从相应分发源安装。重新打包完整离线环境时，需要自行满足各依赖的再分发要求。
