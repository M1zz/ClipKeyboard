# Shared 코드 - iOS와 macOS 독립 개발 가이드

## 📁 구조

```
Shared/
├── Models/
│   └── SharedModels.swift    # 공통 데이터 모델
└── README.md                  # 이 파일
```

## 🎯 목적

iOS와 macOS 앱을 **독립적으로 개발**하면서도 핵심 데이터 모델은 **공유**합니다.

### 장점
- ✅ 데이터 모델 중복 제거
- ✅ iOS/macOS 간 데이터 호환성 보장
- ✅ 각 플랫폼의 UI/기능은 독립적으로 개발
- ✅ 한 플랫폼 수정이 다른 플랫폼에 영향 없음

## ⚙️ Xcode 설정 방법

### 1단계: Shared 파일을 프로젝트에 추가

1. **Xcode에서 프로젝트 열기**
2. **Shared 폴더를 프로젝트 내비게이터로 드래그**
   - 또는 File → Add Files to "ClipKeyboard"...
   - `Shared` 폴더 선택

3. **옵션 설정**
   - ✅ **Copy items if needed**: 체크 해제 (참조만)
   - ✅ **Create groups**: 선택
   - ✅ **Add to targets**: **ClipKeyboard**, **ClipKeyboard.tap**, **ClipKeyboardExtension** 모두 선택

### 2단계: 기존 모델 파일 정리

이제 각 타겟의 모델 파일에서 중복된 정의를 제거하고 Shared 모델을 import합니다.

#### iOS - `ClipKeyboard/Model/Memo.swift`

파일 상단에 추가:
```swift
// Shared 모델을 사용하므로 중복 정의 제거
// - Memo, Combo, ComboItem, SmartClipboardHistory 등은 SharedModels.swift에 있음
```

#### macOS - `ClipKeyboard.tap/Models.swift`

파일 상단에 추가:
```swift
// Shared 모델을 사용하므로 중복 정의 제거
// - Memo, Combo, ComboItem, SmartClipboardHistory 등은 SharedModels.swift에 있음
```

**중요**: 중복된 struct/enum 정의는 제거하되, 플랫폼별 헬퍼 함수나 확장은 유지하세요.

## 📝 개발 가이드

### 공통 모델 수정 시

**Shared/Models/SharedModels.swift**만 수정하면 iOS와 macOS 모두에 반영됩니다.

```swift
// ✅ 올바른 방법
// Shared/Models/SharedModels.swift에서 수정
struct Memo: Identifiable, Codable {
    var id = UUID()
    var title: String
    // 새 필드 추가
    var newField: String = ""
}
```

### 플랫폼별 기능 추가 시

각 타겟의 파일에서 독립적으로 작업합니다.

```swift
// ✅ iOS 전용 기능
// ClipKeyboard/Screens/...
struct MemoListView: View {
    // iOS 전용 UI
}

// ✅ macOS 전용 기능
// ClipKeyboard.tap/...
struct MemoListView: View {
    // macOS 전용 UI
}
```

### 플랫폼별 조건부 컴파일

Shared 파일에서 플랫폼별 코드가 필요한 경우:

```swift
#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
#endif
```

## 🚀 빌드 확인

설정 후 두 타겟 모두 빌드가 성공하는지 확인:

```bash
# iOS 빌드
xcodebuild -scheme "ClipKeyboard" -destination 'platform=iOS Simulator,name=iPhone 15' build

# macOS 빌드
xcodebuild -scheme "ClipKeyboard.tap" -destination 'platform=macOS' build
```

## ⚠️ 주의사항

1. **Shared 파일 수정 시**
   - 양쪽 플랫폼에 영향을 주므로 신중하게 수정
   - 빌드 후 iOS/macOS 모두 테스트

2. **데이터 호환성**
   - Shared 모델의 Codable 속성을 변경하면 기존 저장 데이터와 호환성 문제 발생 가능
   - 마이그레이션 로직 필요

3. **Target Membership 확인**
   - 새 Shared 파일 추가 시 항상 양쪽 타겟에 추가되었는지 확인

## 📊 파일 구조

### Before (중복)
```
ClipKeyboard/Model/Memo.swift          # iOS용 모델
ClipKeyboard.tap/Models.swift           # macOS용 모델 (중복!)
```

### After (공유)
```
Shared/Models/SharedModels.swift     # 공통 모델 (한 번만 정의)
ClipKeyboard/Model/Memo.swift          # iOS 전용 확장/헬퍼
ClipKeyboard.tap/Models.swift           # macOS 전용 확장/헬퍼
```

## 🔄 동기화

Git을 사용하므로 Shared 폴더의 변경사항은 자동으로 동기화됩니다.
팀원과 협업 시 Shared 파일 수정은 리뷰 후 머지를 권장합니다.

---

**문의**: 설정 중 문제가 있으면 `docs/IMPLEMENTATION_PLAN.md`를 참고하세요.
