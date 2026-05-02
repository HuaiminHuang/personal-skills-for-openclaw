#!/bin/bash
# mineru-clean.sh — Clean MinerU intermediate files after parse
# Usage: mineru-clean.sh <dir> [options]
set -euo pipefail

VERSION="1.0.0"

# ── Defaults ──
DRY_RUN=false
SUMMARY=false
ONLY_JSON=false
ONLY_PDF=false
NO_JSON=false
NO_PDF=false

# ── Colors ──
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

# ── Help ──
show_help() {
    cat <<EOF
${CYAN}mineru-clean.sh v${VERSION}${NC} — Clean MinerU intermediate files

${YELLOW}Usage:${NC}
    mineru-clean.sh <dir> [options]

${YELLOW}Arguments:${NC}
    <dir>                     MinerU output directory to clean

${YELLOW}Options:${NC}
    --dry-run                 Preview files that would be deleted
    --summary                 Show file size breakdown and exit (no delete)
    --only-json               Only clean JSON intermediate files
    --only-pdf                Only clean debug PDF files (layout/span/origin)
    --no-json                 Skip JSON files, clean everything else
    --no-pdf                  Skip debug PDF files, clean everything else
    -h, --help                Show this help

${YELLOW}Examples:${NC}
    mineru-clean.sh ./output/paper_name/
    mineru-clean.sh ./output/paper_name/ --dry-run
    mineru-clean.sh ./output/paper_name/ --summary
    mineru-clean.sh ./output/paper_name/ --only-json
    mineru-clean.sh ./output/paper_name/ --no-pdf
EOF
    exit 0
}

# ── Parse args ──
TARGET_DIR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)       DRY_RUN=true; shift ;;
        --summary)       SUMMARY=true; shift ;;
        --only-json)     ONLY_JSON=true; shift ;;
        --only-pdf)      ONLY_PDF=true; shift ;;
        --no-json)       NO_JSON=true; shift ;;
        --no-pdf)        NO_PDF=true; shift ;;
        -h|--help)       show_help ;;
        *)               TARGET_DIR="$1"; shift ;;
    esac
done

# ── Validate ──
if [[ -z "$TARGET_DIR" ]]; then
    echo -e "${RED}Error: <dir> is required${NC}"
    echo "Usage: mineru-clean.sh <dir> [options]"
    exit 1
fi

TARGET_DIR=$(realpath "$TARGET_DIR" 2>/dev/null || echo "$TARGET_DIR")
if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "${RED}Error: directory not found: $TARGET_DIR${NC}"
    exit 1
fi

# ── Resolve clean targets ──
# Build find patterns based on filters
JSON_PATTERNS=()
PDF_PATTERNS=()

if $ONLY_JSON; then
    JSON_PATTERNS=('-name' '*_middle.json' '-o' '-name' '*_model.json' '-o' '-name' '*_content_list.json' '-o' '-name' '*_content_list_v2.json')
elif $ONLY_PDF; then
    PDF_PATTERNS=('-name' '*_layout.pdf' '-o' '-name' '*_span.pdf' '-o' '-name' '*_origin.pdf')
else
    if ! $NO_JSON; then
        JSON_PATTERNS=('-name' '*_middle.json' '-o' '-name' '*_model.json' '-o' '-name' '*_content_list.json' '-o' '-name' '*_content_list_v2.json')
    fi
    if ! $NO_PDF; then
        PDF_PATTERNS=('-name' '*_layout.pdf' '-o' '-name' '*_span.pdf' '-o' '-name' '*_origin.pdf')
    fi
fi

