# 5.1.24 "실행이 끝나지 못한 설치 35%": 대부분 죽은 적이 없었다

2026-11-20 · 허브 30일 기록 (설치 492, 크래시 86건, `launch_incomplete` 281건)

## 한 줄

허브의 "실행 미완 171명(35%)" 은 세 가지가 한 숫자로 섞인 것이었다.
켜다가 죽은 진짜 사고는 빌드 51 이하에서 났고 지금 빌드에는 없다.
가장 큰 덩어리(`prompts`)는 iOS 가 뒤에서 깨운 실행을 멈춘 실행으로 잘못 센 것이고, 이번에 고쳤다.

## 1. 숫자를 갈라 보면

`launch_incomplete` 를 낸 설치 171대를 단계로 나누면 이렇다(한 설치가 여러 칸에 들 수 있다).

| 단계 | 건수 | 설치 | 무엇인가 |
| --- | --- | --- | --- |
| `prompts` · `controls` 등 첫 화면 뒤 단계 | 154 | 108 | 뒤에서 깨어난 실행을 잘못 셈 (2절) |
| `keyboard` | 102 | 65 | 키보드 익스텐션 쪽 기록. 이번에 보지 않았다 |
| `first-frame` | 22 | 22 | 진짜 첫 화면 멈춤과 잘못 센 것이 섞여 있다 |

## 2. 뒤에서 깨어난 실행을 멈춘 실행으로 읽었다

`prompts` · `controls` · `first-frame` 보고 173건 가운데 169건은 **앞뒤 2분 안에 다른 사용 이벤트가 하나도 없다.**
새벽에 혼자 찍힌 것도 많다. 사람이 앱을 연 실행이 아니라는 뜻이다.

iOS 는 백그라운드 새로고침으로 앱을 깨울 때도 **창(씬)을 붙인다.** 그러면 이렇게 된다.

```
뒤에서 깨어남 → 창이 붙음 → WindowGroup 내용 생성 (first-frame 표식)
  → .task 가 돌아 runLaunchSequence() 가 끝 단계까지 감 (prompts 표식)
  → 마지막 4초 대기에서 프로세스가 멈춰짐 (finish 못 부름)
  → 나중에 메모리 정리로 사라짐 → 다음 실행이 prompts 에서 멈춘 런치로 읽음
```

`closeIfBackgroundLaunch` 가 이런 실행을 닫으라고 있었지만 **씬이 하나라도 붙어 있으면 손대지 않았다.**
"화면 없이 깨어난다" 는 가정이 기기에서는 틀렸다(시뮬레이터는 `BGTaskScheduler` 가 없어 밟히지 않는다).
`scenePhase` 도 처음부터 `.background` 라 바뀌는 일이 없어 `finish()` 를 부르지 못했다.

잘못 읽히면 통계만 틀리는 것이 아니다. 그 사용자의 다음 실행이 **세이프 모드**로 열려
동기화 · 백업 · 통계 · 안내를 쉬고, 두 번 되풀이되면 `prompts` 단계가 그 버전 동안 격리된다.

### 고친 것

가르는 기준을 "씬이 붙었는가" 에서 **"앱이 뒤에 있는가"** 하나로 바꿨다(`LaunchGuard.isInBackground`).

- `closeIfBackgroundLaunch`: 앱이 뒤에 있으면 씬이 붙어 있어도 닫는다. 앞에 있으면 그대로 둔다.
- `runLaunchSequence()` 맨 앞(첫 프레임을 내보낸 뒤)에서 한 번 부른다.
- `markFirstFrameIfNeeded()` 는 다음 차례(main async)에 한 번 부른다.
  첫 화면을 그리다 멈춘 진짜 사고는 메인 스레드가 막혀 그 차례가 오지 않으므로 표식이 남는다.

시험: `ClipKeyboardTests/LaunchGuardBackgroundLaunchTests.swift`.
시뮬레이터에서 손으로 켠 실행은 닫히지 않고 예전처럼 `finish` 까지 가는 것을 로그로 확인했다.

