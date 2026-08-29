#!/usr/bin/env python3
"""docs/*.html 의 번체(zh-Hant) 데이터를 간체(zh-Hans) 에서 다시 만든다.

앱에서 쓰는 것과 **같은 방식**이다(scripts/make_zh_hant.py 참고).
  1) 글자: macOS ICU 변환(Hans-Hant) - scripts/zh_hant_transform.swift
  2) 말  : 대만 어휘·「」 인용부호 - scripts/zh_hant_vocab.py

페이지의 자바스크립트 안에 있는 `const NAME = { 'zh-Hans': ..., 'zh-Hant': ... }` 를
통째로 다시 써넣는다. 값이 문자열이면 어디에 있든(중첩 객체·배열) 다 바꾼다.

쓰는 법:
    python3 scripts/make_zh_hant_web.py                 # docs 전체
    python3 scripts/make_zh_hant_web.py docs/index.html # 한 파일만

⚠️ 간체를 먼저 채운 뒤에 돌린다. 간체가 없는 덩어리는 건드리지 않는다.
⚠️ 통화처럼 지역이 다르면 값 자체가 달라지는 것은 OVERRIDES 에 적는다.
   (중국 ¥68 / 대만 NT$320 - App Store Connect 의 실제 가격)
"""
import io
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))
from zh_hant_vocab import to_taiwan  # noqa: E402

SWIFT = os.path.join(ROOT, 'scripts', 'zh_hant_transform.swift')
MARK = '⏎'

# 파일 → 데이터이름 → 키 → 번체에서 쓸 값. 글자 변환으로는 못 얻는 것만 적는다.
OVERRIDES = {
    'index.html': {
        'translations': {
            'priceDesc': 'Pro 升級 NT$320 · 一次買斷 · 7 天免費試用',
        },
    },
}


def transform(lines):
    if not lines:
        return []
    out = subprocess.run(['swift', SWIFT], input='\n'.join(lines),
                         capture_output=True, text=True, check=True).stdout.split('\n')
    if out and out[-1] == '':
        out.pop()
    assert len(out) == len(lines), f'줄 수가 어긋남: {len(lines)} → {len(out)}'
    return out


def walk_strings(node, bucket):
    """중첩된 값에서 문자열만 순서대로 모은다."""
    if isinstance(node, str):
        bucket.append(node)
    elif isinstance(node, list):
        for v in node:
            walk_strings(v, bucket)
    elif isinstance(node, dict):
        for v in node.values():
            walk_strings(v, bucket)


def rebuild(node, it):
    if isinstance(node, str):
        return next(it)
    if isinstance(node, list):
        return [rebuild(v, it) for v in node]
    if isinstance(node, dict):
        return {k: rebuild(v, it) for k, v in node.items()}
    return node


def js_objects(html, name):
    """`const NAME = {...}` 의 여는 괄호와 닫는 괄호 위치."""
    i = html.index('const ' + name)
    j = html.index('=', i) + 1
    while html[j] in ' \n\t':
        j += 1
    open_ch = html[j]
    close_ch = {'{': '}', '[': ']'}[open_ch]
    depth = 0
    k = j
    instr = None
    esc = False
    while k < len(html):
        c = html[k]
        if instr:
            if esc:
                esc = False
            elif c == '\\':
                esc = True
            elif c == instr:
                instr = None
        elif c in '"\'`':
            instr = c
        elif c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return j, k
        k += 1
    raise AssertionError(name)


