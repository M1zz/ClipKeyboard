# Testing Guide - TDD 테스트 가이드

## 📋 개요

Token Memo 앱의 핵심 기능들을 TDD(Test-Driven Development) 관점에서 테스트합니다.

## 🎯 테스트 범위

### 1. 단위 테스트 (Unit Tests)
- ✅ 데이터 모델 (Memo, Combo, SmartClipboardHistory)
- ✅ MemoStore (저장/로드)
- ✅ ComboExecutionService (Combo 실행)
- ✅ 클립보드 자동 분류

### 2. 통합 테스트 (Integration Tests)
- ✅ CloudKit 백업/복구
- ✅ 전체 Combo 실행 플로우

## 📁 테스트 파일 구조

```
ClipKeyboardTests/
├── ModelTests.swift                    # 모델 테스트
├── MemoStoreTests.swift               # 데이터 저장/로드 테스트
├── ComboExecutionServiceTests.swift   # Combo 실행 테스트
├── CloudKitBackupServiceTests.swift   # CloudKit 테스트
└── ClipboardDetectionTests.swift      # 자동 분류 테스트
```

## 🚀 Xcode에서 테스트 설정

### Step 1: 테스트 타겟 추가

1. **Xcode에서 프로젝트 열기**
2. **File → New → Target...**
3. **iOS → Unit Testing Bundle** 선택
4. **Product Name**: `ClipKeyboardTests`
5. **Target to be Tested**: `ClipKeyboard`
6. **Finish** 클릭

### Step 2: 테스트 파일 추가

1. **프로젝트 내비게이터에서 `ClipKeyboardTests` 그룹 선택**
2. **Finder에서 테스트 파일들을 드래그**
   - `ModelTests.swift`
   - `MemoStoreTests.swift`
   - `ComboExecutionServiceTests.swift`
   - `CloudKitBackupServiceTests.swift`
   - `ClipboardDetectionTests.swift`

3. **옵션 설정**:
   - ✅ Copy items if needed
   - ✅ Add to targets: `ClipKeyboardTests`

### Step 3: 앱 타겟 코드 접근 허용

**ClipKeyboard 타겟 → Build Settings → Packaging**
- `Defines Module` = YES

**또는 테스트 파일에서 `@testable import`**:
```swift
@testable import Token_memo
```

## ▶️ 테스트 실행 방법

### Xcode에서 실행

#### 모든 테스트 실행
```
⌘ + U
또는
Product → Test
```

#### 특정 테스트 클래스 실행
```
테스트 파일 열기 → 클래스 옆 다이아몬드 아이콘 클릭
```

#### 특정 테스트 메서드 실행
```
테스트 메서드 옆 다이아몬드 아이콘 클릭
```

### 커맨드라인에서 실행

#### iOS 테스트
```bash
cd /Users/leeo/Documents/code/ClipKeyboard

xcodebuild test \
  -scheme "ClipKeyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:Token\ memoTests
```

#### macOS 테스트
```bash
xcodebuild test \
  -scheme "ClipKeyboard.tap" \
  -destination 'platform=macOS' \
  -only-testing:TokenMemoTests
```

#### 특정 테스트만 실행
```bash
xcodebuild test \
  -scheme "ClipKeyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:Token\ memoTests/ModelTests/testMemoCreation
```

## 📝 테스트 작성 가이드

### TDD 사이클

```
1. Red   → 실패하는 테스트 작성
2. Green → 테스트를 통과하는 최소한의 코드 작성
3. Refactor → 코드 개선
```

### 테스트 네이밍 규칙

```swift
// Given-When-Then 패턴
func test{기능}_{조건}_{예상결과}() {
    // Given - 준비
    let input = "test"

    // When - 실행
    let result = function(input)

    // Then - 검증
    XCTAssertEqual(result, expected)
}
```

### 예시

```swift
func testMemoCreation_WithTitle_CreatesValidMemo() {
    // Given
    let title = "테스트"
    let value = "값"

    // When
    let memo = Memo(title: title, value: value)

    // Then
    XCTAssertNotNil(memo.id)
    XCTAssertEqual(memo.title, title)
    XCTAssertEqual(memo.value, value)
}
```

## 📊 테스트 커버리지 확인

### Xcode에서 확인

1. **Product → Test** (⌘+U)
2. **Report Navigator** (⌘+9) 열기
3. **최신 테스트 결과 선택**
4. **Coverage 탭 선택**

### 커버리지 목표

| 항목 | 목표 |
|-----|------|
| 모델 | 90% 이상 |
| MemoStore | 85% 이상 |
| ComboExecutionService | 80% 이상 |
| CloudKitBackupService | 70% 이상 (네트워크 제외) |

## 🧪 테스트 시나리오

### 1. 모델 테스트 (ModelTests.swift)

#### 검증 항목
- ✅ Memo 생성 및 기본값
- ✅ Memo 인코딩/디코딩
- ✅ 템플릿 플레이스홀더 저장
- ✅ SmartClipboardHistory 생성
- ✅ Combo 생성 및 정렬
- ✅ ComboItem 순서 보장

