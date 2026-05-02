# Image Generation 环境配置

## API

| 项目 | 值 |
|------|-----|
| 模型 | `image-01` |
| API Host | `https://api.minimaxi.com` |
| 每日额度 | 50-200 张（视套餐） |
| API Key | 配置在 ~/.profile |

## 目录

| 目录 | 用途 |
|------|------|
| `~/.openclaw/openclaw-data/image/generated/` | 生成图片持久化保存 |
| `~/.openclaw/openclaw-data/image/references/` | 参考图收藏 |
| `~/.openclaw/media/inbound/` | OpenClaw 接收的参考图 |

## Tmp 管理

目录超过 500MB 时按时间倒序清理旧文件。

## 错误码

| 错误码 | 原因 | 处理方式 |
|--------|------|---------|
| 1026 | 内容涉及敏感 | 修改 prompt，去除敏感词 |
| 1008 | 额度不足 | 告知用户，等次日重置 |
| 1002 | 限流 | 等待 5-10 秒后重试 |
| 2013 | 参数异常 | 检查 prompt 长度/格式 |
