# App Store 피처링 추천 (Featuring Nominations), 2026-10-21 작성

붙여 넣을 곳: App Store Connect ▸ 앱 ▸ 클립키보드 ▸ **Featuring** ▸ **Nominations** ▸ (+) 새 추천.
영어 칸(`Description`, `Helpful Details`)은 에디터가 읽는 글이라 그대로 붙여 넣는다. 한국어는 요약이다.

앵글 원고는 `docs/marketing/APPLE_FEATURING_STORIES.md` 에 있다. 이 파일은 그중 **지금 날짜에 낼 세 건**을
2026-10 현재 사실로 고쳐 쓴 것이다. 그 문서의 몇몇 사실은 낡았으니 섞어 쓰지 않는다(맨 아래 "낡은 주장").

## 폼이 묻는 것 (공식 안내로 확인, 2026-10-21)

출처: [Getting featured](https://developer.apple.com/app-store/getting-featured/) ·
[Nominate your app for featuring](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring)

| 칸 | 무엇을 넣나 | 비고 |
| --- | --- | --- |
| Name | 추천 이름(내부용) | |
| Type | `New Content` · `App Enhancements` · `App Launch` 중 하나 | 제출 뒤에는 유형·관련 앱을 못 바꾼다 |
| Description | 무엇이 바뀌는지, 목적과 **우선순위**를 분명히 | 공식 글자 한도 없음. 아래 글은 1,000~1,400자 |
| Publish date | 하루(Day) 또는 기간(Range) | 내 기기 시간대 기준 |
| Related apps | 같은 계정 앱 최대 10개 | 클립키보드 하나만 |
| Platforms | iPhone · iPad | 인앱 이벤트는 iPhone · iPad 앱만 |
| Relevant Countries or Regions | 판매 중인 나라가 자동 선택됨, 고칠 수 있음 | 아래 건마다 제안 |
| Localizations | 앱 로케일 자동 선택 | 24개 그대로 둔다 |
| In-App Events | 승인됐거나 게시된 이벤트를 붙일 수 있다 | "가능한 한 일찍 붙이라"고 권한다 |
| Supplemental Materials | URL 최대 5개 | 아래 건마다 제안 |
| Helpful Details | 접근성 · 포용성 · 우선순위 · 팀 이야기 | |

시기: 개발자 페이지는 "최소 2주 전", 도움말은 "최소 3주 전"이라고 한다. **3주를 기준으로 잡는다.**
넓게 검토받으려면 최대 3개월 전까지 낸다. 탈락 통보는 없다.

## 한눈에

| # | 유형 | 이름 | 게시 기간 | 늦어도 낼 날 | 붙일 이벤트 |
| --- | --- | --- | --- | --- | --- |
| 1 | App Enhancements | One keyboard for 23 languages | 2026-11-18 ~ 2026-12-17 | **2026-10-28** | `typing-23` (IN_APP_EVENTS.md) |
| 2 | New Content | Holiday Pro gifting | 2026-12-12 ~ 2027-01-06 | 2026-11-21 | `holiday-gift` |
| 3 | App Enhancements | Retype less in the new year | 2026-12-28 ~ 2027-01-18 | 2026-11-07 (STORIES 6절: 11월 초) | 없음 |

---

## 1. One keyboard for 23 languages

**한국어 요약**: 5.1.13(2026-10-21 현재 심사 대기)에서 키보드가 iPhone 기본 키보드와 같은 배열의 **자판**을
다시 갖췄다. 23개 언어를 치면서 같은 키보드에서 단축어를 넣고, 단축어를 넣으면 쓰던 키보드로 돌아간다.
다국어 사용자에게 "키보드를 바꾸지 않아도 되는" 이야기라 현지화·혁신 기준에 맞춘다.
게시 기간을 인앱 이벤트 `typing-23` 과 같게 잡았다. 업데이트 자체는 그보다 먼저(10월 말) 나가지만,
에디터가 실을 창을 이벤트 기간에 맞춘다.

- **Name**: `ClipKeyboard 5.1.13: One keyboard for 23 languages`
- **Type**: `App Enhancements`
- **Publish date**: Range `2026-11-18` ~ `2026-12-17`
- **Countries or Regions**: 전체 유지. 다만 **일본 · 중국 본토 · 대만 · 홍콩은 빼는 것을 권한다.**
  일본어 · 중국어는 지금 가나 · 병음 · 주음까지만 치고 한자 변환이 없다(`docs/engineering/TYPING_KEYBOARD.md` 4단계).
  그 나라 에디터가 보기에 "23개 언어"는 반쪽이다.
- **Localizations**: 24개 그대로.
- **In-App Events**: `typing-23` 이 승인되면 붙인다.
- **Supplemental Materials**:
  1. `https://apps.apple.com/app/id1543660502`
  2. `https://m1zz.github.io/ClipKeyboard/en/`
  3. (있으면) TestFlight 공개 링크
- **근거**: 커밋 `cf4b4f7e`(23개 언어 자판), `aebb532c`(iOS 기본 키보드 모양 · 천지인 10키), `eb59b36e`(단축어 뒤 쓰던 키보드로),
  `2c361f2e`(처음 켤 언어 = 그 사람의 언어 + 영어). 태그 `deploy-ClipKeyboard-5.1.13-37` 에 모두 들어 있다.
  `ClipKeyboardExtension/TypingLayouts.swift`(언어 23개), `TypingEngines.swift`(한글 · Telex · 로마자→가나 · 병음 · 주음).

**Description** (1,356자)

```
Priority: high. This is the largest change to ClipKeyboard this year.

ClipKeyboard keeps the things people type again and again (account numbers, addresses, standard replies, templates with blanks) inside the keyboard, so they go in with one tap in any app. Until now it was a keyboard you switched to for a moment and then left.

Version 5.1.13 makes it a keyboard you can stay on. It now has full typing layouts for 23 languages that follow each country's iPhone layout: QWERTZ, AZERTY, Russian ЙЦУКЕН, Thai Kedmanee, Turkish Q, Zhuyin, and Korean in both the 2-set and the 10-key Cheonjiin layout. Vietnamese uses Telex, Japanese turns romaji into kana, Chinese takes Pinyin and Zhuyin. Saved snippets sit on the same keyboard, so there is no switching between "the keyboard I type on" and "the keyboard that remembers".

For people who write in more than one language every day, which is most of our users outside Korea and the United States, this removes the most common interruption: hunting for the globe key to reach a phrase they saved.

The first languages turned on are chosen from the person's own app language, device language and the iOS keyboards they already use, plus English. Nothing to set up.

Honest limit: Japanese and Chinese currently type kana, Pinyin and Zhuyin; kanji and hanzi conversion is the next step on our public roadmap.
```

**Helpful Details** (728자)

```
Solo developer in Korea (Leeo). No QA team, so the app ships with close to a thousand automated tests, including tests that check every one of the 23 layouts against the app's language list.

Accessibility: 179 VoiceOver labels and 85 hints across the app and the keyboard extension. Visual cues have non-color alternatives (Differentiate Without Color).

Localization: the app and its App Store page are available in 24 App Store localizations, each with its own localized screenshots.

Privacy: what people save stays on the device or in their own iCloud. No third-party analytics SDK.

Business model: free to start; Pro is a one-time purchase or a yearly subscription. A public in-app roadmap shows what is being built next.
```

---

## 2. Holiday Pro gifting

**한국어 요약**: 5.1.12 부터 설정에서 **Pro 를 선물**할 수 있다. 보내는 사람이 결제하면 코드가 생기고, 받는 사람이
앱에서 코드를 넣으면 평생 Pro 와 같아진다. 연말 선물 시즌(12월 중순~1월 초)에 맞춘 `New Content`(공식 정의: "new content,
offers, or events in your app") 추천이고, 인앱 이벤트 `holiday-gift` 를 붙인다.

⚠️ **내기 전 확인**: 선물 상품 `com.Ysoup.TokenMemo.gift.pro` 가 App Store Connect 에서 판매 중이고, 출시 빌드에서
실제로 사고 받는 데까지 된다는 것. 설정의 선물 줄은 상품이 와야만 보인다(`SettingView.giftSection`). 안 되면 이 건은 내지 않는다.

- **Name**: `ClipKeyboard: Holiday Pro gifting`
- **Type**: `New Content`
- **Publish date**: Range `2026-12-12` ~ `2027-01-06`
- **Countries or Regions**: 전체 유지 (선물 상품이 팔리는 모든 나라).
- **In-App Events**: `holiday-gift` 승인 뒤 붙인다.
- **Supplemental Materials**: App Store 링크, 영문 소개 페이지.
- **근거**: `fca03ab4`(설정에서 Pro 선물하고 코드 넣기), `cbbf5fa4`(선물이 안 되면 결제 내용과 함께 문의), `a974a8f9`(개발자 선물 시험),
  `ClipKeyboard/Service/ClipKeyboardSpec.swift` 의 `gift: LeeoGiftConfig(... grantsProductID: StoreManager.proProductID ...)`.

**Description** (991자)

```
Priority: medium. A seasonal spotlight on a feature we shipped this autumn.

ClipKeyboard now lets people give Pro to someone else. In Settings, the giver pays once and receives a short gift code to send in any messaging app. The recipient opens ClipKeyboard, enters the code, and gets the same lifetime Pro as a purchase, with every limit lifted. The giver can see whether the gift has been received.

Why it fits the holidays: the people who benefit most from ClipKeyboard are often not the ones who find it. A parent who types the same bank details to every relative, a friend who runs a small shop from their phone, a colleague who answers the same customer questions all day. Gifting lets an existing user hand the app over fully set up for that person, without asking them to make a purchase decision.

During the event window we will feature gifting in the app and on our support page. No price change is required to take part, and gifting works in every storefront where Pro is sold.
```

**Helpful Details** (328자)

```
Solo developer in Korea (Leeo). The gift flow was built with a support path for the case where something goes wrong: the person can contact us from the gift screen with the purchase details attached, so no one is left with a paid gift that does not arrive.

Available in 24 App Store localizations. No third-party analytics SDK.
```

> "During the event window we will feature gifting in the app" 는 인앱 이벤트 카드(`holiday-gift`)를 가리킨다.
> 앱 안에 따로 배너를 만들 계획이 없으면 이 문장에서 `in the app and` 를 지운다.

---

## 3. Retype less in the new year

**한국어 요약**: 12월 말~1월 중순 생산성 컬렉션용(STORIES 6절 앵글). 새 기능 하나가 아니라 가을에 나온 세 가지
(23개 언어 자판, 동작 버튼 · 제어 센터로 복사한 글 담기, 단축어 마트의 준비된 상황들)를 "새해에 같은 걸 두 번 치지 않기"로 묶는다.

- **Name**: `ClipKeyboard: Retype less in the new year`
- **Type**: `App Enhancements`
- **Publish date**: Range `2026-12-28` ~ `2027-01-18` (3개월 안쪽)
- **Countries or Regions**: 전체 유지.
- **In-App Events**: 없음.
- **근거**: 자판(1번과 같음), `widget/CaptureClipboardControl.swift` · 로드맵 `capture.button` = `.shipped("5.1.12")`,
  `ClipKeyboard/Screens/Memo/ShortcutMartView.swift` · `PersonaGuideData.swift`(쓰임새별 준비된 상황).

**Description** (972자)

```
Priority: medium. A New Year productivity story built on three updates from this autumn.

Most productivity apps ask people to adopt a system. ClipKeyboard asks for nothing: it lives in the keyboard they already use, and the things they retype all day stop needing to be retyped.

What changed this season:
- Typing in 23 languages on iPhone-style layouts, with saved snippets on the same keyboard, so there is no switching back and forth.
- Copy something, then press the Action button or a Control Center control, and it is waiting in the keyboard's Recent row.
- New users do not start from a blank page. The Shortcut Mart offers ready-made situations, such as sharing an account number, asking for a payment, or an out-of-office reply, picked for the kind of work the person said they do. They fill in only the parts that are theirs; the parts that change stay as blanks to complete as they type.

It is a productivity app that succeeds when you spend less time in it.
```

**Helpful Details**: 1번의 Helpful Details 를 그대로 쓴다.

---

## 낡은 주장 (기존 문서에서 가져오지 말 것)

| 기존 문서의 문장 | 지금 사실 |
| --- | --- |
| "one-time $9.99 Pro, no subscription" (`APPLE_FEATURING_PITCH.md`, `PRODUCT_HUNT_LAUNCH.md`) | 연 구독도 있다(`StoreManager.yearlyProductID`). Plus · Pro 트림이 있다. 가격은 적지 않는다 |
| "Zero data collection" | 서드파티 분석 SDK 는 없지만, 익명 사용 통계를 자기 CloudKit 허브로 보낸다(`AnalyticsService.swift`). "No third-party analytics SDK" 로만 쓴다 |
| "Korean and English" | 앱 23개 언어, 스토어 24개 로케일 |
| "116 labels, 61 hints", "over 600 tests" | 2026-10-21 기준 `accessibilityLabel` 179 · `accessibilityHint` 85, 테스트 함수 992개 |
| "It does not replace the keyboard you type on" (`APPSTORE.md` 설명) | 5.1.13 부터 자판이 있다. **APPSTORE.md 설명을 다음 배포 전에 고쳐야 한다**(이 작업에서는 손대지 않았다) |
| Apple Developer Academy 멘토 직함 | 코드로 확인할 수 없다. 넣으려면 직접 표기를 확인한다 |
