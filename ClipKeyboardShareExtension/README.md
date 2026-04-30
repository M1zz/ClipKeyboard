# ClipKeyboardShareExtension

iOS Share Sheet에서 텍스트/URL 받아 ClipKeyboard 메모로 빠르게 저장하는 익스텐션.

## Xcode에서 타겟 등록 (수동, ~2분)

이 폴더의 파일들은 모두 작성되어 있습니다. 다음 단계로 Xcode에 등록하세요:

1. Xcode에서 `ClipKeyboard.xcodeproj` 열기
2. **File → New → Target...**
3. **Share Extension** 선택 → Next
4. 다음 정보 입력:
   - Product Name: `ClipKeyboardShareExtension`
   - Team: `Ysoup` (메인 앱과 동일)
   - Organization Identifier: `com.Ysoup.TokenMemo`
   - Bundle Identifier: `com.Ysoup.TokenMemo.share`
   - Language: Swift
   - "Activate scheme" 체크 해제 (선택)
5. Finish 클릭. Xcode가 자동으로 새 폴더 + 보일러플레이트 생성.
6. **새로 생긴 보일러플레이트 파일 삭제**: `Project Navigator`에서
   - 새로 생긴 `ClipKeyboardShareExtension/ShareViewController.swift` (보일러플레이트) — Move to Trash
   - 새로 생긴 `MainInterface.storyboard` — Move to Trash
   - 새로 생긴 `Info.plist` — Move to Trash (이 repo의 것을 쓸 거임)
7. **이 repo의 파일들을 타겟에 추가**:
   - Project Navigator에서 `ClipKeyboardShareExtension` 그룹 우클릭 → "Add Files to..."
   - 다음 파일 선택:
     - `ShareViewController.swift`
     - `Info.plist`
     - `ClipKeyboardShareExtension.entitlements`
   - "Add to targets"에서 `ClipKeyboardShareExtension`만 체크 (메인 앱은 X)
8. **타겟 설정 조정** (`PROJECT → ClipKeyboardShareExtension → Signing & Capabilities`):
   - + Capability → **App Groups** 추가
   - `group.com.Ysoup.TokenMemo` 체크
   - Code Signing Entitlements: `ClipKeyboardShareExtension/ClipKeyboardShareExtension.entitlements` 지정
9. **Info.plist 경로 확인** (`Build Settings → Packaging → Info.plist File`):
   - `ClipKeyboardShareExtension/Info.plist`
10. **Storyboard 제거** (`Build Settings`):
    - `Main Storyboard File Base Name` 비우기 (있다면)
11. **Build Phases → Embed App Extensions** (메인 앱 타겟):
    - 자동으로 추가됐어야 함. 안 됐으면 + 버튼으로 ClipKeyboardShareExtension 추가.
12. Build & Run on device → 노트 앱에서 텍스트 선택 → Share → ClipKeyboard 시트 확인.

## 동작 방식

- Share Sheet에서 텍스트/URL 받음 (`text/plain`, `URL` UTI)
- 간단한 휴리스틱으로 카테고리 추론 (이메일/URL/IBAN/기본)
- SwiftUI 시트로 미리보기 + 타이틀 인라인 편집
- App Group container의 `memos.data`에 직접 append (메인 앱과 동일 파일 포맷)
- 메인 앱 다음 launch 때 자동으로 변경사항 반영 (`MemoStore.load`가 다시 읽음)
