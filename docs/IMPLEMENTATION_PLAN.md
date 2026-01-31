# Token Memo 앱 개선 계획: Combo 기능 완성

## 목표
"반복 입력 시간 절약"이라는 핵심 가치를 극대화하기 위해 **Combo 기능을 완성**합니다.

## 사용자 요구사항
- **우선순위**: Combo 기능 완성
- **사용 시나리오**: 업무용 (이메일, 주소), 개인정보 입력, 템플릿 활용, 복잡한 순차 입력
- **플랫폼**: iOS + macOS 모두 지원

## 현재 상태 분석

### 구현된 부분 ✅
- Combo 모델 완성 (`Memo.swift` 라인 281-351)
- ComboExecutionService 실행 로직 완성
- MemoStore CRUD 메서드 완성
- ComboList UI 기본 구조

### 미구현 부분 ❌
- **Combo 편집 화면**: 항목 추가 기능 TODO (`ComboList.swift` 라인 435-438)
- **키보드 확장**: Combo 관련 코드 전혀 없음
- **템플릿 처리**: 플레이스홀더 값 입력 UI 부재

## 구현 계획

### Phase 1: Combo 편집 화면 완성 (메인 앱) ✅ 완료

#### 1.1 새 파일 생성

**`ClipKeyboard/Screens/Combo/ComboItemPickerView.swift`** ✅
- 메모/클립보드/템플릿 선택 탭 UI
- 각 타입별 항목 리스트 표시
- 선택 시 ComboItem 생성 및 추가

**`ClipKeyboard/Screens/Combo/ComboTemplateInputView.swift`** ✅
- 템플릿 플레이스홀더 추출
- PlaceholderSelectorView 재사용
- 실시간 미리보기 표시
- displayValue에 최종 값 저장

#### 1.2 기존 파일 수정

**`ClipKeyboard/Screens/ComboList.swift`** ✅
```swift
// 라인 435-438 변경
@State private var showItemPicker = false
@State private var editingTemplateItem: ComboItem? = nil

Button("항목 추가") {
    showItemPicker = true
}
.sheet(isPresented: $showItemPicker) {
    ComboItemPickerView(selectedItems: $selectedItems)
}

// 항목 섹션에 추가 (라인 414-433)
ForEach(selectedItems) { item in
    HStack {
        Image(systemName: "line.3.horizontal")
        ComboItemChip(item: item)
        Spacer()
        if let title = item.displayTitle {
            Text(title).font(.caption)
        }
        if item.type == .template {
            Button {
                editingTemplateItem = item
            } label: {
                Image(systemName: "pencil.circle.fill")
            }
        }
    }
}
.onMove(perform: moveItem)      // 드래그앤드롭 재정렬
.onDelete(perform: deleteItem)   // 스와이프 삭제

// 메서드 추가
private func moveItem(from: IndexSet, to: Int) {
    selectedItems.move(fromOffsets: from, toOffset: to)
    for (index, _) in selectedItems.enumerated() {
        selectedItems[index].order = index
    }
}

private func deleteItem(at: IndexSet) {
    selectedItems.remove(atOffsets: at)
    for (index, _) in selectedItems.enumerated() {
        selectedItems[index].order = index
    }
}
```

### Phase 2: Combo 실행 로직 개선 ✅ 완료

#### 2.1 템플릿 항목 처리 강화

**`ClipKeyboard/Service/ComboExecutionService.swift`** ✅

라인 107-122 `executeCurrentItem()` 메서드 수정:
```swift
if let value = try MemoStore.shared.getComboItemValue(item) {
    var finalValue = value

    // 템플릿인 경우 displayValue 우선 사용
    if item.type == .template, let displayValue = item.displayValue {
        finalValue = displayValue
    }

    // 자동 변수 치환
    finalValue = processTemplateVariables(in: finalValue)

    UIPasteboard.general.string = finalValue
    postNotification(for: item, value: finalValue)
}

// 자동 변수 치환 메서드 추가
private func processTemplateVariables(in text: String) -> String {
    var result = text
    let formatter = DateFormatter()

    formatter.dateFormat = "yyyy-MM-dd"
    result = result.replacingOccurrences(of: "{날짜}", with: formatter.string(from: Date()))

    formatter.dateFormat = "HH:mm:ss"
    result = result.replacingOccurrences(of: "{시간}", with: formatter.string(from: Date()))

    result = result.replacingOccurrences(of: "{연도}", with: String(Calendar.current.component(.year, from: Date())))
    result = result.replacingOccurrences(of: "{월}", with: String(Calendar.current.component(.month, from: Date())))
    result = result.replacingOccurrences(of: "{일}", with: String(Calendar.current.component(.day, from: Date())))

    return result
}
```

