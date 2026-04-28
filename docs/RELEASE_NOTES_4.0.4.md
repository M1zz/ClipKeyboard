# Release Notes v4.0.4

## 한국어 (Korean)

### 버전 4.0.4 업데이트

#### 키보드 익스텐션 개선

- 천지인 키보드의 한글 조합 정확도 개선
  - 단독 ㆍ stroke가 다음 stroke를 기다리도록 수정 (예: ㄱ + ㆍ + ㅡ → 고)
  - 백스페이스 동작 정상화
    - 자음 한 번 탭 후 백스페이스 시 정상 삭제
    - 합성된 모음에서 한 stroke만 되돌리고 미완성 상태 정상 복원
- 천지인 키보드 한글 버튼 자리에 EN 버튼과 시스템 키보드 전환 버튼 추가
- 한글 레이아웃(두벌식/천지인) 선택은 iOS 앱 설정에서만 가능하도록 정리

#### 메모 화면 정리

- 카테고리 필터바 제거
- 즐겨찾기만 보기 토글 버튼 추가 (메모 모드에서 별 아이콘)
- 템플릿 메모 시각 표시 추가 (보라색 중괄호 아이콘 / Template 라벨)

#### 보안 메모 강화

- 보안 메모 마스킹 표시 제거 (●●●● 1234 등)
- 메모 버튼 라벨의 "탭하여 인증" 텍스트 제거
- PIN 미설정 상태에서 보안 메모 입력 차단 (안내 토스트 노출)
- 보안 PIN 설정 메뉴를 별도 화면으로 분리하여 설정 메인에 직접 노출

#### iOS 앱 정리

- 메모 행에 표시되던 사용 빈도 배지("오늘 N회") 제거

---

## English

### Version 4.0.4 Update

#### Keyboard Extension Improvements

- Improved Korean composition accuracy on Cheonjiin keyboard
  - Lone arae-a (ㆍ) stroke now waits for the next stroke (e.g., ㄱ + ㆍ + ㅡ → 고)
  - Backspace now works correctly
    - Single consonant tap followed by backspace properly deletes
    - Composed vowels can be unwound one stroke at a time and partial state is restored
- Replaced the Korean toggle in Cheonjiin layout with EN button and system keyboard switch
- Korean layout choice (Dubeolsik / Cheonjiin) now lives only in the iOS app settings

#### Memo Screen Cleanup

- Removed the category filter bar
- Added a Favorites-only toggle next to the Memos tab
- Added visual markers for template memos (purple curly braces icon / Template label)

#### Security Memo Hardening

- Removed value masking (e.g., ●●●● 1234) from memo buttons
- Removed the "Tap to authenticate" hint label
- Secure memos now refuse to insert until a PIN is set, with a toast prompt
- Moved Secure PIN setup to its own screen, surfaced directly from main Settings

#### iOS App Cleanup

- Removed the per-row usage frequency badge ("Used N× today")
