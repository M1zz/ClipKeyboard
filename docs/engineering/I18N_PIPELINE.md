# 여러 언어를 사람 손 없이 유지하는 법

> 한 줄: **카탈로그는 산출물이다.** 사람이 보는 원본은 `i18n/` 에 있고,
> 언어를 켜는 일은 `i18n/config.json` 의 `enabled` 를 `true` 로 바꾸는 것뿐이다.

## 왜 이렇게 했나

5.0.7 시점의 `ClipKeyboard/Localizable.xcstrings` 는 키 2,680개에 1.9 MB 였다.
여기에 언어를 40개 넣으면 파일이 15 MB 를 넘고, 문자열 하나를 고칠 때마다 diff 가
40줄씩 튄다. 리뷰가 불가능해지는 순간 번역 품질을 지킬 방법도 같이 사라진다.

그리고 이미 한 번 겪었다. `id`(인도네시아어) 는 2,680개 중 283개만 채워진 채로 멈췄고,
`.lproj` 폴더까지 만들어졌지만 `knownRegions` 에 없어 실제로는 나가지도 않았다.
**손으로 시작한 언어는 중간에서 멈춘다.**

## 구조

```
i18n/
  config.json              언어 목록 하나의 출처. enabled 가 곧 출시 여부다
  glossary.json            번역기가 흔들리지 않게 못 박은 말 (단축어=Фраза 처럼)
  infoplist.json           앱 이름·권한 문구의 원본
  source.json              ko 원문 + en(피벗) + comment + 원문 해시   ← extract 가 만든다
  retired.json             코드에 없는 죽은 키. 번역 대상에서 뺀다
  translations/<lang>.json 언어당 한 파일. diff 가 언어별로 갈린다
```

```
                   extract                translate               build
Localizable.xcstrings ──▶ source.json ──▶ translations/ru.json ──▶ Localizable.xcstrings
        ▲                                                                  │
        └──────────── Xcode 가 새 키를 여기 넣는다 ◀────────────────────────┘
                                                          wire ──▶ pbxproj · .lproj · AppLanguage.swift
```

`ko` · `en` · `zh-Hans` 는 사람이 쓴 글이라 파이프라인이 건드리지 않는다(`mode: human`).
`zh-Hant` 는 `scripts/make_zh_hant.py` 가 간체에서 뽑는다(`mode: derived`).
나머지는 전부 `mode: machine` 이다.

## 하는 일

```bash
python3 scripts/i18n.py sync        # 새 NSLocalizedString 을 카탈로그로 (Xcode 없이)
python3 scripts/i18n.py prune       # 죽은 키를 골라 retired.json 으로
python3 scripts/i18n.py extract     # 카탈로그 → source.json
python3 scripts/i18n.py status      # 언어별 번역·낡음·빠짐
python3 scripts/i18n.py translate ru --workers 5
python3 scripts/i18n.py build       # translations/* → 카탈로그
python3 scripts/i18n.py wire        # knownRegions · InfoPlist.strings · AppLanguage.swift
python3 scripts/i18n.py check       # 게이트 (커밋·배포에 물려 있다)
```

번역은 중간에 끊겨도 된다. 묶음마다 저장하고, 다시 돌리면 **빠진 것과 원문이 바뀐 것만** 한다.
원문이 바뀌었는지는 `ko + en + comment` 의 해시로 안다.

### 새 문구를 더했으면

`xcodebuild` 는 문자열 카탈로그를 채워 주지 않는다. 그건 Xcode 앱이 하는 일이다.
그래서 `sync` 가 대신한다. **두 곳을 본다.**

1. 빌드가 남긴 `.stringsdata` (`xcstringstool sync`)
2. **소스의 `NSLocalizedString` 직접 훑기**

②가 왜 필요한가: 스위프트 컴파일러가 `.stringsdata` 에 담는 것은 `String(localized:)`
같은 것뿐이고, 이 저장소가 쓰는 `NSLocalizedString(...)` 은 거기 안 들어간다
(`AISettingsView.stringsdata` 를 열면 `tables` 가 비어 있다). ①만 믿으면 새 문구가 조용히
번역 대상에서 빠지고, 그 언어 사용자만 한국어를 본다.

