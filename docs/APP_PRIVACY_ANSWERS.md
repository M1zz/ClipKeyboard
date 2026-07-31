# App Store Connect — App Privacy 설문 답안 (4.4.3)

> 4.4.3부터 익명 사용 통계를 수집하므로 **App Privacy 설문을 반드시 갱신**해야 한다.
> 이 문서는 콘솔에서 그대로 골라 넣을 답이다. 코드 실사 기준일: **2026-07-30**.
>
> ⚠️ **이 답안 = `PrivacyInfo.xcprivacy` 4개 파일**. 한쪽만 바꾸면 심사에서 불일치로 걸린다.
> 근거 코드: `ClipKeyboard/Service/UsageReportingService.swift`, LeeoKit `LeeoFeedbackService`

## 0. 선행 조건 — CloudKit 스키마 배포 (이게 먼저다)

설문보다 **먼저** 끝내야 한다. 안 하면 앱은 통계를 못 올리는데 "수집한다"고 신고하는 꼴이 된다.

https://icloud.developer.apple.com → `iCloud.com.Ysoup.FeedbackHub`

⚠️ **레코드 타입이 5개다.** 통계 2개만 배포하면 크래시 진단·킬스위치·카테고리 동기화가
조용히 동작하지 않는다(앱은 에러 없이 그냥 아무 일도 안 한 것처럼 보인다).

| 레코드 타입 | 무엇 | 없으면 |
|---|---|---|
| `UsageSnapshot` | 설치당 스냅샷 | 사용자 수·활성 집계 안 됨 |
| `UsageEvent` | 행동 이벤트 스트림 | 추이·퍼널·리텐션 안 나옴 |
| `CrashReport` | MetricKit 크래시·행 진단 | 안정성 화면이 비어 있음 |
| `RemoteFlags` | 원격 킬스위치 | **전부 "켬"으로 동작**(안전 기본값이라 사고는 아님) |
| `CategorySettings` | 카테고리 기기 간 동기화 | 카테고리가 다른 기기로 안 넘어감 |

1. **Development에서 스키마 자동 생성** — 앱 실행(→ `UsageSnapshot`), 주요 행동(→ `UsageEvent`).
   `CrashReport`·`CategorySettings`는 해당 동작이 일어나야 생기므로, 안 생기면
   Dashboard에서 직접 만든다(필드는 코드 주석 참고).
   `RemoteFlags`는 **직접 만들어야 한다** — 앱은 읽기만 한다.
2. **인덱스**
   - `UsageSnapshot`: `recordName` **Queryable**
   - `UsageEvent`: `recordName` **Queryable** + `createdTimestamp` **Sortable**
   - `CrashReport`: `recordName` **Queryable** + `createdTimestamp` **Sortable**
   - `RemoteFlags` / `CategorySettings`: recordName 으로 직접 fetch 하므로 인덱스 불필요
   - `appId`는 인덱스 없이 클라이언트 필터 (인덱스 배포 최소화)
3. **Security Roles** — `_world`는 create만, read 제거 / admin 역할에 read + 본인 userRecordName
   ⚠️ `RemoteFlags`는 **`_world` read 가 필요하다**(모든 기기가 읽어야 함).
   ⚠️ 피드백(`Feedback`)의 `_world` **create** 권한을 실수로 막으면 피드백 전송이 통째로 끊긴다.
4. **레코드 생성** — `RemoteFlags` 에 recordName `flags_com.Ysoup.TokenMemo` 레코드를 만들고
   `syncEnabled`·`usageReportingEnabled`·`paywallEnabled` (Int64, 1=켬)을 넣는다.
   필드를 안 만들어도 앱은 "켬"으로 동작한다(안전 기본값).
5. **Deploy Schema Changes to Production**

⚠️ **Development 와 Production 은 완전히 분리된 DB다.** Xcode 빌드는 Development,
TestFlight·App Store 빌드는 Production 을 쓴다. 인박스가 비어 보이면 **환경부터 확인할 것**.

절차 상세: `docs/USAGE_STATS_HUB.md`

**검증**: 실기기에서 앱 실행 → `설정 > 지원 > 사용 통계`에 카운트·차트가 뜨면 성공.
배포 전에는 "불러오지 못했어요 / read 권한 필요"가 뜨는 게 정상이다.

## 1. 설문 답안

App Store Connect → 앱 → **App Privacy** → Data Types

### 수집한다고 답할 항목 (7개)

| App Privacy 항목 | 매니페스트 키 | 사용자와 연결 | 추적 | 목적 | 실제 데이터 |
|---|---|:---:|:---:|---|---|
| **Product Interaction** | `…ProductInteraction` | ❌ No | ❌ No | Analytics | 이벤트 이름(`app_open`, `memo_created` 등), 실행 횟수, 설치당 개수 지표 |
| **Purchases** | `…PurchaseHistory` | ❌ No | ❌ No | Analytics | `flag.isPro` (Pro 보유 0/1) 하나뿐 |
| **Device ID** | `…DeviceID` | ❌ No | ❌ No | Analytics | 앱이 만든 무작위 설치 UUID(`leeo.usage.installID`) |
| **Crash Data** | `…CrashData` | ❌ No | ❌ No | App Functionality | MetricKit 크래시·행 진단(콜스택·앱버전·OS). 설치 식별자도 안 붙인다 |
| **Customer Support** | `…CustomerSupport` | ✅ Yes | ❌ No | App Functionality | 사용자가 보낸 피드백 본문 |
| **Email Address** | `…EmailAddress` | ✅ Yes | ❌ No | App Functionality | 피드백에서 **직접 입력한 경우에만** |
| **Name** | `…Name` | ✅ Yes | ❌ No | App Functionality | 피드백에서 **직접 입력한 경우에만** |

