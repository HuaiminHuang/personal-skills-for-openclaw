---
name: stt
description: Use when the user sends a voice message, or asks for 语音转文字, 语音识别, 转录, speech transcription, voice recognition, or STT.
---

# STT - Speech-to-Text

## Overview

语音转文字。使用 faster-whisper small 模型在 GPU 上进行语音识别，支持中英日韩等多语言。

## When to Use

- 用户发送语音消息（飞书 .ogg 音频）
- 用户要求转录语音内容
- 用户提到"语音转文字"、"识别语音"、"转录"

### When NOT to Use

- 用户发送文字消息（无需 STT）
- 用户要求语音合成（TTS，方向相反）
- 用户要求翻译而非转录

## Quick Reference

```bash
source config.env && $VENV_PYTHON scripts/whisper_stt.py <音频文件路径> [语言代码]
```

语言代码默认 `zh`，可指定 `en`、`ja`、`ko` 等。

音频文件存放在 `~/.openclaw/media/inbound/`，格式 `.ogg`（Opus）。

输出：stdout 打印识别文字，stderr 输出语言检测结果。

## Common Mistakes

| 错误 | 原因 | 解决方式 |
|------|------|---------|
| GPU 推理失败 | CUDA 不可用 | 脚本自动回退 CPU（较慢），检查 `config.env` 中 CUDA_LIB_PATH |
| 模型加载失败 | 模型路径错误 | 检查 `config.env` 中 WHISPER_MODEL_PATH |
| 音频格式不支持 | 非 .ogg 文件 | 先用 ffmpeg 转换为 Opus .ogg |
| 识别结果为空 | 音频无语音或噪音过大 | 确认音频文件有效 |

## Environment

详细配置（模型路径、CUDA、venv）见 `config.env` 和 `references/env_config.md`。
