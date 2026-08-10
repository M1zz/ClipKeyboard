# 클립키보드, 성숙한 서비스로 가는 설계

> 근거: `app-portfolio/reports/portfolio-explorer.html` (기준일 2026-07-26) + 2026-07-30 리포지토리 실사
> 대상 버전: 4.4.3 (dev) · Swift 파일 145개 · 테스트 파일 31개

---

## 1. 현재 좌표

포트폴리오 46개 앱 중 **성숙도 89점으로 1위** (2위 두번알림 80, 3위 달빛 71).
8축 중 6축이 만점이고, 감점은 두 곳뿐이다.

| 축 | 배점 | 현재 | 상태 |
|----|-----:|-----:|------|
| 스토어 출시 | 15 | 15 | ✅ |
| 태스크 완료율 | 15 | 15 | ✅ |
| 앱스토어 평점 | 15 | 14 | 4.7★ / **평가 13개**: 표본이 얇다 |
| 수익모델 | 15 | 15 | ✅ freemium + Pro ₩17,000 |
| 피드백 루프 | 15 | 15 | ✅ FeedbackHub 연동 |
| **사용현황 수집** | 10 | **0** | ← 아래 2절 |
| 리뷰요청 장치 | 8 | 8 | ✅ |
| 버전 성숙도 | 7 | 7 | ✅ |

**남은 11점의 정체는 "분석 10점 + 평점 1점"이다.** 즉 점수만 보면 거의 다 왔다.
문제는 점수판에 없는 것들이다. 아래가 이 문서의 본론이다.

---

## 2. 리포트의 갭 vs 진짜 갭

리포트는 코드 시그니처 스캔이라 두 가지를 구분하지 못한다.

### 2-1. 분석 0점은 절반만 사실이다
리포트 판정은 `analyticsLocalOnly: true`, "래퍼만 있고 전송 없음".
그러나 **커밋 `3ce5ccb`(2026-07-30)에서 `UsageReportingService`가 들어가면서 실제 전송이 구현됐다.**
`ClipKeyboard/Service/UsageReportingService.swift` → LeeoKit `LeeoUsageReporter` → FeedbackHub(CloudKit public DB).
스냅샷·이벤트·추이 차트(`UsageStatsView`, `UsageTrendChartView`)까지 있고 테스트 14개도 붙었다.

리포트가 0점을 준 건 판정 규칙이 **외부 상용 SDK만 인정**하기 때문이다(TelemetryDeck/Firebase/Amplitude…).
자체 호스팅 파이프라인은 규칙 밖에 있다.

> **결론: Firebase를 붙여서 점수를 올리지 않는다.** 대신 (a) 판정 규칙에 "자체 수집 파이프라인" 등급을 추가하고,
> (b) 아직 안 끝난 마무리 2건을 끝낸다. 이게 진짜 갭이다.

**미완결 2건** (`todo.md`에 체크 안 된 항목, 릴리즈 블로커):
1. CloudKit Dashboard에 `UsageSnapshot`/`UsageEvent` 스키마 생성 → 인덱스 → **Production 배포** (`docs/USAGE_STATS_HUB.md`)
2. App Store **App Privacy** 갱신 (Usage Data / Product Interaction, 미연결·비추적) + 개인정보 처리방침의 "외부로 아무 통계도 보내지 않음" 문구 수정

⚠️ 이 2번을 빼먹고 4.4.3을 올리면 **표기와 실제가 어긋난 상태로 심사에 들어간다.** 가장 높은 우선순위다.

### 2-2. 점수판에 없는 진짜 갭

