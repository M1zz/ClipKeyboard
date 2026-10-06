#!/usr/bin/env python3
"""마케팅 스크린샷 목업 생성: HTML 생성 → 헤드리스 Chrome 렌더링.

슬라이드마다 layout 이 달라 배치가 다양함:
  hero-bleed  : 헤드라인 상단 중앙 + 정면 대형 폰, 하단 블리드
  left-text   : 좌측 정렬 텍스트 + 오른쪽으로 기운 폰
  text-bottom : 폰 상단 + 텍스트 하단
  flat-rotate : 평면 회전(-5°) 폰, 하단 블리드
  dark        : 다크 배경 반전 + 정면 폰
"""
import shutil, subprocess, sys, pathlib, tempfile

# 사용법: python3 scripts/make_marketing_screenshots.py <언어> [iphone|ipad] [파일 하나만]
#
# 자리는 DeployBar 와의 계약이다(docs/screenshots/README.md):
#   docs/screenshots/raw/<기기>/<언어>/01-....png   원본 캡처 (올라가지 않는다)
#   docs/screenshots/marketing/<스토어 로케일>/      제출본. 아이폰 · 아이패드가 한 폴더에 있고 픽셀로 기기를 가른다
LANG = (sys.argv[1] if len(sys.argv) > 1 else "en")
DEVICE = (sys.argv[2] if len(sys.argv) > 2 else "iphone")
# 앱 언어 코드 → App Store Connect 로케일
STORE = {"en": "en-US", "es": "es-MX", "de": "de-DE", "fr": "fr-FR"}.get(LANG, LANG)
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
# 1 · 2장은 검색 결과에서 미리보기 영상 옆에 함께 보인다. 그 나라 검색어(머리말)와 영상과 같은 이야기를 둔다
# (docs/marketing/ASO_2026-10.md).
LAYOUT_ORDER = [
    ("01-reply.png",          "hero-bleed"),
    ("02-recent-clips.png",   "left-text"),
    ("03-template-fill.png",  "text-bottom"),
    ("04-snippet-stack.png",  "flat-rotate"),
    ("05-all-snippets.png",   "dark"),
]

