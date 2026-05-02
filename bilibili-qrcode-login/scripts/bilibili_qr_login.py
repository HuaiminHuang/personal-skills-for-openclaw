import logging

from DrissionPage import Chromium, ChromiumOptions
import requests
import json
import os
import time
import subprocess
import base64
from urllib.parse import urlparse, parse_qs
from PIL import Image
from io import BytesIO

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("bili-qr")

DATA_DIR = os.path.expanduser("~/.openclaw/openclaw-data/bilibili")
QR_PATH = os.path.join(DATA_DIR, "qrcode.png")
BROWSER_PORT = 9111
USER_DATA_DIR = os.path.join(DATA_DIR, "browser-profile")


class BilibiliQRLogin:
    KEY_NAMES = ["SESSDATA", "bili_jct", "DedeUserID", "DedeUserID__ckMdValue"]
    POLL_URL = "https://passport.bilibili.com/x/passport-login/web/qrcode/poll"

    def __init__(self):
        self.browser = None
        self.tab = None
        self._chrome_proc = None

    def run(self):
        self._start_browser()

        cookies = self._check_existing_session()
        if not cookies:
            self._navigate_login()
            qrcode_key, qr_saved_path = self._extract_qrcode()

            if qr_saved_path:
                print(f"QRCODE_IMAGE:{qr_saved_path}", flush=True)

            cookies = self._poll_login(qrcode_key)

        if cookies:
            self._print_cookies(cookies)
            status = "already_logged_in" if self._was_existing else "login_success"
            self._quit_browser()
            return {"status": status, "cookies": cookies}
        else:
            log.error("登录失败，未获取到关键 cookies")
            self._quit_browser()
            return {"status": "login_failed", "cookies": None}

    def _check_existing_session(self):
        self._was_existing = False
        log.info("检查浏览器是否已有登录态...")
        log.info("当前页面: %s", self.tab.url)

        self.tab.get("https://www.bilibili.com/")
        time.sleep(3)
        log.info("已打开首页: %s", self.tab.url)

        cookies = self._extract_cookies()
        if cookies:
            log.info("检测到有效登录态，跳过扫码登录")
            self._was_existing = True
            return cookies

        log.info("未检测到有效登录态，进入扫码登录流程")
        return None

    def _start_browser(self):
        log.info("启动浏览器 (port=%d, profile=%s)...", BROWSER_PORT, USER_DATA_DIR)

        co = ChromiumOptions()
        co.set_address(f"127.0.0.1:{BROWSER_PORT}")
        co.set_user_data_path(USER_DATA_DIR)

        try:
            log.info("尝试连接已有浏览器...")
            self.browser = Chromium(co)
            self.tab = self.browser.latest_tab
            log.info("已连接已有浏览器，URL: %s", self.tab.url)
            return
        except Exception:
            log.info("无已有浏览器，手动启动 chromium...")

        os.makedirs(USER_DATA_DIR, exist_ok=True)
        cmd = [
            "/snap/bin/chromium",
            "--no-sandbox",
            "--disable-dev-shm-usage",
            f"--remote-debugging-port={BROWSER_PORT}",
            f"--user-data-dir={USER_DATA_DIR}",
            "--no-first-run",
            "--no-default-browser-check",
            "about:blank",
        ]
        self._chrome_proc = subprocess.Popen(
            cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        log.info("chromium 进程已启动 (PID=%d)，等待就绪...", self._chrome_proc.pid)

        for i in range(15):
            time.sleep(1)
            try:
                import urllib.request
                urllib.request.urlopen(f"http://127.0.0.1:{BROWSER_PORT}/json/version", timeout=2)
                break
            except Exception:
                if i == 14:
                    raise RuntimeError("浏览器启动超时（15s）")
        else:
            raise RuntimeError("浏览器启动超时（15s）")

        time.sleep(1)
        co2 = ChromiumOptions()
        co2.set_address(f"127.0.0.1:{BROWSER_PORT}")
        self.browser = Chromium(co2)
        self.tab = self.browser.latest_tab
        log.info("浏览器已启动，初始 URL: %s", self.tab.url)

    def _navigate_login(self):
        log.info("导航到登录页...")
        self.tab.get("https://passport.bilibili.com/login")
        log.info("当前 URL: %s", self.tab.url)

        qr_tab = self.tab.ele("text:扫码登录")
        if qr_tab:
            log.info("找到扫码登录 tab，点击切换...")
            qr_tab.click()
            time.sleep(1)
        else:
            log.warning("未找到扫码登录 tab，可能已在扫码页面")

        log.info("切换后 URL: %s", self.tab.url)

    def _extract_qrcode(self):
        log.info("提取二维码...")
        qr_container = self.tab.ele("@class:login-scan__qrcode")
        if not qr_container:
            raise RuntimeError("未找到二维码容器")

        img_el = qr_container.ele("tag:img@alt=Scan me!")
        if not img_el:
            raise RuntimeError("未找到二维码图片")

        src = img_el.attr("src")
        log.info("二维码图片 src 类型: %s", "base64 PNG" if src and src.startswith("data:image") else src[:50] if src else "None")

        qr_saved_path = None
        if src and src.startswith("data:image/png;base64,"):
            b64_data = src.split(",", 1)[1]
            img = Image.open(BytesIO(base64.b64decode(b64_data)))
            log.info("原始二维码尺寸: %sx%s", img.width, img.height)
            img = img.resize((300, 300), Image.LANCZOS)
            os.makedirs(DATA_DIR, exist_ok=True)
            img.save(QR_PATH)
            qr_saved_path = QR_PATH
            log.info("二维码已保存（放大至 300x300）: %s", qr_saved_path)

        title_url = self.tab.run_js(
            'return document.querySelector('
            '".login-scan__qrcode [title*=\\"qrcode_key\\"]")'
            '?.title || ""'
        )
        log.info("title_url: %s", title_url[:120] if title_url else "(空)")

        parsed = urlparse(title_url)
        params = parse_qs(parsed.query)
        qrcode_key = params.get("qrcode_key", [""])[0]

        if not qrcode_key:
            raise RuntimeError(f"未提取到 qrcode_key, title_url={title_url[:100]}")

        log.info("qrcode_key: %s", qrcode_key)
        return qrcode_key, qr_saved_path

    def _poll_login(self, qrcode_key, timeout=180):
        log.info("开始轮询登录状态（超时 %ds）...", timeout)
        start = time.time()
        poll_count = 0
        last_status = None
        while time.time() - start < timeout:
            poll_count += 1
            try:
                resp = requests.get(
                    f"{self.POLL_URL}?qrcode_key={qrcode_key}",
                    timeout=10,
                    headers={
                        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) "
                        "AppleWebKit/537.36 Chrome/147.0.0.0 "
                        "Safari/537.36",
                        "Referer": "https://passport.bilibili.com/",
                    },
                )
                data = resp.json()
            except Exception as e:
                log.warning("poll 第 %d 次请求异常: %s", poll_count, e)
                time.sleep(3)
                continue

            outer_code = data.get("code", -1)
            inner_data = data.get("data", {})
            inner_code = inner_data.get("code", -1) if isinstance(inner_data, dict) else -1
            inner_msg = inner_data.get("message", "") if isinstance(inner_data, dict) else ""

            log.debug(
                "poll #%d: outer_code=%d, inner_code=%d, inner_msg=%s",
                poll_count, outer_code, inner_code, inner_msg,
            )

            if inner_code == 0:
                log.info("登录确认成功! (inner_code=0)")
                refresh_token = inner_data.get("refresh_token", "")
                if refresh_token:
                    log.info("refresh_token: %s...%s", refresh_token[:10], refresh_token[-5:])
                log.info("等待浏览器跳转... 当前 URL: %s", self.tab.url)
                time.sleep(2)
                try:
                    self.tab.wait.url_change("bilibili.com", timeout=15)
                    log.info("页面已跳转到: %s", self.tab.url)
                except Exception:
                    log.warning("url_change 等待超时，当前 URL: %s", self.tab.url)
                time.sleep(3)
                log.info("提取 cookies 前页面 URL: %s", self.tab.url)
                return self._extract_cookies()
            elif inner_code == 86090:
                if last_status != "confirming":
                    log.info("已扫码，请在手机上确认...")
                    last_status = "confirming"
            elif inner_code == 86101:
                if last_status != "waiting":
                    log.info("等待扫码... (第 %d 次轮询)", poll_count)
                    last_status = "waiting"
            elif inner_code == 86038:
                log.warning("二维码已失效，检查浏览器是否已登录...")
                time.sleep(2)
                self.tab.get("https://www.bilibili.com/")
                time.sleep(3)
                cookies = self._extract_cookies()
                if cookies:
                    log.info("浏览器已有登录态，登录成功")
                    return cookies
                log.error("二维码已过期且浏览器未登录")
                return None
            else:
                log.warning("状态异常: outer=%d, inner=%d, msg=%s", outer_code, inner_code, inner_msg)

            time.sleep(2)

        log.error("轮询超时（%d 次）", poll_count)
        return None

    def _extract_cookies(self):
        cookies = self.tab.cookies()
        bilibili = [c for c in cookies if "bilibili" in c.get("domain", "")]
        log.info("浏览器总 cookies: %d，bilibili 域: %d", len(cookies), len(bilibili))

        key_found = [c["name"] for c in bilibili if c["name"] in self.KEY_NAMES]
        log.info("关键 cookies: %s", key_found)

        if not key_found:
            all_names = [c["name"] for c in bilibili]
            log.warning("未找到关键 cookies，所有 cookie 名称: %s", all_names)
            return None

        return bilibili

    def _print_cookies(self, cookies):
        log.info("========== B 站登录 Cookies ==========")
        for c in cookies:
            if c["name"] in self.KEY_NAMES:
                log.info("  %s = %s", c["name"], c["value"])
        log.info("========== 共 %d 个 bilibili cookies ==========", len(cookies))

    def _quit_browser(self):
        try:
            if self.browser:
                self.browser.quit()
                log.info("浏览器已关闭")
        except Exception as e:
            log.warning("关闭浏览器异常: %s", e)
        if self._chrome_proc:
            try:
                self._chrome_proc.terminate()
                self._chrome_proc.wait(timeout=5)
                log.info("chromium 进程已终止")
            except Exception:
                self._chrome_proc.kill()
                log.warning("chromium 进程已强制终止")


if __name__ == "__main__":
    fetcher = BilibiliQRLogin()
    result = fetcher.run()
    print(json.dumps({"status": result["status"]}, ensure_ascii=False), flush=True)
