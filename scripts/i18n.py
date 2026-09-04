#!/usr/bin/env python3
"""여러 언어를 사람 손 없이 유지하는 통로 하나.

왜 카탈로그(.xcstrings)를 사람이 직접 안 만지나:
  언어가 40개면 문자열 하나 고칠 때마다 diff 가 40줄씩 튄다. 리뷰가 불가능해지고
  Xcode 카탈로그 편집기도 버틴다. 그래서 **원본은 i18n/ 에 두고 카탈로그는 합쳐 넣는다.**

  i18n/source.json          ko 원문 + en(피벗) + comment + 원문 해시   ← extract 가 만든다
  i18n/translations/<lang>.json   언어당 한 파일. diff 가 언어별로 갈린다
  i18n/retired.json         Xcode 가 stale 로 표시했고 코드에도 없는 키. 번역하지 않는다
  ClipKeyboard/Localizable.xcstrings   ← build 가 채워 넣는 곳. 사실상 산출물

  ko / en / zh-Hans 는 사람이 쓴 것이라 이 파이프라인이 건드리지 않는다.
  zh-Hant 는 scripts/make_zh_hant.py 가 간체에서 뽑는다. 둘 다 config 의 mode 로 구분한다.

쓰는 법:
    python3 scripts/i18n.py prune              # 죽은 키를 골라 retired.json 에 적는다
    python3 scripts/i18n.py extract            # 카탈로그 → source.json
    python3 scripts/i18n.py status             # 언어별 진행 상황
    python3 scripts/i18n.py translate ru       # 빠진 것·원문이 바뀐 것만 번역
    python3 scripts/i18n.py build              # translations/* → 카탈로그
    python3 scripts/i18n.py check              # 자리표시자·누출·긴 줄표 검사 (게이트)
    python3 scripts/i18n.py wire               # knownRegions + InfoPlist.strings 배선

번역은 중간에 끊겨도 된다. 이미 된 것은 건너뛴다.
"""
import argparse
import collections
import concurrent.futures
import glob
import hashlib
import io
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
I18N = os.path.join(ROOT, "i18n")
CONFIG = os.path.join(I18N, "config.json")
GLOSSARY = os.path.join(I18N, "glossary.json")
SOURCE = os.path.join(I18N, "source.json")
RETIRED = os.path.join(I18N, "retired.json")
INFOPLIST = os.path.join(I18N, "infoplist.json")
TRANSLATIONS = os.path.join(I18N, "translations")

DASHES = ("\u2014", "\u2013")   # CLAUDE.md 의 저장소 전 범위 금지 규칙.
#          글자를 그대로 적으면 scripts/check_dashes.sh 가 이 파일을 걸고 넘어진다.
HANGUL = re.compile(r"[가-힣]")

# %@ %d %lld %1$@ %.1f %% 를 모두 잡는다. 비교는 "종류"만 본다(%1$@ 와 %@ 는 같은 것으로).
# 깃발에 공백을 넣지 않는다. 넣으면 "50% off" 의 "% o" 를 8진수 지정자로 읽어
# 복수형을 만들려 들고, xcstringstool 이 "숫자를 참조하지 않는다" 며 빌드를 막는다.
SPEC = re.compile(r"%(?:(\d+)\$)?[-+#0]*[\d]*(?:\.\d+)?(?:hh|h|ll|l|q|L|z|t|j)?([@diouxXeEfgGcsp%])")
BRACE = re.compile(r"\{[^{}\n]*\}")
INT_TYPES = set("diouxX")


# MARK: - 파일 입출력

def jload(path, default=None):
    if not os.path.exists(path):
        return default
    return json.loads(io.open(path, encoding="utf-8").read(), object_pairs_hook=collections.OrderedDict)


