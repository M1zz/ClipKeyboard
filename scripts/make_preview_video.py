#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""앱 미리보기 영상: 녹화 원본에 자막과 끝 화면을 입혀 제출 규격(886x1920, 15~30초)으로 만든다.

사용법: python3 scripts/make_preview_video.py <언어>
  원본  docs/screenshots/raw/video/<언어>.mov   (scripts/take_demo_video.sh 가 녹화한다)
  결과  docs/screenshots/preview/<스토어 로케일>/app-preview.mp4

앱은 `-ScreenshotScene demo` 로 켜지면 정해 둔 시각에 스스로 움직인다
(InAppKeyboardStage.runScreenshotScene). 그래서 자막을 **장면이 바뀌는 시각에 맞춰** 놓을 수 있다.
녹화본에서 모르는 것은 앱이 화면에 뜬 시각 하나뿐이라, 그것만 그림으로 찾는다.

자막은 ffmpeg 의 drawtext 로 쓰지 않는다. 태국어처럼 글자를 조합하는 언어가 깨진다.
스크린샷 헤드라인과 같은 길(HTML, 헤드리스 Chrome)로 그려 투명 PNG 로 얹는다.
"""
import pathlib, subprocess, sys, tempfile

import numpy as np
from PIL import Image

LANG = sys.argv[1] if len(sys.argv) > 1 else "ko"
STORE = {"en": "en-US", "es": "es-MX", "de": "de-DE", "fr": "fr-FR"}.get(LANG, LANG)
ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "docs" / "screenshots" / "raw" / "video" / f"{LANG}.mov"
OUT = ROOT / "docs" / "screenshots" / "preview" / STORE / "app-preview.mp4"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 886, 1920

# 앱이 화면에 뜬 뒤 첫 동작까지(초). InAppKeyboardStage.runScreenshotScene 의 "demo" 와 맞춘다.
FIRST_STEP = 1.5
# 첫 동작 기준 장면 시각: 넣기 0 · 템플릿 3.1 · '최근' 탭 8.5 · 마지막 보내기 11.9
LEAD, TEMPLATE, RECENT, LAST = 0.8, 3.1, 8.5, 11.9
TAIL, END_CARD = 1.5, 2.2

# (작은 머리말, 헤드라인) 셋 + 끝 화면(이름, 한 줄). 기계번역하지 않는다.
# 헤드라인은 그 나라 사람이 검색하는 말을 담는다(docs/marketing/ASO_2026-10.md).
COPY = {
    "ko": [("어디서나 그대로", "자주 쓰는 문구,<br>탭 한 번에"),
           ("템플릿", "빈칸만 바꿔서<br>보내요"),
           ("최근 탭", "복사한 글도<br>키보드에서 바로"),
           ("클립키보드", "상용구 키보드 · 클립보드")],
}

# 자막은 대화 칸의 빈 자리(말풍선 셋 아래, 입력창 위)에 얹는다.
CAPTION_TOP = 0.38


def stage_appears_at(src: pathlib.Path) -> float:
    """앱 화면이 처음 뜬 시각. 머리말 띠가 마지막 장면과 같아지는 첫 순간이다.

    ⚠️ 녹화는 화면이 바뀔 때만 프레임을 쓴다. 장면 전환 검출(scene)은 그래서 잘 안 잡힌다.
       머리말은 시연 내내 변하지 않으므로 마지막 프레임과 견주는 쪽이 확실하다.
    """
    with tempfile.TemporaryDirectory() as d:
        subprocess.run(["ffmpeg", "-v", "error", "-sseof", "-1", "-i", str(src), "-frames:v", "1",
                        "-vf", "scale=220:-1", f"{d}/ref.png"], check=True)
        subprocess.run(["ffmpeg", "-v", "error", "-t", "12", "-i", str(src),
                        "-vf", "fps=20,scale=220:-1", f"{d}/f%04d.png"], check=True)
        ref = np.asarray(Image.open(f"{d}/ref.png").convert("L"), dtype=float)
        h = ref.shape[0]
        band = slice(int(h * 0.035), int(h * 0.13))  # 상태 막대 아래 머리말
        for i, f in enumerate(sorted(pathlib.Path(d).glob("f*.png"))):
            img = np.asarray(Image.open(f).convert("L"), dtype=float)
            if np.abs(img[band] - ref[band]).mean() < 2.0:
                return i / 20.0
    raise SystemExit("앱 화면을 찾지 못했다. 녹화본을 눈으로 확인할 것")


def render(html: str, out: pathlib.Path):
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, encoding="utf-8") as f:
        f.write(html)
    # ⚠️ 가끔 아무것도 안 그리고 끝나거나(종료 코드 2) 멈춘다. 1분씩 세 번까지 한다.
    #    새 프로필(--user-data-dir)을 주면 첫 실행 준비에서 멈추므로 주지 않는다.
    for attempt in range(3):
        try:
            r = subprocess.run([CHROME, "--headless=new", f"--screenshot={out}", f"--window-size={W},{H}",
                                "--hide-scrollbars", "--default-background-color=00000000",
                                "--force-device-scale-factor=1", f"file://{f.name}"],
                               capture_output=True, timeout=60)
        except subprocess.TimeoutExpired:
            continue
        if r.returncode == 0 and out.exists():
            return
    raise SystemExit("Chrome 이 자막을 그리지 못했다")


BASE_CSS = """
html, body { margin:0; width:886px; height:1920px; background:transparent; overflow:hidden;
  font-family:-apple-system, "Apple SD Gothic Neo", "Hiragino Sans", "PingFang SC", "Thonburi", sans-serif; }
