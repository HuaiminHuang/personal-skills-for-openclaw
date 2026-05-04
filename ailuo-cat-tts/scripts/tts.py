#!/usr/bin/env python3
"""
TTS script for OpenClaw - MiniMax API TTS (via minimax-multimodal-toolkit)

Usage:
  tts.py --text "文本" [--voice-id <音色ID>] [--output <输出路径>]

Environment:
  MINIMAX_API_HOST  - API 地址 (默认 https://api.minimaxi.com)
  MINIMAX_API_KEY   - API Key

Output:
  stdout: 生成音频的绝对路径（每行一个，支持多段）
  stderr: 进度信息

Tmp 文件管理:
  输出目录: /tmp/openclaw_tts/
  每次生成前检查目录总大小，超过 1GB 按时间倒序删除旧文件
  发送完成后立即删除已发送的文件
"""

import os
import sys
import argparse
import subprocess
import uuid

# ──补全环境变量（exec 工具不会自动加载 ~/.profile）─────────────────────────
for _profile in ("/home/h2mzzz/.profile", "/home/h2mzzz/.bashrc"):
    if os.path.exists(_profile):
        result = subprocess.run(
            ["bash", "-c", f"source '{_profile}' && env"],
            capture_output=True, text=True,
        )
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                if "=" in line:
                    k, v = line.split("=", 1)
                    if k not in os.environ:
                        os.environ[k] = v
        break

# Tmp output directory (1GB threshold, auto-cleanup)
TMP_DIR = "/home/h2mzzz/.openclaw/media/qqbot/voice"
MAX_TMP_SIZE_BYTES = 1 * 1024 * 1024 * 1024  # 1GB

# Default voice: cloned ailuo_cat
DEFAULT_VOICE_ID = "ailuo_cat_japan"

# MiniMax toolkit script path
TOOLKIT_SCRIPT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..",
    "..",
    "minimax-multimodal-toolkit",
    "scripts",
    "tts",
    "generate_voice.sh"
)


def cleanup_tmp_dir(max_bytes: int = MAX_TMP_SIZE_BYTES):
    """Remove oldest files in TMP_DIR until total size <= max_bytes."""
    if not os.path.isdir(TMP_DIR):
        return

    files = []
    total = 0
    for f in os.scandir(TMP_DIR):
        if f.is_file() and f.name.endswith((".wav", ".mp3")):
            files.append(f)
            total += f.stat().st_size

    if total <= max_bytes:
        return

    files.sort(key=lambda f: f.stat().st_mtime, reverse=True)

    removed = 0
    for f in files:
        if total - removed <= max_bytes:
            break
        size = f.stat().st_size
        os.remove(f.path)
        removed += size
        print(f"[tmp cleanup] removed {f.name} ({size / 1024 / 1024:.1f} MB)", file=sys.stderr)


def synthesize(
    text: str,
    voice_id: str = DEFAULT_VOICE_ID,
    output_path: str = None,
    max_chars_per_segment: int = 500,
    speed: float = 1.0,
    pitch: float = 0.0,
    volume: float = 1.0,
    emotion: str = "",
) -> list[str]:
    """
    Synthesize speech using MiniMax TTS API.

    Returns:
        List of generated audio file paths.
    """
    # Ensure tmp dir exists
    os.makedirs(TMP_DIR, exist_ok=True)

    # Cleanup old tmp files before generating
    cleanup_tmp_dir()

    # Build the generate_voice.sh command
    if not output_path:
        seg_name = f"tts_{uuid.uuid4().hex[:8]}.mp3"
        output_path = os.path.join(TMP_DIR, seg_name)

    # Build a clean env with conda bin + system bins, plus API keys
    local_bin = os.path.expanduser("~/.local/bin")
    api_host = os.environ.get("MINIMAX_API_HOST", "https://api.minimaxi.com")
    api_key = os.environ.get("MINIMAX_API_KEY", "")

    # Build env: inherit current os.environ, prepend ~/.local/bin (has jq) to PATH, override API keys
    run_env = dict(os.environ)
    run_env["PATH"] = local_bin + ":/usr/local/bin:/usr/bin:/bin"
    run_env["MINIMAX_API_HOST"] = api_host
    run_env["MINIMAX_API_KEY"] = api_key

    print(f">> Synthesizing with voice '{voice_id}': {text[:50]}{'...' if len(text) > 50 else ''}", file=sys.stderr)

    cmd = ["/bin/bash", TOOLKIT_SCRIPT, "tts", text, "-v", voice_id, "-o", output_path]
    if speed != 1.0:
        cmd += ["--speed", str(speed)]
    if pitch != 0.0:
        cmd += ["--pitch", str(pitch)]
    if volume != 1.0:
        cmd += ["--volume", str(volume)]
    if emotion:
        cmd += ["--emotion", emotion]

    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        env=run_env,
    )

    if result.returncode != 0:
        print(f">> Error: {result.stderr.strip()}", file=sys.stderr)
        raise RuntimeError(f"TTS failed: {result.stderr.strip()}")

    if os.path.exists(output_path):
        import shutil
        size_mb = os.path.getsize(output_path) / 1024 / 1024
        print(f">> Generated: {output_path} ({size_mb:.1f} MB)", file=sys.stderr)
        return [output_path]
    else:
        raise RuntimeError(f"TTS output file not found: {output_path}")


def main():
    parser = argparse.ArgumentParser(description="MiniMax TTS for OpenClaw")
    parser.add_argument("--text", type=str, required=True, help="Text to synthesize")
    parser.add_argument("--voice-id", type=str, default=DEFAULT_VOICE_ID, help=f"Voice ID (default: {DEFAULT_VOICE_ID})")
    parser.add_argument("--output", type=str, default=None, help="Output path (default: auto in /tmp/openclaw_tts/)")
    parser.add_argument("--max-chars", type=int, default=500, help="Max characters per segment (default: 500)")
    parser.add_argument("--speed", type=float, default=1.0, help="Speech speed 0.5~2.0 (default: 1.0)")
    parser.add_argument("--pitch", type=int, default=0, help="Pitch -1~1 integer (default: 0)")
    parser.add_argument("--volume", type=float, default=1.0, help="Volume 0~2.0 (default: 1.0)")
    parser.add_argument("--emotion", type=str, default="", help="Emotion: happy|sad|angry|fearful|disgusted|surprised|calm|fluent|whisper")

    args = parser.parse_args()

    try:
        paths = synthesize(
            text=args.text,
            voice_id=args.voice_id,
            output_path=args.output,
            max_chars_per_segment=args.max_chars,
            speed=args.speed,
            pitch=args.pitch,
            volume=args.volume,
            emotion=args.emotion,
        )

        for p in paths:
            print(p)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
