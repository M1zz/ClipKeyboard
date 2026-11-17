# 자판: 쓰던 키보드를 지우고 이 키보드 하나로

> 한 줄: 사용자가 시스템 키보드를 지우고 클립키보드만으로 글을 치면서, 같은 키보드에서 단축어까지 쓴다.

## 왜

예전(2026-05 이전)에도 영어 QWERTY · 한글 두벌식 · 천지인 자판이 있었다. 카테고리 아이콘 작업
(`1bc4ec9c`) 때 단축어 판 · 자판 탭이 함께 빠졌고, 6월 정리(`38c0f59d`)에서 자판 코드가 지워졌다.
일부러 내린 결정이 아니었다. 그 사이 사용자는 글을 치려면 다른 키보드로 건너가야 했다.

## 구조

| 파일 | 하는 일 | 타깃 |
| --- | --- | --- |
| `ClipKeyboardExtension/TypingLayouts.swift` | 언어 23개: 이름 · 배열 · Shift 판 · 길게 누르기 · 숫자 층 돈 기호 · 입력 방식 | 앱 · 키보드 · 시험 |
| `ClipKeyboardExtension/TypingEngines.swift` | 입력 방식(엔진). `TypingInputProxy` 도 여기 | 앱 · 키보드 · 시험 |
| `ClipKeyboardExtension/TypingKeyboardView.swift` | 자판 화면. 키 그리기 · 손가락 받기 | 앱 · 키보드 |
| `ClipKeyboardExtension/ConversionDictionaryFile.swift` | 중국어 한자 사전 파일 읽기(메모리 매핑) · 고른 낱말 기억 | 앱 · 키보드 · 시험 |
| `ClipKeyboardExtension/Dictionaries/` | `zh-Hans.ckdict`(병음) · `zh-Hant.ckdict`(주음) · 재료의 라이선스 | 키보드(리소스) |
| `scripts/make_typing_dictionary.py` | 위 사전 파일을 만든다 | |
| `ClipKeyboard/Screens/TypingLanguagesSettings.swift` | 설정 > 키보드 > 입력 언어 | 앱 |

- 언어는 앱이 켠 언어(`i18n/config.json` 의 enabled)와 같다. 시험(`testLanguagesMatchAppLanguages`)이 둘을 맞춘다.
- 배열은 각 나라 iOS 기본 자판을 따른다. 태국어 · 주음은 4줄이다.
- 엔진: 바로 넣기(라틴 · 키릴 · 그리스 · 태국) / 한글(두벌식 · 천지인, 기존 `HangulComposer` · `CheonjiinInput`) /
  베트남어 Telex / 일본어 로마자 → 가나 / 중국어 병음 · 주음 → 한자.
- 조합 중인 글자는 지웠다 다시 쓴다(앞부분이 같으면 다른 부분만). 키보드 탭의 무대도 같은 길로 움직인다.
- 키보드 확장은 제 영역 밖에 그릴 수 없다. 길게 누른 글자와 한자 후보는 키 위가 아니라 **맨 위 띠**에 선다.
- 키 크기는 판의 폭 · 높이로 계산한다. 높이 설정과 줄 수(3 · 4줄)가 달라도 넘치지 않는다.

## 설정 값 (App Group)

| 키 | 값 |
| --- | --- |
| `keyboardTypingLanguages.v1` | 켜 둔 언어, 쉼표로 이은 rawValue. 비면 **그 사람의 언어 + 영어**: 앱에서 고른 언어 → 기기 언어 → iOS 에 켜 둔 키보드의 언어(앱이 `keyboardUserKeyboardLanguages.v1` 에 적는다), 영어는 늘(예전에 한국어를 켰으면 한국어도). 설정 ▸ 키보드 ▸ 입력 언어에서 더하고 뺀다. 2026-10 전에 키보드를 띄운 적 있는 사람은 예전 처음 목록(기기 언어 + 영어)을 한 번 저장해 그대로 쓴다(`TypingPrefs.keepLegacyDefaultIfNeeded`) |
| `keyboardTypingCurrent.v1` | 지금 언어 |
| `keyboardInputMode.v1` | 처음 보일 판(typing · snippets). 마지막에 보던 판 |
| `keyboardKoreanLayout` | dubeolsik · cheonjiin (예전 키 그대로) |

`keyboardTypingLang` · `keyboardKoreanEnabled` 는 검색칸 자판이 아직 쓴다. 입력 언어 화면이 저장할 때 함께 맞춘다.

