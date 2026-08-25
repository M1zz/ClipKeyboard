# 5.0.1 멈춤: 클립보드를 메인에서 읽고 있었다

2026-08-23 18:58 · iPhone16,2 · iOS 26.6.1 (23G82) · 5.0.1 · **1.2785초 멈춤(hang)**

## 리포트가 말한 것

```
threadAttributed: true        ← 메인 스레드가 붙잡힌 당사자
sampleCount: 127 → 127 → …    ← 붙여넣은 구간 내내 한 갈래
1.2784869160004746s           ← 127 샘플 ≒ 10ms 간격
```

샘플이 한 갈래로만 내려간다는 것은 여러 일이 조금씩 느린 게 아니라
**한 호출이 그 자리에서 기다리고 있었다**는 뜻이다.

## 심볼화: 2026-08-25 에 다시 붙였다

처음 이 문서를 쓸 때는 **"UUID 일치 없음, 원인 미확정"** 으로 닫았다. 그건 틀린 결론이었다.
아카이브를 `4.4.8 이 마지막` 으로 본 것이 잘못이고, 실제로는 **멈추기 21분 전에 만든
5.0.1 아카이브가 그대로 있었다.**

```
~/Library/Developer/Xcode/Archives/2026-08-23/ClipKeyboard 8-23-26, 6.37 PM.xcarchive
  버전 5.0.1 (1)
  ClipKeyboard.app.dSYM : FAE8F200-B00C-33BD-BCB1-DCB12C52F7B6   ← 리포트의 두 번째 프레임
```

> 다음에 같은 일이 생기면 아카이브 폴더를 **날짜별로 전부** 훑을 것.
> `find ~/Library/Developer/Xcode/Archives -name "*.xcarchive"` 한 줄이면 된다.

시스템 프레임은 26.6.1(23G82) 심볼이 없어 정확히는 못 붙였지만, 같은 기기의
**26.6(23G71) 심볼**로 자리를 맞춰 봤더니 여섯 중 다섯이 예상한 함수로 떨어졌다.
그 정도면 스택의 모양은 확정이다.

| # | 바이너리 | 심볼 |
| --- | --- | --- |
| 1 | dyld | `start` |
| 2 | **ClipKeyboard 5.0.1** | `main` (앱 dSYM 으로 확정) |
| 3~5 | SwiftUI | (공유 캐시에 이름 없음) |
| 6 | UIKitCore | `UIApplicationMain` |
| 7 | UIKitCore | `-[UIApplication _run]` |
| 8 | GraphicsServices | `GSEventRunModal` |
| 9 | CoreFoundation | `_CFRunLoopRunSpecificWithOptions` |
| 10 | CoreFoundation | `__CFRunLoopRun` |
| 11 | CoreFoundation | `__CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__` |
| 12 | libdispatch | `_dispatch_main_queue_callback_4CF` |
| 13 | libdispatch | `_dispatch_main_queue_drain` ← 121 샘플, 여기서 잘림 |

**멈춘 곳은 메인 큐에 실린 일 안이다.** 터치 처리도, 레이아웃도, CA 커밋도 아니다.
`DispatchQueue.main.async` · `queue: .main` 알림 · MainActor 작업, 그리고 **SwiftUI 의
갱신 패스**가 여기로 드레인된다. `.onAppear` 클로저가 이 자리에 실린다.

## 그래서 아래 결론은 맞았다

5.0.1 의 `ClipKeyboardList.onAppear` → `viewModel.onAppear()` → `checkFreshClipboard()` →
`UIPasteboard.general.string`. **`.onAppear` 는 메인 큐에서 드레인되는 자리**라 스택 모양과
정확히 맞는다. 아래 고친 내용(`PasteboardReader`)은 2026-08-24 11:38 에 들어갔으니
**멈춘 그 빌드에는 없었다.**

## 걷어낸 자리

메인에서 한 호출이 초 단위로 기다릴 수 있는 자리를 찾았더니, **자동으로 도는 클립보드 읽기**
세 곳이 나왔다.

