#!/usr/bin/env python3
"""마케팅 스크린샷 목업 생성: HTML 생성 → 헤드리스 Chrome 렌더링.

슬라이드마다 layout 이 달라 배치가 다양함:
  hero-bleed  : 헤드라인 상단 중앙 + 정면 대형 폰, 하단 블리드
  left-text   : 좌측 정렬 텍스트 + 오른쪽으로 기운 폰
  text-bottom : 폰 상단 + 텍스트 하단
  flat-rotate : 평면 회전(-5°) 폰, 하단 블리드
  dark        : 다크 배경 반전 + 정면 폰
"""
import subprocess, sys, pathlib, tempfile

# 사용법: python3 scripts/make_marketing_screenshots.py <언어> [iphone|ipad] [파일 하나만]
#
# 자리는 DeployBar 와의 계약이다(docs/screenshots/README.md):
#   docs/screenshots/raw/<기기>/<언어>/01-....png   원본 캡처 (올라가지 않는다)
#   docs/screenshots/marketing/<스토어 로케일>/      제출본. 아이폰 · 아이패드가 한 폴더에 있고 픽셀로 기기를 가른다
LANG = (sys.argv[1] if len(sys.argv) > 1 else "en")
DEVICE = (sys.argv[2] if len(sys.argv) > 2 else "iphone")
# 앱 언어 코드 → App Store Connect 로케일
STORE = {"en": "en-US", "es": "es-MX", "de": "de-DE"}.get(LANG, LANG)
ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "docs" / "screenshots" / "raw" / DEVICE / LANG
OUT = ROOT / "docs" / "screenshots" / "marketing" / STORE
WORK = pathlib.Path(__file__).parent
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
# ⚠️ 이 앱의 App Store Connect 제출 규격은 아이폰 **1242x2688**, 아이패드 **2064x2752** 다.
#    시뮬레이터 원본(1320x2868 · 2064x2752)은 raw 이고, 여기서 바로 제출 규격으로 그린다.
W, H = (2064, 2752) if DEVICE == "ipad" else (1242, 2688)
PREFIX = "ipad-" if DEVICE == "ipad" else ""

# 슬라이드 배치는 언어와 무관하게 같고, 글만 언어별로 고른다.
# ⚠️ 기계번역하지 않는다. 각 언어권에서 자연스럽게 읽히는 말로 따로 쓴다.
LAYOUT_ORDER = [
    ("01-keyboard-in-messages.png", "hero-bleed"),
    ("02-template-fill.png",        "left-text"),
    ("03-snippet-stack.png",        "text-bottom"),
    ("04-keyboard-size.png",        "flat-rotate"),
    ("05-all-snippets.png",         "dark"),
]

