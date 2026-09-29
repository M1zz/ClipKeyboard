# 클립키보드 iPhone Duo 대응 진단 (코드 수정 없음 · 2026-09-24)

> 진단만 한 문서다. **코드는 한 줄도 건드리지 않았다.** 지금 상태에서 무엇이 깨지고,
> 무엇이 이미 준비돼 있는지, 고칠 순서가 무엇인지까지만 적는다.
> 기준 버전: 5.1.5 (build 18), iOS 배포 타겟 26.0, 기기 패밀리 "1,2".

## TL;DR

1. **앱 본체는 생각보다 준비돼 있다.** 회전 전부 허용, `UIRequiresFullScreen` 없음,
   아이패드 지원(1,2), 커스텀 `UIToolbar`/`UITabBar` 없음, 탭 4개 모두 아이콘 있음.
   Duo가 요구하는 "리사이즈 가능한 앱"의 전제 조건은 이미 통과한 상태다.
2. **제일 큰 구멍은 키보드 높이 장부가 `UIScreen.main` 을 본다는 것이다.** Duo는
   화면이 둘이고, 접고 펴는 동안 콘텐츠가 두 화면 사이를 오간다. 지금 셈은 "기기 화면은
   하나"라는 전제 위에 서 있어서, **바깥 화면에서 안쪽 화면 높이로 키보드가 선다.**
   우리 앱의 핵심 기능이 키보드라 이건 P0다.
3. **툴바 아이템 70개 중 60개가 아이콘이 없다.** Duo는 바깥 화면(닫은 상태)과 안쪽
   화면 trailing 시트에서 바를 **세로로** 세우는데, 애플 문서에 "제목만 있고 아이콘이
   없는 아이템은 세로로 세우지 않는다"고 못 박혀 있다. 즉 **취소·저장·완료가 통째로
   사라진다.** 시트가 76곳이라 영향 범위가 넓다.
4. **튜토리얼 물결(TabBarProbe)은 조용히 죽는다.** `first.midY > screen.height * 0.7`
   조건이 "탭바는 아래에 있다"를 전제한다. 세로 탭바에서는 못 재고 nil → 안내가 안 뜬다.
   (잘못 그리지는 않는다. 설계대로 안전하게 죽는다.)

---

## 0. Duo가 무엇을 요구하나 (요약)

| 요구 | 내용 |
| --- | --- |
| 리사이즈 | 바깥/안쪽 화면, 펼침/접음/부분 접음, 회전마다 크기가 바뀐다 |
| 예약 영역 | 접히는 부분(division)과 카메라(occlusion)를 `reservedRegions(kind:options:)` 로 물어본다 |
| 세로 바 | 네비바·툴바·탭바를 화면 옆에 **세로로** 세운다. 아이콘 없는 아이템은 제외된다 |
| 배치 | `ArrangementView` / `UIArrangementViewController` (split · overlay)로 포즈별 배치 |
| 빌드 | Xcode 27.1 이상으로 빌드해야 상태바·카메라 아래까지 화면을 다 쓴다 |
| 금지 | `userInterfaceIdiom`, `UIInterfaceOrientation` 으로 레이아웃 결정하지 말 것 |

출시는 2026년 10월. 지금 우리 CI는 Xcode Cloud를 쓰므로 **툴체인 업그레이드가 선행 조건**이다.

---

## 1. 이미 통과한 것 (손댈 필요 없음)

| 항목 | 근거 |
| --- | --- |
| 회전 잠금 없음 | `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` = Portrait + Landscape L/R |
| `UIRequiresFullScreen` 없음 | 프로젝트 전역에 키 자체가 없다 |
| 기기 패밀리 1,2 | 아이패드를 이미 지원 → 넓은 안쪽 화면의 전제가 이미 검증돼 있다 |
| 커스텀 바 없음 | `UIToolbar(` / `UITabBar(` / `UINavigationBar(` 직접 생성 0건 → 세로 전환은 시스템이 해 준다 |
| 탭 아이콘 | `MainTabView` 의 4개 탭 모두 `systemImage` 있음 → 세로 탭바에서 그대로 선다 |
| 방향 API 미사용 | `UIInterfaceOrientation` / `UIDeviceOrientation` 코드 0건 |
| idiom 분기 없음 | `userInterfaceIdiom` 레이아웃 분기 0건 (`UIDevice.current` 는 ID·클릭음 용도뿐) |
| 격자 열 수 | `ClipKeyboardList.swift:1319`: `horizontalSizeClass == .regular ? 4 : 2`. 사이즈 클래스 기반이라 Duo에서도 따라간다 |
| 윈도우 기준 측정 선례 | `MemoReorderScreen.swift:184`: 이미 `UIScreen.main` 을 버리고 활성 씬 윈도우 너비를 쓴다. **이 파일이 나머지를 고칠 때의 본보기다** |
| 유연 레이아웃 | `KeyboardClipboardPicker.swift:284` 커스텀 `Layout` 이 `proposal.width` 를 받아 흐른다 |

