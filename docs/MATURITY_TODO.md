# 성숙도 투두, 8개 영역 실행 목록

> 근거: `app-portfolio` 완성도 체크리스트 8개 영역 + 2026-07-30 리포지토리 실사
> 설계 배경: `docs/SERVICE_MATURITY_PLAN.md` · 이 문서는 그 **실행 목록**이다
> 각 항목은 **PR 하나 크기**를 목표로 쪼갰다.
>
> **진행 상태 (2026-07-31)**: `[x]` 완료 · `[~]` 부분 완료(뒤에 남은 일 명시) · `[ ]` 미착수.
> P1·P2 코드 항목과 P3 집계 로직은 완료. 남은 큰 덩어리는 **P0(콘솔 수동 작업)**,
> P3 화면 표시, P4 마케팅 발행이다.

## 0. 리포트와 달라진 점 (먼저 읽을 것)

체크리스트는 기준일 07-26 스냅샷이라 아래는 **이미 해결됐다**:

| 체크리스트 표기 | 실제 (07-30) |
|---|---|
| 🔐 개인정보 매니페스트 ✕ | ✅ **완료**, 4개 타겟 전부 (`6f7f255`) |
| 🔭 사용현황 분석 `로컬만` | ✅ **코드 완료**, FeedbackHub 수집 구현. 단 CloudKit 프로덕션 배포가 남아 미완결 |
| 🗄️ 자동저장·작업 복구 `수동` | ✅ **이미 있음**, `DraftStore` / `SavedDraft` / `DraftListView` |
| 🗄️ 동기화 충돌 처리 `수동` | ✅ **정책 있음**, id 단위 최신 우선 + 툼스톤 (`MemoSyncEngine`) |
| ✨ 햅틱 `수동` | ✅ **이미 있음**, `HapticManager` 15개 파일에서 사용 |

반대로 실사에서 **새로 발견된 구멍**:

- 📱 **위젯만 iPhone 전용** (`TARGETED_DEVICE_FAMILY = 1`). 앱·키보드·공유확장은 `1,2`(iPad 지원) → iPad 사용자는 위젯을 못 쓴다
- 🗑 **메모 전체 삭제 경로 없음**, 클립보드 히스토리만 "전체 삭제"가 있다
- 📄 **이용약관(EULA) 없음**, `docs/terms.html` 부재. IAP 앱이라 권장 항목
- 🧪 **마이그레이션 전용 테스트 없음**, 마이그레이션 코드는 6곳에 있는데 검증이 없다

---

## 실행 순서

| 단계 | 묶음 | 항목 수 | 왜 이 순서인가 |
|---|---|---:|---|
| **P0** | 4.4.3 출시 마무리 | 3 | 릴리즈 블로커. 이거 없이는 출시 자체가 어긋난 상태 |
| **P1** | 장애 가시성 + QA 자동화 | 6 | 출시 후 무슨 일이 나는지 볼 수 없는 게 지금 최대 위험 |
| **P2** | 복원력 + 데이터 안정성 | 8 | 사고가 났을 때 대응할 수단 |
| **P3** | 성장·관측 심화 | 6 | P1의 데이터가 쌓인 뒤에야 의미가 있다 |
| **P4** | 마케팅 발행 | 5 | 만들어둔 자산을 실제로 내보내기 |

---

## P0 · 4.4.3 출시 마무리 (릴리즈 블로커)

- [ ] **CloudKit 스키마 Production 배포**, `UsageSnapshot`/`UsageEvent` 생성 → 인덱스(recordName Queryable, createdTimestamp Sortable) → admin read → Deploy.
      절차: `docs/APP_PRIVACY_ANSWERS.md` 0절 · **콘솔 수동 작업**
- [ ] **실기기 검증**, 스냅샷 1건 업로드 → `설정 > 지원 > 사용 통계`에 카운트·차트 렌더링 확인.
      지금까지 유닛 테스트·빌드까지만 검증됐고 실데이터 렌더링은 미확인
- [ ] **App Store Connect App Privacy 입력**, 6개 항목. 답안: `docs/APP_PRIVACY_ANSWERS.md` 1절 · **콘솔 수동 작업**

