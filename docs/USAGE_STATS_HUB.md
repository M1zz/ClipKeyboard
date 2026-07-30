# 사용 통계 — 공용 허브(FeedbackHub) 수집·조회

피드백과 **같은 CloudKit 컨테이너**(`iCloud.com.Ysoup.FeedbackHub`, public DB)에 익명 사용 통계를
쌓고, 앱 안(설정 > 지원 > 사용 통계)에서 그대로 읽어 본다. 별도 서버·SDK 없음.

- 전송 엔진: LeeoKit `LeeoUsageReporter` (v2.6.0 이상)
- 앱 정책: `ClipKeyboard/Service/UsageReportingService.swift`
- 조회 화면: `ClipKeyboard/Screens/UsageStatsView.swift` (마스터 모드 전용)

## 무엇을 보내나

| 레코드 | 언제 | 내용 |
|---|---|---|
| `UsageSnapshot` | 앱 실행 시, 설치당 1건 upsert (12시간 쓰로틀) | 익명 설치 UUID, 앱 버전·플랫폼·OS·로케일, 실행 횟수, 주요 행동 수, 설치 후 경과일, 마지막 활동 시각, `metrics` JSON |
| `UsageEvent` | 주요 행동 시, **이름당 6시간에 1건** (`app_open`만 20시간) | 이벤트 이름(+슬라이스), 앱 버전·플랫폼, 익명 설치 UUID |
| `Feedback` | 사용자가 피드백을 보낼 때 | 기존 LeeoKit 피드백 (변경 없음) |

`metrics` (설치당 대략 지표, 전부 숫자):
`shortcuts` `combos` `templates` `images` `favorites` `uses` `timeSavedMin` `keyboardUses`
`flag.isPro` `flag.keyboardActive` `flag.syncOn` `persona.<페르소나>`

**보내지 않는 것**: 단축어 제목·내용, 클립보드 내용, 이미지, 이메일·이름, 기기 식별자(IDFA/IDFV),
위치. 설치 식별은 앱이 만든 무작위 UUID(`leeo.usage.installID`)뿐이고 재설치하면 새 값이 된다.

**옵트아웃 없음**: 앱 소유자 결정으로 사용자가 끄는 설정은 두지 않는다(항상 수집).
그래서 보내는 항목을 늘릴 때는 "이게 정말 익명 집계 수치인가"를 더 엄격히 따져야 하고,
App Privacy 설문·개인정보 처리방침에 수집 사실이 정확히 적혀 있어야 한다.
⚠️ 심사 가이드라인 5.1.1(ii)(사용 데이터 수집 동의)와 EU GDPR/ePrivacy(설치 식별자 저장) 관점에서
지적 여지가 있는 선택이다 — 리젝되면 옵트아웃 토글이 가장 빠른 해법이다.

## 기간별 차트 (일·주·월·연)

통계 화면의 "기간별 추이"는 **UsageEvent의 생성 시각**으로 만든 시계열이다
(`UsageReportingService.trend(unit:events:snapshots:)` — 빈 구간까지 채워 차트가 끊기지 않게 함).

- 표시값 3가지: **활동한 사용자**(구간 내 서로 다른 installID) / **사용 건수**(이벤트 수) /
  **신규 사용자**(스냅샷 `installDate` 기준)
- 스크롤: `chartScrollableAxes(.horizontal)` + `chartXVisibleDomain` — 한 화면에 일 14 / 주 12 /
  월 12 / 연 5개를 보여주고, 좌우로 넘기면 그 단위만큼 과거로 이동한다(묶음 경계에 스냅).
- **`app_open`(20시간 쓰로틀)** 이 일간 활성 사용자의 근거다. 스냅샷의 `lastActiveAt`은
  덮어쓰기라 날짜별 이력이 남지 않기 때문 — 이벤트 하나로 "이 설치가 그날 앱을 열었다"를 남긴다.
- 이벤트 조회는 커서로 최대 3,000건까지 이어 받는다. 그보다 오래된 구간은 차트에 안 나온다
  (더 길게 보려면 `fetchEvents(limit:)` 상향 또는 서버측 집계 도입 검토).

## 이벤트 이름

`AnalyticsService.log()` 호출이 그대로 이벤트가 된다 (`AnalyticsEvent` rawValue).
슬라이스 파라미터(`triggeredBy` > `source`)가 있으면 `paywall_view:memo` 형태로 붙는다.

연결 지점은 `ClipKeyboardApp.init`의 `AnalyticsService.eventSink` 한 줄이다.
⚠️ `AnalyticsService.swift`는 키보드 익스텐션 타겟에도 포함되므로 그 파일에서
LeeoKit/CloudKit을 직접 참조하면 안 된다 (익스텐션에는 훅이 꽂히지 않아 콘솔 로깅만 한다).

## CloudKit Dashboard 준비 (1회)

https://icloud.developer.apple.com → `iCloud.com.Ysoup.FeedbackHub`

1. **스키마 생성**: Development 환경에서 앱을 한 번 실행(스냅샷)하고 주요 행동을 한 번 하면
   `UsageSnapshot` / `UsageEvent` 레코드 타입이 자동 생성된다.
2. **인덱스**:
   - `UsageSnapshot`: `recordName` **Queryable** (전체 조회용)
   - `UsageEvent`: `recordName` **Queryable** + `createdTimestamp` **Sortable** (최신순 조회용)
   - `appId`는 인덱스 없이 클라이언트에서 필터한다 — 인덱스 배포를 늘리지 않기 위함.
3. **Security Roles**: `_world` 는 create만, read 제거. admin 역할에 read + 개발자 본인
   userRecordName 등록 (피드백 인박스와 동일 — 인박스 하단에서 userRecordName 복사 가능).
4. **Production 배포**: Schema → Deploy Schema Changes to Production.

배포 전에는 앱에서 통계 화면이 "불러오지 못했어요 / read 권한 필요" 안내를 보여준다(정상).

## App Store 제출 시

익명 사용 데이터를 수집하므로 **App Privacy(개인정보 처리방침 설문)** 를 갱신해야 한다:
- Data Type: *Product Interaction* (Usage Data) — Analytics 목적, **사용자와 연결되지 않음**,
  추적(Tracking) 아님(ATT 불필요 — 광고/데이터 브로커 공유 없음).
- 앱 안에 끄는 스위치가 없으므로, 개인정보 처리방침에 수집 항목·목적·보관을 명시해 둘 것.
- 4.4.0 macOS 릴리즈 노트의 "외부로 아무 통계도 보내지 않아요" 문구는 이 기능이 들어간
  버전부터는 맞지 않는다 — 릴리즈 노트/개인정보 처리방침 문구를 함께 갱신할 것.
