# 키보드가 열리지 않던 것: 복사 기록에 남은 옛 그림

> 키보드가 열리지 않습니다.

사용자가 보낸 그대로다. 어떤 앱에서, 언제부터인지는 없었다. 원인은 코드에서 좁혔다.

## 원인: 키보드가 뜰 때마다 쓰지도 않는 그림을 통째로 올렸다

세 가지가 겹쳤다.

| 언제 | 무엇 |
| --- | --- |
| 8월 31일 이전 | 앱이 복사한 **그림을 base64 글자로 복사 기록 한 줄 안에** 담았다(`createHistoryFromImage`, 1024px JPEG, 한 장에 수백 KB) |
| 8월 31일 | 클립보드를 엿보던 길을 걷어 그림을 더 담지 않게 됐다. **이미 담긴 그림은 파일에 남았다** |
| 5.1.8 | 키보드 맨 앞에 '최근' 탭. 키보드가 **뜰 때마다** `smart.clipboard.history.data` 를 통째로 읽는다. 보관 기간도 7일에서 30일로 |

오래된 항목은 새 항목을 더할 때만 지워진다. "남겨 두기" 한 항목은 영영 남는다. 그래서 복사 기록을 한동안 안 쓴 사람, 그림을 남겨 둔 사람의 파일에는 그림이 그대로 있었다.

그 그림을 보여 주거나 붙여 넣는 화면은 **어디에도 없었다.** 목록에는 "이미지 (1024x768)" 라는 글자만 보였다.

## 얼마나 무거웠나

그림 50장(20MB) 이 남은 파일을 시뮬레이터에서 읽어 `phys_footprint` 를 쟀다.

| 읽는 방식 | 늘어난 메모리 |
| --- | --- |
| 예전(`Data(contentsOf:)` + `imageData` 디코드) | **+40MB** |
| 지금(매핑 + `imageData` 를 묻지 않음) | +0MB |

키보드 익스텐션의 한도는 수십 MB 다. 넘으면 iOS 가 **조용히 죽인다**(예외도 경고도 없다).
사용자에게는 "키보드가 열리지 않음" 하나로만 보인다. `KEYBOARD_IMAGE_MEMORY.md` 와 같은 꼴이다.

## 고친 것

| 자리 | 지금 |
| --- | --- |
| `SmartClipboardHistory.init(from:)` | `imageData` 열쇠를 **묻지 않는다.** 디코더가 그 글자를 만들지 않는다. 나머지 칸은 없어도 읽는다(`decodeIfPresent`) |
| `MemoStore.loadSmartClipboardHistory` | 파일을 **매핑**해서 읽고(`.mappedIfSafe`), 그림 줄(`.image`)은 버린다 |
| `MemoStore.compactSmartClipboardHistoryIfNeeded` | 앱이 켜질 때 메인 밖에서, 파일에 옛 그림 칸이 있을 때만 한 번 다시 써서 줄인다 |
| `ClipboardClassificationService` | 부르는 곳 없던 `createHistoryFromImage` 를 걷었다. 그림을 히스토리 JSON 에 넣는 길이 다시 생기지 않게 |

## 다시 그림을 담고 싶어지면

그림은 파일로 따로 두고 줄에는 **이름만** 적는다(단축어 그림이 `Images/` 에 있는 것처럼).
키보드가 뜰 때 읽는 파일에 큰 덩어리를 넣지 않는다.

## 시험

`SmartClipboardLifecycleTests`
- `testLegacyImages_LoadWithoutImagePayload`: 그림 20장이 남은 파일에서 글만 남고 '최근' 탭이 선다
- `testCompaction_RemovesLegacyImageBytesFromDisk`: 줄인 뒤 파일이 1/100 아래로, 두 번째는 쓰지 않는다
- `testDecode_MissingFieldsKeepsHistory`: 칸이 빠진 줄 때문에 기록 전체가 사라지지 않는다

## 남은 의문

피드백에는 버전 · 기기가 없었다. 같은 증상의 다른 원인(다른 메모리 사용, 뜰 때 멈춤)을 지운 것은 아니다.
키보드는 연달아 끝까지 못 뜨면 최소 화면으로 열고 그 횟수를 허브로 보낸다. 다음 판이 나간 뒤 그 수가 줄었는지 본다.