## P1 · 🛟 장애 가시성 + 🧪 QA 자동화

- [x] **MetricKit 진단 수집** ✅ `DiagnosticsService` (⚠️ 실기기 검증 남음 (시뮬레이터엔 페이로드가 거의 안 온다)) `MXMetricManager` 구독 → crash/hang/diskWrite 페이로드에서 콜스택·앱버전·OS만 추출 → FeedbackHub에 `CrashReport` 레코드.
      외부 SDK 0개 유지, 개인정보 신고 항목 증가 없음. **키보드 익스텐션 jetsam(메모리 종료)까지 잡히는 게 핵심**
- [x] **안정성 화면** ✅ `CrashReportsView`, 버전별 진단 건수 + 콜스택(접기). 설정 > 지원(마스터 모드), `UsageStatsView` 옆 탭. 버전별 크래시 건수·상위 콜스택 (마스터 모드 전용)
- [~] **성능 지표 수집**, `MXMetricPayload` 수신·로그까지만. 허브 적재는 크래시 가시성이 자리잡은 뒤: 같은 MetricKit 페이로드의 `MXMetricPayload`(앱 시작시간·메모리·배터리)도 함께 적재. 위 작업에 얹으면 추가 비용 거의 없음
- [x] **GitHub Actions CI** ✅ `.github/workflows/ci.yml`, `predeploy.sh` 호출로 게이트 단일화, `.github/workflows/ci.yml`: build(앱·키보드·위젯) → test → `scripts/check_localization.py`.
      `scripts/predeploy.sh` 내용을 워크플로로 승격하는 게 최단 경로
- [x] **SwiftLint 도입 (3개 규칙만)** ✅ `.swiftlint.yml`, 프로덕션 위반 13건(강제 언랩 11·파일 길이 2). 테스트는 대상 제외, `force_try` / `force_unwrapping` / `file_length`.
      145개 파일에 전체 규칙을 걸면 경고 폭탄 → 아무도 안 본다. 초기엔 non-blocking
- [~] **경고 0 유지 장치**, 현재 컴파일 경고 0 유지 중. CI의 lint 잡은 아직 non-blocking(위반 13건 해소 후 전환), CI에서 신규 경고 발생 시 실패. 현재 경고 0이라 지금이 거는 최적 시점

## P2 · 🛟 복원력 + 🗄️ 데이터 안정성 + 🔐 보안

- [x] **원격 킬스위치** ✅ `RemoteFlagsService`: 동기화·통계 게이트 연결, 테스트 5개. ⚠️ CloudKit에 `RemoteFlags` 레코드 생성은 남음. FeedbackHub public DB에 `RemoteFlags` 레코드 1건. 런치 시 fetch, 실패하면 **로컬 기본값 = 전부 켬**(가용성 우선).
      최소 플래그: `syncEnabled` · `usageReportingEnabled`(옵트아웃 없는 설계의 안전판) · `paywallEnabled`.
      CloudKit 접근 코드는 `UsageReportingService`의 것을 재사용
- [x] **전역 에러 핸들링·폴백 화면** ✅ `DataRecoveryView` + `MemoStore` 손상 격리 (조용한 데이터 유실 경로를 막았다) 최상위에서 치명적 실패를 잡아 "데이터를 불러오지 못했어요 + 복구 시도" 화면 제공. 현재는 빈 화면으로 보일 수 있음
- [x] **`try?` 데이터 경로 트리아지** ✅ 조용한 **쓰기** 실패 4곳 처리. 핵심은 동기화 병합 저장 (실패해도 섀도가 갱신돼 원격 변경을 다시 안 받아오던 문제를 고침(실패 시 섀도 갱신 건너뛰고 재시도)) 127개 전부가 아니라 `MemoStore`·`CategoryStore`·마이그레이션·`CloudKitBackupService`·`MemoSyncEngine`만.
      규칙: **읽기 실패는 폴백 허용, 쓰기 실패는 반드시 표면화**
