#!/bin/bash
# 01_download.sh - 下载视频+音频+字幕
# 用法: bash 01_download.sh <URL> <任务ID>
# 输出: VIDEO_PATH, AUDIO_PATH, SUBTITLE_PATH (用空格分隔)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
source "$SKILL_DIR/config.env"

INPUT="$1"
TASK_ID="${2:-$(date +%s)}"

if [ -z "$INPUT" ]; then
    echo "用法: $0 <URL> <任务ID>" >&2
    exit 1
fi

# 初始化工作目录
WORK_DIR=$(bash "$SCRIPT_DIR/00_setup.sh" "$TASK_ID")

echo "[下载] 开始下载: $INPUT"
echo "[下载] 工作目录: $WORK_DIR"

# === 1. 检测分P视频 ===
echo "[下载] 检测分P信息..."
PARTS=$("$VENV_PYTHON" -m yt_dlp --list-sections "$INPUT" 2>/dev/null | grep -E "^\s*\d+:" || echo "")

if [ -n "$PARTS" ]; then
    echo "[下载] 检测到多P视频:"
    echo "$PARTS"
    echo "[下载] 默认处理第一个P"
fi

# === 2. 下载字幕（CC字幕优先）===
echo "[下载] 尝试获取CC字幕..."
SUBTITLE_PATH=""
SUB_DOWNLOADED=false

if "$VENV_PYTHON" -m yt_dlp \
    --write-subs \
    --sub-langs "zh-Hans,zh-CN,zh,ai-zh" \
    --skip-download \
    -o "$WORK_DIR/subs.%(ext)s" \
    "$INPUT" 2>/dev/null; then
    
    # 找到下载的字幕文件
    SUB_PATH=$(find "$WORK_DIR" -name "subs.*" -type f 2>/dev/null | head -1)
    if [ -n "$SUB_PATH" ]; then
        # 转换为SRT格式
        SUB_EXT="${SUB_PATH##*.}"
        if [ "$SUB_EXT" = "vtt" ] || [ "$SUB_EXT" = "ass" ] || [ "$SUB_EXT" = "srt" ]; then
            "$FFMPEG_BIN" -y -i "$SUB_PATH" "$WORK_DIR/subtitles.srt" 2>/dev/null
            if [ -f "$WORK_DIR/subtitles.srt" ]; then
                rm -f "$SUB_PATH"
                SUBTITLE_PATH="$WORK_DIR/subtitles.srt"
                SUB_DOWNLOADED=true
            fi
        fi
        if [ "$SUB_DOWNLOADED" = false ] && [ -f "$SUB_PATH" ]; then
            SUBTITLE_PATH="$SUB_PATH"
            SUB_DOWNLOADED=true
        fi
    fi
fi

if [ "$SUB_DOWNLOADED" = true ]; then
    echo "[下载] 字幕下载成功: $SUBTITLE_PATH"
else
    echo "[下载] 无CC字幕可用，将使用Whisper转写"
fi

# === 3. 下载视频 ===
echo "[下载] 开始下载视频..."
"$VENV_PYTHON" -m yt_dlp \
    -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" \
    --no-playlist \
    -o "$WORK_DIR/video.%(ext)s" \
    "$INPUT" 2>&1 | tail -3

VIDEO_PATH=$(find "$WORK_DIR" -name "video.*" -type f 2>/dev/null | head -1)

if [ -z "$VIDEO_PATH" ]; then
    echo "[下载] 错误: 视频下载失败" >&2
    exit 1
fi
echo "[下载] 视频下载完成: $VIDEO_PATH"

# === 4. 下载音频 ===
echo "[下载] 开始下载音频..."
AUDIO_PATH=""

if "$VENV_PYTHON" -m yt_dlp \
    -x --audio-format wav --audio-quality 0 \
    -o "$WORK_DIR/audio.%(ext)s" \
    --no-playlist "$INPUT" 2>/dev/null; then
    
    AUDIO_PATH=$(find "$WORK_DIR" -name "audio.*" -type f 2>/dev/null | head -1)
    echo "[下载] 音频下载完成: $AUDIO_PATH"
else
    # 如果直接下载失败，从视频提取音频
    echo "[下载] 从视频提取音频..."
    ffmpeg -y -i "$VIDEO_PATH" -vn -acodec pcm_s16le -ar 16000 -ac 1 "$WORK_DIR/audio.wav" 2>/dev/null
    AUDIO_PATH="$WORK_DIR/audio.wav"
    echo "[下载] 音频提取完成: $AUDIO_PATH"
fi

# === 5. 更新任务信息 ===
cat > "$WORK_DIR/info.txt" <<EOF
WORK_DIR=$WORK_DIR
TASK_ID=$TASK_ID
VIDEO_PATH=$VIDEO_PATH
AUDIO_PATH=$AUDIO_PATH
SUBTITLE_PATH=$SUBTITLE_PATH
INPUT=$INPUT
CREATED=$(date +%Y-%m-%d_%H:%M:%S)
EOF

# === 6. 输出结果 ===
echo ""
echo "[下载] === 下载完成 ==="
echo "VIDEO_PATH=$VIDEO_PATH"
echo "AUDIO_PATH=$AUDIO_PATH"
echo "SUBTITLE_PATH=$SUBTITLE_PATH"
echo ""

# 输出三行，每行一个路径
echo "$VIDEO_PATH"
echo "$AUDIO_PATH"
echo "$SUBTITLE_PATH"
