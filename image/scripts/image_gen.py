#!/usr/bin/env python3
"""
Image Generation Wrapper for MiniMax API (via minimax-multimodal-toolkit)

功能：
- 自动加载 ~/.profile 环境变量
- 支持 t2i（文生图）和 i2i（图生图）模式
- 自动查找 OpenClaw 接收的参考图路径
- Prompt 优化增强
-Tmp 文件清理

Usage:
  image_gen.py --prompt "描述" [--mode i2i] [--ref-image <path>] [--output <path>] [--aspect-ratio 4:3] [--n 1]

Environment:
  MINIMAX_API_HOST  - API 地址 (默认 https://api.minimaxi.com)
  MINIMAX_API_KEY   - API Key (Token Plan sk-cp-...)
"""

import os
import sys
import argparse
import subprocess
import uuid
import glob

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

# Tmp output directory (500MB threshold for images, auto-cleanup)
TMP_DIR = "/home/h2mzzz/.openclaw/openclaw-data/image/generated"
MAX_TMP_SIZE_BYTES = 500 * 1024 * 1024  # 500MB for images

# Official MiniMax toolkit script
TOOLKIT_SCRIPT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..",
    "..",
    "minimax-multimodal-toolkit",
    "scripts",
    "image",
    "generate_image.sh"
)


def get_latest_inbound_image():
    """获取 OpenClaw inbound 目录中最新的图片文件路径"""
    inbound_dir = "/home/h2mzzz/.openclaw/media/inbound"
    if not os.path.isdir(inbound_dir):
        return None

    # 查找所有图片文件，按修改时间排序
    patterns = ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif"]
    files = []
    for pattern in patterns:
        files.extend(glob.glob(os.path.join(inbound_dir, pattern)))
        # 也搜索子目录
        subdirs = [d for d in os.listdir(inbound_dir) if os.path.isdir(os.path.join(inbound_dir, d))]
        for subdir in subdirs:
            subpath = os.path.join(inbound_dir, subdir, pattern)
            files.extend(glob.glob(subpath))

    if not files:
        return None

    # 按修改时间倒序，返回最新的
    files.sort(key=lambda f: os.path.getmtime(f), reverse=True)
    latest = files[0]
    # 确认文件不是空的（>1KB）
    if os.path.getsize(latest) > 1024:
        return latest
    return None


def cleanup_tmp_dir(max_bytes: int = MAX_TMP_SIZE_BYTES):
    """Remove oldest files in TMP_DIR until total size <= max_bytes."""
    if not os.path.isdir(TMP_DIR):
        return

    files = []
    total = 0
    for f in os.scandir(TMP_DIR):
        if f.is_file() and f.name.endswith((".png", ".jpg", ".jpeg", ".webp")):
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


def enhance_prompt(prompt: str, mode: str = "t2i") -> str:
    """
    优化用户输入的 prompt，增加细节和风格描述。

    原则：
    - 保持用户原始描述不变
    - 自动添加基础质量修饰词
    - i2i 模式：参考图已经携带角色信息，prompt 只需描述新场景

    Args:
        prompt: 用户原始 prompt
        mode: t2i 或 i2i

    Returns:
        优化后的 prompt
    """
    # 如果 prompt 已经足够长，只添加质量修饰
    if len(prompt) > 150:
        return prompt + ", high quality"

    # 基础质量修饰词（自动添加）
    quality_suffix = ", high quality, detailed"

    return prompt + quality_suffix