- [x] **구조적 로깅 전환** ✅ `AppLog`(OSLog), MemoStore·백업·통계·킬스위치·진단 90건 전환(error 14·warning 12·info 64). 이모지 컨벤션 유지, `print` 33개 파일 → `Logger(subsystem:category:)`. 우선 동기화·백업·마이그레이션 3개 모듈.
      이모지 컨벤션(📁✅❌)은 메시지 안에 유지 → 기존 디버깅 팁이 그대로 동작
- [x] **마이그레이션 테스트 신설** ✅ `MigrationCompatibilityTests` 9개 + `DataCorruptionDetectionTests` 7개, 구버전 JSON 픽스처 → 현재 모델 디코딩 검증. 대상: `MemoStore`·`CategoryStore`·`ProStatusManager`·`SmartClipboard`
- [x] **동기화 충돌 테스트 보강** ✅ 기존 10개에 더해 **수렴성** 7개 추가(`MemoSyncConvergenceTests`) (결정성·대칭성·멱등성·시계 역전) "id 단위 최신 우선 + 툼스톤" 정책을 테스트로 고정 (양쪽 수정 / 삭제 vs 수정 / 시계 역전)
- [x] **메모 전체 삭제 경로** ✅ `DataWipeService` + 설정 2단계 확인 (구매·iCloud 백업은 보존), 설정에 "모든 데이터 삭제"(2단계 확인). GDPR 삭제권 대응 + 리뷰어가 찾는 항목
- [x] **이용약관(EULA) 페이지** ✅ `docs/terms.html` + 설정 '약관 및 개인정보' 섹션(처리방침 링크 포함). `docs/terms.html` 신설 + 앱 설정·페이월에서 링크. IAP 앱 권장 항목
- [x] **파일 보호 등급 확인·문서화** ✅ `docs/SECURITY_NOTES.md` 2-1절 (올리지 않는 이유(잠금화면 키보드가 깨진다) 기록) 현재 명시 설정 없음(iOS 기본값).
      ⚠️ 키보드 익스텐션은 잠금 상태 접근이 필요할 수 있어 **무턱대고 올리면 깨진다**, 확인 후 결정·기록만

## P3 · 🔭 관측 심화 + 📈 성장

- [x] **전환 퍼널 화면** ✅ 집계 + `UsageStatsView` 표시 완료 (실데이터 렌더링 확인은 P0 후), `paywall_view` → `paywall_cta_tapped` → `paywall_purchase` / `purchase_cancelled` 단계별 전환율.
      **이벤트는 이미 다 있다**: 집계·표시만 추가
- [x] **리텐션 코호트** ✅ 집계 + `UsageStatsView` 표시 완료 (실데이터 렌더링 확인은 P0 후), `UsageSnapshot.installDate` + `app_open` 이벤트로 D1/D7/D30. 새 이벤트 불필요
- [x] **핵심지표 대시보드 정리** ✅ `UsageStatsView` 에 퍼널·리텐션 섹션 추가(막대 시각화), 위 둘 + 기존 추이 차트를 한 화면에. "이번 주 봐야 할 숫자" 상단 고정
- [ ] **리뷰 요청 타이밍 최적화**, `ReviewManager`는 이미 있음. `timeSavedMin` 임계 돌파 직후(가치 순간)로 조정하고 P3-1 데이터로 검증. 목표 평가 13개 → 50개
- [x] **A/B 테스트 기반** ✅ `ExperimentService`, 설치 UUID 해시로 로컬 결정, 이벤트 슬라이스로 비교. 테스트 5개: 원격 플래그 인프라(P2) 재사용. 첫 실험은 페이월 문구
- [x] **위젯 iPad 지원** ✅ `TARGETED_DEVICE_FAMILY` 1 → 1,2, `TARGETED_DEVICE_FAMILY` `1` → `1,2` + iPad 크기 대응 확인

## P4 · 📣 마케팅 발행

원고는 **이미 다 쓰여 있다**. 새로 만들 게 아니라 내보내는 단계다.