---

## 2. P0: 키보드 높이가 "화면은 하나"를 전제한다

Duo에서 가장 크게 어긋나는 지점이자, 하필 이 앱의 본체다.

### 2-1. 장부 열쇠가 화면 크기다

`Service/KeyboardHeightBook.swift:47`: `key(for:)` 가 `짧은변x긴변-방향` 으로 열쇠를 만든다.

- Duo는 **한 기기에 크기가 다른 화면이 둘**이다. 열쇠는 둘을 구분하지만,
  **부분 접힘 상태의 중간 크기들**까지 각각 새 열쇠가 된다 → 장부가 잘게 흩어지고
  대부분의 포즈에서 "잰 적 없음" → `fallbackHeight` 어림값으로 떨어진다.
- `consider(frame:screen:)` (343행)의 신뢰 판정 `coversWidth`(폭이 화면과 1pt 이내)는
  **접힘 영역이 활성인 동안** 입력 뷰 폭과 화면 폭이 갈리면 전부 "믿을 수 없는 값"으로
  버려진다. 즉 Duo에서 **영원히 값을 못 적을 수 있다.**

### 2-2. `UIScreen.main` 을 보는 곳 (앱 타겟 4곳)

| 위치 | 증상 |
| --- | --- |
| `Screens/InAppKeyboardStage.swift:701` | 무대 키보드 높이가 **지금 보고 있는 화면이 아닌** 기본 화면 기준으로 선다 |
| `Screens/KeyboardLayoutSettings.swift:81` | 설정의 "기본 키보드와 견주기" 숫자가 다른 화면 기준 → 설정이 다시 거짓말을 한다 |
| `Screens/KeyboardLayoutSettings.swift:601` | `screenWidth`: 미리보기 폭 |
| `Screens/KeyboardLayoutSettings.swift:626` | 미리보기 자연 높이 |
| `Service/KeyboardHeightBook.swift:343` | 기록 판정의 기준 화면 |

익스텐션(`KeyboardViewController.swift:295`)은 이미 `view.window?.windowScene?.screen.bounds`
를 **먼저** 보고 `UIScreen.main` 은 폴백이다. 방향은 맞다. 다만 Duo에서는 폴백이
**틀린 화면**을 줄 수 있으니, 폴백을 "직전에 알던 크기"나 `minimumContentHeight` 쪽으로
바꾸는 편이 안전하다.

> 고칠 방향(참고): `MemoReorderScreen.swift:184` 처럼 활성 씬의 키 윈도우 `bounds` 를 쓰고,
> 앱 쪽도 `GeometryReader`/`scene` 크기를 인자로 받아 내려보내는 형태.
> `KeyboardHeightBook` 의 공개 함수는 이미 `for size:` 를 받으므로 **호출자만 바꾸면 된다.**

### 2-3. 접힘 영역 위의 키보드

부분 접힘에서 키보드 판이 접히는 선을 가로지르면 아래쪽 키 줄이 꺾인 면에 걸린다.
`KeyboardView.swift` 의 `LazyVGrid`(1171, 2719행)와 조작 키 줄(781~1024행)은
예약 영역을 전혀 모른다. **확인 필요:** 애플 문서에는 키보드 익스텐션의 예약 영역 처리에
대한 명시적 지침이 아직 없다(입력 뷰를 시스템이 접힘 밖으로 밀어 주는지 불명).
시뮬레이터에서 **가장 먼저 눈으로 확인할 항목**으로 둔다.

---

## 3. P1: 세로 바에서 사라지는 버튼들

애플 규칙: 세로로 세울 때 **아이콘만 쓴다. 제목만 있고 아이콘이 없으면 세로로 안 세운다.**
커스텀 뷰를 쓴 아이템도 마찬가지로 제외된다.

- 툴바 아이템 **70개 중 60개가 아이콘 없음** (`ToolbarItem`/`ToolbarItemGroup` 기준,
  블록 안에 `systemImage`·`Image(systemName:)`·`Label(` 이 없는 것).
