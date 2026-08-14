# Xcode Cloud

이 저장소가 클라우드 빌드에서 무엇을 하고, 워크플로를 어떻게 짜야 하는지.

## 왜 쓰는가

로컬에 이미 `scripts/predeploy.sh`(다국어 검사 + 전체 테스트)가 있으므로, 검증만 놓고 보면
겹칩니다. 그래도 남는 실익은 둘입니다.

1. **맥 상태와 무관하게 TestFlight 빌드가 나온다.** 기기 준비·설치가 막혀도, 맥을 닫아 두어도
   푸시하면 빌드가 굴러갑니다.
2. **매번 새로 클론한 환경에서 검증된다.** DerivedData 캐시나 로컬 서명 상태에 기대지 않아
   "내 맥에서는 되는데" 가 생기지 않습니다. 커밋을 빠뜨렸으면 그 자리에서 걸립니다.

## 저장소가 하는 일 (`ci_scripts/`)

Xcode Cloud 는 정해진 이름의 스크립트가 `ci_scripts/` 아래 있으면 알아서 실행합니다.
이름이 다르면 조용히 건너뛰고, 로그에 "script not found" 로만 남습니다.

| 파일 | 언제 | 하는 일 |
|---|---|---|
| `ci_post_clone.sh` | 클론 직후, 빌드 전 | 다국어 검사 · 긴 줄표 검사. 위반이면 **여기서 멈춘다** |
| `ci_pre_xcodebuild.sh` | 빌드 직전 | 빌드 번호를 `1000 + CI_BUILD_NUMBER` 로 채운다 |

### 싼 검사를 앞에 두는 이유

다국어 위반은 컴파일을 통과합니다. 빌드를 15분 돌리고 심사에 올린 뒤에야 영어 사용자가
한국어를 보는 식으로 드러납니다. 그 검사는 1초면 끝나므로 맨 앞에 둡니다.

### 빌드 번호에 1000 을 더하는 이유

Xcode Cloud 의 `CI_BUILD_NUMBER` 는 1부터 시작합니다. 맥에서 손으로 올린 빌드도 1, 2, 3 을
쓰므로 언젠가 정확히 겹쳐서 업로드가 거절됩니다. 1000 위쪽을 클라우드 전용으로 비워 둡니다.

마케팅 버전(`MARKETING_VERSION`)은 건드리지 않습니다. 4.4.7 은 사람이 정하는 값이고,
그것까지 자동으로 만들면 어느 버전이 나갔는지 아무도 모르게 됩니다.

## 워크플로 설정 (Xcode 에서 한 번)

Integrate 메뉴 → Manage Workflows.

### 먼저: 지금 워크플로는 옛 이름을 부르고 있다

2026-01-31 에 프로젝트 이름을 `Token memo` → `ClipKeyboard` 로 바꿨는데(bf6cd10a),
워크플로는 그 전에 만들어져 지금도 이렇게 부릅니다.

```
xcodebuild -resolvePackageDependencies -project 'Token memo.xcodeproj' -scheme 'Token memo'
```

프로젝트 경로는 **제품(Product) 생성 시 고정**되어 워크플로 편집으로는 못 바꿉니다.
지금은 저장소에 옛 이름을 받아 주는 임시 장치가 있습니다(`Token memo.xcodeproj` 심볼릭 링크 +
같은 이름의 스킴 복사본). 제대로 고치려면 제품을 지우고 다시 만든 뒤 그 둘을 지우면 됩니다.

### 권장 워크플로 둘

**① Test on push** (main 에 푸시할 때마다)

```
시작 조건   Branch Changes · main
환경        최신 Xcode · 최신 macOS
액션        Test
  스킴      ClipKeyboard
  대상      iOS Simulator (iPhone 아무거나 최신)
배포        없음
알림        실패 시 메일
```

회귀를 커밋 시점에 잡습니다. 테스트가 732개라 10분 안팎 걸립니다.

**② Release to TestFlight** (태그를 달 때만)

```
시작 조건   Tag Changes · v* (예: v4.4.7)
액션        Archive
  스킴      ClipKeyboard
  배포 준비  TestFlight (Internal Testing)
배포        TestFlight 내부 테스터
알림        성공·실패 모두
```

푸시마다 아카이브하지 않는 이유는 시간입니다. 무료 한도는 월 25시간이고, 이 프로젝트는
한 번에 10~15분을 씁니다. 하루 몇 번씩 푸시하면 금세 동납니다. 릴리즈는 태그에만 겁니다.

## 확인하는 법

두 스크립트는 클라우드 환경 변수를 흉내 내 로컬에서 그대로 돌려볼 수 있습니다.

```sh
CI_PRIMARY_REPOSITORY_PATH="$PWD" sh ci_scripts/ci_post_clone.sh
CI_PRIMARY_REPOSITORY_PATH="$PWD" CI_BUILD_NUMBER=7 sh ci_scripts/ci_pre_xcodebuild.sh
```

두 번째는 `Version.xcconfig` 를 실제로 고치므로, 로컬에서 시험했다면 `git checkout` 으로
되돌려 두세요. (클라우드에서는 일회용 사본이라 커밋되지 않습니다)

## 자주 걸리는 곳

- **스크립트가 안 돈다**: 이름이 정확한지, 실행 권한이 있는지. 권한은 저장소에 들어 있어야
  합니다(`git update-index --chmod=+x`). 맥에서 chmod 만 하고 커밋하면 반영되지 않습니다.
- **상품이 안 보인다**: 인앱 구입은 클라우드 빌드와 무관합니다. App Store Connect 등록·승인
  문제입니다. `docs/RELEASE_NOTES_4.4.7.md` 의 상품 표를 볼 것.
- **CloudKit 스키마**: 앱보다 먼저 Production 에 배포돼야 합니다. 클라우드가 대신 해 주지 않습니다.
