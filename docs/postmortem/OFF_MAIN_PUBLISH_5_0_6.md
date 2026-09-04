# 5.0.6 배경 발행: 경고가 가리킨 줄은 범인이 아니었다

```
MemoStore.swift:123  Publishing changes from background threads is not allowed;
                     make sure to publish values from the main thread
                     (via operators like receive(on:)) on model updates.
```

이 경고를 세 번 손댔다. 앞의 두 번은 옳은 수정이었지만 **원인이 아니었다.**

## 무엇을 잘못 읽었나

`MemoStore.swift:123` 은 당시 `save()` 안의 이 한 줄이었다.

```swift
NotificationCenter.default.post(name: .memoDataChanged, object: nil)
```

여기서 `@Published` 를 바꾸는 코드는 **한 줄도 없다.** `MemoStore` 의 네 `@Published` 는
전부 `DispatchQueue.main.async` 안에서만 대입된다. 그런데도 경고가 이 줄에 붙었다.

경고가 붙여 주는 파일·행은 **발행한 자리가 아니라 발행을 촉발한 자리**다.
즉 이 줄은 스택에 남아 있던 가장 가까운 우리 코드일 뿐이고, 값을 실제로 바꾼 것은
이 알림을 받은 화면들이었다.

## 실제로 일어난 일

1. `save()` 는 배경에서도 불린다. 동기화(`MemoSyncEngine` 의 `CKSyncEngine` 대리자),
   iCloud 복원, 템플릿 화면의 배경 로드가 그렇다.
2. `NotificationCenter` 는 **쏜 스레드에서 그대로** 받는 쪽을 부른다.
3. SwiftUI 의 `onReceive` 는 안에 `receive(on:)` 이 없다. 그래서 클로저가
   **그 배경 스레드에서** 돈다.
4. `.memoDataChanged` 를 받는 화면이 일곱이고, 전부 곧바로 다시 읽는다
   (`loadMemos()` → `viewModel.memos = …`). 그 대입이 배경에서 일어난다.

```
배경 스레드
  └ MemoStore.save()
      └ NotificationCenter.post(.memoDataChanged)   ← 경고가 가리킨 줄
          └ ClipKeyboardList.onReceive { … }        ← 여기가 배경에서 돈다
              └ viewModel.memos = …                 ← 실제 발행
```

`@MainActor` 를 붙여 둔 뷰모델이라 컴파일러는 아무 말도 하지 않는다.
`onReceive` 의 클로저는 뷰 몸(`body`)이 메인이라 **메인으로 추론**되지만,
런타임에 SwiftUI 가 부르는 스레드는 알림을 쏜 스레드다. 추론이 거짓말이 되는 자리다.

## 왜 두 번 헛짚었나

| 시도 | 무엇을 했나 | 왜 안 사라졌나 |
| --- | --- | --- |
| 1 | `postDataChanged()` 가 배경이면 메인으로 넘기게 | 옳지만 `.memoDataChanged` 하나만 막았다 |
| 2 | 메인이어도 한 박자 미루게(재진입 제거) | 같은 알림 하나만 |
| 3 | **쏘는 문을 하나로** + 배경에서 `@State` 를 고치던 자리들 | - |

같은 구멍이 알림마다 따로 뚫려 있었다. `.memoUsed` · `.reviewTriggerClipSaved` ·
`.quickNotesChanged` · `.draftsChanged` · `.comboItemExecuted` 는 그대로 쏜 스레드에서
받는 쪽을 불렀고, 그중 `.quickNotesChanged` 는 `AddQuickNoteIntent`(백그라운드 인텐트)
에서, `.memoUsed` 는 콤보 실행에서 나온다.

## 고친 것

**하나.** 알림을 쏘는 문을 하나로 좁혔다.

```swift
NotificationCenter.postOnMain(name: .someName)   // ClipKeyboard/App/AppNotification.swift
```

이미 메인이면 그 자리에서 쏜다(눌러서 시트가 뜨는 흐름의 순서를 지킨다).
배경일 때만 메인으로 넘긴다. 앱·키보드 익스텐션의 모든 발행이 이 문을 지난다.

예외는 둘이고 둘 다 줄에 `notify-ok` 를 붙여 이유를 적어 두었다.

- `MemoStore.postDataChanged` - 메인이어도 미룬다(저장 중 저장이 겹치는 재진입).
- `AppLanguage.select` - 관문 파일이 없는 작은 타겟(공유·액션 익스텐션·위젯)과
  함께 쓰는 파일이라 손으로 메인을 본다.

**둘.** `View` 의 도우미 함수에서 `await` 뒤에 `@State` 를 고치던 자리에 `@MainActor` 를 붙였다.
`View` 는 몸(`body`)만 메인이고 `private func … async` 는 격리가 없다. `await` 뒤는
아무 스레드에서나 깨어난다.

```
CrashReportsView.load        UsageStatsView.load       ShareVideoSheet.make
DiscountOfferView.buy        AIComponents.loadAIPredictionIfNeeded
TranslationSheet.translate
```

**셋.** 진단 발판(`OffMainPublishDetector`, DEBUG 전용)이 보던 싱글톤을 다섯에서 아홉으로
늘렸다. 다섯만 걸어 두면 못 걸린 하나가 범인일 때 또 헛짚는다.

## 다시 새지 않게

```bash
sh scripts/check_notification_main.sh
```

`.git/hooks/pre-commit` · `scripts/predeploy.sh` · `ci_scripts/ci_post_clone.sh` 에 물려 있다.
새 머신에서는 `sh scripts/install-hooks.sh` 를 한 번 돌린다.

## 다음에 이 경고를 만나면

- **행 번호를 믿지 말 것.** 그건 촉발한 자리다. 스택을 봐야 한다.
- 배경에서 도는 것부터 의심한다: `CKSyncEngine` 대리자, CloudKit 완료, App Intent 의
  `perform()`(`@MainActor` 없으면 배경), `Task {}`(격리 없는 문맥에서 만들면 배경),
  `.task {}`(`@Sendable` 이라 액터를 물려받지 않는다).
- `@MainActor` 가 붙어 있다고 안심하지 않는다. 클로저 추론은 컴파일 시간의 약속일 뿐,
  누가 어느 스레드에서 부르는지는 막지 못한다.
