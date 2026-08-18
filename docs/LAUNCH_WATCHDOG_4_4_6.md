# 4.4.6 런치 워치독 크래시 (0x8BADF00D, scene-create)

기기: iPhone18,4 · iOS 26.6 (23G71) · 2026-08-17 06:03
빌드: 4.4.6 (1)

## 한 줄

첫 화면을 그리던 메인 스레드가 `CKContainer(identifier:)` 안에서 22초 동안 멈춰 있었고,
iOS 가 앱을 워치독으로 죽였다.

## 리포트에서 읽은 것

```
explanation: scene-create watchdog transgression: app<com.Ysoup.TokenMemo>:9454 is stuck (deadlock)
WatchdogEvent: scene-create
WatchdogCPUStatistics: (
  "Elapsed total CPU time (seconds): 22.460 (user 16.330, system 6.130), 73% CPU",
  "Elapsed application CPU time (seconds): 0.135, 0% CPU"
)
```

여기서 갈린다. 경과 22초 동안 **앱이 쓴 CPU 는 0.135초**다.
느린 코드가 런치를 잡아먹은 것이 아니라, 아무 일도 안 하고 무언가를 **기다리고** 있었다.
그래서 처음부터 찾을 것은 "무거운 초기화"가 아니라 "메인 스레드를 붙잡는 한 줄"이었다.

`scene-create` 는 씬이 붙는 순간부터 첫 프레임을 내보낼 때까지의 구간이다.

## 심볼화

리포트의 `binaryUUID` 중 `BC2C56AC-F931-34CD-8A20-32B609B84CEB` 가
로컬 아카이브(`Archives/2026-08-12/ClipKeyboard`, 4.4.6(1))의 앱 본체 dSYM 과 일치했다.

```sh
D="…/ClipKeyboard.app.dSYM/Contents/Resources/DWARF/ClipKeyboard"
atos -o "$D" -arch arm64 -l 0x100000000 0x100324838   # offsetIntoBinaryTextSegment + __TEXT vmaddr
```

| offset | 심볼 |
| --- | --- |
| 537764 | `closure #2 in closure #1 in closure #1 in ClipKeyboardApp.body.getter` (ClipKeyboardApp.swift:705) |
| 3294312 | `one-time initialization function for shared` (CloudKitBackupService.swift:119) |
| 3295288 | `CloudKitBackupService.init()` (CloudKitBackupService.swift:150) |

나머지 UUID 는 시스템 프레임이다. 프레임 순서까지 붙이면 이렇게 된다.

```
SwiftUI            body 최초 평가
  ClipKeyboardApp.swift:705      _ = CloudKitBackupService.shared
    libswiftCore   swift_once                      ← static let shared
      CloudKitBackupService.init()
        CloudKitBackupService.swift:150            CKContainer(identifier: "iCloud.com.Ysoup.TokenMemo")
          CloudKit → XPC → mach_msg 대기           ← 22초, 돌아오지 않음
```

## 원인

`CKContainer(identifier:)` 는 값 하나 만드는 생성자처럼 보이지만 cloudd 와 XPC 를 주고받는다.
그 데몬이 대답하지 않으면 부른 스레드는 오류도 없이 그 자리에 선다.

그 호출이 하필 세 겹으로 나쁜 자리에 있었다.

1. **`static let shared` 의 `swift_once` 안** - 누가 처음 만지든 그 스레드가 통과해야 한다.
   한 스레드가 갇히면 같은 싱글톤을 만지는 다른 스레드도 같이 갇힌다(리포트의 "deadlock").
2. **SwiftUI `body` 평가 중** - 즉 첫 프레임을 그리는 메인 스레드다.
3. **시뮬레이터에서는 안 도는 코드** - `#if targetEnvironment(simulator)` 로 통째로 건너뛴다.
   개발 중에 한 번도 안 밟히고, 남의 기기에서만 터진다.

`_ = CloudKitBackupService.shared` 를 런치로 옮긴 것 자체는 의도한 수정이었다
(백업 화면을 안 연 사용자는 자동 백업 타이머가 아예 안 돌던 문제). 자리가 틀렸을 뿐이다.

## 고친 것

