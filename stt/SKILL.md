---
name: stt
description: 语音转文字（STT）技能。当用户发送语音消息、或提到"识别语音"、"转录"、"语音转文字"时触发。使用 faster-whisper small 模型在 GPU 上进行高精度中文语音识别。环境路径和 CUDA 配置已封装在 scripts/ 和 references/ 中。
---

# STT - 语音转文字

## 快速使用

接收到用户语音后，执行：

```bash
LD_LIBRARY_PATH=/usr/local/lib/ollama/cuda_v12 /home/h2mzzz/.openclaw/venvs/stt/bin/python /home/h2mzzz/.openclaw/skills/stt/scripts/whisper_stt.py <音频文件路径> [语言代码]
```

语言代码默认 `zh`（中文），可指定 `en`、`ja`、`ko` 等。

## 输入

- 飞书语音消息存放在：`~/.openclaw/media/inbound/`
- 文件格式：`.ogg`（Opus 编码）

## 输出

脚本直接打印识别文字，呆猫读取后转发给用户喵。

## 环境信息

详细配置见 `references/env_config.md`，包含：
- 模型路径和大小
- CUDA 环境变量
- venv Python 路径

## 注意事项

- 模型已下载在 GPU 上，推理速度很快
- 如果 GPU 不可用，脚本会自动回退到 CPU（但速度较慢）
- 首次调用模型加载需要 2-3 秒，之后推理很快