def jsave(path, obj, compact_lists=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    io.open(path, "w", encoding="utf-8").write(
        json.dumps(obj, ensure_ascii=False, indent=2, sort_keys=False) + "\n")


def read_catalog(cfg):
    return jload(os.path.join(ROOT, cfg["catalog"]))


def write_catalog(cfg, d):
    """Xcode 가 쓰는 것과 바이트까지 같은 형식으로 쓴다.

    표시가 둘이다. 구분자 `" : "` 와 **마지막 줄바꿈이 없다는 것.**

    ⚠️ 끝에 줄바꿈을 붙이지 않는다. Xcode 는 안 붙인다. 우리가 붙이면 빌드할 때마다
       그 한 글자가 오갔다 하며 2.5 MB 짜리 파일에 diff 가 선다.
    """
    io.open(os.path.join(ROOT, cfg["catalog"]), "w", encoding="utf-8").write(
        json.dumps(d, ensure_ascii=False, indent=2, separators=(",", " : "), sort_keys=False))


def load_cfg():
    cfg = jload(CONFIG)
    cfg["_glossary"] = jload(GLOSSARY)
    return cfg


def langs_of(cfg, modes=None, enabled_only=True):
    out = []
    for code, meta in cfg["languages"].items():
        if enabled_only and not meta.get("enabled"):
            continue
        if modes and meta.get("mode") not in modes:
            continue
        out.append(code)
    return out


# MARK: - 문자열 뜯어보기

def specs(text):
    """자리표시자를 (위치번호, 종류) 목록으로. %% 는 뺀다."""
    out = []
    for pos, kind in SPEC.findall(text or ""):
        if kind == "%":
            continue
        out.append((pos or "", kind))
    return out


def spec_signature(text):
    """비교용 서명. 위치 지정(%1$@)이 하나라도 있으면 순서를 안 따진다."""
    s = specs(text)
    kinds = [k for _, k in s]
    if any(p for p, _ in s):
        return ("set", tuple(sorted(kinds)))
    return ("seq", tuple(kinds))


def spec_compatible(src, dst):
    a, b = spec_signature(src), spec_signature(dst)
    if a == b:
        return True
    # 한쪽만 위치 지정을 쓰면(번역문에서 어순이 바뀌어 %1$@ 로 적은 경우) 종류만 같으면 통과
    return sorted(a[1]) == sorted(b[1])


def braces(text):
    return BRACE.findall(text or "")


LETTER = re.compile(r"[^\W\d_]", re.UNICODE)


def translatable(text):
    """번역할 글자가 있는가.

    '%@ · %@', '%lld/%lld', '#+=' 같은 것은 어느 언어에서도 그대로다. 번역 대상에 넣으면
    40개 언어 × 수십 개만큼 헛돈다. 자리표시자와 기호를 걷어내고 글자가 남는지로 가른다.
    """
    bare = SPEC.sub(" ", text or "")
    bare = BRACE.sub(" ", bare)
    return bool(LETTER.search(bare))


def src_hash(ko, en, comment):
    h = hashlib.sha1(("\x00".join([ko or "", en or "", comment or ""])).encode("utf-8"))
    return h.hexdigest()[:10]


def unit_value(entry, lang):
    """카탈로그 항목에서 그 언어의 값. 복수형이면 other 를 대표로 돌려준다."""
    loc = (entry.get("localizations") or {}).get(lang)
    if not loc:
        return None
    if "stringUnit" in loc:
        return loc["stringUnit"].get("value")
    var = ((loc.get("variations") or {}).get("plural") or {})
    for form in ("other", "many", "few", "one"):
        if form in var:
            return var[form].get("stringUnit", {}).get("value")
    return None


def all_values(entry, lang):
    """검사용. 복수형은 모든 형태를 돌려준다."""
    loc = (entry.get("localizations") or {}).get(lang)
    if not loc:
        return []
    if "stringUnit" in loc:
        return [loc["stringUnit"].get("value")]
    var = ((loc.get("variations") or {}).get("plural") or {})
    return [v.get("stringUnit", {}).get("value") for v in var.values()]


# MARK: - prune: 죽은 키 골라내기

def cmd_prune(args):
    """Xcode 가 stale 로 표시했고 스위프트 코드 어디에도 없는 키를 번역 대상에서 뺀다.

    지우지 않고 '은퇴'만 시키는 이유: 지웠는데 실은 쓰이고 있었다면 모든 언어에서
    한국어 원문이 그대로 노출된다. 카탈로그에는 남겨 두고 새 언어만 안 채운다.
    """
    cfg = load_cfg()
    cat = read_catalog(cfg)
    swift = []
    for base, dirs, files in os.walk(ROOT):
        if any(p in base for p in (os.sep + "build", os.sep + ".git", "DerivedData")):
            continue
        for f in files:
            if f.endswith(".swift"):
                swift.append(os.path.join(base, f))
    blob = "\n".join(io.open(f, encoding="utf-8", errors="ignore").read() for f in swift)

    def in_source(key):
        """코드에 살아 있는가.

        스위프트 소스에는 줄바꿈이 역슬래시 n 두 글자로 적혀 있다. 카탈로그의 키는 진짜
        줄바꿈이다. 그대로 찾으면 여러 줄짜리 문구가 전부 '안 쓰임' 으로 잘못 걸린다.
        """
        if key in blob:
            return True
        escaped = key.replace("\\", "\\\\").replace("\n", "\\n").replace("\t", "\\t").replace('"', '\\"')
        return escaped in blob

    retired, kept = [], 0
    strings = cat["strings"]
    for key, entry in strings.items():
        # 카탈로그 편집기에서 손으로 \n 을 타이핑해 생긴 쌍둥이. 코드가 부르는 키는 진짜
        # 줄바꿈 쪽이라 이쪽은 영원히 안 불린다. 40개 언어로 번역할 이유가 없다.
        if "\\n" in key and key.replace("\\n", "\n") in strings:
            retired.append(key)
            continue
        # 쌍둥이는 없지만 코드도 안 부르는 리터럴 \n 키. 화면에 나가면 "\n" 두 글자가 그대로
        # 보였을 것들이라 어차피 죽은 문구다. 번역기와 씨름할 이유가 없다.
        if "\\n" in key and not in_source(key):
            retired.append(key)
            continue
        if entry.get("extractionState") == "stale" and not in_source(key):
            retired.append(key)
        elif entry.get("extractionState") == "stale":
            kept += 1
    jsave(RETIRED, collections.OrderedDict([
        ("_", "Xcode 가 stale 로 표시했고 .swift 어디에도 문자열이 없는 키. 번역 대상에서 뺀다. "
              "카탈로그에는 남아 있으니 되살리려면 코드에서 다시 쓰기만 하면 된다."),
        ("scannedSwiftFiles", len(swift)),
        ("keys", sorted(retired)),
    ]))
    print(f"🧹 스위프트 {len(swift)}개 파일을 훑음")
    print(f"   stale 이지만 코드에 살아 있어 남긴 키: {kept}개")
    print(f"   은퇴시킨 키: {len(retired)}개 → i18n/retired.json")
    return 0


# `NSLocalizedString("키", comment: "설명")` 한 벌. 줄바꿈을 사이에 두고 적어도 잡는다.
NSLOC = re.compile(
    r'NSLocalizedString\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*comment:\s*"((?:[^"\\]|\\.)*)"\s*\)',
    re.S)


def _swift_unescape(text):
    """소스에 적힌 글자를 실제 문자열로. 카탈로그의 키는 진짜 줄바꿈이다."""
    out, i = [], 0
    while i < len(text):
        c = text[i]
        if c != "\\":
            out.append(c)
            i += 1
            continue
        nxt = text[i + 1] if i + 1 < len(text) else ""
        mapping = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "'": "'", "\\": "\\", "0": "\0"}
        if nxt in mapping:
            out.append(mapping[nxt])
            i += 2
        elif nxt == "u" and text[i + 2:i + 3] == "{":
            end = text.index("}", i)
            out.append(chr(int(text[i + 3:end], 16)))
            i = end + 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def _add_from_source(catalog):
    """소스의 `NSLocalizedString` 중 카탈로그에 없는 것을 넣는다. 넣은 개수를 돌려준다."""
    d = jload(catalog)
    strings = d["strings"]
    added = 0
    for base, _, files in os.walk(ROOT):
        if any(p in base for p in (os.sep + "build", os.sep + ".git", "DerivedData")):
            continue
        for f in files:
            if not f.endswith(".swift"):
                continue
            text = io.open(os.path.join(base, f), encoding="utf-8", errors="ignore").read()
            for raw_key, raw_comment in NSLOC.findall(text):
                if "\\(" in raw_key:
                    continue  # 값이 끼워진 키는 고정된 키가 아니다. 애초에 그렇게 쓰면 안 된다
                key = _swift_unescape(raw_key)
                if not key or key in strings:
                    continue
                entry = collections.OrderedDict()
                comment = _swift_unescape(raw_comment)
                if comment:
                    entry["comment"] = comment
                entry["localizations"] = collections.OrderedDict()
                strings[key] = entry
                added += 1
    if added:
        # ⚠️ **다시 정렬하지 않는다.** 새 키는 뒤에 붙이고 자리는 Xcode 가 정하게 둔다.
        #
        #    Xcode 의 키 순서는 파이썬의 `sorted` 와 다르다(문장부호를 다르게 친다).
        #    여기서 파이썬 순서로 다시 쓰면 다음 빌드에서 Xcode 가 자기 순서로 되돌리고,
        #    그때마다 2.5 MB 파일이 통째로 diff 에 선다. 실제로 한 번 그랬다
        #    (4만 8천 줄). 순서의 주인은 하나여야 하고, 그 주인은 Xcode 다.
        io.open(catalog, "w", encoding="utf-8").write(
            json.dumps(d, ensure_ascii=False, indent=2, separators=(",", " : "), sort_keys=False))
    return added


