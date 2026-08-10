# ClipKeyboardShareExtension

iOS Share Sheet에서 텍스트/URL/이미지 받아 ClipKeyboard 메모로 빠르게 저장하는 익스텐션.

> ✅ **타겟 등록 완료 (v4.3.4)**, `scripts/add_share_extension.rb`로 빌드 타겟에 등록됨
> (번들 ID `com.Ysoup.TokenMemo.share`, App Group `group.com.Ysoup.TokenMemo`, 메인 앱에 임베드).
> 아래 수동 등록 안내는 참고용 히스토리입니다.

## (참고/히스토리) Xcode에서 타겟 등록 (수동, ~2분)

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
   - 새로 생긴 `ClipKeyboardShareExtension/ShareViewController.swift` (보일러플레이트), Move to Trash
   - 새로 생긴 `MainInterface.storyboard`, Move to Trash
   - 새로 생긴 `Info.plist`, Move to Trash (이 repo의 것을 쓸 거임)
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

- Share Sheet에서 이미지(`public.image`), 텍스트, URL 받음
- 이미지: App Group `Images/` 폴더에 JPEG 저장 (최대 1024px, 품질 0.7), contentType=`이미지`
- 텍스트/URL: 간단한 휴리스틱으로 카테고리 추론 (이메일/URL/IBAN/기본), contentType=`텍스트`
- SwiftUI 시트로 미리보기(이미지는 썸네일) + 타이틀 인라인 편집
- App Group container의 `memos.data`에 직접 append (메인 앱과 동일 파일 포맷)
- 메인 앱 다음 launch 때 자동으로 변경사항 반영 (`MemoStore.load`가 다시 읽음)

## 자매 타겟: ClipKeyboardActionExtension (v4.4.5)

공유 시트는 자리가 **둘**이다. 둘 다 있어야 사용자가 자기가 보는 자리에서 찾는다.

| 자리 | 타겟 | NSExtensionPointIdentifier | 동작 |
|---|---|---|---|
| 윗줄(앱 아이콘 가로 스크롤) | `ClipKeyboardShareExtension` | `com.apple.share-services` | 시트를 띄워 제목 수정 + 단축어/보관함 선택 |
| 아래 목록(복사·파일에 저장 아래) | `ClipKeyboardActionExtension` | `com.apple.ui-services` | **화면 없이** 한 번에 단축어로 저장 |

- 등록 스크립트: `scripts/add_action_extension.rb`
- 저장 로직은 **`Shared/QuickShortcutSave.swift` 한 곳**에만 있다. 두 타겟이 같은 파일을 컴파일한다.
  스키마(특히 `lastEdited` 가 2001 기준 초라는 점)를 두 벌로 두면 한쪽만 고쳐진다.
- 앱이 읽을 수 있는지는 `ClipKeyboardTests/ShareExtensionMemoWriteTests` 가 지킨다.
- 목록에 적히는 이름은 `ClipKeyboardActionExtension/{ko,en}.lproj/InfoPlist.strings` 의
  `CFBundleDisplayName` 이다("단축어로 저장" / "Save as Shortcut").
  ⚠️ 윗줄은 앱 이름으로 나오므로 **일부러 다른 이름**을 쓴다. 같은 시트에 같은 이름이
  두 번 뜨면 무엇이 다른지 알 수 없다.
