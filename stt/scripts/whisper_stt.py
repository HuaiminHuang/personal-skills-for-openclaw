#!/usr/bin/env python3
"""
STT script for OpenClaw - Whisper small FP16 on CUDA
Usage: whisper_stt.py <audio_file> [language]

Requires: /home/h2mzzz/.openclaw/venvs/stt/bin/python
"""

import os
import sys

# CUDA environment - required for GPU inference
os.environ["LD_LIBRARY_PATH"] = "/usr/local/lib/ollama/cuda_v12"

# Model path
MODEL_PATH = "/home/h2mzzz/.cache/huggingface/hub/models--Systran--faster-whisper-small"


def transcribe(audio_path: str, language: str = "zh") -> str:
    """Transcribe audio file using faster-whisper small on CUDA."""
    from faster_whisper import WhisperModel

    model = WhisperModel(
        MODEL_PATH,
        device="cuda",
        compute_type="float16"
    )

    segments, info = model.transcribe(audio_path, language=language)
    print(f"Detected language: {info.language}", file=sys.stderr)

    results = []
    for seg in segments:
        results.append(seg.text.strip())

    return " ".join(results)


def main():
    if len(sys.argv) < 2:
        print("Usage: whisper_stt.py <audio_file> [language]", file=sys.stderr)
        sys.exit(1)

    audio_file = sys.argv[1]
    language = sys.argv[2] if len(sys.argv) > 2 else "zh"

    if not os.path.exists(audio_file):
        print(f"Error: file not found: {audio_file}", file=sys.stderr)
        sys.exit(1)

    result = transcribe(audio_file, language)
    print(result)


if __name__ == "__main__":
    main()
