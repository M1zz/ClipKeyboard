#!/usr/bin/env python3
"""Replace string literals with central constant references.

Uses scripts/centralize/maps.json produced by gen_constants.py.
  systemName:/systemImage: "X"   -> ...: AppSymbol.<id>
  forKey: "X" (X in known UD set) -> forKey: DefaultsKey.<id>
  (NS)Notification.Name("X")      -> Notification.Name.<id>
  "X.data" (known set)            -> StorageFile.<id>

Generated constant files are skipped. Prints a per-file change summary.
Run with --apply to write; default is dry-run.
"""
import os, re, json, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC_DIRS = ["ClipKeyboard", "ClipKeyboardExtension", "ClipKeyboard.tap"]
GEN_FILES = {"AppSymbol.swift", "DefaultsKey.swift", "AppNotification.swift",
             "StorageFile.swift", "AppGroup.swift"}
APPLY = "--apply" in sys.argv

with open(os.path.join(os.path.dirname(__file__), "maps.json"), encoding="utf-8") as f:
    M = json.load(f)
SYM, KEYS, NOTIFS, DATA = M["symbols"], M["keys"], M["notifs"], M["datafiles"]

def ident(raw):  # strip backticks for member access (backticked member is valid but ugly; keep as-is)
    return raw

# Precompiled patterns
sym_re   = re.compile(r'(systemName|systemImage):(\s*)"([^"]+)"')
forkey_re = re.compile(r'forKey:(\s*)"([^"]+)"')
notif_re = re.compile(r'(?:NS)?Notification\.Name\("([^"]+)"\)')
data_re  = re.compile(r'"([A-Za-z0-9._]+\.data)"')

def swift_files():
    for d in SRC_DIRS:
        for dp, _, names in os.walk(os.path.join(ROOT, d)):
            if "/checkouts/" in dp or "/.build/" in dp:
                continue
            for n in names:
                if n.endswith(".swift") and n not in GEN_FILES:
                    yield os.path.join(dp, n)

totals = {"sym": 0, "key": 0, "notif": 0, "data": 0}

def process(txt):
    counts = {"sym": 0, "key": 0, "notif": 0, "data": 0}

    def sub_sym(m):
        label, sp, name = m.group(1), m.group(2), m.group(3)
        if name in SYM:
            counts["sym"] += 1
            return f"{label}:{sp}AppSymbol.{ident(SYM[name])}"
        return m.group(0)

    def sub_key(m):
        sp, name = m.group(1), m.group(2)
        if name in KEYS:
            counts["key"] += 1
            return f"forKey:{sp}DefaultsKey.{ident(KEYS[name])}"
        return m.group(0)

    def sub_notif(m):
        name = m.group(1)
        if name in NOTIFS:
            counts["notif"] += 1
            return f"Notification.Name.{ident(NOTIFS[name])}"
        return m.group(0)

    def sub_data(m):
        name = m.group(1)
        if name in DATA:
            counts["data"] += 1
            return f"StorageFile.{ident(DATA[name])}"
        return m.group(0)

    txt = sym_re.sub(sub_sym, txt)
    txt = forkey_re.sub(sub_key, txt)
    txt = notif_re.sub(sub_notif, txt)
    txt = data_re.sub(sub_data, txt)
    return txt, counts

for p in swift_files():
    with open(p, encoding="utf-8") as f:
        orig = f.read()
    new, counts = process(orig)
    if any(counts.values()):
        for k in totals:
            totals[k] += counts[k]
        rel = p.replace(ROOT + "/", "")
        print(f"{rel}: sym={counts['sym']} key={counts['key']} notif={counts['notif']} data={counts['data']}")
        if APPLY and new != orig:
            with open(p, "w", encoding="utf-8") as f:
                f.write(new)

print(f"\nTOTALS: {totals}  applied={APPLY}")
