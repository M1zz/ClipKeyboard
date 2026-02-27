<p align="center">
  <img src="docs/app-icon.png" alt="Clip Keyboard" width="120" height="120" style="border-radius: 22%;">
</p>

<h1 align="center">Clip Keyboard</h1>

<p align="center">
  <strong>반복 입력은 그만, 탭 한 번이면 끝</strong><br>
  자주 쓰는 메시지를 키보드에서 탭 한 번으로 입력하세요.
</p>

<p align="center">
  <a href="https://apps.apple.com/kr/app/clip-keyboard-quick-phrases/id1543660502">
    <img src="https://img.shields.io/badge/App_Store-Download-007AFF?style=for-the-badge&logo=apple&logoColor=white" alt="App Store">
  </a>
  <a href="https://m1zz.github.io/ClipKeyboard/">
    <img src="https://img.shields.io/badge/Landing_Page-Visit-5856D6?style=for-the-badge&logo=safari&logoColor=white" alt="Landing Page">
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS_17+-000000?style=flat-square&logo=apple" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.9-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/SwiftUI-blue?style=flat-square&logo=swift&logoColor=white" alt="SwiftUI">
  <img src="https://img.shields.io/badge/Mac_Catalyst-supported-333333?style=flat-square&logo=apple" alt="Mac Catalyst">
  <img src="https://img.shields.io/badge/version-4.0.0-brightgreen?style=flat-square" alt="Version">
</p>

---

## What is Clip Keyboard?

Clip Keyboard는 **자주 쓰는 문구를 저장하고 키보드에서 바로 입력**할 수 있는 iOS 앱입니다. 고객 응대, 이메일, 코드 리뷰까지 - 반복 타이핑 시간을 90% 절약합니다.

> **Landing Page**: [m1zz.github.io/clip-keyboard](https://m1zz.github.io/ClipKeyboard/)

## Features

### Core
- **Custom Keyboard** - iOS 키보드에서 저장한 문구를 탭 한 번으로 입력
- **Smart Clipboard** - 클립보드 히스토리를 자동 분류 (이메일, 전화번호, 주소, URL, 카드번호 등 15가지 타입)
- **Template System** - `{이름}`, `{날짜}` 같은 플레이스홀더로 동적 문구 생성
- **Combo** - 여러 메모를 순서대로 자동 입력

### Pro (v4.0)
- **iCloud Backup** - CloudKit 기반 메모 백업 및 동기화
- **Biometric Lock** - Face ID/Touch ID로 보안 메모 보호
- **OCR** - Vision Framework 기반 이미지 텍스트 인식
- **macOS Menu Bar** - Mac Catalyst 기반 메뉴바 앱 + 전역 단축키

### Privacy
- **데이터 수집 없음** - 모든 데이터는 기기에만 저장
- **광고 없음** - 일회성 결제, 평생 사용

## Tech Stack

| Category | Technology |
|----------|-----------|
| Language | Swift 5.9 |
| UI | SwiftUI |
| Min Target | iOS 17+ |
| Architecture | Manager/Service Pattern |
| Data | JSONEncoder/Decoder + App Group |
| Cloud | CloudKit |
| OCR | Vision Framework |
| Platform | iOS, macOS (Mac Catalyst) |

## Project Structure

```
ClipKeyboard/
├── ClipKeyboard/                # iOS Main App
│   ├── Model/                   # Data Models
│   ├── Screens/                 # SwiftUI Views
│   │   ├── List/                # Memo List
│   │   ├── Memo/                # Add/Edit Memo
│   │   ├── Template/            # Template Management
│   │   └── Component/           # Reusable Components
│   ├── Service/                 # Business Logic
│   └── Manager/                 # System Managers
├── ClipKeyboardExtension/       # iOS Keyboard Extension
├── ClipKeyboard.tap/            # macOS App (Mac Catalyst)
├── Shared/                      # Shared Models (iOS + macOS)
├── Config/                      # Build Configurations
├── docs/                        # Documentation & Landing Page
│   ├── index.html               # Marketing Landing Page
│   └── *.md                     # Design Guides, Release Notes
└── widget/                      # Widget Extension
```

## Getting Started

### Requirements
- Xcode 15+
- iOS 17+ SDK
- Apple Developer Account (for App Group & CloudKit)

### Build

```bash
# Clone
git clone https://github.com/m1zz/ClipKeyboard.git
cd ClipKeyboard

# Open in Xcode
open ClipKeyboard.xcodeproj
```

### Capabilities Required
- **App Groups**: `group.com.Ysoup.TokenMemo`
- **iCloud** (CloudKit)
- **Keychain Sharing**

## Landing Page

마케팅 랜딩 페이지는 `docs/` 디렉토리에 있으며 GitHub Pages로 호스팅됩니다.

- **URL**: [m1zz.github.io/clip-keyboard](https://m1zz.github.io/ClipKeyboard/)
- **Features**: 반응형 디자인, 다크모드 지원, App Store 연동
- **Deploy**: `docs/` 폴더를 GitHub Pages source로 설정

## License

All rights reserved. &copy; 2024 Clip Keyboard.

## Contact

- **Developer**: Leeo
- **Email**: leeo@kakao.com
- **GitHub**: [@m1zz](https://github.com/m1zz)
