#!/usr/bin/env python3
"""
STT script for OpenClaw - Whisper small FP16 on CUDA
Usage: whisper_stt.py <audio_file> [language]

Config: reads ../config.env for model path and CUDA settings.
"""

import os
import sys
import subprocess


def _load_config():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_path = os.path.normpath(os.path.join(script_dir, "..", "config.env"))
    if not os.path.exists(config_path):
        return {}
    result = subprocess.run(
        ["bash", "-c", f"source '{config_path}' && env"],
        capture_output=True, text=True,
    )
    env = {}
    if result.returncode == 0:
        for line in result.stdout.splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                env[k] = v
    return env


_cfg = _load_config()

MODEL_PATH = _cfg.get(
    "WHISPER_MODEL_PATH",
    "/home/h2mzzz/.cache/huggingface/hub/models--Systran--faster-whisper-small",
)


def transcribe(audio_path: str, language: str = "zh") -> str:
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
