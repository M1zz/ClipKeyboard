# 앱 내 피드백, CloudKit Public Database

사용자가 앱 설정 → 피드백 보내기(또는 피드백 넛지 알림)에서 남긴 의견이
**CloudKit Public Database**에 `Feedback` 레코드로 저장된다. 메일 앱 없이도 동작하며,
CloudKit 제출이 실패하면 기존 이메일(leeo@kakao.com) 경로로 폴백한다.

## 접수된 피드백 확인 방법 ①: 앱 안에서 (마스터 모드, 권장)

1. 설정 → **앱 정보 → 버전 행을 7번 탭** → "개발자 모드가 켜졌어요"
2. 설정 → 지원 → **접수된 피드백 (개발자)** 진입 (`Screens/FeedbackInboxView.swift`)
3. 처음에는 권한 오류가 정상, 다른 사용자의 레코드를 읽으려면 아래 1회 설정 필요:
   - 인박스 화면 하단의 **내 사용자 ID**를 탭해 복사
   - CloudKit Dashboard → Schema → Security Roles → **새 역할 `admin` 생성**
   - `admin`에 Feedback 레코드 타입 **Read + Write** 권한 부여
     (Read = 목록 조회, Write = 완료 표시·삭제)
   - Dashboard → Data → Users에서 복사한 userRecordName 검색 → `admin` 역할에 추가
   - 스키마를 Production으로 배포
4. 이후 pull-to-refresh로 최신 피드백을 앱에서 바로 확인
5. **완료 표시**: 오른쪽으로 스와이프 (status="done" 필드 기록, 완료 배지 표시)
   **삭제**: 왼쪽으로 스와이프 → 확인 알림 → 서버에서 영구 삭제

## 새 피드백 푸시 알림 (개발자 기기)

- 인박스 상단 **"새 피드백 알림"** 토글 ON → 알림 권한 요청 후 CloudKit
  `CKQuerySubscription`(`feedback-new-v1`)이 Public DB에 등록된다.
- 이후 **어떤 사용자가 피드백을 제출하든** 이 iCloud 계정의 기기로 푸시가 온다
  ("새 피드백이 도착했어요 📬"). 구독은 서버에 저장돼 재설치해도 유지.
- 전제 조건: admin 역할 **read** 권한 (구독 매칭에 필요) + 알림 권한 허용.
- 앱 재실행 시 마스터 모드면 APNs 재등록을 자동 수행 (`ClipKeyboardApp`).
- 끄기: 같은 토글 OFF → 구독 삭제.

## 접수된 피드백 확인 방법 ②, CloudKit Dashboard

1. https://icloud.developer.apple.com 접속 → Apple Developer 계정 로그인
2. 컨테이너 **iCloud.com.Ysoup.TokenMemo** 선택
3. **Data** → Database: **Public Database**, Zone: `_defaultZone`, 환경 선택
   - TestFlight/App Store 사용자 피드백 → **Production**
   - Xcode 빌드로 보낸 테스트 피드백 → **Development**
4. Record Type **Feedback** 으로 Query 실행
   - 정렬: `createdTimestamp` (Queryable/Sortable 인덱스 필요, 아래 참고)

### 레코드 필드

| 필드 | 내용 |
|---|---|
| `type` | bug / feature / question / other |
| `message` | 사용자가 쓴 내용 |
| `deviceInfo` | 앱 버전 + 기기 + OS |
| `appVersion` | 마케팅 버전 |
| `locale` | 사용자 로케일 |
| `platform` | iOS / macCatalyst |

## 최초 1회 설정 (배포 전 필수)

1. **개발 환경에서 스키마 생성**: Xcode 빌드 앱에서 피드백을 한 번 보내면
   Development 환경에 `Feedback` 레코드 타입이 자동 생성된다 (just-in-time schema).
2. **인덱스 추가**: Dashboard → Schema → Record Types → Feedback →
   `createdTimestamp`에 **Queryable + Sortable** 인덱스 추가 (recordName에 Queryable도 권장).
3. **권한 잠그기**: Schema → Security Roles → Feedback →
   - `_world`: **Create만 허용**, Read 제거 (다른 사용자가 남의 피드백을 읽지 못하게)
   - `_icloud`(인증 사용자): Create만
   - `_creator`: Read/Write 허용해도 무방
4. **Production 배포**: Schema → **Deploy Schema Changes to Production**

## 제한 사항

- 사용자가 iCloud에 로그인되어 있어야 한다 (아니면 이메일 폴백).
- 익명 제출이라 답장 불가, 답장이 필요한 문의는 이메일 폴백/인스타 DM으로 유도.
- 코드: `ClipKeyboard/Service/FeedbackService.swift`, UI: `Screens/FeedbackView.swift`,
  넛지: `ClipKeyboardApp.maybeShowFeedbackNudge()` (10회째 실행 첫 노출, 이후 40회 간격).
