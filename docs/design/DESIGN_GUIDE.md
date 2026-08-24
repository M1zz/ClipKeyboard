# 📐 ClipKeyboard Design Guide

> 클립키보드 디자인 시스템 최종본
> Version: 1.0
> Last Updated: 2025-02-01

---

## 디자인 철학

```
"최고의 도구는 존재감이 없다"

iOS와 완벽히 동화되어
사용자가 "다른 앱"이라고 느끼지 않게.
```

---

## 컨셉

| 항목 | 정의 |
|------|------|
| **이름** | Native Neutral |
| **정체성** | 조용한 도구 |
| **핵심** | 시스템과 동화, 투명함 |
| **목표** | "원래 있던 기능 같은" 느낌 |

---

## 컬러 시스템

### Primary Colors

| 역할 | Light | Dark | 용도 |
|------|-------|------|------|
| **Primary** | `#007AFF` | `#0A84FF` | CTA, 링크, 선택 |
| **Success** | `#34C759` | `#30D158` | 저장 완료 |
| **Destructive** | `#FF3B30` | `#FF453A` | 삭제 |
| **Favorite** | `#FF9500` | `#FF9F0A` | 즐겨찾기 |

### Background

| 레벨 | Light | Dark | 용도 |
|------|-------|------|------|
| **Base** | `#F2F2F7` | `#000000` | 앱 배경 |
| **Surface** | `#FFFFFF` | `#1C1C1E` | 카드, 셀 |
| **Elevated** | `#FFFFFF` | `#2C2C2E` | 모달, 시트 |

### Text

| 레벨 | Light | Dark | 용도 |
|------|-------|------|------|
| **Primary** | `#000000` | `#FFFFFF` | 본문 |
| **Secondary** | `#3C3C43` 60% | `#EBEBF5` 60% | 보조 텍스트 |
| **Tertiary** | `#3C3C43` 30% | `#EBEBF5` 30% | 힌트, 플레이스홀더 |

### UI Elements

| 요소 | Light | Dark |
|------|-------|------|
| **Separator** | `#3C3C43` 30% | `#545458` 60% |
| **Fill** | `#787880` 20% | `#787880` 36% |
| **Keyboard BG** | `#D1D3D9` | `#2C2C2E` |

---

## 타이포그래피

### 폰트: SF Pro (시스템)

| 용도 | 스타일 | 크기 | 무게 |
|------|--------|------|------|
| 네비게이션 | Large Title | 34pt | Bold |
| 섹션 헤더 | Headline | 17pt | Semibold |
| 본문 | Body | 17pt | Regular |
| 클립 텍스트 | Body | 17pt | Regular |
| 버튼 | Headline | 17pt | Semibold |
| 보조 텍스트 | Subhead | 15pt | Regular |
| 토스트 | Footnote | 13pt | Regular |
| 캡션 | Caption | 12pt | Regular |

---

## 아이콘

### SF Symbols 사용

| 용도 | 심볼 | 컬러 |
|------|------|------|
| 추가 | `plus` | Primary |
| 설정 | `gearshape` | Secondary |
| 검색 | `magnifyingglass` | Secondary |
| 즐겨찾기 (빈) | `heart` | Secondary |
| 즐겨찾기 (채움) | `heart.fill` | Favorite |
| 삭제 | `trash` | Destructive |
| 편집 | `pencil` | Secondary |
| 체크 | `checkmark` | Success |

---

## 컴포넌트

### 1. 클립 셀

```
┌─────────────────────────────────────┐
│                                     │
│  클립 텍스트                      ♡  │
│                                     │
└─────────────────────────────────────┘
```

| 속성 | Light | Dark |
|------|-------|------|
| 배경 | `#FFFFFF` | `#1C1C1E` |
| 텍스트 | `#000000` | `#FFFFFF` |
| 모서리 | 12px | 12px |
| 그림자 | `0 1px 3px rgba(0,0,0,0.08)` | none |
| 패딩 | 16px | 16px |

**선택 상태:**
- 배경: Primary 10% (`#E5F1FF` / `#0A84FF` 15%)
- 또는: scale 0.98

### 2. 키보드 버튼

```
┌──────────┐
│  클립    │
└──────────┘
```

