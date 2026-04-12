#!/bin/bash
# 02_transcribe.sh - 音频转写
# 用法: bash 02_transcribe.sh <音频路径> [工作目录]
# 输出: TRANSCRIPT_PATH

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
source "$SKILL_DIR/config.env"

AUDIO_PATH="$1"
WORK_DIR="${2:-$(dirname "$AUDIO_PATH")}"

if [ -z "$AUDIO_PATH" ]; then
    echo "用法: $0 <音频路径> [工作目录]" >&2
    exit 1
fi

if [ ! -f "$AUDIO_PATH" ]; then
    echo "[转写] 错误: 音频文件不存在: $AUDIO_PATH" >&2
    exit 1
fi

TRANSCRIPT_PATH="$WORK_DIR/transcript.txt"
SRT_PATH="$WORK_DIR/transcript.srt"

echo "[转写] 开始转写: $AUDIO_PATH"

# 确定模型路径
if [ -n "$WHISPER_MODEL_PATH" ] && [ -d "$WHISPER_MODEL_PATH" ]; then
    MODEL_PATH="$WHISPER_MODEL_PATH"
    echo "[转写] 使用本地模型: $MODEL_PATH"
else
    # 使用模型名称，faster-whisper 会自动从缓存加载
    MODEL_PATH="$WHISPER_MODEL"
    echo "[转写] 使用模型: $MODEL_PATH (将自动从缓存加载)"
fi

# 使用 faster-whisper 进行转写
"$VENV_PYTHON" -c "
import faster_whisper
import os

audio_path = '$AUDIO_PATH'
output_txt = '$TRANSCRIPT_PATH'
output_srt = '$SRT_PATH'
model_name = '$WHISPER_MODEL'

print(f'[转写] 加载模型: {model_name}...')
model = faster_whisper.WhisperModel(model_name, device='auto')

print(f'[转写] 开始转写...')
segments, info = model.transcribe(
    audio_path,
    language='zh',
    word_timestamps=True,
)

print(f'[转写] 检测语言: {info.language}, 置信度: {info.language_probability:.2f}')

# 写入TXT（带时间戳）
with open(output_txt, 'w', encoding='utf-8') as f:
    for segment in segments:
        start = segment.start
        end = segment.end
        text = segment.text.strip()
        hours = int(start // 3600)
        mins = int((start % 3600) // 60)
        secs = int(start % 60)
        f.write(f'[{hours:02d}:{mins:02d}:{secs:02d}] {text}\n')

# 重新获取segments用于SRT
segments, _ = model.transcribe(audio_path, language='zh')

# 写入SRT格式
def format_srt_time(seconds):
    hours = int(seconds // 3600)
    mins = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int((seconds % 1) * 1000)
    return f'{hours:02d}:{mins:02d}:{secs:02d},{millis:03d}'

with open(output_srt, 'w', encoding='utf-8') as f:
    for i, segment in enumerate(segments, 1):
        start = segment.start
        end = segment.end
        text = segment.text.strip()
        f.write(f'{i}\n')
        f.write(f'{format_srt_time(start)} --> {format_srt_time(end)}\n')
        f.write(f'{text}\n\n')

print(f'[转写] 完成!')
print(f'[转写] TXT: {output_txt}')
print(f'[转写] SRT: {output_srt}')
"

if [ ! -f "$TRANSCRIPT_PATH" ]; then
    echo "[转写] 错误: 转写失败" >&2
    exit 1
fi

# 更新任务信息
if [ -f "$WORK_DIR/info.txt" ]; then
    echo "TRANSCRIPT_PATH=$TRANSCRIPT_PATH" >> "$WORK_DIR/info.txt"
    echo "SRT_PATH=$SRT_PATH" >> "$WORK_DIR/info.txt"
fi

echo "[转写] 完成: $TRANSCRIPT_PATH"
echo "$TRANSCRIPT_PATH"
