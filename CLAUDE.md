# Token Memo (ClipKeyboard) 프로젝트

## 프로젝트 개요

- **프로젝트명**: Token Memo (앱 이름: ClipKeyboard)
- **현재 버전**: 3.0.1
- **언어**: Swift
- **UI 프레임워크**: SwiftUI
- **최소 지원 버전**: iOS 17+
- **플랫폼**: iOS, macOS (Mac Catalyst 지원)
- **아키텍처**: Manager/Service 패턴 (MVVM 유사)
- **App Group**: `group.com.Ysoup.TokenMemo`

## 핵심 기능

### 1. 메모 관리
- 텍스트/이미지 메모 저장 및 관리
- 템플릿 시스템 (플레이스홀더 {변수} 지원)
- 즐겨찾기, 카테고리(테마) 분류
- 생체인증을 통한 보안 메모

### 2. 클립보드 관리
- **스마트 클립보드 히스토리**: 자동 분류 시스템 (정규식 기반)
  - 15가지 타입 자동 감지 (이메일, 전화번호, 주소, URL, 카드번호, 계좌번호 등)
  - 신뢰도(confidence) 기반 분류
- 임시 항목은 7일 후 자동 삭제
- 최대 100개 항목 유지

### 3. 커스텀 키보드 (ClipKeyboardExtension)
- iOS 키보드 익스텐션
- 메모를 키보드에서 빠르게 입력
- App Group을 통한 메인 앱과 데이터 공유

### 4. macOS 메뉴바 앱 (ClipKeyboard.tap)
- Mac Catalyst 기반 macOS 앱
- 메뉴바 아이콘 및 전역 단축키 지원
- 클립보드 모니터링

### 5. Combo 시스템 (Phase 2)
- 여러 메모를 순서대로 자동 입력
- 사용자 정의 시간 간격 설정
- 메모 + 클립보드 + 템플릿 조합 가능

### 6. CloudKit 백업
- iCloud를 통한 메모 백업 및 동기화
- 이미지 포함 백업 지원

### 7. OCR 지원
- Vision Framework 기반 텍스트 인식
- 한국어 + 영어 인식
- 카드 정보, 주소 자동 파싱

## 프로젝트 구조

```
ClipKeyboard/
├── ClipKeyboard/                  # iOS 메인 앱
│   ├── ClipKeyboardApp.swift     # 앱 진입점
│   ├── Model/                   # 데이터 모델
│   │   └── Memo.swift          # 메모, 클립보드, Combo 모델
│   ├── Screens/                 # 화면 (SwiftUI Views)
│   │   ├── List/               # 메모 리스트
│   │   ├── Memo/               # 메모 추가/편집
│   │   ├── Template/           # 템플릿 관리
│   │   └── Component/          # 재사용 컴포넌트
│   ├── Service/                 # 비즈니스 로직
│   │   ├── MemoStore.swift     # 메모/클립보드 저장소 (싱글톤)
│   │   ├── CloudKitBackupService.swift
│   │   └── ComboExecutionService.swift
│   ├── Manager/                 # 시스템 관리
│   │   ├── DataManager.swift   # 전역 데이터 관리
│   │   ├── BiometricAuthManager.swift
│   │   ├── GlobalHotkeyManager.swift
│   │   └── MenuBarManager.swift
│   ├── Extensions/              # Swift 확장
│   └── Constants.swift          # 상수 (테마, 다국어 등)
├── ClipKeyboardExtension/               # iOS 키보드 익스텐션
│   ├── KeyboardViewController.swift
│   └── KeyboardView.swift
└── ClipKeyboard.tap/               # macOS 앱 (Mac Catalyst)
    └── ClipKeyboard_macApp.swift
```

## 데이터 저장 방식

### 1. MemoStore (JSONEncoder/Decoder + App Group)
- **위치**: `group.com.Ysoup.TokenMemo` 컨테이너
- **파일**:
  - `memos.data`: 메모 목록
  - `clipboard.history.data`: 레거시 클립보드 (하위 호환용)
  - `smart.clipboard.history.data`: 스마트 클립보드 히스토리
  - `combos.data`: Combo 목록
  - `Images/`: 이미지 파일 저장 폴더

### 2. UserDefaults
- **App Group UserDefaults**: 키보드와 메인 앱 간 공유
- **표준 UserDefaults**: 온보딩 상태, 설정 등

### 3. 플레이스홀더 값
- UserDefaults에 `placeholder_values_{플레이스홀더명}` 키로 저장
- JSON 인코딩된 `PlaceholderValue` 배열

## 코딩 컨벤션

### 1. Swift 스타일
```swift
// ✅ GOOD
class MemoStore: ObservableObject {
    static let shared = MemoStore()
    @Published var memos: [Memo] = []
}

// ❌ BAD - 싱글톤은 항상 shared 사용
class MemoStore: ObservableObject {
    static let instance = MemoStore()
}
```