COPY = {
    "ko": [
        ("어디서나 그대로",   "한 번 누르면<br>알아서 입력돼요",   "자주 쓰는 말이 키보드 위에 있어요"),
        ("템플릿",           "빈칸만 채우고<br>보내세요",        "한 줄로 써 두고, 이름만 매번 바꿔요"),
        ("단축어 스택",       "값 여러 개를<br>키 하나에",        "칸마다 이름이 있어 다음이 무엇인지 알아요"),
        ("내 손에 맞게",      "원하는<br>높이로",                "기본 키보드와 같게, 아니면 더 넉넉하게"),
        ("한곳에 모아서",     "또 쓸 말은<br>전부 여기에",        "갈래로 묶고 찾아 써요. 폰 밖으로 나가지 않아요"),
    ],
    "en": [
        ("Works in every app", "Tap once,<br>it types itself",  "Your snippets sit right on the keyboard"),
        ("Templates",          "Fill the blank,<br>send it",    "One line, a different name every time"),
        ("Snippet stacks",     "Several values,<br>one key",    "Every slot has a name, so you know what is next"),
        ("Made to fit",        "The height<br>you want",        "Match your system keyboard, or give it more room"),
        ("All in one place",   "Everything you<br>type again",  "Grouped, searchable, and never leaves your phone"),
    ],
    "zh-Hans": [
        ("在哪个应用都能用", "点一下，<br>它自己输入",   "常用的短语就在键盘上"),
        ("模板",           "填好空格，<br>直接发送",   "写一次，每次只换名字"),
        ("短语堆",         "多个值，<br>一个键",       "每一格都有名字，知道下一个是什么"),
        ("合你的手",        "高度<br>由你定",          "和系统键盘一样高，或者更宽松"),
        ("全都放在一处",    "要反复打的，<br>都在这里", "分组、可搜索，也不会离开你的手机"),
    ],
    "zh-Hant": [
        ("在哪個 App 都能用", "點一下，<br>它自己輸入",   "常用的短語就在鍵盤上"),
        ("範本",             "填好空格，<br>直接送出",   "寫一次，每次只換名字"),
        ("短語堆",           "多個值，<br>一個鍵",       "每一格都有名字，知道下一個是什麼"),
        ("合你的手",          "高度<br>由你決定",        "和系統鍵盤一樣高，或者更寬鬆"),
        ("全都放在一處",      "要反覆打的，<br>都在這裡", "分組、可搜尋，也不會離開你的手機"),
    ],
    "ru": [
        ("Работает везде",    "Одно нажатие,<br>и текст готов", "Ваши фразы прямо на клавиатуре"),
        ("Шаблоны",           "Заполните<br>и отправьте",       "Одна строка, каждый раз новое имя"),
        ("Стопки фраз",       "Много значений,<br>одна клавиша","У каждой ячейки есть имя, и вы знаете, что дальше"),
        ("Под вашу руку",     "Высота,<br>какая нужна",         "Как системная клавиатура или просторнее"),
        ("Всё в одном месте", "Всё, что вы<br>печатаете снова", "По группам, с поиском. Телефон не покидает"),
    ],
    "ja": [
        ("どのアプリでも",   "ワンタップで<br>そのまま入力",     "よく使う言葉がキーボードの上に"),
        ("テンプレート",     "空欄を埋めて<br>送るだけ",         "一度書いておけば、名前だけ毎回変えられます"),
        ("スタック",         "いくつもの値を<br>ひとつのキーに", "欄ごとに名前があるので、次が何かわかります"),
        ("手になじむ",       "好きな<br>高さに",                "標準キーボードと同じ高さにも、もっと広くも"),
        ("ひとつの場所に",   "また使う言葉は<br>すべてここに",   "グループ分けして検索。端末の外には出ません"),
    ],
    "es": [
        ("En cualquier app", "Un toque<br>y se escribe solo",   "Tus frases, justo en el teclado"),
        ("Plantillas",       "Llena el campo<br>y envía",        "Una línea, un nombre distinto cada vez"),
        ("Pilas",            "Varios valores,<br>una tecla",     "Cada campo tiene nombre: sabes qué sigue"),
        ("A tu medida",      "La altura<br>que quieras",         "Igual que el teclado del sistema, o más amplio"),
        ("Todo en un lugar", "Lo que vuelves<br>a escribir",     "Por grupos y con búsqueda. No sale de tu dispositivo"),
    ],
    "de": [
        ("In jeder App",       "Einmal tippen,<br>fertig",          "Deine Textbausteine direkt auf der Tastatur"),
        ("Vorlagen",           "Lücke füllen,<br>abschicken",       "Einmal schreiben, jedes Mal ein anderer Name"),
        ("Stapel",             "Viele Werte,<br>eine Taste",        "Jedes Feld hat einen Namen. Du weißt, was kommt"),
        ("Passt zu dir",       "Die Höhe,<br>die du willst",        "Wie die Systemtastatur oder mit mehr Platz"),
        ("Alles an einem Ort", "Was du öfter<br>tippst",            "Sortiert, durchsuchbar, bleibt auf deinem Gerät"),
    ],
    "th": [
        ("ใช้ได้ทุกแอป",     "แตะครั้งเดียว<br>พิมพ์ให้เลย",      "ข้อความที่ใช้บ่อยอยู่บนคีย์บอร์ด"),
        ("เทมเพลต",          "กรอกช่องว่าง<br>แล้วส่ง",            "เขียนครั้งเดียว เปลี่ยนแค่ชื่อทุกครั้ง"),
        ("สแตก",             "หลายค่า<br>ในปุ่มเดียว",             "ทุกช่องมีชื่อ รู้ว่าถัดไปคืออะไร"),
        ("พอดีมือคุณ",        "ความสูง<br>ตามที่ชอบ",              "เท่าคีย์บอร์ดระบบ หรือกว้างกว่านั้น"),
        ("รวมไว้ที่เดียว",     "ข้อความที่ใช้ซ้ำ<br>อยู่ที่นี่",       "จัดกลุ่ม ค้นหาได้ และไม่ออกไปจากเครื่อง"),
    ],
    "vi": [
        ("Mọi ứng dụng",     "Chạm một lần,<br>tự gõ xong",      "Cụm từ hay dùng nằm ngay trên bàn phím"),
        ("Mẫu",              "Điền ô trống<br>rồi gửi",          "Viết một lần, mỗi lần chỉ đổi tên"),
        ("Ngăn xếp",         "Nhiều giá trị,<br>một phím",       "Mỗi ô đều có tên, biết ngay tiếp theo là gì"),
        ("Vừa tay bạn",      "Chiều cao<br>tùy ý",               "Bằng bàn phím hệ thống, hoặc rộng hơn"),
        ("Tất cả một chỗ",   "Những gì bạn<br>gõ lại",           "Chia nhóm, tìm nhanh, không rời khỏi máy"),
    ],
}

