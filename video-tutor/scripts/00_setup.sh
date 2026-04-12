#!/bin/bash
# 00_setup.sh - 初始化工作目录和清理旧缓存
# 用法: bash 00_setup.sh [任务标识符]
# 输出: WORK_DIR 到 stdout（仅一行）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
source "$SKILL_DIR/config.env"

# 任务标识符（使用纯 ASCII，避免中文问题）
TASK_ID="${1:-$(date +%s)}"

# 清理为合法目录名（使用 venv Python）
SAFE_ID=$("$VENV_PYTHON" -c "import re; print(re.sub(r'[^a-zA-Z0-9_\-]', '_', '''$TASK_ID'''))" | cut -c1-80)

# 创建本次任务的工作目录
WORK_DIR="$CACHE_DIR/$SAFE_ID"
mkdir -p "$WORK_DIR"
mkdir -p "$WORK_DIR/images"

# 写入任务信息
cat > "$WORK_DIR/info.txt" <<EOF
WORK_DIR=$WORK_DIR
TASK_ID=$TASK_ID
SAFE_ID=$SAFE_ID
CREATED=$(date +%Y-%m-%d_%H:%M:%S)
EOF

# 只输出一行：WORK_DIR
echo "$WORK_DIR"