| 영역 | 현재 | 왜 문제인가 |
|------|------|------------|
| 🛟 장애 대응 | **크래시 모니터링 0** (`Crashlytics`/`Sentry`/`MetricKit` 전부 미사용) | 141개 파일 + **메모리 제한이 빡빡한 키보드 익스텐션**을 운영하면서 릴리즈 후 크래시를 알 방법이 없다. 사용자가 리뷰로 알려주기 전까지 모른다 |
| 🔐 개인정보 | **`PrivacyInfo.xcprivacy` 없음** | UserDefaults를 40개 파일에서 쓴다 → Required Reason API 선언 대상. 심사 경고/리젝 리스크이고, 통계 수집을 시작하는 이번 릴리즈에서 특히 위험 |
| 🧪 QA | 테스트 31파일·300+ 케이스인데 **CI 없음** (`.github` 없음, SwiftLint 없음) | 자산은 있는데 자동으로 안 돈다. 로컬에서 돌리는 걸 잊으면 회귀가 그대로 나간다 |
| 🔭 관측성 | `print` 33개 파일 / `OSLog`는 `MemoSyncEngine` 1개뿐 | 사용자 기기에서 무슨 일이 있었는지 사후 확인 불가. 특히 동기화·백업 실패 재현이 어렵다 |
| 🛟 복원력 | **원격 킬스위치·기능 플래그 없음** | 문제 기능을 끄려면 심사 대기 며칠. FeedbackHub 인프라가 이미 있으니 비용이 거의 안 드는데 없다 |
| 🗄️ 무결성 | `try?` **127회** | 조용한 실패. 데이터 경로(저장/마이그레이션/동기화)에 섞여 있으면 "저장된 줄 알았는데 없음"이 된다 |
| 📈 성장 | 평가 13개 · 마케팅 킷·ASO 문서는 있으나 **미발행** | 89점 앱인데 노출 표본이 얇다. 평점 축 1점 손실도 여기서 온다 |

### 2-3. 포트폴리오 전체 대비, 이건 개별 앱 문제가 아니다

| 항목 | 46개 중 보유 |
|------|---:|
| 크래시 모니터링 | **1** |
| CI | **1** |
| SwiftLint | **1** |
| PrivacyInfo.xcprivacy | **3** |
| 테스트 | 11 |
| 클라우드 저장 | 35 |

크래시·CI·개인정보 매니페스트는 **46개 중 43~45개가 똑같이 빈 칸**이다.
클립키보드에서만 풀면 낭비고, **LeeoKit / 공용 템플릿 레벨에서 풀어 나머지 45개에 전파**하는 게 맞다 (5절).

---

## 3. 로드맵

### Phase 0, 지금 막혀 있는 것 (즉시)

**P0-1. `ClipKeyboard.xcodeproj/project.pbxproj` 머지 충돌 해결**
`git status`가 `UU`, 충돌 마커 8개. **현재 빌드 불가 상태다.** 다른 모든 작업의 선행 조건.
pbxproj 충돌은 보통 파일 참조 양쪽 유지로 해결되지만, 최근 추가분(`UsageReportingService`, `UsageStatsView`, `UsageTrendChartView`)이 **어느 타겟 멤버십에 들어가는지**를 반드시 확인할 것: 특히 `AnalyticsService.swift`는 키보드 익스텐션 타겟에도 포함돼야 하고, LeeoKit 참조는 들어가면 안 된다.
검증: 3개 타겟(앱/키보드/위젯) 빌드 + 전체 테스트 그린.

---

### Phase 1: 출시 신뢰 (이번 릴리즈, ~1주)

목표: **4.4.3을 "표기와 실제가 일치하는" 상태로 내보낸다.**

**P1-1. 통계 파이프라인 완결** ← 최우선
- CloudKit Dashboard: `UsageSnapshot`·`UsageEvent` 스키마 → 인덱스(recordName Queryable, UsageEvent `createdTimestamp` Sortable) → admin read → **Production 배포**
- 실기기 1대에서 스냅샷 1건 업로드 → `설정 > 지원 > 사용 통계`에서 카운트·차트 렌더링 육안 확인 (현재 유닛 테스트까지만 검증됨)
- App Store Connect **App Privacy** → 답안 확정 완료: `docs/APP_PRIVACY_ANSWERS.md` (콘솔 입력만 남음)
- ✅ 문구 정리 완료 (2026-07-30), "아무것도 수집 안 함" 주장이 있던 **6개 문서** 수정:
  `privacy.html`(ko·en 사전 포함) · `index.html` · `tutorial.html` · `ASO_2026-07.md`(스토어 설명 원고) ·
  `README.md` · `RELEASE_NOTES_4.4.3.md`(수집 고지 추가)

> ⚠️ **옵트아웃 없는 설계 재검토**: `todo.md`에 기록된 대로 심사 5.1.1(ii)/GDPR 지적 여지가 있다.
> 리젝 시 복구 비용(토글 되살리기)이 작으니 그대로 가되, **되살릴 코드 위치를 문서에 남겨둘 것**.

**P1-2. `PrivacyInfo.xcprivacy` 추가 (4개 타겟 전부)** ✅ **완료 (2026-07-30)**
- 앱 / 키보드 / 공유 / 위젯 4개 파일 작성 → 4개 번들 모두에 포함 확인
- 접근 API: `NSPrivacyAccessedAPICategoryUserDefaults`: 앱은 `CA92.1`+`1C8F.1`, 익스텐션 3개는 `1C8F.1`만
  (실사 결과 익스텐션은 `UserDefaults.standard`를 쓰지 않는다)