### 1. 컨테이너를 만드는 자리를 하나로 (`CloudKitContainerGate.swift`)

`CloudKitContainer` 가 유일한 생성처다. 안쪽이 **액터**라, 액터의 몸통이 협력 스레드풀에서 도는
성질 덕에 `@MainActor` 코드가 불러도 생성이 메인 스레드에서 일어날 수 없다. 부른 쪽은
`await` 로 비켜 서 있을 뿐 스레드를 붙잡지 않는다. identifier 별 캐시도 여기서 따라온다.

```swift
let db = await CloudKitContainer.privateDatabase(identifier)
let db = await CloudKitContainer.publicDatabase(identifier)
```

### 2. `CloudKitBackupService.init()` 에서 CloudKit 을 걷어냈다

배선(`Backend`)을 저장 프로퍼티에서 `async` 접근자로 바꿨다. 컨테이너는 백업/복원처럼
실제로 필요한 순간에, 메인 스레드 밖에서 만들어진다. `init()` 에 남은 것은 UserDefaults
읽기와 알림 구독뿐이라 밀리초 안에 끝난다. 테스트 mock 주입 경로는 그대로다.

### 3. `MemoSyncEngine.startIfEnabled()` 도 같은 처리

`CKContainer` 와 `CKSyncEngine(_:)` 둘 다 XPC 를 탄다. 이 메서드는 런치 시퀀스와
**포그라운드 복귀(`scenePhase == .active`)** 양쪽에서 메인 액터로 불리므로, 같은 사고가
런치가 아니라 복귀 때 날 수 있었다. 배선을 `startTask` 안으로 옮겼고,
`syncNow()` 는 그 작업을 기다렸다가 엔진을 본다(안 그러면 콜드 런치 직후 첫 요청이
조용히 아무 일도 안 하고 끝난다).

### 4. 나머지 호출처 4곳

`RemoteFlagsService`(`@MainActor` 클래스라 특히 위험했다) · `DiagnosticsService` ·
`UsageReportingService` · `CrashReportsView` 전부 관문을 거친다.

### 5. `LaunchGuard` 에 `first-frame` 구간

`init()` 이 끝나고 SwiftUI 가 `body` 를 처음 평가하는 구간에는 표식이 없었다.
그래서 이번 사고가 다음 런치에 직전 단계인 `tips` 의 것으로 기록됐을 것이다.
두 번 반복되면 **죄 없는 TipKit 이 격리되고 진짜 원인은 계속 숨는다.**
`LaunchGuard.markFirstFrame()` 이 그 구간에 이름을 준다(essential 이라 격리 대상 아님).

### 6. 다시 들어오지 못하게

`scripts/check_main_thread_cloudkit.sh` 가 관문 밖의 `CKContainer(identifier:` 를 잡는다.
pre-commit 훅과 `scripts/predeploy.sh` 게이트에 둘 다 걸려 있다.

## 남겨 둔 것

`NSUbiquitousKeyValueStore.default` 도 데몬을 거치고, Pro 게이팅 경로
(`MemoSyncFlags.enabled` · `isProUser` · `mirrorSyncEntitlement`)가 메인 스레드에서 이를 읽는다.
읽기가 로컬 저장소에서 끝나므로 `CKContainer` 만큼의 위험은 아니라고 보고 이번에는 두었다.
런치·복귀 행이 또 보이면 여기부터 볼 것.

## 다음에 같은 리포트를 받으면

1. `WatchdogCPUStatistics` 의 **application CPU** 를 먼저 본다. 0에 가까우면 기다린 것이고,
   경과 시간에 근접하면 진짜로 느린 것이다. 찾을 대상이 완전히 다르다.
2. `binaryUUID` 를 로컬 아카이브 dSYM 과 대조한다(`dwarfdump --uuid`).
   맞는 것이 있으면 `atos -l 0x100000000` 에 `__TEXT vmaddr + offset` 을 넣어 심볼을 뽑는다.
   추측하기 전에 이걸 먼저 한다. 이번에도 이 한 번으로 끝났다.
3. MetricKit 트리는 **리프가 먼저** 나온다. 마지막 프레임이 호출자다.