### "수집하지 않음"으로 두는 항목

메모·클립보드·템플릿 **내용**, 위치, 연락처, 사진, 검색·브라우징 기록, 결제 상세(카드·주소),
IDFA/광고 데이터, 건강·금융 정보.

> 메모 내용은 사용자 **개인** iCloud(`iCloud.com.Ysoup.TokenMemo` private DB)에만 들어가고
> 개발자가 접근할 수 없다 → Apple 기준 "수집"이 아니다.

### Tracking (ATT)

**아니오.** 타사 데이터와 결합하지 않고, 데이터 브로커에 넘기지 않으며, 광고에 쓰지 않는다.
→ `NSPrivacyTracking = false`, ATT 권한 요청 없음.

## 2. 판단이 갈릴 수 있는 두 가지 (결정 기록)

**① Purchases 신고** — 금액·영수증은 안 보내고 `flag.isPro` 0/1 하나만 보낸다.
"이 정도는 구매 이력이 아니다"라고 볼 여지도 있지만, 구매 상태에서 파생된 값이 맞으므로 신고하는 쪽을 택했다.
빼려면: 매니페스트에서 `…PurchaseHistory` 블록 삭제 + 설문에서 Purchases 해제 + `UsageReportingService.currentMetrics()`의 `flag.isPro` 제거(셋 다 같이).

**② Device ID 신고** — 설치 UUID는 기기 단위 ID가 아니고 재설치하면 바뀌므로 "기기 식별자가 아니다"라는 해석도 가능하다.
다만 한 설치의 이벤트를 묶는 지속 식별자이고, FirebaseAnalytics도 같은 성격의 app-instance ID를 Device ID로 신고한다. 과소신고 리스크를 피해 신고하는 쪽을 택했다.

## 3. 함께 고쳐야 하는 문구 (완료 상태)

수집을 시작하는 순간 "아무것도 수집 안 함"이라던 문구가 전부 거짓이 된다. 2026-07-30 기준 정리 완료:

- [x] `docs/privacy.html` — 2절을 "수집하는 정보 / 수집하지 않는 정보"로 재구성, 1·5·8절 및 meta/og 설명 수정 (ko·en 사전 모두)
- [x] `docs/index.html` — hero 배지 "데이터 수집 없음" 및 프라이버시 문단 (ko·en)
- [x] `docs/tutorial.html` — FAQ "개발자는 어떤 데이터도 수집하지 않습니다" (ko·en)
- [x] `docs/ASO_2026-07.md` — **App Store 설명 원고**의 프라이버시 문단
- [x] `README.md` — Privacy 항목
- [x] `docs/RELEASE_NOTES_4.4.3.md` — 수집 시작 고지 추가 (ko·en + 스토어 요약)

남은 것:
- [ ] **App Store Connect 설명란**이 이미 옛 프라이버시 문구로 게시돼 있다면 ASO 원고 기준으로 교체
- [ ] `docs/REDDIT_LAUNCH_POST.md`의 "no data collection" — 미발행 초안이라 발행 시점에 함께 수정
- [ ] `docs/RELEASE_NOTES_4.4.0_macOS.md`의 "외부로 아무 통계도 보내지 않아요" — **과거 릴리즈 노트라 그대로 둔다**(그 시점엔 사실이었음). 맥 앱에 통계를 넣을 때 새 노트에서 고지할 것

## 4. 리젝되면

가이드라인 **5.1.1(ii)** (사용 데이터 수집 동의) 또는 GDPR/ePrivacy 관점에서 **옵트아웃 부재**가 지적될 수 있다.
이건 앱 소유자가 알고 내린 결정이다(`docs/USAGE_STATS_HUB.md`).

가장 빠른 해법은 **옵트아웃 토글 복구**다. 4.4.3 직전에 의도적으로 제거했으므로 git 이력에서 되살리면 된다:

- 제거된 것: 설정 토글 UI, `usageReportingEnabled` 키, 관련 다국어 문자열 2개
- 되살릴 위치: `UsageReportingService`의 전송 지점(`reportLaunch()` / `record(event:)`)에서 플래그 확인
- ⚠️ 옵트아웃 **테스트는 남아 있지 않다** — 되살릴 때 새로 써야 한다
  (현재 `UsageReportingServiceTests` 14개는 쓰로틀·지표 키·훅 규약·버킷팅만 검증)

토글을 되살리면 이 문서의 답안은 그대로 유효하다(수집 항목 자체는 변하지 않음).