"""


def caption_html(eyebrow: str, headline: str) -> str:
    return f"""<html><head><meta charset="utf-8"><style>{BASE_CSS}
.box {{ position:absolute; left:0; right:0; top:{int(H * CAPTION_TOP)}px; text-align:center; padding:0 60px; }}
.eyebrow {{ color:#0a84ff; font-size:34px; font-weight:700; letter-spacing:0.5px; }}
.headline {{ color:#111; font-size:76px; font-weight:800; line-height:1.18; margin-top:18px; letter-spacing:-1px; }}
</style></head><body><div class="box"><div class="eyebrow">{eyebrow}</div>
<div class="headline">{headline}</div></div></body></html>"""


def end_html(name: str, line: str) -> str:
    return f"""<html><head><meta charset="utf-8"><style>{BASE_CSS}
body {{ background:rgba(13,13,14,0.92); }}
.box {{ position:absolute; left:0; right:0; top:760px; text-align:center; padding:0 60px; }}
.name {{ color:#fff; font-size:96px; font-weight:800; letter-spacing:-1px; }}
.line {{ color:#9a9aa0; font-size:40px; font-weight:600; margin-top:30px; }}
</style></head><body><div class="box"><div class="name">{name}</div>
<div class="line">{line}</div></div></body></html>"""


def main():
    if LANG not in COPY:
        raise SystemExit(f"모르는 언어: {LANG} (아는 것: {', '.join(COPY)})")
    if not SRC.exists():
        raise SystemExit(f"원본이 없다: {SRC} (sh scripts/take_demo_video.sh <UDID> {LANG})")
    t0 = stage_appears_at(SRC) + FIRST_STEP
    start = t0 - LEAD
    clip = LEAD + LAST + TAIL                      # 원본에서 쓰는 길이
    total = clip + END_CARD
    # 자막 구간(결과 영상 시각)
    spans = [(0.0, LEAD + TEMPLATE), (LEAD + TEMPLATE, LEAD + RECENT), (LEAD + RECENT, clip)]
    print(f"🎬 [{LANG}] 앱이 뜬 시각 {t0 - FIRST_STEP:.2f}s · 결과 {total:.1f}s")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as d:
        d = pathlib.Path(d)
        caps = COPY[LANG]
        for i, (eyebrow, headline) in enumerate(caps[:3]):
            render(caption_html(eyebrow, headline), d / f"c{i}.png")
        render(end_html(*caps[3]), d / "end.png")

        inputs = ["-ss", f"{start:.3f}", "-t", f"{clip:.3f}", "-i", str(SRC)]
        fc = [f"[0:v]crop=1320:2860:0:4,scale={W}:{H},fps=30,"
              f"tpad=stop_mode=clone:stop_duration={END_CARD}[v0]"]
        last = "v0"
        overlays = [(d / f"c{i}.png", a, b) for i, (a, b) in enumerate(spans)] + [(d / "end.png", clip, total)]
        for n, (png, a, b) in enumerate(overlays, start=1):
            inputs += ["-loop", "1", "-t", f"{total:.3f}", "-i", str(png)]
            # 첫 자막은 첫 프레임부터 또렷해야 한다. 자동 재생이 꺼진 기기는 이 장면만 본다
            fade_in = "" if a == 0 else f"fade=t=in:st={a:.3f}:d=0.3:alpha=1,"
            fade_out = f",fade=t=out:st={b - 0.25:.3f}:d=0.25:alpha=1" if b < total else ""
            fc.append(f"[{n}:v]format=rgba,{fade_in}null{fade_out}[o{n}]")
            fc.append(f"[{last}][o{n}]overlay=0:0:shortest=0[v{n}]")
            last = f"v{n}"
        # ⚠️ App Store Connect 는 색 공간 태그가 sRGB 면 "손상된 파일" 로 돌려보낸다(5.1.2).
        fc.append(f"[{last}]format=yuv420p,setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709[out]")
        n_audio = len(overlays) + 1
        cmd = (["ffmpeg", "-v", "error", "-y"] + inputs +
               ["-f", "lavfi", "-t", f"{total:.3f}", "-i", "anullsrc=r=44100:cl=stereo",
                "-filter_complex", ";".join(fc), "-map", "[out]", "-map", f"{n_audio}:a",
                "-t", f"{total:.3f}", "-c:v", "libx264", "-profile:v", "high", "-crf", "18",
                "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
                "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", str(OUT)])
        subprocess.run(cmd, check=True)
    print(f"✅ {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
