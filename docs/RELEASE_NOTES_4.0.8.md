ClipKeyboard v4.0.8

한국어

- 메모 한 개에 옵션 템플릿을 연결할 수 있습니다, 예를 들어 계좌번호 메모에 "이 계좌로 {금액}원 보내주세요" 템플릿을 붙여두면 사용 시 금액만 입력해서 함께 보낼 수 있습니다
- 토큰 이름에 금액·amount·price·qty 같은 키워드가 있으면 자동으로 숫자 입력으로 인식해 숫자 키패드로 입력합니다
- 키보드에서도 정산 금액 같은 즉석 숫자를 직접 입력할 수 있도록 인라인 숫자 패드와 천 단위 콤마 표시를 추가했습니다
- 입력 진행 중 최종 결과를 실시간으로 미리보기 해 사용자가 결과를 상상할 필요가 없습니다
- 계좌번호가 전화번호로 잘못 분류되던 문제를 수정했습니다, 한국 전화번호 패턴은 그대로 인식하면서 계좌번호 형식을 정확히 구분합니다
- 새 메모를 만들 때 카테고리에 맞는 샘플 데이터를 미리 채워드립니다, 예를 들어 전화번호는 010-0000-0000, IBAN은 GB82 WEST 1234 5698 7654 32 등
- 샘플이 채워진 상태에서는 "샘플 — 수정해서 사용하세요" 배너가 표시되며 한 글자라도 수정하면 자동으로 사라집니다
- 일반 템플릿과 옵션 템플릿을 시각적으로 구분합니다, 일반은 액센트색 TEMPLATE 배지, 옵션 연결은 보라색 +TEMPLATE 배지
- 설정 → 키보드 → "사용 패턴"에서 온보딩 시 선택한 페르소나를 나중에 바꿀 수 있습니다
- 메모 추가 화면을 대대적으로 개선했습니다
  - 붙여넣을 내용 입력칸이 처음에는 작게 시작하고 내용이 많아지면 자동으로 늘어납니다
  - 키보드 위에 "다음" 버튼을 추가해 내용 → 제목으로 즉시 이동할 수 있습니다
  - "활용사례에서 영감 받기" 버튼으로 시나리오를 골라 영어 템플릿을 메모로 가져올 수 있습니다, 카테고리 필터로 원하는 종류만 빠르게 찾기 가능
  - 가져온 영어 템플릿의 [Your Name] 같은 직접 수정 부분은 빨간 굵은 글씨로 강조되어 한눈에 보입니다
  - 라벨을 의미 있게 변경했습니다, "제목" → "키보드에 표시할 이름", "내용" → "붙여넣을 내용"
  - 화면 순서를 카테고리 → 활용사례 → 내용 → 이름 → 옵션 순으로 재배치
- 활용사례 화면을 한국어와 인도네시아어로 완전히 번역했습니다, 영어 템플릿 본문은 사용자가 그대로 보낼 수 있도록 영어로 유지
- 25종 카테고리 자동 분류 우선순위를 개선해 IBAN, SWIFT, VAT, 카드번호, 계좌번호 등의 인식 정확도가 향상되었습니다

English

- A memo can now have an optional attached template — for example, attach "Please send {amount} to this account" to a bank account memo, then you only need to enter the amount when using it
- Tokens whose names contain keywords like amount, price, qty, count, total are auto-recognized as numeric input and bring up the number pad
- The custom keyboard now has an inline numeric pad with thousand separators, so you can punch in one-off numbers like settlement amounts directly
- A live preview shows the final result while you're typing, so you don't have to imagine how it will turn out
- Fixed bank account numbers being misclassified as phone numbers — Korean phone patterns still detect correctly, while account formats are now properly recognized
- New memos are pre-filled with a category-appropriate sample, e.g. 010-0000-0000 for phone, GB82 WEST 1234 5698 7654 32 for IBAN, so you don't start from a blank page
- A "Sample — please edit before using" banner appears when the sample is still in place; it disappears the moment you change a single character
- Templates and optional attached templates are now visually distinct: regular TEMPLATE badge in accent color, attached +TEMPLATE badge in purple
- Settings → Keyboard → "Use case" lets you change the persona you picked during onboarding at any time
- Major improvements to the memo creation screen
  - The content input field starts compact and grows automatically as you type
  - A "Next" button on the keyboard toolbar jumps from content to title in one tap
  - "Get inspired by usage examples" pulls real-world English templates into your memo; a category filter helps you find the right one fast
  - In imported templates, parts you need to edit yourself like [Your Name] are highlighted in bold red, instantly visible
  - Labels are now meaningful: "Title" → "Name shown on keyboard", "Content" → "Content to paste"
  - Screen order rearranged: Category → Usage Examples → Content → Name → Options
- The Usage Examples screen is fully translated into Korean and Indonesian; the English template bodies stay in English so you can send them as-is
- Improved auto-classification priority across 25 categories — better detection accuracy for IBAN, SWIFT, VAT, credit card, bank account, and more
