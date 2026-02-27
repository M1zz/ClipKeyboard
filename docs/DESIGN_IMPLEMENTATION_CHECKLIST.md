# Design System Implementation Checklist

> Based on DESIGN_GUIDE.md v1.0 - "Native Neutral" Concept

**Status**: 🟡 In Progress
**Last Updated**: 2026-02-01

---

## 📋 Overall Progress

```
████████░░░░░░░░░░░░ 40% Complete
```

---

## ✅ Completed

### Concept & Documentation
- [x] Design guide documented (DESIGN_GUIDE.md)
- [x] Color extension created (ColorDesignSystem.swift)
- [x] "Silent Partner" concept implemented
- [x] Toast-only feedback system
- [x] Simplified empty state with friendly message

### Code Structure
- [x] Removed usage statistics
- [x] Simplified settings menu (11 → 8 items)
- [x] Removed clip count displays
- [x] Shortened error messages

---

## 🟡 In Progress / TODO

### 1. Asset Catalog Setup

**Priority**: 🔴 High

```
Asset Catalog Path: ClipKeyboard/Assets.xcassets/Colors/
```

#### Colors to Add

- [ ] **Primary.colorset**
  - Any Appearance: `#007AFF`
  - Dark Appearance: `#0A84FF`

- [ ] **Success.colorset**
  - Any Appearance: `#34C759`
  - Dark Appearance: `#30D158`

- [ ] **Destructive.colorset**
  - Any Appearance: `#FF3B30`
  - Dark Appearance: `#FF453A`

- [ ] **Favorite.colorset**
  - Any Appearance: `#FF9500`
  - Dark Appearance: `#FF9F0A`

**How to Add:**
1. Open Xcode
2. Navigate to Assets.xcassets
3. Right-click → New Color Set
4. Name it (e.g., "Primary")
5. In Attributes Inspector:
   - Set Appearances to "Any, Dark"
   - Set Any color to hex value
   - Set Dark color to hex value

---

### 2. Typography Standardization

**Priority**: 🟡 Medium

#### Update Font Styles

Replace custom font sizes with system styles:

**Files to Check:**
- [ ] `ClipKeyboardList.swift` - Use `.title3` for empty state question
- [ ] `MemoRowView.swift` - Use `.body` for clip text
- [ ] `SettingView.swift` - Use `.headline` for section headers
- [ ] `MemoAdd.swift` - Use `.headline` for buttons
- [ ] `KeyboardSetupOnboardingView.swift` - Use `.title2` for title

**Example Changes:**

```swift
// ❌ Before
Text("자주 치는 문장이 뭔가요?")
    .font(.system(size: 22))

// ✅ After (per design guide)
Text("자주 치는 문장이 뭔가요?")
    .font(.title3)
    .fontWeight(.medium)
```

```swift
// ❌ Before
Text("클립 텍스트")
    .font(.system(size: 17))

// ✅ After
Text("클립 텍스트")
    .font(.body)
```

---

### 3. Icon Standardization

**Priority**: 🟡 Medium

#### Replace Custom Icons with SF Symbols

**Files to Update:**
- [ ] Toolbar icons in `ClipKeyboardList.swift`
- [ ] Settings icons in `SettingView.swift`
- [ ] Button icons in `MemoAdd.swift`

**Icon Mapping (from design guide):**

| Current | Should Be | Location |
|---------|-----------|----------|
| "plus.circle" | "plus" | Add button |
| "info.circle" | "gearshape" | Settings |
| "magnifyingglass.circle" | "magnifyingglass" | Search |
| Custom heart | "heart" / "heart.fill" | Favorite |

**Example:**

```swift
// ❌ Before
Image(systemName: "plus.circle")

// ✅ After
Image(systemName: "plus")
    .foregroundColor(.appPrimary)
```

---

### 4. Color System Migration

**Priority**: 🔴 High

#### Replace Hardcoded Colors with Design System

**Files to Update:**
- [ ] `ClipKeyboardList.swift`
- [ ] `MemoRowView.swift`
- [ ] `SettingView.swift`
- [ ] `MemoAdd.swift`
- [ ] `ReviewRequestView.swift`
- [ ] `KeyboardSetupOnboardingView.swift`

