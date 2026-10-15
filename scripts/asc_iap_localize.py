#!/usr/bin/env python3
"""
App Store Connect 인앱 상품 이름 · 설명을 나라마다 그 나라 말로 올린다.

원본은 Config/StoreKit/iap_localizations.json 하나다. 이 스크립트는 그 표를 App Store Connect 에
맞춘다(없는 언어는 만들고, 다른 값은 고친다). 기본은 미리 보기만 하고, --apply 를 붙여야 올린다.

    ASC_ISSUER_ID=... python3 scripts/asc_iap_localize.py            # 무엇이 바뀌는지 보기
    ASC_ISSUER_ID=... python3 scripts/asc_iap_localize.py --apply    # 올리기

키: ASC_KEY_ID (기본 GNK22862R9), ASC_KEY_PATH (기본 ~/Downloads/AuthKey_<id>.p8)
외부 패키지 없이 돈다(서명은 openssl).
"""

import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLE = os.path.join(ROOT, "Config", "StoreKit", "iap_localizations.json")
BUNDLE_ID = "com.Ysoup.TokenMemo"
API = "https://api.appstoreconnect.apple.com"
NAME_MAX = 30
DESC_MAX = 55


# MARK: - 표 읽기

def load_table():
    with open(TABLE, encoding="utf-8") as f:
        t = json.load(f)
    fields = t["fields"]
    out = {}  # product -> locale -> (name, description)
    errors = []
    for pid, spec in t["products"].items():
        out[pid] = {}
        for locale, lang in t["locales"].items():
            row = dict(zip(fields, t["languages"][lang]))
            row["brand"] = t["brand"].get(lang, t["brand"]["*"])
            name = spec["name"].format(**row)
            desc = row[spec["description"]]
            if len(name) > NAME_MAX:
                errors.append(f"{pid} {locale} 이름 {len(name)}자: {name}")
            if len(desc) > DESC_MAX:
                errors.append(f"{pid} {locale} 설명 {len(desc)}자: {desc}")
            if chr(0x2014) in name + desc or chr(0x2013) in name + desc:
                errors.append(f"{pid} {locale} 줄표 금지: {name} / {desc}")
            out[pid][locale] = (name, desc)
    subs = {pid for pid, s in t["products"].items() if s.get("subscription")}
    brands = {loc: t["brand"].get(lang, t["brand"]["*"]) for loc, lang in t["locales"].items()}
    return out, subs, brands, errors


# MARK: - 인증

def b64url(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def der_to_raw(der):
    # ECDSA DER (SEQUENCE { INTEGER r, INTEGER s }) -> r||s 64바이트
    i = 2 if der[1] < 0x80 else 3
    parts = []
    for _ in range(2):
        assert der[i] == 0x02
        n = der[i + 1]
        v = der[i + 2:i + 2 + n]
        parts.append(v[-32:].rjust(32, b"\0"))
        i += 2 + n
    return b"".join(parts)


def make_token(issuer, key_id, key_path):
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    now = int(time.time())
    payload = {"iss": issuer, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"}
    signing = f"{b64url(json.dumps(header).encode())}.{b64url(json.dumps(payload).encode())}"
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path],
                         input=signing.encode(), capture_output=True, check=True).stdout
    return f"{signing}.{b64url(der_to_raw(der))}"


class ASC:
    def __init__(self, token):
        self.token = token

    def call(self, method, path, body=None):
        url = path if path.startswith("http") else API + path
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method, headers={
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
        })
        try:
            with urllib.request.urlopen(req) as r:
                raw = r.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            raise SystemExit(f"❌ [{method} {path}] {e.code} {e.read().decode()[:800]}")

    def all(self, path):
        items, url = [], path
        while url:
            page = self.call("GET", url)
            items += page.get("data", [])
            url = page.get("links", {}).get("next")
        return items


# MARK: - 맞추기