⚠️ 5.1.24 까지의 기기에 이미 남은 표식은 업데이트 뒤 첫 실행에 한 번 더 세인다. 그 뒤로 줄어야 맞다.

## 3. 켜다가 죽은 진짜 사고는 빌드 51 이하였다

30일 크래시 86건 중 `scene-create` 워치독은 29건이고, **죽은 빌드는 전부 51 이하**다.
"5.1.24 에서 10건" 은 이름표였다. `appVersion` 은 보고서가 배달된 때 깔려 있던 버전이고,
`buildNumber` 로 보면 그 10건은 빌드 45 · 50 · 51 의 크래시 9건과 빌드 54 의 1.1초 멈춤 1건이다
(`docs/postmortem/CRASH_REPORT_SCHEMA.md` 의 경고 그대로다. 바이너리 UUID 도 그 빌드의 dSYM 과 맞았다).

| 빌드 | scene-create | scene-update | process-exit(5초) | 기타 |
| --- | --- | --- | --- | --- |
| 50 이하 | 26 | 4 | 31 | 신호 7 · 멈춤 1 |
| 51 (5.1.21) | 3 | 0 | 2 | |
| 52 (5.1.22) | 0 | 4 | 6 | |
| 53 (5.1.23) | 0 | 0 | 1 | |
| 54 (5.1.24) | 0 | 0 | 0 | 멈춤 1 (1.1초) |

죽은 자리는 한결같다. 워치독 20초 가운데 **앱이 쓴 CPU 가 19초**였다. 기다린 것이 아니라 계속 그렸다.

```
-[UIApplication _firstCommitBlock] → _UIHostingView.layoutSubviews
  → ViewGraphRootValueUpdater.render → GraphHost.flushTransactions
    → GeometryReader.Child.updateValue
      → ClipKeyboardList.categoryContent → categoryTabView (TabView 페이저)
        → 페이지마다 pageHeader → topBanners → ProFeatureManager.tier …
```

첫 프레임 한 번의 갱신 안에서 페이저 전체가 되풀이해 다시 만들어졌고, 표본마다 잎이 달랐다
(`monotonicNow` · `PersonaResolver.confident` · `trackPageScroll` · 뷰 해제).
`monotonicNow` 는 그 고리 안에서 자주 찍힌 한 자리였을 뿐 원인이 아니다.
5.1.21 이 `GeometryReader` + `TabView` 페이저를 걷어내고 카테고리 한 장으로 바꾼 뒤(빌드 52부터)
`scene-create` 는 한 건도 없다. 빌드 51 의 5건은 한 기기(iPhone15,2)에서 같은 날 났다.

## 4. 남은 것: 쓰는 중 멈춤 (빌드 52 · 53)

빌드 52 의 10건, 53 의 1건은 켤 때가 아니라 **쓰는 중**이다. 한 프레임의 갱신이 5~10초 넘게
끝나지 않았고(CPU 를 다 썼다), 사용자가 앱을 밀어 끄거나 워치독이 껐다.

```
_UIUpdateSequenceRunNext → _UIHostingView.layoutSubviews → GraphHost.flushTransactions
  → DynamicBody.updateValue (ClipKeyboardList, screenL6 의 바인딩 갱신)
  → ForEachChild.updateValue → allTabScrollView → memoGridCell
빌드 53: InterpolatedDisplayList.updateValue → 글자를 다시 그리는 애니메이션
```

한 기기(iPhone18,2)가 하루 아침에 5번 겪었다. 목록 화면의 상태가 갱신 도중에 다시 바뀌어
같은 프레임 안에서 되도는 고리로 보이지만 **재현하지 못했다.** 빌드 54 는 아직 기록이 없다(나온 지 이틀).
`.sprintcommander/tasks.json` 에 적어 두었다. 볼 곳: `trackPageScroll` 의 제목 접기(상태가 바 높이를 바꾸고
바 높이가 다시 판정을 바꾼다), `StaleScrollOffsetReset`, `CoachAnchorKey` 의 `onPreferenceChange`.

