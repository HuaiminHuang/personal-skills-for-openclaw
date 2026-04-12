---
name: video-tutor
description: 视频助教技能 - 下载视频、转写音频、提取关键知识点、截取重要截图，生成图文并茂的课程总结。触发词：「视频总结」「分析视频」「课程笔记」
emoji: "🎓"
---

# 🎓 Video Tutor - 视频助教

自动分析视频内容，生成图文并茂的知识总结。

**参考范本**：`~/TRANSFER_LEARNING_REPORT.md`

---

## 目录结构

```
video-tutor/
├── SKILL.md
├── config.env                      # 统一配置（含 CUDA 路径）
├── agents/
│   └── openai.yaml                 # 备用：agent接口配置
├── assets/
│   └── notes-template.tex           # 备用：LaTeX模板
├── references/
│   ├── analyze_prompt.md           # ✅ 分析提示词+书写规范
│   ├── output_template.md          # ✅ Markdown模板
│   └── writing_standards.md        # ✅ 书写规范详解
└── scripts/
    ├── 00_setup.sh                # 初始化工作目录
    ├── 01_download.sh             # 下载视频+音频+字幕
    ├── 02_transcribe.sh           # Whisper转写
    ├── 03_extract_frames.sh       # 批量提取关键帧
    └── 04_generate_report.sh      # 生成报告
```

**数据输出目录**：`~/.openclaw/openclaw-data/video-tutor/`

---

## 工作流程

```
视频URL → 01_download → 02_transcribe → 03_extract_frames → 生成报告
     ↓              ↓              ↓
  视频+音频     转写文本       关键帧截图
  +字幕
```

---

## 书写规范

### 核心原则

| 原则 | 说明 |
|------|------|
| **动机优先** | 先解释"为什么"，再解释"是什么" |
| **结构化** | 每个知识点：定义→思想→对比→例子→总结 |
| **不堆字幕** | 不要按时间顺序罗列，要重组内容 |
| **有深度** | 解释原理、对比差异、给出例子 |

### 每节内容组织顺序

1. **动机**：为什么要介绍这个概念？
2. **核心思想**：主要观点是什么？
3. **机制**：它是如何工作的？
4. **对比**：和其他概念有什么区别？
5. **例子**：具体示例说明
6. **总结**：读者应该记住什么

### 呆猫风格

- 使用"喵~"作为语气词
- 适当使用人格化表达
- 解释复杂概念时用类比

---

## 帧选择规范

### 检查清单（7项）

1. **相关性**：帧必须直接支持当前段落
2. **内容可见**：文字/公式必须清晰
3. **完整状态**：选择最终呈现状态
4. **最佳候选**：比较多个附近帧
5. **可读性**：标签图表必须清晰
6. **时间准确**：时间戳与内容对应
7. **教学价值**：真正帮助解释内容

### 帧命名格式

```
frame_{序号}_{hh}h{mm}m{ss}s.jpg
例如：frame_01_00h03h05s.jpg
```

---

## 输出文件

```
{task_id}/
├── {task_id}.mp4              # 视频
├── audio.wav                   # 音频
├── transcript.txt             # 转写
├── transcript.srt              # SRT字幕
├── info.txt                    # 任务信息
├── images/
│   └── frame_{nn}_{hh}h{mm}m{ss}s.jpg
└── {task_id}_REPORT.md       # ✅ 分析报告（按范本格式）
```

---

## 参考资料

- `references/writing_standards.md` - 完整书写规范
- `references/output_template.md` - Markdown模板
- `references/analyze_prompt.md` - 分析提示词

---

*🎓 呆猫出品*
