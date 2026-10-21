#!/usr/bin/env python3
"""Product Hunt 갤러리 그림(1270x760)을 만든다.

    python3 marketing/global/producthunt/make_ph_gallery.py

원본은 raw/ 의 시뮬레이터 캡처(DEBUG 빌드의 앱 안 키보드 미리보기, `-ScreenshotScene`)다.
다시 찍는 법은 capture.sh 머리말. 문구는 영어다(Product Hunt 는 영어권).
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
W, H = 1270, 760
BG_TOP, BG_BOTTOM = (14, 17, 24), (24, 31, 44)
ACCENT = (79, 172, 254)
WHITE = (245, 247, 250)
MUTED = (160, 170, 186)
SF = "/System/Library/Fonts/SFNS.ttf"


def font(size, weight="Regular"):
    f = ImageFont.truetype(SF, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def background():
    im = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM)))
    return im


def wrap(d, text, f, width):
    lines = []
    for para in text.split("\n"):
        cur = ""
        for word in para.split(" "):
            test = (cur + " " + word).strip()
            if d.textlength(test, font=f) <= width:
                cur = test
            else:
                lines.append(cur)
                cur = word
        lines.append(cur)
    return lines


def text_block(im, x, y, width, eyebrow, title, sub):
    d = ImageDraw.Draw(im)
    if eyebrow:
        d.text((x, y), eyebrow, font=font(20, "Semibold"), fill=ACCENT)
        y += 44
    ft = font(50, "Bold")
    for line in wrap(d, title, ft, width):
        d.text((x, y), line, font=ft, fill=WHITE)
        y += 60
    y += 18
    fs = font(24)
    for line in wrap(d, sub, fs, width):
        d.text((x, y), line, font=fs, fill=MUTED)
        y += 34
    return y


def phone(shot, height):
    """시뮬레이터 화면을 검은 테두리 폰에 끼운다."""
    scr = Image.open(os.path.join(RAW, shot)).convert("RGB")
    bezel = max(8, height // 70)
    sh = height - 2 * bezel
    sw = round(scr.width * sh / scr.height)
    scr = scr.resize((sw, sh), Image.LANCZOS)
    pw, ph = sw + 2 * bezel, height
    r_out = round(pw * 0.16)
    r_in = r_out - bezel
    body = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle([0, 0, pw - 1, ph - 1], r_out, fill=(8, 8, 10, 255),
                                           outline=(70, 74, 82, 255), width=2)
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw - 1, sh - 1], r_in, fill=255)
    body.paste(scr, (bezel, bezel), mask)
    return body


def paste_with_shadow(im, obj, xy):
    shadow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    sm = Image.new("RGBA", obj.size, (0, 0, 0, 150))
    sm.putalpha(obj.split()[3].point(lambda a: 150 if a else 0))
    shadow.paste(sm, (xy[0], xy[1] + 14), sm)
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    base = im.convert("RGBA")
    base = Image.alpha_composite(base, shadow)
    base.paste(obj, xy, obj)
    return base.convert("RGB")


def phone_slide(out, shot, eyebrow, title, sub):
    im = background()
    text_block(im, 80, 190, 660, eyebrow, title, sub)
    p = phone(shot, 720)
    im = paste_with_shadow(im, p, (W - p.width - 110, 20))
    im.save(os.path.join(HERE, out), optimize=True)
    print(out)


def keyboard_crop(shot):
    """자판 줄만 잘라 낸다. 좌표는 1320px 폭(아이폰 17 Pro Max) 기준. 태국어는 다섯 줄이라 위가 더 높다."""
    im = Image.open(os.path.join(RAW, shot)).convert("RGB")
    s = im.width / 1320
    top = 1760 if "-th" in shot else 1905
    return im.crop((0, round(top * s), im.width, round(2615 * s)))


def languages_slide(out):
    im = background()
    d = ImageDraw.Draw(im)
    d.text((80, 36), "23 LANGUAGES", font=font(20, "Semibold"), fill=ACCENT)
    d.text((80, 70), "Type in your language, on the layout you know", font=font(44, "Bold"), fill=WHITE)
    items = [("typing-en.png", "English"), ("typing-de.png", "German (QWERTZ)"), ("typing-ru.png", "Russian"),
             ("typing-ko.png", "Korean"), ("typing-th.png", "Thai"), ("typing-el.png", "Greek")]
    cw, gap = 350, 30
    x0 = (W - (3 * cw + 2 * gap)) // 2
    crops = []
    for shot, label in items:
        k = keyboard_crop(shot)
        crops.append((k.resize((cw, round(k.height * cw / k.width)), Image.LANCZOS), label))
    row_h = [max(k.height for k, _ in crops[r * 3:r * 3 + 3]) for r in range(2)]
    for i, (k, label) in enumerate(crops):
        mask = Image.new("L", k.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, k.width - 1, k.height - 1], 18, fill=255)
        x = x0 + (i % 3) * (cw + gap)
        r = i // 3
        y = 158 + r * (row_h[0] + 52) + (row_h[r] - k.height)
        d.text((x + 4, y), label, font=font(21, "Semibold"), fill=WHITE)
        im.paste(k, (x, y + 34), mask)
    note = ("Your saved snippets are one tap away on the same keyboard. "
            "Japanese and Chinese type kana, Pinyin and Zhuyin for now; kanji conversion is on the roadmap.")
    y = 696
    for line in wrap(d, note, font(19), W - 160):
        d.text((80, y), line, font=font(19), fill=MUTED)
        y += 26
    im.save(os.path.join(HERE, out), optimize=True)
    print(out)


if __name__ == "__main__":
    phone_slide("01-one-keyboard.png", "typing-en.png", "NEW IN 5.1.13",
                "One keyboard for typing and for everything you retype",
                "iPhone-style layouts in 23 languages, with your saved snippets on the same keyboard. "
                "No more switching back and forth.")
    languages_slide("02-23-languages.png")
    phone_slide("03-one-tap-reply.png", "snippets-reply.png", "SNIPPETS & TEMPLATES",
                "Answer the same question in one tap",
                "Templates fill in the parts that change, like the customer's name. "
                "Account numbers, addresses and replies go in exactly as you saved them.")
    phone_slide("04-recent-copies.png", "snippets-recent.png", "SMART CLIPBOARD",
                "What you copied is waiting on the keyboard",
                "Tracking numbers, addresses and codes are sorted by type, so you find them in a second. "
                "No third-party analytics SDK.")