# MARK: - sync: 빌드가 찾아낸 새 문구를 카탈로그로

def cmd_sync(args):
    """Xcode 를 열지 않고 새 `NSLocalizedString` 을 카탈로그에 넣는다.

    왜 필요한가: 문자열 카탈로그를 채우는 것은 원래 Xcode 앱이 빌드할 때 하는 일이다.
    `xcodebuild` 로만 돌리면 새 문구가 카탈로그에 안 들어가고, 그러면 번역할 원본이 없어
    다국어 파이프라인 전체가 조용히 한 발 뒤처진다.

    빌드가 남긴 `.stringsdata` 를 `xcstringstool sync` 에 먹인다. Xcode 가 하는 일과 같다.
    `--skip-marking-strings-stale` 를 붙여 **더하기만** 한다. 죽은 키는 `prune` 이 따로 본다
    (지우는 판단을 두 곳에서 하면 언젠가 서로를 지운다).
    """
    cfg = load_cfg()
    catalog = os.path.join(ROOT, cfg["catalog"])
    roots = [args.derived_data] if args.derived_data else sorted(
        glob.glob(os.path.expanduser(
            "~/Library/Developer/Xcode/DerivedData/ClipKeyboard-*/Build/Intermediates.noindex")),
        key=os.path.getmtime, reverse=True)
    if not roots:
        print("❌ 빌드 산출물을 못 찾았다. 먼저 한 번 빌드한다 (xcodebuild ... build)")
        return 1

    data = []
    for base, _, files in os.walk(roots[0]):
        data += [os.path.join(base, f) for f in files if f.endswith(".stringsdata")]
    if not data:
        print(f"❌ {roots[0]} 에 .stringsdata 가 없다")
        return 1

    before = set(json.loads(io.open(catalog, encoding="utf-8").read())["strings"])
    # 한 번에 다 넘기면 인자 길이 제한에 걸린다. 나눠 부른다(옵션이 더하기뿐이라 안전).
    step = 150
    for i in range(0, len(data), step):
        cmd = ["xcrun", "xcstringstool", "sync", catalog, "--skip-marking-strings-stale"]
        for f in data[i:i + step]:
            cmd += ["--stringsdata", f]
        out = subprocess.run(cmd, capture_output=True, text=True)
        if out.returncode != 0:
            print("❌ xcstringstool sync 실패:", out.stderr.strip()[:300])
            return 1

    # 그리고 소스를 직접 훑는다.
    #
    # ⚠️ 왜 둘 다 하나: 스위프트 컴파일러가 남기는 `.stringsdata` 에는 `String(localized:)`
    #    같은 것만 담긴다. 이 저장소가 쓰는 `NSLocalizedString(...)` 은 **거기 안 들어간다**
    #    (AISettingsView.stringsdata 를 열어 보면 tables 가 비어 있다). 그것만 믿으면 새 문구가
    #    조용히 번역 대상에서 빠지고, 그 언어 사용자만 한국어를 본다.
    added = _add_from_source(catalog)

    after = json.loads(io.open(catalog, encoding="utf-8").read())["strings"]
    new = [k for k in after if k not in before]
    print(f"🔄 .stringsdata {len(data)}개 + 소스 훑기({added}개) → 새 문구 {len(new)}개")
    for k in new[:20]:
        print("   +", repr(k))
    if len(new) > 20:
        print(f"   ... 외 {len(new) - 20}개")
    if new:
        print("   다음: extract → translate → build")
    return 0


# MARK: - extract: 카탈로그 → source.json

def cmd_extract(args):
    cfg = load_cfg()
    cat = read_catalog(cfg)
    pivot = cfg["pivot"]
    retired = set((jload(RETIRED, {}) or {}).get("keys", []))

    src = collections.OrderedDict()
    no_pivot = []
    symbols = []
    for key, entry in sorted(cat["strings"].items()):
        if key in retired:
            continue
        if entry.get("shouldTranslate") is False:
            continue
        ko = unit_value(entry, cfg["source"]) or key
        en = unit_value(entry, pivot)
        if not translatable(ko) and not translatable(en or ""):
            symbols.append(key)
            continue
        comment = entry.get("comment") or ""
        if not en:
            no_pivot.append(key)
        src[key] = collections.OrderedDict([
            ("ko", ko),
            ("en", en or ""),
            ("comment", comment),
            ("h", src_hash(ko, en, comment)),
        ])

    # Info.plist 문구(권한 설명 등)도 같은 통로로 번역한다. 키 앞에 @InfoPlist/ 를 붙여
    # 카탈로그 키와 섞이지 않게 한다. build 는 카탈로그에 없는 키라 그냥 지나가고,
    # wire 가 이것들을 .lproj/InfoPlist.strings 로 떨군다.
    info = (jload(INFOPLIST, {}) or {}).get("targets", {})
    n_info = 0
    for target, entries in info.items():
        for key, meta in entries.items():
            if not meta.get("translate"):
                continue
            src[info_key(target, key)] = collections.OrderedDict([
                ("ko", meta["ko"]), ("en", meta["en"]), ("comment", meta.get("comment", "")),
                ("h", src_hash(meta["ko"], meta["en"], meta.get("comment", ""))),
            ])
            n_info += 1

    jsave(SOURCE, src)
    print(f"   Info.plist 문구 {n_info}개 포함")
    print(f"📤 번역 대상 {len(src)}개 → i18n/source.json "
          f"(은퇴 {len(retired)}개 · 기호뿐 {len(symbols)}개 제외)")
    if no_pivot:
        print(f"⚠️  영어가 없는 키 {len(no_pivot)}개. 한국어만 보고 번역하게 된다:")
        for k in no_pivot[:10]:
            print("   ", repr(k))
    return 0


# MARK: - status

