# 4.4.4 릴리즈 노트

앱 스토어 "이번 버전의 새로운 기능"에 그대로 붙여 넣을 수 있는 문안입니다.
(앱 안 변경 이력은 `ChangelogView.swift` 의 `4.4.4` 항목, 문구가 서로 어긋나지 않게 함께 고칠 것)

---

## 한국어 (App Store)

앱을 열면 키보드가 올라온 모습이 그대로 보입니다. 처음 쓰시는 분은 단축어 하나를 직접 만들고, 눌러서 써 보는 데까지 안내를 따라가면 됩니다.

**첫 화면**
• **키보드가 그대로 보여요**: 다른 앱에서 키보드가 올라온 그 모습을 앱에서 보고, 눌러서 바로 써 볼 수 있어요.
• **짧게 누르면 입력, 길게 누르면 복사**: 앱 안에서는 키를 짧게 누르면 입력창에 들어가고, 길게 누르면 클립보드로 갑니다.
• **목록도 그대로 있어요**: 설정 > 첫 화면에서 단축어 목록과 키보드 화면 중 고르고, 툴바 버튼으로 언제든 오갈 수 있어요.
• **카테고리 탭과 좌우 넘기기**가 처음부터 보입니다.

**처음 쓰신다면**
• **직접 하나 만들어 봐요**: "지인에게 내 주소 알려주기"처럼 상황을 고르면, 채울 칸은 하나뿐이에요.
• **만들고 끝나지 않아요**, 만든 단축어를 실제로 눌러 봐야 다음으로 넘어갑니다. 눌렀을 때 글이 들어가는 장면이 이 앱의 전부니까요.
• **템플릿과 콤보까지 이어져요**: 매번 한 군데만 바뀌는 문구(템플릿), 이미 만든 걸 템플릿으로 바꾸기, 여러 값을 묶는 콤보를 차례로 익힐 수 있어요. 각 단계는 앞 단계를 써 본 뒤에 권하고, "나중에"를 고르면 다시 묻지 않아요.
• **연습으로 만든 건 정리해 드려요**, 다 끝나면 지울지 한 번만 물어봅니다.
• **언제든 다시**, 설정에서 튜토리얼을 처음부터 다시 볼 수 있어요.

**채우는 칸이 뭔지 이제 보여요**
• 템플릿을 만들 때, 같은 문장이 값만 바뀌는 모습을 두 줄로 나란히 보여줍니다. 무엇이 고정이고 어디가 바뀌는 자리인지 설명 없이 바로 읽혀요.
• `{ }` 같은 기호는 어디서도 보이지 않아요. 키보드 미리보기에서도 채우는 칸은 색이 켜진 조각으로 보입니다.

**그 밖에**
• **붙여넣기 허용 팝업을 미뤘어요**: 설치하자마자 묻지 않고, 며칠 써 보신 뒤에 한 번 여쭤봅니다.
• 앱 용량이 약 5.2MB 줄었어요.

**고친 것**
• 키보드를 켰는데도 "아직 다른 앱에서는 못 써요" 안내가 남아 있던 문제
• 단축어 목록이 화면 중앙에서 시작하던 문제
• 눌러서 넣은 글이 사라지던 문제
• 첫 단축어를 눌러 본 뒤 안내가 끊기던 문제
• '단축어를 템플릿으로' 단계가 통째로 건너뛰어지던 문제
• 템플릿을 만들 때 지은 이름이 목록에 그대로 안 쓰이던 문제
• 카테고리 배경색이 사라졌던 문제
• 빈 화면에서 배경이 두 색으로 갈리던 문제

---

## English (App Store)

Open the app and the keyboard is right there, the way it looks everywhere else. New here? You'll make one snippet yourself and use it, step by step.

**The first screen**
• **The keyboard, as it really looks**: see it the way it appears in other apps, and tap to try it right away.
• **Tap to type, hold to copy**: inside the app, a short tap types the snippet and a long press puts it on the clipboard.
• **Your list is still here**: pick your first screen in Settings › First screen, and switch anytime from the toolbar.
• **Category tabs and swipe paging** are there from the start.

**Getting started**
• **Make one yourself**: pick a situation like "Share my address with someone" and you'll have just one field to fill.
• **Making it isn't the end**: you move on only after you actually tap what you made. That moment, when the text lands, is the whole point.
• **Templates and combos follow**: a phrase where only one part changes (template), turning something you already made into a template, and bundling several values (combo). Each step is offered only after you've used the last one, and "later" means we won't ask again.
• **We'll tidy up after**: when it's done, we ask once whether to delete what you made for practice.
• **Anytime again**: you can replay the tutorial from Settings.

**You can see what a fill-in field does**
• While building a template, the same sentence is shown twice with different values. What stays and what changes reads at a glance: no explanation needed.
• You'll never see `{ }` anywhere. Even in the keyboard preview, fill-in fields appear as highlighted chips.

**Also**
• **The paste permission prompt waits**, it no longer greets you right after install; we ask once after you've used the app for a few days.
• The app is about 5.2 MB smaller.

