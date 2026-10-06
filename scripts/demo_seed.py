# -*- coding: utf-8 -*-
"""언어별 시연 데이터를 App Group 에 심는다."""
import json, sys, uuid, io, os, subprocess
G = sys.argv[1]; lang = sys.argv[2]
APP = sys.argv[3] if len(sys.argv) > 3 else None  # 앱 데이터 컨테이너
DEV = sys.argv[3] if len(sys.argv) > 3 else None
def it(k, v): return {"id": str(uuid.uuid4()).upper(), "key": k, "value": v}
def m(t, v, cat, items=None, tv=None):
    return {"id": str(uuid.uuid4()).upper(), "title": t, "value": v, "isChecked": False,
            "isFavorite": False, "clipCount": 0, "category": cat, "isSecure": False,
            "templateVariables": tv or [], "placeholderValues": {},
            "comboValues": [i["value"] for i in (items or [])], "stackItems": items or [],
            "childMemoIds": [], "comboInterval": 2.0, "imageFileNames": [],
            "contentType": "text", "hintShownOnKeyboard": True,
            "isTemplate": bool(tv), "isCombo": bool(items), "currentComboIndex": 0}

# (분류, 메모들, 빈칸 이름, 빈칸에 저장해 둔 값들)
DATA = {
 "ko": ("기본", [
   ("계좌번호", "신한 110-123-456789 홍길동", None, None),
   ("회사 이메일", "hong@company.com", None, None),
   ("전화번호", "010-1234-5678", None, None),
   ("주소", "서울 강남구 테헤란로 1길 10", None, None),
   ("문의 답장", "{이름}님 안녕하세요, 문의 주셔서 감사합니다.", None, ["{이름}"]),
   ("자리 비움", "월요일까지 자리를 비웁니다. 돌아와서 답드릴게요.", None, None),
   ("사업자번호", "123-45-67890", None, None),
   ("출근 보고", "", [("이름","홍길동"),("부서","개발팀"),("오늘 할 일","배포 점검")], None),
 ], "이름", ["홍길동", "김서연", "박도윤"]),
 "en": ("General", [
   ("Bank account", "Chase 110-123-456789 John Doe", None, None),
   ("Work email", "john@company.com", None, None),
   ("Phone", "(415) 555-0123", None, None),
   ("Address", "1 Market St, San Francisco", None, None),
   ("Inquiry reply", "Hi {name}, thanks for reaching out.", None, ["{name}"]),
   ("Away", "I am out until Monday. I will reply when I am back.", None, None),
   ("Tax ID", "12-3456789", None, None),
   ("Morning check in", "", [("Name","John Doe"),("Team","Engineering"),("Today","Release check")], None),
 ], "name", ["John Doe", "Alice Kim", "Sam Patel"]),
 "zh-Hans": ("基本", [
   ("银行账号", "招商 110-123-456789 张三", None, None),
   ("公司邮箱", "zhangsan@company.com", None, None),
   ("手机号", "138-1234-5678", None, None),
   ("地址", "上海市浦东新区世纪大道 100 号", None, None),
   ("咨询回复", "{名字} 您好，感谢您的咨询。", None, ["{名字}"]),
   ("暂时离开", "我要到周一才回来，回来后立刻回复您。", None, None),
   ("税号", "91310000MA1K3XXXXX", None, None),
   ("上班报到", "", [("姓名","张三"),("部门","研发部"),("今天要做的","发布检查")], None),
 ], "名字", ["张三", "李四", "王芳"]),
 "zh-Hant": ("基本", [
   ("銀行帳號", "國泰 110-123-456789 張三", None, None),
   ("公司信箱", "zhangsan@company.com", None, None),
   ("手機號碼", "0912-345-678", None, None),
   ("地址", "台北市信義區松高路 11 號", None, None),
   ("諮詢回覆", "{名字} 您好，感謝您的諮詢。", None, ["{名字}"]),
   ("暫時離開", "我要到週一才回來，回來後立刻回覆您。", None, None),
   ("統一編號", "12345678", None, None),
   ("上班報到", "", [("姓名","張三"),("部門","研發部"),("今天要做的","發布檢查")], None),
 ], "名字", ["張三", "李四", "王芳"]),
 "ru": ("Основные", [
   ("Реквизиты счета", "Сбербанк 110-123-456789 Иван Петров", None, None),
   ("Рабочая почта", "ivan@company.com", None, None),
   ("Телефон", "+7 900 123-45-67", None, None),
   ("Адрес", "Москва, ул. Тверская, 10", None, None),
   ("Ответ на запрос", "{имя}, здравствуйте. Спасибо за обращение.", None, ["{имя}"]),
   ("Не на месте", "Вернусь в понедельник и сразу отвечу.", None, None),
   ("ИНН", "7700123456", None, None),
   ("Утренний отчёт", "", [("Имя","Иван Петров"),("Отдел","Разработка"),("Сегодня","Проверка релиза")], None),
 ], "имя", ["Иван Петров", "Анна Смирнова", "Олег Кузнецов"]),
 "ja": ("基本", [
   ("口座番号", "みずほ 普通 1234567 ヤマダ タロウ", None, None),
   ("仕事用メール", "yamada@company.jp", None, None),
   ("電話番号", "090-1234-5678", None, None),
   ("住所", "東京都渋谷区神南1-2-3", None, None),
   ("問い合わせ返信", "{名前}様、お問い合わせありがとうございます。", None, ["{名前}"]),
   ("不在連絡", "月曜日まで不在です。戻り次第お返事します。", None, None),
   ("法人番号", "1234567890123", None, None),
   ("朝の報告", "", [("名前","山田太郎"),("部署","開発部"),("今日の予定","リリース確認")], None),
 ], "名前", ["山田太郎", "佐藤花子", "鈴木一郎"]),
 "es": ("General", [
   ("Cuenta CLABE", "BBVA 012 180 01234567890 1", None, None),
   ("Correo de trabajo", "maria@empresa.mx", None, None),
   ("Celular", "55 1234 5678", None, None),
   ("Dirección", "Av. Reforma 222, CDMX", None, None),
   ("Respuesta a consulta", "Hola {nombre}, gracias por escribirnos.", None, ["{nombre}"]),
   ("Fuera de oficina", "Regreso el lunes y te respondo.", None, None),
   ("RFC", "GODE561231GR8", None, None),
   ("Reporte del día", "", [("Nombre","María López"),("Área","Ingeniería"),("Hoy","Revisar lanzamiento")], None),
 ], "nombre", ["María López", "Carlos Ruiz", "Ana Torres"]),
 "de": ("Allgemein", [
   ("Bankverbindung", "DE89 3704 0044 0532 0130 00", None, None),
   ("Arbeits-E-Mail", "max@firma.de", None, None),
   ("Telefon", "+49 151 2345678", None, None),
   ("Adresse", "Hauptstraße 1, 10115 Berlin", None, None),
   ("Antwort auf Anfrage", "Hallo {Name}, danke für deine Nachricht.", None, ["{Name}"]),
   ("Abwesend", "Bis Montag nicht erreichbar. Ich melde mich danach.", None, None),
   ("USt-IdNr.", "DE123456789", None, None),
   ("Morgenbericht", "", [("Name","Max Müller"),("Team","Entwicklung"),("Heute","Release prüfen")], None),
 ], "Name", ["Max Müller", "Anna Schmidt", "Lukas Weber"]),
 "th": ("ทั่วไป", [
   ("เลขบัญชี", "กสิกร 123-4-56789-0 สมชาย ใจดี", None, None),
   ("อีเมลที่ทำงาน", "somchai@company.co.th", None, None),
   ("เบอร์โทร", "081-234-5678", None, None),
   ("ที่อยู่", "99 ถนนสุขุมวิท กรุงเทพฯ", None, None),
   ("ตอบลูกค้า", "สวัสดีคุณ{ชื่อ} ขอบคุณที่ติดต่อมา", None, ["{ชื่อ}"]),
   ("ไม่อยู่", "ไม่อยู่ถึงวันจันทร์ กลับมาแล้วจะตอบทันที", None, None),
   ("พร้อมเพย์", "081-234-5678", None, None),
   ("รายงานเช้า", "", [("ชื่อ","สมชาย ใจดี"),("แผนก","พัฒนา"),("วันนี้","ตรวจรีลีส")], None),
 ], "ชื่อ", ["สมชาย ใจดี", "สุดา แก้วดี", "อนันต์ ศรีสุข"]),
 "vi": ("Chung", [
   ("Số tài khoản", "Vietcombank 0123456789 Nguyễn Văn An", None, None),
   ("Email công việc", "an@congty.vn", None, None),
   ("Điện thoại", "0912 345 678", None, None),
   ("Địa chỉ", "12 Lê Lợi, Quận 1, TP.HCM", None, None),
   ("Trả lời khách", "Chào {tên}, cảm ơn bạn đã liên hệ.", None, ["{tên}"]),
   ("Vắng mặt", "Mình vắng đến thứ Hai, về sẽ trả lời ngay.", None, None),
   ("Mã số thuế", "0101234567", None, None),
   ("Báo cáo sáng", "", [("Tên","Nguyễn Văn An"),("Bộ phận","Phát triển"),("Hôm nay","Kiểm tra bản phát hành")], None),
 ], "tên", ["Nguyễn Văn An", "Trần Thị Mai", "Lê Minh Khoa"]),
 "fr": ("Général", [
   ("Coordonnées bancaires", "IBAN FR76 3000 6000 0112 3456 7890 189", None, None),
   ("E-mail pro", "julie.martin@entreprise.fr", None, None),
   ("Téléphone", "06 12 34 56 78", None, None),
   ("Adresse", "12 rue de Rivoli, 75004 Paris", None, None),
   ("Réponse client", "Bonjour {prénom}, merci pour votre message.", None, ["{prénom}"]),
   ("Absence", "Absente jusqu'à lundi. Je vous réponds dès mon retour.", None, None),
   ("N° SIRET", "123 456 789 00012", None, None),
   ("Point du matin", "", [("Nom","Julie Martin"),("Équipe","Développement"),("Aujourd'hui","Vérifier la mise en ligne")], None),
 ], "prénom", ["Julie", "Thomas", "Camille"]),
 "it": ("Generale", [
   ("Conto bancario", "IBAN IT60 X054 2811 1010 0000 0123 456", None, None),
   ("Email di lavoro", "giulia.rossi@azienda.it", None, None),
   ("Telefono", "333 123 4567", None, None),
   ("Indirizzo", "Via Roma 10, 20121 Milano", None, None),
   ("Risposta clienti", "Ciao {nome}, grazie per averci scritto.", None, ["{nome}"]),
   ("Assenza", "Fuori ufficio fino a lunedì. Ti rispondo al rientro.", None, None),
   ("Partita IVA", "IT12345678901", None, None),
   ("Report del mattino", "", [("Nome","Giulia Rossi"),("Team","Sviluppo"),("Oggi","Controllo del rilascio")], None),
 ], "nome", ["Giulia", "Marco", "Sara"]),
 "pt-BR": ("Geral", [
   ("Conta bancária", "Itaú ag. 1234 c/c 56789-0 João Silva", None, None),
   ("E-mail do trabalho", "joao.silva@empresa.com.br", None, None),
   ("Celular", "(11) 91234-5678", None, None),
   ("Endereço", "Av. Paulista, 1000, São Paulo", None, None),
   ("Resposta ao cliente", "Olá {nome}, obrigado pelo contato.", None, ["{nome}"]),
   ("Ausente", "Fora até segunda. Respondo assim que voltar.", None, None),
   ("CNPJ", "12.345.678/0001-90", None, None),
   ("Relatório da manhã", "", [("Nome","João Silva"),("Equipe","Desenvolvimento"),("Hoje","Revisar a versão")], None),
 ], "nome", ["João", "Maria", "Pedro"]),
}
cat, rows, ph_name, ph_values = DATA[lang]
memos = []
for t, v, items, tv in rows:
    memos.append(m(t, v, cat, [it(a,b) for a,b in items] if items else None, tv))
