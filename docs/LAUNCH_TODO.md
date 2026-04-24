# 🚀 ClipKeyboard 런칭 체크리스트 — A세그먼트 (글로벌 디지털 노마드)

> 타겟: 글로벌 원격 프리랜서 · 디지털 노마드 (비원어민)
> 런칭 타이밍: 제품 기능 완성 후 (IBAN 검증 · 타임존 변수 · 영어 템플릿 30종)
> 특가: `APRIL` 코드, $9.99 → $0.99, 1,000회, **2026-05-03 만료**

---

## 🔴 블로커 (기능 개발, 완료해야 런칭 가능)

제품에 없는 기능을 스크린샷·글에서 주장하면 **심사 리젝 + 리뷰 테러**. 최소 3개 중 하나는 반드시 있어야 함:

- [ ] **IBAN/SWIFT/VAT 포맷 검증** — 복사 시 자동 인식 + 체크섬 검증
- [ ] **타임존 템플릿 변수** (`{timezone}`, `{response_time}`, `{currency}`, `{greeting_time}`)
- [ ] **비원어민 영어 템플릿 30종 내장** (Proposal follow-up · Payment reminder · Reschedule · Scope pushback · Invoice delay …)
  - ⭐ **숨은 킬러** — A세그먼트가 돈 내는 가장 큰 이유

> 권장: 3개 중 최소 2개 구현 후 런칭. 영어 템플릿 30종은 기술 부담 없이 데이터만 만들면 되니 가장 쉬움.

---

## 🟠 앱 스토어 세팅 (런칭 D-7 ~ D-3)

### 1. 캠페인 링크 (`pt/ct`) — **제일 먼저**

없으면 Reddit·Twitter·랜딩 중 어디서 다운로드 나왔는지 구분 불가.

- [ ] **App Store Connect → 사용자 및 액세스 → Provider Token(`pt`) 발급** (한 번만)
- [ ] 캠페인별 URL 생성 (`ct=` 값):
  - [ ] `reddit-digitalnomad`
  - [ ] `reddit-freelance`
  - [ ] `twitter-buildinpublic`
  - [ ] `landing-hero`
  - [ ] `landing-pricing`
  - [ ] `tutorial-bottom`