#### 2.2 데이터 무결성 검증

**`ClipKeyboard/Service/MemoStore.swift`** ✅

라인 612 이후 추가:
```swift
/// Combo 항목의 참조 대상이 존재하는지 검증
func validateComboItem(_ item: ComboItem) throws -> Bool {
    switch item.type {
    case .memo:
        let memos = try load(type: .tokenMemo)
        return memos.contains(where: { $0.id == item.referenceId })
    case .clipboardHistory:
        let history = try loadSmartClipboardHistory()
        return history.contains(where: { $0.id == item.referenceId })
    case .template:
        let memos = try load(type: .tokenMemo)
        return memos.contains(where: { $0.id == item.referenceId && $0.isTemplate })
    }
}

/// 유효하지 않은 항목 자동 제거
func cleanupCombo(_ combo: Combo) throws -> Combo {
    var validItems: [ComboItem] = []
    for item in combo.items {
        if try validateComboItem(item) {
            validItems.append(item)
        } else {
            print("⚠️ [MemoStore] Combo '\(combo.title)'의 항목 제거됨")
        }
    }
    var cleanedCombo = combo
    cleanedCombo.items = validItems
    return cleanedCombo
}
```

### Phase 3: 키보드 확장에서 Combo 지원 ✅ 완료

#### 3.1 Combo 전용 뷰 생성

**`ClipKeyboardExtension/ComboKeyboardView.swift`** ✅ (신규 파일)
- Combo 목록 그리드 표시
- 탭 한 번으로 실행
- 실행 중 진행 상황 실시간 표시
- 빈 상태 UI 포함

주요 기능:
```swift
struct ComboKeyboardView: View {
    @State private var combos: [Combo] = []
    @State private var executingComboId: UUID? = nil
    @ObservedObject private var executionService = ComboExecutionService.shared

    var body: some View {
        VStack(spacing: 0) {
            if combos.isEmpty {
                // 빈 상태 UI
                Text("Combo가 없습니다")
                Text("앱에서 Combo를 생성해보세요")
            } else {
                // Combo 그리드
                ScrollView {
                    LazyVGrid(columns: gridItemLayout, spacing: 10) {
                        ForEach(combos) { combo in
                            ComboKeyboardCard(
                                combo: combo,
                                isExecuting: executingComboId == combo.id,
                                executionState: executionService.state,
                                onExecute: { executeCombo(combo) }
                            )
                        }
                    }
                }
            }
        }
        .onAppear { loadCombos() }
    }

    private func executeCombo(_ combo: Combo) {
        executingComboId = combo.id
        ComboExecutionService.shared.startCombo(combo)
    }
}
```

#### 3.2 키보드 메인 뷰 수정

**`ClipKeyboardExtension/KeyboardView.swift`** ✅

라인 177, 183-233에 탭 UI 추가:
```swift
@State private var selectedTab: Int = 0  // 0: 메모, 1: Combo

var body: some View {
    VStack(spacing: 0) {
        // 탭 선택
        Picker("", selection: $selectedTab) {
            Text("메모").tag(0)
            Text("Combo").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)

        // 탭 내용
        if selectedTab == 0 {
            // 기존 메모 그리드 코드
            ZStack {
                backgroundColor
                ScrollView {
                    LazyVGrid(columns: gridItemLayout, spacing: 10) {
                        // ... 기존 코드
                    }
                }
            }
        } else {
            // Combo 뷰
            ComboKeyboardView()
        }
    }
    .overlay(
        Group {
            if templateInputState.isShowing {
                TemplateInputOverlay(state: templateInputState)
            }
        }
    )
}
```

### Phase 4: UX 개선 및 다국어 지원 ✅ 완료

#### 4.1 진행 상황 표시

ComboKeyboardCard에서 실행 상태 시각화 (ComboKeyboardView.swift:175-210):
```swift
if isExecuting {
    switch executionState {
    case .running(let currentIndex, let totalCount):
        ProgressView(value: Double(currentIndex + 1), total: Double(totalCount))
        Text("\(currentIndex + 1) / \(totalCount)")
            .font(.caption)
    case .completed:
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("완료!")
        }
    case .error(let message):
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text("오류")
        }
    default:
        EmptyView()
    }
}
```

#### 4.2 다국어 지원 문자열 추가

