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
