#!/usr/bin/env python3
"""Generate central constant enums from existing string literals.

Scans the three target source dirs, collects:
  - SF Symbol names from systemName:/systemImage: literals  -> AppSymbol
  - UserDefaults keys from forKey: literals (known set)      -> DefaultsKey
  - Notification.Name("...") literals                        -> Notification.Name ext
  - *.data file-name literals                                -> StorageFile

Emits the Swift files and a JSON mapping (for the replacer).
Constant VALUES always equal the exact original string.
"""
import os, re, json, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC_DIRS = ["ClipKeyboard", "ClipKeyboardExtension", "ClipKeyboard.tap"]
GEN_DIR = os.path.join(ROOT, "ClipKeyboard")  # next to AppGroup.swift

# Files we generate — never scan/replace inside these.
GEN_FILES = {"AppSymbol.swift", "DefaultsKey.swift", "AppNotification.swift", "StorageFile.swift"}

SWIFT_KEYWORDS = {
    "repeat", "default", "case", "class", "struct", "enum", "func", "var", "let",
    "return", "switch", "if", "else", "guard", "where", "in", "is", "as", "self",
    "super", "true", "false", "nil", "import", "init", "deinit", "protocol",
    "extension", "operator", "subscript", "static", "public", "private", "internal",
}

def swift_files():
    for d in SRC_DIRS:
        base = os.path.join(ROOT, d)
        for dirpath, _, names in os.walk(base):
            if "/checkouts/" in dirpath or "/.build/" in dirpath:
                continue
            for n in names:
                if n.endswith(".swift") and n not in GEN_FILES:
                    yield os.path.join(dirpath, n)

def read(p):
    with open(p, "r", encoding="utf-8") as f:
        return f.read()

# ---- identifier mapping helpers ----
def camel(parts):
    parts = [p for p in parts if p]
    out = parts[0][:1].lower() + parts[0][1:]
    for p in parts[1:]:
        out += p[:1].upper() + p[1:]
    return out

def sym_ident(s):
    parts = re.split(r"[.]", s)
    ident = camel(parts)
    if ident in SWIFT_KEYWORDS:
        ident = "`" + ident + "`"
    return ident

def key_ident(s):
    parts = re.split(r"[._]", s)
    ident = camel(parts)
    if ident in SWIFT_KEYWORDS:
        ident = "`" + ident + "`"
    return ident

# ---- collect ----
symbols = set()
notifs = set()
datafiles = set()

SYM_RE = re.compile(r'system(?:Name|Image):\s*"([^"]+)"')
NOTIF_RE = re.compile(r'(?:NS)?Notification\.Name\("([^"]+)"\)')
DATA_RE = re.compile(r'"([A-Za-z0-9._]+\.data)"')

# Known UserDefaults keys — exact set, only these forKey: literals get replaced.
UD_KEYS = [
 "autoBackupEnabled","category.feature.enabled.v1","categoryBadgeNudgeDismissed",
 "categoryBadgeVisible","comboModelUnifyMigrated_v1","didRemoveAds",
 "enabledBuiltInCategories_v1","entries","fontSize","hasCompletedOnboarding",
 "hiddenCategoryTabs_v1","kb.beacon.lastUse","kb.beacon.pendingCount",
 "keyboard_extension_did_load","keyboard_paste_count","keyboard_secure_pin_hash",
 "keyboardKoreanEnabled","keyboardTypingLang","koreanEnabledMigrated_v1",
 "lastBackupDate","memoCopyCount","onboarding","pasteTipDismissed",
 "proValueNudgeDismissed_v1","recentEmojis","recentlyUsedCategories",
 "review_banner_dismissed","review_banner_later_date","sampleTemplateFlagsMigrated_v1",
 "secureMemoEncryptionMigrated_v1","showVisualCues","useCaseSelection",
 "userCategoryColors_v1","userCategoryIcons_v1","userDefinedCategories_v1",
 "visualCuesMigrated_v1",
]

for p in swift_files():
    txt = read(p)
    for m in SYM_RE.finditer(txt):
        symbols.add(m.group(1))
    for m in NOTIF_RE.finditer(txt):
        notifs.add(m.group(1))
    for m in DATA_RE.finditer(txt):
        datafiles.add(m.group(1))

# ---- build maps (string -> ident), check collisions ----
def build_map(strings, identfn, label):
    m = {}
    rev = {}
    for s in sorted(strings):
        i = identfn(s)
        if i in rev:
            print(f"!! {label} ident collision: {i} <- {rev[i]} and {s}", file=sys.stderr)
            sys.exit(1)
        rev[i] = s
        m[s] = i
    return m

sym_map = build_map(symbols, sym_ident, "AppSymbol")
key_map = build_map(UD_KEYS, key_ident, "DefaultsKey")
notif_map = build_map(notifs, key_ident, "Notification")
def datafile_ident(s):
    return key_ident(s[:-5])  # strip ".data"
data_map = build_map(datafiles, datafile_ident, "StorageFile")

HEADER = """//
//  {name}
//  ClipKeyboard
//
//  자동 생성 가능 — 정적 {what} 단일 출처(Single Source of Truth).
//  메인앱·키보드(ClipKeyboardExtension)·macOS(.tap) 3개 타겟이 공유한다.
//  하드코딩 리터럴 대신 항상 이 상수를 사용할 것.
//

import Foundation
"""

def write_enum(filename, enumname, what, mapping, value_wrap=lambda s: f'"{s}"'):
    lines = [HEADER.format(name=filename, what=what)]
    lines.append(f"enum {enumname} {{")
    for s in sorted(mapping, key=lambda x: mapping[x].strip("`")):
        ident = mapping[s]
        lines.append(f"    static let {ident} = {value_wrap(s)}")
    lines.append("}")
    lines.append("")
    out = os.path.join(GEN_DIR, filename)
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"wrote {out} ({len(mapping)} entries)")

write_enum("AppSymbol.swift", "AppSymbol", "SF Symbol 이름", sym_map)
write_enum("DefaultsKey.swift", "DefaultsKey", "UserDefaults 키", key_map)
write_enum("StorageFile.swift", "StorageFile", "App Group 저장 파일명", data_map)

# Notification.Name extension (idiomatic)
nlines = [HEADER.format(name="AppNotification.swift", what="Notification 이름")]
nlines.append("extension Notification.Name {")
for s in sorted(notif_map, key=lambda x: notif_map[x].strip("`")):
    nlines.append(f'    static let {notif_map[s]} = Notification.Name("{s}")')
nlines.append("}")
nlines.append("")
with open(os.path.join(GEN_DIR, "AppNotification.swift"), "w", encoding="utf-8") as f:
    f.write("\n".join(nlines))
print(f"wrote AppNotification.swift ({len(notif_map)} entries)")

# Dump mapping for replacer
with open(os.path.join(os.path.dirname(__file__), "maps.json"), "w", encoding="utf-8") as f:
    json.dump({"symbols": sym_map, "keys": key_map, "notifs": notif_map, "datafiles": data_map}, f, ensure_ascii=False, indent=1)
print("wrote maps.json")
print(f"SUMMARY symbols={len(sym_map)} keys={len(key_map)} notifs={len(notif_map)} datafiles={len(data_map)}")
