#!/usr/bin/env python3
"""
App Store 스크린샷 자동 생성기 (ClipKeyboard)

원본 앱 화면을 아이폰 목업 프레임에 끼워넣고, 위에 마케팅 문구를 얹어
깔끔한 App Store 제출용 이미지를 만든다.

핵심 아이디어
- 목업의 "화면 영역"을 중앙에서 flood-fill 로 자동 검출한다.
  → 둥근 모서리 / 노치 컷아웃이 마스크에 그대로 반영되므로 좌표 하드코딩이 필요 없다.
  → 어떤 아이폰 목업 PNG 든 동일하게 동작한다.
- 스크린샷을 프레임 "뒤"에 깔고, 목업 프레임(베젤·노치·버튼)을 "위"에 얹는다.

사용법
    python3 make_shot.py                # marketing/shots.json (있으면) 배치 생성, 없으면 데모 1장
    python3 make_shot.py --config shots.json

의존성: Pillow, numpy (둘 다 시스템에 설치되어 있음)
"""

from __future__ import annotations
import argparse
import json
import os
import sys
from dataclasses import dataclass, field
from typing import Optional

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))

# ─────────────────────────────────────────────────────────────────────────────
# 폰트 (Pretendard: 한글+영문 지원, ~/Library/Fonts 에 설치됨)
# ─────────────────────────────────────────────────────────────────────────────
FONT_DIR = os.path.expanduser("~/Library/Fonts")
FONT_BOLD = os.path.join(FONT_DIR, "Pretendard-Bold.otf")
FONT_SEMIBOLD = os.path.join(FONT_DIR, "Pretendard-SemiBold.otf")
# 폴백 (Pretendard 가 없을 때)
FONT_FALLBACK = "/System/Library/Fonts/AppleSDGothicNeo.ttc"


def load_font(path: str, size: int) -> ImageFont.FreeTypeFont:
    for p in (path, FONT_FALLBACK):
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            continue
    return ImageFont.load_default()


# ─────────────────────────────────────────────────────────────────────────────
# 목업 화면 영역 검출 + 프레이밍
# ─────────────────────────────────────────────────────────────────────────────
def _light_mask(rgba: np.ndarray) -> np.ndarray:
    """프레임(어두운 폰 바디)이 아닌 밝은/투명 픽셀 = True."""
    r, g, b, a = rgba[..., 0], rgba[..., 1], rgba[..., 2], rgba[..., 3]
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    # 밝거나(화면·배경 흰색) 투명한(배경) 픽셀
    return (lum > 140) | (a < 40)


def _screen_mask(light: np.ndarray) -> np.ndarray:
    """프레임에 '갇힌' 밝은/투명 영역(=화면)만 True 로 반환.

    화면과 바깥 배경이 둘 다 흰색이거나 둘 다 투명일 수 있으므로 밝기로는 구분되지
    않는다. 대신 이미지 테두리에서 flood-fill 해 '바깥 배경'을 찾고, 밝은 영역 중
    바깥 배경에 속하지 않는 = 프레임에 갇힌 영역을 화면으로 본다. 노치·둥근 모서리는
    프레임(어두움)이라 자연히 마스크에서 빠진다.

    주의: Image.fromarray 는 읽기전용 numpy 버퍼를 공유할 수 있어 floodfill in-place
    쓰기가 무시된다 → 반드시 .copy() 로 쓰기 가능한 이미지를 만든다.
    """
    base = Image.fromarray(np.where(light, 255, 0).astype("uint8")).copy()
    ImageDraw.floodfill(base, (0, 0), 100, thresh=0)   # (0,0) = 바깥 배경 시드
    exterior = np.array(base) == 100
    return light & ~exterior


def _bbox(mask: np.ndarray):
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def _cover_resize(img: Image.Image, tw: int, th: int) -> Image.Image:
    """대상 크기를 '덮도록' 비율 유지 리사이즈 후 중앙 크롭."""
    sw, sh = img.size
    scale = max(tw / sw, th / sh)
    nw, nh = round(sw * scale), round(sh * scale)
    img = img.resize((nw, nh), Image.LANCZOS)
    left, top = (nw - tw) // 2, (nh - th) // 2
    return img.crop((left, top, left + tw, top + th))