io.open(os.path.join(G, "memos.data"), "w", encoding="utf-8").write(json.dumps(memos, ensure_ascii=False))
print("심음", lang, len(memos))

# 빈칸에 저장해 둔 값. `placeholder_values_{이름}` 에 [PlaceholderValue] 를 JSON 으로 둔다.
# ⚠️ 순서가 그대로 보여야 한다. 5.1.2 에서 고친 것이 바로 이 순서다.
if True:
    tpl = next(r for r in memos if r["isTemplate"])
    ref = 810_000_000.0  # 2026 년 어디쯤. 정확한 날짜는 화면에 안 나온다
    payload = [{"id": str(uuid.uuid4()).upper(), "value": v,
                "sourceMemoId": tpl["id"], "sourceMemoTitle": tpl["title"],
                "addedAt": ref - i * 3600} for i, v in enumerate(ph_values)]
    blob = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    # ⚠️ `simctl spawn defaults write group.…` 는 앱 그룹 컨테이너가 아니라 시뮬레이터
    #    홈의 Preferences 에 쓴다. 앱이 읽는 자리는 그룹 컨테이너 안이라 직접 쓴다.
    #    이름은 **중괄호를 붙인 쪽**이다(`PlaceholderSummary.token`).
    import plistlib
    pref = os.path.join(G, "Library", "Preferences", "group.com.Ysoup.TokenMemo.plist")
    os.makedirs(os.path.dirname(pref), exist_ok=True)
    try:
        d = plistlib.load(io.open(pref, "rb"))
    except Exception:
        d = {}
    for k in [k for k in list(d) if k.startswith("placeholder_values_")]:
        del d[k]
    # 시연은 늘 같은 자리에서 시작한다. 지난 녹화가 바꿔 둔 것을 되돌린다.
    d.pop("keyboardHeightPreset.v1", None)
    # 기본 카테고리(업무 · 개인)는 기기에서 앱을 **처음 켠 언어**로 지어지고 그 뒤로는 그대로다.
    # 한 기기로 여러 언어를 찍으면 한국어 화면에 "Work" 탭이 선다. 시연은 심은 분류 하나로만 간다.
    d["userDefinedCategories_v1"] = []
    d["defaultCategories_v1"] = []
    d["defaultCategories.seeded.v1"] = True
    # 지난 촬영이 '최근' 탭을 열어 둔 채 끝났으면 다음 촬영이 거기서 시작한다. 단축어 탭으로 되돌린다.
    d["keyboardShowsRecentClips.v1"] = False
    d["placeholder_values_{" + ph_name + "}"] = blob
    plistlib.dump(d, io.open(pref, "wb"))
    print("빈칸 값", ph_name, len(ph_values))

    # 앱 자신의 UserDefaults 도 같은 이유로 직접 쓴다. 시연은 늘 목록 탭에서 시작한다.
    if APP:
        ap = os.path.join(APP, "Library", "Preferences", "com.Ysoup.TokenMemo.plist")
        try:
            a = plistlib.load(io.open(ap, "rb"))
        except Exception:
            a = {}
        a["snippetsTabStyle.v1"] = "list"
        a["selectedCategoryTab_v1"] = "__basic__"
        plistlib.dump(a, io.open(ap, "wb"))
        print("탭 되돌림 list")