def sync(asc, kind, owner_id, wanted, apply, label):
    """kind: 'iap' | 'sub' | 'group'. wanted: locale -> attributes"""
    list_path, res_type, rel_name, rel_type = {
        "iap": (f"/v2/inAppPurchases/{owner_id}/inAppPurchaseLocalizations?limit=200",
                "inAppPurchaseLocalizations", "inAppPurchaseV2", "inAppPurchases"),
        "sub": (f"/v1/subscriptions/{owner_id}/subscriptionLocalizations?limit=200",
                "subscriptionLocalizations", "subscription", "subscriptions"),
        "group": (f"/v1/subscriptionGroups/{owner_id}/subscriptionGroupLocalizations?limit=200",
                  "subscriptionGroupLocalizations", "subscriptionGroup", "subscriptionGroups"),
    }[kind]
    have = {x["attributes"]["locale"]: x for x in asc.all(list_path)}
    changed = 0
    for locale, attrs in wanted.items():
        cur = have.get(locale)
        if cur and all(cur["attributes"].get(k) == v for k, v in attrs.items()):
            continue
        changed += 1
        before = cur and cur["attributes"].get("name")
        print(f"  {'고침' if cur else '새로'} {label} {locale}: {before + ' → ' if before else ''}{attrs['name']}")
        if not apply:
            continue
        if cur:
            asc.call("PATCH", f"/v1/{res_type}/{cur['id']}",
                     {"data": {"type": res_type, "id": cur["id"], "attributes": attrs}})
        else:
            asc.call("POST", f"/v1/{res_type}",
                     {"data": {"type": res_type, "attributes": {"locale": locale, **attrs},
                               "relationships": {rel_name: {"data": {"type": rel_type, "id": owner_id}}}}})
    return changed


def main():
    apply = "--apply" in sys.argv
    table, subs, brands, errors = load_table()
    if errors:
        print("❌ [asc_iap_localize] 표가 App Store Connect 길이 제한을 넘는다")
        print("\n".join(errors))
        sys.exit(1)
    print(f"✅ [asc_iap_localize] 표 검사 통과: 상품 {len(table)}개 · 언어 {len(next(iter(table.values())))}개")
    if "--check" in sys.argv:
        return

    issuer = os.environ.get("ASC_ISSUER_ID")
    if not issuer:
        sys.exit("❌ ASC_ISSUER_ID 가 필요하다 (App Store Connect > 사용자 및 액세스 > 통합 > API 키)")
    key_id = os.environ.get("ASC_KEY_ID", "GNK22862R9")
    key_path = os.path.expanduser(os.environ.get("ASC_KEY_PATH", f"~/Downloads/AuthKey_{key_id}.p8"))
    asc = ASC(make_token(issuer, key_id, key_path))

    app = asc.call("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")["data"][0]
    print(f"📁 앱 {app['attributes']['name']} ({app['id']}) · 기본 언어 {app['attributes'].get('primaryLocale')}")

    total, missing = 0, []
    iaps = {x["attributes"]["productId"]: x["id"] for x in asc.all(f"/v1/apps/{app['id']}/inAppPurchasesV2?limit=200")}
    for pid, rows in table.items():
        if pid in subs:
            continue
        if pid not in iaps:
            missing.append(pid)
            continue
        wanted = {loc: {"name": n, "description": d} for loc, (n, d) in rows.items()}
        total += sync(asc, "iap", iaps[pid], wanted, apply, pid)

    groups = asc.all(f"/v1/apps/{app['id']}/subscriptionGroups?limit=50")
    sub_ids = {}
    for g in groups:
        for s in asc.all(f"/v1/subscriptionGroups/{g['id']}/subscriptions?limit=200"):
            sub_ids[s["attributes"]["productId"]] = (s["id"], g["id"])
    for pid in subs:
        if pid not in sub_ids:
            missing.append(pid)
            continue
        sid, gid = sub_ids[pid]
        wanted = {loc: {"name": n, "description": d} for loc, (n, d) in table[pid].items()}
        total += sync(asc, "sub", sid, wanted, apply, pid)
        total += sync(asc, "group", gid, {loc: {"name": b} for loc, b in brands.items()}, apply, "구독 묶음")

    for pid in missing:
        print(f"⚠️ App Store Connect 에 없는 상품: {pid}")
    verb = "올림" if apply else "바뀔 것 (--apply 로 올린다)"
    print(f"{'✅' if apply else '📝'} [asc_iap_localize] {verb}: {total}건")


if __name__ == "__main__":
    main()
