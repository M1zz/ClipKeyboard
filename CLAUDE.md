# ClipKeyboard 프로젝트

## 프로젝트 개요

- **프로젝트명**: ClipKeyboard
- **현재 버전**: 4.4.8
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
│   ├── App/                     # 앱 진입점과 앱 전역의 것
│   │   ├── ClipKeyboardApp.swift   # 진입점
│   │   ├── AppGroup.swift          # App Group 컨테이너·UserDefaults
│   │   ├── AppNotification.swift   # 알림을 쏘는 유일한 문
│   │   ├── AppSymbol.swift         # SF Symbol 이름 단일 출처
│   │   ├── DefaultsKey.swift       # UserDefaults 키 단일 출처
│   │   └── Constants.swift         # 상수 (테마 등)
│   ├── Model/                   # 데이터 모델 (Memo, 클립보드, Combo)
│   ├── Screens/                 # 화면. **View 와 ViewModel 이 같은 폴더에 산다**
│   │   ├── List/               # 메모 리스트 + ClipKeyboardListViewModel
│   │   ├── Memo/               # 메모 추가/편집 + MemoAddViewModel
│   │   ├── Template/           # 템플릿 관리
│   │   └── Component/          # 재사용 컴포넌트
│   ├── Service/                 # 비즈니스 로직 (MemoStore, CloudKit, Combo 등)
│   ├── Manager/                 # 시스템 관리 (생체인증, 단축키, 메뉴바)
│   ├── Domain/  Data/           # 메모 저장 한 갈래만 계층으로 나눠 둔 것
│   ├── DesignSystem/            # 테마·카드 표면·공용 부품
│   └── Extensions/              # Swift 확장
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

### 7. 문장부호: 엠대시(U+2014) 절대 금지

⛔️ **U+2014 (em dash, 긴 줄표) 문자는 이 저장소 어디에도 쓰지 않는다.**
이 문서에 그 글자를 예시로도 적지 않는 이유가 규칙 그 자체다.

- 대상: 앱 UI 문자열, String Catalog, 웹 페이지(docs/), 릴리즈 노트, 문서, 코드 주석, 커밋 메시지 전부
- 이유: AI가 쓴 글처럼 읽히고, 한국어 문장의 리듬을 어색하게 만든다
- 대체: 문맥에 맞게 고른다
  - 사용자에게 보이는 글: 쉼표(,) · 마침표(.) · 가운뎃점(·) · 콜론(:)
  - 코드 주석: 하이픈(`-`)
  - 끼워 넣는 말은 괄호로, 두 문장이면 마침표로 끊는다
- U+2013 (en dash) 도 같은 이유로 피한다. 범위는 `~` 또는 `to`

```swift
// ❌ BAD  (U+2014 사용)
Text(NSLocalizedString("단축어 10개 잠김 \u{2014} Pro 구매 시 동기화됩니다", comment: ""))

// ✅ GOOD
Text(NSLocalizedString("단축어 10개 잠김, Pro 구매 시 동기화됩니다", comment: ""))
// 무대 - 앱을 열면 키보드가 보인다
```

**검사** (결과가 비어 있어야 한다):

```bash
sh scripts/check_dashes.sh
```

이 검사는 **저장소 전 범위**(앱 문자열·카탈로그·docs·릴리즈 노트·주석·스크립트)를 본다.
사람이 기억으로 지키지 않도록 세 곳에 물려 있다.

| 언제 | 무엇이 부르나 |
| --- | --- |
| 커밋할 때 | `.git/hooks/pre-commit` (스테이지된 파일만) |
| 커밋 메시지 | `.git/hooks/commit-msg` |
| 빌드·배포 | `ci_scripts/ci_post_clone.sh` · `scripts/predeploy.sh` |

새 머신에서는 `sh scripts/install-hooks.sh` 를 한 번 돌린다.

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
    if url.scheme == "clipkeyboard" {
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

### 9. 제어센터 컨트롤(ControlWidget)에서 앱 열기
```swift
// ❌ BAD - iOS 26 SDK에서 deprecated, 조용히 무시됨
static var openAppWhenRun: Bool = true

// ✅ GOOD - iOS 26 방식 + 같은 인텐트 타입을 "앱 타겟에도" 반드시 포함
static var supportedModes: IntentModes { .foreground }
```
- 포그라운드 인텐트는 **메인 앱 프로세스에서 실행**되므로 위젯 타겟에만 두면 탭이 조용히 무시됨
- 위젯 측 `widget/QuickNoteControl.swift` ↔ 앱 측 `ClipKeyboard/App/QuickNoteControlIntent.swift` 타입명·동작 일치 유지
- 인텐트 시그니처 변경 시 컨트롤 kind 도 새 문자열로 (죽은 컨트롤 캐시 방지)
- 상세 기록: `docs/engineering/CONTROL_CENTER_APP_LAUNCH.md`

### 10. 다국어 지원 누락
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

- [사용 가이드](https://m1zz.github.io/ClipKeyboard/tutorial.html)
- 개발자 이메일: leeo@kakao.com

### docs 폴더 (자세한 것은 `docs/README.md`)

⚠️ **docs 루트는 GitHub Pages 의 소스다.** `index.html` · `tutorial.html` · `privacy.html` ·
`terms.html` · `accessibility.html` 과 그 자산(`favicon.png` · `app-icon.png` · `media/`)은
그대로 공개 주소가 되므로 **옮기지 않는다.** 글은 아래 폴더에 넣는다.

| 폴더 | 무엇 |
| --- | --- |
| `docs/release-notes/` | 버전별 App Store 문안(`5.0.2.md`, 맥은 `-macos`) + 누적 기록 `HISTORY.md` |
| `docs/postmortem/` | 죽거나 멈춘 기록. 대개 `scripts/` 의 검사와 짝을 이룬다 |
| `docs/engineering/` | 개발 기록·빌드 설정·시험 |
| `docs/design/` | 디자인 가이드 |
| `docs/product/` | 명세·점검·심사 답변 |
| `docs/marketing/` | 알리는 글·스크린샷 |

코드 주석에서 문서를 가리킬 때는 저장소 루트 기준 경로로 적는다
(`docs/postmortem/HANG_PASTEBOARD_5_0_1.md`).

## 버전 히스토리

- **4.3.4**: iCloud 백업 안정성 보완: 파일 내보내기/가져오기(escape hatch), 원본 보호용 atomic 저장, 백업 결과 정확 표시(조용한 실패 제거), 맥 백업 실패 수정
- **3.0.1**: 다국어 지원 추가
- **3.0.0**: Combo 시스템, 스마트 클립보드 분류
- **2.x**: 템플릿 시스템, CloudKit 백업
- **1.x**: 초기 버전 (기본 메모/키보드 기능)