# 키릴·한글은 같은 글자 수라도 더 넓게 퍼진다. 언어마다 글자 크기를 조금 줄인다.
TYPE_SCALE = {"ru": (84, 40), "ko": (92, 44), "zh-Hans": (96, 46), "zh-Hant": (96, 46), "en": (96, 46),
              "ja": (88, 42), "es": (88, 42), "de": (84, 40), "th": (88, 42), "vi": (88, 42)}

if LANG not in COPY:
    raise SystemExit(f"모르는 언어: {LANG} (아는 것: {', '.join(COPY)})")
SHOTS = [(f, l, e, h, s) for (f, l), (e, h, s) in zip(LAYOUT_ORDER, COPY[LANG])]
HEAD_PX, SUB_PX = TYPE_SCALE[LANG]
if DEVICE == "ipad":
    # 캔버스가 아이폰보다 1.66배 넓다. 글은 1.3배만 키운다(더 키우면 헤드라인이 판을 가린다).
    HEAD_PX, SUB_PX = int(HEAD_PX * 1.3), int(SUB_PX * 1.3)

BASE_CSS = f"""
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:{W}px; height:{H}px; overflow:hidden; }}
/* ⚠️ 이 앱의 기존 마케팅 이미지가 어두운 바탕이다. 밝게 바꾸면 스토어 페이지에서
   이 판만 남의 앱처럼 보인다. 바탕·글자색은 여기서만 정한다. */
body {{ background:#0d0d0e; font-family:-apple-system, "Apple SD Gothic Neo", sans-serif; position:relative; }}
.eyebrow {{ font-size:44px; font-weight:700; color:#0A84FF; letter-spacing:-0.5px; }}
.headline {{ font-size:{HEAD_PX}px; font-weight:800; color:#f2f2f4; letter-spacing:-2px; line-height:1.22; }}
.sub {{ font-size:{SUB_PX}px; font-weight:500; color:#8e8e95; letter-spacing:-1px; line-height:1.4; }}
.phone {{ background:#17171a; border-radius:104px; border:3px solid #3a3a3e; padding:22px;
  box-shadow: 50px 80px 110px rgba(0,0,0,.5), 16px 26px 44px rgba(0,0,0,.35); }}
.phone img {{ width:100%; display:block; border-radius:84px; }}
"""

LAYOUTS = {
    # 1) 정면 대형, 하단 블리드
    "hero-bleed": """
.eyebrow { text-align:center; margin-top:230px; }
.headline { text-align:center; margin-top:34px; padding:0 70px; }
.sub { text-align:center; margin-top:52px; }
.wrap { display:flex; justify-content:center; margin-top:150px; }
.phone { width:1000px; }
""",
    # 2) 좌측 정렬 텍스트 + 오른쪽 기울기, 오른쪽 블리드
    "left-text": """
.eyebrow { text-align:left; margin:250px 0 0 114px; }
.headline { text-align:left; margin:30px 0 0 110px; }
.sub { text-align:left; margin:48px 0 0 114px; }
.wrap { perspective:2600px; perspective-origin:30% 30%; position:absolute; left:300px; top:990px; }
.phone { width:840px; transform:rotateY(16deg) rotateX(2deg); }
""",
    # 3) 폰 상단, 텍스트 하단
    "text-bottom": """
.wrap { perspective:2800px; perspective-origin:50% 40%; display:flex; justify-content:center; margin-top:170px; }
.phone { width:880px; transform:rotateY(-10deg) rotateX(2deg); }
.eyebrow { text-align:center; margin-top:100px; }
.headline { text-align:center; margin-top:26px; padding:0 70px; }
.sub { text-align:center; margin-top:48px; }
""",
    # 4) 평면 회전, 좌측 치우침 + 하단 블리드
    "flat-rotate": """
.eyebrow { text-align:center; margin-top:210px; }
.headline { text-align:center; margin-top:34px; padding:0 70px; }
.sub { text-align:center; margin-top:52px; }
.wrap { position:absolute; left:120px; top:1010px; }
.phone { width:1010px; transform:rotate(-6deg); }
""",
    # 5) 다크 배경 반전 + 정면
    "dark": """
body { background:#131316; }
.eyebrow { text-align:center; margin-top:230px; }
.headline { color:#f5f5f7; text-align:center; margin-top:34px; padding:0 70px; }
.sub { color:#77777d; text-align:center; margin-top:52px; }
.wrap { display:flex; justify-content:center; margin-top:150px; }
.phone { width:930px; border-color:#48484e;
  box-shadow: 0 0 160px rgba(80,140,255,.22), 40px 70px 110px rgba(0,0,0,.55); }
""",
}

