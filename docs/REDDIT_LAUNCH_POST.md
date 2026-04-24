# r/digitalnomad · r/freelance 게시글 초안 — ClipKeyboard

> **대상 서브레딧 (우선순위)**
> 1. **[r/digitalnomad](https://www.reddit.com/r/digitalnomad/)** — 1차 타겟 (1.5M+ 구독)
> 2. **[r/freelance](https://www.reddit.com/r/freelance/)** — 2차 (500K+ 구독)
> 3. (후속) r/iOSApps, r/IndieHackers
>
> **⚠️ 주의**: 두 서브 모두 "self-promotion" 규칙 엄격. "I built this because I kept typing my IBAN 10 times a day" **build story 톤** 필수. 직접 판매 글은 밴 위험.
>
> **톤**: 1인칭 + 페인포인트 먼저 + 솔루션 나중. 가격은 댓글 대응시에만 언급.
> **길이**: 500 words 이하. 스크린샷 1~2장.
> **게시 시간(권장)**: 미국 동부 오전 9~11시 (북미 노마드가 커피마시며 보는 시간대) · 유럽은 저녁 시간대

---

## ✅ 게시 전 체크리스트

- [x] **$0.99 맞춤형 특가 코드 `APRIL`** 생성 완료 (1,000회 리딤, 2026-05-03 만료)
- [x] 공개 리딤 URL 확보: `https://apps.apple.com/redeem?ctx=offercodes&id=1543660502&code=APRIL`
- [ ] **제품 준비**: IBAN/SWIFT 검증, 타임존 템플릿 변수, 내장 영어 템플릿 30개 — 셋 중 최소 하나는 **실제 빌드에 들어가 있어야** 이 글의 주장이 거짓말이 안 됨
- [ ] 스크린샷: (1) 이메일/IBAN 저장된 메모 리스트 (2) 키보드에서 Upwork/Gmail에 자동 입력되는 GIF
- [ ] **r/digitalnomad 자기계정 카르마 확인** — 신규 계정·저카르마는 자동 스팸 필터에 걸림. 댓글로 300+ 카르마 먼저 쌓기 권장
- [ ] Flair 선택: `Discussion` 또는 `Question` (직접 `Promotion` 플레어는 제재 가능성)
- [ ] 같은 글을 **24시간 이내** 여러 서브에 복붙하지 말 것. 각각 하루 이상 간격

---

## 📝 Title (3개 중 택일)

1. **Anyone else tired of retyping their IBAN/Wise/tax ID every time a client asks? I built an iOS keyboard that fixes this**
2. **5 years as a remote freelancer and I finally got tired of retyping my bank info — so I made an iOS keyboard**
3. **Non-native English speakers: do you have 30+ "professional reply templates" saved somewhere? I built a keyboard that keeps them a tap away**

**추천**: 1번. 페인포인트가 제목에 명확하고, r/digitalnomad 정규 구독자의 "알아 그 느낌" 반응을 유발. 2번은 자기 경험 앵글, 3번은 비원어민 훅 (가장 좁은 틈이지만 가장 충성도 높은 반응).

---

## 📝 본문 — r/digitalnomad 버전 (복사 후 바로 편집 가능)

```markdown
I've been freelancing remotely for ~4 years (currently Chiang Mai, previously
Lisbon). Spent way too much of that time doing one thing over and over:

Typing my IBAN. My SWIFT code. My VAT number. My Wise address. My PayPal email.
"Hey, I'm GMT+7, will get back in ~6h." The same three sentences, every day,
in five different apps.

Text replacement on iOS is clunky. Paste and TextExpander are desktop-first
and (for me) overkill. I mostly work from my phone — coffee shops, co-working
spaces, airports. So I built what I wanted: an iOS keyboard extension.

**ClipKeyboard** — what it does:

- **Stores phrases + financial info + templates** — tap once to type into
  any app (Gmail, Slack, Upwork, Deel, Wise, ...).
- **Auto-classifies copied text** into IBAN / SWIFT / VAT / card / phone /
  email / address / URL / plain text etc. Don't lose things anymore.
- **Templates with variables**: `Hi {client_name}, I'm currently in {timezone},
  I'll reply within {response_time}...` — remembers previous values.
- **30 built-in "professional English" templates** for non-native speakers
  (proposal follow-ups, payment reminders, scope pushback, invoice delays).
  This was the #1 thing I wished existed when I started.
- **Combos**: chain multiple snippets. E.g. "send banking info" = name +
  IBAN + SWIFT + address, typed in sequence with 0.5s delay.
- **iCloud sync** between iPhone, iPad, Mac, Vision Pro. One $9.99 purchase
  covers all.
- **No subscription. No data collection. No ads.** Local-only storage.

**Why a keyboard extension matters:** every "clipboard manager" app on iOS
hits the sandbox wall — they can't actually paste into other apps. The only
way around that is to be the keyboard itself.

**Screenshots:** [attach 2]

**App Store:** https://apps.apple.com/app/clip-keyboard-quick-phrases/id1543660502

---

**🎁 $0.99 launch deal for r/digitalnomad (90% off, normally $9.99):**
Tap on your iPhone/iPad — App Store opens with the deal pre-applied:
**https://apps.apple.com/redeem?ctx=offercodes&id=1543660502&code=APRIL**

Or enter code **`APRIL`** manually in App Store > profile > "Redeem Gift Card
or Code". First 1,000 redemptions. Expires **May 3**.

Happy to answer questions about how I use it day-to-day, and especially
curious what phrases/templates *you* find yourself typing over and over.
```

### r/freelance 버전 차이점 (본문 2~3줄만 바꿔주면 재사용)

- 앞 2줄 교체: *"Freelancing for 4 years. Spent too much of it retyping my tax ID, IBAN, and the same "here's my banking info" message to every new client..."*
- `{timezone}` 변수 예시 → `{project_name}`, `{deliverable_date}` 로 교체
- "coffee shops, airports" 부분 → "co-working spaces, client calls" 로

---

## 🖼 스크린샷 권장 (2장 필수)

1. **메모 리스트에 IBAN / SWIFT / Wise / PayPal 저장된 모습** — Korean/한국 표기 없이 글로벌 예시만
2. **키보드에서 Gmail 작성 중 IBAN 한 번에 입력되는 GIF 또는 연속 스크린샷**
   - Gmail 또는 Upwork · Slack 중 하나 앵글
   - 화면 위: "Hi [Client], here's my banking info..." 
   - 키보드: ClipKeyboard 열려서 [IBAN] 탭 → 텍스트가 입력

> 📸 iOS 시뮬레이터 아닌 **실제 iPhone에서 촬영**이 신뢰도 높음. 스크린샷 프레임(Apple device frame)은 씌우지 말 것 — r/digitalnomad는 스크린샷이 "진짜처럼" 보일수록 받아들여짐.

---

## 💬 예상 댓글 & 답변 준비

| 예상 질문 | 답변 포인트 |
|----------|------------|
| "How is this different from TextExpander?" | TextExpander는 Mac-first + 구독 기반. ClipKeyboard는 iOS-first + 일회성 구매. 폰으로 일하는 워크플로우 특화. |
| "Why $9.99? Paste is cheaper." | Paste는 Mac 중심. 내장 30개 영어 템플릿, IBAN/SWIFT 검증, 타임존 변수는 TextExpander·Paste 모두 없음. + 평생 업데이트, 구독 없음 |
| "Does Apple allow keyboards to read text fields?" | No — 그게 핵심. 이 앱은 **input만**. 사용자가 탭한 스니펫만 삽입. 필드에서 읽는 것 없음 |
| "Privacy?" | Local-only (App Group). 분석/트래킹 0. iCloud 동기화는 사용자 iCloud에 암호화 저장 (개발자 접근 불가) |
| "Android?" | iOS 생태계 집중. Android 계획 없음 |
| "Is there a free tier?" | 메모 5개까지 무료. 키보드 익스텐션 사용하려면 Pro ($9.99 일회성). `APRIL` 코드로 $0.99 |
| "왜 $0.99?" | r/digitalnomad 런칭 특가 — Apple Offer Code. 1,000명 선착순. 이후 정가 $9.99 |
| "offer code 받는 법?" | 본문 링크 탭 (iPhone/iPad에서) 또는 App Store에 `APRIL` 직접 입력 |

---

## 🎯 게시 후 24시간 액션 플랜

1. **1시간 내 모든 댓글 답변** — 활성 글이 서브 상단에 더 오래 머묾
2. **코드 관련 문의** — 본문에 이미 URL 있으니 "Link in the post 👆"
3. **다운보트 / 토론 유도 댓글** — 방어 자제, 무시가 최선
4. **리딤 현황**: App Store Connect > 특가 코드 > `APRIL` 실시간 확인
5. **12시간 후**: 본문 edit — *"Update: Xxx redemptions so far — thanks r/digitalnomad!"*
6. **D+2**: r/freelance에 수정된 버전 게시 (같은 글 복붙 금지)
7. **D+3**: 만료 D-2 알림 edit — *"⏰ Deal ends in 48h"*

---

## ⚠️ 하지 말 것

- ❌ 제목에 이모지 2개 이상
- ❌ "Revolutionary / Best / Ultimate" 같은 과장
- ❌ 같은 글을 **24시간 안에** 여러 서브에 복붙 (shadowban 위험)
- ❌ "DM me for code" 지양 — 본문에 링크 이미 있음
- ❌ 제품에 없는 기능 주장 (IBAN 검증 없으면 말하지 말 것)

---

## 📅 추가 시딩 아이디어

- **D+7**: r/iOSApps에 "my first iOS keyboard extension app" 톤으로
- **D+14**: r/IndieHackers에 "build in public" 톤 — 숫자 공개 (리딤 수, DL 수, MRR 등)
- **D+21**: ProductHunt 런칭 (위 결과 피드백 반영 후)
- **D+30**: Twitter/X thread로 런칭 복기 (실수·숫자·배운 것)