| 속성 | Light | Dark |
|------|-------|------|
| 배경 | `#FFFFFF` | `#3A3A3C` |
| 텍스트 | `#000000` | `#FFFFFF` |
| 테두리 | `#C7C7CC` | none |
| 모서리 | 8px | 8px |

### 3. Primary 버튼

```
┌─────────────────┐
│      저장       │
└─────────────────┘
```

| 속성 | 값 |
|------|-----|
| 배경 | Primary (`#007AFF`) |
| 텍스트 | `#FFFFFF` |
| 모서리 | 10px |
| 높이 | 50px |
| 폰트 | Headline (17pt Semibold) |

### 4. Secondary 버튼

```
┌─────────────────┐
│      취소       │
└─────────────────┘
```

| 속성 | 값 |
|------|-----|
| 배경 | transparent |
| 텍스트 | Primary (`#007AFF`) |
| 폰트 | Headline (17pt Semibold) |

### 5. Destructive 버튼

```
┌─────────────────┐
│      삭제       │
└─────────────────┘
```

| 속성 | 값 |
|------|-----|
| 배경 | transparent |
| 텍스트 | Destructive (`#FF3B30`) |
| 폰트 | Headline (17pt Semibold) |

### 6. 토스트

```
┌─────────────────────────────┐
│      ✓ 저장됨               │
└─────────────────────────────┘
```

| 속성 | 값 |
|------|-----|
| 배경 | `#1C1C1E` 90% |
| 텍스트 | `#FFFFFF` |
| 아이콘 | Success (`#34C759`) |
| 모서리 | 20px (pill) |
| 위치 | 하단 중앙, safe area 위 |

### 7. 검색바

```
┌─────────────────────────────┐
│  🔍  검색                    │
└─────────────────────────────┘
```

| 속성 | Light | Dark |
|------|-------|------|
| 배경 | Fill (`#787880` 20%) | Fill (`#787880` 36%) |
| 텍스트 | Primary | Primary |
| 플레이스홀더 | Tertiary | Tertiary |
| 모서리 | 10px | 10px |

### 8. 빈 화면

```
┌─────────────────────────────┐
│                             │
│    자주 치는 문장이 뭔가요?   │  ← Primary text
│                             │
│    "지금 가는 중"?           │  ← Secondary text
│                             │
│    [+ 첫 클립 추가]          │  ← Primary button
│                             │
└─────────────────────────────┘
```

---

## 화면별 적용

### 메인 화면

```
┌─────────────────────────────┐  ← Base background
│ 내 클립              +  ⚙️  │  ← Large Title, Primary icons
├─────────────────────────────┤
│ 🔍 검색                     │  ← Search bar
├─────────────────────────────┤
│                             │
│  ┌───────────────────┐      │  ← Surface card
│  │ 지금 가는 중!      │  ♡   │
│  └───────────────────┘      │
│  ┌───────────────────┐      │
│  │ 감사합니다         │      │
│  └───────────────────┘      │
│                             │
└─────────────────────────────┘
```

### 키보드

```
┌─────────────────────────────────────┐  ← Keyboard BG
│ [즐겨찾기]  [전체]      [🔍]  [앱]   │  ← 탭: 선택 Primary / 미선택 Secondary
├─────────────────────────────────────┤
│                                     │
│  ┌──────────┐  ┌──────────┐        │  ← 키보드 버튼
│  │ 지금 가는 │  │ 감사합니다 │        │
│  └──────────┘  └──────────┘        │
│  ┌──────────┐  ┌──────────┐        │
│  │ 5분 후   │  │ 확인     │        │
│  └──────────┘  └──────────┘        │
│                                     │
├─────────────────────────────────────┤
│ [🌐]      [스페이스]        [리턴]  │
└─────────────────────────────────────┘
```

### 설정

```
┌─────────────────────────────┐  ← Base background
│ 설정                        │  ← Large Title
├─────────────────────────────┤
│                             │
│ 키보드                      │  ← Section header (Secondary)
│ ┌─────────────────────────┐ │  ← Grouped surface
│ │ 키보드 설정          >  │ │
│ ├─────────────────────────┤ │  ← Separator
│ │ 키 소리           [OFF] │ │
│ ├─────────────────────────┤ │
│ │ 햅틱              [ON]  │ │
│ └─────────────────────────┘ │
│                             │
└─────────────────────────────┘
```

---

## 모션

### 지속 시간

