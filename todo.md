# ClipKeyboard 진행 상황

## 👆 무대에서는 길게 눌러 복사 (2026-08-06)

- [x] 키마다 붙였던 **작은 복사 버튼 제거** — 좁은 키에 누를 곳이 둘이라 잘못 누르기 쉬웠고
      제목도 가렸다. 길게 누르기는 자리를 차지하지 않는다
- [x] **짧게 = 입력창에, 길게 = 클립보드에**(앱 무대에서만). 익스텐션은 그대로 —
      거기선 롱프레스가 이미 컨텍스트 메뉴(미리보기 + 복사)를 연다
- [x] 길게 누른 직후의 탭은 한 번 무시한다 — 복사만 하려 했는데 글까지 들어가면
      지우는 일이 하나 더 생긴다
- [x] 길게 누르기는 **눈에 안 보이는 동작**이라 무대 안내 말풍선에 한 줄로 알린다
      ("…눌러 보세요. 길게 누르면 복사돼요.") · 손이 불편한 사람을 위해 접근성 동작도 함께
- [x] **고치는 일은 목록에서** — 무대는 써 보는 자리다(편집 진입점 없음, 그대로 유지)
- [x] 전체 스위트 TEST SUCCEEDED · 두 타깃 빌드 그린
- [ ] 실기기에서 길게 누르기 반응 시간(0.45s)이 적당한지 확인 필요

## 🎓 튜토리얼 재구성 — 상황으로 묻고, 눌러 봐야 끝난다 (2026-08-06)

- [x] **고르는 자리에 상황을 준다** — "내 주소"가 아니라 "지인에게 내 주소 알려주기".
      항목 이름만 있으면 그게 뭘 하는 건지, 왜 저장해 두면 좋은지가 안 보인다.
      처음 온 사람에게 필요한 건 이름이 아니라 **언제 쓰는 물건인가**이다
      · ⚠️ 만들어지는 **단축어 이름은 짧게** 유지(`title`) — 상황 문장을 이름으로 쓰면
        카드와 키에 "지인에게 내 주소 알려주기"가 박혀 정작 목록에서 못 알아본다
- [x] **만들면 곧바로 무대에서 그 키가 빛난다** — `KeyboardView(highlightedMemoId:)`.
      빛은 **어디**를, 위의 한 줄("방금 만든 단축어를 눌러 보세요")은 **무엇**을 알린다
- [x] **그 키를 눌러야 첫 걸음이 끝난다**(.memoUsed 로 확인).
      ⚠️ 아무 키나 눌러도 끝나지 않는다 — 가리킨 것과 다른 걸 눌렀는데 안내가 사라지면
      무엇 때문에 끝났는지 알 수 없다. 누르고 나면 배우는 곳(목록)으로 데려간다
- [x] **순서**: 단축어 → 눌러보기 → 템플릿 → 단축어를 템플릿으로 → 콤보 → 키보드 설정
      · 키보드 설정이 **맨 뒤**인 이유: 설정 앱으로 나갔다 오는 일이라 흐름이 가장 크게 끊긴다.
        배울 걸 다 배운 뒤라야 "이제 다른 앱에서도 쓰려면"으로 이어져 나갔다 올 이유가 분명하다
      · 템플릿·콤보 챕터 기계는 목록 화면 것을 그대로 쓴다(새로 만들지 않음)
- [x] 순서 판단은 `SnippetsOnboardingStep` 한 곳 — 테스트 8건 · 전체 스위트 TEST SUCCEEDED
- [ ] 실기기 확인 필요: 하이라이트가 실제로 눈에 띄는지, 눌렀을 때 목록으로 넘어가는 흐름이 자연스러운지
      (시뮬레이터는 탭 입력을 넣을 수 없어 이 경로를 눈으로 못 봤다)

## 🔔 업데이트를 알리는 길 + 새 설치 판정 고침 (2026-08-06)

- [x] **"새로운 기능" 안내가 4.4.4 를 소개하도록** — 내용이 아직 4.3.4(빠른 메모)에 멈춰 있었다.
      `WhatsNewContent.version` 이 그대로여서 업데이트한 사람은 **아무 안내도 못 받는 상태**였다
      (이미 본 것으로 기록돼 있으므로). 내용을 키보드 화면으로 새로 쓰고 버전을 4.4.4 로 올림
      · 큰 버튼은 **그 화면으로 데려간다** — 읽고 닫으면 아무것도 안 달라진다
      · ⚠️ 내용을 바꿀 때 `version` 도 함께 올릴 것(안 올리면 아무도 못 본다)를 주석으로 못박음
- [x] **지우고 깔아도 튜토리얼이 안 뜨던 원인** — 새 설치 판정을 `app_install_date` 가 비어 있는지로
      봤는데, **그 값은 이 시점보다 먼저 쓰일 수 있다**(ReviewManager 등이 다른 경로로 깨어나면
      자기가 찍는다). 그러면 방금 지우고 깐 사람이 '기존 사용자'로 판정돼 튜토리얼이 통째로 사라진다
      · **실행 횟수(appLaunchCount)** 로 바꿈 — `incrementAppLaunchCount()` 한 곳에서만 오르므로
        "이 시점에 0이면 첫 실행"이 흔들리지 않는다
- [x] 전환 버튼·+ 에 **유리 서클**(`glassEffect(.clear.interactive(), in: Circle())`) — 툴바의 +,
      하단 탭바와 같은 유리 언어. 하나만 맨몸이면 그것만 다른 앱에서 온 것처럼 보인다
- [x] 신규 문자열 9개 ko/en/id · 전체 스위트 TEST SUCCEEDED · 빌드 그린
- [x] `PastePermissionGuidance.installDate` 게터가 값을 **쓰던** 부작용 제거 —
      읽기만 하는 자리에서 쓰면 남의 정리(테스트·초기화)를 조용히 되돌려 놓는다
- [ ] ⚠️ **시뮬레이터 오염 주의(경험)** — 스크린샷 찍으려고 `simctl spawn defaults write` 로
      `appLaunchCount`·`app_install_date` 를 써 넣으면 **테스트가 깨진다**(리뷰 초기화 테스트가
      그 값을 0으로 검사). cfprefsd 가 지운 값을 되살려 놔서 `defaults delete` 로도 안 지워졌고,
      `xcrun simctl erase` 로 기기를 초기화해야 풀렸다. 검증용 값 주입 뒤에는 반드시 정리할 것

## 📝 4.4.4 릴리즈 노트 + 맥 호환성 검토 (2026-08-06)

- [x] 앱 안 변경 이력에 **4.4.4** 항목 추가(ChangelogView) · 문구 7개 ko/en/id
- [x] 앱스토어용 문안 `docs/RELEASE_NOTES_4.4.4.md` — 한국어/영어 + 심사 메모
      · 심사 메모에 **붙여넣기 프롬프트 지연**을 적어 둠 — 신규 설치에서 클립보드 탭이
        비어 있는 것이 정상이라는 걸 모르면 리젝 사유로 오해될 수 있다
- [x] **맥 앱(별도 저장소) 호환성 — 깨지는 지점 없음**
      · Memo 모델·MemoStore 포맷·CloudKit 레코드 **변경 없음**
      · 공유 파일 7개 중 바뀐 건 `DefaultsKey.swift` 뿐이고, 추가한 키 3개는 전부
        **표준 UserDefaults + iOS 화면 상태 전용** — 맥은 읽지 않는다
      · `category.feature.enabled.v1` 은 맥도 읽지만 **App Group 컨테이너가 기기마다 별개**라
        맥 값에 영향 없음
- [ ] ⚠️ 맥은 아직 카테고리 **기본 꺼짐** — 같은 사람이 두 기기를 쓰면 탭 노출이 다를 수 있다.
      맞추려면 맥 저장소의 `MacCategoryStore` 기본값을 같은 방식으로 바꿀 것

## 🎞 전환·배경 다듬기 + 튜토리얼 한 줄기로 (2026-08-06)

- [x] **배경은 두 화면 뒤에 하나만** — 각 화면이 자기 배경을 칠하면 갈아 끼우는 순간 바닥색이
      한 번 바뀌어 번쩍인다. `SnippetsTab` 이 바닥을 깔고, 바뀌는 건 그 위에 놓인 것뿐
- [x] **목록 → 미리보기만 튀던 원인** — 무대가 `onAppear` 에서 문구를 읽고 곧바로 `feedToken` 을
      올려 **키보드를 다시 만들었다.** 그게 화면이 들어오는 도중에 일어나 한 번 튀었다
      (반대 방향은 다시 만들 일이 없어서 멀쩡했다)
      · 문구는 **뷰가 만들어질 때**(init) 미리 읽는다 → 등장할 땐 그릴 것이 이미 준비돼 있다
      · 이후에는 **id 목록이 바뀐 경우에만** 다시 만든다(검색어·콤보 위치도 안 날아간다)
- [x] **튜토리얼을 한 줄기로** — ① 하나 만들고 ② 키보드 켜고 ③ 눌러 본다.
      예전엔 ①이 끝나면 무대로 떨어뜨려 두고 ②는 띠를 눌러야만 시작됐다. 거기서 끊기면
      "만들긴 했는데 어디에 쓰지"로 끝난다 — 값어치는 ③에서만 드러나는데 ②를 건너뛰면 ③이 안 온다
      · 순서 판단은 뷰 밖으로(`SnippetsOnboardingStep`) — 테스트 5건으로 고정
      · **이미 키보드를 켜 둔 사람에게는 ②를 건너뛴다**(시뮬레이터에서 확인)
      · 건너뛴 사람은 다시 붙잡지 않는다(`keyboardSetupTutorialDone`)
- [x] 전체 스위트 TEST SUCCEEDED · 빌드 그린
- [ ] 전환이 실제로 매끄러운지는 **정지 스크린샷으로는 판단 못 함** — 실기기에서 눈으로 확인 필요
- [ ] 키보드가 꺼진 기기에서 ② 단계가 실제로 뜨는지 확인 필요(이 시뮬레이터는 켜져 있어 건너뛴다)

## 🗂 카테고리·스와이프 되살리기 + 전환 다듬기 (2026-08-06)

- [x] **카테고리 기능이 처음부터 켜져 있다** — 예전엔 꺼진 채 시작해서 메모 5개가 넘어야 뜨는
      배너를 눌러야 켜졌다. 그 전까지 화면은 '전체' 한 장뿐이라 탭도 스와이프도 없었고,
      **이 앱에 카테고리가 있다는 사실 자체를 알 수 없었다.** 켠 뒤에야 보이는 기능은 없는 기능과 같다
      · 저장된 값이 있으면 그대로 따른다(직접 끈 사람의 선택은 존중)
      · 값이 없을 때만 켜고 **App Group에 적어 둔다** — 익스텐션은 이 키를 직접 읽어서,
        안 적으면 앱엔 탭이 보이고 키보드엔 안 보이는 어긋남이 생긴다
      · 결과: 첫 탭이 `.basic` 이라 제목이 **'기본'**, 좌우 스와이프 페이지네이션도 돌아옴
- [x] 화면 전환을 부드럽게 — 두 화면은 **같은 자리에서 갈아 끼우는 것**이라 서로 밀어내지 않는다.
      살짝 줄었다 펴지는 크로스페이드(0.28s). 동작 줄이기가 켜져 있으면 애니메이션 없음
- [x] 전체 스위트 TEST SUCCEEDED · 빌드 그린
- [ ] 목록 화면(기본 제목·스와이프·카테고리 탭)은 **눈으로 확인 못 함** — 시뮬레이터가 계속
      새 설치로 판정돼 무대만 뜬다. App Group에 `category.feature.enabled.v1 = true` 가
      앱 손으로 기록된 것까지만 확인. 실기기 확인 필요
- [ ] ⚠️ 테스트에서 "설치일 없음" 경로는 검사 못 한다 — 시뮬레이터 cfprefsd 가 지운 키를
      되살려 놔서 삭제 상태를 만들 수 없다(PastePermissionGuidanceTests 주석 참고)

## 📐 그리드가 화면 중앙에서 시작하던 진짜 원인 (2026-08-06)
> 예전에 두 번 손봤지만(측정 범위 좁히기) 계속 재발했다. 범위 문제가 아니었다.

- [x] **경로가 둘인데 여백을 하나로 쓰고 있었다** (최종 원인).
      · **카테고리 페이저(TabView)** — 시스템이 안 밀어 준다 → 잰 바 하단(100~130)을 그대로 줘야 한다.
        안 주면 카드가 타이틀·툴바를 덮는다
      · **단일 페이지**(카테고리 꺼짐, '전체' 한 장) — ScrollView 를 시스템이 밀어 준다 →
        거기에 또 얹어서 여백이 **두 번** 들어갔고, 그게 "그리드가 안 올라간다"의 정체였다
      · 이제 `pageContentTopMargin` 이 **그려지는 경로를 그대로 따라간다**(categoryContent 분기와 같은 조건)
      · 시뮬레이터 확인: 제목 '기본' · 카드가 타이틀 아래에서 시작 · 하단 스와이프 인디케이터 복귀
- [x] (중간 진단) 단일 페이지에서 여백을 0으로 두면 타이틀 아래 36pt 에 붙는다 — 페이저가 세이프에어리어를 무시해도
      **ScrollView 는 시스템이 알아서 바 아래로 콘텐츠를 밀어 넣는다.** 그걸 모르고
      잰 네비바 하단(100~130)을 `contentMargins(.top)` 으로 한 번 더 얹은 게 원인
      · 실측: 여백 0으로 두면 카드가 타이틀 아래 36pt 에 정확히 붙는다 → 시스템이 이미 밀어 준 것
      · `pageContentTopMargin` = **8**(숨 쉴 틈만). 측정값을 더하지 않는다
- [x] 빈 화면은 사정이 **반대** — ScrollView 가 아니라 VStack 이라 시스템이 안 밀어 준다.
      그쪽만 측정값을 쓰도록 `emptyPageTopMargin` 으로 분리
- [x] 측정 자체도 방어: 커지는 쪽으로는 안 움직인다(`min`) — 실패 방식은 언제나 "너무 큼"이었다
- [x] **카테고리는 손대지 않음** — 탭·필터·저장 로직 모두 그대로
- [x] **목록 ↔ 키보드 미리보기 전환 버튼**(`SnippetsStyleSwitchButton`) — 두 칸짜리 스위치가 아니라
      **버튼 하나**. 버튼은 **갈 곳**을 그린다(목록에선 키보드 모양, 미리보기에선 격자 모양)
      → 누르면 그 자리에서 반대편 모양으로 바뀐다
      · 자리는 양쪽 다 **+ 버튼 왼쪽** — 목록은 툴바, 무대는 머리말. 같은 자리라야 같은 스위치로 읽힌다
- [x] 시뮬레이터 확인: 카드가 타이틀 바로 아래에서 시작 · 토글 동작 위치 확인 · 전체 스위트 TEST SUCCEEDED

## 🩹 붙여넣기 시점·키보드 탐지·색 (2026-08-06, `feat/dossier-delight`)

- [x] **붙여넣기 팝업을 설치 3일 뒤로** — iOS는 클립보드를 **읽는 순간** 팝업을 띄운다.
      설치 당일에 뜨면 신규 사용자가 이 앱에서 보는 첫 다이얼로그가 권한 요청이 된다
      · `PastePermissionGuidance.warmUpDays = 3` / `mayAutoReadClipboard` 로 자동 읽기 차단
      · **사용자가 직접 누른 붙여넣기는 그대로 동작한다** — 막는 건 묻지도 않았는데 읽는 것뿐
      · 우리 안내(배너·알림)는 3일 **그리고** 3회 실행 이후로
      · 그 며칠 동안 빈 화면 문구도 사실대로 바꿈("며칠 써 보신 뒤부터 모아요")
- [x] **"아직 다른 앱에서는 못 써요"가 안 사라지던 문제** — 익스텐션이 **떠 본 적 있는가**만 봤다.
      설정에서 켜고 전체 접근까지 허용해도, 아직 아무 앱에서 안 불러냈으면 거짓이라 띠가 남았다
      · `KeyboardInstallState` — ① 설정 목록(`AppleKeyboards`)에 우리 번들이 있는가
        ② 익스텐션이 한 번이라도 떴는가. **둘 중 하나면 쓸 수 있는 것으로 본다**
      · 설치 안내 화면의 '확인' 단계도 같은 판단을 쓴다