- 수집 신고 6종: Product Interaction · Purchase History · Device ID(익명 설치 UUID) ·
  Customer Support · Email · Name → 답안서 `docs/APP_PRIVACY_ANSWERS.md`
- 등록 스크립트 `scripts/add_privacy_manifests.rb` (멱등).
  ⚠️ `widget/`은 Xcode 16 동기화 그룹이라 **파일만 두면 자동 포함**, pbxproj 등록 대상이 아니다

**P1-3. 크래시·행 가시성, MetricKit + FeedbackHub**
Sentry/Crashlytics를 붙이지 **않는다.** 이유: 외부 SDK 0개 원칙 유지, 개인정보 신고 항목 증가 회피, **이미 CloudKit 허브가 있다**.

```
MXMetricManager.add(subscriber)
 ├ MXDiagnosticPayload → crashDiagnostics / hangDiagnostics / diskWriteExceptionDiagnostics
 │    → 콜스택 심볼 + 앱 버전 + OS + (익스텐션 여부)만 추출
 └ LeeoUsageReporter 와 같은 컨테이너에 CrashReport 레코드로 upsert
      → UsageStatsView 옆에 "안정성" 탭 (마스터 모드 전용)
```
- 이득: **키보드 익스텐션의 메모리 종료(jetsam)까지 잡힌다**, 이 앱에서 가장 위험한 실패 모드
- 한계: MetricKit은 최대 24시간 지연 + 기기 기준 집계. 실시간 알림이 필요하면 그때 Sentry 검토
- 위치 제안: `Shared/` 또는 LeeoKit(`LeeoDiagnostics`), 5절 참조

---

### Phase 2: 견고성 (~2주)

**P2-1. CI 파이프라인** (`.github/workflows/ci.yml`, macOS 러너)
```
PR/푸시 → xcodebuild build (앱·키보드·위젯) 
        → xcodebuild test (ClipKeyboardTests)
        → python3 scripts/check_localization.py     # 이미 있는 자산
        → swiftlint --strict (경고만, 초기엔 non-blocking)
```
`scripts/predeploy.sh`가 이미 있으니 그 내용을 워크플로로 승격하는 게 최단 경로.
SwiftLint 규칙은 **처음부터 엄격하게 걸지 말 것**, 145파일에 경고 폭탄이 떨어지면 아무도 안 본다.
1차는 `force_try`, `force_unwrapping`, `file_length` 3개만.

**P2-2. 조용한 실패 제거, `try?` 127개 트리아지**
전부 고치는 건 낭비다. **데이터 경로만** 고른다:
- `MemoStore` 저장/로드 · `CategoryStore` · 마이그레이션 · `CloudKitBackupService` · `MemoSyncEngine`
- 규칙: **읽기 실패는 폴백 허용, 쓰기 실패는 반드시 표면화** (로그 + 필요 시 사용자 알림)
- 기존 컨벤션 유지: `print("❌ [MemoStore.save] …")` → P2-3에서 OSLog로 승격

**P2-3. 구조적 로깅 전환**
`Logger(subsystem: "com.Ysoup.TokenMemo", category: "MemoStore")` 형태로 통일.
이모지 컨벤션(📁✅❌🔄)은 메시지 안에 유지, 기존 디버깅 팁(`CLAUDE.md`)이 그대로 동작한다.
`.error` 이상은 sysdiagnose에 남아 사후 추적이 가능해진다. 우선 대상: 동기화·백업·마이그레이션 3개 모듈.

**P2-4. 원격 킬스위치**
FeedbackHub public DB에 `RemoteFlags` 레코드 1건(앱별 recordName). 런치 시 fetch, 실패하면 **로컬 기본값 = 전부 켬**(가용성 우선).
최소 플래그: `syncEnabled`(동기화 베타), `usageReportingEnabled`(수집 중단 스위치: 옵트아웃 없는 설계의 안전판), `paywallEnabled`.
읽기 코드는 `UsageReportingService`의 CloudKit 접근을 그대로 재사용하면 된다.

---

### Phase 3, 성장·관측 (Phase 1 데이터가 쌓인 뒤)

Phase 1이 끝나면 **처음으로 실제 사용 데이터가 생긴다.** 그 위에서만 의미 있는 작업들이다.

