#!/bin/bash
# mineru-parse.sh — Parse PDFs with MinerU (pipeline backend)
# Usage: mineru-parse.sh <input> [options]
set -euo pipefail

VERSION="2.0.0"

# ── Defaults ──
OUTPUT_DIR=""
LANG="en"
METHOD="auto"
BACKEND="pipeline"
FORMULA=true
TABLE=true
START=0
END=""
MODELS_DIR=""
DRY_RUN=false
SUMMARY=true

# ── Colors ──
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

# ── Help ──
show_help() {
    cat <<EOF
${CYAN}mineru-parse.sh v${VERSION}${NC} — PDF parsing with MinerU pipeline backend

${YELLOW}Usage:${NC}
    mineru-parse.sh <input> [options]

${YELLOW}Arguments:${NC}
    <input>                   PDF file or directory containing PDFs

${YELLOW}Options:${NC}
    -o, --output <dir>        Output directory (default: ./<input_stem>_output)
    -l, --lang <lang>         OCR language (default: en)
                              common: en, ch, japan, korean, latin, arabic
    -m, --method <mode>       Parse method (default: auto)
                              auto | txt | ocr
    -b, --backend <backend>   Backend (default: pipeline)
                              pipeline | hybrid-auto-engine
    --no-formula              Disable formula recognition
    --no-table                Disable table recognition
    -s, --start <page>        Start page (0-based)
    -e, --end <page>          End page
    --models-dir <path>       Custom models directory (offline)
    --no-summary              Suppress parse summary
    --dry-run                 Print command and exit
    -h, --help                Show this help

${YELLOW}Examples:${NC}
    mineru-parse.sh paper.pdf
    mineru-parse.sh ~/papers/ -o ./parsed -l en
    mineru-parse.sh paper.pdf --no-formula --no-table
    mineru-parse.sh paper.pdf -b hybrid-auto-engine
    mineru-parse.sh paper.pdf --dry-run

${YELLOW}Post-Processing:${NC}
    Clean intermediate files after parse:
    mineru-clean.sh <output_dir>/<paper_name>/

${YELLOW}Model Management:${NC}
    Models auto-download on first run (~/.cache/mineru/).
    For offline use: download models manually, then use --models-dir.
    Set MINERU_MODEL_SOURCE=modelscope for China region.
EOF
    exit 0
}

# ── Parse args ──
INPUT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)     OUTPUT_DIR="$2"; shift 2 ;;
        -l|--lang)       LANG="$2"; shift 2 ;;
        -m|--method)     METHOD="$2"; shift 2 ;;
        -b|--backend)    BACKEND="$2"; shift 2 ;;
        --no-formula)    FORMULA=false; shift ;;
        --no-table)      TABLE=false; shift ;;
        -s|--start)      START="$2"; shift 2 ;;
        -e|--end)        END="$2"; shift 2 ;;
        --models-dir)    MODELS_DIR="$2"; shift 2 ;;
        --no-summary)    SUMMARY=false; shift ;;
        --dry-run)       DRY_RUN=true; shift ;;
        -h|--help)       show_help ;;
        -v|--version)    echo "mineru-parse.sh v$VERSION"; exit 0 ;;
        *)               INPUT="$1"; shift ;;
    esac
done

if [[ -z "$INPUT" ]]; then
    echo -e "${RED}Error: <input> is required${NC}"
    echo "Usage: mineru-parse.sh <input> [options]"
    exit 1
fi

# ── Resolve input ──
INPUT_PATH=$(realpath "$INPUT")
INPUT_DIR=$(dirname "$INPUT_PATH")
INPUT_STEM=$(basename "$INPUT_PATH" | sed 's/\.[^.]*$//')
OUTPUT_DIR="${OUTPUT_DIR:-${INPUT_DIR}/${INPUT_STEM}_output}"

# ── Build mineru args ──
MINERU_ARGS=(
    -p "$INPUT_PATH"
    -o "$OUTPUT_DIR"
    -b "$BACKEND"
    -m "$METHOD"
    -l "$LANG"
    -f "$FORMULA"
    -t "$TABLE"
)

if [[ -n "$END" ]]; then
    MINERU_ARGS+=(-s "$START" -e "$END")
fi

# ── Export config ──
if [[ -n "$MODELS_DIR" ]]; then
    CONFIG_FILE="$HOME/mineru.json"
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}Config: $CONFIG_FILE already exists, backing up to ${CONFIG_FILE}.bak${NC}"
        cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    fi
    cat > "$CONFIG_FILE" <<JSONEOF
{
    "models-dir": {
        "pipeline": "$MODELS_DIR"
    },
    "config_version": "1.3.1"
}
JSONEOF
    echo -e "${YELLOW}Config written: $CONFIG_FILE${NC}"
fi

# ── Dry run (check before requiring mineru) ──
if $DRY_RUN; then
    echo -e "${CYAN}Dry run — would execute:${NC}"
    echo -e "  ${GREEN}mineru ${MINERU_ARGS[*]}${NC}"
    exit 0
fi

# ── Require mineru ──
if ! command -v mineru &>/dev/null; then
    echo -e "${RED}Error: 'mineru' command not found${NC}"
    echo ""
    echo "Activate existing environment:"
    echo "  source ~/.openclaw/venvs/mineru-pdf-parser/bin/activate"
    echo ""
    echo "Or install fresh:"
    echo "  uv venv ~/.openclaw/venvs/mineru-pdf-parser --python 3.11"
    echo "  uv pip install --python ~/.openclaw/venvs/mineru-pdf-parser/bin/python 'mineru[pipeline]'"
    exit 1
fi

# ── Execute ──
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${CYAN} MinerU PDF Parser v${VERSION}${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "  Input:    ${INPUT_PATH}"
echo -e "  Output:   ${OUTPUT_DIR}"
echo -e "  Backend:  ${BACKEND}"
echo -e "  Lang:     ${LANG}"
echo -e "  Method:   ${METHOD}"
echo -e "  Formula:  ${FORMULA}"
echo -e "  Table:    ${TABLE}"
[[ -n "$END" ]] && echo -e "  Pages:    ${START}-${END}"
[[ -n "$MODELS_DIR" ]] && echo -e "  Models:   ${MODELS_DIR}"
echo -e "${CYAN}────────────────────────────────────────────────────${NC}"

START_TIME=$(date +%s)
set +e
mineru "${MINERU_ARGS[@]}"
EXIT_CODE=$?
set -e
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

if [[ $EXIT_CODE -eq 0 ]]; then
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN} ✓ Parse complete${NC}"
    echo -e "  Duration: ${DURATION}s"
    echo -e "  Output:   ${OUTPUT_DIR}"
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"

    if $SUMMARY; then
        echo ""
        echo -e "${YELLOW}Output structure:${NC}"
        find "$OUTPUT_DIR" -maxdepth 2 -type f | head -20 | sed 's/^/  /'
        MD_COUNT=$(find "$OUTPUT_DIR" -name "*.md" | wc -l)
        JSON_COUNT=$(find "$OUTPUT_DIR" -name "*.json" | wc -l)
        echo ""
        echo -e "  ${CYAN}Markdown files:${NC} $MD_COUNT"
        echo -e "  ${CYAN}JSON files:${NC}     $JSON_COUNT"
    fi
else
    echo -e "${RED}Error: mineru exited with code $EXIT_CODE${NC}"
fi

exit $EXIT_CODE
