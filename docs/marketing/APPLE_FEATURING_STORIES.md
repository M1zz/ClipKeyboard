# 🍎 Apple 피처링 노미네이션, 시나리오별 스토리 모음

> 제출처: https://developer.apple.com/app-store/promote/ (App Store Featuring Nomination)
> 대상 앱: Clip Keyboard - Quick Phrases (id 1543660502), 현재 4.4.6
> 관련 문서: 폼 필드별 짧은 문안은 `docs/marketing/APPLE_FEATURING_PITCH.md`, 이 파일은 **앵글별 본문**이다.

## 이 문서가 서 있는 전제

1. **노미네이션에는 피드백 루프가 없다.** 탈락 통보도, 이유 설명도 없다.
   그래서 "뽑힐 확률을 올리는 일"과 "피드백을 받는 일"은 다른 채널로 나눠서 해야 한다(9절).
2. **제출은 무제한이고 불이익이 없다.** 같은 앱이라도 모멘트마다 다른 앵글로 다시 낸다.
   이 문서가 앵글을 미리 다 써 두는 이유다. 때가 오면 고민하지 말고 복사해서 낸다.
3. **에디터의 일을 대신해 주는 글이 뽑힌다.** 에디터는 하루에 수백 건을 읽는다.
   기능 나열은 스킵된다. 이기는 포맷은 **그대로 Today 탭에 옮겨 실을 수 있는 문장**이다.
   각 시나리오의 "에디터가 그대로 쓸 수 있는 문장"이 사실상 본체다.

---

## 0. 공통 재료 (코드로 검증된 사실만)

과장은 한 번 걸리면 그 다음 노미네이션까지 죽는다. 아래는 저장소에서 확인한 것만 적는다.

| 쓸 수 있는 주장 | 근거 |
|---|---|
| 온디바이스 Apple Intelligence (분류 · 붙여넣을 앱 예측 · 번역) | `ClipKeyboard/Service/AppleIntelligenceService.swift`, Foundation Models `SystemLanguageModel`, iOS 26+ 게이트 |
| 제어센터 컨트롤 2종 | `widget/CopyValueControl.swift`, `widget/QuickNoteControl.swift` |
| App Intents + App Shortcuts (Siri · 단축어 앱) | `ClipKeyboard/App/QuickNoteAppIntents.swift`, `widget/AppIntent.swift` |
| 위젯 | `widget/widget.swift`, WidgetKit |
| 기기 간 실시간 동기화 | `ClipKeyboard/Service/MemoSyncEngine.swift`, CKSyncEngine |
| 사진 속 글자 인식 | `ClipKeyboard/Service/OCRService.swift`, Vision |
| iOS 26 디자인 언어 대응 | `glassEffect` 사용 5개 화면, `scrollEdgeEffectHidden` |
| 키보드 · 공유 · 액션 확장 3종 | `ClipKeyboardExtension`, `ClipKeyboardShareExtension`, `ClipKeyboardActionExtension` |
| 접근성 | `accessibilityLabel` 116곳, `accessibilityHint` 61곳, `accessibilityAddTraits` 24곳, 46개 파일. 색 외 구분 수단(`differentiateWithoutColor`) |
| Face ID 잠금 | `LocalAuthentication`, 보안 단축어 |
| 구독 없음, 일회성 결제 | StoreKit 2, `ProStatusManager` |
| 기존 유료 구매자 무상 승계 | `AppTransaction.originalPurchaseDate` 기반 그랜드파더링 (v4.0 프리미엄 전환 시) |
| 분석 SDK 0개 | Firebase 를 4.3.9 에서 제거. 남은 것은 CloudKit 익명 집계뿐 |
| 자동 테스트 600건 이상 | `ClipKeyboardTests` 의 테스트 함수 676개 |
| 한국어 · 영어 | `Localizable.xcstrings`, 원본 ko 2,085키에 en 번역 2,076건 |

### ⛔️ 쓰면 안 되는 문장

- **"visionOS 지원"**: 근거 없음. `TARGETED_DEVICE_FAMILY = 1,2` (iPhone · iPad) 뿐이다.
- **"인도네시아어 지원"**: 9317416 에서 제거했다. 카탈로그에 4키만 남은 잔재다.
- **"Mac 앱 포함"**: Mac 은 **별도 앱 · 별도 저장소**(`~/workspace/code/ClipKeyboardMac`)다.
  "iPhone 과 Mac 을 오간다"는 맞고, "한 앱이 두 플랫폼에서 돈다"는 틀리다.