- [x] **색이 갈색이던 이유** — 앱 크롬(툴바·탭바)은 시스템 블루인데 새 화면만 `theme.accent`
      (Paper 테마의 테라코타 #C85A3A)를 써서 혼자 갈색이었다 → 무대의 크롬을 `.accentColor` 로
- [x] **목록 ↔ 키보드 미리보기 왕복** — 무대의 '목록' 버튼은 이제 **설정값을 뒤집는다**(커버 아님).
      목록에는 돌아갈 알약을 얹었다(목록 화면 코드는 손대지 않음 — 뷰 트리 깊이 한계)
      · 고른 값이 저장되므로 다음에 열면 마지막에 본 쪽이 나온다(설정 > 첫 화면과 같은 값)
- [x] 무대 머리말 정리 — 설명 문구 빼고 제목 + 목록 + **＋**(새 단축어). ＋가 없어 만들려면 두 번 건너가야 했다
- [x] 테스트 8건 추가(붙여넣기 날짜 경계·키보드 탐지) · 전체 스위트 TEST SUCCEEDED · 빌드 그린
- [ ] 목록 쪽 '키보드 미리보기' 알약은 **눈으로 확인 못 함** — 시뮬레이터가 새 설치로 계속 판정돼
      목록 모드로 못 들어갔다(설정을 써도 실행 때 시딩이 덮어씀). 실기기 확인 필요

## 🎬 튜토리얼로 시작 + 두 색으로 갈리던 배경 (2026-08-06, `feat/dossier-delight`)

- [x] **새 설치는 튜토리얼부터** — 무대로 바로 떨어뜨리면 눌러 볼 문구가 하나도 없다.
      빈 키보드를 보여주는 셈이라 무엇을 하는 앱인지 알 길이 없다. 하나 만들어 본 다음 무대에 선다
      · `SnippetsTab.needsFirstShortcut` = 무대 스타일 + 새 설치 + 첫 단축어 미완료
      · 목록 쪽은 이미 자기 빈 화면에서 같은 튜토리얼을 띄우므로 **무대일 때만** 가로챈다(두 번 방지)
      · 튜토리얼 → 무대 → (키보드 미설치면) 켜기 띠 → 키보드 설정 안내로 이어진다
- [x] **배경이 흰색/회색 가로줄로 갈리던 문제 수정** — `emptyPage`의 위 여백(`pageContentTopMargin`)과
      네비바 자리를 **아무도 안 칠하고 있었다.** 시스템 흰색이 그대로 나오고 그 아래 내용물이 칠한
      테마색과 경계가 생겼다. 비어 있을 때만 보이던 이유도 이것(카드가 있으면 스크롤뷰가 칠한다)
      · `emptyPage`에 `theme.bg.ignoresSafeArea()` — 빈 화면 4종(기본·전체·즐겨찾기·카테고리) 모두 해결
- [x] 시뮬레이터 확인: 새 설치 = 튜토리얼 단독 화면(목록 크롬 없음) / 빈 목록 = 한 색으로 균일
      ⚠️ 시뮬레이터 `cfprefsd`는 앱을 지워도 이전 설정을 들고 있다 — "새 설치" 검증 전에
      `xcrun simctl spawn <D> defaults delete com.Ysoup.TokenMemo` 로 도메인을 지울 것
      (이걸 몰라 첫 검증이 "기존 사용자"로 잘못 판정됐다)
- [x] 전체 스위트 TEST SUCCEEDED · 빌드 그린

## 🧹 그림·영상 걷어내기 (2026-08-06, `feat/dossier-delight`)
> 스킨을 내린 김에 **광부도, 그에 딸린 그림·영상도** 전부 걷었다. 남은 그림은 기능이 실제로 쓰는 것뿐이다.

- [x] **광부 삭제** — `MinerScene.swift`, `miner_idle.mov`(832K), `MineTunnel` 그림(312K).
      쓰이던 5곳(첫 단축어 온보딩·튜토리얼 3화면·붙여넣기 연습·빈 목록)에서 함께 걷어냄
- [x] **지오드 그림 3장 삭제**(596K) — 스킨이 꺼져 있어 아무에게도 안 보이던 그림.
      ⚠️ 생활 레이어를 다시 켤 거면 **그림부터 다시 넣어야 한다**(GeodeSkin.swift 머리말에 표시)
- [x] **한 번도 안 쓰이던 그림 묶음 삭제** — `KeyboardTutorial/use-1~6`(3.0M), `Onboarding/step1~4`(432K).
      코드 어디에서도 참조하지 않았다(예전 화면의 잔해)
- [x] 총 **약 5.2MB** 앱 자산 감소 · 두 타깃 빌드 그린 · 전체 스위트 TEST SUCCEEDED
- [x] 남긴 것: `ListBackground01~08` — 설정 > 배경 이미지가 실제로 쓰는 사진. 지우면 그 기능이 깨진다
- [ ] 광부가 빠진 화면들 여백 확인 필요(첫 온보딩·튜토리얼) — 글만 남아 가운데 정렬된다.
      시뮬레이터 StoreKit 알림이 가운데를 덮어 눈으로 다 못 봤다

## 🎛 첫 화면 고르기 + 스킨 잠시 내려두기 (2026-08-06, `feat/dossier-delight`)
> 첫 화면을 바꾸는 일은 **쓰던 사람의 화면을 바꾸는 일**이다. 그래서 고르게 하고, 권하기만 한다.

- [x] 설정 > **첫 화면** — 단축어 목록 / 키보드 화면 (`SnippetsTabStyle`)
      기본값은 **목록**. 값이 없다는 건 "아직 고른 적 없다"이지 "새 화면을 원한다"가 아니다
- [x] 새 설치만 첫 실행에 키보드 화면을 뿌린다(`seedDefaultSkinForNewInstalls` 안에서 함께)
- [x] 기존 사용자에게 **1회 제안** 알림 — 써볼게요 / 괜찮아요. 다시 묻지 않는다
      ⚠️ 알림을 `ClipKeyboardList` 안에 두지 않았다(뷰 트리 깊이 한계) — 탭 껍데기 `SnippetsTab`에
- [x] **스킨 전부 내려둠** — `KeyboardSkin.isEnabled` / `LivingSkin.isEnabled` = false 하나로.
      설정에서 감추는 것과 화면을 예전으로 되돌리는 것이 **함께** 일어난다
      (고를 수 없는데 남의 화면만 달라져 있으면 "왜 내 것만 이렇지"가 된다)
      · 새 설치에 금고 스킨을 뿌리던 것도 함께 멈춤 · 코드·테스트는 그대로 → 되살릴 땐 값 하나만 true
- [x] 무대에서 **X(전체 삭제)와 카테고리 탭이 처음부터** 보인다(앱 안에서만).
      X는 글이 없을 땐 흐리게+비활성 — 나타났다 사라지면 줄이 흔들리고 "지울 수 있다"를 못 배운다
      카테고리는 탭 노출과 필터가 **같은 값**을 보게 했다(안 그러면 골라도 반응 없는 죽은 탭)
- [x] **튜토리얼의 마지막 걸음 = 진짜 키보드 켜기** — 무대 위 띠 → `KeyboardSetupOnboardingView`.
      익스텐션이 한 번이라도 떴는지(`keyboardExtensionDidLoad`)로 판단, 켜고 돌아오면 띠가 사라진다
- [x] 신규 문자열 10개 ko/en/id · 테스트 7건 추가 · **전체 스위트 TEST SUCCEEDED · 두 타깃 빌드 그린**
- [x] 시뮬레이터 확인: 새 설치=키보드 화면 + 설정 띠 + 카테고리·X 보임 / 기존=목록 유지(제안 1회 실행됨)
- [ ] 제안 알림 **모양**은 못 봤다 — 시뮬레이터 StoreKit 로그인 알림이 항상 위를 덮는다(실기기 확인)
- [ ] 스킨을 다시 켤지 결정 필요 — 지금은 코드만 남아 있고 아무에게도 안 보인다

## ⌨️ 앱 첫 화면 = 키보드 무대 (2026-08-06, `feat/dossier-delight`)
> 이 앱의 값어치는 목록이 아니라 **다른 앱에서 키보드로 꺼내 쓰는 순간**에 있다.
> 그래서 단축어 탭을 **키보드가 실제로 올라온 장면**으로 바꿨다.
> ⚠️ 아래 키보드는 흉내가 아니라 **익스텐션과 같은 `KeyboardView`** — 두 벌로 만들면 하나만 고쳐진다.

- [x] `KeyboardView`를 앱 타깃에서도 쓸 수 있게 파일 7개 멤버십 추가
      (KeyboardView·KeyboardOverlays·TypingKeyboardView·HangulComposer·CheonjiinInput·
       KeyboardBeacon·KeyboardDocumentState) — **심볼 충돌 없음**
- [x] `KeyboardHostKind` (익스텐션 / 앱) — 기본값 `.keyboardExtension` 이라 익스텐션 동작 무변화
- [x] `InAppKeyboardHost` — 익스텐션의 `KeyboardViewController`가 하던 일을 앱에서.
      **삽입 경로를 새로 만들지 않는다**: `KeyboardView`는 그대로 `.addTextEntry` 를 쏘고
      누가 받느냐만 다르다(컨트롤러 ↔ 무대). 템플릿 변수·`{커서}`·콤보 순차 입력 동일 규칙
- [x] `InAppKeyboardStage` — 말풍선 + 입력창 + 키보드. 입력창은 **진짜 TextField가 아니다**
      (탭하면 시스템 키보드가 올라와 무대를 가린다). 캐럿은 깜빡이지 않음 — 상시 타이머 안 둠
- [x] 앱에서만 보이는 **복사 버튼** — 키를 누르면 입력창에, 복사 버튼은 클립보드에.
      보안 문구에는 안 붙인다(PIN 없이 값을 꺼내는 길이 됨)
- [x] `KeyboardMemoFeed` — `clipMemos` 전역과 정렬 규칙을 두 타깃이 공유(컨트롤러도 이걸 부름)
- [x] 목록으로 가는 문 유지 — 무대 오른쪽 위 "목록"(문구를 만들고 고치는 곳은 여전히 거기)
- [x] 키보드 사용 통계(`keyboardPasteCount`·비콘)는 **안 건드림** — 앱에서 눌러 본 건 키보드를 쓴 게 아니다
- [x] 신규 문자열 10개 ko/en/id · 테스트 15건 · **전체 스위트 TEST SUCCEEDED · 두 타깃 빌드 그린**
- [ ] **실기기 확인 필요** — 시뮬레이터에 탭 입력을 넣을 방법이 없어 "카드 탭 → 입력창에 글" 흐름은
      코드·테스트로만 검증됨. 화면 렌더링(말풍선·입력창·키·복사 버튼)은 스크린샷으로 확인
- [ ] 키보드 높이(화면 50%, 260~430pt)가 작은 기기·큰 기기에서 적당한지
- [ ] 무대에 문구를 **만드는** 길이 없다 — 처음 쓰는 사람이 "목록"을 찾아낼지 관찰 필요

## 💎 보석 스킨 (보류 — 2026-08-06)
- ⚠️ 스킨 자체가 지금 다 내려가 있다(위 항목) — 되살린 뒤에 다시 볼 것
- HTML 시안 3안 제시(컷 / 카보숑 / 프리즘), 추천은 **A 컷**. 사용자 판단 대기
- 시안: https://claude.ai/code/artifact/425089ad-9c03-4807-a0cd-cc33080576aa

## 🌱 생활 레이어 — 카드 위에 사는 것 (2026-08-05, `feat/dossier-delight`)
> 물성 스킨(KeyboardSkin)과 **다른 층**. 물성은 손이 느끼는 것, 생활은 눈이 보는 것.
> 겹쳐 쓸 수 있다 — 기계식 키캡 위에 픽셀 마을이 자라도 된다.
> ⚠️ **앱 전용.** 익스텐션은 메모리 상한(~60MB)이라 상시 그림·타이머를 못 얹는다.
> ⚠️ 기본값 `.none` — 업데이트했다고 남의 화면에 새가 날아다니면 안 된다.

- [x] `LivingSkin` — 없음 / 픽셀 마을 / 눈과 발자국 / 새 / 고양이
      **가르는 축은 남는가 vs 흐르는가**(`isPersistent` / `isVisitor`).
      남는 것은 사용 기록에서 그려져 스크린샷에 찍히고 배터리가 0, 흐르는 것은 타이머가 필요
- [x] **픽셀 마을** — 8×8 스프라이트를 **코드 배열로** 그린다(에셋 0, 배율 무관 또렷).
      `clipCount` → 새싹1 / 꽃4 / 나무10 / 집25, 큰 것부터 채워 규모가 한눈에 읽히게.
      한 카드 최대 9개(상한 없으면 그림밭). Canvas 한 장으로 그려 뷰 수를 안 늘림
- [x] **눈과 발자국** — ⚠️ **눈은 안 내린다.** 상시 낙하는 배터리만 먹고 스크린샷엔 안 남는다.
      이 스킨의 값어치는 눈이 아니라 **발자국**(= 남는 것). 눈은 정지 질감, 발자국만 누적.
      좌표는 사용 횟수에서 결정적 계산 — 난수면 스크롤할 때마다 옮겨 다녀 자취로 안 읽힘
- [x] **새·고양이** — ⚠️ 상시 배회 아님. 하루 수십 번 여는 도구에서 뭔가 늘 움직이면
      셋째 날부터 소음이 된다. 90초/70초마다 잠깐 들르는 **손님**으로.
      ⚠️ 격자 전체를 가로지르지 않고 **카드 한 장 위**에서만 — 격자는 스크롤·재정렬돼서
      전역 경로를 쓰면 사라진 발판으로 뛰어내린다. `GuestScheduler`가 호스트 카드만 정함
      ⚠️ 저전력 모드·동작 줄이기·연출 토글 OFF면 스케줄러가 아예 안 돈다
- [x] 설정 > 키보드 레이아웃에 '생활 레이어' 섹션 — 각 행에 결과 미리보기(자란 모습을 보여줌)
- [x] 재정렬(경량) 모드에선 전 레이어 생략 — 회전 카드마다 Canvas가 붙으면 드래그가 무거워짐
- [x] 신규 문자열 13개 ko/en/id · 테스트 20개 추가 · **전체 스위트 TEST SUCCEEDED · 빌드 그린**
- [x] **"골라도 반응이 없다" 3건 수정**
      ① 안 쓴 문구(clipCount 0)에 아무것도 안 그려졌다 → **빈 땅** 스프라이트 추가.
         카드 대부분이 clipCount 0이라 스킨을 켜도 화면이 그대로였다
      ② `.overlay` 로 얹어 눈 베일·발자국이 **제목을 덮고** 있었다 → `.background`(글자 뒤)로
      ③ `keycapSkin` 이 `KeyboardSkin.current`(UserDefaults 직접 읽기)라 **설정을 바꿔도
         화면이 다시 안 그려졌다** → @AppStorage 로 교체. 생활 레이어 변경 시 손님 스케줄러도 재시작
      · 마을을 카드 아래쪽(지면)으로 옮기고 픽셀 2→3pt 로 키움
- [x] **렌더링 테스트 4건** — ImageRenderer 로 뷰를 비트맵으로 구워 픽셀이 실제로 찍혔는지 확인.
      계획(순수 함수)만 맞고 Canvas 경로가 죽는 사고는 기존 테스트로 안 잡힌다
- [ ] 실기기에서 확인: 마을이 카드 제목을 가리지 않는지, 손님 등장 빈도가 적당한지
- [ ] ⚠️ 앱 실행 직후 **붙여넣기 권한 프롬프트**가 뜬다(클립보드 자동 캡처). 시뮬레이터
      스크린샷 검증을 3회 막았고, 신규 사용자가 앱에서 보는 첫 화면이 권한 다이얼로그다
- [ ] 스프라이트 다크 모드 검토 — 현재 팔레트는 테마 무관 고정(픽셀 아트는 색 대비로 형태를 만듦)

## ↩️ 되돌릴 길 + 기본값 전환 (2026-08-05)
- [x] **기본값을 `classic`(예전 모습)으로** — 키캡은 취향이 갈리는 변화라 기본을 예전에 두고
      원하는 사람만 켜게 한다. 쓰던 사람 화면이 업데이트로 멋대로 바뀌지 않는 쪽이 항상 옳다
      · `standard` 는 '키캡' 으로 이름 변경(도톰한 선택지), `classic` 이 '기본'
      · 저장값 없음/깨짐/모르는 값 → 전부 `classic` 으로 폴백(테스트로 고정)
- [x] **생활 레이어를 제자리로** — 목록 화면 이야기인데 '키보드 레이아웃' 안에 있었다.
      `LivingSkinSettings` 신설 → **설정 > 디스플레이 > 생활 레이어**.
      키보드 설정을 열어야 목록 꾸밈을 바꿀 수 있는 건 앞뒤가 안 맞는다
      (키캡 스킨은 키보드 레이아웃에 그대로 — 거긴 실시간 키보드 미리보기가 있어 판단하기 좋다)
- [x] `KeyboardSkin.classic` **'예전 방식'** 추가 — 키캡 작업 이전(4.4.3) 모습 그대로.
      두께 0 · 표면광 0 · 그림자 0.08(예전 값) · 모서리 테마 값 그대로.
      ⚠️ 이 케이스의 값은 바꾸지 말 것 — "예전 그대로"라는 약속이 존재 이유다(테스트로 고정)
- [x] **푹신한 바운스 복원** — 키캡으로 바꾸면서 사라졌던 scaleEffect 0.92→1.05→1.0 을
      `CardPressEffect` 안에 남겨 두고, **두께가 0인 스킨에서 자동으로 되살린다**.
      그러지 않으면 납작/예전 방식에서 눌러도 반응 없는 죽은 카드가 된다
- [x] 되돌릴 수 있는 항목 정리 — 물성(스킨 5종) · 생활 레이어(기본 없음) · 입력 반응 토글 ·
      커스텀 색 · 구분 표시 · 설정의 '기본값으로 되돌리기'가 두 스킨을 모두 초기화

## ⌨️ 키캡 스킨 + 또깍거리는 손맛 (2026-08-05, `feat/dossier-delight`)
- [x] **키캡 스커트** — 키 아래로 삐져나온 옆면을 깔고, 누르면 그 위로 내려앉아 가려진다.
      두께(skirtDepth)와 눌림 거리(travel)가 **같은 값**이라 바닥에 딱 닿는다. 이 한 겹이 "또깍"의 정체
      내려갈 땐 즉각(0.03~0.09s), 올라올 땐 스프링 — 양방향을 같은 커브로 두면 물컹해진다
- [x] **시스템 키 클릭음** — `UIDevice.playInputClick()`.
      ⚠️ 커스텀 사운드 파일이 아니다. 재생 여부를 iOS가 **사용자의 설정 > 사운드 > 키보드 클릭음**으로
      결정하므로, 꺼 둔 사람에겐 아무 일도 안 일어난다(회의 중 우리 앱만 떠드는 사태가 구조적으로 불가능)
      ⚠️ `UIInputViewAudioFeedback` 채택 필수 — 안 하면 호출이 **조용히 무시**된다
- [x] **`KeyboardSkin`** 신설(앱·익스텐션 두 타겟) — 기본 / 기계식 / 납작 / 말랑
      ⚠️ 스킨은 **색을 정하지 않는다.** 색은 테마(Paper/Dusk)와 커스텀 키 색이 이미 담당한다.
      스킨까지 색을 잡으면 셋이 서로 덮어쓰며 싸우고 "왜 내가 고른 색이 안 나오지"가 된다.
      스킨이 정하는 건 두께·빛·모서리·눌림뿐 → 어떤 스킨을 골라도 고른 색이 그대로 유지된다
      ⚠️ 기본값은 `.standard` = 지금까지의 생김새. 업데이트로 남의 키보드가 바뀌면 안 된다(테스트로 고정)
- [x] 설정 > 키보드 레이아웃에 스킨 선택 섹션 — 각 행에 **눌러지는 키캡 미리보기**(설명 대신 만져보게)
- [x] 상단 실시간 미리보기(`KeyboardPreviewView`)에도 스킨 반영 — 미리보기가 실물과 다르면 고르고 나서 배신감
- [x] `typeBorder` **세 번째 사본** 제거 — 앱 카드·키보드 키·설정 미리보기가 이제 MemoTypeStyle 하나를 본다
- [x] 신규 문자열 9개 ko/en/id · 테스트 10개 추가 · **전체 스위트 TEST SUCCEEDED · 빌드 그린**
- [ ] 실기기에서 스커트 두께·클릭음 확인 (시뮬레이터는 햅틱·클릭음 모두 안 남)
- [x] 콤보 분할 버튼 = **통짜 키캡 하나** — 좌·우 어디를 눌러도 한 덩어리로 내려앉는다.
      두 버튼이 각자 내려앉으면 한 덩어리가 반으로 쪼개져 보임 → `KeycapPressReporter`가
      눌림 사실만 부모로 올리고, 부모가 `KeycapSurface`로 통째로 그린다
      가운데 Divider → 옅은 홈(divider 0.6, 높이 42%)으로 — '틈'이 아니라 '파인 홈'으로 읽히게
- [x] 키캡 장식을 `KeycapSurface` 하나로 통합(개별 키·콤보 키가 같은 규칙)
- [x] **중복 햅틱 제거** — 누를 때 tap + 삽입 때 stamp 로 한 번 눌렀는데 두 번 울리던 것.
      각 종착지(일반 삽입 stamp / 이미지 복사 완료 / 보안 인증 UI)가 자기 피드백을 갖는다

## ⌨️ 키보드 기본기 5종 (2026-08-05, `feat/dossier-delight` 브랜치)
> 기능 티어 체크리스트(L0~L4) 대조 결과 비어 있던 3개 + 리스크 2개를 메움.

- [x] **`{clipboard}` / `{클립보드}` 토큰** — 클립보드 히스토리와 템플릿 엔진이 있는데 둘을 잇는 토큰만 없었음.
      ⚠️ **토큰이 있을 때만** `UIPasteboard`를 읽는다(`containsClipboardToken`) — 무조건 읽으면
      iOS 16+ 붙여넣기 프롬프트가 아무 이유 없이 뜬다. 값이 없으면 토큰을 지운다(빈칸 > 토큰 노출)
- [x] **`{커서}` / `{cursor}` 토큰** — 삽입 후 캐럿을 빈칸으로 보낸다. `resolveCursor`가 순수 함수라 테스트 가능.
      ⚠️ `process(keepCursorToken:)` **기본값 false(제거)** — 캐럿을 못 옮기는 경로(클립보드 복사·미리보기·
      콤보 중간 단계)에서 토큰이 살면 "{커서}"가 그대로 붙여넣어진다. 키보드만 true로 연다
      ⚠️ 콤보는 **마지막 단계에서만** 커서를 반영 — 중간에 옮기면 다음 단계가 엉뚱한 자리에 들어감
      ⚠️ 네 토큰 모두 `autoVariableTokens`에 등록 필수 — 아니면 누를 때마다 "값을 입력하세요" 폼이 뜬다(테스트로 고정)
- [x] **Full Access 런타임 감지** — `KeyboardCapability`(익스텐션 전역). 지금까지 익스텐션이 진짜 권한을
      **한 번도 확인하지 않고** 있었음. 코드의 `ProFeatureManager.hasFullAccess`는 Pro 결제 판정이라 무관 —
      이름이 비슷해서 생긴 착시. 미허용 시 클립보드 복사·`{clipboard}`가 조용히 실패하던 것을 토스트로 안내
- [x] **`PasteButton`** — 대량 가져오기의 "클립보드에서 붙여넣기"를 시스템 버튼으로 교체 → 프롬프트 제거.
      ⚠️ 스마트 클립보드 **자동 캡처 경로는 그대로 둠** — PasteButton으로 바꾸면 자동 캡처가 사라진다
- [x] **다음 키보드(지구본) 복구** — UIKit 버튼이 SwiftUI 호스팅 뷰에 가려 안 보여서 아예 숨겨져 있었음.
      `categoryTabRow` 왼쪽에 고정 배치, `needsInputModeSwitchKey`일 때만 표시(심사 요건)
- [x] 토큰 바에 "복사한 것"·"커서" 버튼 추가 — 없으면 사용자가 존재 자체를 모름
- [x] 신규 문자열 6개 ko/en/id · 테스트 19개 추가 · **전체 스위트 TEST SUCCEEDED · 빌드 그린**
- [ ] 실기기에서 커서 이동 확인 — 이모지가 토큰 **뒤에** 오면 `adjustTextPosition`의 문자 단위와
      어긋날 수 있음(한글·영문은 일치). 알려진 한계로 주석에 기록함
- [ ] 사용 가이드/튜토리얼에 새 토큰 2종 설명 추가

## 🔖 DOSSIER delight 레이어 (2026-08-04, `feat/dossier-delight` 브랜치)
> 컨셉: "나에 관한 건, 두 번 치지 않는다" — 클립보드 앱이 아니라 **개인 신원·말투 서류철**.
> 인앱은 Native Neutral 유지(AppTheme 토큰만 사용). 여권/지폐 무드는 마케팅 표면 전용.
> 시안: 컨셉 보드 + delight 동작 데모(HTML)를 먼저 만들고 확정 후 구현.

- [x] `Delight`(DelightMotion.swift) — **모션 예산 단일 출처**. 연출은 빈도의 역수로 배분한다:
      매일(0.18s·무음) / 가끔(0.42s) / 한 번(0.90s). reduce-motion·사용자 토글 모두 존중.
      동작별 햅틱 래퍼(stamp/filed/verified/rejected/sealed/unsealed) — 세기가 아니라 동작으로 부른다
- [x] **날인** — 입력 순간 햅틱을 `UINotificationFeedbackGenerator(.success)` → `KeyboardHaptics.stamp()`(medium 1회)로 교체(4곳).
      알림 패턴은 두세 번 울리는 느낌이라 하루 수십 번 반복엔 과했음. `KeycapButtonStyle`로 문구 버튼이 실제로 눌림(2pt↓)
- [x] **잉크 농도** — `clipCount`를 숫자 배지가 아니라 자국 농도로(`Delight.inkOpacity`, 100회에서 상한 0.5).
      `MemoRowView`에 `StampMark` 추가 — **showVisualCues 게이트 준수**(기본 OFF). VoiceOver엔 숫자로 읽어 줌
- [x] **검증 각인** — `ChecksumVerifier` 신설(IBAN mod-97 / 카드 Luhn / 사업자등록번호).
      ⚠️ 핵심 규약: **확실할 때만 말한다.** 형식이 명백할 때만 실패를 단언하고, 모호하면 성공만 말하고 침묵(nil).
      붙여 쓴 16자리는 계좌번호일 수 있어 통과 시에만 표시. 분류 로직은 건드리지 않음(표시 전용 API)
      ⚠️ 실패 햅틱 없음 — 입력 중 미완성 값에 진동을 붙이면 타이핑 내내 손을 때리는 꼴
- [x] **비자 페이지** — `UsagePassport`(순수 집계) + `UsagePassportView`. 설정 > 디스플레이 > 사용 기록.
      새로 수집하는 것 0 (`clipCount`/`lastUsedAt`/`KeyboardUsageTracker` 재사용). **보안 문구는 제목도 노출 안 함**
- [x] **봉인** — `WaxSealView`. 리스트의 자물쇠 아이콘을 봉랍으로 교체, 보안 설정/해제에 rigid/soft 햅틱 + 토스트 문구 교체
- [x] 설정 > 디스플레이에 **입력 반응** 마스터 토글(App Group — 키보드 익스텐션도 같은 키를 읽음)
- [x] 신규 파일 7개 pbxproj 수동 등록(메인 앱 그룹은 동기화 그룹이 아님) + `plutil -lint` 통과
- [x] 신규 문자열 29개 ko/en/id 추가 · `check_localization.py` 통과
- [x] 테스트 27개 추가(ChecksumVerifierTests 14 / UsagePassportTests 13) · **전체 스위트 TEST SUCCEEDED · 빌드 그린**
- [ ] 실기기에서 햅틱 세기·키캡 프레스 체감 확인 (시뮬레이터는 햅틱이 안 옴)
- [ ] 온보딩 "발급 절차" 재설계 — delight 6번째 항목. 유일하게 **키보드 활성화율 지표를 직접 움직이는** 작업이라 별도 진행
- [ ] 마케팅 표면(스토어 프로모션 텍스트·스크린샷 6컷·랜딩 히어로)에 DOSSIER 무드 반영 — 코드와 무관, 먼저 가능

## 📈 사용 통계를 FeedbackHub로 (2026-07-30, 커밋 대기)
- [x] `UsageReportingService` 신설 — 피드백과 **같은 컨테이너**(iCloud.com.Ysoup.FeedbackHub)로 익명 통계 전송. 엔진은 LeeoKit `LeeoUsageReporter`(v2.6.0에 이미 포함, 패키지 버전 그대로)
  - `UsageSnapshot`: 설치당 1건 upsert(12h 쓰로틀) → **사용 인원(설치 수)·7/30일 활성** 집계
  - `UsageEvent`: 주요 행동 스트림, **이름당 6h 쓰로틀** → **앱 사용 내용**
  - `metrics`: shortcuts/combos/templates/images/favorites/uses/timeSavedMin/keyboardUses + flag.isPro·flag.keyboardActive·flag.syncOn + persona.*
- [x] `AnalyticsService.eventSink` 훅 — 기존 14개 이벤트 호출부를 그대로 재사용(`paywall_view:memo` 처럼 슬라이스 한 조각만 덧붙임).
      ⚠️ AnalyticsService는 키보드 익스텐션 타겟에도 포함돼 LeeoKit 직접 참조 금지 → 메인 앱이 런치 시 훅을 꽂는 방식
- [x] 키보드 비콘 누적 카운터 `kb.beacon.totalCount` 추가 (flush 때 합산) — 키보드만 쓰는 사용자도 지표에 반영
- [x] `UsageStatsView` (설정 > 지원 > **사용 통계**, 마스터 모드 전용) — 허브에서 실제로 읽어와 표시:
      사용자/활성/신규 · 이벤트별 건수·설치 수 · 설치당 평균 지표 · Pro·키보드·동기화 비율 · 버전/플랫폼 분포 · 피드백 건수 + 인박스 링크
- [x] **기간별 추이 차트** (`UsageTrendChartView`, Swift Charts) — 일간/주간/월간/연간 전환 + 좌우 스크롤로 그 단위만큼 과거 이동(묶음 경계 스냅). 표시값 3종: 활동한 사용자 / 사용 건수 / 신규 사용자. 보이는 구간 합계·기간 라벨 표시
  - `trend(unit:events:snapshots:)`가 빈 구간까지 채워 차트가 끊기지 않게 함 (Calendar 주입 가능 → 테스트 가능)
  - 이벤트 조회는 CloudKit 커서로 최대 3,000건까지 이어 받음(단일 요청 상한 회피)
  - **`app_open` 이벤트(20시간 쓰로틀)** 추가 — 스냅샷 lastActiveAt은 덮어쓰기라 날짜별 이력이 없어서, 일간 활성 사용자가 실제 접속을 반영하도록
- [x] ~~옵트아웃 토글~~ **제거** — 사용자가 끌 수 없게(항상 수집). 설정 토글·`usageReportingEnabled` 키·관련 문자열 전부 삭제
  - ⚠️ 심사 5.1.1(ii)/GDPR 지적 여지 있는 선택 — 리젝 시 토글 복구가 가장 빠른 해법(문서에 기록)
- [x] 신규 문자열 51개 ko/en/id 추가(토글 문구 2개는 제거), `check_localization.py` 통과
- [x] 테스트 14개 추가(쓰로틀(기본/커스텀)·지표 키/PII 없음·훅 규약·이름별 집계·일/주/월/연 버킷팅·빈 구간 채움) · 전체 스위트 TEST SUCCEEDED · 빌드 그린
- [ ] ⚠️ **CloudKit Dashboard 선행 작업**: FeedbackHub에 `UsageSnapshot`·`UsageEvent` 스키마 생성 → 인덱스(recordName Queryable, UsageEvent는 createdTimestamp Sortable) → admin read 권한 → **Production 배포**. 절차: `docs/USAGE_STATS_HUB.md`
- [ ] ⚠️ App Store **App Privacy** 갱신 필요(Usage Data / Product Interaction, 사용자와 미연결·추적 아님) + "외부로 아무 통계도 보내지 않음" 문구가 있는 릴리즈 노트·개인정보 처리방침 수정
- [ ] 실기기에서 스냅샷 1건 올라가는지 → 통계 화면에서 카운트·차트 보이는지 확인 (차트는 유닛 테스트·빌드까지만 검증, 실데이터 렌더링 미확인 — Xcode 캔버스용 `UsageTrendChartView_Previews` 있음)

## 🔖 버전 4.4.3 (2026-07-30, 커밋 대기)
- [x] iOS `Version.xcconfig` 4.4.2(1) → **4.4.3(1)** — 4.4.2는 미출시(커밋 전)라 그대로 4.4.3으로 올림
- [x] `CLAUDE.md` 현재 버전 4.4.0 → 4.4.3 (오래 방치돼 있던 값)
- [x] iOS 릴리즈 노트 `RELEASE_NOTES_4.4.2.md` → `RELEASE_NOTES_4.4.3.md` 이름·제목 변경
- [ ] 릴리즈 노트에 "익명 사용 통계 수집 시작" 문구 추가 여부 결정 (수집 사실 고지 — App Privacy 갱신과 세트)
- [ ] 맥 `Version.xcconfig`도 4.4.3으로 맞출지 (맥 빌드번호는 절대 리셋 금지, 전역 단조 증가)

## 🔖 iOS·맥 둘 다 4.4.2로 (2026-07-29, 커밋 대기 — 4.4.3으로 대체됨)
- [x] iOS `Version.xcconfig` 4.4.1(1) → **4.4.2(1)** — 마케팅 버전 올릴 때 빌드번호 1로 시작하는 기존 관례 유지
- [x] 맥 `Version.xcconfig` 4.4.1(11) → **4.4.2(12)** — (1)로 리셋했다가 업로드 거절됨: **macOS 는 마케팅 버전과 무관하게 빌드번호가 전역 단조 증가**해야 한다(iOS 는 버전 트레인별 리셋 허용). 맥 README 배포 섹션에 경고 추가
- [x] 빌드 산출물 Info.plist 로 확인: iOS 4.4.2(1) / 맥 4.4.2(12)
- [x] 맥 릴리즈 노트 `RELEASE_NOTES_4.4.1_macOS.md` → `RELEASE_NOTES_4.4.2_macOS.md` 로 이름·제목 변경(내용은 이번 릴리즈 그대로)
- [x] iOS 릴리즈 노트 병합 — 미출시 4.4.1 내용(여러 값 단축어·키보드 2/3 분할·이미지+값·새 단축어 화면)을 `docs/RELEASE_NOTES_4.4.2.md` 로 옮기고, 이번에 고친 기기 간 동기화(베타) 항목 추가. 낡은 `RELEASE_NOTES_4.4.1.md` 는 삭제(git 이력에 남음)

## 🗂 맥 카테고리 구분 + 하위호환 (2026-07-29, 커밋 대기)
- [x] `MacCategoryStore` 신설 — iOS `CategoryStore` 와 **같은 App Group 키**(userDefinedCategories_v1 / hiddenCategoryTabs_v1 / userCategoryIcons_v1 / category.feature.enabled.v1)를 읽어 순서·숨김 규칙 공유
- [x] 메인 창: 카테고리 필터 Picker 를 스토어 기반으로 교체(전체 센티넬 `__all__` 로 "전체"라는 사용자 카테고리와의 충돌 제거, 선택 값이 사라지면 전체로 복귀)
- [x] 메뉴바 팝오버: 카테고리 칩 필터 추가(카테고리를 쓸 때만 노출)
- [x] 단축어 추가 화면: 자유 입력 → **카테고리 선택기 + "새 카테고리…" 시트**(만들면 iOS 와 같은 목록에 등록)
- [x] **하위호환 1** — 목록에 등록 안 된 "고아" 카테고리(메모에만 있는 값)를 필터·선택기에 항상 포함. 어떤 경우에도 메모의 `category` 값을 고쳐 쓰지 않음
- [x] **하위호환 2** — 1회 마이그레이션(append 전용): 기존 메모가 쓰던 카테고리를 목록에 등록 + 비-기본 카테고리 사용 시 카테고리 기능 자동 활성(iOS `migrateFeatureEnabledIfNeeded` 와 동일 규칙)
- [x] **하위호환 3** — 맥 `MemoStore` 에도 **카테고리 사이드카**(`memoCategoryAssignments_v1`) 도입: 저장 시 기록, 로드 시 유실분 복원·치유. iOS 와 키·규칙 동일(한쪽만 있으면 서로의 카테고리를 되돌릴 위험)
- [x] 라운드트립 검증 통과 — iOS 인코딩 → 맥 디코드 → 맥 재인코딩 → iOS 검증(전 필드 + 레거시 키 + OldMemo 폴백)
- [x] `scripts/roundtrip/run_roundtrip_test.sh` 경로 수정 — 맥 리포 분리 후 깨져 있던 것(`MAC_REPO` 환경변수) + 공유 상수 함께 컴파일
- [ ] 맥에는 카테고리 **관리**(이름변경·삭제·순서·숨김)가 없음 — iOS 카테고리 관리 화면이 정본. 필요하면 맥에도 추가 검토

## 🔌 iOS→맥 동기화 미작동 원인 4개 수정 (2026-07-29, 커밋 대기)
- [x] **Pro 게이트**: 공유 `MemoSyncEngine.isProUser` 가 결제 키만 봐서, 그랜드파더/TestFlight/체험 사용자는 **토글이 켜져 있어도 엔진이 조용히 거부** → `wasProAtV3`·`existingFreeUser`·신규 `syncEntitled` 도 인정. iOS 는 `ProFeatureManager.mirrorSyncEntitlement()`(hasFullAccess 미러링)를 앱 시작·포그라운드 복귀 때 호출
- [x] **전송 확정 전 섀도 갱신**: `enqueueLocalChanges` 가 큐에 넣자마자 섀도를 "보냄"으로 기록 → 전송 전 종료 시 그 변경이 영영 재전송 안 됨. `confirmSent`(sentRecordZoneChanges) 에서만 섀도 기록하도록 수정 — 실제로 맥이 이 상태에 빠져 있었음(shadow 4건, lastPushAt 없음)
- [x] **존 생성 실패가 안 보이던 구멍**: `.sentDatabaseChanges.failedZoneSaves` 오류 기록 추가 — Production 스키마 미배포 등 "아무것도 못 올리는" 원인이 상태 화면에 표시됨
- [x] **CloudKit 환경 불일치**: 맥 엔타이틀먼트의 `icloud-container-environment = Production` 고정 제거 → iOS 와 동일하게 빌드 방식을 따름(Xcode=Development, 스토어=Production). 상태 화면에 현재 환경 행 추가(`CloudKitEnvironment.current`, 엔타이틀먼트 직접 조회)
- [x] 맥 예시 시드가 클라우드로 업로드돼 아이폰을 오염시키던 문제 — 동기화 켜져 있으면 시드 생략
- [x] iOS 테스트 402개 통과 / 맥 빌드 성공 / drift-check 일치
- [ ] ⚠️ **아이폰·맥 빌드 방식을 맞출 것** — 한쪽이 App Store·TestFlight(Production)면 다른 쪽도 그래야 함. Xcode 설치본끼리면 Development 로 만남
- [ ] Production 으로 테스트할 경우 CloudKit Dashboard 에서 `MemosZone`/`Memo` 스키마 배포 여부 확인

## 🚨 iOS 실행 즉시 크래시 수정 + 저장 경로 점검 (2026-07-29, 커밋 대기)
- [x] **런치 크래시**: `ClipKeyboardSpec.paywall` 를 비옵셔널로 선언 → `LeeoAppSpec` 요구(`LeeoPaywallConfig?`)의 witness 가 못 돼 기본값 `nil` 이 쓰였고, `StoreManager.init` 의 `ClipKeyboardSpec.paywall!` 가 nil 강제 언랩 → `@StateObject StoreManager.shared` 생성 시점에 앱 사망. 타입을 `LeeoPaywallConfig?` 로 명시해 수정
- [x] 로컬 LeeoKit 이 origin/main 보다 3커밋 뒤쳐져 `LeeoPaywallConfig` 자체가 없어 **clean 빌드 불가** 였음 → `git pull --ff-only` 로 f8e81c3 까지 동기화(로컬 전용 커밋 없었음)
- [x] iOS 프로젝트도 LeeoKit 을 **원격 SPM**(`github.com/M1zz/LeeoKit.git`, upToNextMajor 2.6.0)으로 전환 — Xcode "Missing package product 'LeeoKit'" 해소, 맥 프로젝트와 같은 버전으로 통일. `Package.resolved`(신규) 커밋 필요
- [x] 전체 테스트 402개 통과(ko 로케일) — 저장 경로(MemoStore/라운드트립/타임머신/동기화 코어) 34개 포함
- [ ] ⚠️ `CloudKitBackupServiceTests` 2개는 **로케일 의존** — 한글 문구를 assert 해서 영어 시뮬레이터에선 실패(`-testLanguage ko` 로는 통과). 테스트를 로케일 독립적으로 고칠 것
- [ ] 동기화 업로드 경로 위험: `enqueueLocalChanges` 가 전송 확정 전에 shadow 를 갱신 → 첫 전송 전에 앱이 죽으면 그 변경은 메모를 다시 고칠 때까지 영영 재전송 안 됨
- [ ] 맥 첫 실행 시드 예시 4개가 동기화 켜져 있으면 클라우드로 업로드돼 아이폰까지 오염 — 시드 조건에 `MemoSyncFlags.enabled` 제외 검토

## 🖥️ 맥 동기화 상태 화면 + 맥=Pro (2026-07-29, 커밋 대기) — 맥 리포 `~/Documents/workspace/code/ClipKeyboardMac`
- [x] 공유 코드에 `MemoSyncStatus` 추가 — 마지막 수신/전송/확인 시각·건수·오류를 App Group에 기록 (iOS `Service/MemoSyncEngine.swift` 원본 + `DefaultsKey` 키 7개)
- [x] 맥 `SyncStatusView` 신설 — 결론 배너 + 근거 9행(Pro·iCloud 계정·엔진·클라우드 개수·아직 안 받은 것·마지막 수신/전송/확인·로컬 개수) + 동기화 스위치 + "지금 동기화"
- [x] 3분기 판정 `SyncCloudPeek` — 클라우드 존을 직접 조회(토큰 없이, desiredKeys=lastEdited/deletedAt로 경량)해 **가져올 게 없음 / 다 받음 / N개 아직 안 옴**을 구분. 로컬 툼스톤 반영(이미 지운 건 "받을 것"에서 제외)
- [x] "왜 아이폰 데이터가 안 보이지" 안내 — 맥은 아이폰과 다른 기기라 자동으로 안 넘어옴을 사용자에게 설명
  - 상태 화면 "이제 뭘 하면 되나요?" 카드(상태별 할 일 + 맥/아이폰 각각 할 일 + 버튼: 동기화 켜기·iCloud 설정 열기·지금 동기화·백업에서 가져오기)
  - 메인 목록/메뉴바 팝오버 빈 상태에 "아이폰 단축어 가져오기" 진입점, 목록 상단 안내 배너
  - `MacSampleSeeder.containsOnlySamples` — 첫 실행 예시만 있는 상태를 구분해 "이건 예시입니다" 명시(시드 ID 기록)
  - `MacFirstRun.restoreOutcome` — 자동 복원이 조용히 실패하던 4가지 경우(백업없음/미로그인/실패/로컬있음)를 기록해 화면에 이유 표시
- [x] 맥 피드백 UI 먹통 수정 — `LeeoSupportSection`은 NavigationLink 기반인데 환경설정에 NavigationStack이 없어 "피드백 보내기"·"접수된 피드백"이 눌러도 반응 없었음 → generalTab을 NavigationStack으로 감쌈
- [x] 진입점: 메뉴 ⌃⇧Y · 메뉴바 우클릭 (WindowManager `sync-status` 창) / 환경설정 **Pro 탭은 버튼 없이 상태를 인라인 표시**(`SyncStatusView(scrolls: false)` — 창/인라인 겸용, 로직 중복 없음)
- [x] 맥 = Pro: `MacProManager.isPro = true` (유료 앱, 과거 무료 다운로드도 그랜드파더) + 실행 시 **App Group에만** proStatus 기록 → 공유 동기화 엔진 게이트 통과. ⚠️ iCloud KV엔 쓰지 않음(아이폰까지 Pro 풀림 방지)
- [x] 환경설정 Pro 탭을 "포함된 기능" 안내로 교체(무료 플랜/업그레이드 유도 제거), 아이폰 Pro는 별도라고 명시
- [x] String Catalog 41개 키 ko/en 추가, 맥 4.4.1(빌드11) 확인, `docs/RELEASE_NOTES_4.4.1_macOS.md` 작성
- [x] stale 경로 수정: `scripts/shared_files.sh` IOS_REPO → `~/Documents/workspace/code/ClipKeyboard` (드리프트 가드가 조용히 건너뛰던 문제)
- [x] 빌드: 맥(서명 제외) · iOS 시뮬 모두 성공 / drift-check 7개 일치
- [ ] ⚠️ 맥 서명 빌드는 프로비저닝 프로파일에 `iCloud.com.Ysoup.FeedbackHub` 컨테이너가 없어 실패 (기존 문제 — 개발자 계정에서 프로파일 갱신 필요)
- [x] LeeoKit을 로컬 경로(`../LeeoKit`) → **원격 SPM**(`github.com/M1zz/LeeoKit.git`, upToNextMajor 2.6.0)으로 전환 — Xcode "Missing package product 'LeeoKit'" 해소, 2.6.0 resolve + 빌드 성공
- [ ] `Package.resolved`(신규 파일) 커밋 필요 — 버전 고정본. 앞으로 LeeoKit 수정은 **push + 태그**해야 맥 앱에 반영됨
- [ ] iOS 프로젝트는 여전히 로컬 `../LeeoKit` 참조 — 맥(2.6.0)과 버전이 갈릴 수 있음, 원격 전환할지 결정 필요
- [ ] ⚠️ **피드백 전송/인박스는 프로비저닝 프로파일 갱신 전까진 런타임에서도 실패** — App ID에 `iCloud.com.Ysoup.FeedbackHub` 컨테이너 추가 후 프로파일 재발급 필요(개발자 포털 작업)
- [ ] 기기 확인: 아이폰·맥 모두 동기화 켜기 → 아이폰에서 단축어 수정 → 맥 상태 화면 "받고 있어요" + 마지막 수신 갱신

## 📂 빈 카테고리 탭 스와이프 이동 + 4.4.0 빌드7 (2026-07-22, 커밋 대기)
- [x] 카테고리 관리에서 토글 켠 사용자 카테고리는 **메모가 없어도** 탭 노출(스와이프 이동 가능) — `allCategoryTabs`에서 메모 ≥1 조건 제거 (빈 상태 화면·추가 카드는 기존 것 그대로)
- [x] 버전: Version.xcconfig 빌드번호 6→7 (마케팅 4.4.0 유지)
- [x] stale 고아 `Config/Version.xcconfig`(4.3.4/5) 삭제 — 정본은 root Version.xcconfig 단일 소스

## 🐛 피드백 완료 처리 "WRITE not permitted" 수정 (2026-07-22, LeeoKit 커밋 대기)
- [x] 원인: 완료 처리가 공개 DB의 **남이 만든 레코드**에 `status="done"` 서버 저장 시도 → permissionFailure(WRITE not permitted)
- [x] B안: 완료 상태를 **이 기기 로컬(UserDefaults)** 에 저장 — `LeeoFeedbackService.setDoneLocal/isDoneLocally/loadLocalDoneIDs`, `fetchAll`에서 오버레이(레거시 서버 done 1회 흡수 후 로컬 단일 소스)
- [x] `LeeoFeedbackInboxView.toggleDone` 서버 호출 제거 → 로컬 저장(에러 경로 없음), 안내 문구/카탈로그(ko/en/id/ja) 갱신
- [x] `swift build` (LeeoKit 패키지) 통과 — 실제 타입 검증
- [ ] ⚠️ 이 수정은 **LeeoKit 저장소(/Users/leeo/.../LeeoKit)** 에 있음 — 별도 커밋 필요. 앱은 로컬 패키지 참조라 앱 코드 변경 없음
- [ ] 기기 확인: 인박스에서 완료 표시/해제 → 에러 없이 반영, 앱 재실행 후에도 유지 / 삭제는 여전히 admin 쓰기 권한 필요(별개)

## ⌨️ 키보드 검색 한글 조합 깨짐 수정 (2026-07-22, 커밋 대기) — 피드백 반영
- [x] 원인: 키보드 익스텐션 검색 미니 키보드가 자모를 조합 없이 `searchQuery.append` → "인사"가 "ㅇㅣㄴㅅㅏ"로 깨짐
- [x] 수정: 기존 `HangulComposer`(2벌식 오토마타)를 검색 문자열용 `HangulSearchController`로 재사용 — 모든 검색 키 입력을 조합기로 라우팅(자모→음절 결합, 영문/공백은 확정 후 삽입), 백스페이스/언어전환/초기화 3곳도 조합기 경유
- [x] syntax parse 통과 + 조합 로직 수기 추적 검증
- [ ] 기기 확인: 키보드 검색에서 "한" 모드로 한글 입력 → 음절 정상 조합 + 검색 매칭 / 백스페이스 단계별 되돌림 / EN↔한 전환

## 🖥️ 맥에서도 단축어 순서 바꾸기 (2026-07-22, 커밋 대기) — 피드백 반영
- [x] 공유 헬퍼 `MacMemoOrder`(Models.swift) — App Group `memoManualOrder_v1` 읽기/쓰기, iOS `sortMemos`/`commitReorder`와 동일 규칙
- [x] 세 화면 모두 iOS 수동 순서 반영: 메뉴바 팝오버·⌃⌥K 플로팅 패널·메인 창(`MemoListView`)
- [x] 메인 창 `MemoListView`에 드래그 순서 변경(`.onMove`) + 안내 문구 — 바꾼 순서는 App Group 통해 iOS·키보드까지 공유
- [ ] ⚠️ 빌드 검증 대기: 이 환경엔 `../LeeoKit` 로컬 패키지가 없어 full build 불가 → syntax parse만 통과. Xcode에서 macOS 타겟 빌드/실행 확인 필요
- [ ] 기기 확인: 아이폰에서 순서 변경 → 맥 세 화면 반영 / 맥에서 드래그 → 아이폰·키보드 반영

## 🌐 랜딩페이지 전면 개편 (2026-07-17, 커밋 대기)
- [x] docs/index.html 싹 개편 — 페르소나 템플릿 라이브러리 중심
  - 앱 PersonaGuideData.swift에서 스토리 자동 추출(ko/en × 4페르소나 × 10개) → JS 렌더링
  - 각 카드: 공감 pain → 템플릿(변수 칩 + **복사 버튼**) → "이렇게 달라져요" — 다운로드 전부터 유용한 페이지
  - 용어 동기화: 단축어/Snippet 체계 반영 (히어로·설명·가격 카드)
  - "단축어가 뭐예요?" 3단 설명 섹션 신설, 기존 노마드 단일 타깃 → 4페르소나로 확장
  - KO/EN 토글·가격(₩17,000/$9.99)·프라이버시·푸터 유지, 정적 검증(JSON/태그/JS 문법) 통과
- [ ] tutorial.html 용어 동기화 ("메모" 84회) — 별도 작업 필요

## ✨ UX 폴리시 (2026-07-16)

### Liquid Glass 마지막 차단막 제거 (커밋 대기) — iOS 빌드 통과
- [x] ThemedNavTitleModifier(전역 UINavigationBar.appearance 폰트 오버라이드) 완전 삭제
      — iOS 26에선 커스텀 appearance 객체 설정만으로 해당 바가 시스템 glass에서 제외됨(불투명해 보이던 진짜 원인)
      — 트레이드오프: Paper 테마 네비바 Fraunces 서체 포기(시스템 서체), 콘텐츠 내 serif 텍스트는 무관
- [ ] 기기에서 확인: 네비바(맨 위 투명→스크롤 시 glass), 탭바 pill 뒤로 콘텐츠 굴절

### 용어 전면 재통일 (커밋 대기) — iOS·macOS 빌드 통과, 시뮬 확인
- [x] 저장 항목(키-밸류) = **단축어** (en/id: Snippet) — 복합어 포함 전부 (보안 단축어, 단축어 구분 표시 등)
- [x] 미분류 빠른 캡처 = **메모** (en: Note, id: Catatan) — "빠른 메모"에서 "빠른" 제거, 보관함·제어센터·공유시트·Siri 포함
- [x] 카탈로그 179개 키 리네임 + 값(ko/en/id) 교체, 코드 48개 파일(.tap 포함) 키 동기화
- [x] ⚠️ ComboItemType rawValue "메모"는 저장 데이터라 동결 — localizedName switch로 표시만 분리 (iOS+.tap)
- [x] ScenarioFeature.memo → .snippet (rawValue 미저장 확인), 카탈로그 'Memo'→'Snippet', 'Save as memo'→'Save as snippet'

### Claude가 완료한 것 — iOS 빌드 통과
- [x] Liquid Glass 시야 확보(상단) — 큰 제목·배너를 고정 크롬이 아닌 **각 페이지 스크롤 콘텐츠**로 이동
      (`pageHeader(for:)`), 스크롤하면 함께 올라가 화면 전체가 콘텐츠. 상단 엣지는 시스템 soft glass 유지
- [x] 순정(네이티브) IA 개편 — 사용자 선택 4건 반영 (iOS·macOS 빌드 통과, 시뮬레이터 시각 확인)
      - 루트를 순정 플로팅 glass TabView로: 메모 / 클립보드 / 설정 + 검색 탭(Tab role: .search),
        tabBarMinimizeBehavior(.onScrollDown). `MainTabView`·`MemoSearchView` (ClipKeyboardApp.swift)
      - 검색: 커스텀 하단 검색바 제거 → 검색 탭 + 순정 .searchable (보안 메모는 내용검색·복사 제외)
      - 메인 제목: 스크롤 콘텐츠 제목 제거("같이 올라가는 것 별로" 피드백) → 순정 인라인 네비바 타이틀
        (현재 카테고리명, 스와이프 시 갱신), pageHeader는 배너만
      - 하단 툴바 폐지 → ⋯·+ 를 네비바 트레일링으로(시스템 glass 알약), + 글리프는 plain plus
      - ⋯ 메뉴에서 클립보드 히스토리·설정 제거(탭으로 이전), scrollEdgeEffectHidden 제거(순정 엣지 복원)
      - 잔여 데드코드: searchBarInlineSection·isSearchBarVisible·searchNoResultsView (다음 정리 대상)
- [x] Liquid Glass 전면 적용 (iOS 26, iOS·macOS 빌드 통과)
      - `solidNavBar` 불투명 강제 해제(정의 1곳 수정 → 27개 화면 네비바 일괄 glass 전환)
      - `ThemedNavTitleModifier` 전역 UINavigationBar appearance의 opaque 배경 제거(앱 전체 glass를 죽이던 주범),
        폰트만 오버라이드 + scrollEdge는 투명(시스템과 동일: 맨 위 투명 → 스크롤 시 glass)
      - 토스트 2곳(메인 리스트·클립보드) → 다크 틴트 glass (`glassEffect(.regular.tint(...))`)
      - SwipePageIndicator → glass 캡슐, 하단 검색바 → glass 바
      - 의도적 제외: 콘텐츠 카드·배너(Apple 가이드: glass는 플로팅 컨트롤 레이어 전용),
        키보드 익스텐션(시스템 glass 크롬 없음 + ~60MB 메모리 한도)
- [x] 하단 툴바 버튼 유리 배경 제거 — `ToolbarItemGroup.sharedBackgroundVisibility(.hidden)` (검색·⋯ 알약 제거)
      ※ + 버튼의 파란 원은 배경이 아니라 `plusCircleFill` 글리프 자체
- [x] 메모 구분 표시 토글 단일화 — `visualCuesVisible = showVisualCues`만 (iOS '색상 없이 구별' 강제 연동 제거,
      4곳: ClipKeyboardList/MemoRowView/KeyboardView/KeyboardLayoutSettings + 설정·접근성 가이드 문구 갱신)
- [x] 하단 툴바 회색 스크롤 엣지 제거 — `scrollEdgeEffectHidden(true, for: .bottom)`로 더 넓은 시야 (iOS 26+)
- [x] 메인 화면 붙여넣기 허용 팁 배너 추가 — 앱 진입 시 팝업 뜨는 지점(topBanners)에서 설정으로 바로 안내
      (`PastePermissionTipBanner`, `pasteTipDismissed` 키를 클립보드 화면 배너와 공유)
- [x] 메모/단축어 용어 통일 — 사용자 항목을 가리키는 "단축어"→"메모" (Apple 단축어 앱 의미는 유지)
- [x] 활용 사례 화면 → 페르소나 스토리로 개편 — 4개 페르소나(nomad/business/student/general)×10개
      활용법, 공감 pain→예시→"이렇게 달라져요" 3단, ko/en/id 전체 (`PersonaGuideData.swift`, pbxproj 등록)
- [x] 기본(basic) 탭 그리드 끝 "메모 추가" 카드 제거 (하단 + 메뉴로 유도)

## 🤖 v4.3.6 — Apple Intelligence + CloudKit 피드백 (2026-07-14)

### Claude가 완료한 것
- [x] 버전 4.3.6으로 상향 (Version.xcconfig)
- [x] `Service/AppleIntelligenceService.swift` — Foundation Models(온디바이스 AI, iOS 26+) 래퍼
  - AI 클립보드 재분류 (정규식 신뢰도 <0.7 항목, tags "ai"로 재분류 방지, 세션당 최대 10개)
  - "붙여넣을 앱" 예측 (mail/messages/calendar/webSearch/notes)
  - 온디바이스 번역 (16개 언어, 무료/오프라인)
- [x] `Screens/Component/AIComponents.swift` — 단축 액션 칩(타입 기반 + AI 예측) + 번역 시트
- [x] `Screens/AISettingsView.swift` — 설정 > Apple Intelligence (토글 2종 + 기본 번역 언어)
- [x] `Service/FeedbackService.swift` — 피드백 CloudKit Public DB 직접 제출 (실패 시 이메일 폴백)
- [x] 피드백 넛지 — 10회째 실행 첫 노출, 이후 40회 간격, "다시 보지 않기" 지원
- [x] String Catalog 38개 키 추가 (ko/en/id), pbxproj 등록, iOS 빌드+전체 테스트+macOS 빌드 통과
- [x] 마스터(개발자) 모드 — 설정 > 앱 정보 > 버전 7번 탭 → 지원 섹션에 "접수된 피드백" 인박스
  (`FeedbackInboxView`, CloudKit Public DB 조회 + userRecordName 복사 UI)
- [x] 메모 심볼 기본 숨김 — 상시 노출되던 보안 자물쇠(그리드 카드·키보드 셀)를 구분 표시 토글 뒤로,
  설정 미리보기 좌상단 심볼도 토글 연동, showVisualCues 1회 강제 OFF 리셋(v4.3.6 정책, 구 승계 마이그레이션 폐기)
- [x] 인박스 완료 표시(status=done)·삭제 스와이프 + 새 피드백 푸시 알림(CKQuerySubscription 토글)
- [x] 4.3.6 릴리즈 노트 (docs/RELEASE_NOTES_4.3.6.md)

### 사용자(leeo)가 해야 하는 것 — CloudKit 피드백 1회 설정 (docs/FEEDBACK_CLOUDKIT.md)
- [ ] Xcode 빌드에서 피드백 1회 제출 → Development에 Feedback 스키마 자동 생성
- [ ] CloudKit Dashboard에서 인덱스(createdTimestamp Queryable+Sortable) 추가
- [ ] Security Roles: _world는 Create만 (Read 제거)
- [ ] Feedback 인덱스: recordName Queryable + createdTimestamp Sortable (인박스 조회용)
- [ ] admin 역할 생성 + Feedback **Read+Write** 권한 + 내 userRecordName 추가 (Write는 완료표시·삭제용)
- [ ] Schema를 Production으로 배포
- [ ] 실기기(iOS 26, Apple Intelligence 기기)에서 AI 분류/제안/번역 확인

---

## 🎯 마케팅 (2026-07-07 시작) — 상세: docs/MARKETING_PLAN_2026-07.md

### Claude가 완료한 것
- [x] 시장/경쟁/채널 리서치 (KR 4.7★/13리뷰, 최대 병목=리뷰 수, 차별화=구독 없음)
- [x] 랜딩페이지 가격 오류 수정 (docs/index.html: ₩14,900 일시불 → 무료+Pro ₩17,000) — **커밋/푸시 대기**
- [x] ASO 카피 팩 작성 (docs/ASO_2026-07.md)
- [x] 한국 커뮤니티 포스트 4종 (docs/KR_COMMUNITY_POSTS.md)
- [x] Product Hunt 런칭 킷 (docs/PRODUCT_HUNT_LAUNCH.md)
- [x] Apple 피처링 신청서 (docs/APPLE_FEATURING_PITCH.md)

### 사용자(leeo)가 해야 하는 것 — 우선순위: 글로벌 먼저 (2026-07-07 결정)
- [ ] ASC 프로모션 텍스트 교체 (심사 불필요, 오늘 가능)
- [ ] Apple 피처링 신청 제출 (10분)
- [ ] 새 Offer Code 발급 (APRIL 만료됨) + 캠페인 링크 pt/ct 발급
- [ ] 스크린샷 6종 + 데모 GIF 실기기 캡처 (ASO/PH/Reddit 공용 — 글로벌 런칭 블로커)
- [ ] Product Hunt 런칭 → Reddit(r/digitalnomad, r/freelance) → Show HN
- [ ] 이후 한국 커뮤니티 (디스콰이엇 → 루리웹 → 클리앙 → 뽐뿌, 각 1일+ 간격)

---

# ClipKeyboard 리팩토링 진행 상황

## Phase 1: Foundation (Storage + Repository) ✅ 완료

- [x] `Data/Storage/AppGroupStorage.swift` - App Group 스토리지 래퍼
- [x] `Domain/Repository/MemoRepositoryProtocol.swift`
- [x] `Domain/Repository/ClipboardRepositoryProtocol.swift`
- [x] `Domain/Repository/ComboRepositoryProtocol.swift`
- [x] `Data/Repository/MemoRepository.swift` - MemoStore 위임
- [x] `Data/Repository/ClipboardRepository.swift`
- [x] `Data/Repository/ComboRepository.swift`

## Phase 2: Use Cases ✅ 완료

- [x] `Domain/UseCase/ClassifyClipboardUseCase.swift`
- [x] `Domain/UseCase/SaveMemoUseCase.swift`

## Phase 3: ViewModel ✅ 완료

- [x] `Presentation/MemoAdd/MemoAddViewModel.swift`

## Phase 4: DI Container ✅ 완료

- [x] `App/AppDependencies.swift`

## Phase 5: Xcode 프로젝트 파일 등록 ✅ 완료

- [x] PBXFileReference 등록 (11개 파일)
- [x] PBXBuildFile 등록 (11개 파일, ClipKeyboard 타겟만)
- [x] PBXGroup 생성 (Data, Data/Storage, Data/Repository, Domain, Domain/Repository, Domain/UseCase, Presentation, Presentation/MemoAdd, App)
- [x] PBXSourcesBuildPhase 등록

## Phase 6: 구조 개선 ✅ 완료

- [x] ClipKeyboardApp.swift에 AppDependencies 주입 (`.environmentObject(deps)`)
- [x] ProStatusManager 이중 상태 제거 (Combine 구독 제거, StoreManager 직접 호출 방식 유지)
- [x] MemoStore God Object 분해:
  - [x] ClipboardClassificationService → 별도 파일 추출 (678줄 → 540줄 → 삭제)
  - [x] OCRService → 별도 파일 추출
  - [x] MemoStore.swift: 1,220줄 → 678줄 (분류/OCR 서비스 분리)

## Phase 7: 최종 완료 ✅

- [x] MemoAdd.swift의 @State 변수를 MemoAddViewModel로 완전 연결 (recentlyUsedCategories, updateRecentlyUsedCategories View 중복 제거, selectCategory 메서드 추가)
- [x] ClipKeyboardList ViewModel 분리 (ClipKeyboardListViewModel 신규 생성, View는 isSearchBarVisible만 유지)
- [x] 미커밋 파일 전체 커밋 완료

## 전체 완료 🎉

---

# v4.0 이전 유료 구매자 Pro 복구 (2026-05-29)

## 문제
- 앱은 v4.0 출시(2026-02-21 00:14 KST) 전까지 **유료 앱(다운로드 유료)**, 이후 **무료 + Pro IAP**로 전환.
- 2024년 유료 구매자가 v4.0 업데이트 후 Pro 기능이 잠겨 "다시 사야 하냐"는 피드백.
- 원인: 그랜드파더 부여가 (1) 신규 Pro IAP 영수증, (2) 기기 내 메모 개수 휴리스틱에만 의존.
  과거 유료 구매자는 신규 IAP 영수증이 없고, 재설치/기기변경 시 메모도 0개 → 신규 무료 유저로 오인.
  Apple 정식 수단인 `AppTransaction`(최초 구매일)을 전혀 확인하지 않던 것이 핵심 결함.

## 해결
- [x] `ProFeatureManager.grandfatherPaidUserIfNeeded()` 추가
  - `AppTransaction.shared.originalPurchaseDate < freemiumReleaseDate`이면 `grandfatheredPurchaseKey` 영구 부여
  - iOS의 `originalAppVersion`은 빌드번호라 신뢰 불가 → `originalPurchaseDate`로 판별
  - 컷오프: `freemiumReleaseDate = 1_771_686_000` (2026-02-22 00:00 KST, 출시일 +여유)
  - idempotent (이미 그랜드파더면 즉시 return)
- [x] `ClipKeyboardApp.init()`에서 매 실행 검증 Task 추가 (bootstrap_done 1회 가드와 무관 → 이미 막힌 유저 자동 구제)
- [x] `StoreManager.restorePurchases()`에서도 재검증 (이전 구매 복원 버튼으로 즉시 해제)
- [x] 부여 직후 `ProStatusManager.objectWillChange.send()`로 UI 갱신
- [x] ClipKeyboard 스킴 빌드 성공 확인

## 검증 필요 (실기기/Sandbox)
- [ ] Sandbox/TestFlight에서 originalPurchaseDate 동작 확인 (Xcode 환경은 originalPurchaseDate가 컷오프 이전이라 항상 부여됨에 유의)
- [ ] 실제 2024 구매 계정으로 업데이트 후 Pro 자동 복구 확인

---

# 기본 제공 카테고리 (타입별 모아보기) (2026-06-06)

## 요청
- 템플릿만 / 메모+템플릿 / 이미지 메모만 / 콤보만 처럼 앱이 미리 만들어 두는 카테고리를
  제공하고, 사용자가 켜고 끌 수 있게. (필터가 아니라 "카테고리"로 — 사용자에겐 일반
  카테고리와 동일하게 보이되 멤버십만 타입 기준으로 판정)

## 구현 ✅
- [x] `BuiltInCategory` enum 신설 (templates/textMemos/images/combos)
  - displayName·icon·tint + `matches(Memo)` 타입 판정 (isTemplate / contentType / isCombo)
- [x] `CategoryTab`에 `.builtIn(BuiltInCategory)` 케이스 추가 (isBuiltIn=true → 칩 삭제버튼 없음)
- [x] ViewModel: `enabledBuiltInCategories` @Published, `allCategoryTabs`·`memos(for:)` 확장,
      loadCustomCategories에서 App Group 키 로드 + 끈 탭이 선택중이면 .all로 복귀
- [x] CategoryStore: `enabledBuiltInCategories_v1` 영구 저장 + `isBuiltInEnabled/setBuiltInEnabled`
- [x] CategorySettings: "기본 제공 카테고리" 섹션 + 토글 4개
- [x] ClipKeyboardList: tabIndicatorColor·tabBackgroundColor·tabPageView 스위치에 .builtIn 처리
- [x] Localizable.xcstrings: 신규 키 5개 ko/en/id 추가
- [x] ClipKeyboard 스킴 빌드 성공

## 비고
- 켜면 메모 유무와 무관하게 탭 노출(사용자가 명시적으로 켰으므로) — 빈 경우 empty state 표시
- 키보드 익스텐션도 같은 App Group 키를 읽으면 동일 카테고리 활용 가능(추후)

---

# 메모 순서 바꾸기(흔들기/드래그) + Today 스타일 탭 애니메이션 (2026-06-06)

## 요청
- 메모 길게 누르기 → "수정" 위에 "순서 바꾸기" 버튼 → iOS 홈화면처럼 카드가 오들오들
  떨면서 드래그앤드롭으로 그리드 순서 변경. 순서 영구 저장.
- 메모 탭 시 App Store Today 카드처럼 폭 눌렸다 부드럽게 올라오는 애니메이션.

## 결정 (사용자 확인)
- 순서 범위: **전체 메모 한 벌**(전체 탭 기준). 재정렬 모드는 전체 목록을 보여줌.
- 즐겨찾기 고정: **해제** — 수동 순서를 한 번이라도 쓰면 즐겨찾기 맨위 고정 풀고 내 순서 그대로.

## 구현 ✅
- [x] sortMemos: manualOrderActive면 저장된 id 순서대로 정렬(없는 새 메모는 맨 위). 아니면 기존 즐겨찾기→최근순.
- [x] ViewModel: isReorderMode/reorderList + enterReorderMode/exitReorderMode/commitReorder.
      manualOrder/manualOrderActive는 App Group UserDefaults(memoManualOrder_v1 / memoManualOrderActive_v1)에 저장.
- [x] MemoActionSheet: onReorder 콜백 + "순서 바꾸기" 행(수정 위). 시트 높이 470→530.
- [x] memoCardSurface(memo:) 추출 — 제스처 없는 카드 비주얼을 그리드 셀/재정렬 셀이 공유.
- [x] Today 스타일 press: pressedMemoId + scaleEffect(0.95) + spring(response 0.34, damping 0.62).
      onPressingChanged에서 set/reset, 롱프레스 완료 시 reset. reduceMotion이면 비활성.
- [x] reorderModeView(fullScreenCover): 흔들리는 LazyVGrid + onDrag(명시 preview)/onDrop 라이브 재배치.
      MemoReorderDropDelegate(dropEntered에서 move+haptic), 여백 드롭용 ReorderResetDropDelegate.
      wiggle 회전 ±1.4°, index별 delay로 유기적. reduceMotion/드래그 중엔 정지.
- [x] Localizable.xcstrings: "순서 바꾸기"/"카드를 끌어 순서를 바꾸세요"/"드래그하여 순서를 바꿉니다" ko/en/id.
- [x] ClipKeyboard 스킴 빌드 성공.

## 검증 필요 (실기기/시뮬레이터)
- [ ] 흔들기·드래그 재배치 부드러움, 미리보기 또렷함, 여백 드롭 복구
- [ ] 완료 후 메인 그리드 순서 반영 + 앱 재시작 후 순서 유지
- [ ] Today 탭 press 애니메이션 느낌
- [ ] 새 메모 추가 시 맨 위 노출(순서 미등록) 확인

---

# 검색 후 키보드 안 올라옴 + "전체" 탭 → "기본" 탭 교체 (2026-06-08)

## 요청 1: 메인 페이지에서 검색 시 키보드가 안 올라옴
- 원인: 검색바(searchBarInlineSection)가 나타날 때 TextField에 포커스를 주는
  코드(@FocusState)가 없어 키보드가 자동으로 뜨지 않음.
- [x] `@FocusState private var isSearchFieldFocused` 추가
- [x] TextField에 `.focused($isSearchFieldFocused)` + `.submitLabel(.search)`
- [x] 검색 토글 버튼: 열릴 때 0.35s 뒤(스프링 애니메이션 후 마운트) 포커스, 닫을 때 해제

## 요청 2: "전체" 탭 제거 + 카테고리 없는 메모를 "기본"으로
- 결정(사용자 확인): "전체" 탭만 제거 / 비어있는 category만 "기본"으로.
- 설계: `.all`은 카테고리 기능 OFF용 단일 페이지로 유지하고, 탭 목록에서만 제거.
  새 `.basic`("기본") 탭이 첫 탭 — **커스텀 카테고리에 속하지 않은 모든 메모 catch-all**
  (기본/빈값/삭제된 카테고리 고아 포함) → "전체"가 사라져도 메모 누락 없음.
- [x] `CategoryTab`에 `.basic` 추가 (displayName "기본", storageKey "__basic__", icon tray.full.fill)
- [x] ViewModel: 기본 선택 탭 `.basic`, allCategoryTabs 선두 `.basic`, `basicBucketMemos` 추가,
      memos(for:)·restore·delete/hide/load 리셋 지점 모두 `.all`→`.basic`
- [x] loadMemos: `normalizeEmptyCategories` — 빈 category를 "기본"으로 정규화(멱등, 변경 시만 저장)
- [x] ClipKeyboardList: allTabScrollView를 `func(memos:)`로 전환(전체/기본 데이터 소스 분리),
      tabIndicatorColor·tabBackgroundColor·tabPageView·addCard 스위치에 `.basic` 처리
- [x] "기본" 문자열은 String Catalog에 기존재(en "General", id 포함) — 추가 작업 불필요
- [x] ClipKeyboard 스킴 빌드 성공

## 검증 필요 (실기기/시뮬레이터)
- [ ] 메인에서 돋보기 → 검색바와 함께 키보드 자동 노출
- [ ] 탭 바에 "전체" 없이 "기본"이 첫 탭으로 표시
- [ ] 빈 카테고리 메모가 "기본" 탭에 모이는지 / 커스텀 카테고리 메모는 해당 탭에만
- [ ] 카테고리 기능 OFF 시 단일 페이지에 모든 메모 정상 노출

---

# 색맹용 메모 타입 테두리를 접근성 설정으로 제어 (2026-06-08)

## 요청
- 색맹용 메모 테두리(템플릿/콤보/보안 타입 구분)를 항상 표시하지 말고 접근성 설정으로 제어.

## 결정 (사용자 확인)
- iOS 시스템 "색상 없이 구별"(Differentiate Without Color) 연동 — 별도 인앱 토글 없이
  `@Environment(\.accessibilityDifferentiateWithoutColor)`로 제어. 켜면 테두리 표시, 끄면 숨김(기본).

## 구현 ✅
- [x] ClipKeyboardList: `@Environment(\.accessibilityDifferentiateWithoutColor)` 추가,
      `memoTypeBorder`가 꺼져 있으면 `.clear` 반환 (메인 메모 그리드 카드)
- [x] KeyboardView(익스텐션): 동일 환경값 추가, `typeStyle`이 꺼져 있으면 clear 반환
- [x] KeyboardLayoutSettings의 KeyboardPreviewView: `typeBorder`도 게이팅(실제 키보드와 일치)
- [x] AccessibilityGuideView "색상 없이 구별" 항목: 설명을 메모/키보드 테두리 제어로 갱신,
      경로를 "색상 필터" → "색상 없이 구별"로 정정
- [x] Localizable.xcstrings: 신규 키 2개(ko 소스 + en) 추가, JSON 유효성 확인
      (구 키 2개는 미사용 → Xcode가 stale 표시)
- [x] ClipKeyboard 스킴 빌드 성공(익스텐션 포함)

## 비고
- 기본값(설정 OFF): 메모 카드/키보드 칸에 타입 테두리 없음 → 더 깔끔.
  타입 구분이 필요한 색맹 사용자는 iOS "색상 없이 구별"을 켜면 색+패턴 테두리 노출.
- 키보드 익스텐션도 SwiftUI 트레잇으로 동일 접근성값을 받으므로 메인 앱과 일관 동작.

## 검증 필요 (실기기)
- [ ] iOS 설정 → 손쉬운 사용 → 디스플레이 및 텍스트 크기 → "색상 없이 구별" OFF: 테두리 없음
- [ ] ON으로 전환: 메인 메모 그리드 + 키보드에 타입 테두리(보라 실선/주황 dash/회색 dot) 표시
- [ ] 키보드 레이아웃 설정 미리보기가 실제 키보드와 동일하게 반영

---

# 우상단 심볼(즐겨찾기 하트 + 카테고리 심볼)을 접근성/토글로 제어 (2026-06-08)

## 요청
- 즐겨찾기 하트 심볼도 항상 보여주지 말 것. 접근성과 연동해 보여주고,
  설정에서 카테고리 심볼 표시 여부를 토글로 제공.

## 결정 (사용자 확인)
- 표시 조건: **접근성 OR 토글** — iOS "색상 없이 구별" ON 또는 설정 "카테고리 심볼" 토글 ON.
- 설정 토글 기본값: **OFF**(기본은 깔끔). 하트·카테고리 심볼 모두 동일 적용.

## 구현 ✅
- [x] ClipKeyboardList: `cornerSymbolVisible = differentiateWithoutColor || categoryBadgeVisible`
      computed 추가. 우상단 심볼 블록(즐겨찾기 하트 + 카테고리 심볼)을 이 게이트로 감쌈.
- [x] `categoryBadgeVisible` 기본값 true → **false**로 변경 (View + DisplaySettingsView 양쪽)
- [x] DisplaySettingsView 푸터 텍스트 갱신(하트+카테고리 심볼, 접근성 자동 표시, 기본 OFF 안내)
- [x] Localizable.xcstrings: 신규 푸터 키(ko+en) 추가, 구 키는 미사용(stale). JSON 유효성 확인
- [x] ClipKeyboard 스킴 빌드 성공

## 비고
- 즐겨찾기는 심볼이 꺼져도 카드 **배경색(clipFavorite 분홍)**으로 여전히 식별 가능 → 정보 손실 없음.
- 기존 사용자도 키 미설정 시 기본 false 적용 → 우상단 심볼이 사라짐(의도된 동작).
- "카테고리 배지 끄기" 넛지는 categoryBadgeVisible=true일 때만 떠서, 기본 OFF에선 자연히 비노출.

## 검증 필요 (실기기)
- [ ] 기본 상태: 우상단에 하트/카테고리 심볼 없음(즐겨찾기는 분홍 배경으로 구분)
- [ ] iOS "색상 없이 구별" ON: 하트·카테고리 심볼 자동 표시
- [ ] 설정 → 디스플레이 → 메모 표시 → "카테고리 심볼" ON: 심볼 표시 / OFF: 숨김
- [ ] 설정 미리보기 토글 즉시 반영

---

# 데이터 모델 단순화: 모든 것을 메모/템플릿으로 통합 (2026-06-08)

## 요청
- 모든 데이터는 메모이거나 템플릿. "메모+템플릿"은 그냥 템플릿. 콤보는 "메모 안에 메모들".
  → 메모/템플릿만 남기고 Combo·attachedTemplateId 정리. (계획 승인 후 진행)

## 확정 설계
- 콤보 = **기존 메모 참조** `Memo.childMemoIds: [UUID]` (순서). 비어있지 않으면 콤보.
- attachedTemplateId = **본문 합쳐 일반 메모로** (TemplateVariableProcessor.compose).
- 콤보 입력 = **순차 입력 유지**(interval). 키보드는 정책 A(탭 1회→자식 순차 insert).

## 구현 ✅ (전 타깃 빌드 그린: iOS앱+익스텐션+위젯, macOS tap)
- [x] Memo 모델: childMemoIds/comboInterval 추가, isCombo **계산형**(`!childMemoIds.isEmpty`),
      comboValues/currentComboIndex/attachedTemplateId **제거**. 3개 Memo 정의 동기화.
- [x] MemoStore: childMemos/resolveChildValues/pruneMissingChildren 추가.
- [x] ComboExecutionService: startCombo(Memo) + childMemoIds 기반 순차 클립보드 복사.
- [x] 키보드: handleComboMemoIfNeeded 정책A 재작성, handleAttachedTemplate/Skip 제거, canSplit/bypass 정리.
- [x] UI: ComboList를 콤보-메모 매니저로 전면 재작성(자식 메모 피커), ComboEditSheet→ComboAddEditView redirect,
      MemoAdd에서 콤보/attached 섹션 제거, MemoAddViewModel/SaveMemoUseCase 정리.
- [x] ClipKeyboardList body가 콜드 타입체크 한계 초과 → mainColumn/screenBody/screenL3~L8 computed로 분할.
- [x] 마이그레이션 `migrateComboModelIfNeeded`(플래그 comboModelUnifyMigrated_v1, onAppear 맨앞):
      원본 JSON에서 레거시 필드 선읽기 → 메모내장콤보/attached/combos.data 변환, combos.data 삭제.
- [x] 테스트: ComboExecutionServiceTests 신모델 재작성, AttachedTemplateTests→콤보 모델 테스트.
- [x] Localizable.xcstrings 신규 키 2개(ko+en).

## 비고 / 남은 것
- 레거시 `Combo`/`ComboItem`/`ComboItemType` 타입 + MemoStore combo CRUD + CloudKit combosAsset는
  **마이그레이션 디코드용으로 의도적으로 유지**(죽은 코드). pbxproj 수술 회피.
- ComboItemPickerView/ComboTemplateInputView도 미사용이나 컴파일됨(레거시 타입 참조).
- **기존 실패(무관)**: CategoryStoreTests.swift:127 `CategoryStore.localeDefaults` — 내 변경 아님(git 깨끗).
  테스트 타깃 전체 빌드는 이 한 줄 때문에 실패하나 콤보/attached 테스트 자체는 정상.

## 검증 필요 (실기기/업그레이드)
- [ ] 업그레이드: 메모내장콤보/attached/플랫콤보 각 1개 → 첫 실행 변환·combos.data 삭제·재시작 무중복
- [ ] 콤보 생성/편집(ComboList): 자식 메모 선택·순서·interval, 실행 시 순차 복사 + 완료 clipCount↑
- [ ] 키보드 콤보 탭: 자식 값 interval 순차 입력
- [ ] 메모 리스트/검색/키보드에 콤보 배지·미리보기 정상

## 마이그레이션 하위호환 강화 (2026-06-09)
- [x] **init 맨 앞에서 실행** — bootstrapV4GrandfatherFlags의 load()(구 카테고리 자동 재저장)가
      레거시 키를 지우기 전에 변환. onAppear 호출은 방어용 유지(멱등).
- [x] **레거시 데이터 감지 시 재실행** — `hasLegacyComboData()`(combos.data 존재 OR memos.data 원본에
      `"isCombo":true`/`"attachedTemplateId":"`)가 참이면 플래그 set돼 있어도 재변환 → 옛 CloudKit 백업 복원 대비.
- [x] **CloudKit 복원 시 플래그 리셋** — saveRestoredData에서 comboModelUnifyMigrated_v1=false →
      복원된 레거시 데이터가 다음 실행에 신 모델로 재변환.
- [x] **변환 견고화** — 빈/공백 comboValue·빈 콤보·값 없는 항목 스킵(잡 메모 방지), 자식 0개 콤보 미생성,
      변경 있을 때만 원자적 save(실패 시 플래그 미set→재시도), OldMemo 등 과거 포맷도 id로 디코드.
- [x] ClipKeyboard 스킴 빌드 성공

---

# 구분 장치 심플화: 기본 제목만 + 마스터 토글 옵션 (2026-06-09)

## 요청
- 색맹/구분 장치는 좋지만, 기본은 최대한 심플(인지부하↓). 지금까지의 장치들을 옵션으로 제공.

## 결정(사용자)
- 기본 모습 = **제목만** (아이콘/배지/테두리/우상단 심볼/배경색 전부 OFF). 이미지 콘텐츠는 유지.
- 제어 = **단일 마스터 토글** "메모 구분 표시". iOS "색상 없이 구별" 켜면 자동 ON.

## 구현 ✅ (iOS앱+키보드+위젯+macOS 빌드 그린)
- [x] `showVisualCues`(App Group UD, 기본 false) + `visualCuesVisible = differentiateWithoutColor || showVisualCues`.
- [x] ClipKeyboardList 카드: 상단 행(타입 아이콘+우상단 심볼)·타입 테두리·배경색·cardIsColored 전부 게이팅.
      배지 nudge는 "구분 표시 끄기" 제안으로 의미 전환.
- [x] MemoRowView(검색 행): leadingIcon·배지·하트 게이팅.
- [x] KeyboardView: typeStyle(테두리)·메모 버튼 카테고리 틴트 게이팅(App Group 토글 공유).
- [x] SettingView DisplaySettingsView: "카테고리 심볼"→"메모 구분 표시" 마스터 토글(showVisualCues).
- [x] AccessibilityGuide "색상 없이 구별" 카피 갱신(이제 마스터 토글 자동 ON).
- [x] 마이그레이션 `migrateVisualCuesIfNeeded`: 구 categoryBadgeVisible=true → showVisualCues=true 승계.
- [x] Localizable.xcstrings 신규 키 3개(ko+en).

## 비고
- 카테고리 색 코딩/즐겨찾기 분홍/타입 아이콘이 기본 OFF → 카테고리는 상단 탭/스와이프로 구분(여전히 동작).
- 토글 하나로 카드·검색행·키보드의 모든 구분 장치가 한 번에 켜짐(인지부하 최소).
- 검증 권장(실기기): 기본=제목만 / 토글 ON 시 전 장치 표시 / iOS "색상 없이 구별" ON 시 자동 표시 / 구버전 categoryBadgeVisible 사용자 승계.

---

# 제안(고스트) 메모 등장/퇴장 애니메이션 (2026-06-09)
- [x] ghostMemoCell에 `.transition(.scale(0.2)+opacity)` + `.id(pattern.title)`.
- [x] X 버튼: ① `withAnimation(.easeIn 0.22){ ghostSuggestion=nil }`(작아지며 사라짐)
      ② 0.24s 뒤 `withAnimation(.spring){ refreshGhostSuggestion() }`(다음 제안이 작은 네모부터 커지며 등장).
- [x] reduceMotion이면 즉시 전환(애니메이션 없음). 빌드 성공.

---

# 생성 모델 통합: "메모 하나"로 (2026-06-09)
- 사용자 인지 모델: 메모만 만든다. **변수({…}) 넣으면 템플릿**, **이어지는 메모 더하면 콤보**.
- [x] Memo: `comboValues:[String]` 복원(출시본 호환), `isCombo`=`!comboValues.isEmpty`, `isTemplate`=`!templateVariables.isEmpty`(둘 다 계산형). childMemoIds는 디코드/마이그레이션용만.
- [x] 실행: ComboExecutionService/키보드/프리뷰를 comboValues로.
- [x] MemoAdd: 수동 템플릿 토글 제거(변수 자동 감지→템플릿 도우미 자동 노출), 본문 포커스 시 변수삽입 바 상시,
      "이어지는 메모" 섹션(continuations→저장 시 comboValues=[본문]+단계들). 편집 진입 시 분해 로드.
- [x] "+" 메뉴: **새 메모 + 텍스트 가져오기**만(새 템플릿/새 콤보 항목 제거). 콤보 메모 탭→통합 MemoAdd 편집.
- [x] 마이그레이션: 출시본 인라인 comboValues는 그대로 / flat combos.data→comboValues / dev childMemoIds→comboValues.
- [x] 다국어 신규 키(ko+en). 전 타깃 빌드 그린(iOS·키보드·위젯·macOS).
- 비고: ComboList 화면은 미사용(#Preview만)이라 죽은 코드. ComboAddEditView는 ComboList에서만 참조(미도달).
- 검증 권장(실기기): 본문에 {변수}→템플릿 도우미 / 이어지는 메모→콤보·키보드 순차입력 / "+"엔 새 메모만 / 콤보 탭 편집.

## 템플릿 변수 표시: 중괄호 없는 하이라이트(4.3.0 스타일) (2026-06-09)
- [x] HighlightedTextEditor: `{변수}` 토큰의 칩 배경/강조색은 유지하되 `{`·`}` 글자만 투명색 → 화면엔 변수명만 칩으로(텍스트엔 중괄호 남아 파싱 그대로). 편집 중에도 willProcessEditing에서 재적용.
- [x] QuickInsertTokenButton: 칩 라벨을 `token.strippingTemplateBraces`로(중괄호 없이 표시, 삽입은 {…} 그대로).
- 비고: 템플릿 안내 문구("{날짜} 형식…")는 작성법 설명이라 유지. 빌드 그린.

---

# 카테고리 손실 버그 수정 + 메모 타임머신 (2026-06-09)

## 카테고리 자동 손실 차단 (데이터 손실 사고 대응)
- [x] `migrateLegacyCategoriesToThemes` — `개인정보/금융/여행/업무/기본` 카테고리를 자동으로 덮어써 삭제하던
      파괴적 1회 마이그레이션. **무력화(항상 원본 반환)**. (이미 출시본에 있던 버그 → 핫픽스 필요)
- [x] `migrateExistingMemosClassification` — "기본" 메모를 타입으로 자동 이동하던 부분 제거(autoDetectedType만 채움).
- [x] MemoAdd 편집 시 기존 category 미로드로 저장 시 재분류 덮어쓰던 버그 수정(편집은 항상 기존 category 보존).
- 검증: 자동으로 기존 카테고리를 바꾸는 경로 0 (이동/삭제는 사용자 직접 동작만).

## 메모 타임머신 (A안: 전체 스냅샷 링버퍼)
- [x] `MemoStore.save(.memo)` 직전, **의미 있는 변경**(제목/본문/카테고리/자식/이미지/힌트 변화)일 때만
      직전 전체 상태를 `MemoSnapshot`으로 보관. 사용량(clipCount/lastUsedAt)만 변경 시 skip. 최근 10개 유지.
- [x] `memo.history.data`(App Group) 저장. `loadMemoHistory()` / `restoreMemoSnapshot(id)`(되돌리기도 되돌림 가능).
- [x] 설정 → 데이터 & 보안 → "변경 기록 (되돌리기)" 화면(MemoHistoryView): 시점 목록·복원 확인·토스트.
- [x] 마이그레이션 같은 대량 변경도 직전 상태가 스냅샷되어 되돌릴 수 있음(오늘 같은 사고 복구 가능).
- [x] Localizable.xcstrings 신규 키 10개(ko+en), 날짜는 setLocalizedDateFormatFromTemplate로 자동 현지화. 빌드 성공.

---

# 지원 페이지(사용 가이드) 기능 동기화 (2026-06-10)

## 요청
- docs/tutorial.html(지원/사용 가이드)을 현재 기능에 맞게 업데이트.

## 반영 ✅
- [x] 용어 정리: "테마" → "카테고리" (메모 추가 단계)
- [x] 콤보 생성 흐름 수정: 별도 "콤보 탭" 제거 → 메모 본문 + "이어지는 메모"로 콤보 생성, 탭 시 미리보기 하프시트
- [x] 보안 메모 섹션 추가: 길게 눌러 잠금/해제, 기기 암호화, Face ID·Touch ID, 자물쇠 표시 (Pro)
- [x] 템플릿: 탭 시 값 입력 시트, "템플릿으로 만들기"(롱프레스), 날짜 변수 선택지
- [x] 키보드 외형: 즐겨찾기 분홍·보안 자물쇠·현재 카테고리 큰 제목
- [x] 이미지 메모: OCR(문자 인식) 추가
- [x] FAQ: 보안 메모 잠금 항목 추가
- [x] ko/en 양쪽 번역 동기화

---

# 데이터 모델 UML 다이어그램 HTML (2026-06-08)

## 요청
- 앱의 데이터 모델링을 UML 다이어그램으로 시각화한 HTML 문서로 남기기.

## 산출물 ✅
- [x] `docs/data-model-uml.html` 생성 — 완전 자립형(인터넷/CDN 불필요)
  - Mermaid classDiagram을 **다크 테마 SVG로 미리 렌더해 인라인 임베드**(오프라인 OK)
  - 편집용 Mermaid 소스는 `<details>`에 보존
  - 엔티티 상세 카드(속성·타입·프로토콜) + 영속화 테이블 + 마이그레이션 노트
- [x] 포함 모델: Memo, OldMemo(레거시), SmartClipboardHistory, ClipboardHistory(레거시),
      PlaceholderValue, Combo, ComboItem + enum(ClipboardItemType/ContentType/ComboItemType/MemoType)
      + 서비스(MemoStore, CloudKitBackupService)
- [x] 관계 표기: 합성(*--)/집합(o--)/연관(-->)/의존·UUID참조·마이그레이션(..>)
- [x] mermaid-cli로 문법 검증(SVG 생성) + 헤드리스 크롬 스크린샷으로 렌더 확인

## 비고
- 출처: Model/Memo.swift(정본), Service/MemoStore.swift, Service/CloudKitBackupService.swift
- 코드 변경 없음(문서 산출물만). 모델 변경 시 details의 Mermaid 소스를 고쳐 재렌더하면 됨.

---

# 기능 명세 + Swift Testing 테스트 대거 작성 (2026-06-09)

## 요청
- 현재 존재하는 기능을 명세하고, 이를 검증하는 테스트코드(Swift Testing)를 대거 작성.

## 산출물 ✅
- [x] `docs/FEATURE_SPEC.md` — 현재(4.3.x dev) 기능 명세 8개 영역 + 테스트 매핑표.
- [x] Swift Testing 신규 6개 스위트(`ClipKeyboardTests/*SwiftTests.swift`):
  - MemoModelSwiftTests / TemplateVariableProcessorSwiftTests / MemoPreviewFormatterSwiftTests
  - ClipboardClassificationSwiftTests / ProFeatureLimitsSwiftTests / ComboAndTemplateModelSwiftTests
- [x] 전체 ClipKeyboardTests **294 케이스 그린**(시뮬레이터 실행 검증).

## 테스트 인프라 수리 (리팩터 이후 stale 제거)
- [x] 호스트 앱 런치 가드 추가(`ClipKeyboardApp.isRunningUnitTests`) — 테스트 시 Firebase/스케줄러/
      마이그레이션 스킵 → "test runner hung before establishing connection" 해결.
- [x] stale 테스트 수정: ModelTests/MemoStoreTests(`isTemplate:` 인자 제거), CategoryStoreTests
      (`localeDefaults` 제거), ComboExecutionServiceTests(childMemoIds→comboValues),
      PersonaTests(applyPersona는 카테고리 시드 안 함→선택 저장만), AttachedTemplateTests(콤보=comboValues).

## ⚠️ 테스트가 잡아낸 실제 데이터 손실 회귀 (수정 완료)
- [x] Memo가 **합성 Codable**이라, 최근 추가된 비옵셔널 키(childMemoIds/comboInterval/comboValues 등)가
      없는 구버전 memos.data는 `keyNotFound`로 **[Memo] 전체 디코딩 실패** → OldMemo 폴백 → 대량 손실.
- [x] **3개 Memo 복사본 모두** 관용 디코더(`init(from:)` + decodeIfPresent) 추가:
      `ClipKeyboard/Model/Memo.swift`, `Shared/Models/SharedModels.swift`(키보드/위젯),
      `ClipKeyboard.tap/Models.swift`(macOS). 누락 키를 기본값으로 안전 디코딩.
- [x] 회귀 가드 테스트 2건(MemoModelSwiftTests): 신규 키 누락 JSON·배열 안전 디코딩.
- [x] iOS 테스트 타겟 + macOS tap 빌드 그린.

---

# 콤보/리팩터 죽은 코드 정리 (2026-06-09, 테스트 안전망 기반)

## 방법
- 모든 삭제 후보를 grep으로 직접 참조 검증(에이전트 조사 신뢰 안 함 — 실제로 "KEEP" 오판 다수 발견).
- 삭제마다 294개 테스트 그린 유지 확인.

## 삭제 (확정 죽은 코드)
- [x] 파일 5개: `Screens/ComboList.swift`, `Screens/Combo/ComboItemPickerView.swift`,
      `Screens/Combo/ComboTemplateInputView.swift`, `Data/Repository/ComboRepository.swift`,
      `Domain/Repository/ComboRepositoryProtocol.swift` (+ pbxproj 항목 20줄 제거).
- [x] `AppDependencies.comboRepository` 주입 라인(아무 데서도 안 읽힘).
- [x] `MemoStore`: `childMemos`/`resolveChildValues`/`pruneMissingChildren`(참조 0),
      무력화된 `migrateLegacyCategoriesToThemes`(no-op) + 호출부 → `load()` 단순화.

## 유지 (검증으로 확인 — 살아있음)
- `ComboEditSheet.swift`(ComboSheetResolver) ← ClipKeyboardListComponents.swift:889에서 사용.
- 콤보 CRUD(`loadCombos`/`saveCombos` 등) + `Combo`/`ComboItem` 타입 ← CloudKit 백업 + 테스트 커버.
- `Memo.childMemoIds` + `migrateComboModelIfNeeded`/`LegacyMemoFields`/`attachedTemplateId` ← 마이그레이션/디코드 전용.

## 검증
- iOS 테스트 타겟 빌드 + 294 테스트 그린 + 제네릭 iOS 디바이스 빌드 그린.

---

# 템플릿 탭 → 키보드 스타일 값 입력 하프모달 (2026-06-09)

## 요청
- 템플릿 메모를 탭하면 값 입력 하프모달이 올라오고, 우상단 복사 버튼 + 복사될 결과 미리보기.
- 키보드 익스텐션의 TemplateInputOverlay와 동일한 UI 사용.

## 구현 ✅
- [x] `TemplateFillSheet` (Screens/Template/TemplateSheets.swift에 추가 — 메인 타겟이 명시적
      pbxproj 참조라 새 파일 대신 기존 파일에 합침).
  - 컬러 프리뷰(채운 값 초록, 빈 변수 {토큰}) — 키보드 coloredPreviewText 이식.
  - 숫자 토큰: 1-9 키패드 + ⌫ + 00/000/0000 + 저장값 칩 (키보드 PlaceholderInputView 이식).
  - 텍스트 토큰: TextField(직접 입력) + 저장값 빠른 선택 칩.
  - 우상단 "복사" 버튼(모두 채워야 활성) → 입력값 히스토리 저장 후 resolved 문자열 복사.
  - `.presentationDetents([.medium, .large])` 하프모달.
- [x] 탭 라우팅(processMemoAfterAuth): 템플릿 → 하프모달. 단, 자동 변수({날짜})만 있으면 바로 복사.
- [x] SheetModifiers: selectedTemplateIdForSheet → TemplateFillSheet로 교체(기존 편집시트는 폴백).
      편집은 셀 메뉴 onEdit로 계속 접근 가능.

## 검증
- 빌드(테스트 타겟/제네릭 iOS) 그린 + 294 테스트 그린.

---

# iCloud 백업/복원 무결성 테스트 + 메모 타임머신 테스트 (2026-06-11)

## 요청
- 아이클라우드를 포함, 사용자가 쓰는 기능들의 정상 동작 무결성을 테스트 코드로 보장.

## 구현 ✅
- [x] **CloudKitBackupService 테스트 가능 리팩토링** — `CloudKitBackupDatabase` 프로토콜 신설
      (record(for:)/save/deleteRecord), CKDatabase가 그대로 채택. 계정 상태도 클로저 주입.
      테스트 전용 init(database:accountStatus:)는 타이머·리스너·초기백업 부작용 없음.
      shared 동작은 동일(시그니처/경로 변화 없음).
- [x] `CloudKitBackupIntegrityTests` 14건 — 네트워크 없이 mock DB로 출시 코드 경로 전체 검증:
  - 백업 레코드 구성(3 Asset+버전+날짜), 2차 백업은 기존 레코드 갱신(레코드 1개 유지)
  - **백업→로컬 전체 삭제→복원 라운드트립: Memo 전 필드 보존**(보안/즐겨찾기/템플릿 변수/
    placeholderValues/comboValues/이미지 파일명/힌트/날짜/clipCount + 클립보드·콤보)
  - 복원 시 comboModelUnifyMigrated_v1 플래그 리셋(옛 백업 재변환 보장)
  - 로컬 데이터 있으면 forceOverwrite 없이 복원 거부 + 로컬 데이터 무손상
  - 백업 없음→noBackupFound / 깨진 백업 JSON→실패해도 로컬 데이터 무손상
  - 레거시 Data 필드 백업(CKAsset 이전 포맷) 복원 호환
  - 미인증(noAccount/restricted) 시 백업·복원 거부(네트워크 시도 0회)
  - 일시적 네트워크 오류 1회 재시도 후 성공 / 권한 오류는 재시도 없이 즉시 실패
  - hasBackup 정합성, deleteBackup 후 레코드·lastBackupDate 제거
- [x] `MemoTimeMachineTests` 7건 — 변경 기록(스냅샷 링버퍼) 첫 테스트:
  - 의미 있는 변경만 스냅샷(사용량 clipCount 변경은 skip), recordHistory:false는 미기록
  - 최근 10개 링버퍼 유지, 대량 삭제 복원(전 필드), 되돌리기의 되돌리기, 없는 id는 false+무손상

## 검증
- 신규 21건 그린 + **전체 스위트 297건 그린**(기존 테스트 무회귀, 시뮬레이터 iPhone 17 Pro).

## 남은 것 (실기기/실계정에서만 가능)
- [ ] 실제 iCloud 계정으로 기기 A 백업 → 기기 B 복원 E2E (CKContainer 실연결)

---

# 커버리지 갭 검토 + 미커버 기능 테스트 27건 추가 (2026-06-11)

## 요청
- 버그 신고를 받기 전에 보장 안 된 기능이 없는지 검토하고 테스트 보강.

## 갭 분석 결과 → 테스트 추가 ✅
- [x] `CategorySidecarTests` 6건 — **카테고리 다운그레이드 안전장치(완전 미검증이었음)**:
      save 시 비기본만 사이드카 기록 / 유실(기본·빈값)만 복원·사용자 변경은 보존 /
      다운그레이드 재저장→load 치유 왕복 / 의도적 "기본" 이동은 부활 안 함 / 기존 사용자 부트스트랩
- [x] `SmartClipboardLifecycleTests` 6건 — 복사 시 자동 분류, 중복은 맨 앞 이동(무중복),
      요금제별 개수 제한(무료50/Pro100), 7일 지난 임시 항목 정리(보관 항목은 유지),
      사용자 분류 수정 영속, 레거시 clipboard.history.data → 스마트 마이그레이션(id 보존)
- [x] `MemoListSortingTests` 4건 — 즐겨찾기 우선→최근순, 수동 순서 시 즐겨찾기 고정 해제,
      순서 미등록 새 메모 맨 위, commitReorder 영구 저장+새 ViewModel 재현
- [x] `BuiltInCategoryTests` 4건 + `CategoryTabStorageTests` 2건 — 타입별 모아보기 판정
      (템플릿은 메모+템플릿 탭에도 포함, mixed는 이미지 탭), 탭 storageKey 왕복(한글·이모지 포함)
- [x] `KeyboardUsageTrackerTests` 4건 — 일일 카운트, 절약 시간 누적(40자=9초), 음수 clamp, 날짜 스코프
- [x] `TemplateBraceDisplayTests` 1건 — 칩 라벨 중괄호 제거

## 검증
- **전체 스위트 324건 그린**(297 + 신규 27, 시뮬레이터 iPhone 17 Pro).

## 남은 갭 (현 구조로는 단위 테스트 불가 — 인지하고 관리)
- [ ] `migrateComboModelIfNeeded`/`hasLegacyComboData` — ClipKeyboardApp에 private.
      테스트하려면 별도 타입으로 추출 필요(마이그레이션 로직 이동 리스크 있어 보류). 실기기 검증 항목 유지.
- [ ] 키보드 익스텐션/위젯의 Memo 복사본(Shared/Models/SharedModels.swift) — 익스텐션 타겟에
      테스트 타겟이 없음. 메인 Memo와 디코더 동기화는 코드 리뷰로 관리(memo_codable_backcompat 참고).
- [ ] `grandfatherPaidUserIfNeeded` — AppTransaction(StoreKit) 의존, Sandbox/실기기 전용.
- [ ] UI 레이어(시트 라우팅·애니메이션·키보드 익스텐션 UI) — 단위 테스트 범위 밖, 실기기 체크리스트로.

---

# 키보드 익스텐션 타이핑 로직 테스트 33건 추가 (2026-06-11)

## 요청
- 키보드 익스텐션 입력(타이핑) 쪽도 테스트로 커버.

## 방법
- HangulComposer/CheonjiinInput은 익스텐션 타겟 소속이지만 **순수 Foundation 로직 +
  HangulInputProxy 프로토콜 추상화**라, pbxproj에서 두 소스를 ClipKeyboardTests 타겟에도
  컴파일하도록 등록(PBXBuildFile 2건 + 테스트 타겟 Sources phase).
- `FakeHangulProxy`(insertText/deleteBackward를 텍스트 버퍼로 재현) → **fake의 text가
  사용자가 키보드에서 보는 글자** 그대로를 검증.

## 구현 ✅
- [x] `HangulComposerTests` 18건 — 2벌식 조합:
      기본 음절(한/한글/꼬), 받침 이동 도깨비불(안+ㅏ=아나), 겹받침 분해 이동(읽+ㅓ=일거),
      복합 모음(과/희), 겹받침(읽), 종성불가 ㄸ 처리(바따), ㅇ초성 자동(가오),
      백스페이스 단계 되돌리기(한→하→ㅎ→∅, ㄺ→ㄹ, ㅘ→ㅗ), 비한글 commit(가!나), commit 후 글자단위 삭제
- [x] `CheonjiinInputTests` 15건 — 천지인:
      자음 multi-tap 순환(ㄱ→ㅋ→ㄲ→ㄱ), 0.5초 타임아웃 시 새 글자(ㄱㄱ), 다른 키로 사이클 중단,
      모음 획 진화(이→아→야), ㅐ 조합, 단독 ㆍ 임시표시→해석(ㅓ), 음절 완성(한),
      받침 이동(간+ㅏ=가나), 백스페이스(자음 전체 삭제/획 되돌리기 야→아/임시 ㆍ 제거),
      commit(음절 확정/미완성 획 폐기 — 쓰레기 문자 방지)

## 검증
- **전체 스위트 357건 그린**(324 + 신규 33). 익스텐션은 앱 임베드로 함께 빌드 확인.

## 여전히 자동화 불가 (실기기 수동 체크리스트)
- [ ] KeyboardViewController의 입력 핸들링(메모 탭→insertText, 콤보 순차 입력) — UIInputViewController 의존
- [ ] 시스템 레벨 E2E(서드파티 키보드 활성화·전환·실제 앱에서 타이핑) — iOS 제약상 XCUITest 불가

---

# 메인 화면 검색 키보드가 안 내려가는 문제 수정 (2026-06-11)

## 원인
- 검색 포커스(isSearchFieldFocused) 해제 경로가 돋보기 토글 버튼 단 하나뿐.
  iOS는 배경 탭으로 키보드를 자동으로 닫지 않으며(항상 opt-in), 메모 그리드는
  일반 ScrollView라(List/Form과 달리) 스크롤 시 자동 dismiss도 없었음.

## 수정 ✅
- [x] ClipKeyboardList.screenBody의 ZStack(메모 영역)에:
  - `.simultaneousGesture(TapGesture → isSearchFieldFocused = false)` — 빈 곳/카드
    어디를 탭해도 키보드 닫힘. simultaneous라 카드 탭 동작(복사 등)은 그대로 실행.
  - `.scrollDismissesKeyboard(.immediately)` — 그리드 스크롤/탭 페이지 스와이프 시 닫힘.
- 검색바 자신은 safeAreaInset 분리 영역이라 탭해도 포커스 안 풀림(재탭 깜빡임 없음).
- [x] ClipKeyboard 스킴 빌드 그린.

## 검증 필요 (시뮬레이터/실기기)
- [ ] 검색 중 메모 카드 탭 → 키보드 내려가면서 복사 동작 정상
- [ ] 빈 공간 탭/스크롤/페이지 스와이프 → 키보드 내려감
- [ ] 검색 필드 재탭 → 키보드 유지(깜빡임 없음)

---

# 메모 카드 속 "내용 힌트" — 맺혔다 흩어지는 미리보기 (2026-06-11)

## 요청 (3차 확정)
- 1차: 타이틀 아래 통계 띠(반려). 2차: 카드 속 내용이 물고기처럼 좌우 유영(반려 — "좀 별로,
  깔끔하고 우아하게. 힌트는 주고 싶은데 지저분하지 않게").
- 확정: **움직임 없이 제자리에서** 블러가 걷히며 살며시 맺혔다가, 머문 뒤 흩어지듯 사라지는 힌트.

## 구현 ✅
- [x] `ContentHintPreview` (ClipKeyboardListComponents.swift, 구 FishbowlContentPreview 교체):
  - 주기 14~18초(메모 id 시드별) 중 6초만 노출:
    **맺힘 0.9s**(blur 4→0, 3pt 아래서 떠오름, 페이드 인) → **머묾 4.2s**(또렷) →
    **흩어짐 0.9s**(blur 0→4, 살짝 떠오르며 페이드 아웃) → 휴식 8~12s(빈 공간).
  - smoothstep(easeInOut) 곡선, 좌우 이동·기울기·둥실거림 전부 제거 — iOS 알림 텍스트 톤.
  - 시드 기반 위상 분산(카드들이 동시에 깜빡이지 않음), allowsHitTesting(false),
    accessibilityHidden, reduceMotion=페이드만(blur·rise 없음).
- [x] 호출부 이름 교체 외 동일: fishbowlText(보안 메모 nil) + 영역 상시 확보(높이 균일).

## 검증 ✅
- 빌드 그린. 시뮬레이터 프레임: "간단 인사말" 힌트 또렷 + "내 이메일"은 블러에 싸여 맺히는 중
  (위상 분산 확인), 5초 뒤 앞 힌트는 사라지고 "이름 + 연락처"에 "2 items" 등장.
- 검증 권장(실기기): 머묾 4.2s/휴식 길이 취향, 다크모드 가독성, reduceMotion.

## 후속 조정 (2026-06-11, 사용자 피드백 "좋고")
- [x] **더 가끔 등장**: 기본 주기 14~18s → 24~31s(보통). 빈도 3단계 `ContentHintPace`:
      여유롭게(38~48s) / 보통(24~31s, 기본) / 자주(14~19s).
- [x] **설정 추가** (설정 → 메모 표시): "메모 내용 힌트" 토글(기본 ON) + "등장 빈도"
      세그먼트 피커(토글 OFF면 비활성). @AppStorage contentHintEnabled / contentHintPace.
      끄면 힌트 영역 자체가 사라져 완전한 제목-only 카드로(전 카드 동일 → 높이 균일 유지).
- [x] **폰트 .caption2 → .body**, zoneHeight 16 → 22.
- [x] Localizable.xcstrings 신규 키 5개(ko+en/id): 메모 내용 힌트/등장 빈도/여유롭게/자주/푸터 설명.
- [x] 빌드 그린 + 시뮬레이터 확인(.body 크기 힌트 교대 등장).

## 후속 조정 2 — 등장 기준 변경 + 키보드 확장 (2026-06-11)
- 요청: "사용자가 화면을 봤을 때에는 안 나오다가 **2초 머물면** 지금처럼 보이다가 사라지게.
  설정은 유지. 키보드에도 비슷하게 — 공간이 좁으니 **타이틀을 잠시 감추고 내용을 보였다가
  다시 타이틀로**."
- [x] **앱 카드 힌트 — 주기 반복 → 등장 1회**: `ContentHintPreview` 재작성.
      카드가 화면에 나타나 2초 머묾 → 맺힘 0.9s → 머묾 4.2s → 흩어짐 0.9s → 끝.
      `.task` 기반(화면 이탈 시 취소·재등장 시 처음부터). TimelineView 20fps 상시 구동 제거(배터리↓).
      seed·`ContentHintPace`(빈도 3단계) 삭제 — 반복이 없어져 빈도 개념 소멸.
- [x] **설정**: "메모 내용 힌트" 토글 유지, "등장 빈도" 피커 제거, 푸터 설명 갱신(2초 기준 +
      키보드 동작 + 보안 메모 미노출). `contentHintEnabled`를 **App Group**으로 이동
      (키보드 공유). xcstrings: 등장 빈도/여유롭게/자주/구 푸터 키 삭제, 새 푸터 키 추가(ko+en/id).
- [x] **키보드 — 제목 ↔ 내용 스왑** (`MemoTitleHintSwap`, KeyboardView.swift):
      셀 등장 2초 후 제목이 내용으로 크로스페이드(0.4s, 블러 3pt) → 3.2s 읽힘 → 제목 복귀.
      등장당 1회. 보안 메모·이미지·설정 OFF는 nil → 스왑 없음. VoiceOver는 버튼 라벨 그대로.
- [x] MemoPreviewFormatter.swift를 키보드 익스텐션 타겟에 추가(pbxproj),
      `String.strippingTemplateBraces`를 HighlightedTextEditor → MemoPreviewFormatter로 이동
      (키보드 타겟 공유). xcstrings는 키보드 타겟에 이미 포함 → "%d items" 등 번역 그대로 동작.
- [x] 빌드 그린(앱+키보드+위젯) + 전체 테스트 그린.
- [ ] 검증 권장(실기기): 키보드 셀 스왑 가독성(좁은 셀에서 긴 내용 2줄), 머묾 시간 취향,
      스크롤 시 재등장 빈도가 과하지 않은지.

## 후속 조정 3 — 시차 분산 + 콤보 첫 값 (2026-06-11)
- 요청: "한 번에 다 머물다 사라질 필요 없다, 감각적으로 임의의 패턴으로"(앱·키보드 모두) +
  "콤보는 모든 곳에서 첫 번째 값이 표시되도록".
- [x] **앱 카드**: seed(메모 id 해시) 기반 결정적 편차 — 등장 지연 2.0~3.6s,
      머묾 3.6~5.4s. 2초 바닥값은 유지, 카드들이 하나둘 맺혔다 제각각 흩어진다.
      (splitmix64풍 해시 → 0..<1, salt로 지연/머묾 독립)
- [x] **키보드 셀**: 동일 방식 — 스왑 시점 2.0~3.6s, 읽힘 2.8~4.2s.
- [x] **콤보 미리보기**: "%d items" → **"첫 값(≤28자) · %d items"**
      (MemoPreviewFormatter.comboPreview — 앱 카드 힌트·리스트 행·키보드 스왑 모두 공통).
      기존 테스트 comboPreviewShowsCount(숫자 포함 검사)와 호환.
- [x] 빌드 + 전체 테스트 그린.

## 후속 조정 4 — 커스텀 힌트 + 주기 반복 + 키보드 전환 완화 (2026-06-11)
- 요청: ① 보이고 싶은 값을 직접 넣으면 그걸 표시(만들기/수정에서 힌트 입력 +
  "키보드에 표시할 이름과 같이 표시" 동기화 토글), ② 앱 힌트는 켜둔 동안 주기적으로
  반복(휴식 4~10초 괜찮음), ③ 키보드는 너무 확확 바뀜 → 더 천천히.
- [x] **모델**: 기존 `Memo.hint`(컨텍스트 힌트, UI 미연결 상태였음)를 카드/키보드 표시에 연결.
      신규 `hintShownOnKeyboard: Bool = true`(decodeIfPresent ?? true — 하위호환,
      신규 키 추가라 구버전 디코더 안전). 라운드트립+구버전 기본값 테스트 추가.
- [x] **MemoAdd(풀 모드)**: titleInputSection 아래 "내용 힌트 (선택)" 입력 +
      힌트가 있을 때만 나타나는 동기화 토글(기본 ON). ViewModel 로드/저장/리셋 연결.
      xcstrings 신규 키 4개(ko+en/id).
- [x] **표시 우선순위**: 커스텀 힌트 > 자동 요약. 커스텀 힌트는 직접 쓴 한 줄이라
      보안 메모에도 표시(자동 요약은 여전히 보안 메모 미노출). 키보드는 동기화 토글
      OFF면 해당 메모 스왑 없음.
- [x] **앱 카드 주기 반복**: 1회성 → 맺힘·머묾·흩어짐 후 휴식 4~10s(seed별) 쉬고 다시 맺힘.
      앱을 켜둔 동안 반복, 화면 이탈 시 task 취소.
- [x] **키보드 전환 완화**: 크로스페이드 0.4s → 1.0s, 읽힘 3.2~4.6s.
- [x] 빌드 + 전체 테스트 그린(신규 테스트 포함).

---

# iOS ↔ macOS 저장체계 동기화 (2026-06-12)

## 맥앱 업데이트 (Models.swift / CloudKitBackupService.swift)

- [x] `Memo.hint` 필드 추가 — 맥에서 저장 시 iOS 힌트가 영구 손실되던 버그 수정
- [x] `OldMemo` 폴백 디코딩 추가 (1.x 포맷 마이그레이션, iOS와 동일)
- [x] `preloadLocalizedStrings`에 v4.0 항목(IBAN/SWIFT/VAT/Crypto/PayPal) 동기화
- [x] 맥 CloudKitBackupService에 `CloudKitBackupDatabase` 테스트 시임 추가 (iOS와 동일 구조)
- [x] 맥 복원 시 `comboModelUnifyMigrated_v1` 플래그 리셋 (iOS와 동일)

## 백업/복원 무결성 테스트

- [x] `scripts/roundtrip/run_roundtrip_test.sh` — 실제 양쪽 모델 소스로
      iOS 인코딩→맥 디코딩→맥 재인코딩→iOS 디코딩 전 필드 보존 검증
- [x] 수정 전 모델로 돌리면 hint 손실로 실패함을 확인 (테스트 유효성 검증)
- [x] macOS 타겟 빌드 그린
- [x] iOS 전체 테스트 스위트 (CloudKitBackupIntegrityTests 포함) 그린
- [x] (부수 수정) KeyboardUsageTrackerTests 날짜 잔존값 격리 버그 수정
      — 전날 실행이 남긴 어제 키 때문에 다음 날 반드시 깨지던 테스트

---

# 정적 리터럴 중앙화 + 미사용 import 정리 (2026-06-15)

## 미사용 import 제거
- [x] `ColorExtension.swift`의 `import LeeoKit` 제거 (실제 사용 0건, 주석만 LeeoKit 언급).
      나머지 20개 파일은 LeeoKit 심볼을 실제 사용 중 → 유지. AppTheme stale 주석 정정.

## 정적 문자열·이미지 심볼 단일 출처화 (AppGroup.swift 패턴, 3개 타겟 공유 enum)
- [x] `AppSymbol.swift` — SF Symbol 125종(systemName/systemImage 290곳 치환).
- [x] `DefaultsKey.swift` — UserDefaults 키 36종(forKey 92곳) + 프로/그랜드파더링/템플릿
      키 10종(iOS·Mac 중복 정의 제거, 정의를 DefaultsKey로 위임).
- [x] `AppNotification.swift` — Notification.Name 19종 통합. 기존 분산 선언
      (NotificationExtension.swift ×2, ComboExecutionService extension) 제거.
- [x] `StorageFile.swift` — App Group 저장 파일명 5종. AppGroupStorage.FileKey는
      raw-value enum → computed `fileName`(StorageFile 위임)으로 변경.
- [x] pbxproj: 4개 파일을 ClipKeyboard/Extension/.tap 3개 타겟에 등록(xcodeproj gem).
- [x] iOS·macOS 빌드 그린 + 전체 테스트 스위트 그린.
- [x] 재현용 도구: `scripts/centralize/` (gen_constants.py, add_files.rb, replace_literals.py).

---

# 검색 결과 없음 — 빈 화면 개선 (2026-06-15)

- 요청: 검색 결과가 없을 때 "결과 없음"을 분명히 알리고 "이런 걸 만들어 보는 건
  어떠세요?"라고 제안. 단, 제안 모습이 우리가 쓰는 실제 메모 카드와 같아야 함
  (지금은 완전 다른 메모가 보임).
- [x] `tabPageView` 최상단에서 "검색 중 + 결과 0" 가로채기 → 모든 탭 일괄 처리.
      기존 switch는 `tabPageContent(for:filtered:)`로 분리.
- [x] `searchNoResultsView` — "'검색어' 검색 결과가 없어요" + "이런 메모를 만들어
      보는 건 어떠세요?" 피드백. 메모 0개용 EmptyListView(다른 디자인) 대신 사용.
- [x] `searchSuggestionCard(query:)` — ghostMemoCell과 동일 비주얼(실제 메모 카드
      치수·제목 스타일 + 반투명·점선). 2열 그리드에 배치해 진짜 카드처럼 보임.
      탭 시 검색어를 키워드로 채운 편집기 진입(기존 ghostAddPattern 시트 재사용).
- [x] xcstrings 신규 키 5개(ko 소스 + en/id 번역).
- [x] iOS 빌드 그린 + 전체 테스트 그린.

---

# 메모 실시간 동기화 (iPhone ↔ Mac) — CKSyncEngine (2026-06-15)

목표: App Group이 기기별이라 갈라지던 메모를 CloudKit으로 근실시간 동기화. Pro 전용,
메모만(이미지·보안메모 암호문·콤보 포함). 저장소는 기존 JSON 유지.

- [x] `MemoSyncCore.swift`(순수 로직) — id 단위 최신우선 병합 + 툼스톤(소프트 삭제) +
      섀도 diff. `MemoSyncCoreTests` 10케이스 그린(병합/충돌/삭제 경쟁/되살림).
- [x] `MemoSyncEngine.swift` — CKSyncEngine 래퍼. 커스텀 존 `MemosZone`, 레코드타입
      `Memo`(payload/lastEdited/deletedAt + 이미지 CKAsset). push(저장 훅→섀도 diff→enqueue)
      / pull(수신→merge→MemoStore.save→.dataRestored). 에코 루프 차단(isApplyingRemoteChanges).
      상태/섀도/툼스톤은 App Group에 영속. **플래그 OFF 기본**(DefaultsKey.memoSyncEnabled) + Pro 게이팅.
- [x] iOS 엔티틀먼트 `aps-environment`=development + Info.plist `remote-notification` 백그라운드.
- [x] 트리거: iOS onAppear `startIfEnabled` + scenePhase active `syncNow`; Mac autoRestore 후
      start + `applicationDidBecomeActive` syncNow. Mac `MemoStore.save`가 `.memoDataChanged` 발행 추가.
- [x] 초기 정합화: 시작 시 빈 섀도 대비 전체 업서트 + fetch로 자연 수렴.
- [x] iOS·Mac 빌드 그린 + 전체 테스트 그린.
- [x] **활성화 UI**: 설정 → "데이터 & 보안" 아래 "기기 간 동기화 (베타)" 섹션에 토글 추가.
      Pro 게이팅(비Pro는 페이월), 켜면 즉시 `startIfEnabled`. 플래그는 App Group + **iCloud KV**
      양쪽 기록 → 한 기기에서 켜면 다른 기기로 전파(Pro 상태와 동일). 포그라운드 핸들러가
      `startIfEnabled` 먼저 호출해 막 켜진 기기도 활성화. xcstrings 신규 3키(ko+en/id).
- [ ] **남은 검증**: 실제 동기화는 iCloud 2대 필요(샌드박스 검증 불가). 푸시 실시간 전달은
      CKSyncEngine 자동 구독에 의존 — 기기 검증 필요(포그라운드 동기화는 동작). 검증 후
      `aps-environment`=production 전환 + (원하면) 기본 ON.

---

# 백업/복원에 이미지 포함 (2026-06-15)

문제: 기존 CloudKitBackupService 백업은 메모/콤보/스마트클립보드 JSON만 담고, 첨부 PNG는
빠져 있었음 → 새 아이폰·맥 복원 시 이미지 메모가 그림 없이 깨짐.

- [x] iOS·Mac `CloudKitBackupService`에 `attachImages(to:memos:)` / `restoreImages(from:)` 추가.
      메모가 참조하는 PNG(App Group Images/)를 백업 레코드에 `imageAssets`(\[CKAsset\]) +
      `imageNames`(\[String\])로 첨부, 복원 시 본문 저장 **전에** Images/에 기록(깨진 참조 방지).
      이미지 없으면 필드 비워 잔존 이미지 정리.
- [x] iOS·Mac 빌드 그린 + 전체 테스트 그린(CloudKitBackupIntegrityTests 포함).
- [x] **새 기기 첫 실행 안내**(자동 복원 대신 일회성 안내): 시작 시 ① 안내 미표시 ②
      로컬에 내 메모 없음 ③ iCloud에 실제 백업 존재 → "기존 메모를 불러올 수 있어요" 알림
      1회 노출. "불러오기"→백업/복원 화면 시트. 표시 시 `restoreHintShown_v1` 기록(1회).
      백업 없으면 안 뜸(신규 유저 보호). xcstrings 신규 3키. iOS 빌드+테스트 그린.

---

# 빠른 메모(Quick Note / Inbox) 기능 (2026-06-18)

애플 메모앱의 "빠른 메모"처럼 어디서든 빠르게 캡처 → 보관함(Inbox)에 보류 →
나중에 "키보드 메모로 저장(승격)/삭제" 결정. 정식 Memo 와 분리된 별도 저장소.

## A. 기반 (공유) ✅
- [x] `StorageFile.quickNotes = "quicknotes.data"`
- [x] `AppNotification`: `.quickNotesChanged`, `.openQuickNoteInbox`
- [x] `AppSymbol`: trayFull, trayAndArrowDownFill
- [x] `DefaultsKey.pendingOpenQuickNoteInbox`
- [x] `Model/QuickNote.swift` — 관용 Codable(createdAt=epoch Double), toMemo() 승격
- [x] `Service/QuickNoteStore.swift` — add/update/remove/promoteToMemo, App Group 파일

## B. 앱 내 Inbox UI ✅
- [x] `Screens/List/QuickNoteInboxView.swift` — 목록·편집/추가 시트·빈상태·스와이프(승격/삭제)
- [x] 메인 리스트 "더보기" 메뉴에 보관함 진입(배지 카운트)

## C. 공유 익스텐션 → Inbox ✅
- [x] ShareViewController: memos.data 직접 저장 → quicknotes.data(Inbox) 보류 저장
- [x] (부수) 기존 공유 익스텐션의 contentType/날짜 스키마 버그 회피(올바른 rawValue/epoch)
- [x] 공유 시트 문구 "Add to Inbox"로 변경

## D. Shortcuts / 액션 버튼 ✅
- [x] `QuickNoteAppIntents.swift` — AddQuickNoteIntent(백그라운드), OpenQuickNoteInboxIntent, AppShortcutsProvider

## E. Control Center / 잠금화면 (iOS 18) ✅
- [x] `widget/QuickNoteControl.swift` — ControlWidget + 인텐트(App Group 플래그 → 앱이 활성화 시 소비)
- [x] widgetBundle 등록, 앱 didBecomeActive 에서 보류 플래그 소비

## 다국어 ✅
- [x] Localizable.xcstrings 신규 키 28개 ko/en/id 추가
- [x] 공유 익스텐션 타겟에 Localizable.xcstrings 멤버십 추가(공유 시트 현지화)

## 빌드 ✅
- [x] xcodebuild ClipKeyboard 스킴 BUILD SUCCEEDED (앱+위젯+공유 익스텐션 임베드)

## TODO / 후속
- [ ] 위젯/Control 자체 문자열은 위젯 번들에 카탈로그가 없어 미현지화(컨트롤 라벨 일부) — 필요 시 위젯 타겟에도 카탈로그 추가
- [ ] 실기기에서 Control Center 컨트롤 추가→앱 열림→Inbox 이동 동작 확인
- [ ] Shortcuts/Siri/액션 버튼에서 AddQuickNoteIntent 동작 확인

---

# 빠른 메모 발견성(Discovery) 3종 (2026-06-18)

"기능을 어떻게 알릴까" — TipKit 단독이 아니라 3층 구조로 구현.

## ① 가시성: Inbox 상단 배너 ✅
- [x] `QuickNoteInboxBanner`(QuickNoteInboxView.swift) — 메인 리스트 상단, "Inbox · N개 정리 대기"
- [x] ClipKeyboardList mainColumn에 배치(categoryLargeTitle 아래, 첫 배너)
- [x] 닫으면 현재 개수 기억(inboxBannerDismissCount) → 새 캡처로 더 쌓이면 재노출
- [x] 메뉴 배지 카운트는 기존 구현(B단계) 유지

## ② TipKit 맥락 팁 ✅
- [x] `QuickNoteInboxTip`(Tips.swift) — rule: engaged==true(앱 2회 이상 실행)
- [x] 더보기(⋯) 메뉴 버튼에 popoverTip 부착, "어디서든 담아 보관함에 모여요" 외부 캡처 안내
- [x] onAppear에서 appLaunchCount>=2면 engaged=true

## ③ What's-New 시트 ✅
- [x] `WhatsNewView.swift`(Screens) — 빠른 메모 3가지 설명 + "보관함 열기"/"나중에"
- [x] `WhatsNewContent.version="4.3.4"`, `DefaultsKey.lastSeenWhatsNewVersion`/`appLaunchCount`
- [x] ClipKeyboardApp.maybeShowWhatsNew(): 첫 실행(신규설치)은 표시만, 업데이트 유저(launch>=2)·미열람·타 모달 없을 때 1회 노출

## 다국어 ✅
- [x] Localizable.xcstrings 신규 키 12개 ko/en/id 추가 (총 1450)

## 빌드/테스트 ✅
- [x] BUILD SUCCEEDED + TEST SUCCEEDED

---

# 버그픽스: 앱이 실기기에서 실행 안 됨 (2026-06-18)

## 증상
- 빌드는 성공하나 실기기/구버전 시뮬레이터에서 설치·실행 안 됨.

## 원인
- `IPHONEOS_DEPLOYMENT_TARGET = 26.0` (12개 빌드 config 전부) — iOS 26 이상에서만 설치 가능.
  최신 SDK(26.x) 시뮬레이터에서만 돌아가서 "빌드만 성공"으로 보였음.
- CLAUDE.md 명시 최소 지원 = iOS 17, RECOMMENDED=15.0 → 26.0은 (공유 익스텐션 추가 등으로) 잘못 올라간 값.

## 수정
- [x] IPHONEOS_DEPLOYMENT_TARGET 26.0 → 17.0 (12개 config 전부)
- [x] 빌드 검증: 17.0 타겟에서 BUILD SUCCEEDED (iOS 18+ API 미가드 사용 없음 확인)
- [x] Control Center 컨트롤은 @available(iOS 18) 가드되어 17.0에서도 안전

---

# 버그픽스: 실기기 런치 크래시 (타입 메타데이터 스택오버플로) (2026-06-19)

## 증상
- iOS 26.0 실기기 런치 직후 크래시. 시뮬(26.2) 재현 불가.
- 백트레이스: __swift_instantiateConcreteTypeFromMangledNameV2 → mainColumn.getter(VStack)
  → decodeMangledType↔decodeGenericArgs 100겹+ 재귀 → 스택오버플로.

## 원인
- mainColumn VStack의 조건부 자식(배너 5종+탭뷰)이 거대 중첩 제네릭 타입 생성 →
  기기 런타임이 타입 메타데이터 인스턴스화하다 스택 초과. (빠른 메모 배너가 마지막 한 방울)

## 수정 (909b4a3)
- [x] mainColumn → categoryLargeTitle / topBanners / categoryContent 3슬롯
- [x] topBanners(배너 5종)·categoryContent(탭뷰)를 AnyView로 타입 소거 → 중첩 깊이↓
- [x] 동작/레이아웃 불변(시뮬 렌더 확인), 빠른 메모 deferral 유지
- [x] 메모리 기록: swiftui_type_metadata_limit

## 곁다리 수정(앞서)
- [x] 배포 타깃 26.0 유지(요청), QuickNoteStore 블록 옵저버, 배너 중첩 버튼 제거

## v4.3.5 — 순서 바꾸기 개선 (사용자 피드백 반영)

- [x] 앱 버전 4.3.4 → 4.3.5 (MARKETING_VERSION 12곳 + CLAUDE.md)
- [x] 키보드 익스텐션이 '순서 바꾸기' 수동 순서를 무시하던 문제 수정
  - KeyboardViewController.sortMemos에 memoManualOrder_v1 반영 (앱과 동일 규칙)
- [x] 순서 바꾸기를 현재 카테고리 탭 범위로 제한
  - enterReorderMode: 현재 탭 메모만 재정렬 목록에 (기능 꺼짐 시 전체)
  - commitReorder: 부분 재정렬을 전체 순서에 슬롯 치환 방식으로 병합
  - 재정렬 화면 안내 문구에 카테고리 이름 표시 (신규 다국어 키 추가)
- [x] DefaultsKey에 memoManualOrderV1 / memoManualOrderActiveV1 추가 (3타겟 공유)
- [x] 회귀 테스트 3개 추가 (부분 병합 / 커스텀 탭 범위 / 기본 탭 범위)
- [x] 시뮬레이터 테스트 통과 확인 (전체 스위트 TEST SUCCEEDED)
- [ ] macOS(.tap)는 App Group UD가 기기 간 미공유라 이번 범위 제외 — 추후 검토

## v4.3.5 — 제어 센터 빠른 메모 수정 (사용자 피드백)

- [x] 제어 센터 빠른 메모 컨트롤 미동작 수정 (콜드 런치 알림 유실)
  - 원인: URL 딥링크 → NotificationCenter 알림이 리스트 구독 설치 전에 발행되어 유실
  - 위젯 컨트롤 인텐트가 App Group 보류 플래그(pendingQuickNoteAdd)를 켜도록 복원
  - 앱 URL 핸들러(quicknote)도 플래그 병행 + 리스트 onAppear 폴백 소비 추가
  - 알림 경로로 처리 시 플래그 동시 해제(중복 시트 방지)
  - Siri/단축어 OpenQuickNoteInboxIntent에도 같은 플래그 패턴 적용
- [x] 빠른 메모 담은 후 "어디서 보나" 안내 개선
  - 저장 시 토스트 "빠른 메모를 보관함에 담았어요" / 승격 시 "메모로 저장했어요"
  - (기존) 보관함 진입점: 리스트 상단 Inbox 배너 + ⋯ 메뉴 "보관함 (n)"
- [x] 시뮬레이터 빌드 성공 (BUILD SUCCEEDED) · 기기 확인 필요

## v4.3.5 — 순서 바꾸기 드래그 매끄럽게 (사용자 피드백)

- [x] 드래그 중 전체 카드 흔들림 일시정지 (repeatForever 회전과 재배치 스프링 경합 제거)
- [x] 드래그 원위치 카드: 완전 투명(0.001) → 흐릿하게(0.3)+축소 — 드롭 취소돼도 안 사라져 보임
- [x] 흔들림 위상 index → 메모 id 기반 고정 (재배치 시 애니메이션 리셋/깜빡임 방지)
- [x] 재정렬 카드 경량 렌더링 (그림자·내용 힌트 애니메이션 생략)
- [x] 스크롤 영역 전체에 드래그 상태 리셋 onDrop 안전망 추가
- [x] 흔들림 주기 0.14s → 0.22s (덜 부산하고 GPU 부담 감소)
- [x] 빌드 확인 (BUILD SUCCEEDED)

## v4.3.5 — 플레이스홀더 하이라이트 전면 적용 + 재정렬 빈 상태

- [x] templateChipAttributed에 font 파라미터 추가 + templateAwareAttributed 진입점 신설
- [x] 적용: 메인 리스트 카드 제목(재정렬 카드 포함) / MemoRowView 제목 /
      액션시트 헤더 / 길게 누르기 미리보기 제목·본문
- [x] 키보드: kbTemplateAwareAttributed 복제 후 셀 제목·최근 칩·미리보기 제목·본문 적용
- [x] 순서 바꾸기 빈 상태 안내 추가 (현재 탭에 메모 없을 때 이유 표시, ko/en/id)
- [x] 앱 + 키보드 익스텐션 빌드 성공
- [ ] "메모 다 안 보임" 증상 — 화면 특정 필요 (재정렬 화면 범위 축소 vs 기본 탭 제외 규칙)
