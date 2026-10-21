# 글로벌 마케팅 1단계: SNS 없이 외국인에게 닿기

외국어 SNS 를 운영하지 않고 쓸 수 있는 길만 모았다. App Store 피처링 추천, 인앱 이벤트, 영어권 디렉터리.
DeployBar 는 이 셋을 올리지 못하므로 **사람이 붙여 넣는다.** 모든 글은 앱에 실제로 있는 기능만 말한다(근거 커밋 · 파일을 각 문서에 적었다).

| 파일 | 무엇 | 붙여 넣을 곳 |
| --- | --- | --- |
| `FEATURING_NOMINATIONS.md` | 피처링 추천 3건 (영어 본문 + 한국어 요약) | App Store Connect ▸ 클립키보드 ▸ Featuring ▸ Nominations |
| `IN_APP_EVENTS.md` | 인앱 이벤트 2개, 24개 로케일 문구와 글자 수 표 | App Store Connect ▸ 클립키보드 ▸ 인앱 이벤트 |
| `events/event_text.json` | 이벤트 문구 원본 | (위 표의 원본) |
| `events/count_event_text.py` | 글자 수 · 한도 · 한글 섞임 검사 | `python3 marketing/global/events/count_event_text.py` |
| `events/*.png` | 이벤트 카드(3840×2160) · 상세(2160×3840) 그림 | 인앱 이벤트의 이미지 칸 |
| `events/make_event_art.py` | 그림 다시 만들기 | |
| `DIRECTORIES.md` | AlternativeTo · Apptisan · Product Hunt 제출 초안 | 각 사이트 |

## 사람이 할 일 (순서대로)

| 언제 | 할 일 | 어디 |
| --- | --- | --- |
| **지금 ~ 10/28** | 추천 1 `One keyboard for 23 languages` 제출 (게시 기간 11/18~12/17, 3주 여유 마감 10/28) | Featuring ▸ Nominations |
| 지금 | Apptisan 양식 제출 | https://tally.so/r/w8xqGO |
| 지금 | AlternativeTo 가입 · 이메일 인증 → Suggest new application | alternativeto.net |
| 5.1.13 출시 확인 직후 (늦어도 10/31) | 이벤트 1 `typing-23` 만들기: 배지 Major Update, 알림 11/04, 11/18~12/17, 우선순위 높음, 24개 로케일 문구, 그림 2장 → 심사 제출 | 인앱 이벤트 |
| 이벤트 1 승인 뒤 | 추천 1 에 이벤트 붙이기 | Nominations |
| 11/07 까지 | 추천 3 `Retype less in the new year` 제출 (12/28~1/18) | Nominations |
| 11/18 주 화~목 | Product Hunt 런칭 (갤러리 에셋 먼저) | producthunt.com |
| 11/21 까지 | 선물 상품이 출시 빌드에서 되는지 확인 → 되면 이벤트 2 `holiday-gift`(Special Event, 알림 11/28, 12/12~1/6) 심사 제출 + 추천 2 `Holiday Pro gifting` 제출 | 인앱 이벤트 · Nominations |
| AlternativeTo 승인 뒤 | TextExpander · Paste · Gboard 페이지에 대안으로 걸기 | alternativeto.net |
| 매주 | App Analytics ▸ 소스 유형 ▸ **App Store 탐색**, **인앱 이벤트** 노출 · 다운로드 확인. 탐색이 평소 2배 넘게 튀면 어딘가 실린 것 | App Store Connect |

## 알아 둘 것

- **APPSTORE.md 설명을 5.1.13 에 맞게 고쳤다(2026-10-21).** "It does not replace the keyboard you type on" 이 들어 있던 '먼저 알아 두실 것' 문단을
  24개 로케일 모두 "이제 23개 언어 자판도 있다 · 쓰던 키보드가 편하면 단축어 뒤 그리로 돌아간다 · 일본어 · 중국어 한자 변환은 아직 없다" 로 바꿨다.
  5.1.13 은 심사 대기라 그 버전의 설명은 잠겨 있다. **다음 버전(5.1.14) 배포 때 스토어에 실린다.** 추천 1 을 낼 때 제품 페이지가 아직 옛 문장일 수 있다.
- **일본어 · 중국어는 한자 변환이 없다.** 추천 1 · 이벤트 1 에서 일본 · 중국 · 대만 · 홍콩을 빼기를 권했고, ja · zh 문구에는 "다음 업데이트"라고 적었다.
- **딥링크가 없다.** 두 이벤트 모두 "열기"가 앱 첫 화면으로 간다. 다음 이벤트부터는 `clipkeyboard://typing` · `clipkeyboard://gift` 를 앱에 더하면 좋다(로드맵이 아니라 개발 안쪽 일).
- **그림은 글자 없는 일러스트다.** 실제 자판 · 선물 화면을 찍으면 더 좋다. 찍을 장면은 `IN_APP_EVENTS.md` ▸ 그림.
- 이벤트 문구를 고치면 `count_event_text.py` 를 다시 돌려 표를 갈아 끼운다.
- 기존 원고와의 관계: 앵글 모음은 `docs/marketing/APPLE_FEATURING_STORIES.md`, 7월 계획은 `docs/marketing/MARKETING_PLAN_2026-07.md`.
  그 문서들의 가격 · 데이터 수집 · 언어 수 같은 사실은 2026-10-21 에 고쳤다. 쓴 때의 기록인 글(레딧 게시글 · 7월 계획 · 스토어 문안 기록)은
  본문을 두고 맨 위에 "지금과 다른 사실" 덧붙임을 달았다(`FEATURING_NOMINATIONS.md` 맨 아래 표).