- **Full Access 없이 전 기능**: 핵심 입력은 되지만 클립보드 읽기 등은 아니다. 범위를 붙여 쓸 것.

---

## 1. 개발자 스토리 앵글 (상시, 가장 강함)

에디터가 Today 탭에 싣는 인디 앱 글은 대부분 **사람 이야기**다. 기능은 그 다음이다.
이 앵글은 다른 모든 앵글에 얹을 수 있는 바닥이므로 먼저 둔다.

> ⚠️ 아래 두 사실은 리오님이 주신 것이라 코드로 검증할 수 없다. 제출 전 표현을 직접 확인할 것.
> (경력 연차, Apple Developer Academy @ POSTECH 멘토 직함의 정확한 영문 표기)

**한 줄 훅**
> 낮에는 다음 세대 개발자를 가르치고, 밤에는 자기 앱의 접근성을 손본다.

**Helpful Details 본문 (영문, 복붙용)**
```
I am a solo developer with ten years of shipping iOS apps, and I mentor at
Apple Developer Academy @ POSTECH in Korea. I teach students by day and build
this app at night, which is why it is put together the way it is: every visual
cue in the app has a non-color alternative, every control has a VoiceOver
label, and the whole thing ships with over 600 automated tests because there
is no QA team behind me.

ClipKeyboard exists because I kept watching people retype the same bank
account number, the same address, the same canned reply, several times a day.
It puts those inside the keyboard itself, so they go in with one tap in any
app. Everything a user copies is classified on device into fifteen semantic
types. Nothing is sent anywhere: there is no analytics SDK in the binary and
no server of mine to send it to.

When the app moved from paid to freemium, every existing paying customer was
grandfathered into Pro for free rather than being asked to buy again. Pro is
still a one-time purchase. There is no subscription and there will not be one.
```

**에디터가 그대로 쓸 수 있는 문장**
- "A mentor at Apple's own developer academy in Korea, building the app he wishes his students would build."
- "No analytics SDK, no server, no subscription. Just a keyboard that remembers."
- "When he switched to freemium, he let everyone who had already paid keep everything."

**준비물**: 개발자 사진 1장, 작업 공간 사진 1장. 인물 스토리 앵글은 사진이 없으면 실리지 못한다.

---

## 2. 새 OS 런치 앵글 (9월, 지금 가장 급한 것)

애플 캘린더에 올라타는 앵글이다. 새 OS 출시 직후는 에디터가 **"새 OS 기능을 쓴 앱"을
의무적으로 찾아야 하는 기간**이라 수요가 있는 시장이다. 경쟁이 아니라 공급 부족 쪽이다.

**제출 시기**: 새 OS 정식 출시 4~6주 전. 9월 출시라면 **8월 중순이 마감선**이다.

> 📌 새 OS 의 구체적 기능명은 이 문서를 쓴 시점에 확정되지 않았다. 아래 `[NEW_OS_FEATURE]`
> 자리에 **실제로 구현해서 넣은 것 하나**를 적는다. 구현하지 않은 것을 적으면 안 된다.
> 이미 있는 재료로 대체 가능한 후보: 새 디자인 언어 대응 완료, 새 App Intents 표면,
> 제어센터 컨트롤 확장.

**한 줄 훅**
> 새 OS 가 나오는 날, 이미 그 기능을 쓰고 있는 키보드.

**Helpful Details 본문 (영문, 복붙용)**
```
We are shipping an update built on [NEW_OS_FEATURE] on the day the new OS
becomes available. The work is done and in TestFlight now; the release is
scheduled for [DATE].

ClipKeyboard has adopted new platform surfaces early for several releases in a
row, so this is not a one-off: on-device Foundation Models classify what the
user copies and suggest which app to paste it into, two Control Center
controls copy a saved value or capture a note without opening the app, App
Intents expose the same actions to Siri and Shortcuts, and the interface has
already been rebuilt for the current design language.

For a keyboard extension, these surfaces matter more than they do for most
apps: the entire point is to not make someone leave what they are doing.
```

**에디터가 그대로 쓸 수 있는 문장**
- "Updated on day one, not three months later."
- "Two Control Center buttons mean you never open the app to paste an account number."

