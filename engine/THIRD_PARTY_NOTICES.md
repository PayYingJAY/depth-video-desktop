# Third-party notices

## Video Depth Anything

Source: https://github.com/DepthAnything/Video-Depth-Anything

Revision: 4f5ae23172ba60fd7bc11ef671cca678842c7072

Copyright (2025) Bytedance Ltd. and/or its affiliates. Apache License 2.0.

The original Python inference sources (video_depth_anything and utils), README and LICENSE are included under vendor/Video-Depth-Anything. The inference source files are not modified. Their existing copyright notices and licenses are retained, including notices inherited from Depth Anything, DINOv2 and other components.

This wrapper only downloads the **Small relative-depth** checkpoint, not Base/Large models. The official project identifies the Small model as Apache-2.0; Base/Large have different licensing. Do not infer licensing of other checkpoints from this package.

Checkpoint source: https://huggingface.co/depth-anything/Video-Depth-Anything-Small

Expected SHA256: 13379300b739e659f076a59d52e9801bd8d38c541a7e71f73bbca4dcfb013609

## Runtime dependencies

The small launcher ZIP does not bundle Python, PyTorch, model weights or FFmpeg binaries. The with-model variant also includes the Apache-2.0 Small checkpoint described above. Setup downloads runtime dependencies from their upstream package distributors; the optional Setup-China entry uses the Tsinghua PyPI mirror for ordinary Python dependencies. Installed packages and runtime distributions retain their own license files. Python: PSF license; PyTorch/torchvision: upstream BSD-style licenses; NumPy: BSD; OpenCV: Apache-2.0; Pillow: HPND; imageio-ffmpeg wrapper: BSD; bundled FFmpeg binary: see its build/license information (may include GPL components); einops: MIT; easydict: LGPL-3.0; tqdm: MPL-2.0/MIT as documented upstream.

If redistributing a fully installed offline runtime, preserve ALL upstream license files and satisfy applicable binary/source-distribution requirements, especially for the included FFmpeg build and LGPL/GPL dependencies. The default deliverable is the source/launcher ZIP, not an independently re-licensed runtime bundle.

Runtime sources: https://www.python.org/ ; https://pytorch.org/ ; https://pypi.org/ ; https://ffmpeg.org/
