#!/usr/bin/env python3
"""인앱 이벤트 그림을 그린다. 글자·앱 이름·로고를 넣지 않는다(Apple 권고). 테두리·그라데이션도 넣지 않는다.

    python3 marketing/global/events/make_event_art.py

나오는 것 (marketing/global/events/):
    typing-23-card.png      3840x2160 (16:9, 이벤트 카드)
    typing-23-detail.png    2160x3840 (9:16, 이벤트 상세 화면)
    holiday-gift-card.png   3840x2160
    holiday-gift-detail.png 2160x3840

App Store 가 그림 위에 자르기·그라데이션을 얹으므로 중요한 것은 가운데에 모은다.
렌더링은 scripts/make_marketing_screenshots.py 와 같은 헤드리스 Chrome 이다.
"""
import pathlib, subprocess, tempfile, time

HERE = pathlib.Path(__file__).resolve().parent
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

BG = "#131316"
KEY = "#2c2c31"
KEY_TOP = "#3a3a40"
ACCENT = "#0A84FF"
INK = "#f2f2f4"

# 23개 입력 언어에서 한 글자씩. 한자는 넣지 않는다(일본어·중국어 한자 변환은 아직 없다).
GLYPHS = ["A", "ㅎ", "あ", "Ж", "ß", "ก", "Ω", "ç", "đ", "ş", "ø", "ñ",
          "ł", "ř", "ä", "ㄅ", "ā", "é", "å", "ğ", "ё", "ü", "ơ", "ö", "ά"]

FONT = '-apple-system, "SF Pro Display", "Apple SD Gothic Neo", "Hiragino Sans", "Thonburi", sans-serif'


def key(glyph, size, accent=False):
    bg = ACCENT if accent else KEY
    return (f'<div class="k" style="width:{size}px;height:{size}px;background:{bg};'
            f'font-size:{int(size*0.46)}px">{glyph}</div>')


def chip(w, h, accent=False):
    color = ACCENT if accent else KEY_TOP
    return f'<div class="chip" style="width:{w}px;height:{h}px;background:{color}"></div>'