def cmd_status(args):
    cfg = load_cfg()
    src = jload(SOURCE)
    if not src:
        print("먼저 extract 를 돌린다.")
        return 1
    total = len(src)
    print(f"원문 {total}개 (i18n/source.json)\n")
    print(f"{'언어':<10} {'방식':<9} {'상태':<6} {'번역':>6} {'낡음':>6} {'빠짐':>6}")
    print("-" * 52)
    for code, meta in cfg["languages"].items():
        if not (meta.get("enabled") or args.all):
            continue
        mode = meta.get("mode")
        if mode == "machine":
            tr = jload(os.path.join(TRANSLATIONS, code + ".json"), {}) or {}
            done = sum(1 for k, v in tr.items() if k in src and v.get("src") == src[k]["h"])
            stale = sum(1 for k, v in tr.items() if k in src and v.get("src") != src[k]["h"])
            missing = total - done - stale
        else:
            cat = read_catalog(cfg)
            done = sum(1 for k in src if unit_value(cat["strings"].get(k, {}), code))
            stale, missing = 0, total - done
        flag = "켜짐" if meta.get("enabled") else "꺼짐"
        print(f"{code:<10} {mode:<9} {flag:<6} {done:>6} {stale:>6} {missing:>6}")
    return 0


# MARK: - translate

PROMPT = """You are localizing an iOS/macOS app called {app_name} into {lang_name} ({lang_code}).
{app_line}

TONE: {tone}
Match that register in {lang_name}: plain, warm, concise. Address the user with the standard polite form used by well-made consumer apps in this language. Never sound like an ad.

HARD RULES (a violation makes the string unusable):
1. Format specifiers (%@, %d, %lld, %1$@, %.1f) must appear in the translation with the SAME set of types.
   If the natural word order differs, use positional forms (%1$@, %2$d) rather than dropping or reordering bare ones.
2. Text inside curly braces {{like_this}} is a fill-in placeholder shown to the user.
   Translate the word inside the braces, keep the braces, keep the SAME NUMBER of them.
   Use exactly these fixed forms where they appear: {token_map}
3. Never use the em dash (U+2014) or en dash (U+2013). Use a comma, a period, a colon, or parentheses.
4. Keep \\n line breaks exactly as in the source: same count, same positions.
   If the source shows a literal backslash followed by n as two visible characters, keep it as
   two characters. Do not turn it into a real line break.
5. Do not translate these names: {never}
6. No Korean characters in the output.
7. Keep leading/trailing spaces and trailing punctuation style of the source.

VOCABULARY (this app's nouns, keep them consistent everywhere):
{terms}

LENGTH: these strings sit in a tight mobile UI. Stay within about {expansion}x the English length. Shorter is better.

INPUT: a JSON array. Each item has
  "i"  id, "ko" Korean source, "en" English translation (the best reference), "c" a comment about where it appears.
  Some items have "plural": true. Those contain a number and need {plural_forms} grammatical forms.

OUTPUT: a single JSON object, nothing else. No markdown fence, no commentary.
  For a normal item:  "<i>": "translation"
  For a "plural" item: "<i>": {{{plural_example}}}
Every input id must appear exactly once.

INPUT:
{items}
"""

PLURAL_FORMS = {
    "slavic": (["one", "few", "many", "other"],
               '"one": "...", "few": "...", "many": "...", "other": "..."'),
    "arabic": (["zero", "one", "two", "few", "many", "other"],
               '"zero": "...", "one": "...", "two": "...", "few": "...", "many": "...", "other": "..."'),
    "simple": (["one", "other"], '"one": "...", "other": "..."'),
}


def plural_eligible(cfg, code, ko, en):
    """복수형을 따로 받을 값인가.

    자리표시자가 정수 하나뿐인 것만 한다. 인자가 둘 이상이면 xcstrings 는
    substitutions 를 써야 하는데 그건 별건이라 여기서는 건드리지 않는다.
    """
    rule = cfg["languages"][code].get("plural", "none")
    if rule not in PLURAL_FORMS:
        return False
    s = specs(en or ko)
    return len(s) == 1 and s[0][1] in INT_TYPES


def build_prompt(cfg, code, items):
    meta = cfg["languages"][code]
    g = cfg["_glossary"]
    forms, example = PLURAL_FORMS.get(meta.get("plural", "none"), (["other"], '"other": "..."'))
    tokens = []
    for ko_tok, m in g["tokens"].items():
        fixed = m.get(code)
        if fixed:
            tokens.append(f"{ko_tok} = {fixed}")
    terms = "\n".join(
        f"  - {ko} = {m['en']}" + (f"  ({m['role']})" if m.get("role") else "") + (f"  → {m[code]}" if m.get(code) else "")
        for ko, m in g["terms"].items())
    return PROMPT.format(
        app_name=cfg["app"]["name"],
        app_line=cfg["app"]["oneLine"],
        tone=cfg["app"]["tone"],
        lang_name=meta["native"], lang_code=code,
        token_map=(", ".join(tokens) if tokens else "(none fixed yet: choose one word per placeholder and use it consistently)"),
        never=", ".join(g["neverTranslate"]),
        terms=terms,
        expansion=meta.get("expansion", 1.4),
        plural_forms="/".join(forms),
        plural_example=example,
        items=json.dumps(items, ensure_ascii=False),
    )


def call_model(prompt, model):
    """번역기. 앱 개발 머신에 이미 있는 claude CLI 를 쓴다(API 키 설정이 필요 없다).

    ANTHROPIC_API_KEY 가 있으면 그쪽이 더 싸고 빠르지만, 없는 채로도 굴러가는 것이
    이 파이프라인의 조건이다.
    """
    p = subprocess.run(["claude", "-p", "--model", model, prompt],
                       capture_output=True, text=True, cwd="/tmp")
    if p.returncode != 0:
        raise RuntimeError(p.stderr.strip()[:400] or "claude CLI 실패")
    out = p.stdout.strip()
    if out.startswith("```"):
        out = re.sub(r"^```[a-z]*\n|\n```$", "", out)
    start, end = out.find("{"), out.rfind("}")
    if start < 0 or end < 0:
        raise RuntimeError("JSON 을 못 찾음: " + out[:200])
    return json.loads(out[start:end + 1])


def validate_value(cfg, code, entry, value):
    """번역문 한 개를 검사해 문제 목록을 돌려준다(비면 통과)."""
    g = cfg["_glossary"]
    ko, en = entry["ko"], entry["en"] or entry["ko"]
    problems = []
    vals = list(value.values()) if isinstance(value, dict) else [value]
    for v in vals:
        if not isinstance(v, str) or not v.strip():
            problems.append("빈 값")
            continue
        if not spec_compatible(en, v) and not spec_compatible(ko, v):
            problems.append(f"자리표시자 불일치: 원문 {[k for _, k in specs(en)]} → 번역 {[k for _, k in specs(v)]}")
        if len(braces(v)) != len(braces(en or ko)):
            problems.append(f"{{ }} 개수 불일치: {len(braces(en or ko))} → {len(braces(v))}")
        if any(d in v for d in DASHES):
            problems.append("긴 줄표(U+2014/U+2013) 사용")
        if v.count("\n") != (en or ko).count("\n"):
            problems.append(f"줄바꿈 수 불일치: {(en or ko).count(chr(10))} → {v.count(chr(10))}")
        if code != cfg["source"] and HANGUL.search(v):
            if not any(a in v for a in g["allowSourceScript"]):
                problems.append("한국어가 남아 있음")
    return problems