COPY = {
    "ko": [
        ("상용구 키보드", "문의엔<br>바로 답장", "자주 쓰는 문구를 키보드에서 탭 한 번에"),
        ("클립보드", "복사한 글도<br>키보드에서", "복사한 것은 '최근' 탭에 30일 동안 남아요"),
        ("템플릿",           "빈칸만 채우고<br>보내세요",        "한 줄로 써 두고, 이름만 매번 바꿔요"),
        ("단축어 스택",       "값 여러 개를<br>키 하나에",        "칸마다 이름이 있어 다음이 무엇인지 알아요"),
        ("한곳에 모아서",     "또 쓸 말은<br>전부 여기에",        "갈래로 묶고 찾아 써요. 폰 밖으로 나가지 않아요"),
    ],
    "en": [
        ("Text snippets", "Reply in<br>one tap", "Saved replies, right on your keyboard"),
        ("Clipboard manager", "Paste what<br>you copied", "Copied text stays in Recent for 30 days"),
        ("Templates",          "Fill the blank,<br>send it",    "One line, a different name every time"),
        ("Snippet stacks",     "Several values,<br>one key",    "Every slot has a name, so you know what is next"),
        ("All in one place",   "Everything you<br>type again",  "Grouped, searchable, and never leaves your phone"),
    ],
    "zh-Hans": [
        ("快捷短语", "有人问，<br>一点就回", "常用语就在键盘上"),
        ("剪贴板", "复制过的，<br>键盘里就有", "复制的内容在“最近”里保留 30 天"),
        ("模板",           "填好空格，<br>直接发送",   "写一次，每次只换名字"),
        ("短语堆",         "多个值，<br>一个键",       "每一格都有名字，知道下一个是什么"),
        ("全都放在一处",    "要反复打的，<br>都在这里", "分组、可搜索，也不会离开你的手机"),
    ],
    "zh-Hant": [
        ("常用語", "有人問，<br>一點就回", "快速回覆就在鍵盤上"),
        ("剪貼簿", "複製過的，<br>鍵盤裡就有", "複製的內容在「最近」裡保留 30 天"),
        ("範本",             "填好空格，<br>直接送出",   "寫一次，每次只換名字"),
        ("短語堆",           "多個值，<br>一個鍵",       "每一格都有名字，知道下一個是什麼"),
        ("全都放在一處",      "要反覆打的，<br>都在這裡", "分組、可搜尋，也不會離開你的手機"),
    ],
    "ru": [
        ("Быстрые ответы", "Ответ<br>в одно касание", "Шаблоны и фразы прямо на клавиатуре"),
        ("Буфер обмена", "Скопированное<br>под рукой", "Всё скопированное 30 дней во вкладке «Недавние»"),
        ("Шаблоны",           "Заполните<br>и отправьте",       "Одна строка, каждый раз новое имя"),
        ("Стопки фраз",       "Много значений,<br>одна клавиша","У каждой ячейки есть имя, и вы знаете, что дальше"),
        ("Всё в одном месте", "Всё, что вы<br>печатаете снова", "По группам, с поиском. Телефон не покидает"),
    ],
    "ja": [
        ("定型文キーボード", "聞かれたら<br>すぐ返信", "よく使う文章をワンタップで"),
        ("クリップボード履歴", "コピーした文も<br>キーボードから", "コピーしたものは「最近」に30日間残ります"),
        ("テンプレート",     "空欄を埋めて<br>送るだけ",         "一度書いておけば、名前だけ毎回変えられます"),
        ("スタック",         "いくつもの値を<br>ひとつのキーに", "欄ごとに名前があるので、次が何かわかります"),
        ("ひとつの場所に",   "また使う言葉は<br>すべてここに",   "グループ分けして検索。端末の外には出ません"),
    ],
    "es": [
        ("Respuestas rápidas", "Responde<br>con un toque", "Tus frases guardadas, en el teclado"),
        ("Portapapeles", "Pega lo que<br>copiaste", "Lo copiado queda 30 días en Recientes"),
        ("Plantillas",       "Llena el campo<br>y envía",        "Una línea, un nombre distinto cada vez"),
        ("Pilas",            "Varios valores,<br>una tecla",     "Cada campo tiene nombre: sabes qué sigue"),
        ("Todo en un lugar", "Lo que vuelves<br>a escribir",     "Por grupos y con búsqueda. No sale de tu dispositivo"),
    ],
    "de": [
        ("Textbausteine", "Sofort<br>antworten", "Gespeicherte Antworten direkt auf der Tastatur"),
        ("Zwischenablage", "Kopiertes<br>direkt einfügen", "Kopierter Text bleibt 30 Tage unter „Zuletzt“"),
        ("Vorlagen",           "Lücke füllen,<br>abschicken",       "Einmal schreiben, jedes Mal ein anderer Name"),
        ("Stapel",             "Viele Werte,<br>eine Taste",        "Jedes Feld hat einen Namen. Du weißt, was kommt"),
        ("Alles an einem Ort", "Was du öfter<br>tippst",            "Sortiert, durchsuchbar, bleibt auf deinem Gerät"),
    ],
    "th": [
        ("ข้อความด่วน", "ตอบกลับ<br>ในแตะเดียว", "ข้อความที่ใช้บ่อยอยู่บนคีย์บอร์ด"),
        ("คลิปบอร์ด", "ที่คัดลอกไว้<br>วางได้ทันที", "ข้อความที่คัดลอกอยู่ในแท็บล่าสุด 30 วัน"),
        ("เทมเพลต",          "กรอกช่องว่าง<br>แล้วส่ง",            "เขียนครั้งเดียว เปลี่ยนแค่ชื่อทุกครั้ง"),
        ("สแตก",             "หลายค่า<br>ในปุ่มเดียว",             "ทุกช่องมีชื่อ รู้ว่าถัดไปคืออะไร"),
        ("รวมไว้ที่เดียว",     "ข้อความที่ใช้ซ้ำ<br>อยู่ที่นี่",       "จัดกลุ่ม ค้นหาได้ และไม่ออกไปจากเครื่อง"),
    ],
    "vi": [
        ("Trả lời nhanh", "Trả lời<br>trong một chạm", "Câu hay dùng nằm ngay trên bàn phím"),
        ("Bảng tạm", "Đã sao chép,<br>dán ngay", "Nội dung sao chép được giữ 30 ngày ở tab Gần đây"),
        ("Mẫu",              "Điền ô trống<br>rồi gửi",          "Viết một lần, mỗi lần chỉ đổi tên"),
        ("Ngăn xếp",         "Nhiều giá trị,<br>một phím",       "Mỗi ô đều có tên, biết ngay tiếp theo là gì"),
        ("Tất cả một chỗ",   "Những gì bạn<br>gõ lại",           "Chia nhóm, tìm nhanh, không rời khỏi máy"),
    ],
    "fr": [
        ("Réponses rapides", "Répondez<br>en un toucher", "Vos textes enregistrés, sur le clavier"),
        ("Presse-papiers", "Collez ce que<br>vous avez copié", "Le texte copié reste 30 jours dans Récents"),
        ("Modèles", "Remplissez<br>et envoyez", "Une ligne, un prénom différent à chaque fois"),
        ("Piles", "Plusieurs valeurs,<br>une touche", "Chaque champ a un nom : vous savez ce qui suit"),
        ("Tout au même endroit", "Tout ce que<br>vous retapez", "Classé, consultable, et ça reste sur votre appareil"),
    ],
    "it": [
        ("Risposte rapide", "Rispondi<br>con un tocco", "Le tue frasi salvate, sulla tastiera"),
        ("Appunti", "Incolla ciò<br>che hai copiato", "Il testo copiato resta 30 giorni in Recenti"),
        ("Modelli", "Compila<br>e invia", "Una riga, un nome diverso ogni volta"),
        ("Pile", "Più valori,<br>un tasto", "Ogni campo ha un nome: sai cosa viene dopo"),
        ("Tutto in un posto", "Quello che<br>riscrivi spesso", "Diviso in gruppi, con ricerca. Resta sul tuo dispositivo"),
    ],
    "pt-BR": [
        ("Respostas rápidas", "Responda<br>com um toque", "Suas frases salvas, direto no teclado"),
        ("Área de transferência", "Cole o que<br>você copiou", "O texto copiado fica 30 dias em Recentes"),
        ("Modelos", "Preencha<br>e envie", "Uma linha, um nome diferente a cada vez"),
        ("Pilhas", "Vários valores,<br>uma tecla", "Cada campo tem um nome: você sabe o que vem depois"),
        ("Tudo num só lugar", "O que você<br>digita de novo", "Organizado, com busca, e não sai do seu aparelho"),
    ],
}

