# ClipKeyboard Release Notes

## v4.0.1 (build 3)

### 한국어

**Mac 앱이 완전히 새로워졌어요**
- **빠른 붙여넣기 패널** — ⌃⇧V로 어디서든 메모 패널을 띄우고, 클릭하면 바로 원래 입력 중이던 곳에 붙여넣습니다. 포커스를 잃지 않아요.
- **메뉴바 검색** — 메뉴바 아이콘을 클릭하면 즉시 검색 팝오버. Fuzzy 매치, ↑↓ 방향키로 이동, ⌘1–9로 상위 9개 즉시 선택.
- **⌥Enter로 직접 붙여넣기** — Enter는 복사, ⌥Enter는 복사 후 전경 앱에 바로 ⌘V. Preferences에서 기본값을 "바로 붙여넣기"로 바꿀 수 있어요.
- **로그인 시 자동 실행** — Preferences에서 토글 한 번.
- **우클릭 컨텍스트 메뉴** — 메모 위에서 우클릭하면 복사·즐겨찾기·수정·삭제 바로 접근.
- **네이티브 Mac Preferences** — General/Shortcuts/About 탭 구성, Mac 기본 설정 창 스타일.
- **단축키 전면 재설계** — ⌃⇧V·⌃⇧M·⌃⇧N·⌃⇧H·⌃⇧B로 통일. 다른 앱과 거의 겹치지 않아요.

**iOS 리스트 화면 리뉴얼**
- **한 줄 프리뷰** — 메모 제목 아래 실제 내용이 한 줄 보여요. 보안 메모의 카드·계좌번호는 `•••• 4829`로 자동 마스킹.
- **타입별 고유 아이콘** — 이메일·URL·카드·IBAN 등 22개 타입 각각 전용 아이콘과 컬러. 스캔 속도가 확 빨라집니다.
- **시간 기반 섹션** — 방금 / 자주 쓰는 것 / 이번 주 / 더 오래. 오래된 메모가 자연스럽게 아래로 내려가요.
- **히어로 카드** — 방금 쓴 메모가 리스트 상단에 부각되어 표시.
- **상대 시간 + 사용 빈도** — "3분 전", "오늘 2번" 같은 부드러운 신호.
- **하단 툴바 재정의** — 검색과 새 메모를 주인공으로, 나머지는 ⋯ 메뉴로 정리.

**글로벌 프리랜서 기능 추가**
- **스마트 분류 확장** — 이제 IBAN(체크섬 검증), SWIFT/BIC, VAT 번호, 비트코인·이더리움·TRON 지갑 주소, PayPal.me 링크까지 자동 인식.
- **영어 템플릿 30개 내장** — 프리랜서 인트로, 견적, IBAN 인보이스, 타임존 답장, 일정 조율, 우아한 거절 등. 비원어민도 바로 꺼내 쓰도록.
- **새 템플릿 변수** — `{timezone}`, `{currency}`, `{greeting_time}` (시간대 따라 Good morning/afternoon/evening), `{date}`/`{time}` 영어 alias.

**개선 사항**
- 키보드 익스텐션 백스페이스 롱프레스 1초 이후 단어 단위 삭제로 가속.
- 리뷰 배너 좁은 화면에서 버튼 라벨 잘림 해결.
- 메모 리스트 스와이프 삭제 기능.
- iCloud 백업 안정성 개선 (CKAsset 사용, 재시도 로직, race condition 해결).
- Mac 모든 창에서 콘텐츠가 잘리는 현상 해결 (모든 창 크기 조절 가능).
- iOS 설정 화면에 Mac 앱 소개 진입점.
- Mac Catalyst 창 기본 크기 조정.

---

### English

**A brand-new Mac app**
- **Quick Paste Panel** — Press ⌃⇧V anywhere. Click a memo and it's pasted right into the text field you were typing in. Focus stays where it was.
- **Menu bar search** — Click the menu bar icon for an instant search popover. Fuzzy matching, arrow-key navigation, ⌘1–9 for top 9 picks.
- **⌥Enter for direct paste** — Enter copies, ⌥Enter copies and pastes into the frontmost app. Flip the default in Preferences.
- **Launch at login** — One toggle in Preferences.
- **Right-click context menu** — Copy, favorite, edit, delete — right on memos.
- **Native Mac Preferences** — General / Shortcuts / About tabs, built like a real Mac settings window.
- **Redesigned shortcuts** — Unified to ⌃⇧V · ⌃⇧M · ⌃⇧N · ⌃⇧H · ⌃⇧B. Very unlikely to conflict with other apps.

**iOS list refresh**
- **Single-line preview** — See what's actually in each memo at a glance. Sensitive types like cards and accounts mask to `•••• 4829` automatically.
- **Type-specific icons** — Email, URL, card, IBAN and more — 22 types with their own icon + color. Scan-friendly.
- **Time-based sections** — Just now / Frequent / This week / Older. Older items gracefully sink.
- **Hero card** — The memo you just used floats to the top.
- **Relative time + usage counts** — "3 min ago", "Used 2× today" ambient signals.
- **Bottom toolbar redesign** — Search and "+" get the spotlight. Everything else moves into a ⋯ menu.

**Built for global freelancers**
- **Smart detection expanded** — Now recognizes IBAN (with mod-97 checksum), SWIFT/BIC, VAT numbers, BTC/ETH/TRON wallets, and PayPal.me links.
- **30 English templates built in** — Client intro, rate quote, IBAN invoice, timezone auto-reply, meeting reschedule, polite decline, and more. Designed for non-native English speakers.
- **New template variables** — `{timezone}`, `{currency}`, `{greeting_time}` (Good morning/afternoon/evening based on time), plus English aliases like `{date}` and `{time}`.

**Improvements**
- Keyboard extension: hold backspace over 1s to accelerate to word-by-word deletion.
- Review banner no longer clips on narrow screens.
- Swipe-to-delete in memo list.
- iCloud backup reliability fixes (CKAsset, retry logic, race condition resolved).
- Every Mac window is now resizable — no more clipped content.
- iOS Settings now has a "Use on other devices" card introducing the Mac app.
- Mac Catalyst default window size adjusted.

---

## v4.0.0

### 한국어
- 잠금화면 위젯 - 즐겨찾기 메모를 바로 복사할 수 있습니다

### English
- Lock Screen Widget - Copy your favorite memos instantly from the lock screen