| 자리 | 언제 도나 | 무엇이 걸리나 |
| --- | --- | --- |
| `ClipKeyboardListViewModel.checkFreshClipboard()` | 목록이 뜰 때 + **앱이 앞으로 올 때마다** | `UIPasteboard.general.string` |
| `ClipboardList.checkAndAddCurrentClipboard()` | 클립보드 화면이 뜰 때 | 같은 읽기 + 이어지는 파일 읽기 |
| `MemoAddViewModel.checkClipboardAndSuggest()` | 새 단축어 화면이 뜰 때 | `.image` 먼저 → 리사이즈 → JPEG → base64, **전부 메인에서** |

`UIPasteboard.general.string` 은 속성 하나 읽는 것처럼 생겼지만 pasteboardd 와 주고받는
일이고, **유니버설 클립보드가 켜져 있으면 옆 기기에서 내용을 끌어오기까지 기다린다.**
맥에서 뭔가 복사한 직후 앱을 앞으로 부르는 것은 흔한 동작이고, 그때 이 한 줄이 메인을 잡는다.

4.4.6 의 `CKContainer(identifier:)` 와 같은 종류의 함정이다.
생김새는 값 읽기, 하는 일은 프로세스 사이 통신. → `docs/postmortem/LAUNCH_WATCHDOG_4_4_6.md`

덤으로 하나 더 나왔다: 그림을 줄일 때 `UIGraphicsBeginImageContextWithOptions(_:_:0.0)`
라 **화면 배율(3x)이 붙어 있었다.** 1024로 줄인다면서 3072px 짜리를 만들어 base64 로
안고 있었던 셈이다.

## 고친 것

### 1. 읽는 자리를 하나로 (`ClipKeyboard/Service/PasteboardReader.swift`)

```swift
PasteboardReader.string { text in … }        // 글자만
PasteboardReader.content { content in … }    // 글자와 그림
PasteboardReader.content(transform: …) { … } // 뒷일까지 백그라운드에서 끝내고 결과만 메인으로
```

- 직렬 큐 하나에서 읽는다. 앱을 앞뒤로 여러 번 오가도 느린 클립보드를 여러 번 기다리지 않는다
- `has…` 로 **있는지부터 묻는다.** 없는 줄 모르고 읽으면 붙여넣기 허용 팝업이 이유 없이 뜬다
- 완료는 **메인에서** 부른다. 받은 쪽이 그대로 `@Published` 를 만질 수 있다
- 무거운 뒷일은 `transform` 으로 백그라운드에 함께 둔다.
  읽기만 옮기고 인코딩을 메인에서 하면 **멈추는 자리만 옮긴 셈**이다

### 2. 그림 줄이기를 `UIGraphicsImageRenderer` 로, 배율은 1

백그라운드에서도 안전하고(예전 UIGraphics 컨텍스트와 다르다), 1024로 줄이면 실제로 1024가 된다.

### 3. 검사 (`scripts/check_main_thread_pasteboard.sh`)

자동으로 읽는 자리는 통로 하나뿐이라는 규칙을 pre-commit 훅과 `predeploy.sh` 에서 강제한다.
사용자가 붙여넣기를 직접 누른 자리는 기다림이 곧 대답이라 예외지만, **그 줄에 이유를 적어야** 한다.

```swift
// pasteboard-ok: 입력창의 붙여넣기 버튼을 눌러 부른 자리다
let image = UIPasteboard.general.image
```

파일 단위로 봐주지 않는다. 한 파일 안에 사용자가 시킨 읽기와 저절로 도는 읽기가 같이 살기 때문이다.

### 4. 시험 (`ClipKeyboardTests/PasteboardReaderTests.swift`)

값을 잘 읽는지가 아니라 **어디서 기다리는지**를 지킨다: 부른 자리를 붙잡지 않는가 ·
답이 메인으로 오는가 · 뒷일이 백그라운드에서 도는가.

## 다음에 같은 것이 오면

1. **Organizer > Hangs** 의 심볼화된 화면을 먼저 본다(TestFlight/App Store 경유면 이게 제일 빠르다)
2. 아니면 잘리지 않은 JSON 전체 + 그 버전의 dSYM. `binaryUUID` 를 로컬 아카이브와 대조한다
   (`dwarfdump --uuid`), `atos -o "$DWARF" -arch arm64 -l 0x100000000 <offset+vmaddr>`
3. 이 앱은 **아카이브를 남겨야 한다.** 5.0.1 은 로컬에 없어서 확정을 못 했다
