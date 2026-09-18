"""Local relative-depth video conversion. Wrapper licensed under Apache-2.0."""
import argparse
import hashlib
import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import time
import types
import urllib.request

BASE = Path(__file__).resolve().parent
MODEL_URL = 'https://huggingface.co/depth-anything/Video-Depth-Anything-Small/resolve/main/video_depth_anything_vits.pth'
MODEL_SHA = '13379300b739e659f076a59d52e9801bd8d38c541a7e71f73bbca4dcfb013609'

def weights():
    path = BASE/'models/video_depth_anything_vits.pth'
    path.parent.mkdir(exist_ok=True)
    if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() == MODEL_SHA:
        return path
    print('Downloading official Small model (~116 MB). Video stays on this computer.', flush=True)
    partial = path.with_suffix('.part')
    for attempt in range(3):
        try:
            with urllib.request.urlopen(MODEL_URL, timeout=120) as response, partial.open('wb') as dst:
                size = 0
                while chunk := response.read(1024*1024):
                    dst.write(chunk)
                    size += len(chunk)
                    if size % (10*1024*1024) == 0:
                        print(f'Model download: {size//(1024*1024)} MiB', flush=True)
            break
        except (OSError, urllib.error.URLError):
            if attempt<2:
                print('Network interrupted; retrying model download...',flush=True)
                time.sleep(2)
            else:
                curl=shutil.which('curl.exe' if os.name=='nt' else 'curl')
                if not curl: raise
                print('Retrying with system curl (TLS verification remains enabled).',flush=True)
                subprocess.run([curl,'--fail','--location','--retry','3','--connect-timeout','30','--max-time','600','--output',str(partial),MODEL_URL],check=True)
    if hashlib.sha256(partial.read_bytes()).hexdigest() != MODEL_SHA:
        raise RuntimeError('Model checksum mismatch. Run again to redownload; incomplete model will not be loaded.')
    partial.replace(path)
    return path