# 키릴·한글은 같은 글자 수라도 더 넓게 퍼진다. 언어마다 글자 크기를 조금 줄인다.
TYPE_SCALE = {"ru": (84, 40), "ko": (92, 44), "zh-Hans": (96, 46), "zh-Hant": (96, 46), "en": (96, 46),
              "ja": (88, 42), "es": (88, 42), "de": (84, 40), "th": (88, 42), "vi": (88, 42),
              "fr": (84, 40), "it": (88, 42), "pt-BR": (84, 40)}

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
        # ⚠️ Chrome 은 가끔 아무것도 안 그리고 끝나거나(종료 코드 2) 멈춘다. 1분씩 세 번까지 한다
        for _ in range(3):
            try:
                r = subprocess.run([CHROME, "--headless=new", f"--screenshot={out_png}",
                                    f"--window-size={W},{H}", "--force-device-scale-factor=1",
                                    "--hide-scrollbars", "--disable-gpu", html_path.as_uri()],
                                   capture_output=True, timeout=60)
            except subprocess.TimeoutExpired:
                continue
            if r.returncode == 0:
                break
        else:
            raise SystemExit(f"Chrome 이 그리지 못했다: {out_png}")
        print(f"rendered {out_png}")
        # 영국 페이지는 미국과 같은 그림을 쓴다(앱에 en-GB 번역이 없어 화면이 같다)
        if STORE == "en-US":
            gb = OUT.parent / "en-GB"
            gb.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(out_png, gb / out_png.name)

if __name__ == "__main__":
    # python3 scripts/make_marketing_screenshots.py [언어] [iphone|ipad] [파일 하나만]
    main(sys.argv[3] if len(sys.argv) > 3 else None)