**준비물**: 실제 배포 날짜. **날짜가 적힌 건이 먼저 검토된다.** "곧"이라고 쓰면 안 된다.

---

## 3. 접근성 앵글 (5월 셋째 목요일 GAAD, 그리고 상시)

경쟁이 가장 적고, 리오님이 실제 전문성으로 뒷받침할 수 있는 영역이다.
애플은 접근성 컬렉션을 매년 돌리는데 **후보 앱이 늘 모자란다.**

**제출 시기**: 세계 접근성 인식의 날(5월 셋째 목요일) 6~8주 전. 즉 **3월 하순**.

**한 줄 훅**
> 타이핑을 줄이는 것이 누군가에게는 편의가 아니라 접근의 문제다.

**Helpful Details 본문 (영문, 복붙용)**
```
For most people a text expander saves seconds. For someone with limited motor
control, a tremor, or chronic pain, the number of keystrokes needed to send an
address is the difference between doing it and not doing it. That is the frame
we build in.

What is actually in the app:
- Every interactive element has a VoiceOver label, and 61 of them carry hints
  that explain what happens next rather than restating the label.
- Every visual cue that distinguishes one snippet from another has a
  non-color alternative. The app honors Differentiate Without Color, and by
  default snippet cards show titles only, so the list stays readable before
  any customization.
- Dynamic Type throughout, including inside the keyboard extension, which is
  where most keyboard apps stop caring.
- Sensitive entries can be locked behind Face ID, so a shared or assisted
  device does not expose them.
- Korean and English, fully localized rather than machine translated.

The developer mentors at Apple Developer Academy @ POSTECH and teaches this
as the default way to build, not as a late pass over a finished app.
```

**에디터가 그대로 쓸 수 있는 문장**
- "For some people, fewer keystrokes is not convenience. It is access."
- "Accessibility that reaches inside the keyboard extension, where most apps stop."

**준비물**: VoiceOver 로 주요 흐름을 통과하는 30초 영상. 접근성 앵글은 **증명이 곧 자산**이다.

---

## 4. 온디바이스 AI · 프라이버시 앵글

애플이 가장 반복해서 미는 서사(기기 안에서 처리한다)와 정확히 겹친다.
"AI 앱" 컬렉션은 상시로 채워야 하는 자리라 수요가 꾸준하다.

**제출 시기**: 상시. Apple Intelligence 관련 발표 직후 2주가 가장 좋다.

**한 줄 훅**
> 클립보드는 사람이 가진 가장 사적인 데이터다. 그래서 한 줄도 밖으로 내보내지 않는다.

**Helpful Details 본문 (영문, 복붙용)**
```
A clipboard sees bank details, passwords on their way to a manager, medical
notes, addresses. It is arguably the most sensitive stream on the device. We
treat it that way.

Everything the app understands about your content is worked out on the device.
Foundation Models classify what you copied, suggest which app you are likely
to paste it into, and translate a snippet, all locally, with a rules based
classifier as the fallback on devices without Apple Intelligence. Fifteen
semantic types are detected, including bank account numbers validated by
checksum rather than by shape alone.

There is no analytics SDK in the binary. We removed the last one in 4.3.9.
There is no server we own. Data lives in the App Group container and, only if
the user turns it on, in their own private CloudKit database. Optional
device-to-device sync uses CKSyncEngine, so it never passes through us either.

This is also why the business model is a one-time purchase. We do not need
recurring revenue from data we refuse to collect.
```

**에디터가 그대로 쓸 수 있는 문장**
- "The most private stream on your phone, and it never leaves it."
- "No analytics SDK. Not a stripped-down one. None."

**준비물**: 앱 프라이버시 라벨이 본문과 정확히 일치하는지 확인(`docs/product/APP_PRIVACY_ANSWERS.md`).
라벨과 주장이 어긋나면 이 앵글은 역효과다.

---

## 5. 한국 스토어 · 로컬 문화 앵글

한국 에디토리얼 팀은 **한국에서만 말이 되는 앱**을 찾는다. 글로벌 앵글로는 안 보이는 자리다.

**제출 시기**: 상시. 명절 정산 시즌(설 · 추석) 4주 전이 특히 좋다.

**한 줄 훅**
> 한국에서 산다는 건 계좌번호를 하루에 몇 번씩 옮겨 적는다는 뜻이다.

