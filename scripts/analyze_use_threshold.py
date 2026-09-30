#!/usr/bin/env python3
"""결제 문턱을 '단축어를 N번 쓴 뒤' 로 옮기면 어떻게 되나 - 허브 스냅샷으로 미리 재 본다.

묻는 것 세 가지:
  1. 쓴 횟수(uses)가 어떻게 퍼져 있나. N번에 닿은 설치는 몇 % 인가
  2. N번에 닿는 데 며칠 걸리나 (uses / daysSinceInstall 로 속도를 재 추정)
  3. 많이 쓴 사람일수록 이미 더 많이 결제했나 (구간별 결제율)

쓰는 법:
  xcrun cktool save-token --type management   # 한 번 (브라우저에서 토큰 복사)
  xcrun cktool save-token --type user         # 한 번
  python3 scripts/analyze_use_threshold.py            # 받아서 분석
  python3 scripts/analyze_use_threshold.py --cached   # 받아 둔 것으로 다시 분석

데이터: CloudKit 공개 DB `iCloud.com.Ysoup.FeedbackHub` 의 `UsageSnapshot`.
설치당 한 레코드이고 metrics 는 JSON 글자다(UsageReportingService.currentMetrics).
내용·식별자는 없다. 개수와 0/1 플래그뿐이다.
"""
import json
import os
import statistics
import subprocess
import sys

TEAM = "QGAQ3AY3R3"
CONTAINER = "iCloud.com.Ysoup.FeedbackHub"
APP_ID = "com.Ysoup.TokenMemo"
CACHE = os.path.join(os.path.dirname(__file__), "..", "build", "usage_snapshots.json")
THRESHOLDS = [30, 50, 100, 150, 200, 300]


def field(record, name):
    value = record.get("fields", {}).get(name)
    if isinstance(value, dict):
        return value.get("value")
    return value


def fetch():
    records, token = [], None
    while True:
        cmd = ["xcrun", "cktool", "query-records", "--team-id", TEAM, "--container-id", CONTAINER,
               "--environment", "production", "--database-type", "public",
               "--record-type", "UsageSnapshot", "--limit", "200"]
        if token:
            cmd += ["--continuation-token", token]
        out = subprocess.run(cmd, capture_output=True, text=True)
        if out.returncode != 0:
            sys.exit("❌ cktool 실패 (토큰을 다시 저장해야 할 수 있음):\n" + (out.stderr or out.stdout)[:600])
        page = json.loads(out.stdout)
        records += page.get("records", [])
        token = page.get("continuationToken")
        print(f"   {len(records)}건 받음", file=sys.stderr)
        if not token:
            break
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    with open(CACHE, "w") as f:
        json.dump(records, f)
    return records


def rows(records):
    out = []
    for r in records:
        if field(r, "appId") not in (None, APP_ID):
            continue
        try:
            metrics = json.loads(field(r, "metrics") or "{}")
        except (TypeError, json.JSONDecodeError):
            continue
        days = field(r, "daysSinceInstall")
        out.append({
            "uses": metrics.get("uses", 0) or 0,
            "days": max(1, int(days)) if days is not None else None,
            "paid": metrics.get("flag.isPaid", 0) == 1,
            "comped": metrics.get("flag.isComped", 0) == 1,
            "own": metrics.get("ownShortcuts", metrics.get("shortcuts", 0)) or 0,
            "keyboard": metrics.get("flag.keyboardActive", 0) == 1,
        })
    return out


def pct(n, d):
    return f"{(100 * n / d):5.1f}%" if d else "   -  "


def main():
    if "--cached" in sys.argv and os.path.exists(CACHE):
        records = json.load(open(CACHE))
    else:
        records = fetch()
    data = rows(records)
    # 공짜로 Pro 를 받은 사람(TestFlight, 예전 무료 사용자 인정)은 결제 판단에서 뺀다.
    data = [d for d in data if not d["comped"]]
    total = len(data)
    if not total:
        sys.exit("❌ 이 앱의 스냅샷이 없습니다")

    uses = sorted(d["uses"] for d in data)
    print(f"\n설치 {total}개 (TestFlight · 인정 Pro 제외)")
    print(f"쓴 횟수: 중앙값 {statistics.median(uses):.0f} · 상위 25% {uses[int(total * .75)]:.0f} "
          f"· 상위 10% {uses[int(total * .9)]:.0f}")

    print("\n## 1·2. 문턱 N 에 닿은 설치, 닿기까지 걸린 날")
    print("   N    닿음         닿은 사람의 걸린 날(추정 중앙값)   아직 못 닿은 사람이 닿기까지(추정 중앙값)")
    for n in THRESHOLDS:
        reached = [d for d in data if d["uses"] >= n]
        # 걸린 날은 '하루 평균 속도가 일정했다' 고 보고 되짚는다. 앞쪽에 몰아 쓴 사람은 짧게 잡힌다.
        took = [n / (d["uses"] / d["days"]) for d in reached if d["days"]]
        remaining = [(n - d["uses"]) / (d["uses"] / d["days"])
                     for d in data if d["uses"] < n and d["uses"] > 0 and d["days"]]
        took_text = f"{statistics.median(took):6.0f}일" if took else "     -"
        remaining_text = f"{statistics.median(remaining):6.0f}일" if remaining else "     -"
        print(f"  {n:4d}  {len(reached):5d} {pct(len(reached), total)}   {took_text}"
              f"                          {remaining_text}")

    print("\n## 3. 쓴 횟수 구간별 결제율 (지금 모델 기준)")
    edges = [0, 1, 10, 30, 50, 100, 200, 10**9]
    for lo, hi in zip(edges, edges[1:]):
        group = [d for d in data if lo <= d["uses"] < hi]
        paid = sum(d["paid"] for d in group)
        label = f"{lo}~{hi - 1}" if hi < 10**9 else f"{lo}+"
        print(f"  {label:>9}  설치 {len(group):5d}  결제 {paid:4d}  {pct(paid, len(group))}")

    overall = sum(d["paid"] for d in data)
    print(f"\n전체 결제율 {pct(overall, total)} ({overall}/{total})")
    print("⚠️ uses 는 지금 남아 있는 단축어의 사용 합이다. 지운 단축어의 횟수는 빠진다.")
    print("⚠️ 걸린 날은 평균 속도로 되짚은 추정이다. 실제 날짜 기록이 아니다.")


if __name__ == "__main__":
    main()
