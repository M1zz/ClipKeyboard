# 4.4.4 릴리즈 노트

앱 스토어 "이번 버전의 새로운 기능"에 그대로 붙여 넣을 수 있는 문안입니다.
(앱 안 변경 이력은 `ChangelogView.swift` 의 `4.4.4` 항목 — 문구가 서로 어긋나지 않게 함께 고칠 것)

---

## 한국어 (App Store)

앱을 열면 키보드가 올라온 모습이 그대로 보입니다.

• **첫 화면이 달라졌어요** — 다른 앱에서 키보드가 올라온 그 화면을 앱에서 그대로 보고, 눌러서 바로 써 볼 수 있어요.
• **목록도 그대로 있어요** — 설정 > 첫 화면에서 단축어 목록과 키보드 화면 중 고르고, 툴바 버튼으로 언제든 바로 오갈 수 있어요.
• **처음 쓰신다면** 단축어 만들기 → 키보드 켜기 → 눌러보기까지 끊기지 않고 이어집니다.
• **키마다 복사 버튼** — 키를 누르면 입력창에, 복사 버튼을 누르면 클립보드로 갑니다.
• **카테고리 탭과 좌우 넘기기**가 처음부터 보입니다.
• **붙여넣기 허용 팝업을 미뤘어요** — 설치하자마자 묻지 않고, 며칠 써 보신 뒤에 한 번 여쭤봅니다.

고친 것
• 키보드를 켰는데도 "아직 다른 앱에서는 못 써요" 안내가 남아 있던 문제
• 단축어 목록이 화면 중앙에서 시작하던 문제
• 빈 화면에서 배경이 두 색으로 갈리던 문제

---

## English (App Store)

Open the app and the keyboard is right there — the way it looks everywhere else.

• **A new first screen** — see the keyboard exactly as it appears in other apps, and tap to try it right away.
• **Your list is still here** — pick your first screen in Settings › First screen, and switch between the two anytime from the toolbar.
• **New here?** Creating your first snippet now leads straight into turning the keyboard on and trying it out.
• **A copy button on every key** — tap the key to type it, tap copy to put it on the clipboard.
• **Category tabs and swipe paging** are there from the start.
• **The paste permission prompt waits** — it no longer greets you right after install; we ask once after you've used the app for a few days.

Fixes
• The "not available in other apps yet" notice lingering after you'd already enabled the keyboard
• The snippet list starting halfway down the screen
• The two-tone background on empty screens

---

## 심사·배포 메모 (내부)

- **버전**: `Version.xcconfig` 의 `MARKETING_VERSION = 4.4.4`. 빌드 번호는 업로드 전 올릴 것.
- **새 권한 없음** — 추가된 권한·엔타이틀먼트 없음.
- **붙여넣기 프롬프트 시점 변경**: 클립보드 자동 읽기를 설치 후 3일 뒤로 미룸
  (`PastePermissionGuidance.warmUpDays`). 사용자가 직접 누른 붙여넣기는 그대로 동작.
  심사 중 신규 설치에서는 클립보드 탭이 비어 있는 것이 **정상**이며, 그 사실을 화면 문구로 안내한다.
- **키보드 감지**: `AppleKeyboards`(표준 UserDefaults) + App Group 표식 두 신호를 함께 본다.
- **스킨(키캡·생활 레이어)은 이번 버전에서 노출하지 않음** — `KeyboardSkin.isEnabled` /
  `LivingSkin.isEnabled` 가 false. 코드는 남아 있어 값 하나로 되살릴 수 있다.
- **앱 자산 약 5.2MB 감소** — 광부 영상·미사용 튜토리얼 이미지 제거.

## macOS 앱(별도 저장소) 호환성

검토 결과 **깨지는 지점 없음**. 근거:

| 항목 | 결과 |
|---|---|
| `Memo` 모델·`MemoStore` 저장 포맷 | 변경 없음 |
| `MemoSyncCore` / `StorageFile` / `AppGroup` (공유 파일) | 변경 없음 (양쪽 동일) |
| CloudKit 백업·동기화 레코드 | 변경 없음 |
| `DefaultsKey.swift` (공유 파일) | iOS 쪽에만 키 3개 추가(`snippetsTabStyle`, `keyboardStageOffered`, `keyboardSetupTutorialDone`) — 셋 다 **표준 UserDefaults, iOS 화면 상태 전용**이라 맥이 읽지 않는다. 맥 사본은 원래도 iOS 전용 키를 안 갖는 부분집합이다 |
| `category.feature.enabled.v1` (App Group) | 맥도 읽는 키. iOS가 이제 값이 없을 때 `true` 를 적지만, **App Group 컨테이너는 기기·앱마다 별개**라 맥 쪽 값에는 영향이 없다. 맥은 자기 `MacCategoryStore` 판단을 그대로 쓴다 |
| 이번에 지운 파일(MinerScene·영상·이미지) | 맥 저장소에 없음 |

⚠️ 남는 일: 맥에도 카테고리 기본 활성화를 맞출지는 **맥 저장소에서 따로 정할 문제**다.
지금은 맥이 예전 규칙(기본 꺼짐)을 쓰므로, 같은 사람이 두 기기를 쓰면 카테고리 탭 노출이
서로 다를 수 있다. 맞추려면 `MacCategoryStore` 의 기본값을 같은 방식으로 바꿔야 한다.