### 2. 로깅
- **이모지로 구분**: 📁 (파일), ✅ (성공), ❌ (실패), 🔄 (마이그레이션), 📝 (변경사항) 등
- **형식**: `print("🔧 [ClassName.methodName] 설명")`
- **예시**: `print("✅ [MemoStore.load] 메모 \(count)개 로드 완료")`

### 3. 주석
- **한글 주석 허용**: 비즈니스 로직 설명 시
- **영문 주석 권장**: 공개 API, 라이브러리 성격의 코드
- **MARK 주석 필수**: 큰 섹션 구분
  ```swift
  // MARK: - Public Methods
  // MARK: - Private Helpers
  // MARK: - Detection Methods
  ```

### 4. 네이밍
- **변수/함수**: camelCase
- **클래스/구조체/열거형**: PascalCase
- **상수**: static let (camelCase)
- **한글 사용 제한**: rawValue, 로그, 주석만 허용

### 5. 다국어 지원
⚠️ **매우 중요**: 다국어 지원은 이 프로젝트의 필수 요구사항입니다.
- **필수 규칙**:
  - 모든 사용자에게 노출되는 문자열은 **반드시** NSLocalizedString으로 처리
  - UI에 표시되는 한글, 영문 텍스트는 **예외 없이** 다국어 처리 필수
  - 새로운 기능 추가, 문구 변경 시 **즉시** String Catalog에 추가
  - Alert, 버튼, 라벨, placeholder, 안내 메시지 등 **모든 UI 텍스트** 포함
- **방식**: `NSLocalizedString("키", comment: "설명")`
- **위치**: `Constants.swift` 또는 사용 위치에서 직접 호출
- **String Catalog**: Xcode String Catalog 사용 (자동 다국어 변환)
- **지원 언어**: 한국어(ko), 영어(en)

**코드 작성 전 체크리스트**:
- [ ] 이 문자열이 사용자에게 보이는가? → YES면 NSLocalizedString 사용
- [ ] String Catalog에 추가했는가?
- [ ] 한국어와 영어 번역이 모두 제공되는가?

### 6. 파일 크기
- SwiftUI View는 300줄 이하 권장
- 큰 파일은 MARK 주석으로 섹션 구분
- 재사용 가능한 컴포넌트는 별도 파일로 분리

## 주요 패턴 및 규칙

### 1. App Group 사용
```swift
// ✅ GOOD - App Group 컨테이너 사용
guard let containerURL = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo"
) else { return }

// ✅ GOOD - App Group UserDefaults
UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")
```

### 2. 데이터 마이그레이션
- 하위 호환성 유지 필수
- 새 형식 디코딩 실패 시 이전 형식으로 폴백
- 마이그레이션 후 자동 저장
```swift
// OldMemo → Memo 마이그레이션 예시
if let newMemos = try? JSONDecoder().decode([Memo].self, from: data) {
    return newMemos
} else if let oldMemos = try? JSONDecoder().decode([OldMemo].self, from: data) {
    return oldMemos.map { Memo(from: $0) }
}
```

### 3. 클립보드 자동 분류
- 정규식 기반 패턴 매칭
- **우선순위**: 구체적인 패턴 먼저 검사 (주민등록번호 → 사업자등록번호 → 카드번호 → 계좌번호)
- 신뢰도 0.0 ~ 1.0 반환

### 4. 싱글톤 패턴
```swift
// ✅ GOOD - MemoStore, ClipboardClassificationService 등
class MemoStore: ObservableObject {
    static let shared = MemoStore()
    private init() {}
}
```

### 5. Published 변수 업데이트
```swift
// ✅ GOOD - 메인 스레드에서 업데이트
DispatchQueue.main.async {
    self.memos = newMemos
}
```

## 자주 하는 실수 (Claude 학습용)

### 1. App Group 경로 실수
```swift
// ❌ BAD - 표준 Documents 폴더 사용
FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

// ✅ GOOD - App Group 컨테이너 사용
FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo"
)
```

### 2. UserDefaults 공유 누락
```swift
// ❌ BAD - 키보드와 공유 안 됨
UserDefaults.standard.set(value, forKey: "key")

// ✅ GOOD - App Group UserDefaults
UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.set(value, forKey: "key")
```

### 3. 이미지 저장 경로
```swift
// ✅ GOOD - App Group 내 Images 폴더 사용
let imagesDirectory = containerURL.appendingPathComponent("Images")
```

### 4. 클립보드 분류 순서
```swift
// ❌ BAD - 계좌번호를 먼저 검사하면 생년월일(8자리)도 계좌번호로 오인
detectBankAccount() → detectBirthDate()

// ✅ GOOD - 구체적인 패턴부터 검사
detectRRN() → detectBusinessNumber() → detectCreditCard() →
detectBirthDate() → detectBankAccount()
```

### 5. Mac Catalyst 조건부 컴파일
```swift
// ✅ GOOD - Mac Catalyst 전용 코드
#if targetEnvironment(macCatalyst)
setupMacCatalystCommands()
#endif

// ✅ GOOD - iOS만 지원하는 기능
#if os(iOS)
import UIKit
import Vision
#endif
```