# Combine all patterns
ALL_PATTERNS=()
if [[ ${#JSON_PATTERNS[@]} -gt 0 ]]; then
    ALL_PATTERNS+=("${JSON_PATTERNS[@]}")
fi
if [[ ${#PDF_PATTERNS[@]} -gt 0 ]]; then
    if [[ ${#ALL_PATTERNS[@]} -gt 0 ]]; then
        ALL_PATTERNS+=('-o')
    fi
    ALL_PATTERNS+=("${PDF_PATTERNS[@]}")
fi

# ── --summary mode ──
if $SUMMARY; then
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${CYAN} mineru-clean.sh — File Summary${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  Directory: ${TARGET_DIR}"
    echo -e "${CYAN}────────────────────────────────────────────────────${NC}"

    TOTAL=0
    while IFS='|' read -r size name; do
        printf "  %-8s  %s\n" "$size" "$(basename "$name")"
        case "$size" in
            *K) TOTAL=$((TOTAL + ${size%K})) ;;
            *M) TOTAL=$((TOTAL + ${size%M} * 1024)) ;;
        esac
    done < <(find "$TARGET_DIR" -maxdepth 3 -type f \( \
        -name '*_middle.json' -o \
        -name '*_model.json' -o \
        -name '*_content_list.json' -o \
        -name '*_content_list_v2.json' -o \
        -name '*_layout.pdf' -o \
        -name '*_span.pdf' -o \
        -name '*_origin.pdf' \
    \) -exec du -h {} \; 2>/dev/null | sort -rh | sed 's/\t/|/')

    if [[ $TOTAL -ge 1024 ]]; then
        TOTAL_DISPLAY="$(echo "scale=1; $TOTAL / 1024" | bc)M"
    else
        TOTAL_DISPLAY="${TOTAL}K"
    fi
    echo -e "${CYAN}────────────────────────────────────────────────────${NC}"
    echo -e "  ${YELLOW}Total cleanable:${NC} $TOTAL_DISPLAY"
    exit 0
fi

# ── Find directories to clean ──
# Detect if TARGET_DIR is a method-level dir (has .md files) or a paper-level dir (has method subdirs)
CLEAN_DIRS=()
if ls "$TARGET_DIR"/*.md &>/dev/null 2>&1; then
    # TARGET_DIR is method-level (auto/, txt/, etc.)
    CLEAN_DIRS=("$TARGET_DIR")
elif ls "$TARGET_DIR"/*/ &>/dev/null 2>&1; then
    # TARGET_DIR has subdirectories — find method dirs
    for sub in "$TARGET_DIR"/*/; do
        if ls "$sub"/*.md &>/dev/null 2>&1; then
            CLEAN_DIRS+=("$sub")
        fi
    done
fi

if [[ ${#CLEAN_DIRS[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No MinerU output found in: $TARGET_DIR${NC}"
    echo -e "${YELLOW}Expected *.md files in target or its subdirectories.${NC}"
    exit 0
fi

# ── Execute clean ──
TOTAL_CLEANED=0
for dir in "${CLEAN_DIRS[@]}"; do
    dir_name=$(basename "$dir")
    CLEANED=0

    if $DRY_RUN; then
        echo -e "${CYAN}[${dir_name}]${NC} Would clean:"
    fi

    while IFS= read -r -d '' f; do
        if $DRY_RUN; then
            echo -e "  ${YELLOW}$(basename "$f")${NC}"
        else
            rm -f "$f"
        fi
        CLEANED=$((CLEANED + 1))
    done < <(if [[ ${#ALL_PATTERNS[@]} -gt 0 ]]; then
        find "$dir" -maxdepth 1 -type f \( "${ALL_PATTERNS[@]}" \) -print0 2>/dev/null
    else
        find "$dir" -maxdepth 1 -type f -print0 2>/dev/null
    fi)

    if [[ $CLEANED -gt 0 ]] && ! $DRY_RUN; then
        echo -e "${YELLOW}[${dir_name}] Cleaned ${CLEANED} file(s)${NC}"
    elif [[ $CLEANED -gt 0 ]] && $DRY_RUN; then
        echo -e "${YELLOW}  → ${CLEANED} file(s) would be deleted${NC}"
    fi

    TOTAL_CLEANED=$((TOTAL_CLEANED + CLEANED))
done

if [[ $TOTAL_CLEANED -eq 0 ]]; then
    echo -e "${GREEN}Nothing to clean.${NC}"
fi

exit 0
