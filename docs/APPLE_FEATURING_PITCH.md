# 🍎 Apple 피처링 신청, 제출용 텍스트

> 제출처: https://developer.apple.com/app-store/promote/ (App Store Featuring Nomination)
> 소요: 10분. 비용 0원. 인디 앱도 접근성·최신 OS 대응이 좋으면 실제로 선정됨.
> ClipKeyboard의 어필 포인트: **접근성(VoiceOver·색 외 구분) + 온디바이스 AI + 프라이버시(데이터 수집 0) + 구독 없는 가격 모델**
>
> 📌 **앵글별 본문은 `docs/APPLE_FEATURING_STORIES.md`.** 이 파일은 폼 필드에 넣을 짧은 문안이고,
> 저쪽은 시기·상황별로 골라 쓰는 Helpful Details 본문 아홉 가지다. 검증된 근거 표도 그쪽에 있다.

---

## 제출 폼 필드별 텍스트

**App Name**: Clip Keyboard - Quick Phrases (id 1543660502)

**What makes your app unique?**
```
ClipKeyboard is a clipboard manager that lives inside the iOS keyboard itself.
Users save frequently typed content once: bank details, addresses, canned
replies: and insert it with one tap in any app. Everything copied is
auto-classified into 15 semantic types (email, phone, IBAN with ISO 13616
checksum validation, addresses) entirely on-device. Templates support
{variable} placeholders, and Combos insert multiple snippets in sequence.
A Mac Catalyst menu-bar companion brings the same library to macOS.
```

**Privacy & values angle**
```
Zero data collection: no analytics SDKs, no tracking, no server. All data
lives in the user's device and their private iCloud. The keyboard extension
works without Full Access for core features. Sensitive memos can be locked
behind Face ID / Touch ID.
```

**Accessibility**
```
Full VoiceOver support across the app and keyboard (116 labels, 61 hints),
Dynamic Type, and Differentiate Without Color support: every visual
differentiation cue has a non-color alternative. Localized in Korean and
English, written in Korean first rather than machine translated.
```

> ⚠️ **인도네시아어를 쓰지 말 것.** 9317416 에서 제거했고 카탈로그에 4키만 잔재로 남아 있다.
> **visionOS 도 쓰지 말 것.** `TARGETED_DEVICE_FAMILY = 1,2` (iPhone · iPad) 뿐이다.
> 검증된 주장 목록은 `docs/APPLE_FEATURING_STORIES.md` 0절.

**Business model**
```
Free to start, with a one-time $9.99 Pro purchase: no subscription.
Existing paid-app customers were grandfathered into Pro for free when
the app moved to freemium.
```

**Upcoming updates worth featuring** *(제출 시점에 맞게 수정)*
```
Recent 4.3.x releases added Control Center quick-capture, a Quick Note
inbox fed by the Share Sheet and App Intents, widget support, and
{variable} highlighting across the template editor.
```

---

## 제출 팁

- 폼은 영어로 제출 (한국 에디토리얼 팀도 영문 폼을 읽음)
- "다가오는 업데이트"와 묶어 제출하면 선정 확률↑, 다음 메이저 기능 출시 4~6주 전 제출이 최적
- 선정 여부 통보 없음. 3개월마다 재제출 가능
- 한국 스토어 "오늘" 탭 인디 코너(우리가 사랑한 앱)도 동일 폼으로 커버됨
```