def build_framed_phone(mockup_path: str, screenshot_path: str) -> Image.Image:
    """스크린샷을 목업에 끼운, 폰 크기로 타이트하게 크롭된 RGBA 이미지를 반환."""
    mockup = Image.open(mockup_path).convert("RGBA")
    arr = np.array(mockup)
    light = _light_mask(arr)

    screen = _screen_mask(light)
    sbox = _bbox(screen)
    if sbox is None:
        raise RuntimeError(f"화면 영역을 찾지 못했습니다: {mockup_path}")

    # 스크린샷을 화면 bbox 크기로 cover-fit
    sx0, sy0, sx1, sy1 = sbox
    sw, sh = sx1 - sx0, sy1 - sy0
    shot = Image.open(screenshot_path).convert("RGBA")
    shot_fit = _cover_resize(shot, sw, sh)

    # 화면 마스크를 살짝 팽창시켜 스크린샷이 베젤 아래로 tuck 되게 (흰 테두리 방지)
    screen_img = Image.fromarray(np.where(screen, 255, 0).astype("uint8"), "L")
    screen_dil = screen_img.filter(ImageFilter.MaxFilter(9))

    # 1) 스크린샷 레이어 (전체 목업 크기, 화면 위치에 배치)
    shot_layer = Image.new("RGBA", mockup.size, (0, 0, 0, 0))
    shot_layer.paste(shot_fit, (sx0, sy0))
    shot_layer.putalpha(screen_dil)

    # 2) 프레임 오버레이 = 목업에서 (화면+바깥배경) 을 투명 처리 → 폰 바디만 남김
    background = light & ~screen                      # 바깥쪽 밝은 배경
    frame_alpha = np.array(mockup)[..., 3].copy()
    frame_alpha[background] = 0
    frame_alpha[screen] = 0                           # 화면부는 스크린샷 레이어가 담당
    frame_overlay = mockup.copy()
    frame_overlay.putalpha(Image.fromarray(frame_alpha, "L"))

    # 3) 합성: 스크린샷 → 프레임
    out = Image.new("RGBA", mockup.size, (0, 0, 0, 0))
    out = Image.alpha_composite(out, shot_layer)
    out = Image.alpha_composite(out, frame_overlay)

    # 폰 바디 기준으로 타이트 크롭
    body = np.array(mockup)[..., 3] > 10
    if (np.array(mockup)[..., 3] > 250).all():
        # 목업 배경이 불투명(흰색)인 경우: 밝은 배경을 제외한 영역으로 크롭
        body = ~background
    fbox = _bbox(body)
    return out.crop(fbox)