**Example Changes:**

```swift
// ❌ Before
.foregroundColor(.blue)
.background(Color.white)
.foregroundColor(.red)

// ✅ After
.foregroundColor(.appPrimary)
.background(.appSurface)
.foregroundColor(.appDestructive)
```

---

### 5. Toast Component Standardization

**Priority**: 🟡 Medium

#### Current Implementation
- Toast exists in `MemoAdd.swift`
- Using basic styling

#### Design Guide Specs
```
Background: #1C1C1E 90%
Text: #FFFFFF
Icon: Success (#34C759)
Corner Radius: 20px (pill)
Position: Bottom center, above safe area
```

**TODO:**
- [ ] Create reusable `ToastView` component
- [ ] Apply design guide colors (.toastBackground, .toastText)
- [ ] Add success icon (checkmark)
- [ ] Use pill shape (capsule)
- [ ] Add slide-up animation (0.2s easeOut)

---

### 6. Button Style Standardization

**Priority**: 🟡 Medium

#### Create Button Styles

**New File:** `ClipKeyboard/Components/ButtonStyles.swift`

```swift
// Primary Button
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(Color.appPrimary)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// Secondary Button
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.appPrimary)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// Destructive Button
struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.appDestructive)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
```

**Usage:**
```swift
Button("저장") { }
    .buttonStyle(PrimaryButtonStyle())

Button("취소") { }
    .buttonStyle(SecondaryButtonStyle())

Button("삭제") { }
    .buttonStyle(DestructiveButtonStyle())
```

---

### 7. Search Bar Component

**Priority**: 🟢 Low

#### Current State
- Exists in `ClipKeyboardList.swift`
- Basic styling

#### Design Guide Specs
```
Background: Fill (#787880 20% / 36%)
Text: Primary
Placeholder: Tertiary
Corner Radius: 10px
```

**TODO:**
- [ ] Update background to `.appFill`
- [ ] Update text color to `.appTextPrimary`
- [ ] Update placeholder to `.appTextTertiary`
- [ ] Ensure 10px corner radius

---

### 8. Empty State Enhancement

**Priority**: ✅ Done (verify styling)

#### Current Implementation
- Question: "자주 치는 문장이 뭔가요?"
- Examples: "지금 가는 중?", "감사합니다?"
- CTA: "첫 클립 추가" button

#### Verify Against Design Guide
- [ ] Question uses `.title3` font
- [ ] Examples use `.appTextSecondary` color
- [ ] Button uses `PrimaryButtonStyle`
- [ ] Spacing follows design guide (20px between elements)

---

### 9. Dark Mode Verification

**Priority**: 🔴 High

#### Test All Screens

**Main App:**
- [ ] ClipKeyboardList - Light mode
- [ ] ClipKeyboardList - Dark mode
- [ ] SettingView - Light mode
- [ ] SettingView - Dark mode
- [ ] MemoAdd - Light mode
- [ ] MemoAdd - Dark mode
- [ ] Empty state - Light mode
- [ ] Empty state - Dark mode
- [ ] Onboarding - Light mode
- [ ] Onboarding - Dark mode

**Keyboard Extension:**
- [ ] Keyboard - Light mode
- [ ] Keyboard - Dark mode