- 배치 분포: `.cancellationAction` 21, `.confirmationAction` 19, `.topBarLeading` 11,
  `.topBarTrailing` 6, `.primaryAction` 3, `.navigationBarTrailing` 3, `.navigationBarLeading` 2.
- 시트가 **76곳**, `presentationDetents` 13곳. 바깥 화면에서 시트 바는 기본이 세로다.

대표 사례(전부 텍스트 버튼): `ClipboardList.swift:861/867/932/938` (취소·저장·취소·생성),
`Template/TemplateSheets.swift:131/134/631`, `Template/PlaceholderSelectorView.swift:527/530/603/606`,
`Memo/MemoAdd.swift:253`, `Memo/BulkImportView.swift:155`, `List/MemoReorderScreen.swift:75`,
`App/ClipKeyboardApp.swift:1283` (Done), `Screens/AccessibilityGuideView.swift:33` (확인).

> 고칠 방향(참고):
> - 취소/닫기 → `.cancellationAction` 유지 + `Label("취소", systemImage: "xmark")`
> - 저장/완료 → `ToolbarItemPlacement.topBarPinnedTrailing` + 체크 아이콘
> - 세로에서 뺄 것은 `axisBehavior(_:)`, 넘침 순서는 `visibilityPriority(_:)`,
>   처음부터 넘침으로 보낼 것은 `ToolbarOverflowMenu`
> - 시트 위치는 `presentationPlacement(_:)`, 세로 바가 싫으면 `toolbarVerticalBehavior(_:)`
> - 커스텀 뷰에서 지금 세로인지 알아야 하면 `EnvironmentValues.toolbarVerticalEdge`

접근성 관점에서도 같은 작업이 이득이다. 아이콘 없는 버튼에 아이콘을 다는 일은
VoiceOver·다이내믹 타입 쪽 품질과 방향이 같다.

---

## 4. P1: "탭바는 아래에 있다" 전제

`Screens/TabBarProbe.swift:40`

```swift
guard screen.contains(CGPoint(x: first.midX, y: first.midY)),
      first.midY > screen.height * 0.7 else { return nil }
```

- 세로 탭바에서는 첫 칸이 화면 **위쪽 옆**에 선다 → 조건 불통과 → `nil`
  → 튜토리얼의 "탭을 한 번 더 누르면 오갑니다" 물결이 **안 뜬다.**
- 정렬도 `sorted { $0.minX < $1.minX }` 라 가로 배열 전제다. 세로면 `minY` 로 정렬해야 한다.
- 다행히 설계상 "못 재면 안 그린다"라서 **엉뚱한 자리에 뜨지는 않는다.** 기능이 조용히
  빠질 뿐이다. 무대 머리말의 격자 버튼 쪽 안내는 살아 있으니 완전한 실종은 아니다.
- 같은 전제가 `App/ClipKeyboardApp.swift` 끝의 `.scrollEdgeEffectHidden(true, for: .bottom)`
  에도 있다. 세로 바에서 하단만 숨기는 것이 무슨 뜻이 되는지 확인 필요.

---

## 5. P2: 예약 영역(접힘·카메라)을 모르는 커스텀 뷰

`GeometryReader` 를 쓰는 9개 파일이 지금은 **크기만** 보고 `reservedRegions` 는 안 본다.

| 파일 | 왜 걸리나 |
| --- | --- |
| `Screens/InAppKeyboardStage.swift` | 대화 + 입력창 + 키보드 무대가 한 화면에 세로로 쌓임 → 접힘 선이 이 사이를 가른다. **`ArrangementView`(split)가 가장 잘 맞는 화면** |
| `ClipKeyboardExtension/KeyboardView.swift` | 키 격자 (2-3 참조) |
| `ClipKeyboardExtension/NumberPadPanel.swift` | 숫자판 격자 |
| `Screens/List/ClipKeyboardList.swift` | 카드 격자: 열 수는 사이즈 클래스로 따라가나 접힘 선 위에 카드가 걸리는 건 별개 |
| `Screens/Memo/SmearTextPickerView.swift` | 문지르는 제스처 영역이 접힘 선을 넘으면 감각이 끊긴다 |
| `Screens/UsageStatsView.swift`, `Component/UsageBreakdownCharts.swift` | 차트가 접힘 선에서 갈린다 |
| `DesignSystem/Living/FootprintTrail.swift`, `Vault/VaultDeposit.swift` | 연출 좌표계 |

또한 `KeyboardLayoutSettings.budget = 200` 처럼 고정 예산으로 미리보기를 자르는 자리는
안쪽 화면에서 필요 이상으로 작아진다(깨지지는 않는다).