`comment:` 는 번역기가 읽는다. 옮기면 안 되는 것이 있으면 거기 적는다.
실제로 통했던 예: "Keep the ICU pattern letters (yyyy, M, d) exactly as they are,
they are code, not words" 를 적었더니 러시아어에서도 `MMM d, yyyy` 가 그대로 남았다.

### 새 언어 하나를 켜는 순서

1. `i18n/config.json` 에서 그 언어의 `enabled` 를 `true` 로
2. `i18n/glossary.json` 의 `terms` · `tokens` 에 그 언어 칸을 채운다.
   **번역을 돌리기 전에** 한다. 묶음을 병렬로 돌리므로 안 정해 두면 묶음마다 다른 단어를 고른다
3. `python3 scripts/i18n.py translate <lang>`
4. `python3 scripts/i18n.py build && python3 scripts/i18n.py wire`
5. `python3 scripts/i18n.py check` 가 통과해야 커밋된다

## 검사가 절반이다

40개 언어를 사람이 눈으로 볼 수 없다. 그래서 `check` 가 유일한 품질 보증이다.
커밋(`.git/hooks/pre-commit`)과 배포(`scripts/predeploy.sh`) 양쪽에 물려 있다.

**차단하는 것**

| 검사 | 왜 |
| --- | --- |
| 자리표시자 불일치 (`%@` `%d` `%lld` `%1$@`) | 개수·종류가 어긋나면 런타임에 쓰레기 값이 찍히거나 죽는다 |
| 한국어가 남아 있음 | 그 언어 사용자가 한글을 본다. 원문에 한글이 있는 문구(한/EN 토글)는 예외 |
| 긴 줄표 (U+2014 · U+2013) | 저장소 전 범위 규칙 (CLAUDE.md) |
| 빈 값 | |
| **커버리지 100% 아님** | `id` 처럼 반쯤 하다 만 언어를 다시 만들지 않기 위한 것. 켰으면 다 채워야 한다 |

**경고만 하는 것** (`--strict` 로 차단으로 올린다)

| 검사 | 왜 |
| --- | --- |
| 줄바꿈 수 불일치 | 여러 줄 문구가 첫 줄만 남고 잘려 나간 경우를 잡는다 |
| `{ }` 개수 불일치 | 채우는 칸이 사라졌다 |
| 사람이 채우는 언어의 미번역 | en · zh-Hans 는 손이 늦은 것뿐이라 막지 않는다 |

## 자동으로 안 되는 것

- **RTL (ar · he)**: 글이 아니라 레이아웃 문제다. `.leading/.trailing`, 키보드 키 배열,
  악어 연출 좌표가 전부 뒤집힌다. `tier: 9` 로 따로 세워 두었고, 레이아웃 작업 전에는 켜지 않는다
- **긴 언어 (de · ru · fi)**: 한국어 대비 1.6~1.7배로 늘어난다. 키보드 익스텐션의 좁은 버튼이 깨진다.
  `config.json` 의 `expansion` 이 번역기에 길이 상한으로 들어가지만, 실제 확인은 화면으로 해야 한다
- **앱스토어 키워드**: 번역이 아니라 그 나라 사람이 실제로 검색하는 말이다. 100자 제한이라 기계번역은 낭비

## 복수형

러시아어·폴란드어처럼 형태가 여러 개인 언어는 `%d` 하나만 든 문구에 한해
`one / few / many / other` 를 따로 받아 카탈로그의 `variations.plural` 로 넣는다.
인자가 둘 이상인 문구(`'%1$@' 에 단축어 %2$d개`)는 `substitutions` 를 써야 하는데,
그건 아직 안 한다. 그런 문구는 소유격 복수 한 형태로 나가고 대부분 자연스럽게 읽힌다.

## 번역기

`claude` CLI 를 그대로 쓴다. API 키를 따로 두지 않아도 개발 머신에서 바로 돈다.

```bash
python3 scripts/i18n.py translate ru --model sonnet --chunk 40 --workers 5
```

한 묶음이 검사에 걸리면 그 항목만 문제를 적어 다시 물어보고(1회),
그래도 안 되면 저장하지 않는다. 저장되지 않은 항목은 `status` 의 "빠짐" 으로 남고
`check` 가 커밋을 막으므로 조용히 새어 나가지 않는다.