def translate_chunk(cfg, code, chunk, model):
    items = []
    for key, entry in chunk:
        it = collections.OrderedDict([("i", str(len(items)))])
        it["ko"] = entry["ko"]
        if entry["en"]:
            it["en"] = entry["en"]
        if entry["comment"]:
            it["c"] = entry["comment"]
        if plural_eligible(cfg, code, entry["ko"], entry["en"]):
            it["plural"] = True
        items.append(it)
    got = call_model(build_prompt(cfg, code, items), model)

    ok, bad = {}, []
    for idx, (key, entry) in enumerate(chunk):
        v = got.get(str(idx))
        if v is None:
            bad.append((key, entry, "응답에 없음"))
            continue
        problems = validate_value(cfg, code, entry, v)
        if problems:
            bad.append((key, entry, "; ".join(problems)))
        else:
            ok[key] = v
    return ok, bad


RETRY_PROMPT = """You translated these strings into {lang_name} and each one broke a rule.
Fix them. Same rules as before: keep every format specifier ({{%@, %d, %lld}}) with the same types,
keep the same number of {{braces}}, keep the same number of \\n line breaks, no em dash or en dash,
no Korean characters.

OUTPUT: a single JSON object mapping id to the corrected translation, nothing else.

{items}
"""


def retry_bad(cfg, code, bad, model):
    meta = cfg["languages"][code]
    items = []
    for idx, (key, entry, why) in enumerate(bad):
        items.append(collections.OrderedDict([
            ("i", str(idx)), ("ko", entry["ko"]), ("en", entry["en"]),
            ("problem", why),
            ("plural", True) if plural_eligible(cfg, code, entry["ko"], entry["en"]) else ("c", entry["comment"]),
        ]))
    prompt = RETRY_PROMPT.format(lang_name=meta["native"], items=json.dumps(items, ensure_ascii=False))
    try:
        got = call_model(prompt, model)
    except Exception as e:
        return {}, [(k, e2, w) for k, e2, w in bad]
    ok, still = {}, []
    for idx, (key, entry, why) in enumerate(bad):
        v = got.get(str(idx))
        if v is not None and not validate_value(cfg, code, entry, v):
            ok[key] = v
        else:
            still.append((key, entry, why))
    return ok, still


def cmd_translate(args):
    cfg = load_cfg()
    src = jload(SOURCE)
    if not src:
        print("먼저 extract 를 돌린다.")
        return 1

    codes = args.langs or langs_of(cfg, modes=["machine"])
    rc = 0
    for code in codes:
        meta = cfg["languages"].get(code)
        if not meta:
            print(f"❌ config.json 에 없는 언어: {code}")
            rc = 1
            continue
        if meta.get("mode") != "machine" and not args.force:
            print(f"⏭  {code}: mode={meta.get('mode')} 이라 이 파이프라인이 안 건드린다 (--force 로 무시)")
            continue

        path = os.path.join(TRANSLATIONS, code + ".json")
        tr = jload(path, collections.OrderedDict()) or collections.OrderedDict()
        todo = [(k, v) for k, v in src.items()
                if k not in tr or tr[k].get("src") != v["h"]]
        if args.limit:
            todo = todo[:args.limit]
        if not todo:
            print(f"✅ {code}: 이미 최신 ({len(tr)}개)")
            continue

        chunks = [todo[i:i + args.chunk] for i in range(0, len(todo), args.chunk)]
        print(f"🌐 {code} ({meta['native']}): {len(todo)}개를 {len(chunks)}묶음으로, "
              f"동시 {args.workers}개, 모델 {args.model}")
        if args.dry_run:
            print(build_prompt(cfg, code, [{"i": "0", "ko": todo[0][1]["ko"], "en": todo[0][1]["en"]}])[:2000])
            continue

        failed = []
        done_n = 0
        lock_note = []

        def work(chunk):
            return translate_chunk(cfg, code, chunk, args.model)

        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
            futures = {pool.submit(work, c): c for c in chunks}
            for fut in concurrent.futures.as_completed(futures):
                chunk = futures[fut]
                try:
                    ok, bad = fut.result()
                except Exception as e:
                    print(f"   ⚠️  묶음 실패: {e}")
                    failed.extend((k, v, "호출 실패") for k, v in chunk)
                    continue
                if bad:
                    fixed, still = retry_bad(cfg, code, bad, args.model)
                    ok.update(fixed)
                    failed.extend(still)
                for k, v in ok.items():
                    tr[k] = collections.OrderedDict([("v", v), ("src", src[k]["h"])])
                done_n += len(ok)
                # 중간에 끊겨도 되도록 묶음마다 저장한다
                jsave(path, collections.OrderedDict(sorted(tr.items())))
                print(f"   {done_n}/{len(todo)}")

        print(f"✅ {code}: {done_n}개 저장 → i18n/translations/{code}.json")
        if failed:
            rc = 1
            print(f"❌ {code}: 검사에 걸려 못 넣은 것 {len(failed)}개")
            for k, _, why in failed[:15]:
                print(f"   {k!r}: {why}")
    return rc


# MARK: - build: translations/* → 카탈로그

def cmd_build(args):
    cfg = load_cfg()
    cat = read_catalog(cfg)
    strings = cat["strings"]
    src = jload(SOURCE, {}) or {}
    changed_total = 0
    known = set()

    for code in langs_of(cfg, modes=["machine"]):
        tr = jload(os.path.join(TRANSLATIONS, code + ".json"), {}) or {}
        if not tr:
            print(f"⏭  {code}: 번역 파일이 비어 있다")
            continue
        known.add(code)
        changed = 0
        for key, rec in tr.items():
            entry = strings.get(key)
            if entry is None:
                continue
            if key in src and rec.get("src") != src[key]["h"]:
                continue  # 원문이 바뀐 낡은 번역은 넣지 않는다
            value = rec["v"]
            if isinstance(value, dict):
                var = collections.OrderedDict()
                for form in ("zero", "one", "two", "few", "many", "other"):
                    if form in value:
                        var[form] = collections.OrderedDict([
                            ("stringUnit", collections.OrderedDict(
                                [("state", "translated"), ("value", value[form])]))])
                new = collections.OrderedDict([("variations", collections.OrderedDict([("plural", var)]))])
            else:
                new = collections.OrderedDict([
                    ("stringUnit", collections.OrderedDict([("state", "translated"), ("value", value)]))])
            locs = entry.setdefault("localizations", collections.OrderedDict())
            if locs.get(code) == new:
                continue
            locs[code] = new
            entry["localizations"] = collections.OrderedDict(sorted(locs.items()))
            changed += 1
        changed_total += changed
        print(f"📥 {code}: {changed}개 갱신 ({len(tr)}개 중)")

    if changed_total:
        write_catalog(cfg, cat)
    size = os.path.getsize(os.path.join(ROOT, cfg["catalog"])) / 1e6
    print(f"📦 카탈로그 {size:.1f} MB · 이번에 바뀐 항목 {changed_total}개")
    return 0