- [ ] docs/* 의 모든 App Store 링크 일괄 교체
  - `docs/REDDIT_LAUNCH_POST.md`
  - `docs/index.html` (`hero-cta`, `pricing-cta`, `footer-appstore`)
  - `docs/tutorial.html` (`nav-appstore`, `bottom-cta`)

### 2. 맞춤형 제품 페이지 3개 (Custom Product Pages)

각 페이지마다 심사 24~48h 소요. D-3까지 제출 필수.

#### 📄 페이지 1: `cpp-digitalnomad` (1차 타겟)

**참조 이름**: `r/digitalnomad Launch 2026-04`

**키워드 선택** (체크):
- ✅ 키보드
- ✅ 템플릿
- ✅ 자동입력
- ✅ 빠른 답장
- ✅ 미리 작성된 답변

**프로모션 텍스트 (한국어, 170자 이내)**:
```
원격 프리랜서를 위한 iOS 키보드. IBAN · SWIFT · 타임존 응대 · 프로페셔널 영어 템플릿 30종을 한 번에 저장하고 어디서든 탭 한 번으로 입력하세요. 5/3까지 $0.99 런칭 특가.
```

**프로모션 텍스트 (영어, 170자 이내)**:
```
The iOS keyboard for remote freelancers. Save IBAN, SWIFT, timezone replies, and 30 pro English templates once — tap to insert into any app. $0.99 launch deal until May 3.
```

**스크린샷 7장 (iPhone 6.5", 1242 × 2688px)**:
| # | 제목 오버레이 | 내용 |
|---|------|------|
| 1 | **IBAN in one tap** — "Stop typing your banking info to every client" | 메모 리스트 + 상단 "방금 복사" 카드에 IBAN |
| 2 | **30 pro English templates** — "Non-native speaker? We got you." | 템플릿 리스트 (Proposal Follow-up 등) |
| 3 | **Timezone replies, automated** — `{timezone}` adjusts | 템플릿 편집 `Hi {client}, I'm in {timezone}...` |
| 4 | **Works in Gmail, Slack, Upwork** | 실제 앱에서 키보드 열려서 IBAN 탭 |
| 5 | **Smart clipboard, classified** | 스마트 클립보드 자동 분류 배지 |
| 6 (선택) | **One-time $9.99** — "No subscriptions. Ever." | 가격/설정 |
| 7 (선택) | **Privacy first** | 프라이버시 설명 |

**딥링크**: 비워둘 것 (현재 랜딩 라우팅 미구현)

**URL 확보 후**: `?pt=X&ct=reddit-digitalnomad` 붙여 Reddit 글에 삽입

---

#### 📄 페이지 2: `cpp-freelance` (2차)

**참조 이름**: `r/freelance Launch 2026-04`

**키워드**: 키보드 / 템플릿 / 미리 작성된 답변 / 빠른 답장 / 자동입력

**프로모션 (한국어, 111자)**:
```
프리랜서를 위한 iOS 키보드. 인보이스·VAT·결제 정보·제안서 후속 템플릿을 한 번에 저장. 클라이언트 응대 시간 90% 단축. 5/3까지 $0.99 특가.
```

**프로모션 (영어, 146자)**:
```
Invoices, VAT, payment info, proposal follow-ups — save once, tap forever. The iOS keyboard freelancers use from their phone. $0.99 until May 3.
```

**스크린샷 순서만 조정** (인보이스 1번으로):
1. **Invoice + VAT** — "Stop retyping your tax ID"
2. **30 pro English templates**
3. IBAN (디지털노마드 페이지의 1번을 3번으로)
4. 4~5번 동일

---

#### 📄 페이지 3: `cpp-general` (오가닉 검색 유입)

**참조 이름**: `General ASO 2026-04`

**키워드** (폭 넓게): 키보드 / 템플릿 / 자동입력 / 클립보드 / 짧은 문구 / 빠른 답장 / 미리 작성된 답변 / 메모 (8개)

**프로모션 (한국어, 100자)**:
```
자주 쓰는 문장·결제 정보·영어 템플릿을 키보드에 저장하고 어디서든 탭 한 번으로 입력하세요. 구독 없는 일회성 iOS 키보드 앱.
```

**프로모션 (영어, 155자)**:
```
Save phrases, financial info, and email templates to your keyboard. Tap once to insert anywhere. iOS keyboard extension. One-time purchase — no subscription.
```

**스크린샷**: 기존 메인 재활용 OK

---

### 3. Product Page Optimization (A/B 테스트)

앱 아이콘·스크린샷·프리뷰 영상 A/B/C 테스트. 런칭과 동시에 시작해서 2주간 데이터 수집.

- [ ] App Store Connect → 앱 → **Product Page Optimization** → 새 테스트
- [ ] 최대 3 variants (최대 90일)
- [ ] 테스트 제안:
  - Treatment A (Control): 현재 스크린샷
  - Treatment B: IBAN·타임존 앵글
  - Treatment C: 비원어민 영어 템플릿 앵글
- [ ] 목표 지표: **전환율 3.95% → 7~10%**

### 4. In-App Event: $0.99 Launch Sale

App Store 검색 결과에 이벤트 카드로 노출. 오가닉 유입 증가.

- [ ] App Store Connect → 앱 → (특정 버전) → **앱 이벤트** → 새 이벤트
- [ ] 설정:
  - **이름**: "Launch Deal for Remote Freelancers"
  - **기간**: 2026-04-28 ~ 2026-05-03 (심사 2~3일 감안)
  - **프로모션 카피**: "$0.99 for limited time — save phrases, IBAN, timezone replies"
  - **타겟**: 신규 + 기존 양쪽
  - **이미지**: 이벤트 카드용 배너 (규격 확인 필요)
- [ ] 심사 제출 → 통과 후 자동 게시

### 5. Promoted In-App Purchase

$9.99 Pro unlock을 App Store 페이지에 배지처럼 노출. 검색 결과에도 IAP 배지 표시.

- [ ] **코드 구현**: `SKPaymentTransactionObserver` + `shouldAddStorePayment` delegate
- [ ] App Store Connect → 앱 → 앱 내 구입 → IAP 선택 → **"App Store에 표시"** 체크
- [ ] 프로모션 이미지 업로드 (1024×1024 PNG)
- [ ] 프로모션 이름 · 설명 작성

---

## 🟡 런칭 직후 (D+1 ~ D+7)

### 6. 코호트 분석 모니터링

- [ ] App Store Connect → 분석 → **코호트** 
- [ ] 그룹핑: 다운로드 소스별 (r/digitalnomad vs r/freelance vs 오가닉)
- [ ] 관찰: "r/digitalnomad 유저가 빨리 구매하는가?", "$0.99 리딤 유저 7일 유지율?"

### 7. Sources 탭에서 채널별 비교

- [ ] D+7에 Sources 탭 확인
- [ ] 전환율 낮은 채널 컷, 승자 채널에 배가 투자
- [ ] 판단 기준: **전환율 5% 미만 채널은 드롭**

### 8. Analytics Reports API 자동화 (선택)

- [ ] `/analytics` endpoint로 일간 데이터 Cron 수집
- [ ] Slack/이메일 리포트 설정

---

## 🟢 D+14 ~ D+35 (중장기 측정)

### 9. Product Page Optimization 결과 적용

- [ ] D+14 승자 variant 확인
- [ ] 메인 제품 페이지에 winning treatment 적용

### 10. Peer Group Benchmarks 확인

Apple이 최근 추가한 2개 지표 비교:

- [ ] **Download-to-Paid Conversion (D35)** — D+35 이후 첫 유의미 비교 가능
- [ ] **Revenue Per Download** — 동종 Freemium/Premium iOS 유틸 대비 위치
- [ ] 크래시 레이트 — 세션당 0.1% 이하 유지 여부

### 11. 리딤 · 전환 데이터로 전략 재정렬

- [ ] `APRIL` 리딤 수 집계 (1,000 중 몇 개 소진?)
- [ ] 리딤 → 실제 재방문/구매 전환율
- [ ] 추가 특가 코드 필요한지 판단 (예: `MAY` 코드 발급)

---

## ❌ 하지 말 것 / 영구 스킵

- ❌ **구독 분석** — 구독 상품 없음, 영구 회색
- ❌ **App Clips** — 키보드 앱 핏 안 맞음
- ❌ **3rd-party analytics** (Firebase/Mixpanel) — "No data collection" 프라이버시 약속과 충돌
- ❌ **Facebook/Google 광고** — A세그먼트 CAC 회수 불가

---

## 🛡️ 심사 리젝 방지 체크리스트

- [ ] 스크린샷에 "$0.99" 가격 문구 **넣지 말 것** (Apple 가이드라인 2.3.8)
- [ ] "TextExpander alternative" 등 경쟁사 이름 **언급 금지**
- [ ] 앱에 없는 기능을 스크린샷에 **보여주지 말 것** (IBAN 검증 미구현 상태에서 "IBAN 자동 감지" UI 금지)
- [ ] 프로모션 텍스트만 수정 = 심사 없음 / 그 외 = 심사 필수

---

## 📅 총 타임라인

| 시점 | 액션 | 예상 시간 |
|------|------|---------|
| **D-14 ~ D-7** | IBAN/타임존/영어템플릿 중 최소 2개 개발 | 대형 |
| **D-7** | `pt/ct` 캠페인 링크 발급 + docs 일괄 교체 | 1h |
| **D-6** | Custom Product Page 3개 심사 제출 | 3h |
| **D-5** | In-App Event 등록 + 심사 제출 | 1h |
| **D-4** | Promoted IAP 이미지 + 코드 | 3h |
| **D-3** | Product Page Optimization 시작 | 1h |
| **D-1** | 최종 리뷰, 스크린샷 승인 확인 | 1h |
| **D-day** | Reddit r/digitalnomad 게시 + Twitter 동시 | 3h |
| **D+2** | Reddit r/freelance 수정 버전 게시 | 1h |
| **D+7** | Sources 채널 분석 | 1h |
| **D+14** | POP 결과 적용 | 1h |
| **D+35** | D35 벤치마크 확인 + 전략 재정렬 | 2h |

---

## 🔗 참고 링크 · 준비물

- **App Store Connect**: https://appstoreconnect.apple.com
- **공개 리딤 URL (`APRIL`, 만료 5/3)**: https://apps.apple.com/redeem?ctx=offercodes&id=1543660502&code=APRIL
- **현재 전환율**: 3.95% (목표 7~10%)
- **현재 MRR**: US$14/day (최근)

## 📝 참고 문서

- `docs/REDDIT_LAUNCH_POST.md` — Reddit 게시글 초안 (r/digitalnomad + r/freelance)
- `docs/SEEDING-GUIDE.md` — 커뮤니티 시딩 가이드
- `docs/tutorial.html` — 사용 가이드 랜딩
- `docs/index.html` — 메인 랜딩

---

*Last updated: 2026-04-25 · Target: A세그먼트 (글로벌 디지털 노마드 프리랜서)*
