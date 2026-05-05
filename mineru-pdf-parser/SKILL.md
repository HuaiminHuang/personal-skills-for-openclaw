---
name: mineru-pdf-parser
description: Use when parsing PDFs, academic papers, or scanned documents for text extraction, OCR, formula/table recognition, or converting to structured Markdown for LLM ingestion. Also covers batch PDF processing and offline GPU-based document parsing.
---

# MinerU PDF Parser

## Overview

Two bash scripts around `mineru` CLI for local PDF parsing and post-parse cleanup. Pipeline backend runs fully offline on GPU — no API calls, no cloud.

## When to Use

- Converting academic papers with formulas, tables, figures to Markdown
- Batch-processing directories of PDFs
- OCR on scanned documents (109 languages)
- Extracting structured text without internet access
- Preparing document corpora for RAG pipelines

## Quick Reference

```bash
# Parse single paper
mineru-parse.sh paper.pdf

# Parse + clean (recommended for LLM consumption)
mineru-parse.sh paper.pdf && mineru-clean.sh ./paper_output/paper_name/

# Batch parse
mineru-parse.sh ~/papers/ -o ./parsed -l en

# Chinese OCR
mineru-parse.sh paper.pdf -l ch -m ocr

# Preview clean without deleting
mineru-clean.sh ./output/paper_name/ --dry-run

# Check what can be cleaned
mineru-clean.sh ./output/paper_name/ --summary

# Selective clean (JSON only / PDF only)
mineru-clean.sh ./output/paper_name/ --only-pdf
mineru-clean.sh ./output/paper_name/ --no-json
```

## Scripts

Script: `scripts/mineru-parse.sh` — parse PDFs via `mineru`.
Script: `scripts/mineru-clean.sh` — clean intermediate files post-parse.

Requires `mineru` in PATH (`pip install 'mineru[pipeline]'` in openclaw venv).

### mineru-parse.sh Options

| Short | Long | Description | Default |
|-------|------|-------------|---------|
| `-o` | `--output` | Output directory | `./<name>_output` |
| `-l` | `--lang` | OCR language (en, ch, japan, etc.) | `en` |
| `-m` | `--method` | Parse method: auto/txt/ocr | `auto` |
| `-b` | `--backend` | Backend: pipeline/hybrid-auto-engine | `pipeline` |
| | `--no-formula` | Disable formula recognition | enabled |
| | `--no-table` | Disable table recognition | enabled |
| `-s` | `--start` | Start page (0-based) | `0` |
| `-e` | `--end` | End page | all |
| | `--models-dir` | Custom models directory | auto-download |
| | `--no-summary` | Suppress output summary | shown |
| | `--dry-run` | Preview mineru command | false |

### mineru-clean.sh Options

| Option | Description | Default |
|--------|-------------|---------|
| `--dry-run` | Preview files to delete | false |
| `--summary` | Show file sizes and exit | false |
| `--only-json` | Clean only JSON intermediates | false |
| `--only-pdf` | Clean only debug PDFs | false |
| `--no-json` | Skip JSON, clean other files | false |
| `--no-pdf` | Skip debug PDFs, clean other files | false |

### Default clean behavior

Deletes `*_middle.json` `*_model.json` `*_content_list*.json` `*_layout.pdf` `*_span.pdf` `*_origin.pdf`.
Keeps `*.md` + `images/`.

### Directory auto-detection

```
If <dir> has .md files directly       → clean in-place (method-level dir)
If <dir> has auto/ txt/ ocr/ etc.     → clean each subdirectory
```

## Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `HF_ENDPOINT` | HuggingFace mirror (China) | `https://hf-mirror.com` |
| `MINERU_MODEL_SOURCE` | Model download source (China) | `modelscope` |
| `MINERU_DEVICE_MODE` | Override device | `cuda` / `cpu` |
| `MINERU_PROCESSING_WINDOW_SIZE` | Batch size (pages) | `64` |

## Output Structure

Full output (`mineru-parse.sh`):
```
output_dir/paper_name/auto/
  paper_name.md                   # Primary output
  paper_name_content_list.json    # Structured content (flat)
  paper_name_content_list_v2.json # Structured content (hierarchical)
  paper_name_middle.json          # Intermediate data (bbox, scores)
  paper_name_model.json           # Raw model detection output
  paper_name_layout.pdf           # Layout bbox visualization
  paper_name_span.pdf             # Span bbox visualization
  paper_name_origin.pdf           # Original PDF copy
  images/                         # Extracted images
```

After `mineru-clean.sh`:
```
output_dir/paper_name/auto/
  paper_name.md
  images/
```

## Common Mistakes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `mineru: command not found` | venv not activated | `source ~/.openclaw/venvs/mineru-pdf-parser/bin/activate` |
| `ConnectionResetError` on HF | Proxy / GFW blocking | `HF_ENDPOINT=https://hf-mirror.com` |
| Model download hangs | Network issue | Pre-download with `mineru-models-download`, use `--models-dir` |
| VRAM OOM | Too many pages | Reduce `MINERU_PROCESSING_WINDOW_SIZE` or `-s 0 -e 10` |
| `mineru-clean.sh` finds nothing | Wrong directory level | Target paper dir (has subdirs like auto/), not method dir |

## Conventions

- **PDF 下载目录**: 所有下载的 PDF 文件统一保存到 `/home/h2mzzz/.openclaw/openclaw-data/pdf/`
- **解析输出目录**: 所有解析结果保存到 `/home/h2mzzz/.openclaw/openclaw-data/pdf/`，使用 `-o /home/h2mzzz/.openclaw/openclaw-data/pdf/` 覆盖默认路径
- 完整流程：下载 PDF → 保存到 `/home/h2mzzz/.openclaw/openclaw-data/pdf/` → 在同目录下解析 → 清理中间文件

## Notes

- First run downloads ~2-5GB models to `~/.cache/mineru/` (subsequent runs offline)
- Pipeline backend: ~3s/page, tested on RTX 4060 8GB
- Default processing window: 64 pages
- Supports PDF, images (JPG/PNG), DOCX, PPTX, XLSX
