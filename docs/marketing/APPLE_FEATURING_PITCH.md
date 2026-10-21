# 🍎 Apple 피처링 신청, 제출용 텍스트

> 제출처: https://developer.apple.com/app-store/promote/ (App Store Featuring Nomination)
> 소요: 10분. 비용 0원. 인디 앱도 접근성·최신 OS 대응이 좋으면 실제로 선정됨.
> ClipKeyboard의 어필 포인트: **접근성(VoiceOver·색 외 구분) + 23개 언어 자판 + 프라이버시(서드파티 분석 SDK 없음, 단축어 내용을 모으지 않음) + 쓴 만큼 무료**
>
> 📌 **앵글별 본문은 `docs/marketing/APPLE_FEATURING_STORIES.md`.** 이 파일은 폼 필드에 넣을 짧은 문안이고,
> 저쪽은 시기·상황별로 골라 쓰는 Helpful Details 본문 아홉 가지다. 검증된 근거 표도 그쪽에 있다.

---

## 제출 폼 필드별 텍스트

**App Name**: Clip Keyboard: Paste Snippets (id 1543660502)

**What makes your app unique?**
```
ClipKeyboard is a clipboard manager that lives inside the iOS keyboard itself.
Users save frequently typed content once: bank details, addresses, canned
replies: and insert it with one tap in any app. Everything copied is
sorted by type (email, phone, IBAN with ISO 13616 checksum validation,
addresses) entirely on-device. Templates support {variable} placeholders,
and Stacks insert several values in sequence. Since 5.1.13 it is also a
full typing keyboard with iPhone-style layouts for 23 languages, so people
type and insert snippets on one keyboard (Japanese and Chinese type kana,
Pinyin and Zhuyin for now; kanji conversion is on the roadmap).
```

**Privacy & values angle**
```
No third-party analytics SDK and no tracking. Snippet contents are never
collected; they live on the user's device and in their private iCloud. The
app sends anonymous usage statistics (counts, not content) to the
developer's own CloudKit container. The keyboard extension
works without Full Access for core features. Sensitive memos can be locked
behind Face ID / Touch ID.
```

**Accessibility**
```
Full VoiceOver support across the app and keyboard (179 labels, 85 hints
as of October 2026), Dynamic Type, and Differentiate Without Color support:
every visual differentiation cue has a non-color alternative. Localized in
23 languages, and the keyboard follows each country's iPhone layout.
```

> ⚠️ 인도네시아어는 지금 23개 언어에 들어 있다(예전에 한 번 뺐다가 다시 켰다).
> **visionOS 는 쓰지 말 것.** `TARGETED_DEVICE_FAMILY = 1,2` (iPhone · iPad) 뿐이다.
> 검증된 주장 목록은 `docs/marketing/APPLE_FEATURING_STORIES.md` 0절.

**Business model**
```
Every feature is free for the first 100 snippet inserts, and what people
made keeps working after that. Pro is a one-time purchase or a yearly
subscription. Existing paid-app customers were grandfathered into Pro for
free when the app moved to freemium.
```

**Upcoming updates worth featuring** *(제출 시점에 맞게 수정)*
```
5.1.13 adds full typing layouts for 23 languages to the keyboard, and
switches back to the person's own keyboard after a snippet goes in.
5.1.12 added the Action button and Control Center capture of copied text.
```

---

## 제출 팁

- 폼은 영어로 제출 (한국 에디토리얼 팀도 영문 폼을 읽음)
- "다가오는 업데이트"와 묶어 제출하면 선정 확률↑, 다음 메이저 기능 출시 4~6주 전 제출이 최적
- 선정 여부 통보 없음. 3개월마다 재제출 가능
- 한국 스토어 "오늘" 탭 인디 코너(우리가 사랑한 앱)도 동일 폼으로 커버됨
```