**Fixes**
• The "not available in other apps yet" notice lingering after you'd already enabled the keyboard
• The snippet list starting halfway down the screen
• Text disappearing after you tapped to insert it
• The tutorial stopping after you used your first snippet
• The "turn a snippet into a template" step being skipped entirely
• The name you gave a template not being used in the list
• Category background colors going missing
• The two-tone background on empty screens

---

## 심사·배포 메모 (내부)

- **버전**: `Version.xcconfig` 의 `MARKETING_VERSION = 4.4.4`. 빌드 번호는 업로드 전 올릴 것.
- **새 권한 없음**, 추가된 권한·엔타이틀먼트 없음.
- **붙여넣기 프롬프트 시점 변경**: 클립보드 자동 읽기를 설치 후 3일 뒤로 미룸
  (`PastePermissionGuidance.warmUpDays`). 사용자가 직접 누른 붙여넣기는 그대로 동작.
  심사 중 신규 설치에서는 클립보드 탭이 비어 있는 것이 **정상**이며, 그 사실을 화면 문구로 안내한다.
- **키보드 감지**: `AppleKeyboards`(표준 UserDefaults) + App Group 표식 두 신호를 함께 본다.
- **스킨(키캡·생활 레이어)은 이번 버전에서 노출하지 않음**, `KeyboardSkin.isEnabled` /
  `LivingSkin.isEnabled` 가 false. 코드는 남아 있어 값 하나로 되살릴 수 있다.
  ⚠️ 되살릴 생각이라면 **그림부터 다시 넣어야 한다**, 금고·정동석 이미지는 이 버전에서
  지웠고, 지금 켜면 그 자리가 빈칸으로 남는다(`GeodeSkin.swift` 머리말 참고).
- **앱 자산 약 5.2MB 감소**, 광부 영상·미사용 튜토리얼 이미지 제거.
- **튜토리얼 상태 키 5개 추가**(전부 표준 UserDefaults, iOS 화면 상태 전용):
  `pendingMakeTemplateTutorial` · `tutorialCreatedMemoIds` · `tutorialCleanupAsked` ·
  `tutorialChaptersDone` · `tutorialFirstUseMemoId`.

### ⚠️ 인도네시아어, 제거가 덜 끝났다

`9317416` 에서 인도네시아어를 걷어냈지만 **프로젝트 설정에는 그대로 남아 있다.**
`knownRegions` 에 `id` 가 있고 두 타겟이 `id.lproj/InfoPlist.strings` 를 참조해서,
파일이 없으면 빌드가 멈춘다(실제로 멈췄고 `862cc90` 에서 파일을 만들어 세웠다).

지금 상태: `Localizable.xcstrings` 에 `id` 값이 **4개만** 남아 있다.
배포 전에 둘 중 하나로 정리할 것.

| 택할 길 | 할 일 |
|---|---|
| 인도네시아어를 **버린다** | `knownRegions` 에서 `id` 제거, `INFOPLIST005/006` 참조와 `id.lproj` 두 폴더 삭제, 카탈로그의 남은 `id` 값 4개 정리 |
| **되살린다** | 카탈로그 전체(2,000여 항목)에 `id` 번역 채우기 |

그대로 두면 앱 스토어에 인도네시아어 지원으로 표시되는데 실제로는 문구 4개만 번역된 상태가 된다.

## macOS 앱(별도 저장소) 호환성

검토 결과 **깨지는 지점 없음**. 근거:

| 항목 | 결과 |
|---|---|
| `Memo` 모델·`MemoStore` 저장 포맷 | 변경 없음 |
| `MemoSyncCore` / `StorageFile` / `AppGroup` (공유 파일) | 변경 없음 (양쪽 동일) |
| CloudKit 백업·동기화 레코드 | 변경 없음 |
| `DefaultsKey.swift` (공유 파일) | iOS 쪽에만 키가 추가됐다(첫 화면 3개 + 튜토리얼 5개). 전부 **표준 UserDefaults, iOS 화면 상태 전용**이라 맥이 읽지 않는다. 맥 사본은 원래도 iOS 전용 키를 안 갖는 부분집합이다 |
| `category.feature.enabled.v1` (App Group) | 맥도 읽는 키. iOS가 이제 값이 없을 때 `true` 를 적지만, **App Group 컨테이너는 기기·앱마다 별개**라 맥 쪽 값에는 영향이 없다. 맥은 자기 `MacCategoryStore` 판단을 그대로 쓴다 |
| 이번에 지운 파일(MinerScene·영상·이미지) | 맥 저장소에 없음 |

⚠️ 남는 일: 맥에도 카테고리 기본 활성화를 맞출지는 **맥 저장소에서 따로 정할 문제**다.
지금은 맥이 예전 규칙(기본 꺼짐)을 쓰므로, 같은 사람이 두 기기를 쓰면 카테고리 탭 노출이
서로 다를 수 있다. 맞추려면 `MacCategoryStore` 의 기본값을 같은 방식으로 바꿔야 한다.