**`Localizable.xcstrings`** ✅ 업데이트 완료
- "Combo가 없습니다" / "No combos"
- "앱에서 Combo를 생성해보세요" / "Create Combos in the app"
- "%lld개 항목" / "%lld items"
- "완료!" / "Done!"
- "오류" / "Error"

## 추가 수정: CloudKit 백업/복구 개선 ✅ 완료

**문제점:**
- SmartClipboardHistory가 백업되지 않음
- Combo 데이터가 백업되지 않음
- 단일 데이터 타입 실패 시 전체 복구 실패
- 레거시 백업 호환성 없음

**해결 방법:**
- `ClipKeyboard/Service/CloudKitBackupService.swift` 수정
- `ClipKeyboard.tap/CloudKitBackupService.swift` 수정 (macOS)

```swift
// 백업 시 SmartClipboardHistory와 Combo 포함
let smartClipboardHistory = try MemoStore.shared.loadSmartClipboardHistory()
let combos = try MemoStore.shared.loadCombos()

record["smartClipboardHistory"] = smartClipboardData as CKRecordValue
record["combos"] = combosData as CKRecordValue

// 복구 시 옵셔널 처리 (레거시 백업 호환)
var smartClipboardHistory: [SmartClipboardHistory] = []
if let smartClipboardData = record["smartClipboardHistory"] as? Data {
    if let decoded = try? JSONDecoder().decode([SmartClipboardHistory].self, from: smartClipboardData) {
        smartClipboardHistory = decoded
    }
}

var combos: [Combo] = []
if let combosData = record["combos"] as? Data {
    if let decoded = try? JSONDecoder().decode([Combo].self, from: combosData) {
        combos = decoded
    }
}
```

## 주요 변경 파일

### 새로 생성 ✅
1. `ClipKeyboard/Screens/Combo/ComboItemPickerView.swift` (363 lines)
2. `ClipKeyboard/Screens/Combo/ComboTemplateInputView.swift` (238 lines)
3. `ClipKeyboardExtension/ComboKeyboardView.swift` (218 lines)

### 수정 ✅
1. `ClipKeyboard/Screens/ComboList.swift` - 항목 추가/재정렬/삭제
2. `ClipKeyboard/Service/ComboExecutionService.swift` - 템플릿 처리 및 자동 변수 치환
3. `ClipKeyboard/Service/MemoStore.swift` - 검증 메서드 추가
4. `ClipKeyboardExtension/KeyboardView.swift` - 탭 UI 추가
5. `ClipKeyboard/Service/CloudKitBackupService.swift` - SmartClipboard, Combo 백업
6. `ClipKeyboard.tap/CloudKitBackupService.swift` - macOS 버전 동일 수정
7. `ClipKeyboard/Localizable.xcstrings` - 다국어 문자열 추가

## 검증 방법

### 테스트 시나리오 1: 회원가입 정보 입력
1. 메인 앱에서 Combo 생성
   - 항목: 이름, 이메일, 전화번호, 주소 메모
   - interval: 2초

2. 키보드에서 실행
   - 웹사이트 회원가입 폼 열기
   - 키보드에서 Combo 탭 선택 → 실행
   - 각 항목이 2초 간격으로 자동 입력되는지 확인
   - 진행 상황 표시 확인 (1/4, 2/4, 3/4, 4/4)

**기대 결과**: 모든 항목이 순서대로 입력, 진행 바 정상 표시, 완료 메시지 표시

### 테스트 시나리오 2: 템플릿 활용
1. 템플릿 메모 생성
   - 제목: "이메일 서명"
   - 내용: "감사합니다.\n{이름} 드림\n{부서} | {회사명}"

2. Combo 생성
   - 항목 1: 메모 "안녕하세요"
   - 항목 2: 템플릿 "이메일 서명" → 플레이스홀더 값 입력
     - {이름}: "홍길동"
     - {부서}: "개발팀"
     - {회사명}: "ABC회사"

3. 실행 및 검증
   - "안녕하세요" → 1초 대기 → "감사합니다.\n홍길동 드림\n개발팀 | ABC회사"
   - 플레이스홀더가 정확히 치환되었는지 확인

**기대 결과**: 템플릿의 플레이스홀더가 입력한 값으로 정확히 치환됨

