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
| 빈 것은 저장되지 않는다 | 누를 것이 없는 빈 키가 생긴다 | `BasicScenarioTests/test_이름이나_내용이_없으면_저장되지_않는다` |
| 스택 순서 입력 | 값이 빠지거나 순서가 바뀐다 | `BasicScenarioTests/test_스택은_값을_순서대로_넣는다` |
| 보안 단축어 | 파일에 평문 · `smenc1:...` 이 붙여넣어진다 | `BasicScenarioTests/test_보안_단축어는_파일에_평문이_없고_키보드는_원래_값을_넣는다` |
| 복사한 것을 단축어로 | 저장했는데 키보드에 없다 · 분류가 틀린다 | `BasicScenarioTests/test_복사한_것을_단축어로_저장하면_키보드에_실린다` |
| 복사한 카드번호를 보안으로 | 보안이라 했는데 평문 (2026-09-29 실제로 있던 버그) | `BasicScenarioTests/test_복사한_카드번호를_보안으로_저장하면_암호화된다` |
| 클립보드 기록 | 복사한 것이 분류되지 않는다 | `SmartClipboardLifecycleTests/testAdd_ClassifiesContentAutomatically` |
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
| 무료 한도의 경계 | Pro 상태가 기기의 구매 기록에 달려 시험에서 고정하기 어렵다 | `OwnShortcutLimitTests`(계산), 기기 QA |
