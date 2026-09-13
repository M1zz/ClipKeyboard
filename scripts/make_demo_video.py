# -*- coding: utf-8 -*-
"""녹화본에서 멈춰 있는 구간을 잘라 앱 미리보기 규격(886x1920)으로 만든다.

MCP 왕복 지연 때문에 실제 녹화는 90초쯤 늘어진다. 앱스토어 미리보기는 15~30초다.
정지 구간을 찾아 각 `HOLD` 초만 남기고 이어 붙인다.
"""
import subprocess, sys, re, pathlib

src = pathlib.Path(sys.argv[1]); out = pathlib.Path(sys.argv[2])
TARGET = float(sys.argv[3]) if len(sys.argv) > 3 else 20.0  # 앱스토어 미리보기는 15~30초
MINFREEZE = 0.9

p = subprocess.run(["ffmpeg", "-i", str(src), "-vf", f"freezedetect=n=0.003:d={MINFREEZE}",
                    "-map", "0:v", "-f", "null", "-"], capture_output=True, text=True)
ev = re.findall(r"freeze_(start|end|duration):\s*([0-9.]+)", p.stderr)
dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                            "-of", "csv=p=0", str(src)], capture_output=True, text=True).stdout)

freezes, cur = [], None
for kind, val in ev:
    if kind == "start": cur = float(val)
    elif kind == "end" and cur is not None:
        freezes.append((cur, float(val))); cur = None
if cur is not None: freezes.append((cur, dur))

# ⚠️ ffmpeg 가 겹치는 구간을 뱉을 때가 있다(맨 앞의 freeze_start: 0 이 뒤의 것들을 감싼다).
#    겹친 채로 두면 뒤쪽 구간이 통째로 "움직이는 동안" 으로 남아 영상이 배로 길어진다.
freezes.sort()
merged = []
for s, e in freezes:
    if merged and s <= merged[-1][1]:
        merged[-1] = (merged[-1][0], max(merged[-1][1], e))
    else:
        merged.append((s, e))
freezes = merged

# 정지 구간을 몇 초씩 남길지는 결과 길이로 거꾸로 정한다. 손으로 맞추면 언어마다 어긋난다.
active = sum(b - a for a, b in
             [(0.0, freezes[0][0])] +
             [(freezes[i][1], freezes[i + 1][0]) for i in range(len(freezes) - 1)] +
             [(freezes[-1][1], dur)]) if freezes else dur
HOLD = max(0.8, min(4.5, (TARGET - active) / max(1, len(freezes))))

# 유지 구간: 움직이는 동안 전부 + 정지 시작 HOLD 초
keep, t = [], 0.0
for s, e in freezes:
    if s > t: keep.append((t, s))
    keep.append((s, min(s + HOLD, e)))
    t = e
if t < dur: keep.append((t, dur))
keep = [(a, b) for a, b in keep if b - a > 0.08]

parts = "".join(f"[0:v]trim={a:.3f}:{b:.3f},setpts=PTS-STARTPTS[v{i}];"
                for i, (a, b) in enumerate(keep))
chain = "".join(f"[v{i}]" for i in range(len(keep)))
# ⚠️ 1320x2868 원본의 위아래 4px 은 잘라 낸다. 886x1920 과 종횡비가 딱 맞지 않는다.
fc = (parts + f"{chain}concat=n={len(keep)}:v=1:a=0,"
      "crop=1320:2860:0:4,scale=886:1920,fps=30[out]")
subprocess.run(["ffmpeg", "-y", "-i", str(src), "-filter_complex", fc, "-map", "[out]",
                "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20",
                "-movflags", "+faststart", str(out)], check=True, capture_output=True)
got = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                            "-of", "csv=p=0", str(out)], capture_output=True, text=True).stdout)
print(f"{out.name}: {dur:.1f}s → {got:.1f}s (정지 {len(freezes)}구간 x {HOLD:.1f}s, 이은 조각 {len(keep)}개)")
