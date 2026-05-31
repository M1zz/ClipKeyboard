//
//  KeyboardLayoutSettings.swift
//  ClipKeyboard
//
//  키보드 레이아웃 및 언어 설정. 상단에 키보드 익스텐션 전체 미리보기를 포함.
//

import SwiftUI
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - KeyboardLayoutSettings

struct KeyboardLayoutSettings: View {

    // MARK: AppStorage — App Group 공유 (익스텐션과 동일 키)
    @AppStorage("keyboardColumnCount",    store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var columnCount:    Int    = 2
    @AppStorage("keyboardButtonHeight",   store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var buttonHeight:   Double = 56.0
    @AppStorage("keyboardButtonFontSize", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var buttonFontSize: Double = 17.0
    @AppStorage("keyboardUseCustomColors",store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var useCustomColors:Bool   = false
    @AppStorage("keyboardCustomBgHex",    store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var customBgHex:    String = ""
    @AppStorage("keyboardCustomKeyHex",   store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var customKeyHex:   String = ""
    @AppStorage("keyboardShowSearch",     store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var showSearch:     Bool   = false
    @AppStorage("keyboardShowRecent",     store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var showRecent:     Bool   = false
    @AppStorage("keyboardKoreanLayout",   store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var koreanLayout:   String = "dubeolsik"
    @AppStorage("keyboardTypingLang",     store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var defaultLang:    String = "english"
    // 한국어 입력 사용(기본 OFF). 영어 전용 사용자가 한/EN 토글을 보지 않도록 명시적으로 켜야 함.
    @AppStorage("keyboardKoreanEnabled",  store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var koreanEnabled:  Bool   = false

    @State private var customBgColor:  Color = .clear
    @State private var customKeyColor: Color = .clear
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // ── 상단 고정 실시간 미리보기 — 아래 설정을 바꾸면 즉시 반영된다 ──
            KeyboardPreviewView()
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusMd)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .background(theme.bg)

            List {
            // ── 2. 그리드 레이아웃 ─────────────────────────────────────
            Section {
                // 열 개수 — segmented
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("열 개수", comment: "Column count label"))
                        Spacer()
                        Text(String(format: NSLocalizedString("%d열", comment: "Column count value"), columnCount))
                            .foregroundColor(.secondary)
                    }
                    Picker("", selection: $columnCount) {
                        ForEach(1...5, id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 버튼 높이
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(NSLocalizedString("버튼 높이", comment: "Button height label"))
                        Spacer()
                        Text("\(Int(buttonHeight))pt").foregroundColor(.secondary)
                    }
                    Slider(value: $buttonHeight, in: 32...120, step: 1).tint(theme.accent)
                    HStack {
                        Text(NSLocalizedString("작게", comment: "Small")).font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(NSLocalizedString("크게", comment: "Large")).font(.caption).foregroundColor(.secondary)
                    }
                }

                // 글자 크기
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(NSLocalizedString("글자 크기", comment: "Font size label"))
                        Spacer()
                        Text("\(Int(buttonFontSize))pt").foregroundColor(.secondary)
                    }
                    Slider(value: $buttonFontSize, in: 10...36, step: 1).tint(theme.accent)
                    HStack {
                        Text(NSLocalizedString("작게", comment: "Small")).font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(NSLocalizedString("크게", comment: "Large")).font(.caption).foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(NSLocalizedString("그리드 레이아웃", comment: "Section: grid layout"))
            }

            // ── 3. 언어 설정 ───────────────────────────────────────────
            Section {
                // 한국어 입력 사용 — 기본 OFF. 켜야 키보드에 한/EN 토글과 한글 자판이 나타난다.
                Toggle(isOn: $koreanEnabled) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(NSLocalizedString("한국어 입력", comment: "Enable Korean input toggle"))
                        Text(NSLocalizedString("켜면 키보드에서 한국어도 입력할 수 있어요", comment: "Enable Korean input subtitle"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }

                if koreanEnabled {
                // 기본 언어 — Apple-style Picker (NavigationLink)
                Picker(NSLocalizedString("기본 언어", comment: "Default language picker label"), selection: $defaultLang) {
                    Label("English", systemImage: "globe").tag("english")
                    Label(NSLocalizedString("한국어", comment: "Korean language option"), systemImage: "globe.asia.australia.fill").tag("korean")
                }

                // 한국어 레이아웃 — Apple-style Picker (NavigationLink)
                Picker(NSLocalizedString("한국어 레이아웃", comment: "Korean layout picker label"), selection: $koreanLayout) {
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("두벌식", comment: "Korean layout: dubeolsik"))
                        Text(NSLocalizedString("QWERTY 스타일 (표준)", comment: "Dubeolsik subtitle"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .tag("dubeolsik")

                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("천지인", comment: "Korean layout: cheonjiin"))
                        Text(NSLocalizedString("3×3 키패드 스타일", comment: "Cheonjiin subtitle"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .tag("cheonjiin")
                }

                // 레이아웃 시각 가이드
                koreanLayoutGuide
                }   // if koreanEnabled
            } header: {
                Text(NSLocalizedString("언어", comment: "Section: language"))
            } footer: {
                Text(koreanEnabled
                     ? NSLocalizedString("키보드의 한/EN 버튼으로 언어를 전환할 수 있습니다. 기본 언어는 키보드를 처음 열었을 때 적용됩니다.", comment: "Language section footer")
                     : NSLocalizedString("이 설정을 켜면 키보드에 한/EN 전환 버튼이 추가됩니다.", comment: "Language section footer when Korean off"))
            }

            // ── 4. 표시 옵션 ───────────────────────────────────────────
            Section {
                Toggle(isOn: $showSearch) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(NSLocalizedString("검색창", comment: "Show search bar toggle"))
                        Text(NSLocalizedString("메모를 이름으로 빠르게 찾습니다", comment: "Search bar description"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Toggle(isOn: $showRecent) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(NSLocalizedString("최근 메모", comment: "Show recent snippets toggle"))
                        Text(NSLocalizedString("최근 사용한 메모 5개를 상단에 표시합니다", comment: "Recent snippets description"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(NSLocalizedString("표시 옵션", comment: "Section: display options"))
            }

            // ── 5. 색상 ────────────────────────────────────────────────
            Section {
                Toggle(isOn: $useCustomColors) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(NSLocalizedString("커스텀 색상 사용", comment: "Use custom colors toggle"))
                        Text(NSLocalizedString("기본 Paper 테마 대신 직접 색상을 지정합니다", comment: "Custom colors description"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                if useCustomColors {
                    ColorPicker(NSLocalizedString("배경색", comment: "Background color picker"),
                                selection: $customBgColor, supportsOpacity: false)
                        .onChange(of: customBgColor) { _, c in customBgHex = c.toHex() ?? "" }

                    ColorPicker(NSLocalizedString("키 색상", comment: "Key color picker"),
                                selection: $customKeyColor, supportsOpacity: false)
                        .onChange(of: customKeyColor) { _, c in customKeyHex = c.toHex() ?? "" }

                    Button {
                        customBgHex  = ""; customKeyHex  = ""
                        customBgColor = .clear; customKeyColor = .clear
                    } label: {
                        Label(NSLocalizedString("색상 초기화", comment: "Reset colors"), systemImage: "arrow.uturn.backward")
                            .foregroundColor(theme.accent).font(.footnote)
                    }
                }
            } header: {
                Text(NSLocalizedString("색상", comment: "Section: colors"))
            }

            // ── 6. 전체 초기화 ─────────────────────────────────────────
            Section {
                Button(role: .destructive) { resetToDefaults() } label: {
                    Label(NSLocalizedString("기본값으로 되돌리기", comment: "Reset to defaults"), systemImage: "arrow.counterclockwise")
                }
            }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle(NSLocalizedString("키보드 설정", comment: "Keyboard settings nav title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbarBackground(theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            if !customBgHex.isEmpty,  let c = Color(hex: customBgHex)  { customBgColor  = c }
            if !customKeyHex.isEmpty, let c = Color(hex: customKeyHex) { customKeyColor = c }
        }
    }

    // MARK: - Korean Layout Visual Guide

    private var koreanLayoutGuide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("레이아웃 미리보기", comment: "Layout preview label"))
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                // 두벌식
                layoutCard(
                    title: NSLocalizedString("두벌식", comment: "Dubeolsik Korean keyboard layout name"),
                    layoutId: "dubeolsik",
                    rows: [["ㅂ","ㅈ","ㄷ","ㄱ","ㅅ"],["ㅁ","ㄴ","ㅇ","ㄹ","ㅎ"],["ㅗ","ㅓ","ㅏ","ㅣ","ㅡ"]],
                    isSelected: koreanLayout == "dubeolsik"
                )
                // 천지인
                layoutCard(
                    title: NSLocalizedString("천지인", comment: "Cheonjiin Korean keyboard layout name"),
                    layoutId: "cheonjiin",
                    rows: [["ㅣ","ㆍ","ㅡ"],["ㄱㅋ","ㄴㄹ","ㄷㅌ"],["ㅂㅍ","ㅅㅎ","ㅈㅊ"]],
                    isSelected: koreanLayout == "cheonjiin"
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func layoutCard(title: String, layoutId: String, rows: [[String]], isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            ForEach(rows.indices, id: \.self) { ri in
                HStack(spacing: 3) {
                    ForEach(rows[ri].indices, id: \.self) { ci in
                        Text(rows[ri][ci])
                            .font(.system(size: 9, weight: .medium))
                            .frame(minWidth: 18, minHeight: 16)
                            .background(isSelected ? theme.accent.opacity(0.15) : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
                    }
                }
            }
            Text(title)
                .font(.caption2)
                .foregroundColor(isSelected ? theme.accent : .secondary)
                .padding(.top, 2)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusSm)
                .fill(isSelected ? theme.accent.opacity(0.08) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusSm)
                .strokeBorder(isSelected ? theme.accent.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .onTapGesture { if !isSelected { koreanLayout = layoutId } }
    }

    // MARK: - Reset

    private func resetToDefaults() {
        columnCount = 2; buttonHeight = 56; buttonFontSize = 17
        useCustomColors = false; customBgHex = ""; customKeyHex = ""
        customBgColor = .clear; customKeyColor = .clear
        showSearch = false; showRecent = false
        koreanLayout = "dubeolsik"; defaultLang = "english"
    }
}

// MARK: - KeyboardPreviewView

/// 키보드 익스텐션 전체를 설정 화면에서 실시간으로 미리 보여주는 뷰.
/// AppStorage를 직접 읽어 슬라이더/토글 변경이 즉시 반영된다.
struct KeyboardPreviewView: View {

    private let ud = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")

    @AppStorage("keyboardColumnCount",    store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var columnCount:    Int    = 2
    @AppStorage("keyboardButtonHeight",   store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var buttonHeight:   Double = 56.0
    @AppStorage("keyboardButtonFontSize", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var buttonFontSize: Double = 17.0
    @AppStorage("keyboardUseCustomColors",store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var useCustomColors:Bool   = false
    @AppStorage("keyboardCustomBgHex",    store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var customBgHex:    String = ""
    @AppStorage("keyboardCustomKeyHex",   store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var customKeyHex:   String = ""

    @State private var previewMemos: [Memo] = []
    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme { AppTheme.resolve(kind: .paper, isDark: colorScheme == .dark) }

    private var bgColor: Color {
        if useCustomColors, !customBgHex.isEmpty, let c = Color(hex: customBgHex) { return c }
        return theme.bg
    }
    private var keyColor: Color {
        if useCustomColors, !customKeyHex.isEmpty, let c = Color(hex: customKeyHex) { return c }
        return theme.surface
    }

    // 카테고리 탭 (익스텐션과 동일 로직)
    private var categoryFeatureEnabled: Bool { ud?.bool(forKey: "category.feature.enabled.v1") ?? false }
    private var allUserCats: [String] { ud?.stringArray(forKey: "userDefinedCategories_v1") ?? [] }
    private var hiddenCats: Set<String> { Set(ud?.stringArray(forKey: "hiddenCategoryTabs_v1") ?? []) }
    private var customIcons: [String: String] { ud?.dictionary(forKey: "userCategoryIcons_v1") as? [String: String] ?? [:] }

    private var categoryPages: [String] {
        guard categoryFeatureEnabled else { return [] }
        var pages = ["★all"]
        if !hiddenCats.contains("__favorites__"), previewMemos.contains(where: { $0.isFavorite }) {
            pages.append("★favorites")
        }
        pages.append(contentsOf: allUserCats.filter { cat in
            !hiddenCats.contains(cat) && previewMemos.contains { $0.category == cat }
        })
        return pages
    }

    private func catIcon(_ key: String) -> String {
        if key == "★all"       { return "square.grid.2x2.fill" }
        if key == "★favorites" { return "heart.fill" }
        if let c = customIcons[key] { return c }
        let palette = ["folder.fill","bookmark.fill","tag.fill","briefcase.fill",
                       "star.fill","heart.circle.fill","person.fill","house.fill"]
        let idx = allUserCats.firstIndex(of: key) ?? 0
        return palette[idx % palette.count]
    }
    private func catColor(_ key: String) -> Color {
        if key == "★all"       { return .blue }
        if key == "★favorites" { return .pink }
        let pal: [Color] = [.blue,.green,.orange,.purple,.teal,.indigo,.cyan]
        let idx = allUserCats.firstIndex(of: key) ?? 0
        return pal[idx % pal.count]
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: max(1, min(5, columnCount)))
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── 상단 헤더: 카테고리 탭 ──
            if !categoryPages.isEmpty {
                HStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(categoryPages.enumerated()), id: \.offset) { idx, key in
                                let sel = idx == 0
                                Image(systemName: catIcon(key))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(sel ? .white : theme.textMuted)
                                    .frame(width: 30, height: 26)
                                    .background(sel ? catColor(key) : keyColor)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                    }
                }
            }

            // ── 메모 그리드 ──
            ZStack {
                bgColor

                if previewMemos.isEmpty {
                    // 메모 없을 때 플레이스홀더
                    LazyVGrid(columns: gridColumns, spacing: 8) {
                        ForEach(0..<(columnCount * 2), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: theme.radiusSm)
                                .fill(keyColor.opacity(0.6))
                                .frame(height: min(buttonHeight, 50))
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.radiusSm)
                                        .strokeBorder(theme.divider, lineWidth: 0.5)
                                )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                } else {
                    let displayMemos = Array(previewMemos.prefix(columnCount * 3))
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: gridColumns, spacing: 8) {
                            ForEach(displayMemos) { memo in
                                ZStack(alignment: .bottomLeading) {
                                    RoundedRectangle(cornerRadius: theme.radiusSm)
                                        .fill(keyColor)
                                        .frame(height: min(buttonHeight, 60))
                                        .shadow(color: .black.opacity(0.10), radius: 1.5, y: 1)
                                    Text(memo.title)
                                        .font(.system(size: min(buttonFontSize, 14), weight: .medium))
                                        .foregroundColor(theme.text)
                                        .lineLimit(1)
                                        .padding(.horizontal, 7)
                                        .padding(.bottom, 5)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .disabled(true)
                }
            }
        }
        .background(bgColor)
        .onAppear {
            previewMemos = (try? MemoStore.shared.load(type: .memo)) ?? []
        }
    }
}

// MARK: - SecurePINSetupView

struct SecurePINSetupView: View {
    var onSave: (String) -> Void

    enum Step { case enter, confirm }

    @State private var step: Step = .enter
    @State private var firstPIN = ""
    @State private var currentPIN = ""
    @State private var mismatch = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.orange)
                    Text(step == .enter
                         ? NSLocalizedString("4자리 PIN 입력", comment: "PIN setup: enter step title")
                         : NSLocalizedString("PIN 확인", comment: "PIN setup: confirm step title"))
                        .font(.title3).fontWeight(.semibold)
                    if mismatch {
                        Text(NSLocalizedString("PIN이 일치하지 않습니다. 다시 시도하세요.", comment: "PIN mismatch error"))
                            .font(.caption).foregroundColor(.red)
                    } else {
                        Text(step == .enter
                             ? NSLocalizedString("보안 메모 잠금에 사용할 PIN을 입력하세요.", comment: "PIN setup: enter hint")
                             : NSLocalizedString("동일한 PIN을 한 번 더 입력하세요.", comment: "PIN setup: confirm hint"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.top, 32)

                HStack(spacing: 20) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i < currentPIN.count ? Color.orange : Color(UIColor.systemGray4))
                            .frame(width: 16, height: 16)
                    }
                }

                VStack(spacing: 12) {
                    ForEach([[1,2,3],[4,5,6],[7,8,9]], id: \.first) { row in
                        HStack(spacing: 20) {
                            ForEach(row, id: \.self) { n in pinDigitButton(String(n)) }
                        }
                    }
                    HStack(spacing: 20) {
                        Color.clear.frame(width: 80, height: 60)
                        pinDigitButton("0")
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if !currentPIN.isEmpty { currentPIN.removeLast() }
                        } label: {
                            Image(systemName: "delete.left.fill")
                                .font(.system(size: 22)).foregroundColor(.primary)
                                .frame(width: 80, height: 60)
                        }
                    }
                }
                Spacer()
            }
            .navigationTitle(NSLocalizedString("보안 PIN 설정", comment: "Secure PIN setup nav title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func pinDigitButton(_ digit: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            guard currentPIN.count < 4 else { return }
            currentPIN.append(digit)
            if currentPIN.count == 4 { advance() }
        } label: {
            Text(digit).font(.system(size: 24, weight: .medium)).foregroundColor(.primary)
                .frame(width: 80, height: 60)
                .background(Circle().fill(Color(UIColor.systemGray6)))
        }
    }

    private func advance() {
        if step == .enter {
            firstPIN = currentPIN; currentPIN = ""; mismatch = false; step = .confirm
        } else {
            if firstPIN == currentPIN {
                let hash = SHA256.hash(data: Data(firstPIN.utf8))
                    .compactMap { String(format: "%02x", $0) }.joined()
                onSave(hash)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                mismatch = true; step = .enter; firstPIN = ""; currentPIN = ""
            }
        }
    }
}

#Preview {
    NavigationStack { KeyboardLayoutSettings() }
}