# '최근' 탭에 보일 복사 기록(`smart.clipboard.history.data`). 맨 앞이 가장 최근이다.
# 미리보기 영상은 맨 앞 것(송장번호)을 넣는다(InAppKeyboardStage.runScreenshotScene).
# 종류는 ClipboardItemType 의 rawValue 다: 송장번호 · 주소 · 텍스트 · 예약번호.
CLIPS = {
 "ko": ["6012-3456-7890", "서울 마포구 월드컵북로 396", "오늘 7시 강남역 2번 출구에서 봬요", "예약번호 KX4R92"],
 "en": ["1Z 999 AA1 01 2345 6784", "350 5th Ave, New York, NY 10118", "See you at 7 by the north entrance", "Confirmation code KX4R92"],
 "zh-Hans": ["SF1234567890123", "上海市浦东新区世纪大道100号", "晚上7点在南门见", "预订号 KX4R92"],
 "zh-Hant": ["1234-5678-9012", "台北市信義區市府路45號", "晚上7點在南門見", "訂位代號 KX4R92"],
 "ru": ["RA123456789RU", "Москва, ул. Тверская, 7", "Встречаемся в 7 у главного входа", "Код брони KX4R92"],
 "ja": ["1234-5678-9012", "東京都渋谷区神南1-2-3", "7時に東口で待ち合わせしましょう", "予約番号 KX4R92"],
 "es": ["Guía 1234 5678 9012", "Av. Reforma 222, Juárez, CDMX", "Nos vemos a las 7 en la entrada norte", "Código de reserva KX4R92"],
 "de": ["00340434161234567890", "Friedrichstraße 43, 10117 Berlin", "Wir treffen uns um 7 am Haupteingang", "Buchungscode KX4R92"],
 "th": ["TH1234567890", "99 ถนนสีลม กรุงเทพฯ 10500", "เจอกันหนึ่งทุ่มที่ทางเข้าหลัก", "รหัสจอง KX4R92"],
 "vi": ["1234567890", "45 Nguyễn Huệ, Quận 1, TP.HCM", "Hẹn gặp lúc 7 giờ ở cổng chính", "Mã đặt chỗ KX4R92"],
 "fr": ["6A12345678901", "8 rue de la Paix, 75002 Paris", "Rendez-vous à 19 h à l'entrée principale", "Code de réservation KX4R92"],
 "it": ["1234567890", "Corso Buenos Aires 1, 20124 Milano", "Ci vediamo alle 19 all'ingresso principale", "Codice prenotazione KX4R92"],
 "pt-BR": ["BR123456789BR", "Rua Oscar Freire, 900, São Paulo", "Te encontro às 19h na entrada principal", "Código da reserva KX4R92"],
}
import time
now = time.time() - 978_307_200  # JSONEncoder 의 기본 날짜는 2001-01-01 기준 초
kinds = ["송장번호", "주소", "텍스트", "예약번호"]
history = [{"id": str(uuid.uuid4()).upper(), "content": c, "copiedAt": now - (i + 1) * 900,
            "isTemporary": True, "contentType": "text", "detectedType": kinds[i],
            "confidence": 0.9, "tags": [], "autoSaveOffered": True}
           for i, c in enumerate(CLIPS[lang])]