| 유형 | 시간 |
|------|------|
| 버튼 탭 | 0.1s |
| 화면 전환 | 0.3s |
| 토스트 등장 | 0.2s |
| 토스트 퇴장 | 0.15s |
| 셀 애니메이션 | 0.25s |

### 이징

| 유형 | 커브 |
|------|------|
| 등장 | easeOut |
| 퇴장 | easeIn |
| 이동 | easeInOut |

### 피드백

| 액션 | 피드백 |
|------|--------|
| 클립 탭 | 햅틱 light + scale 0.95 |
| 저장 완료 | 토스트 slide up |
| 삭제 | 햅틱 medium + slide out |
| 에러 | 햅틱 error + shake |

---

## 앱 아이콘

### 디자인

```
┌─────────────────┐
│                 │
│    ┌─────┐      │
│    │     │      │  ← 키보드 키 형태
│    └─────┘      │
│        _        │  ← 커서
│                 │
└─────────────────┘
```

| 속성 | 값 |
|------|-----|
| 배경 | `#007AFF` |
| 아이콘 | `#FFFFFF` |
| 스타일 | 미니멀, 플랫 |

---

## 스크린샷 (마케팅)

> 앱 내부는 네이티브, 마케팅은 눈에 띄게

### 배경 옵션

| 옵션 | 컬러 |
|------|------|
| A (추천) | `#007AFF` → `#5856D6` 그라데이션 |
| B | `#000000` |
| C | `#F2F2F7` |

### 텍스트

| 배경 | 텍스트 |
|------|--------|
| 어두운 배경 | `#FFFFFF` |
| 밝은 배경 | `#000000` |
| 강조 | `#007AFF` |

---

## 규칙

### ✓ 항상 할 것

```
✓ SF Pro 시스템 폰트
✓ SF Symbols 아이콘
✓ iOS 시맨틱 컬러 사용
✓ 시스템 키보드와 동일한 스타일
✓ 다크모드 완벽 지원
✓ Dynamic Type 지원
✓ 충분한 색상 대비 (접근성)
```

### ✗ 절대 하지 않을 것

```
✗ 커스텀 폰트
✗ 하드코딩 컬러
✗ 과한 그라데이션
✗ 네온/형광 컬러
✗ 복잡한 애니메이션
✗ 다크모드에서 순백(#FFF) 배경
✗ 브랜드 컬러 과다 사용
```

---

## SwiftUI 컬러 코드

```swift
import SwiftUI

extension Color {
    // Primary
    static let appPrimary = Color("Primary") // Asset catalog
    static let appSuccess = Color("Success")
    static let appDestructive = Color("Destructive")
    static let appFavorite = Color("Favorite")

    // Background
    static let appBackground = Color(UIColor.systemGroupedBackground)
    static let appSurface = Color(UIColor.secondarySystemGroupedBackground)

    // Text
    static let appTextPrimary = Color(UIColor.label)
    static let appTextSecondary = Color(UIColor.secondaryLabel)
    static let appTextTertiary = Color(UIColor.tertiaryLabel)
}
```

### Asset Catalog 설정

**Primary:**
- Any: `#007AFF`
- Dark: `#0A84FF`

**Success:**
- Any: `#34C759`
- Dark: `#30D158`

**Destructive:**
- Any: `#FF3B30`
- Dark: `#FF453A`

**Favorite:**
- Any: `#FF9500`
- Dark: `#FF9F0A`

---

## 체크리스트

### 개발 전 확인

- [ ] Asset Catalog에 컬러 세트 등록
- [ ] 다크모드 대응 컬러 설정
- [ ] SF Symbols 버전 확인 (iOS 16+)

### 화면별 확인

- [ ] 메인 화면 라이트/다크
- [ ] 키보드 라이트/다크
- [ ] 설정 화면 라이트/다크
- [ ] 빈 화면 라이트/다크
- [ ] 토스트 표시 확인
- [ ] 모든 버튼 상태 (기본/눌림/비활성)

### 최종 확인

- [ ] Dynamic Type 대응
- [ ] VoiceOver 접근성
- [ ] 색맹 대응 (컬러만으로 구분 X)
- [ ] 키보드 Extension 다크모드

---

## 버전 히스토리

| 버전 | 날짜 | 변경 |
|------|------|------|
| 1.0 | 2025-02-01 | 최초 작성 |