### 6. URL Scheme 처리
```swift
// ✅ GOOD - URL scheme으로 키보드에서 앱 열기
.onOpenURL { url in
    if url.scheme == "tokenMemo" {
        // 처리 로직
    }
}
```

### 7. 다국어 문자열 중복 선언 방지
```swift
// ❌ BAD - 여러 곳에서 중복 선언
NSLocalizedString("텍스트", comment: "Text")

// ✅ GOOD - enum에 localizedName 계산 프로퍼티로 통합
var localizedName: String {
    return NSLocalizedString(self.rawValue, comment: "Type name")
}
```

### 8. 이미지 메모리 관리
```swift
// ✅ GOOD - 이미지 크기 제한 (1024px)
// ✅ GOOD - JPEG 압압 (0.7 품질)
guard let imageData = image.jpegData(compressionQuality: 0.7) else { return }
```

### 9. 다국어 지원 누락
```swift
// ❌ BAD - 하드코딩된 문자열
Text("메모 추가")
.alert("삭제하시겠습니까?", isPresented: $showAlert)
Button("확인") { }

// ✅ GOOD - NSLocalizedString 사용
Text(NSLocalizedString("Add Memo", comment: "Button to add a new memo"))
.alert(NSLocalizedString("Delete confirmation", comment: "Alert message"), isPresented: $showAlert)
Button(NSLocalizedString("Confirm", comment: "Confirm button")) { }

// ❌ BAD - enum rawValue를 UI에 직접 노출
Text(theme.rawValue) // "비즈니스" 같은 한글이 그대로 노출

// ✅ GOOD - localizedName 프로퍼티 사용
Text(theme.localizedName) // NSLocalizedString으로 처리된 값
```

## 테스트 시 확인사항

### 1. App Group 데이터 공유
- [ ] 메인 앱에서 메모 추가 → 키보드에서 확인
- [ ] 키보드에서 메모 사용 → 메인 앱에서 사용 횟수 증가 확인

### 2. 클립보드 자동 분류
- [ ] 이메일 복사 → 이메일로 분류되는지 확인
- [ ] 주민등록번호 → RRN으로 분류 (계좌번호 아님)
- [ ] 통관부호(P123...) → 계좌번호 아님

### 3. 템플릿 시스템
- [ ] 플레이스홀더 값 저장/로드
- [ ] 템플릿에서 메모 생성 → 플레이스홀더 값 히스토리 확인

### 4. Mac Catalyst 기능
- [ ] 메뉴바 아이콘 표시
- [ ] 전역 단축키 동작
- [ ] Command Menu 동작

### 5. 데이터 마이그레이션
- [ ] 구버전 → 신버전 업데이트 시 데이터 손실 없음
- [ ] 카테고리 → 테마 마이그레이션

### 6. 다국어 지원
- [ ] iOS 설정에서 언어를 영어로 변경 → 앱의 모든 텍스트가 영어로 표시되는지 확인
- [ ] 한글과 영어 간 전환 시 UI 레이아웃이 깨지지 않는지 확인
- [ ] Alert, placeholder, 버튼 등 모든 UI 요소가 번역되는지 확인
- [ ] enum의 rawValue가 직접 노출되지 않고 localizedName을 사용하는지 확인

## 개발 환경

### Xcode 설정
- **개발 팀**: Ysoup
- **번들 ID**: com.Ysoup.TokenMemo
- **앱 그룹**: group.com.Ysoup.TokenMemo
- **Capabilities**:
  - App Groups ✅
  - iCloud (CloudKit) ✅
  - Keychain Sharing (생체인증)

### 빌드 타겟
1. **ClipKeyboard** (iOS 메인 앱)
2. **ClipKeyboardExtension** (키보드 익스텐션)
3. **ClipKeyboard.tap** (macOS 앱, Mac Catalyst)

## 디버깅 팁

### 1. 로그 검색
```bash
# App 초기화 로그
grep "🚀 \[APP INIT\]"

# 메모 저장/로드 로그
grep "📁 \[MemoStore"

# 마이그레이션 로그
grep "🔄 \[MemoStore\] 마이그레이션"
```

### 2. App Group 파일 확인
```bash
# iOS 시뮬레이터
xcrun simctl get_app_container booted com.Ysoup.TokenMemo data
```

### 3. UserDefaults 확인
```swift
// App Group UserDefaults 전체 출력
if let dict = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.dictionaryRepresentation() {
    print(dict)
}
```

## 참고 문서

- [노션 튜토리얼](https://leeo75.notion.site/ClipKeyboard-tutorial-70624fccc524465f99289c89bd0261a4)
- 개발자 이메일: leeo@kakao.com

## 버전 히스토리

- **3.0.1**: 다국어 지원 추가
- **3.0.0**: Combo 시스템, 스마트 클립보드 분류
- **2.x**: 템플릿 시스템, CloudKit 백업
- **1.x**: 초기 버전 (기본 메모/키보드 기능)
