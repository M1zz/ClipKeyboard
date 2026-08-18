# 4.4.8 릴리즈 노트

앱 스토어 "이번 버전의 새로운 기능"에 그대로 붙여 넣을 수 있는 문안입니다.
(앱 안 변경 이력은 `ChangelogView.swift` 의 `4.4.8` 항목)

> **이 문서는 4.4.8 에서 바뀐 것만 담습니다.** 4.4.7 문안을 승계하지 않습니다.
>
> ⚠️ 그래서 알아 둘 것: 4.4.4 · 4.4.5 · 4.4.6 · 4.4.7 은 App Store 에 나가지 않았고,
> 사용자는 4.4.3 에서 곧장 4.4.8 로 넘어옵니다. 이 문안만 올리면 그 네 버전에서 만든 것
> (첫 화면 키보드 · 단축어 마트 · 이미지 단축어 · 사진에서 글자 읽기 · 공유 익스텐션 ·
> 제어센터 복사 · 설정 정리 등)은 사용자에게 **한 번도 소개되지 않은 채** 들어갑니다.
> 누적 문안이 필요해지면 `docs/RELEASE_NOTES_4.4.7.md` 에 그대로 있습니다.

---

## 한국어 (App Store)

이번 버전은 앱이 열리는 일과 기기 사이를 오가는 일을 바로잡았습니다.

### 고친 것

• **앱을 열다가 멈추던 문제.** iCloud 를 준비하는 일이 첫 화면을 그리는 일과 같은 줄에 서 있어서, iCloud 응답이 늦는 기기에서는 앱이 열리지 못하고 그대로 종료됐습니다. 이제 그 준비는 화면과 따로 진행돼 화면이 먼저 뜹니다.
• **시작하다 문제가 생겨도 다음 실행은 열립니다.** 걸렸던 부분만 쉬고 화면부터 띄웁니다. 같은 자리에서 두 번 걸리면 그 부분은 이번 버전 동안 아예 시작하지 않아요. 데이터를 지키는 일은 예외로 계속 돌아갑니다.
• **기기 간 동기화에서 처음 올린 뒤의 수정과 삭제가 반영되지 않던 문제.** 아이폰에서 지운 단축어가 맥에서 안 사라지고, 고친 내용도 반대편에 가지 않았습니다. 눈에는 "추가만 되는 동기화"로 보였어요.

---

## English (App Store)

This release fixes how the app opens, and how your devices keep up with each other.

### Fixes

• **The app freezing while it opened.** Getting iCloud ready sat on the same thread as drawing the first screen, so on devices where iCloud was slow to answer, the app never opened and was shut down. That preparation now runs apart from the screen, and the screen comes up first.
• **A failed startup no longer blocks the next one.** Whatever got stuck sits out, and your screen comes up first. If the same step gets stuck twice, it stays off for this version. Anything that protects your data keeps running regardless.
• **Sync between devices dropping every edit and deletion after the first upload.** A snippet deleted on iPhone stayed on the Mac, and edits never crossed over. It looked like sync that only ever added things.

---

## 심사·배포 메모 (내부)

- 버전: `Version.xcconfig` 의 `MARKETING_VERSION = 4.4.8`. 빌드 번호(`CURRENT_PROJECT_VERSION`)는 1 그대로다.
  마케팅 버전이 바뀌었으니 iOS 는 1이어도 업로드된다. 같은 4.4.8 로 두 번째 빌드를 올릴 때만 올릴 것.
- 새 권한 없음. 추가된 권한·엔타이틀먼트 없음.
- 4.4.8 에서 바뀐 코드는 런치 경로와 동기화 엔진뿐이다. 새 기능은 없다.

### ⚠️ 아직 안 나간 버전들의 배포 조건이 그대로 남아 있다

문안은 4.4.8 것만 쓰지만, **배포 전 확인 항목은 4.4.4~4.4.7 것이 전부 유효하다.**
그 버전들이 나가지 않았으므로 이번 빌드가 그 코드를 처음 들고 나간다.
아래 셋을 빠뜨리면 이번에도 사고가 난다. 전문은 `docs/RELEASE_NOTES_4.4.7.md`.

1. **새 상품 두 개 등록** (`com.Ysoup.TokenMemo.pro.halfoff` $4.99 · `com.Ysoup.TokenMemo.slots5` $1.99).
   둘 다 비소모성, 가족 공유는 정가 상품과 같은 값으로. 칸 추가는 Pro 권한이 아니다
   (`testSlotPackNeverGrantsPro` 가 그 선을 지킨다).
2. **CloudKit 스키마를 앱보다 먼저 Production 에 올린다.** `UsageEvent.occurredAt` 이 없으면
   통계 이벤트 전송이 통째로 실패한다. 백업·동기화 필드(`categoriesAsset`, `deletedAt`)도 같이 확인.
3. **Xcode Cloud 는 아직 옛 이름을 부른다.** 저장소의 심볼릭 링크·스킴 복사본이 받아 주고 있다.
   임시 장치이므로 지우지 말 것.

### ⚠️ 실기기 콜드 런치 확인 없이 올리지 말 것

이번에 고친 경로는 시뮬레이터에서 `#if targetEnvironment(simulator)` 로 통째로 건너뛴다.
테스트 731개가 초록이어도 이 수정이 동작한다는 증거가 되지 않는다.
아이폰에서 콜드 런치 → 백업 화면 → 동기화 토글까지 실제로 밟을 것.

### 이번에 고친 것 중 가장 큰 것

4.4.6 이 실기기에서 런치 중에 죽었다(`0x8BADF00D`, `scene-create` 워치독).
경과 22초 동안 앱이 쓴 CPU 는 0.135초. 느린 게 아니라 기다리다 죽은 것이다.

리포트의 `binaryUUID` 가 로컬 아카이브 dSYM 과 맞아 심볼화했더니 한 줄로 나왔다.
SwiftUI 가 `body` 를 처음 평가하다 `CloudKitBackupService.shared` 를 건드렸고,
그 `swift_once` 안의 `init()` 이 `CKContainer(identifier:)` 를 불렀다.
이 생성자는 cloudd 와 XPC 를 주고받는데, 그 데몬이 대답하지 않으면 부른 스레드가 그대로 선다.
그 스레드가 첫 프레임을 그리는 메인 스레드였다.

`CloudKitContainer` 관문(액터)을 만들어 컨테이너를 메인 스레드에서 만들 수 없게 했고,
`CloudKitBackupService.init()` · `MemoSyncEngine.startIfEnabled()` 를 비롯한 호출처 여섯 곳을
전부 그리로 돌렸다. `scripts/check_main_thread_cloudkit.sh` 가 pre-commit 과 배포 게이트에서
관문 밖 생성을 막는다. `LaunchGuard` 에는 `first-frame` 구간을 추가했다.
그게 없으면 첫 화면에서 죽은 사고가 직전 단계(`tips`) 것으로 기록돼 엉뚱한 단계가 격리된다.

전체 기록: `docs/LAUNCH_WATCHDOG_4_4_6.md`