### 멈춤을 재는 시험 (2026-11-20 추가)

몽키 시험은 "죽었는가" 만 봐서 굳은 앱을 못 잡는다. 멈춘 시간 자체를 재는 길을 만들었다.

- `ClipKeyboard/Service/HangProbe.swift`: 메인 스레드가 1초 넘게 대답하지 않으면 적는 탐침(개발 빌드, `-HangProbe`).
- `ClipKeyboardUITests/ListHangUITests.swift`: 단축어 300개를 깔고 목록을 굴리며(문턱 근처 천천히 스크롤 ·
  카테고리 전환 · 탭 오가기 · 회전 · 홈 나갔다 오기) 2.5초 넘는 멈춤이 있으면 직전 동작과 함께 실패한다.

시뮬레이터에서 시드 셋(2026 · 7 · 99), 동작 620개를 돌린 결과 **쓰는 중 2.5초 넘는 멈춤은 없었다.**
가장 긴 것은 홈에서 돌아오는 순간의 1.3초였다. 켤 때는 단축어 10개든 1000개든 1초 남짓이라 개수에 비례하지 않는다.
즉 빌드 52 · 53 의 멈춤은 아직 재현하지 못했다. 시드와 동작 수를 늘려 더 돌리거나, 그 기기의 조건
(큰 글씨 · 배너가 서 있는 상태 · 카테고리 색)을 시험 데이터에 더해 볼 것.

### 고리의 재료를 걷었다 (5.1.25)

재현은 못 했지만, 한 프레임 안에서 되돌 수 있는 구조 하나를 찾아 걷었다.

- **배너 게시판이 화면 갱신 도중에 결과를 바꿨다.** 띠(`PromptRow`)는 갱신 도중에 손을 들고 내리고
  (`onChange` · `onDisappear`), 게시판은 그 자리에서 곧바로 다시 골라 `picked` 를 바꿨다. 고른 결과가 띠를
  세우거나 걷으면 다시 손이 오르내린다. 이제 한 차례에 한 번만 고른다(`PromptBoard.scheduleRecompute`).
  같은 차례에 내렸다 든 손은 없던 일이 되고, 고리는 프레임을 넘지 못한다.
  시험: `ClipKeyboardTests/PromptBoardDeferralTests.swift`.
- **배너 묶음을 목록 화면에서 떼어 냈다**(`ListTopBanners`). 배너의 상태(결제 순간 · 닫은 기록 · 이용 기간 안내)가
  바뀔 때 카드 격자까지 다시 그리던 것이 묶음 안에서 끝난다.
- **다시 그리기 폭주를 센다**(`HangProbe.noteRender`). 같은 화면이 1초에 200번 넘게 다시 계산되면 멈춤 시험이 실패한다.

⚠️ 이것이 빌드 52 · 53 멈춤의 원인이었는지는 모른다. 5.1.25 의 허브 기록(`process-exit` · `scene-update`)으로 본다.

## 다음에 같은 숫자를 받으면

1. `launch_incomplete` 는 **단계별로** 나눠 본다. `first-frame` 만 켜다가 멈춘 것이다.
2. 크래시는 `appVersion` 이 아니라 **`buildNumber`** 로 센다.
3. 허브 원본은 FeedbackHubViewer 가 받아 둔다:
   `~/Library/Containers/com.Ysoup.FeedbackHubViewer.prod/Data/Library/Application Support/FeedbackHubViewer/hub-production.json`
   (`crashes` · `events`). dSYM 은 `DeployBar --dsym 클립키보드`, 시스템 프레임은
   `~/Library/Developer/Xcode/iOS DeviceSupport/<기기 iOS 빌드>/…/Symbols` 에 `atos -offset` 으로 푼다.
4. `WatchdogCPUStatistics` 의 application CPU 가 경과 시간에 가까우면 기다린 것이 아니라 계속 그린 것이다.
