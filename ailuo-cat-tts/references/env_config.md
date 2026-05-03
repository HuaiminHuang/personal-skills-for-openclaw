# TTS 环境配置

## 实现方式

| 项目 | 值 |
|------|-----|
| TTS 引擎 | MiniMax TTS API (speech-2.8-hd) |
| API 地址 | `https://api.minimaxi.com` |
| API Key | `sk-api-r2o...` (已配置) |

## 音色配置

| Voice ID | 类型 | 状态 |
|----------|------|------|
| `ailuo_cat` | 克隆音色（旧版，已弃用） | ⚠️ |
| `ailuo_cat_japan` | 克隆音色（呆猫本人日语音频 180s） | ✅ 已注册 |
| `female-shaonv` | 内置女声 | ✅ 可用 |
| `male-qn-qingse` | 内置男声 | ✅ 可用 |

## 调用脚本

| 项目 | 路径 |
|------|------|
| 主脚本 | `~/.openclaw/skills/ailuo-cat-tts/scripts/tts.py` |
| MiniMax 工具包 | `~/.openclaw/skills/minimax-multimodal-toolkit/scripts/tts/generate_voice.sh` |

## Tmp 目录

| 项目 | 值 |
|------|-----|
| 目录路径 | `~/.openclaw/openclaw-data/tts/audio/` |
| 阈值 | 1GB |
| 清理策略 | 超过阈值时按时间倒序删除旧文件 |

## 调用示例

```bash
# 默认（呆猫克隆音色）
python ~/.openclaw/skills/ailuo-cat-tts/scripts/tts.py --text "你好喵，我是呆猫"

# 指定音色
python ~/.openclaw/skills/ailuo-cat-tts/scripts/tts.py \
  --text "今天天气真好" \
  --voice-id female-shaonv \
  --output /tmp/my_audio.mp3
```
