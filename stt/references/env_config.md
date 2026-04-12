# STT 环境配置

## 模型信息

| 项目 | 值 |
|------|-----|
| 模型名称 | Systran/faster-whisper-small |
| 模型路径 | `/home/h2mzzz/.cache/huggingface/hub/models--Systran--faster-whisper-small` |
| 模型大小 | 461MB |
| 量化方式 | FP16 (float16) |
| 参数量 | 244M |

## CUDA 环境

| 项目 | 值 |
|------|-----|
| CUDA 库路径 | `/usr/local/lib/ollama/cuda_v12` |
| 显存占用 | ~2.5-3GB (FP16) |
| 适用 GPU | RTX 4060 (8GB) 及以上 |

## Python 环境

| 项目 | 值 |
|------|-----|
| venv 路径 | `/home/h2mzzz/.openclaw/venvs/stt` |
| Python 版本 | 3.11 |
| 核心依赖 | faster-whisper, ctranslate2, httpx[socks] |

## 调用示例

```bash
# 基本调用
/home/h2mzzz/.openclaw/skills/stt/scripts/whisper_stt.py <音频文件路径>

# 指定语言
/home/h2mzzz/.openclaw/skills/stt/scripts/whisper_stt.py <音频文件路径> en

# 在 Python 中调用
from faster_whisper import WhisperModel
model = WhisperModel(
    '/home/h2mzzz/.cache/huggingface/hub/models--Systran--faster-whisper-small',
    device='cuda',
    compute_type='float16'
)
segments, info = model.transcribe('audio.ogg', language='zh')
for seg in segments:
    print(seg.text)
```
