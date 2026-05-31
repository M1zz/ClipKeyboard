# r/digitalnomad · r/freelance 게시글 초안 — ClipKeyboard (v4.2.1 사용성 개선 런칭)

> **대상 서브레딧 (우선순위)**
> 1. **[r/digitalnomad](https://www.reddit.com/r/digitalnomad/)** — 1차 타겟 (1.5M+ 구독)
> 2. **[r/freelance](https://www.reddit.com/r/freelance/)** — 2차 (500K+ 구독)
> 3. (후속) r/iOSApps, r/IndieHackers
>
> **⚠️ 주의**: 두 서브 모두 "self-promotion" 규칙 엄격. "I built this because I kept typing my IBAN 10 times a day" **build story 톤** 필수. 직접 판매 글은 밴 위험.
>
> **톤**: 1인칭 + 페인포인트 먼저 + 솔루션 나중. 가격은 본문 하단/댓글에서만.
> **이번 앵글**: "앱을 싹 갈아엎어 **단순하게** 만들었다" (v4.2.1) — 가치 어필은 검증된 IBAN/타임존 기능으로.
> **길이**: 500 words 이하. 스크린샷 1~2장.
> **게시 시간(권장)**: 미국 동부 오전 9~11시 (북미 노마드가 커피마시며 보는 시간대) · 유럽은 저녁 시간대

---

## 🔴 게시 전 반드시 (BLOCKER)

- [ ] **새 Offer Code 발급** — `APRIL`은 2026-05-03 만료(사용 불가). App Store Connect에서 새로 발급:
  - 가격: **$2.99** (정가 $9.99 → 70% off)
  - 코드명(권장): **`2026JUNE`** ← 발급 후 다른 이름이면 이 문서·index.html·tutorial.html에서 일괄 치환
  - 리딤 횟수: 1,000회 / 만료일: **2026-06-14** *(← 본인이 ASC에서 확정. 글의 "Expires" 문구도 같이 맞출 것)*
  - 리딤 URL: `https://apps.apple.com/redeem?ctx=offercodes&id=1543660502&code=2026JUNE`
- [ ] **허위 주장 제거 확인** — "30개 내장 영어 템플릿"은 실제 시드 데이터 미구현이라 **이 글에서 삭제함**. 다시 넣지 말 것.
- [x] **실제로 구현되어 주장 가능한 기능** (글에 써도 거짓말 아님):
  - IBAN 자동분류 + ISO 13616 mod-97 체크섬 검증 (`ClipboardClassificationService.swift`)
  - `{timezone}` `{currency}` `{response_time}` 템플릿 변수 (`TemplateVariableProcessor.swift`)
  - v4.2.1 사용성 개선 — 빈 카테고리 시작 / 스마트 자동 제안 / 길게 눌러 이동

## ✅ 게시 전 체크리스트

- [ ] 공개 리딤 URL 동작 확인 (iPhone에서 탭 → 특가 적용된 채 App Store 열림)
- [ ] 스크린샷: (1) IBAN/Wise/PayPal 저장된 메모 리스트 (2) 키보드에서 Gmail/Upwork에 자동 입력되는 GIF
- [ ] **자기계정 카르마 확인** — 신규·저카르마 계정은 자동 스팸 필터에 걸림. 댓글로 300+ 카르마 먼저 쌓기 권장
- [ ] Flair 선택: `Discussion` 또는 `Question` (직접 `Promotion` 플레어는 제재 가능성)
- [ ] 같은 글을 **24시간 이내** 여러 서브에 복붙하지 말 것. 각각 하루 이상 간격

---

## 📝 Title (3개 중 택일)

1. **I freelance from my phone and got tired of retyping my IBAN/tax info to every client — so I built (and just simplified) an iOS keyboard for it**
2. **Spent a weekend stripping my own freelance keyboard app down to the essentials — here's what's left**
3. **Anyone else tired of retyping their IBAN/Wise/tax ID every time a client asks? Built an iOS keyboard that fixes this (just rebuilt it to be dead-simple)**

**추천**: 1번. 페인포인트(IBAN 반복 입력) + 이번 업데이트 앵글(simplified)을 둘 다 자연스럽게 담음.

---

## 📝 본문 — r/digitalnomad 버전 (복사 후 바로 편집 가능)

```markdown
I've been freelancing remotely for ~4 years (currently Chiang Mai, previously
Lisbon). Spent way too much of that time doing one thing over and over:

Typing my IBAN. My SWIFT code. My VAT number. My Wise address. My PayPal email.
"Hey, I'm GMT+7, will get back in ~6h." The same handful of sentences, every
day, across five different apps.

Text replacement on iOS is clunky, and the desktop tools (TextExpander, Paste)
are overkill for someone who mostly works from a phone — coffee shops,
co-working spaces, airports. So a while back I built what I wanted: an iOS
keyboard extension, **ClipKeyboard**.

The reason I'm posting now: I just shipped a big cleanup update and it finally
feels right. The app had quietly gotten cluttered — a dozen pre-made
categories I never asked for, confusing "theme vs category" wording. So I
stripped it down:

- **Starts empty.** No junk categories. You add only the ones you actually use.
- **Smart suggestions.** When similar items pile up (emails, phone numbers,
  banking info), it gently offers to group them in one tap.
- **Long-press to move/organize** anything on the fly.

What it actually does day-to-day:

- **Save phrases + financial info → tap once to type into any app** (Gmail,
  Slack, Upwork, Deel, Wise...).
- **Auto-classifies copied text** into IBAN / SWIFT / VAT / card / phone /
  email / address / URL. IBAN even gets a real mod-97 checksum check so a
  typo'd one gets flagged.
- **Templates with variables**: `Hi {client_name}, I'm currently in {timezone},
  I'll reply within {response_time}...` — fills in automatically and remembers
  previous values.
- **Combos**: chain multiple snippets. E.g. "send banking info" = name + IBAN
  + SWIFT + address, typed in sequence.
- **iCloud sync** between iPhone, iPad, Mac. One $9.99 purchase covers all.
- **No subscription. No data collection. No ads.** Local-only storage.

**Why a keyboard extension matters:** every "clipboard manager" app on iOS
hits the sandbox wall — they can't actually paste into other apps. The only
way around that is to *be* the keyboard.

**Screenshots:** [attach 2]

**App Store:** https://apps.apple.com/app/clip-keyboard-quick-phrases/id1543660502

---

**🎁 70% off for r/digitalnomad — $2.99 (normally $9.99):**
Tap on your iPhone/iPad — App Store opens with the deal pre-applied:
**https://apps.apple.com/redeem?ctx=offercodes&id=1543660502&code=2026JUNE**

Or enter code **`2026JUNE`** manually in App Store > profile > "Redeem Gift Card
or Code". First 1,000 redemptions. Expires **June 14**.

Happy to answer questions about how I use it day-to-day, and especially
curious what phrases you find yourself typing over and over.
```

### r/freelance 버전 차이점 (본문 2~3줄만 바꿔주면 재사용)

- 앞 2줄 교체: *"Freelancing for 4 years. Spent too much of it retyping my tax ID, IBAN, and the same 'here's my banking info' message to every new client..."*
- `{timezone}` 변수 예시 → `{project_name}`, `{deliverable_date}` 로 교체
- "coffee shops, airports" 부분 → "co-working spaces, client calls" 로

---

## 🖼 스크린샷 권장 (2장 필수)

1. **메모 리스트에 IBAN / SWIFT / Wise / PayPal 저장된 모습** — 한국어/한국 표기 없이 글로벌 예시만. (가능하면 깔끔해진 v4.2.1 카테고리 화면)
2. **키보드에서 Gmail 작성 중 IBAN 한 번에 입력되는 GIF 또는 연속 스크린샷**
   - Gmail 또는 Upwork · Slack 중 하나 앵글
   - 화면 위: "Hi [Client], here's my banking info..."
   - 키보드: ClipKeyboard 열려서 [IBAN] 탭 → 텍스트가 입력

> 📸 iOS 시뮬레이터 아닌 **실제 iPhone에서 촬영**이 신뢰도 높음. Apple device frame은 씌우지 말 것 — r/digitalnomad는 스크린샷이 "진짜처럼" 보일수록 받아들여짐.

---

## 💬 예상 댓글 & 답변 준비

| 예상 질문 | 답변 포인트 |
|----------|------------|
| "How is this different from TextExpander?" | TextExpander는 Mac-first + 구독 기반. ClipKeyboard는 iOS-first + 일회성 구매. 폰으로 일하는 워크플로우 특화. |
| "Why $9.99? Paste is cheaper." | Paste는 Mac 중심. IBAN/SWIFT mod-97 검증, 타임존 변수는 둘 다 없음. + 평생 업데이트, 구독 없음. |
| "Does Apple allow keyboards to read text fields?" | No — 그게 핵심. 이 앱은 **input만**. 사용자가 탭한 스니펫만 삽입. 필드에서 읽는 것 없음. |
| "Privacy?" | Local-only (App Group). 분석/트래킹 0. iCloud 동기화는 사용자 iCloud에 암호화 저장 (개발자 접근 불가). |
| "Android?" | iOS 생태계 집중. Android 계획 없음. |
| "Is there a free tier?" | 메모 일부 무료. 키보드 익스텐션 풀 사용은 Pro ($9.99 일회성). `2026JUNE` 코드로 $2.99. |
| "왜 할인?" | r/digitalnomad 대상 70% off — Apple Offer Code. 1,000명 선착순. 이후 정가 $9.99. |
| "offer code 받는 법?" | 본문 링크 탭 (iPhone/iPad에서) 또는 App Store에 `2026JUNE` 직접 입력. |

---

## 🎯 게시 후 24시간 액션 플랜

1. **1시간 내 모든 댓글 답변** — 활성 글이 서브 상단에 더 오래 머묾
2. **코드 관련 문의** — 본문에 이미 URL 있으니 "Link in the post 👆"
3. **다운보트 / 토론 유도 댓글** — 방어 자제, 무시가 최선
4. **리딤 현황**: App Store Connect > 특가 코드 > `2026JUNE` 실시간 확인
5. **12시간 후**: 본문 edit — *"Update: Xxx redemptions so far — thanks r/digitalnomad!"*
6. **D+2**: r/freelance에 수정된 버전 게시 (같은 글 복붙 금지)
7. **D+3 / 만료 D-2**: 알림 edit — *"⏰ Deal ends in 48h"*

---

## ⚠️ 하지 말 것

- ❌ 제목에 이모지 2개 이상
- ❌ "Revolutionary / Best / Ultimate" 같은 과장
- ❌ 같은 글을 **24시간 안에** 여러 서브에 복붙 (shadowban 위험)
- ❌ "DM me for code" 지양 — 본문에 링크 이미 있음
- ❌ 제품에 없는 기능 주장 (특히 "30개 내장 템플릿" — 미구현, 언급 금지)

---

## 📅 추가 시딩 아이디어

- **D+7**: r/iOSApps에 "my iOS keyboard extension — just did a big simplify pass" 톤으로
- **D+14**: r/IndieHackers에 "build in public" 톤 — 숫자 공개 (리딤 수, DL 수, MRR 등)
- **D+21**: ProductHunt 런칭 (위 결과 피드백 반영 후)
- **D+30**: Twitter/X thread로 런칭 복기 (실수·숫자·배운 것)

---

## 📮 r/apphunt 버전 (앱 쇼케이스 — 직접 소개 OK)

> r/apphunt·r/iOSApps·r/SideProject 류는 self-promo 규칙이 느슨해 **앱을 직접 소개해도 됨**.
> 단, 게시 전 각 서브 룰 확인 (플랫폼 태그 `[iOS]`, 앱 1개/글, 플레어). 코드: `2026JUNE` ($2.99, ~6/14).

**Title (택1)**

1. **[iOS] ClipKeyboard — a keyboard that types your saved phrases, IBAN & email templates into any app (70% off this week)**
2. **[iOS] I built a keyboard for the stuff I retype every day — IBAN, templates, timezone replies. $2.99 this week.**

**본문 (복사용)**

```markdown
**ClipKeyboard** — an iOS keyboard extension that types your saved stuff into any app.

I'm the dev. Built this because I kept retyping the same things from my phone:
my IBAN, SWIFT, VAT, a couple of email templates, "I'm GMT+7, will reply in
~6h." Clipboard-manager apps on iOS can't paste into other apps (sandbox), so
the only real fix is to *be* the keyboard.

What it does:
- Save phrases + info → tap once to type into any app (Gmail, Slack, Upwork, Wise…)
- Auto-classifies copied text: IBAN (with mod-97 checksum), SWIFT, VAT, card,
  email, phone, address, URL
- Templates with fill-in slots — `Hi {name}, I'm in {timezone}, I'll reply
  within {response_time}…` — remembers your previous values
- Combos: chain several snippets in order (name + IBAN + SWIFT + address)
- iCloud sync across iPhone / iPad / Mac
- No subscription, no ads, no data collection. Local-only storage.

Just shipped a big cleanup update: it starts empty now instead of dumping a
dozen default categories on you, suggests grouping similar items, and lets you
long-press to organize. Felt like the right time to share it.

**Deal for this sub: $2.99 (normally $9.99) — 70% off.**
Tap on iPhone/iPad and the App Store opens with it applied:
https://apps.apple.com/redeem?ctx=offercodes&id=1543660502&code=2026JUNE
(or enter code `2026JUNE` in App Store → profile → "Redeem Gift Card or Code".
First 1,000, expires June 14.)

App Store: https://apps.apple.com/app/clip-keyboard-quick-phrases/id1543660502

Happy to answer anything — and genuinely curious what you all find yourself
retyping the most.
```

> 게시 계정: **leehyunho**. 게시 후 1시간 내 댓글 응대, 리딤 현황은 ASC > 특가 코드 > `2026JUNE`.