**Helpful Details 본문 (영문, 복붙용, 한국 에디토리얼 팀도 영문 폼을 읽는다)**
```
In Korea, splitting a bill, paying a vendor, or getting reimbursed all start
the same way: someone types out a bank account number, digit by digit, into a
chat window. People do it several times a day and get it wrong often enough
that "check the number again" is a normal thing to say.

ClipKeyboard was built around that specific daily friction. The classifier
knows the local formats that generic clipboard managers miss: resident
registration numbers, business registration numbers, personal customs clearance
codes, and Korean bank account patterns, checked in a deliberate order so an
eight digit date is never mistaken for an account number. Templates cover the
phrasing that goes with them, so "Name, bank, account number, amount" arrives
as one tap instead of four.

The app is Korean-first, written in Korean and translated to English, not the
other way around.
```

**에디터가 그대로 쓸 수 있는 문장**
- "계좌번호를 옮겨 적다 틀리는 일이 없어진다."
- "한국에서 쓰는 번호 체계를 아는 클립보드."

**준비물**: 한국어 스크린샷 세트(이미 `marketing/shots.json` 에 있음).

---

## 6. 연말 · 새해 생산성 앵글

12월 하순부터 1월은 생산성 컬렉션이 매년 서는 자리다. 경쟁은 세지만 슬롯도 많다.

**제출 시기**: **11월 초**. 12월에 내면 이미 편성이 끝나 있다.

**한 줄 훅**
> 새해 결심은 앱을 더 쓰는 것이 아니라, 같은 걸 두 번 치지 않는 것이다.

**Helpful Details 본문 (영문, 복붙용)**
```
Most productivity apps ask you to adopt a system. This one asks for nothing:
you keep using the same apps, with the same keyboard, and the things you retype
all day stop needing to be retyped.

New users do not start from a blank page. The Shortcut Mart offers ready-made
situations, sharing your account number, asking for a settlement, an
out-of-office reply, filtered to the kind of work you said you do. You fill in
only the parts that are yours; the parts that change every time stay as blanks
you complete as you go.

It is the rare productivity app where the measure of success is that you spend
less time in it, not more.
```

**에디터가 그대로 쓸 수 있는 문장**
- "A productivity app that succeeds when you stop looking at it."
- "No system to adopt. It lives in the keyboard you already use."

---

## 7. 애플 생태계 연속성 앵글

"기기 사이를 오간다"는 애플이 언제나 좋아하는 축이다.
다만 **Mac 은 별도 앱**이라는 점을 숨기지 말고 그대로 쓴다.

**제출 시기**: 상시. Mac 앱 업데이트와 iOS 업데이트를 같은 주에 내면 그때.

**한 줄 훅**
> 아이폰에서 저장하고, 맥에서 붙여 넣는다. 사이에 아무 단계도 없다.

**Helpful Details 본문 (영문, 복붙용)**
```
Save a snippet on the iPhone and it is on the Mac before you have switched
chairs. Sync runs on CKSyncEngine over the user's own private CloudKit
database, with deletions and edits converging correctly rather than only
additions, which is where most homegrown sync quietly fails.

On iPhone and iPad the library is reachable from the keyboard itself, from
two Control Center controls, from widgets, from the share sheet, and from Siri
and the Shortcuts app through App Intents. On the Mac it lives in the menu bar
with a global hotkey. Same library, whichever surface you happen to be near.

The Mac companion is a separate app, and anyone who owns it is treated as Pro
on that machine.
```

**에디터가 그대로 쓸 수 있는 문장**
- "Saved on the phone, pasted on the Mac, with nothing in between."

**준비물**: iPhone 과 Mac 이 함께 나오는 사진 또는 영상.

---

## 8. 앱 업데이트 정규 앵글 (재사용 템플릿)

메이저 기능이 나갈 때마다 쓰는 기본형이다. 위 앵글 중 하나를 골라 앞에 얹어 쓴다.

**제출 시기**: 배포 **4~6주 전**. 이미 나간 기능으로는 잘 안 된다.

```
Shipping [DATE], now in TestFlight.

[가장 큰 것 하나를 두 문장으로. 기능 이름이 아니라 사라진 불편으로 쓴다.]

Why it matters for the platform: [사용한 애플 기술 한 줄. 0절 표에서 고른다.]

Context: solo developer, no analytics SDK, one-time purchase with no
subscription, Korean and English, over 600 automated tests.
```

