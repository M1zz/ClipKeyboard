# Release Notes v4.0.5

## 한국어 (Korean)

### 버전 4.0.5 업데이트

#### 신규 기능

- 일괄 가져오기 — 다른 메모 앱에서 텍스트 통째로 붙여넣고 자동으로 분할해 한 번에 저장. 분할 모드 선택(자동/구분선/빈 줄/한 줄당 한 메모) 및 항목별 미리보기와 인라인 편집 가능. 메모 추가 버튼의 메뉴에서 진입.
- 카테고리 사용자화 — 본인이 자주 쓰는 카테고리를 직접 추가, 이름 변경, 순서 변경, 삭제할 수 있어요. 설정의 카테고리 메뉴에서 관리.
- 국가별 기본 카테고리 — 첫 실행 시 기기 지역에 맞는 식별번호 항목이 자동으로 채워집니다. 한국은 주민등록번호·사업자등록번호·통관번호 등, 다른 국가도 각 현지 기준에 맞춤.
- 인도네시아어(Bahasa Indonesia) 정식 지원 — 앱 전체 UI 100% 번역 완료. 활용 사례 가이드도 인도네시아 컨텍스트(NPWP, BPJS 등)로 현지화.
- 키보드의 X(전체 지우기) 버튼이 빈 텍스트 필드에서는 자동으로 숨겨져요.

#### 천지인 키보드 입력 정확도 개선

- "너와", "무화과", "와", "과", "야", "여", "워" 등 복합 모음과 연속 자음이 들어간 단어 입력 정상화. ㆍ 단독 stroke가 다음 stroke를 기다리도록 수정.
- 백스페이스가 모든 모드(영문/한글/숫자/특수문자)에서 정상 동작.
- 단일 자음 탭 후 백스페이스 무효 버그 수정.

#### 키보드 익스텐션

- 숫자 모드에서 #+= 토글 추가 — 이제 키보드에서 모든 특수문자([ ] { } # % ^ * + = _ \\ | ~ < > € £ ¥ • 등)에 접근 가능.
- 백스페이스가 누락되어 있던 숫자/특수문자 모드에서도 정상 노출.

#### 버그 수정

- 메모 수정 시 새 메모가 생기고 기존 메모가 삭제되지 않던 문제 수정.
- 한국어 환경에서 일부 메뉴(카테고리, 일괄 가져오기 등)가 영어로 노출되던 번역 누락 보완.

#### 기본 언어를 영어로 전환

- 지원하지 않는 언어 환경에서 앱이 한국어로 표시되던 동작을 영어 fallback으로 변경. 한국어/영어/인도네시아어 사용자는 영향 없음.

---

## English

### Version 4.0.5 Update

#### New features

- Bulk import — paste an entire chunk of text from another notes app and the app automatically splits it into individual memos. Choose split mode (Auto / Separator / Blank line / One per line), preview each item, edit titles inline, save in one tap. Available from the + menu in the memo list.
- Custom categories — add, rename, reorder, and delete your own categories. Manage from Settings → Categories.
- Country-specific default categories — on first launch, the category list is seeded based on your device region. Brazil gets CPF/CNPJ, US gets SSN/EIN, Indonesia gets NPWP/KTP, and so on for major regions worldwide.
- Indonesian (Bahasa Indonesia) officially supported — 100% UI translation. Use Cases Guide also localized with Indonesian context (NPWP, BPJS, etc.).
- The keyboard's clear-all (X) button now hides automatically when the text field is empty.

#### Cheonjiin keyboard accuracy

- Fixed composition for words with compound vowels and consecutive consonants: "너와", "무화과", "와", "과", "야", "여", "워" and similar. Lone arae-a (ㆍ) stroke now waits for the next stroke.
- Backspace now works correctly in all modes (English / Korean / Numbers / Symbols).
- Fixed a bug where backspace did nothing after a single consonant tap.

#### Keyboard extension

- Added #+= toggle in numbers mode — all symbols ([ ] { } # % ^ * + = _ \\ | ~ < > € £ ¥ • etc.) are now accessible.
- Backspace now appears in numbers and symbols modes (it was missing before).

#### Bug fixes

- Fixed a bug where editing a memo would create a new one and leave the original undeleted.
- Filled in missing translations for some menus (Categories, Bulk import, etc.) that appeared in English on Korean devices.

#### Default language switched to English

- For unsupported locales, the app now falls back to English instead of Korean. No impact for Korean / English / Indonesian users.