io.open(os.path.join(G, "smart.clipboard.history.data"), "w", encoding="utf-8").write(
    json.dumps(history, ensure_ascii=False))
print("복사 기록", lang, len(history))

# 미리보기 영상에서 상대가 건네는 부탁 셋(InAppKeyboardStage.runScreenshotScene "demo").
# 첫 줄의 이름은 빈칸에 저장해 둔 두 번째 값과 같아야 한다. 영상이 그 이름을 골라 답한다.
# 둘째는 첫 단축어(계좌), 셋째는 '최근' 탭의 맨 앞(송장번호)을 부른다.
REQUESTS = {
 "ko": ["안녕하세요, 김서연이에요. 주문 관련해서 문의드려요", "입금 계좌 알려 주실래요?", "송장번호도 부탁드려요"],
 "en": ["Hi, this is Alice Kim. I have a question about my order", "Could you send me your bank details?", "And the tracking number, please"],
 "zh-Hans": ["你好，我是李四，想咨询一下我的订单", "能告诉我收款账号吗？", "快递单号也发我一下吧"],
 "zh-Hant": ["你好，我是李四，想詢問一下我的訂單", "可以告訴我匯款帳號嗎？", "也麻煩給我物流單號"],
 "ru": ["Здравствуйте, это Анна Смирнова. У меня вопрос по заказу", "Пришлите, пожалуйста, реквизиты для оплаты", "И трек-номер, пожалуйста"],
 "ja": ["こんにちは、佐藤花子です。注文について質問があります", "振込先を教えていただけますか？", "追跡番号もお願いします"],
 "es": ["Hola, soy Carlos Ruiz. Tengo una duda sobre mi pedido", "¿Me pasas tu CLABE para el pago?", "Y el número de guía, por favor"],
 "de": ["Hallo, hier ist Anna Schmidt. Ich habe eine Frage zu meiner Bestellung", "Kannst du mir deine Bankverbindung schicken?", "Und die Sendungsnummer bitte"],
 "th": ["สวัสดี สุดา แก้วดี เอง อยากสอบถามเรื่องคำสั่งซื้อ", "ขอเลขบัญชีสำหรับโอนเงินหน่อย", "ขอเลขพัสดุด้วยนะ"],
 "vi": ["Chào bạn, mình là Trần Thị Mai. Mình muốn hỏi về đơn hàng", "Bạn gửi mình số tài khoản nhé?", "Cho mình xin mã vận đơn luôn nhé"],
 "fr": ["Bonjour, c'est Thomas. J'ai une question sur ma commande", "Pouvez-vous m'envoyer vos coordonnées bancaires ?", "Et le numéro de suivi, s'il vous plaît"],
 "it": ["Ciao, sono Marco. Ho una domanda sul mio ordine", "Mi mandi le coordinate bancarie?", "E il numero di spedizione, per favore"],
 "pt-BR": ["Oi, aqui é a Maria. Tenho uma dúvida sobre meu pedido", "Pode me passar os dados da conta?", "E o código de rastreio, por favor"],
}
if APP:
    import plistlib
    ap = os.path.join(APP, "Library", "Preferences", "com.Ysoup.TokenMemo.plist")
    try:
        a = plistlib.load(io.open(ap, "rb"))
    except Exception:
        a = {}
    a["DemoRequests"] = REQUESTS[lang]
    plistlib.dump(a, io.open(ap, "wb"))
    print("부탁", lang, len(REQUESTS[lang]))
