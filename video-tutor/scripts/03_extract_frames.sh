#!/bin/bash
# 03_extract_frames.sh - 按时间戳批量提取视频帧
# 用法: bash 03_extract_frames.sh <视频路径> <时间戳JSON数组> [输出目录]
# 时间戳格式: '["00:02:30", "00:05:10", ...]'
# 输出: FRAME_PATHS (空格分隔)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
source "$SKILL_DIR/config.env"

VIDEO_PATH="$1"
TIMESTAMPS_JSON="$2"
OUTPUT_DIR="${3:-$(dirname "$VIDEO_PATH")/images}"

if [ -z "$VIDEO_PATH" ] || [ -z "$TIMESTAMPS_JSON" ]; then
    echo "用法: $0 <视频路径> <时间戳JSON数组> [输出目录]" >&2
    echo "示例: $0 video.mp4 '[\"00:02:30\", \"00:05:10\"]'" >&2
    exit 1
fi

if [ ! -f "$VIDEO_PATH" ]; then
    echo "[截帧] 错误: 视频文件不存在: $VIDEO_PATH" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "[截帧] 开始提取..."
echo "[截帧] 视频: $VIDEO_PATH"
echo "[截帧] 时间戳: $TIMESTAMPS_JSON"

# 使用Python解析JSON并提取帧
"$VENV_PYTHON" << 'PYEOF'
import json
import subprocess
import sys
import os
import re

video_path = sys.argv[1]
timestamps_json = sys.argv[2]
output_dir = sys.argv[3] if len(sys.argv) > 3 else os.path.dirname(video_path) + "/images"

timestamps = json.loads(timestamps_json)

os.makedirs(output_dir, exist_ok=True)

def parse_timestamp(ts):
    """解析时间戳字符串为秒"""
    # 支持格式: "00:02:30" 或 "2:30" 或 "30"
    parts = ts.split(":")
    if len(parts) == 3:
        return int(parts[0]) * 3600 + int(parts[1]) * 60 + float(parts[2])
    elif len(parts) == 2:
        return int(parts[0]) * 60 + float(parts[1])
    else:
        return float(parts[0])

frame_paths = []
for i, ts in enumerate(timestamps, 1):
    seconds = parse_timestamp(ts)
    
    # 格式化输出文件名: frame_{nn}_{hh}h{mm}m{ss}s.jpg
    hh = int(seconds // 3600)
    mm = int((seconds % 3600) // 60)
    ss = int(seconds % 60)
    frame_name = f"frame_{i:02d}_{hh:02d}h{mm:02d}m{ss:02d}s.jpg"
    output_path = os.path.join(output_dir, frame_name)
    
    # 使用ffmpeg提取帧
    cmd = [
        "ffmpeg", "-y",
        "-ss", str(seconds),
        "-i", video_path,
        "-vframes", "1",
        "-q:v", "2",
        output_path
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if os.path.exists(output_path):
        print(f"[截帧] {ts} -> {frame_name}")
        frame_paths.append(output_path)
    else:
        print(f"[截帧] 失败: {ts}")

print(f"[截帧] 共提取 {len(frame_paths)} 帧")
print("FRAME_PATHS:" + " ".join(frame_paths))
PYEOF

# 输出帧路径供后续使用
FRAME_PATHS=$("$VENV_PYTHON" -c "
import json
import os
timestamps = json.loads('$TIMESTAMPS_JSON')
output_dir = '$OUTPUT_DIR'
paths = []
for i, ts in enumerate(timestamps, 1):
    parts = ts.split(':')
    if len(parts) == 3:
        seconds = int(parts[0])*3600 + int(parts[1])*60 + float(parts[2])
    elif len(parts) == 2:
        seconds = int(parts[0])*60 + float(parts[1])
    else:
        seconds = float(parts[0])
    hh, mm, ss = int(seconds//3600), int((seconds%3600)//60), int(seconds%60)
    frame_name = f'frame_{i:02d}_{hh:02d}h{mm:02d}m{ss:02d}s.jpg'
    path = os.path.join(output_dir, frame_name)
    if os.path.exists(path):
        paths.append(path)
print(' '.join(paths))
")

echo "$FRAME_PATHS"
