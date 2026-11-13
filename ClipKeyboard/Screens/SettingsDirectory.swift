//
//  SettingsDirectory.swift
//  ClipKeyboard
//
//  설정에 무엇이 어디 있는지 적은 단 하나의 표.
//
//  사용자 의견(2026-11): 고칠 수 있는 것이 많은데 어디로 가야 할지 감이 안 온다.
//  예) 키보드 언어를 더하려면 어디로 가나.
//
//  이 표를 두 곳이 읽는다.
//   - 설정 맨 위 검색 (`SettingsSearchResults`): "언어" 를 치면 "키보드 ▸ 입력 언어" 가 나온다
//   - 설정 첫 화면의 갈래 줄: 이름 아래에 안에 든 것 세 개를 흐리게 보인다
//  새 설정을 더하면 그 화면에 줄을 세우고 **여기에도 한 줄** 더한다.
//  갈래마다 맨 앞 세 줄이 갈래 줄 아래에 보이므로, 가장 자주 찾는 것을 앞에 둔다.
//

import SwiftUI
import LeeoKit

// MARK: - 갈래

/// 설정 첫 화면의 갈래. 순서가 곧 첫 화면의 순서다.
enum SettingsCategory: String, CaseIterable, Identifiable {
    case keyboard, shortcuts, appearance, usage, data, help, apps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keyboard: return NSLocalizedString("키보드", comment: "Settings section: keyboard")
        case .shortcuts: return NSLocalizedString("단축어", comment: "Settings section: shortcuts")
        case .appearance: return NSLocalizedString("화면과 표시", comment: "Settings section: appearance")
        case .usage: return NSLocalizedString("사용 기록", comment: "Usage passport settings entry")
        case .data: return NSLocalizedString("내 데이터", comment: "Settings section: my data")
        case .help: return NSLocalizedString("사용법과 문의", comment: "Settings section: how to use the app, tips and contact")
        case .apps: return NSLocalizedString("함께 쓰면 좋은 앱", comment: "Settings section: other apps by the same developer that pair well with this one")
        }
    }

    var systemImage: String {
        switch self {
        case .keyboard: return AppSymbol.keyboard
        case .shortcuts: return AppSymbol.textQuote
        case .appearance: return AppSymbol.paintbrush
        case .usage: return AppSymbol.checkmarkSealFill
        case .data: return AppSymbol.externaldrive
        case .help: return AppSymbol.questionmarkCircle
        case .apps: return AppSymbol.squareGrid2x2
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .keyboard: KeyboardSettingsView()
        case .shortcuts: ShortcutsSettingsView()
        case .appearance: AppearanceSettingsView()
        case .usage: UsagePassportView()
        case .data: MyDataSettingsView()
        case .help: HelpSettingsView()
        case .apps: AppInfoSettingsView()
        }
    }

    /// 갈래 줄 아래 흐린 한 줄. 안에 든 것 앞의 셋이다. 갈래 이름과 같은 줄 하나뿐이면 비운다.
    var summary: String? {
        let names = SettingsDirectory.entries
            .filter { $0.category == self && $0.title != title }
            .prefix(3)
            .map(\.title)
        return names.isEmpty ? nil : names.joined(separator: " · ")
    }
}

// MARK: - 한 줄

struct SettingsEntry: Identifiable {
    /// 바꾸지 않는다. 시험이 이 값으로 찾는다.
    let id: String
    let category: SettingsCategory
    /// 갈래 안에서 한 번 더 들어간 화면이면 그 이름(예: "단축어 표시"). 검색 결과의 길에 보인다.
    var page: String? = nil
    let title: String
    let systemImage: String
    /// 이름에 없지만 사람이 칠 만한 말. 쉼표로 가른 한 문구라 언어마다 그 나라 말로 옮긴다.
    var keywords: String = ""
    let destination: () -> AnyView

    /// 검색 결과 아래에 보이는 길. "키보드" 또는 "화면과 표시 ▸ 단축어 표시".
    var path: String {
        [category.title, page].compactMap { $0 }.joined(separator: " ▸ ")
    }
}

// MARK: - 표

enum SettingsDirectory {

    static var entries: [SettingsEntry] {
        keyboard + shortcuts + appearance + usage + data + help + apps
    }

