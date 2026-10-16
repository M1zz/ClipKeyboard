# 사용자 여정과 그것을 지키는 시험

사용자가 "완성도가 떨어진다", "기능이 이상하다"를 느끼는 순간은 대개 **부품이 아니라 이음매**에서 온다.
저장은 되는데 키보드에 안 나온다, 키보드에서 썼는데 앱의 횟수가 그대로다, 보안으로 저장했는데 평문이다.
부품 시험은 각자 통과하는데 사용자는 고장을 본다.

그래서 **사용자가 앱으로 하는 일 하나하나를 적고, 각각에 그것을 끝까지 지키는 시험을 하나씩 붙인다.**
표의 시험이 없어지면(이름을 바꾸거나 지우면) 커밋이 막힌다: `scripts/check_journeys.sh`.

## 세 겹의 문

| 언제 | 무엇이 | 무엇을 |
| --- | --- | --- |
| 커밋할 때 | `.git/hooks/pre-commit` → `check_journeys.sh` | 아래 표의 시험이 전부 있는가(몇 초) |
| 푸시할 때 | `.git/hooks/pre-push` | 여정 시험(`BasicScenarioTests`)을 실제로 돌린다(1~2분) |
| 배포할 때 | `scripts/predeploy.sh` | 전체 시험 1,390여 개 + 여정 표 검사 |

훅은 `sh scripts/install-hooks.sh` 로 설치한다. 급할 때 푸시 시험만 건너뛰려면 `SKIP_JOURNEYS=1 git push`.

## 여정 표

`시험` 칸은 `파일명/함수명` 이다. 검사 스크립트가 이 칸을 읽는다.