## 단계

1. **자판 틀 + 한국어 · 영어 + 전환 · 설정** - 이 문서와 함께 들어왔다. 23개 언어 배열도 이때 같이 들어왔다.
2. **나머지 언어 손보기** - 원어민 눈으로 배열 · 길게 누르기 순서를 확인한다(태국어 Kedmanee, 주음, 체코어 QWERTZ).
3. **자동 수정 · 추천 낱말 · 문장 첫 글자 대문자 · 스페이스 두 번 마침표** - `UITextChecker` · `UILexicon`.
4. **중국어 한자 변환** - 들어왔다(2026-11). 아래.
5. **일본어 한자 변환** - 아직. 가나까지만 친다.

## 4단계: 중국어 한자 변환

2026-11 중국 사용자 의견 "为什么用输入法无法输入汉字" 로 들어왔다. 그 전까지 중국어 자판은 병음 글자만 넣었고,
자판 위 띠는 "사전은 앱의 키보드 설정에서 받아요" 라고 했지만 받는 곳이 없었다.

- **사전은 키보드 확장 번들에 들어 있다.** 처음 계획은 필요할 때 받는 것이었다(CloudKit 공개 DB · Background Assets).
  그러면 받기 전에는 한자를 못 치고, 받는 길이 하나 더 고장 날 수 있다. 두 파일 합쳐 4.9MB(압축하면 절반쯤)라 그냥 싣는다.
  앱 용량이 문제가 되면 `ConversionDictionaryStore.fileURL` 에 App Group 자리를 더하고 파일을 밖으로 옮기면 된다.
- 앱(키보드 탭의 무대)은 제 번들이 아니라 안에 든 키보드 확장의 파일을 읽는다. 한 벌만 싣는다.
- 키보드는 파일을 메모리에 올리지 않는다. 메모리 매핑으로 열고 이분 탐색으로 필요한 곳만 읽는다(`MappedConversionDictionary`).
- 후보 순서: 전에 고른 것 → 읽기 전체와 같은 낱말 · 덜 친 낱말 → 낱말로 잘라 이은 한 줄 → 앞부분만 바꾸는 낱말(긴 것부터).
  통째로 없는 긴 읽기("jintiantianqihenhao")는 한 줄로 이은 것이 맨 앞에 선다.
- 앞부분만 바꾸는 후보를 고르면 남은 읽기는 밑줄 친 채 남는다(`ConversionMatch.consumed`).
- 주음은 성조 없이 찾는다. 성조 기호(ˊ ˇ ˋ ˙)는 쳐도 되고 안 쳐도 된다. 1성은 스페이스(첫 후보 고르기).
- 고른 낱말은 읽기별로 3개, 읽기 400개까지 App Group UserDefaults 에 남는다(`DefaultsKey.typingLearnedConversions`). 기기 밖으로 안 나간다.
- 재료: jieba 낱말 빈도표(MIT) · pypinyin 읽기(MIT) · OpenCC 간체 → 번체(Apache-2.0). 번들의 `LICENSES.txt` 에 적혀 있다.
  사전을 다시 만드는 법은 `scripts/make_typing_dictionary.py` 머리말.

아직 없는 것: 간체 약자 입력(nh → 你好), 병음 끊기 기호('), 대만 읽기와 어휘(번체는 간체 낱말을 글자만 바꾼 것이다), 사용자 사전.

## 시험

- `ClipKeyboardTests/TypingEnginesTests.swift`: 언어표 모양, 터키어 대문자, 두벌식 쌍자음, 길게 누르기 순서,
  처음 언어(그 사람의 언어 + 영어) · 켜 둔 키보드 읽기 · 기존 사용자 목록 지키기 · 기기 언어 고르기, 한글 조합, Telex(모양 · 성조 · 되돌리기), 로마자 → 가나, 후보 고르기.
- `ClipKeyboardTests/ChineseConversionTests.swift`: 실리는 진짜 사전 파일로 병음 → 한자, 앞부분만 고르기, 긴 문장, 주음, 고른 낱말 기억, 깨진 파일.
- `ClipKeyboardUITests`: `testTypingKeyboardComposesHangul` - 키보드 탭에서 자판으로 바꿔 "한글" 이 들어가는지.
- 진짜 키보드(남의 앱)에서 치는 것은 XCUITest 로 못 본다. 기기에서 손으로 본다.
