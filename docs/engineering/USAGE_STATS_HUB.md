# 사용 통계, 공용 허브(FeedbackHub) 수집·조회

피드백과 **같은 CloudKit 컨테이너**(`iCloud.com.Ysoup.FeedbackHub`, public DB)에 익명 사용 통계를
쌓고, 앱 안(설정 > 지원 > 사용 통계)에서 그대로 읽어 본다. 별도 서버·SDK 없음.

- 전송 엔진: LeeoKit `LeeoUsageReporter` (**v2.9.0 이상**, `occurredAt`·`installID` 필요)
- 앱 정책: `ClipKeyboard/Service/UsageReportingService.swift`
- 활동일 원장: `ClipKeyboard/Service/AnalyticsService.swift`의 `KeyboardDayLedger`
- 조회 화면: `ClipKeyboard/Screens/UsageStatsView.swift` (마스터 모드 전용)

> ⚠️ LeeoKit은 **2.x 라인(`release/2.x` 브랜치)** 에 핀 고정돼 있다. 3.0은 `LeeoAppSpec`에
> `legal`·`monetization`을 강제하는 breaking 변경이라, 그 마이그레이션을 할 때 따로 올린다.

## 무엇을 보내나

| 레코드 | 언제 | 내용 |
|---|---|---|
| `UsageSnapshot` | 프로세스 시작 시, 설치당 1건 upsert (12시간 쓰로틀) | 익명 설치 UUID, 앱 버전·플랫폼·OS·로케일, 실행 횟수, 주요 행동 수, 설치 후 경과일, 마지막 활동 시각, `metrics` JSON |
| `UsageEvent` | 주요 행동 시, **이름당 6시간에 1건** (`app_open`만 20시간) | 이벤트 이름(+슬라이스), 앱 버전·플랫폼, 익명 설치 UUID, **발생 시각(`occurredAt`)** |
| `Feedback` | 사용자가 피드백을 보낼 때 | 기존 LeeoKit 피드백 (변경 없음) |

`metrics` (설치당 대략 지표, 전부 숫자):
`shortcuts` `ownShortcuts` `combos` `templates` `images` `texts` `favorites` `uses` `timeSavedMin`
`categories` `unusedShortcuts` `topUses` `clips` `keyboardUses`
`flag.isPro` `flag.keyboardActive` `flag.syncOn` `persona.<페르소나>`

### `shortcuts` 와 `ownShortcuts` 는 다른 숫자다

`shortcuts` 는 저장된 단축어 **전부**를 센다. 온보딩이 심어 주는 샘플 4개
(`ClipKeyboardApp.performSampleInsertion`, 페르소나 무관하게 4개)가 여기 포함된다.
그래서 아무것도 만들지 않은 신규 설치도 4에서 시작하고, 개수 분포의 봉우리가
`4~6` 칸에 섰다. 그것은 사용자의 행동이 아니라 시드값이었다.

`ownShortcuts` 는 `SampleMemoStorage` 에 적힌 샘플 ID를 뺀 값, 즉 **사용자가 직접
저장한 개수**다. "결제 문턱까지 얼마나 왔나" 를 묻는 개수 분포 차트는 이쪽을 본다.

- `shortcuts` 는 **뜻을 바꾸지 않는다.** 과거 스냅샷이 그 키로 쌓여 있어서, 같은
  이름의 뜻을 바꾸면 추이가 그 지점에서 끊긴다
- 분포 차트는 `ownShortcuts` 가 **없는 구버전 스냅샷을 세지 않는다.** 폴백으로
  `shortcuts` 를 쓰면 뜻이 다른 두 숫자가 한 막대에 섞여, 지우려던 봉우리가 남는다.
  빠진 개수는 `UsageInsights.legacyShortcutSnapshotCount` 로 화면 아래에 밝힌다
- ⚠️ **한도 판정(`ProFeatureManager.canAddMemo`)은 아직 `memos.count` 를 본다**, 즉
  샘플까지 센다. 차트와 페이월이 서로 다른 숫자를 보는 동안에는 거리가 4만큼 어긋난다
  (샘플을 남겨 둔 사람은 차트의 6개에서 이미 한도). 화면 아래 경고가 그 말을 하고 있다

## 키보드만 쓰는 사용자를 어떻게 세나

이 앱은 **메인 앱을 거의 안 열고 키보드만 쓰는 사용자**가 상당수다. 익스텐션은 네트워크를
쓰지 않으므로(메모리 상한 약 60MB·심사 리스크) 그 사람들의 활동은 기본적으로 허브에 안 남는다.

그래서 **날짜별 원장 + 소급 전송**으로 메운다:

1. 익스텐션이 키보드가 뜰 때마다 App Group에 `kb.beacon.dayCounts`(`"yyyy-MM-dd"` → 횟수)를
   쌓는다. UserDefaults 쓰기뿐이라 입력 경로에 비용이 거의 없다.
2. 앱이 앞으로 나오거나 백그라운드 새로고침이 돌면 `reportKeyboardActiveDays()`가
   그 날짜들을 `keyboard_active_day` 이벤트로 보내되, **`occurredAt`을 실제 사용일로 찍는다.**
   앱을 2주 만에 열어도 그 2주가 추이 차트에 그대로 복원된다.
3. **오늘은 보내지 않는다.** 보내고 원장에서 지우면 오늘 키보드를 더 쓸 때 같은 날이 다시
   쌓여 중복이 된다. 오늘 앱을 열었다면 `app_open`이 이미 활동을 증명한다.
4. 전송이 **확정된 날만** 원장에서 지운다. iCloud 미로그인·네트워크 실패로 못 보낸 날은
   남아 다음 기회에 다시 나간다 (`logEvent`의 반환값이 그 판단 근거).

한 번에 최대 40일까지 보내고 나머지는 다음 기회로 미룬다(백그라운드 task 시간 제한).
원장 보관 한도는 120일, 그보다 오래 앱을 안 열면 가장 오래된 날부터 버린다.

**남는 사각지대**: 설치 후 앱을 영영 한 번도 다시 열지 않고 백그라운드 새로고침도
한 번도 안 뜨는 사용자. 익스텐션이 직접 네트워크를 쓰지 않는 한 구조적으로 셀 수 없다.

### `app_open`은 앞으로 나온 순간에만
프로세스 시작(`reportProcessStart`)과 사람이 앱을 연 순간(`reportForegroundOpen`)은 다르다.
백그라운드 새로고침으로 깨어난 경우에도 `ClipKeyboardApp.init`은 돈다. 여기서 `app_open`을
남기면 **앱을 열지도 않은 사람이 앱 사용자로 잡혀**, 정작 가려내려는 "키보드만 쓰는 사람"이
사라진다. 그래서 `app_open`과 실행 횟수는 화면이 실제로 뜨는 경로에서만 남긴다.

**보내지 않는 것**: 단축어 제목·내용, 클립보드 내용, 이미지, 이메일·이름, 기기 식별자(IDFA/IDFV),
위치. 설치 식별은 앱이 만든 무작위 UUID(`leeo.usage.installID`)뿐이고 재설치하면 새 값이 된다.

**옵트아웃 없음**: 앱 소유자 결정으로 사용자가 끄는 설정은 두지 않는다(항상 수집).
그래서 보내는 항목을 늘릴 때는 "이게 정말 익명 집계 수치인가"를 더 엄격히 따져야 하고,
App Privacy 설문·개인정보 처리방침에 수집 사실이 정확히 적혀 있어야 한다.
⚠️ 심사 가이드라인 5.1.1(ii)(사용 데이터 수집 동의)와 EU GDPR/ePrivacy(설치 식별자 저장) 관점에서
지적 여지가 있는 선택이다. 리젝되면 옵트아웃 토글이 가장 빠른 해법이다.

## 기간별 차트 (일·주·월·연)

통계 화면의 "기간별 추이"는 **UsageEvent의 `occurredAt`** 으로 만든 시계열이다
(`UsageReportingService.trend(unit:events:snapshots:)`, 빈 구간까지 채워 차트가 끊기지 않게 함).

⚠️ `creationDate`가 아니라 `occurredAt`을 본다. `creationDate`는 서버가 "쓴 시각"을 찍기
때문에, 소급 전송된 키보드 활동일이 전부 보낸 날 하루로 뭉쳐 버린다. `occurredAt`이 없는
구버전 레코드는 `creationDate`로 떨어진다(하위 호환).

- 표시값 3가지: **활동한 사용자**(구간 내 서로 다른 installID) / **사용 건수**(이벤트 수) /
  **신규 사용자**(스냅샷 `installDate` 기준)
- 스크롤: `chartScrollableAxes(.horizontal)` + `chartXVisibleDomain`, 한 화면에 일 14 / 주 12 /
  월 12 / 연 5개를 보여주고, 좌우로 넘기면 그 단위만큼 과거로 이동한다(묶음 경계에 스냅).