def read_data(path, names):
    """페이지 스크립트를 평가해 상수들을 JSON 으로 꺼낸다 (DOM 은 인형으로 대신)."""
    script = os.path.join(ROOT, 'scripts', '_extract_page_data.mjs')
    out = subprocess.run(['node', script, path, ','.join(names)],
                         capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError(f'{path} 데이터 추출 실패: {out.stderr[:400]}')
    return json.loads(out.stdout)


def process_spans(path):
    """`<span class="zh-hans">…</span><span class="zh-hant">…</span>` 로 된 페이지
    (accessibility.html). 간체 스팬에서 번체 스팬을 다시 만든다."""
    html = io.open(path, encoding='utf-8').read()
    pairs = re.findall(r'<span class="zh-hans">(.*?)</span><span class="zh-hant">(.*?)</span>',
                       html, re.S)
    if not pairs:
        print(f'{os.path.basename(path)}: 간체 스팬 없음, 건너뜀')
        return 0
    hans = [a for a, _ in pairs]
    hant = [to_taiwan(x).replace(MARK, '\n')
            for x in transform([h.replace('\n', MARK) for h in hans])]
    it = iter(hant)
    html = re.sub(r'(<span class="zh-hans">)(.*?)(</span><span class="zh-hant">)(.*?)(</span>)',
                  lambda m: m.group(1) + m.group(2) + m.group(3) + next(it) + m.group(5),
                  html, flags=re.S)
    io.open(path, 'w', encoding='utf-8').write(html)
    print(f'{os.path.basename(path)}: 스팬 {len(pairs)}쌍 재생성')
    return 1


def process(path):
    if os.path.basename(path) == 'accessibility.html':
        return process_spans(path)
    html = io.open(path, encoding='utf-8').read()
    names = [m.group(1) for m in re.finditer(r'const ([A-Za-z_][\w]*) = [\[{]', html)]
    names = [n for n in names if "'zh-Hans'" in html[html.find('const ' + n):
                                                     html.find('const ' + n) + 200000]]
    data = read_data(path, names) if names else {}
    changed = 0
    for name in names:
        block = data.get(name)
        if not isinstance(block, dict) or 'zh-Hans' not in block:
            continue
        hans = block['zh-Hans']
        bucket = []
        walk_strings(hans, bucket)
        hant_lines = transform([s.replace('\n', MARK) for s in bucket])
        hant = [to_taiwan(x).replace(MARK, '\n') for x in hant_lines]
        built = rebuild(hans, iter(hant))
        for key, value in OVERRIDES.get(os.path.basename(path), {}).get(name, {}).items():
            built[key] = value
        # 기존 zh-Hant 를 통째로 갈아 끼운다(없으면 zh-Hans 뒤에 넣는다)
        a, b = js_objects(html, name)
        obj = json.loads(html[a:b + 1]) if False else None  # JS 라 직접 파싱하지 않는다
        body = json.dumps(built, ensure_ascii=False, indent=1)
        pat = re.compile(r"(\n\s*)'zh-Hant':\s*", re.S)
        seg = html[a:b + 1]
        if "'zh-Hant':" in seg:
            s2, e2 = value_span(seg, seg.index("'zh-Hant':"))
            seg = seg[:s2] + body + seg[e2:]
        else:
            s2, e2 = value_span(seg, seg.index("'zh-Hans':"))
            seg = seg[:e2] + ",\n            'zh-Hant': " + body + seg[e2:]
        html = html[:a] + seg + html[b + 1:]
        changed += 1
    if changed:
        io.open(path, 'w', encoding='utf-8').write(html)
    print(f'{os.path.basename(path)}: 덩어리 {changed}개 재생성')
    return changed


def value_span(seg, key_at):
    """`'zh-Hans': <값>` 에서 <값>의 시작과 끝(배타) 위치."""
    j = seg.index(':', key_at) + 1
    while seg[j] in ' \n\t':
        j += 1
    open_ch = seg[j]
    close_ch = {'{': '}', '[': ']'}[open_ch]
    depth = 0
    k = j
    instr = None
    esc = False
    while k < len(seg):
        c = seg[k]
        if instr:
            if esc:
                esc = False
            elif c == '\\':
                esc = True
            elif c == instr:
                instr = None
        elif c in '"\'`':
            instr = c
        elif c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return j, k + 1
        k += 1
    raise AssertionError('값의 끝을 못 찾음')


if __name__ == '__main__':
    targets = sys.argv[1:] or [os.path.join(ROOT, 'docs', f) for f in
                               ('index.html', 'tutorial.html', 'privacy.html', 'terms.html',
                                'accessibility.html')]
    total = 0
    for t in targets:
        total += process(t if os.path.isabs(t) else os.path.join(ROOT, t))
    print('총', total, '덩어리')