    /// 이름이 맞는 것을 먼저, 그다음 숨은 말이 맞는 것, 끝으로 길(갈래 이름)이 맞는 것.
    /// 대소문자 · 악센트 · 띄어쓰기를 가리지 않는다("키보드높이" 로도 "키보드 높이" 를 찾는다).
    static func search(_ query: String) -> [SettingsEntry] {
        let q = normalize(query)
        guard !q.isEmpty else { return [] }
        let all = entries
        let byTitle = all.filter { normalize($0.title).contains(q) }
        let byKeyword = all.filter { e in
            !byTitle.contains { $0.id == e.id }
                && e.keywords.split(separator: ",").contains { normalize(String($0)).contains(q) }
        }
        let byPath = all.filter { e in
            !byTitle.contains { $0.id == e.id } && !byKeyword.contains { $0.id == e.id }
                && normalize(e.path).contains(q)
        }
        return byTitle + byKeyword + byPath
    }

    private static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .filter { !$0.isWhitespace }
    }

    // MARK: 키보드

    private static var keyboard: [SettingsEntry] {
        let c = SettingsCategory.keyboard
        return [
            .init(id: "keyboard.languages", category: c,
                  title: NSLocalizedString("입력 언어", comment: "Settings: typing languages screen title"),
                  systemImage: AppSymbol.globe,
                  keywords: NSLocalizedString("언어 추가, 자판, 한국어, 영어, 일본어, 중국어, 지구본, 키보드 추가",
                                              comment: "Settings search keywords for the keyboard's typing languages screen. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(TypingLanguagesSettings()) }),
            .init(id: "keyboard.layout", category: c,
                  title: NSLocalizedString("키보드 레이아웃", comment: "Keyboard layout"),
                  systemImage: AppSymbol.rectangle3Group,
                  keywords: NSLocalizedString("키보드 높이, 키 크기, 글자 크기, 열 개수, 보내기 키, 붙여넣기 키, 숫자 판, 검색창",
                                              comment: "Settings search keywords for the keyboard layout screen. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(KeyboardLayoutSettings()) }),
            .init(id: "keyboard.vibration", category: c,
                  title: NSLocalizedString("키보드 진동", comment: "Toggle: vibrate when using the keyboard"),
                  systemImage: AppSymbol.iphoneRadiowaves,
                  keywords: NSLocalizedString("햅틱, 소리, 키 소리", comment: "Settings search keywords for keyboard vibration. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(KeyboardSettingsView()) }),
            .init(id: "keyboard.fullAccess", category: c,
                  title: NSLocalizedString("전체 접근 허용", comment: "Settings row: keyboard Full Access"),
                  systemImage: AppSymbol.lockShieldFill,
                  destination: { AnyView(FullAccessGuideView()) }),
            .init(id: "keyboard.switchBack", category: c,
                  title: NSLocalizedString("단축어 넣고 쓰던 키보드로", comment: "Toggle: switch back to the previous keyboard after inserting a snippet"),
                  systemImage: AppSymbol.keyboard,
                  destination: { AnyView(KeyboardSettingsView()) }),
            .init(id: "keyboard.textReplacement", category: c,
                  title: NSLocalizedString("텍스트 대치", comment: "Toggle: apply the iPhone's Text Replacement while typing on this keyboard"),
                  systemImage: AppSymbol.textCursor,
                  destination: { AnyView(KeyboardSettingsView()) }),
            .init(id: "keyboard.learnsPicks", category: c,
                  title: NSLocalizedString("자주 넣는 단축어 꺼내 주기", comment: "Toggle: the keyboard learns which snippet you insert after a word and suggests it"),
                  systemImage: AppSymbol.sparkles,
                  destination: { AnyView(KeyboardSettingsView()) }),
            .init(id: "keyboard.compactFill", category: c,
                  title: NSLocalizedString("빈칸 한 칸씩 채우기", comment: "Compact placeholder filling toggle"),
                  systemImage: AppSymbol.textJustify,
                  destination: { AnyView(KeyboardSettingsView()) }),
            .init(id: "keyboard.ai", category: c,
                  title: NSLocalizedString("Apple Intelligence", comment: "AI settings status row title"),
                  systemImage: AppSymbol.sparkles,
                  destination: { AnyView(AISettingsView()) }),
            .init(id: "keyboard.setupGuide", category: c,
                  title: NSLocalizedString("키보드 설정 가이드", comment: "Keyboard setup guide"),
                  systemImage: AppSymbol.keyboardBadgeEye,
                  keywords: NSLocalizedString("키보드 켜기, 키보드 추가, 설치", comment: "Settings search keywords for the guide that shows how to turn on the keyboard in iOS Settings. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(KeyboardSettingsView()) }),
            .init(id: "keyboard.onlyThis", category: c,
                  title: NSLocalizedString("클립키보드 하나로 쓰기", comment: "Only-this-keyboard guide title"),
                  systemImage: AppSymbol.keyboard,
                  destination: { AnyView(OnlyThisKeyboardGuideView()) }),
            .init(id: "keyboard.pasteAlert", category: c,
                  title: NSLocalizedString("붙여넣기 알림 허용 끄기", comment: "Paste notification settings title"),
                  systemImage: AppSymbol.docOnClipboard,
                  destination: { AnyView(CopyPasteView()) }),
            .init(id: "keyboard.actionButton", category: c,
                  title: NSLocalizedString("버튼 한 번으로 담기", comment: "Action Button capture guide title"),
                  systemImage: AppSymbol.buttonProgrammable,
                  destination: { AnyView(ActionButtonGuideView()) }),
        ]
    }

    // MARK: 단축어

    private static var shortcuts: [SettingsEntry] {
        let c = SettingsCategory.shortcuts
        return [
            .init(id: "shortcuts.categories", category: c,
                  title: NSLocalizedString("카테고리 관리", comment: "Manage categories settings entry"),
                  systemImage: AppSymbol.folder,
                  keywords: NSLocalizedString("폴더, 분류, 아이콘, 색", comment: "Settings search keywords for managing categories. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(CategorySettings()) }),
            .init(id: "shortcuts.placeholders", category: c,
                  title: NSLocalizedString("빈칸 관리", comment: "Placeholder management title (by name)"),
                  systemImage: AppSymbol.textJustify,
                  keywords: NSLocalizedString("템플릿, 변수", comment: "Settings search keywords for managing template placeholders. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(ShortcutsSettingsView()) }),
            .init(id: "shortcuts.inbox", category: c,
                  title: NSLocalizedString("보관함", comment: "Quick note inbox entry"),
                  systemImage: AppSymbol.tray,
                  destination: { AnyView(QuickNoteInboxView()) }),
            .init(id: "shortcuts.cardTap", category: c,
                  title: NSLocalizedString("카드를 누르면 메뉴 열기", comment: "Settings toggle: in the app's list, tapping a Phrase card opens its menu (edit, delete...) instead of copying it"),
                  systemImage: AppSymbol.handTap,
                  destination: { AnyView(ShortcutsSettingsView()) }),
            .init(id: "shortcuts.profile", category: c,
                  title: NSLocalizedString("나에게 맞추기", comment: "Usage profile settings title: the app adapts to how you use it"),
                  systemImage: AppSymbol.wandAndSparkles,
                  destination: { AnyView(UsageProfileSettingsView()) }),
            .init(id: "shortcuts.usageGuide", category: c,
                  title: NSLocalizedString("이렇게들 써요", comment: "Use cases / usage scenarios"),
                  systemImage: AppSymbol.bookPages,
                  destination: { AnyView(UsageGuideView()) }),
        ]
    }

    // MARK: 화면과 표시

    private static var appearance: [SettingsEntry] {
        let c = SettingsCategory.appearance
        let display = NSLocalizedString("단축어 표시", comment: "Memo display settings entry")
        return [
            .init(id: "appearance.display", category: c,
                  title: display,
                  systemImage: AppSymbol.rectangleGrid1x2,
                  destination: { AnyView(DisplaySettingsView()) }),
            .init(id: "appearance.keyColor", category: c,
                  title: NSLocalizedString("키 컬러", comment: "Settings: key color"),
                  systemImage: AppSymbol.paintbrush,
                  keywords: NSLocalizedString("색, 테마, 다크 모드", comment: "Settings search keywords for the key color screen. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(KeyColorSettingsView()) }),
            .init(id: "appearance.background", category: c,
                  title: NSLocalizedString("배경 이미지", comment: "Menu: list background image"),
                  systemImage: AppSymbol.photoOnRectangleAngled,
                  keywords: NSLocalizedString("배경, 사진, 벽지", comment: "Settings search keywords for the list background image. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(ListBackgroundSettings()) }),
            .init(id: "appearance.language", category: c,
                  title: NSLocalizedString("언어", comment: "Settings: app language"),
                  systemImage: AppSymbol.globe,
                  keywords: NSLocalizedString("앱 언어, 한국어, 영어", comment: "Settings search keywords for the app's display language. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(LanguageSettingsView()) }),
            .init(id: "appearance.firstScreen", category: c,
                  title: NSLocalizedString("첫 화면", comment: "Settings section: first screen"),
                  systemImage: AppSymbol.squareGrid2x2,
                  destination: { AnyView(FirstScreenSettingsView()) }),
            .init(id: "appearance.contentPreview", category: c, page: display,
                  title: NSLocalizedString("칸 안에 내용 보이기", comment: "Setting: how the snippet's content is previewed inside its card or key"),
                  systemImage: AppSymbol.sparkles,
                  keywords: NSLocalizedString("미리보기, 내용", comment: "Settings search keywords for showing a snippet's content inside its card. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(DisplaySettingsView()) }),
            .init(id: "appearance.listLayout", category: c, page: display,
                  title: NSLocalizedString("목록 모양", comment: "Setting: show the snippet list as a grid or as a list"),
                  systemImage: AppSymbol.squareGrid2x2,
                  keywords: NSLocalizedString("격자, 리스트", comment: "Settings search keywords for choosing grid or list layout. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(DisplaySettingsView()) }),
            .init(id: "appearance.cardHeight", category: c, page: display,
                  title: NSLocalizedString("단축어 높이", comment: "Memo cell height"),
                  systemImage: AppSymbol.rectangleGrid1x2,
                  destination: { AnyView(DisplaySettingsView()) }),
            .init(id: "appearance.recentTime", category: c, page: display,
                  title: NSLocalizedString("최근 복사한 때", comment: "Setting: how the copy time is shown on the Recent page"),
                  systemImage: AppSymbol.clock,
                  destination: { AnyView(DisplaySettingsView()) }),
            .init(id: "appearance.delight", category: c,
                  title: NSLocalizedString("입력 반응", comment: "Delight effects toggle title"),
                  systemImage: AppSymbol.sparkles,
                  destination: { AnyView(AppearanceSettingsView()) }),
            .init(id: "appearance.allFeatures", category: c,
                  title: NSLocalizedString("모든 기능 바로 보기", comment: "Settings toggle: show every feature on the main screens right away"),
                  systemImage: AppSymbol.eyeFill,
                  destination: { AnyView(AppearanceSettingsView()) }),
        ]
    }

    // MARK: 사용 기록

    private static var usage: [SettingsEntry] {
        [
            .init(id: "usage.passport", category: .usage,
                  title: SettingsCategory.usage.title,
                  systemImage: SettingsCategory.usage.systemImage,
                  keywords: NSLocalizedString("통계, 아낀 시간", comment: "Settings search keywords for the usage record screen. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(UsagePassportView()) }),
        ]
    }

    // MARK: 내 데이터

    private static var data: [SettingsEntry] {
        let c = SettingsCategory.data
        return [
            .init(id: "data.backup", category: c,
                  title: NSLocalizedString("백업 및 복원", comment: "Backup and restore"),
                  systemImage: AppSymbol.icloudAndArrowUp,
                  keywords: NSLocalizedString("iCloud, 내보내기, 가져오기, 파일", comment: "Settings search keywords for backup and restore. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(CloudBackupView()) }),
            .init(id: "data.pin", category: c,
                  title: NSLocalizedString("보안 단축어 PIN", comment: "Secure memo PIN"),
                  systemImage: AppSymbol.lockFill,
                  keywords: NSLocalizedString("비밀번호, 잠금, Face ID", comment: "Settings search keywords for the secure snippet PIN. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(SecurePINSettings()) }),
            .init(id: "data.clipboard", category: c,
                  title: NSLocalizedString("클립보드 기록", comment: "Clipboard history settings entry"),
                  systemImage: AppSymbol.docOnClipboard,
                  keywords: NSLocalizedString("복사, 최근", comment: "Settings search keywords for clipboard history. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(ClipboardList()) }),
            .init(id: "data.sync", category: c,
                  title: NSLocalizedString("기기 간 동기화 (베타)", comment: "Cross-device sync section header"),
                  systemImage: AppSymbol.icloudFill,
                  keywords: NSLocalizedString("동기화, iCloud, Mac, iPad", comment: "Settings search keywords for cross-device sync. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(MyDataSettingsView()) }),
            .init(id: "data.autoBackup", category: c,
                  title: NSLocalizedString("자동 백업", comment: "Auto backup label"),
                  systemImage: AppSymbol.clockArrowCirclepath,
                  destination: { AnyView(LeeoVaultView(appName: ClipKeyboardSpec.displayName)) }),
            .init(id: "data.history", category: c,
                  title: NSLocalizedString("변경 기록 (되돌리기)", comment: "Memo change history / undo"),
                  systemImage: AppSymbol.arrowUturnBackward,
                  keywords: NSLocalizedString("되돌리기, 복구, 지운 단축어", comment: "Settings search keywords for the change history where edits and deletions can be undone. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(MemoHistoryView()) }),
            .init(id: "data.wipe", category: c,
                  title: NSLocalizedString("모든 데이터 삭제", comment: "Delete all data settings entry"),
                  systemImage: AppSymbol.trash,
                  destination: { AnyView(MyDataSettingsView()) }),
        ]
    }

    // MARK: 사용법과 문의

    private static var help: [SettingsEntry] {
        let c = SettingsCategory.help
        return [
            .init(id: "help.guide", category: c,
                  title: NSLocalizedString("사용 가이드", comment: "User guide"),
                  systemImage: AppSymbol.bookClosed,
                  keywords: NSLocalizedString("도움말, 사용법, 튜토리얼", comment: "Settings search keywords for the user guide. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(TutorialView()) }),
            .init(id: "help.feedback", category: c,
                  title: NSLocalizedString("피드백 보내기", comment: "Send feedback settings entry"),
                  systemImage: AppSymbol.envelopeBadge,
                  keywords: NSLocalizedString("문의, 의견, 버그, 연락, 메일", comment: "Settings search keywords for sending feedback to the developer. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(FeedbackView()) }),
            .init(id: "help.changelog", category: c,
                  title: NSLocalizedString("변경사항", comment: "Changelog settings entry"),
                  systemImage: AppSymbol.listBulletRectangle,
                  destination: { AnyView(ChangelogView()) }),
            .init(id: "help.roadmap", category: c,
                  title: LeeoRoadmapText.entry,
                  systemImage: AppSymbol.calendar,
                  destination: { AnyView(RoadmapScreen()) }),
            .init(id: "help.didYouKnow", category: c,
                  title: NSLocalizedString("그거 아세요?", comment: "Did you know header"),
                  systemImage: AppSymbol.infoCircle,
                  destination: { AnyView(DidYouKnowListView()) }),
            .init(id: "help.accessibility", category: c,
                  title: NSLocalizedString("손쉬운 사용", comment: "Accessibility guide settings entry"),
                  systemImage: AppSymbol.infoCircle,
                  destination: { AnyView(AccessibilityGuideView()) }),
        ]
    }

    // MARK: 함께 쓰면 좋은 앱

    private static var apps: [SettingsEntry] {
        [
            .init(id: "apps.mac", category: .apps,
                  title: NSLocalizedString("ClipKeyboard for Mac", comment: "Mac app intro title"),
                  systemImage: AppSymbol.macbook,
                  keywords: NSLocalizedString("맥, 메뉴 막대", comment: "Settings search keywords for the Mac app. Comma-separated words a user of this language would type to find it; translate into natural search words, not literally"),
                  destination: { AnyView(MacAppIntroView()) }),
        ]
    }
}

// MARK: - 검색 결과

/// 설정 검색창에 글이 있을 때 설정 목록 대신 서는 결과.
struct SettingsSearchResults: View {
    @Environment(\.appTheme) private var theme
    let query: String

    var body: some View {
        let results = SettingsDirectory.search(query)
        if results.isEmpty {
            Section {
                ContentUnavailableView.search(text: query)
                    .listRowBackground(Color.clear)
            }
        } else {
            Section {
                ForEach(results) { entry in
                    FoldLink(destination: entry.destination()) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                Text(entry.path)
                                    .font(.caption)
                                    .foregroundStyle(theme.textMuted)
                            }
                        } icon: {
                            Image(systemName: entry.systemImage)
                        }
                    }
                }
            }
        }
    }
}