# MARK: - check: 게이트

def collect_issues(cfg, cat):
    """카탈로그에 실제로 들어간 값을 훑어 문제를 모은다. check 와 repair 가 같은 눈으로 본다."""
    src_lang = cfg["source"]
    hard, soft = [], []
    for key, entry in cat["strings"].items():
        if not key.strip():
            continue
        en = unit_value(entry, cfg["pivot"]) or key
        # 원문 자체에 한글이 있는 문구(한/EN 토글·두벌식 같은 고유명사)는 번역문에 한글이 남아도 된다
        hangul_ok = bool(HANGUL.search(en)) or bool(HANGUL.search(entry.get("comment") or ""))
        for code, meta in cfg["languages"].items():
            if code == src_lang or not meta.get("enabled"):
                continue
            # 복수형은 형태마다 숫자를 참조해야 한다. 안 그러면 xcstringstool 이
            # "Plural variation requires referencing the number" 로 빌드를 막는다.
            loc = (entry.get("localizations") or {}).get(code) or {}
            for form, unit in ((loc.get("variations") or {}).get("plural") or {}).items():
                val = unit.get("stringUnit", {}).get("value", "")
                if not any(t in INT_TYPES for _, t in specs(val)):
                    hard.append(collections.OrderedDict(
                        [("lang", code), ("key", key), ("en", en), ("comment", ""),
                         ("value", val), ("why", f"복수형 '{form}' 이 숫자를 참조하지 않는다 (빌드가 막힌다)")]))
            for v in all_values(entry, code):
                if v is None:
                    continue
                rec = lambda why, bucket: bucket.append(
                    collections.OrderedDict([("lang", code), ("key", key), ("en", en),
                                             ("comment", entry.get("comment") or ""),
                                             ("value", v), ("why", why)]))
                if not v.strip():
                    rec("빈 값", hard)
                    continue
                if not spec_compatible(en, v) and not spec_compatible(key, v):
                    rec(f"자리표시자 불일치 {[k for _, k in specs(en)]} → {[k for _, k in specs(v)]}", hard)
                if any(d in v for d in DASHES):
                    rec("긴 줄표", hard)
                if HANGUL.search(v) and not hangul_ok and not any(
                        a in v for a in cfg["_glossary"]["allowSourceScript"]):
                    rec("한국어 노출", hard)
                if len(braces(v)) != len(braces(en)):
                    rec(f"{{ }} 개수 {len(braces(en))} → {len(braces(v))}", soft)
                if v.count("\n") != en.count("\n"):
                    rec(f"줄바꿈 수 {en.count(chr(10))} → {v.count(chr(10))} (잘려 나갔을 수 있다)", soft)
    return hard, soft


def cmd_check(args):
    """40개 언어를 사람이 눈으로 못 보므로 이 검사가 유일한 품질 보증이다."""
    cfg = load_cfg()
    cat = read_catalog(cfg)
    src = jload(SOURCE, {}) or {}
    retired = set((jload(RETIRED, {}) or {}).get("keys", []))
    hard, soft = collect_issues(cfg, cat)

    # 커버리지: 켠 언어는 100% 여야 한다. id 처럼 반쯤 하다 만 언어를 다시는 만들지 않는다.
    coverage_fail, coverage_warn = [], []
    for code, meta in cfg["languages"].items():
        if code == cfg["source"] or not meta.get("enabled"):
            continue
        missing = [k for k in src if k in cat["strings"] and not unit_value(cat["strings"][k], code)]
        if not missing:
            continue
        # 사람이 쓰는 언어(en/zh-Hans)는 손이 늦은 것뿐이라 경고. 파이프라인이 채우는
        # 언어가 비어 있으면 그 언어 사용자가 한국어를 보게 되므로 차단한다.
        (coverage_fail if meta.get("mode") in ("machine", "derived") else coverage_warn).append(
            (code, len(missing), missing[:5]))

    prefix = "error: " if args.xcode else ""
    if hard:
        print(f"\n❌ 반드시 고쳐야 하는 것 {len(hard)}건")
        for it in hard[:args.limit]:
            print(f"{prefix}[{it['lang']}] {it['key']!r}: {it['why']}: {it['value']!r}")
        if len(hard) > args.limit:
            print(f"   ... 외 {len(hard) - args.limit}건")
    if coverage_fail:
        print(f"\n❌ 켜 놓고 다 안 채운 언어 {len(coverage_fail)}개 (그 언어 사용자는 한국어를 본다)")
        for code, n, sample in coverage_fail:
            print(f"{prefix}[{code}] {n}개 빠짐. 예: {sample[0]!r}")
    for code, n, sample in coverage_warn:
        soft.append(collections.OrderedDict(
            [("lang", code), ("key", ""), ("why", f"{n}개 미번역(사람이 채우는 언어). 예: {sample[0]!r}")]))
    if soft:
        print(f"\n⚠️  살펴볼 것 {len(soft)}건" + ("" if args.strict else " (게이트는 막지 않는다. --strict 로 막을 수 있다. 고치기: i18n.py repair)"))
        for it in soft[:args.limit]:
            where = f"[{it['lang']}] {it['key']!r}: " if it["key"] else f"[{it['lang']}] "
            print(f"   {where}{it['why']}")
        if len(soft) > args.limit:
            print(f"   ... 외 {len(soft) - args.limit}건")

    bad = bool(hard or coverage_fail or (args.strict and soft))
    if not bad:
        n = len([c for c in cfg["languages"] if cfg["languages"][c].get("enabled")])
        print(f"✅ 다국어 검사 통과 (언어 {n}개 · 키 {len(cat['strings'])}개 · 은퇴 {len(retired)}개 제외)")
    return 1 if bad else 0