**P3-1. 전환 퍼널**, 이벤트는 이미 다 있다(`paywall_view` → `paywall_cta_tapped` → `paywall_purchase` / `purchase_cancelled` / `purchase_failed`).
`UsageStatsView`에 퍼널 단계별 전환율만 얹으면 된다. "안 누름 vs 누르고 이탈"이 이미 분리돼 있는 게 강점.

**P3-2. 리텐션 코호트**, `UsageSnapshot.firstSeen` + `app_open` 이벤트로 D1/D7/D30 산출. 새 이벤트 불필요.

**P3-3. 평가 13개 → 50개**, `ReviewManager`는 이미 있다. 요청 **타이밍**을 데이터로 조정:
`timeSavedMin`이 임계값을 넘은 직후(가치 순간)에만 요청. 현재 트리거 조건을 P3-1 데이터로 검증.

**P3-4. 마케팅 발행**: `docs/ASO_2026-07.md`, `MARKETING_PLAN_2026-07.md`, `KR_COMMUNITY_POSTS.md`, `PRODUCT_HUNT_LAUNCH.md`가 **다 쓰여 있는데 발행이 안 됐다**(포트폴리오 리포트: "실제 발행·이벤트·캠페인 미진행").
새로 만들 것 없음. 발행 일정만 잡으면 되는 단계다.

---

## 4. 하지 않을 것 (명시적 비목표)

| 안 하는 것 | 이유 |
|-----------|------|
| 성숙도 점수 올리려고 Firebase/Amplitude 도입 | 자체 파이프라인이 이미 동작한다. 점수 규칙이 현실을 못 따라온 것이지 앱이 부족한 게 아니다 → **판정 규칙 쪽을 고친다** |
| CoreData/SwiftData 마이그레이션 | JSON + App Group이 키보드 익스텐션 제약(메모리·기동시간)에 더 맞다. 리포트의 `localdb: false`는 결함이 아니다 |
| 서버 백엔드 구축 | CloudKit으로 충분. 운영 비용·개인정보 책임만 늘어난다 |
| SwiftLint 전체 규칙 일괄 적용 | 경고 폭탄 → 무시 → 무의미. 3개 규칙으로 시작 |

---

## 5. 공용화 판단, LeeoKit으로 올릴 것

크래시·CI·개인정보 매니페스트는 **46개 앱 중 43~45개가 동일하게 비어 있다.**
클립키보드에서 검증한 뒤 공용 자산으로 승격한다.

| 자산 | 승격 위치 | 전파 대상 |
|------|----------|----------|
| `LeeoDiagnostics` (MetricKit → 허브) | LeeoKit | 45개 앱, Spec 한 줄로 활성화 |
| `LeeoRemoteFlags` (킬스위치) | LeeoKit | FeedbackHub 쓰는 28개 앱 |
| `PrivacyInfo.xcprivacy` 템플릿 | 공용 템플릿 | 43개 앱 |
| `ci.yml` 워크플로 템플릿 | 공용 템플릿 | 전체 |
| 판정 규칙 개정(자체 수집 등급) | `app-portfolio/scripts/build-portfolio-status.py` | 리포트 전체 정확도 |

클립키보드가 **파일럿**이다. 포트폴리오 1위 앱이고, LeeoKit·FeedbackHub·CloudKit이 이미 다 붙어 있어 검증 비용이 가장 싸다.

---

## 6. 성공 기준

| 시점 | 확인 |
|------|------|
| Phase 0 완료 | 3개 타겟 빌드 그린 + 전체 테스트 통과 |
| Phase 1 완료 | 실기기 스냅샷이 `사용 통계` 화면에 표시 · App Privacy 신고와 `PrivacyInfo.xcprivacy` 일치 · 크래시 리포트 1건 이상 수신 확인 |
| Phase 2 완료 | PR마다 CI 자동 실행 · 동기화/백업/마이그레이션 실패가 로그에 남고 조용히 삼켜지지 않음 · 원격 플래그로 기능 1개 끄기 실증 |
| Phase 3 (3개월) | 평가 50개+ · 페이월 전환율·D7 리텐션 수치 확보 · 마케팅 채널 3곳 이상 발행 |
| 포트폴리오 | 판정 규칙 개정 후 성숙도 재산출 · LeeoKit 자산 2개 이상 다른 앱에 적용 |

---

*작성: 2026-07-30 · 갱신 시 `todo.md` 및 포트폴리오 리포트와 함께 볼 것*
