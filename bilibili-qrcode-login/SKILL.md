---
name: bilibili-qrcode-login
description: Use when needing authenticated access to Bilibili APIs, fetching user data from B站, accessing watch history or favorites, or any task involving bilibili.com that requires login. Also use when the user mentions "bilibili cookies", "B站登录", "SESSDATA", "扫码登录", or when other skills need Bilibili authentication to work.
---

# Bilibili QR Code Login

Get authenticated Bilibili session cookies. Either reuses existing browser login or triggers QR code scan flow.

## Workflow

```
Run script
  ├─ Try connect existing browser on port 9111
  │   ├─ Connected? → check cookies
  │   └─ No browser? → subprocess.Popen chromium manually (--no-sandbox)
  ├─ Browser already logged in? → Print cookies → Done
  └─ Not logged in?
       ├─ Generate QR code → Save to ~/.openclaw/openclaw-data/bilibili/qrcode.png
       ├─ Print "QRCODE_IMAGE:<path>" to stdout
       ├─ Wait for user to scan (up to 180s)
       └─ On success → Print cookies → Quit browser → Done
```

## Usage

```bash
/home/h2mzzz/.openclaw/venvs/bilibili-qrcode-login/bin/python ~/.openclaw/skills/bilibili-qrcode-login/scripts/bilibili_qr_login.py
```

### Reading the output

**Already logged in** — script prints key cookies directly:
```
========== B 站登录 Cookies ==========
  SESSDATA = 5eaae6d3%2C1792756926%2C...
  bili_jct = 0bfe02fc74baa7ec288cb3fef2b80932
  DedeUserID = 57382874
========== 共 22 个 bilibili cookies ==========
```

**Need to scan** — script outputs QR image path:
```
QRCODE_IMAGE:/home/h2mzzz/.openclaw/openclaw-data/bilibili/qrcode.png
```
Read this image and send it to the user. Tell them to scan with Bilibili mobile app. The script blocks until scan completes or times out.

## Key Cookies

| Cookie | Purpose | Needed For |
|--------|---------|------------|
| `SESSDATA` | Session auth token | All authenticated API calls |
| `bili_jct` | CSRF token | Write operations (comment, like) |
| `DedeUserID` | User numeric ID | User-specific API endpoints |

## Validating Cookies

```python
resp = requests.get(
    "https://api.bilibili.com/x/web-interface/nav",
    cookies={"SESSDATA": "<value>"},
    headers={"User-Agent": "Mozilla/5.0 ..."},
)
data = resp.json()
is_logged_in = data.get("data", {}).get("isLogin", False)
```

## Important Implementation Notes

- **WSL2 browser launch**: DrissionPage cannot launch snap chromium directly on WSL2 (crashes). Script uses `subprocess.Popen` to start chromium with `--no-sandbox`, then connects via `set_address()`.
- **Persistent browser profile**: Fixed user data directory (`~/.openclaw/openclaw-data/bilibili/browser-profile`) on port `9111`. Cookies persist across runs — scan QR once, reuse login for ~30 days.
- **86038 race condition**: QR code is destroyed after successful login confirmation. Poll may skip code 0 and see 86038 instead. Script falls back to checking browser cookies when 86038 is received.
- **Poll API pitfall**: Response is `{"code": 0, "data": {"code": 86101}}`. Check `data["data"]["code"]`, NOT `data["code"]`. Outer code is just API call status.
- **QR code image saved to**: `~/.openclaw/openclaw-data/bilibili/qrcode.png`
- **Requires real display** — headless mode not used (WSL2 + snap compatibility)
- **venv**: `~/.openclaw/venvs/bilibili-qrcode-login/` (uv, Python 3.11, 38MB)
- Script uses DrissionPage proprietary locator syntax (`text:扫码登录`, `tag:img@alt=Scan me!`) — NOT standard CSS/XPath
- Browser is always quit at end of `run()` (both `browser.quit()` and `subprocess.terminate()`)

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| No SESSDATA after poll success | Browser redirect not finished | Script waits 5s + `url_change()`, usually enough |
| Poll returns HTML | Missing User-Agent | Script includes UA headers |
| `chrome://newtab/` no cookies | Must visit bilibili.com first | Script navigates to bilibili.com first |
| QR code not found | Not on QR tab | Script clicks "扫码登录" tab |
| ConnectionResetError on startup | DrissionPage trying to launch snap chromium | Script now uses subprocess.Popen workaround |
| 86038 after scanning | QR destroyed during poll race condition | Script checks browser cookies as fallback |
