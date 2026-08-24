# docs

이 폴더는 두 가지를 겸합니다. **밖으로 나가는 웹 페이지**와 **안에서 보는 글**입니다.
그래서 규칙이 하나 있습니다.

## ⚠️ 루트에 있는 것은 옮기지 않는다

이 폴더는 GitHub Pages 의 소스입니다. 루트의 파일은 그대로 주소가 됩니다.
`docs/tutorial.html` 은 `m1zz.github.io/ClipKeyboard/tutorial.html` 이고, 그 주소는
앱 안과 App Store 에 이미 적혀 있습니다. 옮기면 조용히 깨집니다.

| 루트에 남는 것 | 주소 |
| --- | --- |
| `index.html` | 랜딩 페이지 |
| `tutorial.html` | 사용 가이드 (앱 안에서 연다) |
| `privacy.html` · `terms.html` | 개인정보 처리방침 · 이용약관 (App Store 에 등록된 주소) |
| `accessibility.html` | 접근성 안내 |
| `favicon.png` · `app-icon.png` · `media/` | 위 페이지가 쓰는 자산 |

새 글은 아래 폴더 중 하나에 넣습니다. 웹으로 나갈 페이지가 아니라면 루트에 두지 않습니다.

## 폴더

### [release-notes/](release-notes/)

버전마다 하나씩. 앱 스토어 "이번 버전의 새로운 기능" 칸에 그대로 붙여 넣을 문안과
그 버전의 심사·배포 메모입니다. 파일 이름은 버전뿐입니다(`5.0.2.md`, 맥은 `5.0.2-macos.md`).
문안은 **특수기호를 쓰지 않은 평문**으로 씁니다. 쓰는 규칙은 [그 폴더의 README](release-notes/README.md).

`HISTORY.md` 는 저장소용 누적 기록입니다(예전 루트의 `RELEASE_NOTES.md`).

### [postmortem/](postmortem/)

죽거나 멈춘 기록. **무엇이 원인이었고 무엇을 못 밝혔는지**까지 적습니다.
같은 함정을 다시 밟지 않으려고 두는 글이라, 여기 적힌 규칙은 대개
`scripts/` 의 검사 스크립트와 짝을 이룹니다.

- `LAUNCH_WATCHDOG_4_4_6.md` - 런치 중 워치독. `CKContainer(identifier:)` 가 메인에서 기다렸다
- `HANG_PASTEBOARD_5_0_1.md` - 1.28초 멈춤. 클립보드를 메인에서 읽고 있었다 (원인 미확정)
- `CRASH_REPORT_SCHEMA.md` - 앱이 모으는 크래시 기록의 형식

### [engineering/](engineering/)

개발하며 알아낸 것과 설정 절차.

- `RELEASE_PROCESS.md` - 올리는 절차
- `XCODE_CLOUD.md` · `SHARED_SETUP.md` - 빌드와 저장소 설정
- `TESTING_GUIDE.md` · `TEST_RESULTS.md` - 시험
- `CONTROL_CENTER_APP_LAUNCH.md` · `FEEDBACK_CLOUDKIT.md` · `USAGE_STATS_HUB.md` - 기능별 기록
- `SECURITY_NOTES.md` · `SEEDING-GUIDE.md` · `usage-spec.json` · `data-model-uml.html`

### [design/](design/)

디자인 가이드와 시스템 정리. 화면을 손보기 전에 `DESIGN_GUIDE.md` 를 먼저 봅니다.

### [product/](product/)

기획과 점검. 명세(`FEATURE_SPEC.md` · `FUNCTIONAL_SPEC.md`), 접기 기준(`KILL_CRITERIA.md`),
심사 답변(`APP_PRIVACY_ANSWERS.md`), 체크리스트들. `qa-4.4.5.html` 도 여기 있습니다.

### [marketing/](marketing/)

알리는 글. ASO, Apple 피처링 제출 문안, 블로그와 커뮤니티 글, 스크린샷(`screenshots/`).

## 코드에서 문서를 가리킬 때

저장소 루트 기준 경로로 적습니다. 주석에서든 스크립트에서든 같습니다.

```swift
//  기록: docs/postmortem/HANG_PASTEBOARD_5_0_1.md
```