- [ ] **App Store 설명 갱신**, `docs/ASO_2026-07.md` 기준으로 교체(프라이버시 문단이 수집 사실 반영본으로 바뀌었다)
- [ ] **공개 쇼케이스 사이트 발행**, `docs/index.html` GitHub Pages 배포 확인
- [ ] **커뮤니티 게시**, `KR_COMMUNITY_POSTS.md` · `REDDIT_LAUNCH_POST.md`(발행 시 "no data collection" 문구 수정 필요) · `THREADS_LAUNCH_POST.md`
- [ ] **Product Hunt 런치**, `PRODUCT_HUNT_LAUNCH.md`
- [ ] **ASO 키워드 반영 및 추적**, `ASO_2026-07.md` 키워드 적용 후 순위 변화 기록

## 추가로 처리한 것 (2026-07-31)

- [x] **온보딩 완료 이벤트**, `onboarding_completed`. 획득 퍼널의 첫 단계
- [x] **iPad 그리드 대응**, 카드 그리드가 `.flexible()` 2열 고정이라 아이패드에서 카드가
      500pt까지 늘어났다. `.adaptive(minimum:maximum:)` 으로 교체하고 드래그 미리보기 폭도 함께 맞춤
- [x] **최소 권한·암호화 근거 문서화**, `docs/SECURITY_NOTES.md`
      (키보드·위젯 엔타이틀먼트에 App Group만 있어 유출 경로가 구조적으로 없다는 점 포함)

## 프로세스 항목 (코드 아닌 것)

- [x] **TestFlight 베타 루틴** ✅ `docs/RELEASE_PROCESS.md` 3절, 릴리즈 전 외부 테스터 N명, 최소 3일
- [x] **회귀 테스트 체크리스트** ✅ `docs/RELEASE_PROCESS.md` 2절 (자동 테스트가 못 잡는 것만), `docs/TESTING_GUIDE.md`를 릴리즈 전 필수 통과 목록으로 승격
- [x] **롤백 전략 문서화** ✅ `docs/RELEASE_PROCESS.md` 4절 (사고 등급별 대응 + 킬스위치 절차 + 긴급 심사) App Store 단계적 출시(phased release) 중단 절차 + 이전 버전 재제출 판단 기준
- [x] **코드 리뷰 프로세스** ✅ `docs/RELEASE_PROCESS.md` 1절 (CI·SwiftLint·/code-review 를 머지 조건으로) 1인 개발이라 `/code-review` + CI 통과를 머지 조건으로 정의

---

## 하지 않을 것 (명시적 비목표)

| 항목 | 이유 |
|---|---|
| **구조적 로컬 DB (CoreData/SwiftData)** | JSON + App Group이 키보드 익스텐션 제약(메모리·기동시간)에 더 맞다. 체크리스트의 ✕는 결함이 아니라 설계 선택 |
| **Firebase/Amplitude 등 외부 분석 SDK** | 자체 파이프라인이 이미 동작. 점수 규칙이 현실을 못 따라온 것 → 판정 규칙 쪽을 고친다 |
| **Sentry/Crashlytics** | MetricKit + 기존 허브로 충분. 외부 SDK 0개 원칙 유지 |
| **자체 서버 백엔드** | CloudKit으로 충분. 운영 비용·개인정보 책임만 증가 |

## 포트폴리오 공용화 (LeeoKit 승격 후보)

크래시(1/46) · CI(1/46) · SwiftLint(1/46), **46개 앱 중 43~45개가 같은 빈칸**이다.
클립키보드에서 검증 후 공용 자산으로 올려 나머지에 전파한다.

- [ ] `LeeoDiagnostics` (MetricKit → 허브), 45개 앱, Spec 한 줄로 활성화
- [ ] `LeeoRemoteFlags` (킬스위치), FeedbackHub 쓰는 28개 앱
- [ ] `PrivacyInfo.xcprivacy` 템플릿, 43개 앱 (이번 4개 파일이 원본)
- [ ] `ci.yml` 워크플로 템플릿, 전체
- [ ] 포트폴리오 판정 규칙 개정, "자체 수집 파이프라인" 등급 추가 (`build-portfolio-status.py`)