def build_clean_phone(screenshot_path: str, width: int = 1000,
                      bezel_color: str = "#0B0B0D",
                      screen_radius_ratio: float = 0.135,
                      bezel_ratio: float = 0.028) -> Image.Image:
    """스톡 목업 없이 코드로 그린 깔끔한 디바이스 프레임에 스크린샷을 끼운다.

    워터마크가 없고 임의 해상도로 선명하며, 모서리 반경을 앱 화면에 맞춰 클리핑이
    생기지 않는다. 스크린샷에 이미 iOS 상태바(다이나믹 아일랜드)가 포함돼 있으므로
    아일랜드는 별도로 그리지 않는다.
    아이패드는 screen_radius_ratio(≈0.045)·bezel_ratio(≈0.02)를 줄여 iPad 베젤 비율로.
    """
    ss = 2  # supersampling (안티에일리어싱)
    shot = Image.open(screenshot_path).convert("RGBA")
    aspect = shot.height / shot.width

    inner_w = width * ss
    inner_h = round(inner_w * aspect)
    bezel = round(inner_w * bezel_ratio)
    inner_r = round(inner_w * screen_radius_ratio)   # 화면 모서리 반경
    outer_w, outer_h = inner_w + 2 * bezel, inner_h + 2 * bezel
    outer_r = inner_r + bezel

    # 화면(둥근 모서리)
    shot_r = shot.resize((inner_w, inner_h), Image.LANCZOS)
    inner_mask = Image.new("L", (inner_w, inner_h), 0)
    ImageDraw.Draw(inner_mask).rounded_rectangle(
        [0, 0, inner_w - 1, inner_h - 1], radius=inner_r, fill=255)

    # 베젤(둥근 검정 바디)
    phone = Image.new("RGBA", (outer_w, outer_h), (0, 0, 0, 0))
    body_mask = Image.new("L", (outer_w, outer_h), 0)
    ImageDraw.Draw(body_mask).rounded_rectangle(
        [0, 0, outer_w - 1, outer_h - 1], radius=outer_r, fill=255)
    body = Image.new("RGBA", (outer_w, outer_h), bezel_color)
    body.putalpha(body_mask)
    phone = Image.alpha_composite(phone, body)

    # 화면 합성
    phone.paste(shot_r, (bezel, bezel), inner_mask)

    # 다운샘플
    return phone.resize((outer_w // ss, outer_h // ss), Image.LANCZOS)


# ─────────────────────────────────────────────────────────────────────────────
# 배경 / 텍스트
# ─────────────────────────────────────────────────────────────────────────────
def make_background(w: int, h: int, top: str, bottom: str) -> Image.Image:
    """세로 그라디언트 배경."""
    t = np.array(Image.new("RGB", (1, 1), top))[0, 0].astype(float)
    b = np.array(Image.new("RGB", (1, 1), bottom))[0, 0].astype(float)
    ramp = np.linspace(0, 1, h)[:, None]
    col = (t[None, :] * (1 - ramp) + b[None, :] * ramp).astype("uint8")  # (h,3)
    grad = np.repeat(col[:, None, :], w, axis=1)
    return Image.fromarray(grad, "RGB")


def _wrap(draw, text: str, font, max_w: int):
    """공백 기준 워드랩 + 명시적 개행(\n) 지원."""
    lines = []
    for para in text.split("\n"):
        if para == "":
            lines.append("")
            continue
        words, cur = para.split(" "), ""
        for wd in words:
            trial = wd if not cur else cur + " " + wd
            if draw.textlength(trial, font=font) <= max_w or not cur:
                cur = trial
            else:
                lines.append(cur)
                cur = wd
        if cur:
            lines.append(cur)
    return lines


def draw_text_block(canvas: Image.Image, spec: "Shot", top_y: int) -> None:
    draw = ImageDraw.Draw(canvas)
    W = canvas.width
    margin = int(W * 0.09)
    max_w = W - 2 * margin
    y = top_y

    if spec.eyebrow:
        f = load_font(FONT_SEMIBOLD, spec.eyebrow_size)
        for line in _wrap(draw, spec.eyebrow, f, max_w):
            tw = draw.textlength(line, font=f)
            draw.text(((W - tw) / 2, y), line, font=f, fill=spec.accent)
            y += int(spec.eyebrow_size * 1.35)
        y += int(spec.eyebrow_size * 0.55)

    if spec.title:
        f = load_font(FONT_BOLD, spec.title_size)
        asc, desc = f.getmetrics()
        lh = int(spec.title_size * 1.18)
        for line in _wrap(draw, spec.title, f, max_w):
            tw = draw.textlength(line, font=f)
            draw.text(((W - tw) / 2, y), line, font=f, fill=spec.title_color)
            y += lh


# ─────────────────────────────────────────────────────────────────────────────
# Spec / 렌더
# ─────────────────────────────────────────────────────────────────────────────
@dataclass
class Shot:
    screenshot: str
    out: str
    mockup: str = os.path.join(HERE, "mockup.png")
    title: str = ""
    eyebrow: str = ""
    size: tuple = (1290, 2796)          # 6.9" App Store 기본
    bg_top: str = "#16181D"
    bg_bottom: str = "#0E0F12"
    accent: str = "#4FACFE"
    title_color: str = "#FFFFFF"
    title_size: int = 104
    eyebrow_size: int = 50
    phone_scale: float = 0.86           # 캔버스 폭 대비 폰 폭
    text_top: float = 0.055             # 캔버스 높이 대비 텍스트 시작 y
    phone_top: float = 0.30             # 캔버스 높이 대비 폰 상단 y
    frame_style: str = "clean"          # "clean"(코드 프레임) | "mockup"(PNG 목업)
    bezel_color: str = "#0B0B0D"
    # 디자인 다양화 옵션
    phone_rotate: float = 0.0           # 폰 기울기(도, +는 시계방향)
    phone_x: float = 0.5                # 폰 중심의 가로 위치(캔버스 폭 대비 0~1)
    screen_radius_ratio: float = 0.135  # 화면 모서리 반경 비율 (아이패드 ≈0.045)
    bezel_ratio: float = 0.028          # 베젤 두께 비율 (아이패드 ≈0.02)

    def resolve(self, base_dir: str):
        for k in ("screenshot", "mockup", "out"):
            v = getattr(self, k)
            if not os.path.isabs(v):
                setattr(self, k, os.path.join(base_dir, v))
        return self


def render(spec: Shot) -> str:
    W, H = spec.size
    canvas = make_background(W, H, spec.bg_top, spec.bg_bottom).convert("RGBA")

    # 텍스트 (상단)
    draw_text_block(canvas, spec, int(H * spec.text_top))

    # 폰 (하단)
    if spec.frame_style == "mockup":
        phone = build_framed_phone(spec.mockup, spec.screenshot)
    else:
        phone = build_clean_phone(spec.screenshot, bezel_color=spec.bezel_color,
                                  screen_radius_ratio=spec.screen_radius_ratio,
                                  bezel_ratio=spec.bezel_ratio)
    target_w = int(W * spec.phone_scale)
    scale = target_w / phone.width
    phone = phone.resize((target_w, int(phone.height * scale)), Image.LANCZOS)

    # 기울기 - 컷마다 다른 표정. expand=True 로 잘림 없이 회전.
    if spec.phone_rotate:
        phone = phone.rotate(-spec.phone_rotate, expand=True,
                             resample=Image.BICUBIC)

    # 은은한 그림자
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sh_alpha = phone.split()[3].point(lambda a: int(a * 0.45))
    px = int(W * spec.phone_x - phone.width / 2)
    py = int(H * spec.phone_top)
    shd = Image.new("RGBA", phone.size, (0, 0, 0, 255))
    shd.putalpha(sh_alpha)
    shadow.paste(shd, (px, py + 26), shd)
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    canvas = Image.alpha_composite(canvas, shadow)

    # 폰 합성
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer.paste(phone, (px, py), phone)
    canvas = Image.alpha_composite(canvas, layer)

    os.makedirs(os.path.dirname(spec.out), exist_ok=True)
    canvas.convert("RGB").save(spec.out, "PNG")
    return spec.out


# ─────────────────────────────────────────────────────────────────────────────
# main
# ─────────────────────────────────────────────────────────────────────────────
DEMO = Shot(
    screenshot=os.path.join(HERE, "raw/screen1.png"),
    out=os.path.join(HERE, "out/01.png"),
    mockup=os.path.join(HERE, "mockup.png"),
    eyebrow="키보드에서 바로 꺼내 쓰는",
    title="자주 쓰는 문장,\n한 번의 탭으로",
)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default=os.path.join(HERE, "shots.json"))
    args = ap.parse_args()

    specs = []
    if os.path.exists(args.config):
        with open(args.config, encoding="utf-8") as f:
            data = json.load(f)
        defaults = data.get("defaults", {})
        for item in data["shots"]:
            merged = {**defaults, **item}
            if "size" in merged and isinstance(merged["size"], list):
                merged["size"] = tuple(merged["size"])
            specs.append(Shot(**merged).resolve(os.path.dirname(os.path.abspath(args.config))))
    else:
        print("ℹ️  shots.json 이 없어 데모 1장을 생성합니다.")
        specs = [DEMO]

    for s in specs:
        out = render(s)
        print(f"✅ {out}")


if __name__ == "__main__":
    main()