#### 실행
```bash
xcodebuild test -scheme "ClipKeyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:Token\ memoTests/ModelTests
```

### 2. MemoStore 테스트 (MemoStoreTests.swift)

#### 검증 항목
- ✅ 메모 저장/로드
- ✅ 메모 수정/삭제
- ✅ SmartClipboardHistory 저장/로드
- ✅ Combo 저장/로드/수정/삭제
- ✅ Combo 유효성 검증
- ✅ Combo 정리 (cleanupCombo)
- ✅ ComboItem 값 가져오기
- ✅ 사용 횟수 증가

#### 실행
```bash
xcodebuild test -scheme "ClipKeyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:Token\ memoTests/MemoStoreTests
```

### 3. Combo 실행 테스트 (ComboExecutionServiceTests.swift)

#### 검증 항목
- ✅ 초기 상태 확인
- ✅ Combo 시작/중지/일시정지/재개
- ✅ 단일/다중 항목 실행
- ✅ 진행률 계산
- ✅ 현재 항목 추적
- ✅ 템플릿 변수 치환 ({날짜}, {시간})
- ✅ 에러 발생 시 다음 항목 계속 진행
- ✅ 중복 실행 방지
- ✅ 사용 횟수 증가

#### 실행
```bash
xcodebuild test -scheme "ClipKeyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:Token\ memoTests/ComboExecutionServiceTests
```

### 4. CloudKit 테스트 (CloudKitBackupServiceTests.swift)

#### 검증 항목
- ✅ 서비스 초기화
- ✅ iCloud 인증 상태 확인
- ✅ 백업 데이터 준비
- ✅ CloudKit 에러 메시지
- ✅ 백업 날짜 저장/로드

#### 통합 테스트 (주석 처리됨)
- ⚠️ 백업 및 복구 (실제 iCloud 필요)
- ⚠️ 백업 존재 확인
- ⚠️ 백업 삭제

#### 실행
```bash
xcodebuild test -scheme "ClipKeyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:Token\ memoTests/CloudKitBackupServiceTests
```

**Note**: 통합 테스트는 실제 iCloud 로그인이 필요하므로 주석 처리되어 있습니다.

### 5. 클립보드 자동 분류 테스트 (ClipboardDetectionTests.swift)

#### 검증 항목
- ✅ 이메일 감지 (유효/무효)
- ✅ 전화번호 감지 (유효/무효)
- ✅ URL 감지
- ✅ 신용카드 감지
- ✅ IP 주소 감지 (유효/무효)
- ✅ 우편번호 감지
- ✅ 감지 우선순위 (이메일 > 텍스트)
- ✅ 신뢰도 점수 (confidence)

#### 실행
```bash
xcodebuild test -scheme "ClipKeyboard" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:Token\ memoTests/ClipboardDetectionTests
```

## 🔧 테스트 환경 설정

### setUp() & tearDown()

```swift
override func setUp() {
    super.setUp()
    // 테스트 전 초기화
}

override func tearDown() {
    // 테스트 후 정리
    super.tearDown()
}
```

### 비동기 테스트

```swift
func testAsyncOperation() async throws {
    // When
    try await someAsyncFunction()

    // Then
    XCTAssertTrue(condition)
}
```

### 타이머가 있는 테스트

```swift
func testWithTimer() {
    let expectation = XCTestExpectation(description: "Wait for timer")

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        expectation.fulfill()
    }

    wait(for: [expectation], timeout: 2.0)
}
```

## ⚠️ 주의사항

### 1. 테스트 격리
- 각 테스트는 독립적이어야 함
- `tearDown()`에서 데이터 정리 필수

### 2. 공유 싱글톤
- `MemoStore.shared` 사용 시 주의
- 테스트 간 데이터 충돌 방지

### 3. 네트워크 테스트
- CloudKit 테스트는 실제 네트워크 필요
- CI/CD에서는 mock 사용 권장

### 4. UI 테스트
- UI 테스트는 별도의 UITests 타겟에서
- 단위 테스트는 로직만 검증

## 📈 CI/CD 통합

### GitHub Actions 예시

```yaml
name: Run Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2

      - name: Run Tests
        run: |
          xcodebuild test \
            -scheme "ClipKeyboard" \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -only-testing:Token\ memoTests
```

## 🎓 학습 자료

### XCTest 공식 문서
- [Apple - Testing with Xcode](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/)

### TDD 참고 자료
- [Test-Driven Development by Example](https://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530)

## 📞 문제 해결

### "No such module 'XCTest'" 에러
→ 테스트 타겟이 제대로 설정되지 않음
→ Target Membership 확인

### "Cannot find type in scope" 에러
→ `@testable import Token_memo` 추가
→ 앱 타겟에서 `Defines Module = YES` 설정

### 테스트가 실행되지 않음
→ Scheme에서 테스트 타겟이 활성화되어 있는지 확인
→ Product → Scheme → Edit Scheme → Test 탭 확인

---

**테스트 작성 원칙**: 테스트는 문서다. 다른 개발자가 읽고 이해할 수 있도록 명확하게 작성하세요.