> 이 마지막 "Context" 세 줄은 **모든 앵글에 넣는다.** 에디터가 앱을 분류하는 데 쓰는 정보다.

---

## 9. 피드백은 노미네이션 밖에서 받는다

노미네이션은 답을 주지 않는다. 피드백은 다른 세 곳에서 온다.

| 경로 | 시기 | 무엇을 얻나 |
|---|---|---|
| **WWDC 랩** (App Store 랩 · 디자인 랩) | 6월 | 애플이 피처링 관점의 의견을 주는 사실상 유일한 공식 창구. "피처링 관점에서 뭐가 부족한가"를 직접 물을 수 있다 |
| **Academy 멘토라는 위치** | 상시 | 청탁이 아니라 "데모를 보여주고 소감을 듣는" 방식. 애플 쪽 사람이 앱을 이미 만져 본 상태로 심사 시즌에 들어가는 것 자체가 자산이다 |
| **App Analytics 의 Browse 트래픽** | 주간 | 소규모 컬렉션 피처링은 **알림 없이** 이뤄지는 경우가 많다. 소스 타입 "App Store 탐색"이 갑자기 튀면 어딘가 실렸다는 신호이고, 어떤 앵글이 반응했는지 역추적할 수 있는 유일한 데이터다 |

**주간 루틴 하나**: App Analytics > 소스 타입 > Browse 를 주 1회 본다. 평소 대비 2배 이상
튀는 주가 있으면 그 주에 무엇이 실렸는지 찾고, **그 앵글을 다음 노미네이션에 다시 쓴다.**

---

## 10. 제출 캘린더

| 시기 | 앵글 | 마감선 |
|---|---|---|
| 8월 중순 | **2. 새 OS 런치** | 지금. 9~10월 슬롯은 여기서 닫힌다 |
| 9월 | 1. 개발자 스토리 (새 OS 건이 떨어졌다고 가정하고 각도만 바꿔 재제출) | 상시 |
| 11월 초 | 6. 연말 · 새해 생산성 | 12월에 내면 늦다 |
| 12월 | 5. 한국 로컬 (설 정산 시즌 대비) | 설 4주 전 |
| 3월 하순 | **3. 접근성** (GAAD) | 5월 셋째 목요일 6~8주 전 |
| 6월 | 9. WWDC 랩 예약 | 랩 예약은 기조연설 직후 몇 시간 안에 마감된다 |
| 상시 | 4. 온디바이스 AI · 프라이버시 / 7. 생태계 / 8. 업데이트 | 메이저 배포 4~6주 전 |

---

## 11. 제출 전 5분 점검

에디터가 노미네이션을 읽고 **처음 하는 행동은 제품 페이지를 여는 것**이다.
본문이 아무리 좋아도 페이지가 낡았으면 거기서 끝난다.

- [ ] 스크린샷이 현재 버전의 화면인가 (`marketing/out` 이 최신인지)
- [ ] **앱 프리뷰 영상이 걸려 있는가.** 없으면 이것부터. `marketing/video/clipkeyboard-demo-en.mp4` 가 있다
- [ ] 첫 스크린샷 한 장만 보고 이 앱이 뭔지 알 수 있는가
- [ ] 이번 버전의 새로운 기능이 최신인가 (`docs/RELEASE_NOTES_*.md`)
- [ ] 앱 프라이버시 라벨이 4절의 주장과 어긋나지 않는가
- [ ] 최근 리뷰에 미응답 별점 1~2개가 쌓여 있지 않은가
- [ ] 본문에 0절의 "쓰면 안 되는 문장"이 섞여 들어가지 않았는가

---

## 12. 다른 앱에 이 프레임을 재사용할 때

앵글 자체는 앱과 무관하다. 바꾸는 것은 **증거**뿐이다.

1. 0절과 같은 표를 그 앱 저장소에서 만든다. 코드로 확인되지 않는 주장은 표에 넣지 않는다.
2. 1절(개발자 스토리)은 그대로 쓴다. 사람은 앱마다 바뀌지 않는다.
3. 앱의 성격에 맞는 앵글 두세 개만 고른다. 아홉 개를 다 쓰면 어느 것도 날카롭지 않다.
4. 10절 캘린더는 공용이다. 앱이 여럿이면 **같은 시기에 서로 다른 앵글로** 낸다.
