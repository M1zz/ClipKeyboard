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

## ⚠️ 원인은 확정하지 못했다

받은 스택이 **잎(leaf) 프레임 앞에서 잘려 있었다.** `callStackRootFrames` 는 바깥
(`start` → `main` → …)부터 안쪽으로 내려가는데, 남아 있는 여덟아홉 겹은 아직 UIKit
언저리라 어느 앱이든 똑같이 나온다. 범인을 부르는 자리는 잘린 뒤에 있었다.

심볼화도 막혔다.

- 리포트의 `binaryUUID` 7개를 로컬 아카이브와 DerivedData 전체에서 훑었으나 **일치 없음**
  (아카이브는 4.4.8(2026-08-18)이 마지막, 5.0.x 없음)
- iOS 26.6.1(23G82) 기기 심볼도 없어(로컬 최신 26.5.2) 시스템 프레임도 못 붙임

그래서 이 문서는 "범인을 잡았다"가 아니라 **"그 모양에 맞는 자리를 걷어냈다"** 는 기록이다.
다음에 같은 리포트가 오면 잘리지 않은 전체 JSON 이나 Organizer 의 심볼화 화면을 먼저 확보할 것.

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
생김새는 값 읽기, 하는 일은 프로세스 사이 통신. → `docs/LAUNCH_WATCHDOG_4_4_6.md`

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