| 여정 | 사용자가 겪는 고장 | 시험 |
| --- | --- | --- |
| 만들고 키보드에서 쓰고 고치고 지운다 | 저장했는데 키보드에 없다 · 썼는데 횟수가 그대로 · 고쳤더니 둘이 됐다 · 지웠는데 키보드에 남았다 | `BasicScenarioTests/test_만든_단축어를_키보드에서_쓰고_고치고_지운다` |
| 즐겨찾기가 키보드 맨 앞에 | 즐겨찾기했는데 키보드에서 못 찾는다 | `BasicScenarioTests/test_즐겨찾기한_단축어가_키보드_맨_앞에_선다` |
| 템플릿 빈칸 채우기 | `{이름}` 이 그대로 붙여넣어진다 | `BasicScenarioTests/test_템플릿은_빈칸을_채워야_들어간다` |
| 긴 빈칸 값 고르기 | 주소 같은 긴 값이 가로로 넘쳐 옆으로 한참 밀어야 읽힌다 (2026-10 사용자 요청) | `PlaceholderValueLayoutTests/oneLongValueMakesList` |
| 키보드가 뜬다 (옛 복사 기록 그림) | 키보드가 열리지 않는다 (2026-10 사용자 신고, 남은 그림을 통째로 읽다 메모리 한도로 죽음) | `SmartClipboardLifecycleTests/testLegacyImages_LoadWithoutImagePayload` |
| 빈 것은 저장되지 않는다 | 누를 것이 없는 빈 키가 생긴다 | `BasicScenarioTests/test_이름이나_내용이_없으면_저장되지_않는다` |
| 스택 순서 입력 | 값이 빠지거나 순서가 바뀐다 | `BasicScenarioTests/test_스택은_값을_순서대로_넣는다` |
| 보안 단축어 | 파일에 평문 · `smenc1:...` 이 붙여넣어진다 | `BasicScenarioTests/test_보안_단축어는_파일에_평문이_없고_키보드는_원래_값을_넣는다` |
| 복사한 것을 단축어로 | 저장했는데 키보드에 없다 · 분류가 틀린다 | `BasicScenarioTests/test_복사한_것을_단축어로_저장하면_키보드에_실린다` |
| 복사한 카드번호를 보안으로 | 보안이라 했는데 평문 (2026-09-29 실제로 있던 버그) | `BasicScenarioTests/test_복사한_카드번호를_보안으로_저장하면_암호화된다` |
| 무료로 다 쓰다가 문턱을 넘는다 | 무료 기간에 결제 화면이 뜬다 · 문턱 뒤에 만든 것이 사라진다 · 새로 만들어도 안 막힌다 | `BasicScenarioTests/test_문턱을_넘어도_만든_것은_그대로고_새로_만들기에서만_결제를_묻는다` |
| 무료 기간을 세는 값 | 단축어를 지웠다 만들면 문턱을 피한다 | `FreeUseTests/test_쓸_때마다_세고_지워도_줄지_않는다` |
| 이정표 안내 | 같은 안내가 계속 뜬다 · 돈 낸 사람에게 뜬다 | `FreeUseTests/test_본_이정표는_다시_뜨지_않고_돈을_낸_사람에게는_없다` |
| 클립보드 기록 | 복사한 것이 분류되지 않는다 | `SmartClipboardLifecycleTests/testAdd_ClassifiesContentAutomatically` |
| 키보드 '최근' 탭 | 담아 둔 것이 키보드에 없다 · 한 주 지나 말없이 사라졌다 | `BasicScenarioTests/test_담아_둔_것은_키보드_최근_탭에_30일_남는다` |
| 복사하고 동작 버튼으로 담는다 | 버튼을 눌렀는데 '최근'에 없다 · 앱만 열리고 아무 일도 없다 · 붙여넣기 팝업이 두 번 뜬다 · 담은 글로 '저장할까요?' 가 또 뜬다 | `BasicScenarioTests/test_복사하고_버튼을_누르면_키보드_최근에_담긴다` |
| 다 가진 사람이 개발자를 응원한다 | 팁을 냈더니 Pro 가 열렸다(무료 사용자) · 팁 결제가 끝나지 않고 다시 뜬다 | `BasicScenarioTests/test_팁은_응원일_뿐_아무것도_열지_않는다` |
| Pro 를 선물받는다 | 코드를 넣었는데 백업 · 잠금이 안 열린다 · 다시 켜니 Pro 가 사라졌다 · 선물을 산 사람이 Pro 가 됐다 | `BasicScenarioTests/test_선물받은_Pro_는_산_Pro_와_같고_선물을_산_사람은_Pro_가_아니다` |
| 목록 '최근' 탭 | 키보드에는 '최근' 이 있는데 목록 탭에는 없다 · 앱을 켜면 단축어 대신 복사 기록이 먼저 보인다 | `BasicScenarioTests/test_키보드에_최근이_있으면_목록_탭에도_맨_앞에_선다` |
| 아이폰 듀오 펼침 | 펴도 화면이 늘어나기만 한다 · 누를 것이 접힌 선에 걸린다 · 펴면 목록 모양이 바뀐다 | `FoldLayoutTests/test_두_쪽은_접힌_선을_비우고_창_기준으로_맞는다` |
| 아이폰 듀오 펼침: 접힌 선 비움 | 탭바 · 시트 · 알림창이 접힌 선 위에 선다 · 알림창이 닫힌 뒤 보이지 않는 창이 터치를 막는다 | `FoldPresentationGuardTests/test_펴면_알림창은_고르는_쪽_판에서_뜨고_내려가면_판_창이_비켜선다` |
| 아이폰 듀오 펼침: 목록 \| 자세히 | 펴도 설정 줄을 누르면 화면이 통째로 바뀐다 · 깊이 들어가면 돌아올 길이 없다 · 미리보기가 작은 채로 남는다 | `FoldNavigationTests/test_결과_쪽에서_고르면_밀리고_뒤로는_한_장씩` |
| 키보드에서 빈칸 값 더하기 | 고를 값이 없는데 키보드에서 더할 길이 없다 · 앱 안에서 앱을 다시 열려 한다 (2026-10 사용자 요청) | `KeyboardAppLinkTests/addValueOpensAppOnlyInExtension` |
| 전체 접근이 꺼져 있다는 안내 | 진동·복사한 글이 말없이 안 돼 고장인 줄 안다 · 앱 안에서 엉뚱하게 켜라고 한다 | `KeyboardAppLinkTests/fullAccessNoticeOnlyInExtensionWhenOff` |
| 페이월 세 칸 (무료 · Plus · Pro) | Plus 를 살 길이 없다 · 아무것도 안 산 사람에게 업그레이드 값이 보인다 · 이미 Pro 인 사람에게 다시 판다 | `PaywallPlansTests/plusOwnerUpgrades` |
| 키보드 한글 입력 | 검색창에서 자모가 흩어진다 | `HangulComposerTests/testMultipleSyllables_CommitOnNewInitial` |
| 업데이트 뒤에도 데이터가 남는다 | 업데이트했더니 단축어가 사라졌다 | `MigrationCompatibilityTests/testOneLegacyItemDoesNotBreakWholeArray` |
| iCloud 백업과 복원 | 복원했더니 일부 필드가 빠졌다 | `CloudKitBackupIntegrityTests/testBackupThenRestore_PreservesAllMemoFields` |
| 빈 기기가 백업을 덮지 않는다 | 새 폰을 켜자마자 백업이 비었다 | `CloudKitBackupIntegrityTests/testAutoBackup_EmptyLocal_DoesNotOverwriteExistingBackup` |
| 두 기기 동기화 | 두 기기가 서로 다른 목록으로 굳는다 | `MemoSyncConvergenceTests/mergeIsOrderIndependent` |
| 크래시 보고가 읽힌다 | (사용자는 모름) 고칠 수 없는 크래시가 쌓인다 | `DiagnosticsStackTests/test_실제_페이로드_모양에서_dyld_는_맨_끝에_온다` |