#### Common Issues to Check
- [ ] No pure white (#FFFFFF) backgrounds in dark mode
- [ ] Text contrast ratio meets WCAG AA (4.5:1)
- [ ] Icons visible in both modes
- [ ] Separators visible but subtle

---

### 10. Motion & Haptics

**Priority**: 🟢 Low

#### Implement Design Guide Specs

**Animation Durations:**
- [ ] Button tap: 0.1s
- [ ] Screen transition: 0.3s
- [ ] Toast appear: 0.2s
- [ ] Toast dismiss: 0.15s
- [ ] Cell animation: 0.25s

**Easing:**
- [ ] Appear: `.easeOut`
- [ ] Dismiss: `.easeIn`
- [ ] Move: `.easeInOut`

**Haptic Feedback:**
- [ ] Clip tap: `.light` + scale 0.95
- [ ] Save complete: Toast slide up
- [ ] Delete: `.medium` + slide out
- [ ] Error: `.error` + shake

**Example:**
```swift
// Button tap animation
Button("저장") { }
    .scaleEffect(isPressed ? 0.95 : 1.0)
    .animation(.easeOut(duration: 0.1), value: isPressed)
    .simultaneousGesture(
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
    )
```

---

### 11. Accessibility

**Priority**: 🔴 High

#### Dynamic Type Support

- [ ] All text respects user's Dynamic Type settings
- [ ] Layouts adapt to larger text sizes
- [ ] No fixed height constraints that break with large text

**Example:**
```swift
// ✅ Good - adapts to Dynamic Type
Text("클립 텍스트")
    .font(.body)

// ❌ Bad - fixed size
Text("클립 텍스트")
    .font(.system(size: 17))
```

#### VoiceOver Support

- [ ] All buttons have accessibility labels
- [ ] Interactive elements have hints
- [ ] Reading order is logical
- [ ] Images have descriptions

**Example:**
```swift
Button(action: addMemo) {
    Image(systemName: "plus")
}
.accessibilityLabel("새 클립 추가")
.accessibilityHint("탭하여 새로운 클립을 생성합니다")
```

#### Color Contrast

- [ ] Text meets WCAG AA (4.5:1 minimum)
- [ ] Don't rely on color alone for information
- [ ] Icons have sufficient contrast

---

### 12. Localization

**Priority**: 🟡 Medium

#### Update Localizable.xcstrings

**New Strings to Add:**

**Empty State:**
- `"자주 치는 문장이 뭔가요?"`
- `"\"지금 가는 중\"?"`
- `"\"감사합니다\"?"`
- `"첫 클립 추가"`

**Onboarding:**
- `"키보드를 추가해주세요"`
- `"설정 > 키보드"`
- `"새 키보드 추가"`
- `"Clip Keyboard 선택"`
- `"나중에"`
- `"설정 열기"`

**Toast:**
- `"저장됨"`

**Review Request:**
- `"잘 쓰고 계신가요?"`
- `"별점 하나가\n1인 개발자에게 큰 힘이 됩니다."`
- `"별점 남기기"`

**Error Messages (shortened):**
- `"백업이 없습니다."`
- `"저장 실패. 앱을 재시작해주세요."`
- `"네트워크 연결을 확인해주세요."`
- All other shortened messages from CloudKitBackupService

---

## 🎯 Implementation Priority

### Phase 1 (Week 1) - Foundation
1. ✅ Asset Catalog color setup
2. ✅ Color system migration
3. ✅ Dark mode verification

### Phase 2 (Week 2) - Polish
4. ✅ Typography standardization
5. ✅ Icon standardization
6. ✅ Button styles
7. ✅ Toast component

### Phase 3 (Week 3) - Refinement
8. ✅ Motion & haptics
9. ✅ Accessibility
10. ✅ Localization

---

## 📝 Notes

### Design System Files

```
ClipKeyboard/
├── DESIGN_GUIDE.md (reference doc)
├── DESIGN_IMPLEMENTATION_CHECKLIST.md (this file)
├── Extensions/
│   └── ColorDesignSystem.swift (color system)
├── Components/ (to create)
│   ├── ButtonStyles.swift
│   ├── ToastView.swift
│   └── SearchBarView.swift
└── Assets.xcassets/
    └── Colors/
        ├── Primary.colorset
        ├── Success.colorset
        ├── Destructive.colorset
        └── Favorite.colorset
```

### Testing Checklist

Before marking as complete:
- [ ] Build succeeds without warnings
- [ ] All screens tested in Light mode
- [ ] All screens tested in Dark mode
- [ ] VoiceOver navigation tested
- [ ] Dynamic Type tested (smallest to largest)
- [ ] All animations smooth (60fps)
- [ ] No hardcoded colors remain
- [ ] All strings localized

---

## ✅ Completion Criteria

The design system implementation is complete when:

1. All checkboxes in this document are marked [x]
2. App passes design review against DESIGN_GUIDE.md
3. No hardcoded colors, fonts, or icons remain
4. Dark mode works flawlessly
5. Accessibility score is 100%
6. App feels "native" to iOS

---

**Current Status**: 40% complete - Foundation laid, styling in progress
**Next Steps**: Complete Asset Catalog setup, then migrate colors system-wide