REPAIR_PROMPT = """These {lang_name} ({lang_code}) strings in a shipping iOS app are broken.
Each item has the English source ("en"), the current broken translation ("bad"), and what is wrong ("problem").
Most of them were truncated: the translator kept only the first line and dropped the rest.

Re-translate each one FROM THE ENGLISH, completely.
Keep every \n line break in the same place, keep the same number of {{braces}} and format
specifiers (%@, %d, %lld), no em dash or en dash, no Korean characters.

OUTPUT: a single JSON object mapping id to the corrected translation, nothing else.

{items}
"""


def cmd_repair(args):
    """검사에 걸린 항목만 다시 번역해 카탈로그에 직접 넣는다.

    사람이 쓴 언어(en·zh-Hans)에서 여러 줄 문구가 첫 줄만 남고 잘려 나간 것을 발견해서
    만들었다. 전부 다시 돌리면 사람이 손본 좋은 번역까지 날아가므로, 걸린 것만 손댄다.
    """
    cfg = load_cfg()
    cat = read_catalog(cfg)
    hard, soft = collect_issues(cfg, cat)
    issues = [it for it in hard + soft if it.get("key")]
    if args.lang:
        issues = [it for it in issues if it["lang"] in args.lang]
    # 같은 (언어, 키) 가 두 가지 이유로 걸릴 수 있다. 한 번만 고친다.
    seen, uniq = set(), []
    for it in issues:
        sig = (it["lang"], it["key"])
        if sig in seen:
            continue
        seen.add(sig)
        uniq.append(it)
    if args.limit:
        uniq = uniq[:args.limit]
    if not uniq:
        print("✅ 고칠 것이 없다")
        return 0

    by_lang = collections.OrderedDict()
    for it in uniq:
        by_lang.setdefault(it["lang"], []).append(it)

    fixed_total = 0
    for code, items in by_lang.items():
        meta = cfg["languages"][code]
        print(f"🩹 {code} ({meta['native']}): {len(items)}건")
        for i in range(0, len(items), args.chunk):
            batch = items[i:i + args.chunk]
            payload = [collections.OrderedDict([
                ("i", str(n)), ("en", it["en"]), ("bad", it["value"]),
                ("problem", it["why"]), ("c", it["comment"])]) for n, it in enumerate(batch)]
            try:
                got = call_model(REPAIR_PROMPT.format(
                    lang_name=meta["native"], lang_code=code,
                    items=json.dumps(payload, ensure_ascii=False)), args.model)
            except Exception as e:
                print(f"   ⚠️  호출 실패: {e}")
                continue
            for n, it in enumerate(batch):
                v = got.get(str(n))
                if not isinstance(v, str):
                    continue
                entry = collections.OrderedDict([("ko", it["key"]), ("en", it["en"]), ("comment", "")])
                problems = validate_value(cfg, code, entry, v)
                if problems:
                    print(f"   ⚠️  {it['key'][:40]!r}: 고친 것도 걸림 ({problems[0]})")
                    continue
                locs = cat["strings"][it["key"]].setdefault("localizations", collections.OrderedDict())
                locs[code] = collections.OrderedDict([
                    ("stringUnit", collections.OrderedDict([("state", "translated"), ("value", v)]))])
                cat["strings"][it["key"]]["localizations"] = collections.OrderedDict(sorted(locs.items()))
                fixed_total += 1
            print(f"   {min(i + args.chunk, len(items))}/{len(items)}")
            write_catalog(cfg, cat)

    print(f"✅ {fixed_total}건 고쳐 카탈로그에 넣음")
    return 0



INFO_PREFIX = "@InfoPlist/"


def info_key(target, key):
    return f"{INFO_PREFIX}{target}/{key}"


# MARK: - wire: 프로젝트 배선 (여기를 손으로 하면 반드시 빠뜨린다)

def _pbx_id(*parts):
    """Xcode 오브젝트 ID. 같은 입력이면 늘 같은 값이라 wire 를 여러 번 돌려도 안 늘어난다."""
    return hashlib.md5("i18n|".join(parts).encode()).hexdigest()[:24].upper()


STRINGS_HEADER = """/*
  InfoPlist.strings
  {target} ({native})

  ⚠️ scripts/i18n.py wire 가 만든 파일이다. 고칠 곳은 i18n/infoplist.json 과
     i18n/translations/{lang}.json 이다.
*/
"""


def cmd_wire(args):
    cfg = load_cfg()
    info = (jload(INFOPLIST, {}) or {}).get("targets", {})
    pbx_path = os.path.join(ROOT, "ClipKeyboard.xcodeproj", "project.pbxproj")
    pbx = io.open(pbx_path, encoding="utf-8").read()
    before = pbx
    wrote = []

    codes = [c for c in cfg["languages"] if cfg["languages"][c].get("enabled")]

    # 1) InfoPlist.strings 파일
    for code in codes:
        meta = cfg["languages"][code]
        tr = jload(os.path.join(TRANSLATIONS, code + ".json"), {}) or {}
        for target, entries in info.items():
            path = os.path.join(ROOT, target, code + ".lproj", "InfoPlist.strings")
            if os.path.exists(path) and not args.force:
                continue
            lines = [STRINGS_HEADER.format(target=target, native=meta["native"], lang=code)]
            missing = False
            for key, m in entries.items():
                if not m.get("translate"):
                    value = m["en"]          # 앱 이름 같은 고유명사는 영어 그대로
                else:
                    rec = tr.get(info_key(target, key))
                    if not rec:
                        missing = True
                        break
                    value = rec["v"] if isinstance(rec["v"], str) else rec["v"].get("other", "")
                lines.append(f'\n/* {m.get("comment") or key} */\n"{key}" = "{value}";\n')
            if missing:
                print(f"⏭  {target}/{code}: 번역이 아직 없다. translate 를 먼저 돌린다")
                continue
            os.makedirs(os.path.dirname(path), exist_ok=True)
            io.open(path, "w", encoding="utf-8").write("".join(lines))
            wrote.append(f"{target}/{code}.lproj")

    # 2) knownRegions
    m = re.search(r"(knownRegions = \(\n)(.*?)(\t+\);)", pbx, re.S)
    if m:
        body = m.group(2)
        have = set(re.findall(r'"?([\w-]+)"?,', body))
        add = [c for c in codes if c not in have]
        if add:
            indent = re.match(r"(\t+)", body).group(1)
            body = body + "".join(f'{indent}{_quote(c)},\n' for c in add)
            pbx = pbx[:m.start(2)] + body + pbx[m.end(2):]
            print(f"🔧 knownRegions 에 추가: {', '.join(add)}")

    # 3) InfoPlist.strings 를 각 타깃의 variant group 에 물린다
    for vg_id, target in _variant_groups(pbx).items():
        entries = info.get(target)
        if not entries:
            continue
        for code in codes:
            if not os.path.exists(os.path.join(ROOT, target, code + ".lproj", "InfoPlist.strings")):
                continue
            pbx = _ensure_variant_child(pbx, vg_id, target, code)

    if pbx != before:
        io.open(pbx_path, "w", encoding="utf-8").write(pbx)
        print("🔧 project.pbxproj 갱신")
    if wrote:
        print(f"📝 InfoPlist.strings {len(wrote)}개: {', '.join(wrote)}")

    _write_app_language(cfg)
    return 0