### 테스트 시나리오 3: 항목 재정렬 및 삭제
1. Combo 생성: A, B, C, D (순서대로)
2. D를 첫 번째로 드래그 → 저장 → 다시 열기 → 순서 확인 (D, A, B, C)
3. B 항목 스와이프 삭제 → 저장 → 다시 열기 → D, A, C만 남았는지 확인
4. 키보드에서 실행 → D → A → C 순서로 입력되는지 확인

**기대 결과**: 재정렬/삭제가 정상 작동, 실행 순서 유지

### 테스트 시나리오 4: 에러 처리
1. Combo 생성: 메모 A, B, C 추가
2. 메인 앱에서 메모 B 삭제
3. Combo 실행 → A 입력 → B 항목 에러(건너뜀) → C 입력
4. Combo 편집 → 유효하지 않은 항목 경고 표시 확인

**기대 결과**: 실행 중 에러 발생해도 다음 항목 계속 진행, 편집 시 경고

### 테스트 시나리오 5: macOS 지원
1. Mac Catalyst 빌드
2. 메인 앱과 동일하게 Combo 편집/실행 테스트
3. 단축키 동작 확인 (⌘⇧X, ⌘⇧N 등)

**기대 결과**: iOS와 동일하게 작동

## 구현 순서 (완료)

1. **Phase 1 완성** ✅ (메인 앱 편집 화면)
   - ComboItemPickerView 생성
   - ComboTemplateInputView 생성
   - ComboList.swift 수정
   - 테스트 시나리오 3 검증

2. **Phase 2 완성** ✅ (실행 로직 개선)
   - ComboExecutionService 수정
   - MemoStore 검증 메서드 추가
   - 테스트 시나리오 2, 4 검증

3. **Phase 3 완성** ✅ (키보드 확장)
   - ComboKeyboardView 생성
   - KeyboardView 탭 UI 추가
   - 테스트 시나리오 1 검증

4. **Phase 4 완성** ✅ (UX 개선)
   - 진행 상황 표시
   - 다국어 지원
   - 테스트 시나리오 5 검증

5. **CloudKit 수정** ✅ (추가 작업)
   - SmartClipboardHistory 백업/복구
   - Combo 백업/복구
   - 레거시 호환성
   - iOS + macOS 양쪽 수정

## 성공 기준 (모두 달성 ✅)

- ✅ Combo 편집 화면에서 항목 추가/재정렬/삭제 가능
- ✅ 템플릿 항목의 플레이스홀더 값 미리 입력 가능
- ✅ 키보드에서 Combo 목록 표시 및 실행
- ✅ 실행 중 진행 상황 실시간 표시
- ✅ 에러 발생 시 다음 항목 계속 진행
- ✅ iOS/macOS 모두에서 정상 작동
- ✅ CloudKit 백업에 SmartClipboard와 Combo 포함
- ✅ 한국어/영어 다국어 지원

## 구현된 기능

### 메인 앱
- ✅ Combo 생성/편집/삭제
- ✅ 메모/클립보드/템플릿 항목 추가
- ✅ 드래그앤드롭으로 순서 변경
- ✅ 스와이프로 항목 삭제
- ✅ 템플릿 플레이스홀더 값 미리 설정
- ✅ 실시간 미리보기
- ✅ 자동 변수 치환 ({날짜}, {시간}, {연도}, {월}, {일})

### 키보드 확장
- ✅ 메모 / Combo 탭 전환
- ✅ Combo 목록 그리드 표시
- ✅ 탭으로 즉시 실행
- ✅ 진행 바 및 상태 표시
- ✅ 완료/오류 메시지
- ✅ 빈 상태 UI

### 백업/복구
- ✅ SmartClipboardHistory 백업
- ✅ Combo 백업
- ✅ 레거시 백업 호환
- ✅ 부분 실패 시 복구 계속

## UX 최적화 포인트

1. **원탭 실행**: ✅ Combo 카드 자체를 탭하면 즉시 실행
2. **진행 시각화**: ✅ 현재 실행 중인 항목 진행 바, 남은 개수 표시
3. **에러 복구**: ✅ 항목 실행 실패 시 자동으로 다음 항목 진행
4. **템플릿 값 관리**: ✅ 플레이스홀더 값을 Combo에 미리 저장
5. **자동 변수**: ✅ {날짜}, {시간} 등 실행 시점에 자동 치환

이 계획을 따라 구현하여 "반복 입력 시간 절약"이라는 앱의 핵심 가치를 극대화했습니다.

---

**구현 완료일**: 2026-01-16
**총 작업 시간**: Phase 1-4 + CloudKit 수정
**생성된 파일**: 3개 (총 819 lines)
**수정된 파일**: 7개
