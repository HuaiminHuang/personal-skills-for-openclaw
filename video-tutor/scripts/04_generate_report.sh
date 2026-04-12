#!/bin/bash
# 04_generate_report.sh - 生成视频分析报告
# 用法: bash 04_generate_report.sh <工作目录>
# 输出: REPORT_PATH

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
source "$SKILL_DIR/config.env"

WORK_DIR="$1"

if [ -z "$WORK_DIR" ]; then
    echo "用法: $0 <工作目录>" >&2
    exit 1
fi

if [ ! -f "$WORK_DIR/info.txt" ]; then
    echo "[报告] 错误: info.txt 不存在" >&2
    exit 1
fi

# 读取info.txt获取路径
source "$WORK_DIR/info.txt"

# 生成报告文件名
TASK_BASE=$(basename "$WORK_DIR")
REPORT_PATH="$WORK_DIR/${TASK_BASE}_summary.md"

echo "[报告] 开始生成报告..."

# 读取转写文本（如果存在）
TRANSCRIPT_CONTENT=""
if [ -f "$TRANSCRIPT_PATH" ]; then
    TRANSCRIPT_CONTENT=$(cat "$TRANSCRIPT_PATH")
fi

# 生成报告
cat > "$REPORT_PATH" << 'EOF'
# 视频分析报告

## 视频信息

| 项目 | 内容 |
|------|------|
| 任务ID | TASK_ID_PLACEHOLDER |
| 视频路径 | VIDEO_PATH_PLACEHOLDER |
| 音频路径 | AUDIO_PATH_PLACEHOLDER |
| 转写路径 | TRANSCRIPT_PATH_PLACEHOLDER |
| 创建时间 | CREATED_PLACEHOLDER |

## 视频内容摘要

（由AI根据转写内容生成）

EOF

# 替换占位符
sed -i "s/TASK_ID_PLACEHOLDER/$TASK_ID/g" "$REPORT_PATH"
sed -i "s|VIDEO_PATH_PLACEHOLDER|$VIDEO_PATH|g" "$REPORT_PATH"
sed -i "s|AUDIO_PATH_PLACEHOLDER|$AUDIO_PATH|g" "$REPORT_PATH"
sed -i "s|TRANSCRIPT_PATH_PLACEHOLDER|$TRANSCRIPT_PATH|g" "$REPORT_PATH"
sed -i "s|CREATED_PLACEHOLDER|$CREATED|g" "$REPORT_PATH"

# 如果有截图，列出截图
if [ -d "$WORK_DIR/images" ]; then
    FRAME_COUNT=$(find "$WORK_DIR/images" -name "*.jpg" | wc -l)
    echo "" >> "$REPORT_PATH"
    echo "## 关键帧截图 ($FRAME_COUNT 张)" >> "$REPORT_PATH"
    echo "" >> "$REPORT_PATH"
    for img in "$WORK_DIR/images"/*.jpg; do
        if [ -f "$img" ]; then
            IMG_NAME=$(basename "$img")
            echo "### $IMG_NAME" >> "$REPORT_PATH"
            echo "![$IMG_NAME](images/$IMG_NAME)" >> "$REPORT_PATH"
            echo "" >> "$REPORT_PATH"
        fi
    done
fi

echo "[报告] 完成: $REPORT_PATH"
echo "$REPORT_PATH"