고정 폭 프레임은 4곳뿐이라 큰 문제는 아니다:
`KeyboardSetupOnboardingView.swift:654`(100), `TutorialFlow.swift:258`(132),
`ShareVideoRenderer.swift:272`(320: 렌더러라 의도된 값), `ShareViewController.swift:280`(120).

---

## 6. P2: 카메라 방향

OCR 입력 경로가 카메라를 쓴다: `Memo/ImagePickerComponents.swift` 의
`VNDocumentCameraViewController` 와 `UIImagePickerController(sourceType: .camera)`,
호출부는 `Memo/BulkImportView.swift:152/299`, `Memo/MemoAddComponents.swift:406/670`.

Duo는 바깥·안쪽 각각 전면 카메라가 있고, **접고 펴는 동안 앱이 있는 화면이 바뀌면서
쓰던 카메라가 반대 방향을 보게 된다.** `UIImagePickerController` 는 시스템 UI라 대부분
시스템이 처리하지만, 스캔 도중 접었을 때의 거동은 확인 항목이다.
(애플 지침: `AVKit` 의 "choosing a camera by the direction it faces")

---

## 7. 그 밖의 타겟

- **위젯**: `systemSmall` / `accessory*` 만 지원 → 크기 계약이 시스템 몫이라 Duo 영향 적음.
  단 바깥 화면 잠금화면 위젯이 어떻게 보이는지는 눈으로 볼 것.
- **공유 익스텐션**(`ShareViewController.swift`): 120pt 고정 이미지 외에는 표준 시트.
  바깥 화면에서 세로 바로 뜰 때 버튼 아이콘 문제(3번)를 같이 받는다.
- **액션 익스텐션**, **Token memo.xcodeproj**: 별도 확인 필요(이번 진단 범위 밖).

---

## 8. 검증 계획 (코드 고치기 전에 먼저 할 것)

1. **Xcode 27.1 베타 설치 → Duo 시뮬레이터로 현 상태 그대로 한 번 돌린다.**
   고치기 전에 "진짜로 어떻게 깨지는지"를 봐야 위 추정 중 무엇이 틀렸는지 걸러진다.
2. 포즈 6가지 × 회전: 닫음 / 텐트 / 완전 펼침(가로) / 부분 접힘 / 완전 펼침(세로) / 랩탑.
3. 키보드 전용 행렬: 포즈 6 × 높이 프리셋 3(`compact`/`standard`/`roomy`) × 열 수 설정.
   보는 것: 판 높이가 화면과 맞는가, 접힘 선 위에 키가 걸리는가, 화면을 오갈 때 높이가 튀는가.
4. 시트 76곳 중 자주 쓰는 순으로 10개만 먼저: 바깥 화면에서 **버튼이 보이는가**.
5. 튜토리얼 물결(TabBarProbe): 안 뜨는 것이 맞는지 확인.
6. Xcode Cloud 툴체인 버전 확인(`ci_scripts/`): 27.1로 올려야 화면 전체를 쓴다.

## 9. 고칠 순서 (제안)

| 순위 | 일 | 크기 |
| --- | --- | --- |
| 1 | 툴체인 27.1 + Duo 시뮬레이터에서 실측 | 반나절 |
| 2 | `UIScreen.main` 5곳 → 씬/윈도우 기준으로 (호출자만) | 반나절 |
| 3 | `KeyboardHeightBook` 열쇠·신뢰 판정을 Duo 전제로 재설계 | 1~2일 |
| 4 | 툴바 아이템 60개에 아이콘: 자주 쓰는 시트부터 | 1~2일 |
| 5 | `TabBarProbe` 세로 대응 또는 세로일 때 명시적 비활성 | 2시간 |
| 6 | `InAppKeyboardStage` → `ArrangementView(split)` | 1일 |
| 7 | 키 격자 예약 영역 대응 | 실측 결과에 달림 |

---

## 참고

- [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)
- [Designing for iPhone Duo (HIG)](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)
- [Prepare your app for iPhone Duo (Tech Talk 111461)](https://developer.apple.com/videos/play/tech-talks/111461/)
- [Design for iPhone Duo (Tech Talk 111466)](https://developer.apple.com/videos/play/tech-talks/111466/)
- [Leverage multiple displays and scenes on iPhone Duo (Tech Talk 111464)](https://developer.apple.com/videos/play/tech-talks/111464/)
- [Get Ready for iPhone Duo](https://developer.apple.com/iphone-duo/)