- **`app_open`(20시간 쓰로틀)** 과 **`keyboard_active_day`** 가 일간 활성 사용자의 근거다.
  스냅샷의 `lastActiveAt`은 덮어쓰기라 날짜별 이력이 남지 않기 때문, 이벤트 하나로
  "이 설치가 그날 활동했다"를 남긴다. 앞쪽은 앱을 연 날, 뒤쪽은 키보드만 쓴 날이다.
  둘을 합쳐야 진짜 활성 사용자이고, 둘을 나눠 보면 "앱을 여는 사람 vs 키보드만 쓰는 사람"이
  갈린다(`installs` 기준으로 비교).
- 이벤트 조회는 커서로 최대 3,000건까지 이어 받는다. 그보다 오래된 구간은 차트에 안 나온다
  (더 길게 보려면 `fetchEvents(limit:)` 상향 또는 서버측 집계 도입 검토).

## 이벤트 이름

`AnalyticsService.log()` 호출이 그대로 이벤트가 된다 (`AnalyticsEvent` rawValue).
슬라이스 파라미터(`triggeredBy` > `source`)가 있으면 `paywall_view:memo` 형태로 붙는다.

연결 지점은 `ClipKeyboardApp.init`의 `AnalyticsService.eventSink` 한 줄이다.
⚠️ `AnalyticsService.swift`는 키보드 익스텐션 타겟에도 포함되므로 그 파일에서
LeeoKit/CloudKit을 직접 참조하면 안 된다 (익스텐션에는 훅이 꽂히지 않아 콘솔 로깅만 한다).

## 🚨 `occurredAt` 필드 배포, 앱을 내보내기 **전에**

Production 스키마는 잠겨 있다. 레코드 타입에 없는 필드를 담아 저장하면 **그 저장이 실패한다.**
`occurredAt`은 모든 `UsageEvent`에 들어가므로, 스키마 배포 전에 앱이 먼저 나가면
`app_open`을 포함한 **이벤트 전송이 통째로 실패한다**(스냅샷은 무사).

반드시 이 순서로:

1. 새 빌드를 **Development 환경**에서 한 번 실행하고 주요 행동을 한 번 한다
   → `UsageEvent`에 `occurredAt`(Date/Timestamp) 필드가 자동 생성된다.
2. CloudKit Dashboard에서 필드가 생겼는지 눈으로 확인한다.
3. **Schema → Deploy Schema Changes to Production.**
4. 그 다음에 앱을 심사에 올린다.

순서가 뒤집혀도 **키보드 활동일은 유실되지 않는다**, 전송이 확정된 날만 원장에서 지우므로,
스키마를 배포하면 밀린 날짜가 다음 실행에서 한꺼번에 나간다. 다만 그 사이의 `app_open`은
로컬 쓰로틀이 이미 찍혀 다시 나가지 않으니, 그 기간의 앱 접속 기록은 복구되지 않는다.

## CloudKit Dashboard 준비 (1회)

https://icloud.developer.apple.com → `iCloud.com.Ysoup.FeedbackHub`

1. **스키마 생성**: Development 환경에서 앱을 한 번 실행(스냅샷)하고 주요 행동을 한 번 하면
   `UsageSnapshot` / `UsageEvent` 레코드 타입이 자동 생성된다.
2. **인덱스**:
   - `UsageSnapshot`: `recordName` **Queryable** (전체 조회용)
   - `UsageEvent`: `recordName` **Queryable** + `createdTimestamp` **Sortable** (최신순 조회용)
   - `appId`는 인덱스 없이 클라이언트에서 필터한다. 인덱스 배포를 늘리지 않기 위함.
3. **Security Roles**: `_world` 는 create만, read 제거. admin 역할에 read + 개발자 본인
   userRecordName 등록 (피드백 인박스와 동일, 인박스 하단에서 userRecordName 복사 가능).
4. **Production 배포**: Schema → Deploy Schema Changes to Production.

배포 전에는 앱에서 통계 화면이 "불러오지 못했어요 / read 권한 필요" 안내를 보여준다(정상).

## App Store 제출 시

익명 사용 데이터를 수집하므로 **App Privacy(개인정보 처리방침 설문)** 를 갱신해야 한다:
- Data Type: *Product Interaction* (Usage Data), Analytics 목적, **사용자와 연결되지 않음**,
  추적(Tracking) 아님(ATT 불필요, 광고/데이터 브로커 공유 없음).
- 앱 안에 끄는 스위치가 없으므로, 개인정보 처리방침에 수집 항목·목적·보관을 명시해 둘 것.
- 4.4.0 macOS 릴리즈 노트의 "외부로 아무 통계도 보내지 않아요" 문구는 이 기능이 들어간
  버전부터는 맞지 않는다. 릴리즈 노트/개인정보 처리방침 문구를 함께 갱신할 것.