새 기능을 내면 이 표에 한 줄을 더하고, 그 줄의 시험을 같이 쓴다. 시험 없는 줄은 검사에 걸린다.

## 시험이 볼 수 없는 것 (그래서 다른 것이 지킨다)

시험이 다 통과해도 이 목록은 여전히 사람이나 현장 신호가 본다. 여기를 "시험으로 보장된다"고 말하지 않는다.

| 사각지대 | 왜 시험이 못 보나 | 무엇이 지키나 |
| --- | --- | --- |
| 진짜 키보드 익스텐션 | 다른 앱 위에 키보드를 띄워야만 돈다. 시험은 같은 알림을 받는 앱 안 키보드(`InAppKeyboardHost`)를 본다 | 기기 QA(QARotation), 허브의 키보드 크래시 루프 신호 |
| 화면 모양 (가장 큰 글자, 다크, 번역 길이) | 논리 시험은 픽셀을 안 본다 | 기기 QA, `AccessibilityContrastTests` |
| 실기기 전용 경로 (CloudKit 실서버, 결제, MetricKit) | 시뮬레이터에 없다 | 허브의 릴리즈 건강 카드 · 크래시/멈춤 이슈 |
| 멈춤 · 워치독 | 시간과 기기 부하에 달렸다 | 허브 멈춤 이슈 + dSYM 으로 되돌리기, `check_main_thread_*.sh` |
| 아이폰 듀오의 실제 펼친 화면 | Xcode 27.0 으로 빌드한 앱은 듀오에서 호환 틀(아이폰 크기)로 떠서 펼친 배치가 켜지지 않는다. 명령줄 시뮬레이터는 펼칠 수 없다 | `-FoldPreview` 미리보기 틀(아이패드 시뮬레이터), Xcode 27.1 로 올린 뒤 듀오 시뮬레이터 · 기기 QA |
| 무료 한도의 경계 | Pro 상태가 기기의 구매 기록에 달려 시험에서 고정하기 어렵다 | `OwnShortcutLimitTests`(계산), 기기 QA |
