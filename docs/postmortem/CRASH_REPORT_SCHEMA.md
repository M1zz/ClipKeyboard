# CrashReport 스키마 (FeedbackHub)

`DiagnosticsService` 가 MetricKit 진단을 올리고 `CrashReportsView` 가 읽는 레코드 타입.
컨테이너는 피드백·통계와 같은 `iCloud.com.Ysoup.FeedbackHub` 공개 DB 를 쓴다.

## 왜 이 문서가 생겼나

설정 > 지원 > 안정성 화면에 **"Did not find record type: CrashReport"** 가 떴다.
앱 버그가 아니라 스키마가 없어서 나는 소리다.

CloudKit 은 **저장(save)이 성공할 때만, 그것도 Development 환경에서만** 레코드 타입을
자동으로 만든다. 조회로는 절대 안 만들어진다. 그런데 이 타입에 쓰는 유일한 경로인
`DiagnosticsService.upload` 는 다음 조건이 다 맞아야 돌아간다.

- 실기기 (시뮬레이터엔 MetricKit 진단 페이로드가 거의 안 온다)
- 실제로 크래시·행이 났고, iOS 가 하루 한 번꼴로 묶어서 보내줄 때까지 기다림
- `usageReportingEnabled` 원격 플래그가 켜져 있음

그래서 한 번도 저장이 성공한 적이 없었고, 타입은 만들어지지 않았고, 조회는 계속 실패했다.
**수집 코드와 조회 화면만 만들고 스키마 배포를 안 한 상태**였다.

`Feedback`(`docs/engineering/FEEDBACK_CLOUDKIT.md`)과 `UsageEvent`(`docs/engineering/USAGE_STATS_HUB.md`)에는 이 절차가
문서로 있는데 `CrashReport` 만 빠져 있었다. 이 문서가 그 구멍을 메운다.

## 레코드 타입 정의

`CrashReport`, 필드는 전부 **String**. `DiagnosticsService.upload` 가 쓰는 그대로다.

| 필드 | 내용 |
|---|---|
| `appId` | 앱 구분자 (허브를 여러 앱이 공유하므로 필요) |
| `kind` | `crash` / `hang` / `disk_write` |
| `detail` | 종료 사유, 멈춤 지속시간 등 종류별 한 줄 |
| `appVersion` | `CFBundleShortVersionString` |
| `osVersion` | `MXMetaData.osVersion` |
| `deviceType` | `MXMetaData.deviceType` |
| `stack` | 콜스택, **프레임 한 줄씩** 8000자에서 자름 (0번이 죽은 자리) |

5.0.6 에서 늘린 필드. 옛 레코드에는 없으므로 읽는 쪽은 **전부 없을 수 있다고** 보고 다룬다.

| 필드 | 타입 | 내용 |
|---|---|---|
| `occurredAt` | **Date/Time** | 크래시가 **난** 시각(`MXDiagnosticPayload.timeStampEnd`). 레코드 생성 시각은 배달된 때라 하루까지 늦다 |
| `buildNumber` | String | `MXMetaData.applicationBuildVersion`. **죽은 빌드를 정확히 가리키는 유일한 값** |
| `exceptionType` | String | 크래시만. 없으면 필드 자체를 안 보낸다 |
| `exceptionCode` | String | 〃 |
| `signal` | String | 〃 (예: `11` = SIGSEGV, `6` = SIGABRT) |

⚠️ `occurredAt` 만 **Date/Time** 이고 나머지는 전부 String 이다. 콘솔에서 타입을 String 으로
만들면 저장이 실패한다.

⚠️ `appVersion` 은 `Bundle.main` 에서 읽으므로 **지금 깔려 있는** 버전이다. 죽은 버전이
아닐 수 있다(MetricKit 배달이 늦는 사이에 업데이트가 깔리면 옛 크래시가 새 버전 이름표를
단다). 정확한 값은 `buildNumber` 쪽이고, 둘이 어긋나면 이름표를 의심한다.