# 아이패드: 글은 위, 기기는 아래로 크게 걸친다. 정면과 살짝 기운 것을 번갈아 쓴다.
IPAD_CSS = """
.eyebrow { font-size:58px; text-align:center; margin-top:200px; }
.headline { text-align:center; margin-top:34px; padding:0 120px; }
.sub { text-align:center; margin-top:48px; padding:0 160px; }
.phone { border-radius:72px; padding:26px; }
.phone img { border-radius:48px; }
"""
IPAD_LAYOUTS = {
    "front": ".wrap { display:flex; justify-content:center; margin-top:130px; } .phone { width:1640px; }",
    "tilt":  ".wrap { perspective:3600px; display:flex; justify-content:center; margin-top:130px; } "
             ".phone { width:1580px; transform:rotateY(-9deg) rotateX(2deg); }",
}
IPAD_ORDER = ["front", "tilt", "front", "tilt", "front"]

# text-bottom 은 폰이 먼저 오는 DOM 순서
# 눈썹글(파란 한 줄)이 헤드라인 위에 선다. 기존 마케팅 이미지가 그 모양이다.
BODY_TEXT_FIRST = ('<div class="eyebrow">{eyebrow}</div><div class="headline">{headline}</div>'
                   '<div class="sub">{sub}</div><div class="wrap"><div class="phone"><img src="{img}"></div></div>')
BODY_PHONE_FIRST = ('<div class="wrap"><div class="phone"><img src="{img}"></div></div>'
                    '<div class="eyebrow">{eyebrow}</div><div class="headline">{headline}</div><div class="sub">{sub}</div>')

HTML = """<!doctype html><html><head><meta charset="utf-8"><style>
{base}{layout}
</style></head><body>{body}</body></html>"""

def main(only=None):
    OUT.mkdir(parents=True, exist_ok=True)
    for i, (fname, layout, eyebrow, headline, sub) in enumerate(SHOTS):
        if only and fname != only:
            continue
        if DEVICE == "ipad":
            body_tpl, layout_css = BODY_TEXT_FIRST, IPAD_CSS + IPAD_LAYOUTS[IPAD_ORDER[i]]
            if layout == "dark":
                layout_css += LAYOUTS["dark"].split(".eyebrow")[0]
        else:
            body_tpl = BODY_PHONE_FIRST if layout == "text-bottom" else BODY_TEXT_FIRST
            layout_css = LAYOUTS[layout]
        src = SRC / fname
        if not src.exists():
            raise SystemExit(f"원본이 없다: {src}")
        body = body_tpl.format(eyebrow=eyebrow, headline=headline, sub=sub, img=src.as_uri())
        # ⚠️ 중간 HTML 은 scripts/ 가 아니라 임시 폴더에 쓴다. 예전에는 여기 남아서
        #    산출물이 저장소에 같이 올라갔다.
        html_path = pathlib.Path(tempfile.gettempdir()) / ("clipkb-shot-" + PREFIX + fname.replace(".png", ".html"))
        html_path.write_text(HTML.format(base=BASE_CSS, layout=layout_css, body=body), encoding="utf-8")
        out_png = OUT / (PREFIX + fname)
        subprocess.run([CHROME, "--headless=new", f"--screenshot={out_png}",
                        f"--window-size={W},{H}", "--force-device-scale-factor=1",
                        "--hide-scrollbars", "--disable-gpu", html_path.as_uri()],
                       check=True, capture_output=True)
        print(f"rendered {out_png}")

if __name__ == "__main__":
    # python3 scripts/make_marketing_screenshots.py [언어] [iphone|ipad] [파일 하나만]
    main(sys.argv[3] if len(sys.argv) > 3 else None)
