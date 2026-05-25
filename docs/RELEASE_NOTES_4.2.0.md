ClipKeyboard v4.2.0

한국어

- 키보드에서 타자를 빨리 칠 때 첫 입력이 뚝뚝 끊기던 문제를 해결했습니다, 햅틱 엔진을 미리 깨워두고 공유해서 매 키마다 새로 생성하지 않도록 바꿨습니다 — 빠른 한글·영문 입력이 한층 부드러워집니다
- 메모 셀에서 카테고리 아이콘·즐겨찾기 하트·T/C/S 같은 작은 뱃지를 모두 빼고 제목만 가운데로 정렬했습니다, 좁은 키보드 공간에 같은 폭으로 더 긴 제목과 더 많은 메모를 보여드립니다
- 셀 높이 기본값을 56pt에서 44pt로 낮췄습니다 (기존 사용자는 본인 설정 그대로) — 한 화면에 메모가 더 많이 표시됩니다
- 템플릿·콤보·보안 메모는 셀 테두리의 색과 점선 패턴으로 구분합니다, 보라 실선=템플릿, 주황 굵은 점선=콤보, 회색 짧은 점선=보안 — 색약·색맹 사용자도 패턴만으로 구분 가능
- 계좌번호처럼 일반 메모에 템플릿이 연결된 경우, 그리드에 두 셀로 따로 표시됩니다 — 하나는 메모 원문만, 하나는 메모+템플릿 변수 입력 후 붙여넣기. 상황에 맞게 골라 쓰세요
- 키보드 익스텐션 상단의 카테고리 행을 폴더 토글로 접을 수 있게 했습니다, 평소엔 접혀서 메모 영역이 한 줄 더 확보되고 필요할 때만 펼쳐서 카테고리 점프 가능 (좌우 스와이프 전환은 그대로 동작)
- 즐겨찾기 고정 스트립(상단의 즐겨찾기 2열 그리드)을 제거했습니다, 즐겨찾기는 카테고리 페이지에서 별도로 확인할 수 있어 화면을 위/아래로 쪼개지 않습니다
- iOS 앱 메모 리스트의 카테고리 관리 진입점을 단일화했습니다, 페이지 인디케이터 옆 ⚙ 톱니 버튼은 제거하고 ... 메뉴의 "카테고리 관리" 하나로 통합
- 카테고리 관리 시트에 페르소나에 맞는 카테고리들이 미리 채워집니다, 온보딩에서 선택한 페르소나에 따라 IBAN·여권번호·VAT 같은 항목이 처음부터 후보로 표시 (한 번만 자동 적용, 삭제 시 다시 안 들어옴)
- 카테고리에 메모가 하나도 없으면 그 카테고리 탭이 자동으로 숨겨집니다, 빈 페이지로 swipe되는 일이 사라지고 첫 메모가 분류되는 순간 다시 나타납니다
- 카테고리 기능을 꺼두면 메모 셀이 흰색으로 표시됩니다, 시드된 카테고리 잔재로 색이 들어가던 문제 해결
- 메모 추가 화면에서 일반 카테고리에도 "이미지 추가" 큰 탭 버튼을 추가했습니다, 헤더 우측 작은 아이콘만 있던 이전 버전과 달리 어디를 눌러야 할지 한눈에 보입니다
- 키보드 익스텐션의 메모 셀에서 + 템플릿 분할 버튼을 제거하고 위 두 셀 분리 방식으로 대체했습니다, 같은 줄에 두 액션이 끼어 있어 좁아 보이던 문제 해소

English

- Fast typing on the custom keyboard no longer stutters on the first keystroke — the haptic engine is now pre-warmed and shared across all keys instead of allocated per tap, so quick Korean and English input flows smoothly
- Removed category icons, favorite hearts, and T/C/S badges from memo cells and centered the title — same cell width fits longer titles, and the grid shows more memos
- Default cell height lowered from 56pt to 44pt (your custom setting is preserved) — more memos visible on a single keyboard
- Templates, combos, and secure memos are now distinguished by border color and dash pattern: solid purple = template, dashed orange = combo, dotted gray = secure. Color-blind / low-vision users can identify each type by pattern alone
- When a regular memo (like a bank account number) has a template attached, it now appears as two separate cells in the grid: one for the memo only, one for memo + template variables. Pick the action you actually want
- The category row at the top of the keyboard is now collapsible via a folder toggle — collapsed by default to give memos one more row of space, and left/right swipe still switches categories
- Removed the pinned-favorites strip (the 2-column row that sat above the memo grid). Favorites live in the dedicated ★ favorites category page instead, so the screen no longer splits in half
- The iOS app now has a single entry point for category management — the gear button next to the page indicator is gone; all category management goes through "Manage categories" in the ... menu
- Category management is pre-populated based on your persona — picking nomad seeds IBAN, passport, VAT etc.; business gets work email, business card, meeting notes; students get student ID, school email, etc. (one-time seeding per persona; deleted items don't come back)
- Categories with no memos are automatically hidden from the tab strip. No more swiping into an empty page; the tab reappears the moment you add a memo to it
- With the category feature off, memo cells render with a plain white background — fixes leftover seed-category colors showing through
- Added a large "Add Image" tap button on the memo creation screen for regular categories (previously only a tiny header icon) — much clearer where to tap
- Removed the split "+ Template" button on the keyboard in favor of the two-cell approach above — no more cramped half-buttons sharing a row