`stack` 형식이 5.0.6 에서 바뀌었다. 읽는 쪽은 `{` 로 시작하는지로 옛 형식(JSON 덩어리)과
새 형식(프레임 목록)을 구분한다. 왜 바뀌었는지는 `docs/postmortem/CRASH_STACK_TRUNCATION.md`.

## 인덱스

`CrashReportReader.fetch` 가 `NSPredicate(value: true)` 전건 조회 + `creationDate` 내림차순
정렬을 쓴다. 그래서 둘 다 필요하다. 하나라도 빠지면 이번엔
`Field 'recordName' is not marked queryable` 같은 다른 에러로 바뀐다.

- `recordName` **Queryable**
- `createdTimestamp` **Queryable + Sortable**

`appId` 는 **인덱스를 만들지 않는다.** 통계·피드백과 같은 방침으로, 클라이언트에서 거른다
(`fetch` 안에서 필터). 배포해야 할 인덱스를 늘리지 않기 위함이다.

## Security Roles

⚠️ **`_world` 에 read 를 주지 않는다.** 콜스택은 익명이지만 아무나 읽을 이유가 없다.
피드백·통계와 같은 구성을 따른다.

- `_icloud`: **create 만**
- `_world`: read 제거
- admin 역할: read + 개발자 본인 `userRecordName` 등록
  (피드백 인박스 하단에서 `userRecordName` 복사 가능)

## 배포 절차 (1회)

https://icloud.developer.apple.com → `iCloud.com.Ysoup.FeedbackHub`

1. Development 환경에서 위 필드로 `CrashReport` 레코드 타입 생성
2. 위 인덱스 2개 추가
3. 위 Security Roles 설정
4. **Schema → Deploy Schema Changes to Production**

### 5.0.6 에서 늘린 필드 (추가 1회)

기존 타입에 위 표의 5개 필드를 더한다. `occurredAt` 만 **Date/Time**, 나머지는 String.
필드를 더한 뒤 다시 **Deploy Schema Changes to Production** 을 한 번 더 눌러야 한다.
누르지 않으면 Production 에서 저장이 조용히 실패하고, 진단이 **하나도 안 올라온다.**

인덱스는 늘리지 않는다. 새 필드로 서버 쪽 조회를 하지 않기 때문이다
(`occurredAt` 정렬도 클라이언트에서 한다).

배포 전까지 안정성 화면은 "진단 스키마가 아직 허브에 배포되지 않았어요" 안내를 보여준다
(에러가 아니라 정상 상태). 배포 후 첫 진단이 올라오기 전까지는 평소의 빈 화면 문구가 뜬다.

## 검증

배포했으면 조회가 통하는지 본다. 진단이 0건이어도 **에러 없이 빈 결과**가 나와야 한다.

```bash
xcrun cktool query-records \
  --team-id QGAQ3AY3R3 \
  --container-id iCloud.com.Ysoup.FeedbackHub \
  --environment production \
  --database-type public \
  --record-type CrashReport
```

`cktool` 은 관리 토큰이 필요하다. 계정 레벨 Tokens 페이지의 **Management Token** 이어야 하고,
컨테이너별 **API Token** 은 생김새(64자 hex)가 같지만 `cktool` 에서 거부된다. 헷갈리기 쉽다.

```bash
xcrun cktool save-token --type management   # 대화형 프롬프트에 붙여넣기
xcrun cktool get-teams                      # 토큰이 유효한지 먼저 확인
```

## 앱 쪽 동작

`CrashReportReader.isSchemaNotReady` 가 `unknownItem`(타입 없음)과
`invalidArguments`(인덱스 없음)를 스키마 미배포 상태로 묶어 처리한다.
서버 원문을 그대로 화면에 띄우면 사용자는 앱이 고장난 줄 아니, 한국어 안내로 바꾸고
원문은 `AppLog.warning(.diagnostics, ...)` 로만 남긴다.
