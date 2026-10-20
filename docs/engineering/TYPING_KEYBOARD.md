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
| `ClipKeyboard/Screens/TypingLanguagesSettings.swift` | 설정 > 키보드 > 입력 언어 | 앱 |

- 언어는 앱이 켠 언어(`i18n/config.json` 의 enabled)와 같다. 시험(`testLanguagesMatchAppLanguages`)이 둘을 맞춘다.
- 배열은 각 나라 iOS 기본 자판을 따른다. 태국어 · 주음은 4줄이다.
- 엔진: 바로 넣기(라틴 · 키릴 · 그리스 · 태국) / 한글(두벌식 · 천지인, 기존 `HangulComposer` · `CheonjiinInput`) /
  베트남어 Telex / 일본어 로마자 → 가나 / 중국어 병음 · 주음.
- 조합 중인 글자는 지웠다 다시 쓴다(앞부분이 같으면 다른 부분만). 키보드 탭의 무대도 같은 길로 움직인다.
- 키보드 확장은 제 영역 밖에 그릴 수 없다. 길게 누른 글자와 한자 후보는 키 위가 아니라 **맨 위 띠**에 선다.
- 키 크기는 판의 폭 · 높이로 계산한다. 높이 설정과 줄 수(3 · 4줄)가 달라도 넘치지 않는다.

## 설정 값 (App Group)

| 키 | 값 |
| --- | --- |
| `keyboardTypingLanguages.v1` | 켜 둔 언어, 쉼표로 이은 rawValue. 비면 **영어 하나**(예전에 한국어를 켰으면 한국어도). 다른 언어는 설정 ▸ 키보드 ▸ 입력 언어에서 더한다. 2026-10 전에 키보드를 띄운 적 있는 사람은 예전 처음 목록(기기 언어 + 영어)을 한 번 저장해 그대로 쓴다(`TypingPrefs.keepLegacyDefaultIfNeeded`) |
| `keyboardTypingCurrent.v1` | 지금 언어 |
| `keyboardInputMode.v1` | 처음 보일 판(typing · snippets). 마지막에 보던 판 |
| `keyboardKoreanLayout` | dubeolsik · cheonjiin (예전 키 그대로) |

`keyboardTypingLang` · `keyboardKoreanEnabled` 는 검색칸 자판이 아직 쓴다. 입력 언어 화면이 저장할 때 함께 맞춘다.

## 단계

1. **자판 틀 + 한국어 · 영어 + 전환 · 설정** - 이 문서와 함께 들어왔다. 23개 언어 배열도 이때 같이 들어왔다.
2. **나머지 언어 손보기** - 원어민 눈으로 배열 · 길게 누르기 순서를 확인한다(태국어 Kedmanee, 주음, 체코어 QWERTZ).
3. **자동 수정 · 추천 낱말 · 문장 첫 글자 대문자 · 스페이스 두 번 마침표** - `UITextChecker` · `UILexicon`.
4. **일본어 · 중국어 한자 변환** - 아래.

## 4단계: 변환 사전을 필요할 때 받기

- 받는 것은 **앱**이 한다. 키보드 확장은 메모리 한도가 작고, 전체 접근 없이는 네트워크를 못 쓴다.
- 사용자가 입력 언어에 일본어 · 중국어를 켜면 앱이 그 언어 사전만 받아 App Group 에 둔다.
- 키보드는 사전을 메모리에 다 올리지 않고 메모리 매핑으로 필요한 곳만 읽는다(`ConversionDictionary`).
- 둘 곳 후보: CloudKit 공개 데이터베이스의 에셋, 또는 iOS 26 의 Apple-hosted Background Assets. 둘 다 앱 용량을 늘리지 않는다.
- 데이터는 상업 앱에 쓸 수 있는 공개 라이선스 자료에서 고른다. 표시 의무가 있으면 설정 > 정보에 적는다.
- 사전이 오기 전에는 가나 · 병음 · 주음까지만 친다. 자판 맨 위 띠와 입력 언어 화면이 그 사실을 말한다.

## 시험

- `ClipKeyboardTests/TypingEnginesTests.swift`: 언어표 모양, 터키어 대문자, 두벌식 쌍자음, 길게 누르기 순서,
  처음 언어(영어 하나) · 기존 사용자 목록 지키기 · 기기 언어 고르기, 한글 조합, Telex(모양 · 성조 · 되돌리기), 로마자 → 가나, 후보 고르기.
- `ClipKeyboardUITests`: `testTypingKeyboardComposesHangul` - 키보드 탭에서 자판으로 바꿔 "한글" 이 들어가는지.
- 진짜 키보드(남의 앱)에서 치는 것은 XCUITest 로 못 본다. 기기에서 손으로 본다.