def convert(args, src, model, device):
    import cv2
    import numpy as np
    import imageio_ffmpeg
    start = time.perf_counter()
    cap = cv2.VideoCapture(str(src))
    if not cap.isOpened():
        raise ValueError(f'Cannot open video: {src}')
    source_fps = cap.get(cv2.CAP_PROP_FPS)
    expected_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    if not 0 < source_fps <= 240:
        raise ValueError(f'Unsupported or missing frame rate: {source_fps}')
    step = max(1, round(source_fps/args.fps)) if args.fps else 1
    fps = source_fps/step
    frames = []
    decoded = 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        if decoded == 0:
            h,w = frame.shape[:2]
            scale = min(1,480/max(w,h))
            dw,dh = max(2,round(w*scale)),max(2,round(h*scale))
        if decoded % step == 0:
            frames.append(cv2.cvtColor(cv2.resize(frame,(dw,dh)),cv2.COLOR_BGR2RGB))
            if len(frames) > args.max_frames:
                cap.release()
                raise ValueError(f'More than {args.max_frames} inference frames. Use --fps 15 or a shorter clip. No truncated output was produced.')
        decoded += 1
    cap.release()
    if not frames:
        raise ValueError('Video has no decodable frames.')
    if expected_frames > 0 and abs(decoded-expected_frames)>1:
        raise ValueError(f'Video decode ended early or frame metadata is inconsistent: {decoded}/{expected_frames}. Repair the input before converting.')
    print(f'{src.name}: {decoded} source frames, {len(frames)} inference frames, {fps:.3f} output fps, {device}',flush=True)
    infer_start = time.perf_counter()
    depths,_ = model.infer_video_depth(np.stack(frames),fps,input_size=args.size,device=device,fp32=True)
    del frames
    infer_seconds = time.perf_counter()-infer_start
    if not np.isfinite(depths).all():
        raise RuntimeError('Non-finite depth output; no final video exported.')
    lo,hi = np.percentile(depths,[.5,99.5])
    if hi <= lo:
        raise RuntimeError('Flat depth output; check source video.')
    args.output.mkdir(parents=True,exist_ok=True)
    name = src.stem+'_depth_'+time.strftime('%Y%m%d_%H%M%S')+'_'+str(time.time_ns()%1000000)
    final = args.output/(name+'.mp4')
    silent = args.output/(name+'.silent.mp4')
    log = args.output/(name+'.ffmpeg.log')
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    # Pad odd source dimensions instead of distorting aspect ratio.
    ow,oh = w+w%2,h+h%2
    command = [ff,'-y','-v','error','-f','rawvideo','-pix_fmt','gray','-s',f'{dw}x{dh}','-r',str(fps),'-i','pipe:0',
               '-vf',f'scale={w}:{h},pad={ow}:{oh}:0:0','-an','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p',str(silent)]
    with log.open('wb') as errors:
        process = subprocess.Popen(command,stdin=subprocess.PIPE,stderr=errors)
        try:
            for depth in depths:
                gray = np.uint8(np.clip((depth-lo)/(hi-lo),0,1)*255)
                process.stdin.write(gray.tobytes())
        finally:
            process.stdin.close()
            code = process.wait()
    if code:
        raise RuntimeError(f'Encoder failed; see {log}')
    # Optional map permits silent inputs; AAC also works with source audio codecs unsupported by MP4.
    with log.open('ab') as errors:
        subprocess.run([ff,'-y','-v','error','-i',str(silent),'-i',str(src),'-map','0:v:0','-map','1:a:0?',
                        '-c:v','copy','-c:a','aac','-b:a','192k','-t',str(decoded/source_fps),'-movflags','+faststart',str(final)],check=True,stderr=errors)
        subprocess.run([ff,'-v','error','-i',str(final),'-f','null','-'],check=True,stderr=errors)
    check = cv2.VideoCapture(str(final))
    count = int(check.get(cv2.CAP_PROP_FRAME_COUNT))
    actual_fps = check.get(cv2.CAP_PROP_FPS)
    check.release()
    if abs(count-len(depths))>1 or abs(actual_fps-fps)>.05:
        raise RuntimeError('Unexpected exported frame count/rate; inspect output before use.')
    silent.unlink()
    if args.save_depth:
        np.savez_compressed(args.output/(name+'.npz'),depth=depths,fps=fps)
    # Six representative images, no full-size frames retained.
    sheet = np.zeros((320,180*6,3),np.uint8)
    for j,k in enumerate(np.linspace(0,len(depths)-1,6,dtype=int)):
        g=np.uint8(np.clip((depths[k]-lo)/(hi-lo),0,1)*255)
        thumb=cv2.cvtColor(g,cv2.COLOR_GRAY2BGR)
        ratio=min(180/dw,290/dh)
        thumb=cv2.resize(thumb,(max(1,round(dw*ratio)),max(1,round(dh*ratio))))
        sheet[30:30+thumb.shape[0],j*180:j*180+thumb.shape[1]]=thumb
        cv2.putText(sheet,f'{k/fps:.2f}s',(j*180+5,20),cv2.FONT_HERSHEY_SIMPLEX,.5,(255,255,255),1)
    # imencode + tofile supports Chinese output paths on Windows.
    cv2.imencode('.jpg',sheet)[1].tofile(str(args.output/(name+'.jpg')))
    report = dict(source=str(src),output=str(final),source_frames=decoded,source_fps=source_fps,output_frames=count,output_fps=actual_fps,
                  source_duration=decoded/source_fps,output_duration=count/actual_fps,device=device,input_size=args.size,depth_map_size=[dw,dh],
                  inference_seconds=infer_seconds,total_processing_seconds=time.perf_counter()-start,model_sha256=MODEL_SHA,
                  note='Relative depth, not metric distance. Output upscaled from estimated depth. Audio preserved in AAC. VFR sources are treated as average-FPS CFR.',
                  normalization='clip-wide 0.5 to 99.5 percentile',decode_check='passed')
    (args.output/(name+'.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf-8')
    print(f'COMPLETE: {final}\nInference {infer_seconds:.1f}s; processing {report["total_processing_seconds"]:.1f}s',flush=True)

def main():
    parser=argparse.ArgumentParser(description='Offline Video Depth Anything Small. First setup requires Internet; no video upload/API key.')
    parser.add_argument('videos',nargs='*',type=Path)
    parser.add_argument('--output',type=Path,default=BASE/'results')
    parser.add_argument('--fps',type=float,default=15,help='Desired maximum approximate FPS; 0 keeps original FPS. Default 15.')
    parser.add_argument('--size',type=int,choices=[196,252,392,518],default=252)
    parser.add_argument('--device',choices=['cpu','cuda'],default='cpu')
    parser.add_argument('--threads',type=int,default=min(8,os.cpu_count() or 4))
    parser.add_argument('--max-frames',type=int,default=1800)
    parser.add_argument('--save-depth',action='store_true')
    parser.add_argument('--download-only',action='store_true')
    args=parser.parse_args()
    if args.fps<0 or args.threads<1 or args.max_frames<1:
        parser.error('fps must be >=0; threads and max-frames must be >=1')
    if not args.download_only and not args.videos:
        parser.error('Provide a video path or drag it onto Start-Fast.bat.')
    for src in args.videos:
        if not src.is_file(): parser.error(f'File not found: {src}')
    checkpoint=weights()
    if args.download_only: return
    import torch
    torch.set_num_threads(args.threads)
    if args.device=='cuda' and not torch.cuda.is_available():
        raise RuntimeError('CUDA unavailable. Default package uses CPU; use --device cpu.')
    vendor=BASE/'vendor/Video-Depth-Anything'
    sys.path.insert(0,str(vendor))
    namespace=types.ModuleType('utils');namespace.__path__=[str(vendor/'utils')];sys.modules['utils']=namespace
    from video_depth_anything.video_depth import VideoDepthAnything
    model=VideoDepthAnything(encoder='vits',features=64,out_channels=[48,96,192,384],metric=False)
    model.load_state_dict(torch.load(checkpoint,map_location='cpu',weights_only=True),strict=True)
    model.to(args.device).eval()
    for src in args.videos: convert(args,src.resolve(),model,args.device)

if __name__=='__main__':
    try: main()
    except KeyboardInterrupt:
        print('\nCancelled. Original video unchanged.',file=sys.stderr);sys.exit(130)
    except Exception:
        import traceback
        traceback.print_exc();sys.exit(1)