def generate_image(
    prompt: str,
    mode: str = "t2i",
    ref_image: str = None,
    output_path: str = None,
    aspect_ratio: str = "4:3",
    n: int = 1,
    seed: int = None,
    prompt_optimizer: bool = True,
) -> list[str]:
    """
    生成图片。

    Returns:
        生成的图片路径列表
    """
    os.makedirs(TMP_DIR, exist_ok=True)

    # Cleanup old tmp files before generating
    cleanup_tmp_dir()

    # Resolve ref_image - 如果没指定，尝试获取最新的 inbound 图片
    if mode == "i2i" and not ref_image:
        ref_image = get_latest_inbound_image()
        if ref_image:
            print(f">> Using latest inbound image as ref: {ref_image}", file=sys.stderr)
        else:
            raise ValueError("i2i mode requires --ref-image, but no reference image found")

    # Enhance prompt
    enhanced_prompt = enhance_prompt(prompt, mode=mode)

    # Build output path
    if not output_path:
        ext = "png"
        filename = f"img_{uuid.uuid4().hex[:8]}.{ext}"
        output_path = os.path.join(TMP_DIR, filename)

    # Build env
    local_bin = os.path.expanduser("~/.local/bin")
    api_host = os.environ.get("MINIMAX_API_HOST", "https://api.minimaxi.com")
    api_key = os.environ.get("MINIMAX_API_KEY", "")

    run_env = dict(os.environ)
    run_env["PATH"] = local_bin + ":/usr/local/bin:/usr/bin:/bin"
    run_env["MINIMAX_API_HOST"] = api_host
    run_env["MINIMAX_API_KEY"] = api_key

    # Build command
    cmd = [
        "/bin/bash", TOOLKIT_SCRIPT,
        "--prompt", enhanced_prompt,
        "--aspect-ratio", aspect_ratio,
        "-o", output_path,
    ]

    if mode == "i2i" and ref_image:
        cmd.extend(["--mode", "i2i", "--ref-image", ref_image])

    if n > 1:
        cmd.extend(["--n", str(n)])

    if seed is not None:
        cmd.extend(["--seed", str(seed)])

    if prompt_optimizer:
        cmd.append("--prompt-optimizer")

    print(f">> Generating [{mode}]: {prompt[:60]}{'...' if len(prompt) > 60 else ''}", file=sys.stderr)
    if enhanced_prompt != prompt:
        print(f">> Enhanced: {enhanced_prompt[:80]}...", file=sys.stderr)

    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        env=run_env,
    )

    if result.returncode != 0:
        print(f">> Error: {result.stderr.strip()}", file=sys.stderr)
        raise RuntimeError(f"Image generation failed: {result.stderr.strip()}")

    # Collect output files
    output_files = []
    if os.path.exists(output_path):
        size_mb = os.path.getsize(output_path) / 1024 / 1024
        print(f">> Generated: {output_path} ({size_mb:.2f} MB)", file=sys.stderr)
        output_files.append(output_path)

    return output_files


def main():
    parser = argparse.ArgumentParser(description="MiniMax Image Generation for OpenClaw")
    parser.add_argument("--prompt", type=str, required=True, help="Image description text")
    parser.add_argument("--mode", type=str, default="t2i", choices=["t2i", "i2i"], help="Generation mode: t2i (text-to-image) or i2i (image-to-image)")
    parser.add_argument("--ref-image", type=str, default=None, help="Reference image path for i2i mode")
    parser.add_argument("--output", type=str, default=None, help="Output file path")
    parser.add_argument("--aspect-ratio", type=str, default="4:3",
                        choices=["1:1", "16:9", "4:3", "3:2", "2:3", "3:4", "9:16", "21:9"],
                        help="Aspect ratio (default: 4:3)")
    parser.add_argument("--n", type=int, default=1, help="Number of images to generate (1-9)")
    parser.add_argument("--seed", type=int, default=None, help="Random seed for reproducibility")
    parser.add_argument("--no-prompt-optimizer", action="store_true", help="Disable prompt optimizer")

    args = parser.parse_args()

    try:
        files = generate_image(
            prompt=args.prompt,
            mode=args.mode,
            ref_image=args.ref_image,
            output_path=args.output,
            aspect_ratio=args.aspect_ratio,
            n=args.n,
            seed=args.seed,
            prompt_optimizer=not args.no_prompt_optimizer,
        )

        for f in files:
            print(f)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