def typing_html(w, h):
    portrait = h > w
    size = 132 if not portrait else 150
    cols = 8 if not portrait else 5
    rows = 3 if not portrait else 5
    glyphs = (GLYPHS * 3)[: cols * rows]
    accent_at = {cols + 2}  # 한 칸만 파랗게
    grid = "".join(key(g, size, i in accent_at) for i, g in enumerate(glyphs))
    # 맨 위 띠: 저장해 둔 단축어 자리(글자 없이 알약 모양만)
    chips = chip(330, 84, True) + chip(250, 84) + chip(290, 84)
    if portrait:
        chips = chip(300, 84, True) + chip(220, 84) + chip(200, 84)
    gap = 26
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
html,body{{margin:0;width:{w}px;height:{h}px;background:{BG};overflow:hidden}}
.wrap{{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:{gap*2}px}}
.board{{background:#1c1c20;border-radius:56px;padding:44px;display:flex;flex-direction:column;gap:{gap+8}px;align-items:center}}
.chips{{display:flex;gap:22px}}
.chip{{border-radius:42px}}
.grid{{display:grid;grid-template-columns:repeat({cols},{size}px);gap:{gap}px}}
.k{{border-radius:28px;color:{INK};display:flex;align-items:center;justify-content:center;
   font-family:{FONT};font-weight:500;box-shadow:0 6px 0 #0c0c0e}}
.space{{width:{cols*size+(cols-1)*gap - 2*(size+gap)}px;height:{size}px;border-radius:28px;background:{KEY};box-shadow:0 6px 0 #0c0c0e}}
.bottom{{display:flex;gap:{gap}px}}
</style></head><body><div class="wrap"><div class="board">
<div class="chips">{chips}</div>
<div class="grid">{grid}</div>
<div class="bottom">{key("🌐", size)}<div class="space"></div>{key("⏎", size)}</div>
</div></div></body></html>"""


def gift_html(w, h):
    portrait = h > w
    box = 620 if not portrait else 600
    small = 120 if not portrait else 140
    ring = ["A", "あ", "ㅎ", "Ж", "ß", "ก", "ç", "đ"]
    # 큰 열쇠 모양 선물 상자 + 리본, 둘레에 작은 키
    if portrait:
        pos = [(-0.36, -0.30), (0.36, -0.30), (-0.40, 0.0), (0.40, 0.0),
               (-0.36, 0.30), (0.36, 0.30), (-0.12, -0.36), (0.12, 0.36)]
    else:
        pos = [(-0.34, -0.28), (0.34, -0.28), (-0.40, 0.04), (0.40, 0.04),
               (-0.30, 0.32), (0.30, 0.32), (-0.18, -0.38), (0.18, 0.40)]
    keys = "".join(
        f'<div class="k" style="left:{w/2 + x*w - small/2:.0f}px;top:{h/2 + y*h - small/2:.0f}px;'
        f'width:{small}px;height:{small}px;font-size:{int(small*0.46)}px">{g}</div>'
        for g, (x, y) in zip(ring, pos))
    rib = int(box * 0.16)
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
html,body{{margin:0;width:{w}px;height:{h}px;background:{BG};overflow:hidden;position:relative}}
.box{{position:absolute;left:{(w-box)/2:.0f}px;top:{(h-box)/2 + box*0.06:.0f}px;width:{box}px;height:{box}px;
     border-radius:{box*0.2:.0f}px;background:{KEY};box-shadow:0 {box*0.04:.0f}px 0 #0c0c0e;overflow:hidden}}
.v{{position:absolute;left:{(box-rib)/2:.0f}px;top:0;width:{rib}px;height:100%;background:{ACCENT}}}
.hz{{position:absolute;top:{(box-rib)/2:.0f}px;left:0;height:{rib}px;width:100%;background:{ACCENT}}}
.bow{{position:absolute;box-sizing:border-box;width:{box*0.32:.0f}px;height:{box*0.22:.0f}px;border:{rib*0.55:.0f}px solid {ACCENT};
     border-radius:50%;top:{(h-box)/2 - box*0.10:.0f}px}}
.bl{{left:{w/2 - box*0.32 + rib*0.3:.0f}px;transform:rotate(-16deg);transform-origin:right center}}
.br{{left:{w/2 - rib*0.3:.0f}px;transform:rotate(16deg);transform-origin:left center}}
.k{{position:absolute;border-radius:26px;background:{KEY};color:{INK};display:flex;align-items:center;
   justify-content:center;font-family:{FONT};font-weight:500;box-shadow:0 6px 0 #0c0c0e;opacity:.9}}
</style></head><body>
{keys}
<div class="bow bl"></div><div class="bow br"></div>
<div class="box"><div class="v"></div><div class="hz"></div></div>
</body></html>"""


def render(html, w, h, out):
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="clipkb-event-"))
    src = tmp / "a.html"
    src.write_text(html)
    for _ in range(5):
        p = subprocess.Popen([CHROME, "--headless=new", f"--screenshot={out}",
                              f"--user-data-dir={tempfile.mkdtemp(prefix='clipkb-chrome-')}",
                              "--hide-scrollbars", "--force-device-scale-factor=2",
                              f"--window-size={w},{h}", src.as_uri()],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        t = time.time()
        while p.poll() is None and time.time() - t < 120:
            if out.exists() and out.stat().st_size > 0:
                time.sleep(1); break
            time.sleep(0.5)
        if p.poll() is None:
            p.kill()
        if out.exists() and out.stat().st_size > 0:
            return
    raise SystemExit(f"Chrome 이 {out.name} 을 못 그렸다")


if __name__ == "__main__":
    for name, fn in (("typing-23", typing_html), ("holiday-gift", gift_html)):
        for kind, (w, h) in (("card", (1920, 1080)), ("detail", (1080, 1920))):
            out = HERE / f"{name}-{kind}.png"
            out.unlink(missing_ok=True)
            render(fn(w, h), w, h, out)
            print(out.name)