def _quote(code):
    return code if re.fullmatch(r"[A-Za-z]+", code) else f'"{code}"'


def _variant_groups(pbx):
    """variant group id → 그것이 들어앉은 그룹(=타깃 폴더) 이름."""
    out = {}
    for gm in re.finditer(r"\w+ /\* (\w+) \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n(.*?)\);\n\t\t\tpath = (\w+);", pbx, re.S):
        name, children, path = gm.group(1), gm.group(2), gm.group(3)
        for cm in re.finditer(r"(\w+) /\* InfoPlist\.strings \*/", children):
            out[cm.group(1)] = path
    return out


def _ensure_variant_child(pbx, vg_id, target, code):
    ref = _pbx_id("infoplist", target, code)
    if ref in pbx:
        return pbx
    # 이미 다른 ID 로 물려 있는 언어를 또 달면 children 이 중복된다.
    # Xcode 는 조용히 빌드하지만 프로젝트 파일이 망가진 채로 남는다.
    m = re.search(re.escape(vg_id) + r" /\* InfoPlist\.strings \*/ = \{\n\t\t\tisa = PBXVariantGroup;\n\t\t\tchildren = \(\n(.*?)\t\t\t\);", pbx, re.S)
    if m and re.search(r"/\* " + re.escape(code) + r" \*/", m.group(1)):
        return pbx
    # 파일 참조를 PBXFileReference 구역에 넣는다
    line = (f'\t\t{ref} /* {code} */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.strings; '
            f'name = {_quote(code)}; path = "{code}.lproj/InfoPlist.strings"; sourceTree = "<group>"; }};\n')
    anchor = "/* End PBXFileReference section */"
    pbx = pbx.replace(anchor, line + anchor, 1)
    # variant group 의 children 에 건다
    m = re.search(re.escape(vg_id) + r" /\* InfoPlist\.strings \*/ = \{\n\t\t\tisa = PBXVariantGroup;\n\t\t\tchildren = \(\n", pbx)
    if not m:
        print(f"⚠️  variant group {vg_id} 를 못 찾음 ({target}/{code})")
        return pbx
    pbx = pbx[:m.end()] + f"\t\t\t\t{ref} /* {code} */,\n" + pbx[m.end():]
    print(f"🔧 {target} 의 InfoPlist.strings 에 {code} 연결")
    return pbx


APP_LANGUAGE = os.path.join("ClipKeyboard", "Service", "AppLanguage.swift")
CASES_BEGIN = "    // i18n:cases:begin"
CASES_END = "    // i18n:cases:end"
NAMES_BEGIN = "    // i18n:names:begin"
NAMES_END = "    // i18n:names:end"


def _swift_case(code):
    parts = re.split(r"[-_]", code)
    return parts[0] + "".join(p[:1].upper() + p[1:] for p in parts[1:])


def _write_app_language(cfg):
    """앱 안 언어 선택 목록을 config.json 에서 다시 쓴다.

    왜 생성하나: 언어를 켤 때마다 스위프트 열거형에 한 줄, 표시 이름에 한 줄을 손으로
    더해야 한다면 40개 중 하나는 반드시 빠진다. 빠지면 그 언어는 번역이 들어 있어도
    앱 안에서 고를 수 없다.
    """
    path = os.path.join(ROOT, APP_LANGUAGE)
    text = io.open(path, encoding="utf-8").read()
    codes = [c for c in cfg["languages"] if cfg["languages"][c].get("enabled")]
    cases = "\n".join(f'    case {_swift_case(c)} = "{c}"' for c in codes)
    names = ["    private static let nativeNames: [String: String] = ["]
    names += [f'        "{c}": "{cfg["languages"][c]["native"]}",' for c in codes]
    names += ["    ]"]
    for begin, end, block in ((CASES_BEGIN, CASES_END, cases),
                              (NAMES_BEGIN, NAMES_END, "\n".join(names))):
        if begin not in text:
            print(f"⚠️  {APP_LANGUAGE} 에 {begin} 표시가 없다. 생성 구간을 먼저 만들어야 한다")
            return
        head = text[:text.index(begin) + len(begin)]
        tail = text[text.index(end):]
        text = head + "\n" + block + "\n" + tail
    io.open(path, "w", encoding="utf-8").write(text)
    print(f"🔧 {APP_LANGUAGE}: 고를 수 있는 언어 {len(codes)}개로 다시 씀")


def main():
    ap = argparse.ArgumentParser(description="다국어 파이프라인")
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("prune").set_defaults(func=cmd_prune)
    p = sub.add_parser("sync")
    p.add_argument("--derived-data", help="Intermediates.noindex 경로 (기본: 가장 최근 빌드)")
    p.set_defaults(func=cmd_sync)

    sub.add_parser("extract").set_defaults(func=cmd_extract)

    p = sub.add_parser("status"); p.add_argument("--all", action="store_true"); p.set_defaults(func=cmd_status)

    p = sub.add_parser("translate")
    p.add_argument("langs", nargs="*")
    p.add_argument("--model", default="sonnet")
    p.add_argument("--chunk", type=int, default=40)
    p.add_argument("--workers", type=int, default=4)
    p.add_argument("--limit", type=int, default=0)
    p.add_argument("--force", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    p.set_defaults(func=cmd_translate)

    sub.add_parser("build").set_defaults(func=cmd_build)

    p = sub.add_parser("repair")
    p.add_argument("--lang", nargs="*")
    p.add_argument("--model", default="sonnet")
    p.add_argument("--chunk", type=int, default=15)
    p.add_argument("--limit", type=int, default=0)
    p.set_defaults(func=cmd_repair)

    p = sub.add_parser("wire"); p.add_argument("--force", action="store_true"); p.set_defaults(func=cmd_wire)

    p = sub.add_parser("check")
    p.add_argument("--xcode", action="store_true")
    p.add_argument("--strict", action="store_true")
    p.add_argument("--limit", type=int, default=30)
    p.set_defaults(func=cmd_check)

    args = ap.parse_args()
    sys.exit(args.func(args))


if __name__ == "__main__":
    main()
