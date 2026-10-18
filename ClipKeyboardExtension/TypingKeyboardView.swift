//
//  TypingKeyboardView.swift
//  ClipKeyboardExtension
//
//  **자판.** 시스템 키보드 없이 우리 키보드만으로 글을 치게 한다.
//
//  사용자는 쓰던 키보드를 지우고 이 키보드 하나로 친다. 단축어 판과 자판은 맨 위 띠의 키로 오간다.
//  배열은 `TypingLayouts`, 글자 넣기는 `TypingEngines`. 여기는 키를 그리고 손가락을 받는 일만 한다.
//
//  ⚠️ 키보드 확장은 제 영역 밖에 그릴 수 없다. 그래서 길게 눌러 나오는 글자, 한자 후보는
//     키 위로 띄우지 않고 **맨 위 띠**에 세운다(맨 윗줄 키 위로는 그릴 자리가 없다).
//  ⚠️ 키 크기는 판의 폭과 높이로 계산한다. 키보드 높이 설정 · 언어(3줄 · 4줄)가 달라도 넘치지 않는다.
//

import SwiftUI

// MARK: - 설정 값

/// 자판 설정. 앱(설정 화면)과 키보드가 App Group 으로 같이 본다.
enum TypingPrefs {
    /// 켜 둔 언어들(순서대로, 쉼표로 이은 rawValue).
    static let languagesKey = DefaultsKey.keyboardTypingLanguages
    /// 지금 치는 언어(rawValue).
    static let currentKey = DefaultsKey.keyboardTypingCurrent
    /// 한국어 자판 모양(dubeolsik · cheonjiin).
    static let koreanLayoutKey = DefaultsKey.keyboardKoreanLayout
    /// 키보드를 열면 어느 판이 먼저인가(typing · snippets).
    static let modeKey = DefaultsKey.keyboardInputMode

    /// 저장된 문자열을 언어 목록으로. 비어 있으면 기기 언어에서 고른다.
    ///
    /// ⚠️ 예전 설정에서 "한국어 입력" 을 켜 둔 사람(`keyboardKoreanEnabled`)은 기기 언어가 무엇이든
    ///    한국어를 넣는다. 켜 둔 것을 업데이트가 빼앗지 않게.
    static func languages(from raw: String, koreanWasEnabled: Bool = AppGroup.defaults?.bool(forKey: DefaultsKey.keyboardKoreanEnabled) ?? false) -> [TypingLanguage] {
        let parsed = raw.split(separator: ",").compactMap { TypingLanguage(rawValue: String($0)) }
        var unique: [TypingLanguage] = []
        for lang in parsed where !unique.contains(lang) { unique.append(lang) }
        guard unique.isEmpty else { return unique }
        var picked = TypingLanguage.defaults()
        if koreanWasEnabled && !picked.contains(.ko) { picked.insert(.ko, at: 0) }
        return picked
    }

    static func raw(from languages: [TypingLanguage]) -> String {
        languages.map(\.rawValue).joined(separator: ",")
    }
}

/// 키보드가 지금 보여 주는 판.
enum KeyboardInputMode: String {
    /// 글자를 치는 자판.
    case typing
    /// 단축어 키 판(예전부터 있던 것).
    case snippets
}

// MARK: - 자판 판

struct TypingKeyboardPanel: View {

    let proxy: TypingInputProxy
    let theme: AppTheme
    /// 호스트가 말한 리턴 키 이름. nil 이면 줄바꿈 화살표.
    let returnKeyName: String?
    /// 빈 칸에서 리턴을 잠그는가.
    let returnLocked: Bool
    /// 시스템 지구본(다음 키보드). iOS 가 요구하는 기기에서만 받는다.
    let globeKey: AnyView?
    /// 단축어 판으로.
    let onShowSnippets: () -> Void

    @AppStorage(TypingPrefs.languagesKey, store: AppGroup.defaults) private var languagesRaw: String = ""
    @AppStorage(TypingPrefs.currentKey, store: AppGroup.defaults) private var currentRaw: String = ""
    @AppStorage(TypingPrefs.koreanLayoutKey, store: AppGroup.defaults)
    private var koreanLayoutRaw: String = KoreanTypingLayout.dubeolsik.rawValue

    @StateObject private var session = TypingSession()
    @State private var layer: Layer = .letters
    @State private var shift: ShiftState = .off
    /// 길게 눌러 고르는 중인 키와 그 후보, 지금 손가락이 가리키는 칸.
    @State private var alternates: AlternatePick?
    /// 판 폭. 길게 누른 키가 왼쪽 반인지 오른쪽 반인지 가를 때 쓴다.
    @State private var panelWidth: CGFloat = 0

    enum Layer { case letters, numbers, symbols }
    enum ShiftState { case off, once, locked }

    private var languages: [TypingLanguage] { TypingPrefs.languages(from: languagesRaw) }

    private var language: TypingLanguage {
        if let current = TypingLanguage(rawValue: currentRaw), languages.contains(current) { return current }
        return languages.first ?? .en
    }

    private var koreanLayout: KoreanTypingLayout {
        KoreanTypingLayout(rawValue: koreanLayoutRaw) ?? .dubeolsik
    }

    private var usesCheonjiin: Bool { language == .ko && koreanLayout == .cheonjiin && layer == .letters }

    var body: some View {
        GeometryReader { geo in
            let metrics = Metrics(size: geo.size, rowCount: letterRows.count + 1)
            VStack(spacing: 0) {
                topStrip(metrics: metrics)
                    .frame(height: metrics.stripHeight)
                if usesCheonjiin {
                    cheonjiinGrid(metrics: metrics)
                } else {
                    keyRows(metrics: metrics)
                }
            }
            .padding(.horizontal, Metrics.sidePadding)
            .padding(.bottom, Metrics.bottomPadding)
            .onAppear { panelWidth = geo.size.width }
            .onChange(of: geo.size.width) { _, width in panelWidth = width }
        }
        .coordinateSpace(name: TypingLetterKeySpace.name)
        .onAppear { session.prepare(language: language, proxy: proxy, koreanLayout: koreanLayout) }
        .onChange(of: currentRaw) { _, _ in languageDidChange() }
        .onChange(of: languagesRaw) { _, _ in languageDidChange() }
        .onChange(of: koreanLayoutRaw) { _, _ in languageDidChange() }
    }

    // MARK: - 맨 위 띠

    /// 맨 위 띠: 길게 누르는 중이면 그 글자들, 후보가 있으면 후보, 아니면 단축어 판으로 가는 키.
    @ViewBuilder
    private func topStrip(metrics: Metrics) -> some View {
        if let pick = alternates {
            alternateStrip(pick, metrics: metrics)
        } else if !session.candidates.isEmpty {
            candidateStrip
        } else {
            HStack(spacing: 8) {
                Button {
                    KeyboardHaptics.softTap()
                    session.engine?.commit()
                    onShowSnippets()
                } label: {
                    Label(NSLocalizedString("단축어", comment: "Typing keyboard: switch to the snippet keys"),
                          systemImage: AppSymbol.squareGrid2x2)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.keycapLabel)
                        .padding(.horizontal, 12)
                        .frame(height: metrics.stripHeight - 8)
                        .background(theme.keycap)
                        .clipShape(Capsule())
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.squish)
                .accessibilityHint(NSLocalizedString("단축어 키 판으로 바꿉니다", comment: "Typing keyboard: snippets button hint"))
                Spacer(minLength: 0)
                if language.needsConversionDictionary && session.dictionaryMissing {
                    Text(NSLocalizedString("한자 사전은 앱의 키보드 설정에서 받아요", comment: "Typing keyboard: CJK dictionary not downloaded yet"))
                        .font(.system(size: 11))
                        .foregroundColor(theme.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }

    private var candidateStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(session.candidates.enumerated()), id: \.offset) { index, word in
                    Button {
                        KeyboardHaptics.tap()
                        session.engine?.selectCandidate(at: index)
                        session.refresh()
                    } label: {
                        Text(word)
                            .font(.system(size: 18))
                            .foregroundColor(theme.text)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollEdgeEffectHidden(true, for: .all)
    }

    private func alternateStrip(_ pick: AlternatePick, metrics: Metrics) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(pick.options.enumerated()), id: \.offset) { index, option in
                Text(option)
                    .font(.system(size: 20))
                    .foregroundColor(index == pick.highlighted ? theme.accentFg : theme.text)
                    .frame(width: metrics.keyWidth, height: metrics.stripHeight - 6)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radiusXs)
                            .fill(index == pick.highlighted ? theme.accent : theme.keycap)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: pick.alignLeading ? .leading : .trailing)
        .accessibilityHidden(true)
    }

    // MARK: - 키 줄

    private var letterRows: [[String]] {
        switch layer {
        case .letters:
            return language.layout.rows(shifted: shift != .off, locale: language.locale, hasCase: language.hasCase)
        case .numbers:
            return TypingLayoutBook.numberRows(currency: language.currencySymbol)
        case .symbols:
            return TypingLayoutBook.symbolRows
        }
    }

    /// 이 언어에 Shift 가 쓸모 있는가(대소문자 · 두벌식 쌍자음 · 태국어 윗줄).
    private var hasShiftKey: Bool {
        layer == .letters && (language.hasCase || language.layout.shiftedRows != nil)
    }

    private func keyRows(metrics: Metrics) -> some View {
        let rows = letterRows
        let lastIndex = rows.count - 1
        return VStack(spacing: Metrics.rowSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: Metrics.keySpacing) {
                    if index == lastIndex {
                        if layer == .letters {
                            if hasShiftKey { shiftKey(metrics: metrics) }
                        } else {
                            symbolsToggleKey(metrics: metrics)
                        }
                    }
                    ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                        letterKey(key, metrics: metrics, width: metrics.keyWidth(forRow: row.count, in: index == lastIndex))
                    }
                    if index == lastIndex {
                        backspaceKey(metrics: metrics)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            bottomRow(metrics: metrics)
        }
    }

    private func bottomRow(metrics: Metrics) -> some View {
        HStack(spacing: Metrics.keySpacing) {
            layerKey(metrics: metrics)
            if let globeKey { globeKey }
            if languages.count > 1 { languageKey(metrics: metrics) }
            spaceKey(metrics: metrics)
            returnKey(metrics: metrics)
        }
        .frame(height: metrics.keyHeight)
    }

    // MARK: - 키

    private func keyFace(_ label: some View, fill: Color, width: CGFloat?, metrics: Metrics) -> some View {
        label
            .frame(width: width, height: metrics.keyHeight)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
            .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
    }

    private func letterKey(_ key: String, metrics: Metrics, width: CGFloat) -> some View {
        TypingLetterKey(
            key: key,
            alternates: layer == .letters ? language.alternates(for: key) : [],
            keyWidth: width,
            panelWidth: panelWidth,
            onTap: { type(key) },
            onAlternatesBegan: { options, alignLeading in
                alternates = AlternatePick(options: options, highlighted: 0, alignLeading: alignLeading)
            },
            onAlternatesMoved: { index in alternates?.highlighted = index },
            onAlternatesEnded: { index in
                if let options = alternates?.options, options.indices.contains(index) { type(options[index]) }
                alternates = nil
            }
        ) {
            keyFace(Text(key).font(.system(size: metrics.letterFontSize)).foregroundColor(theme.keycapLabel),
                    fill: theme.keycap, width: width, metrics: metrics)
        }
        .accessibilityLabel(key)
    }

    private func controlFace(_ symbol: String, active: Bool = false, width: CGFloat, metrics: Metrics) -> some View {
        keyFace(Image(systemName: symbol)
                    .font(.system(size: metrics.controlFontSize, weight: .medium))
                    .foregroundColor(active ? theme.accentFg : theme.text),
                fill: active ? theme.accent : theme.divider, width: width, metrics: metrics)
    }

    private func shiftKey(metrics: Metrics) -> some View {
        Button {
            KeyboardHaptics.softTap()
            switch shift {
            case .off: shift = .once
            case .once: shift = .locked
            case .locked: shift = .off
            }
        } label: {
            controlFace(shift == .locked ? "capslock.fill" : (shift == .once ? "shift.fill" : "shift"),
                        active: shift != .off, width: metrics.wideKeyWidth, metrics: metrics)
        }
        .buttonStyle(.squish)
        .accessibilityLabel(NSLocalizedString("Shift", comment: "Typing keyboard: shift key"))
        .accessibilityAddTraits(shift != .off ? .isSelected : [])
    }

    private func backspaceKey(metrics: Metrics) -> some View {
        RepeatingKey {
            KeyboardHaptics.tap()
            session.engine?.backspace()
            session.refresh()
        } label: {
            controlFace(AppSymbol.deleteLeft, width: metrics.wideKeyWidth, metrics: metrics)
        }
        .accessibilityLabel(NSLocalizedString("지우기", comment: "Backspace key"))
    }

    private func symbolsToggleKey(metrics: Metrics) -> some View {
        Button {
            KeyboardHaptics.softTap()
            layer = layer == .numbers ? .symbols : .numbers
        } label: {
            keyFace(Text(layer == .numbers ? "#+=" : "123").font(.system(size: metrics.controlFontSize)).foregroundColor(theme.text),
                    fill: theme.divider, width: metrics.wideKeyWidth, metrics: metrics)
        }
        .buttonStyle(.squish)
    }

    private func layerKey(metrics: Metrics) -> some View {
        Button {
            KeyboardHaptics.softTap()
            session.engine?.commit()
            session.refresh()
            layer = layer == .letters ? .numbers : .letters
            shift = .off
        } label: {
            keyFace(Text(layer == .letters ? "123" : lettersLabel).font(.system(size: metrics.controlFontSize)).foregroundColor(theme.text),
                    fill: theme.divider, width: metrics.wideKeyWidth, metrics: metrics)
        }
        .buttonStyle(.squish)
        .accessibilityLabel(layer == .letters
                            ? NSLocalizedString("숫자", comment: "Typing keyboard: switch to numbers")
                            : NSLocalizedString("글자", comment: "Typing keyboard: switch to letters"))
    }

    /// 숫자 층에서 글자로 돌아가는 키의 이름(그 언어 글자로).
    private var lettersLabel: String {
        switch language {
        case .ko: return "가"
        case .ja: return "あ"
        case .zhHans, .zhHant: return "中"
        case .ru: return "АБВ"
        case .el: return "ΑΒΓ"
        case .th: return "กขค"
        default: return "ABC"
        }
    }

    /// 다음 언어로. 이름은 **갈 곳**을 적는다(누르면 그 언어가 된다).
    private func languageKey(metrics: Metrics) -> some View {
        let next = nextLanguage
        return Button {
            KeyboardHaptics.softTap()
            currentRaw = next.rawValue
        } label: {
            keyFace(Text(next.shortLabel).font(.system(size: metrics.controlFontSize, weight: .medium)).foregroundColor(theme.text),
                    fill: theme.divider, width: metrics.wideKeyWidth, metrics: metrics)
        }
        .buttonStyle(.squish)
        .accessibilityLabel(next.nativeName)
        .accessibilityHint(NSLocalizedString("입력 언어를 바꿉니다", comment: "Typing keyboard: language key hint"))
    }

    private var nextLanguage: TypingLanguage {
        guard let index = languages.firstIndex(of: language) else { return languages.first ?? .en }
        return languages[(index + 1) % languages.count]
    }

    private func spaceKey(metrics: Metrics) -> some View {
        Button {
            KeyboardHaptics.tap()
            if let engine = session.engine, engine.isComposing {
                engine.commit()
                // 가나 · 병음은 스페이스가 조합만 끝낸다(일본 · 중국 입력기와 같다).
                if !language.needsConversionDictionary { proxy.insertText(" ") }
            } else {
                proxy.insertText(" ")
            }
            session.refresh()
            if shift == .once { shift = .off }
        } label: {
            keyFace(Text(language.nativeName).font(.system(size: metrics.controlFontSize)).foregroundColor(theme.textMuted).lineLimit(1),
                    fill: theme.keycap, width: nil, metrics: metrics)
        }
        .buttonStyle(.squish)
        .accessibilityLabel(NSLocalizedString("스페이스", comment: "Spacebar (ko)"))
    }

    private func returnKey(metrics: Metrics) -> some View {
        Button {
            KeyboardHaptics.tap()
            session.engine?.commit()
            session.refresh()
            proxy.insertNewline()
        } label: {
            Group {
                if let returnKeyName {
                    keyFace(Text(returnKeyName).font(.system(size: metrics.controlFontSize, weight: .semibold))
                                .foregroundColor(theme.accentFg).lineLimit(1).minimumScaleFactor(0.7),
                            fill: theme.accent, width: metrics.returnKeyWidth, metrics: metrics)
                } else {
                    controlFace(AppSymbol.returnLeft, width: metrics.returnKeyWidth, metrics: metrics)
                }
            }
        }
        .buttonStyle(.squish)
        .opacity(returnLocked ? 0.4 : 1)
        .disabled(returnLocked)
        .accessibilityLabel(returnKeyName ?? NSLocalizedString("리턴 키", comment: "Return key accessibility label"))
    }

    // MARK: - 천지인

    /// 천지인 판. 12칸 격자(3열) 양옆에 조작 키를 세운다.
    private func cheonjiinGrid(metrics: Metrics) -> some View {
        let grid: [[String]] = [["ㅣ", "ㆍ", "ㅡ"], ["ㄱㅋ", "ㄴㄹ", "ㄷㅌ"], ["ㅂㅍ", "ㅅㅎ", "ㅈㅊ"], [".,?!", "ㅇㅁ", "?"]]
        return VStack(spacing: Metrics.rowSpacing) {
            ForEach(Array(grid.enumerated()), id: \.offset) { index, row in
                HStack(spacing: Metrics.keySpacing) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                        cheonjiinKey(key, metrics: metrics)
                    }
                    if index == 0 { backspaceKey(metrics: metrics) }
                }
            }
            bottomRow(metrics: metrics)
        }
    }

    @ViewBuilder
    private func cheonjiinKey(_ key: String, metrics: Metrics) -> some View {
        if key == ".,?!" {
            Button {
                KeyboardHaptics.tap()
                session.engine?.commit()
                proxy.insertText(".")
                session.refresh()
            } label: {
                keyFace(Text(".,?!").font(.system(size: metrics.controlFontSize)).foregroundColor(theme.keycapLabel),
                        fill: theme.keycap, width: nil, metrics: metrics)
            }
            .buttonStyle(.squish)
        } else if key == "?" {
            Button {
                KeyboardHaptics.tap()
                session.engine?.commit()
                proxy.insertText("?")
                session.refresh()
            } label: {
                keyFace(Text("?").font(.system(size: metrics.letterFontSize)).foregroundColor(theme.keycapLabel),
                        fill: theme.keycap, width: nil, metrics: metrics)
            }
            .buttonStyle(.squish)
        } else {
            Button {
                type(key)
            } label: {
                keyFace(Text(key).font(.system(size: metrics.letterFontSize * 0.85)).foregroundColor(theme.keycapLabel),
                        fill: theme.keycap, width: nil, metrics: metrics)
            }
            .buttonStyle(.squish)
            .accessibilityLabel(key)
        }
    }

    // MARK: - 넣기

    private func type(_ key: String) {
        KeyboardHaptics.tap()
        session.engine?.input(key)
        session.refresh()
        if shift == .once { shift = .off }
    }

    private func languageDidChange() {
        session.engine?.commit()
        layer = .letters
        shift = .off
        alternates = nil
        session.prepare(language: language, proxy: proxy, koreanLayout: koreanLayout)
    }
}

// MARK: - 엔진을 들고 있는 것

/// 엔진은 언어가 바뀔 때만 새로 만든다. 그리기마다 만들면 조합 중이던 글자가 끊긴다.
final class TypingSession: ObservableObject {
    private(set) var engine: TypingEngine?
    private var key: String = ""
    @Published private(set) var candidates: [String] = []
    @Published private(set) var dictionaryMissing = false

    func prepare(language: TypingLanguage, proxy: TypingInputProxy, koreanLayout: KoreanTypingLayout) {
        let next = "\(language.rawValue)|\(koreanLayout.rawValue)"
        guard next != key || engine == nil else { return }
        key = next
        let dictionary = ConversionDictionaryStore.dictionary(for: language)
        dictionaryMissing = language.needsConversionDictionary && dictionary == nil
        engine = TypingEngineFactory.make(for: language, proxy: proxy, koreanLayout: koreanLayout, dictionary: dictionary)
        refresh()
    }

    /// 후보가 바뀌었을 수 있다(키를 누른 뒤마다).
    func refresh() {
        let next = engine?.candidates ?? []
        if next != candidates { candidates = next }
    }
}

/// 받아 둔 변환 사전을 찾는 곳. 4단계에서 채운다(`docs/engineering/TYPING_KEYBOARD.md`).
enum ConversionDictionaryStore {
    static func dictionary(for language: TypingLanguage) -> ConversionDictionary? { nil }
}

// MARK: - 치수

private struct Metrics {
    static let sidePadding: CGFloat = 3
    static let bottomPadding: CGFloat = 4
    static let keySpacing: CGFloat = 6
    static let rowSpacing: CGFloat = 10

    let size: CGSize
    let rowCount: Int

    /// 맨 위 띠 높이.
    var stripHeight: CGFloat { 40 }

    /// 한 줄에 가장 많은 키 수에 맞춘 글자 키 폭. 12개(태국어 · 터키어)까지 들어간다.
    var keyWidth: CGFloat {
        let columns: CGFloat = 10
        let usable = size.width - Self.sidePadding * 2
        return (usable - Self.keySpacing * (columns - 1)) / columns
    }

    /// 줄 하나에 키가 몇 개냐에 따라 폭을 줄인다. 마지막 줄은 Shift · 지우기 자리를 뺀다.
    func keyWidth(forRow count: Int, in lastRow: Bool) -> CGFloat {
        let usable = size.width - Self.sidePadding * 2
        let reserved = lastRow ? (wideKeyWidth + Self.keySpacing) * 2 : 0
        let fit = (usable - reserved - Self.keySpacing * CGFloat(max(count - 1, 0))) / CGFloat(max(count, 1))
        return min(keyWidth, fit)
    }

    var wideKeyWidth: CGFloat { max(keyWidth * 1.35, 40) }
    var returnKeyWidth: CGFloat { max(keyWidth * 2.2, 72) }

    /// 남는 높이를 줄 수로 나눈다.
    var keyHeight: CGFloat {
        let usable = size.height - stripHeight - Self.bottomPadding - Self.rowSpacing * CGFloat(rowCount - 1)
        return max(30, min(usable / CGFloat(rowCount), 54))
    }

    var letterFontSize: CGFloat { min(keyHeight * 0.52, 24) }
    var controlFontSize: CGFloat { min(keyHeight * 0.36, 16) }
}

// MARK: - 길게 누르기

/// 자판 판의 좌표 공간 이름.
private enum TypingLetterKeySpace {
    static let name = "typingPanel"
}

struct AlternatePick: Equatable {
    var options: [String]
    var highlighted: Int
    /// 왼쪽 반의 키면 띠 왼쪽에, 오른쪽 반이면 오른쪽에 세운다(손가락 가까이).
    var alignLeading: Bool
}

/// 글자 키. 짧게 누르면 그 글자, 길게 누르면 맨 위 띠에 다른 글자를 띄우고 옆으로 밀어 고른다.
private struct TypingLetterKey<Label: View>: View {
    let key: String
    let alternates: [String]
    let keyWidth: CGFloat
    let panelWidth: CGFloat
    let onTap: () -> Void
    let onAlternatesBegan: (_ options: [String], _ alignLeading: Bool) -> Void
    let onAlternatesMoved: (Int) -> Void
    let onAlternatesEnded: (Int) -> Void
    @ViewBuilder let label: () -> Label

    @State private var pressStarted: Date?
    @State private var showingAlternates = false
    @State private var highlighted = 0
    @State private var longPressWork: DispatchWorkItem?

    private static var longPressDelay: TimeInterval { 0.4 }

    var body: some View {
        GeometryReader { geo in
            label()
                .scaleEffect(pressStarted != nil && !showingAlternates ? 0.94 : 1)
                .animation(.easeOut(duration: 0.08), value: pressStarted != nil)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            if pressStarted == nil { began(alignLeading: isLeadingHalf(geo)) }
                            if showingAlternates {
                                let step = keyWidth + 4
                                let raw = Int((value.translation.width / step).rounded())
                                let options = options(alignLeading: isLeadingHalf(geo))
                                let index = min(max(raw, 0), options.count - 1)
                                if index != highlighted {
                                    highlighted = index
                                    onAlternatesMoved(index)
                                }
                            }
                        }
                        .onEnded { _ in ended() }
                )
        }
        .frame(width: keyWidth)
    }

    private func isLeadingHalf(_ geo: GeometryProxy) -> Bool {
        geo.frame(in: .named(TypingLetterKeySpace.name)).midX < panelWidth / 2
    }

    private func options(alignLeading: Bool) -> [String] { [key] + alternates }

    private func began(alignLeading: Bool) {
        pressStarted = Date()
        highlighted = 0
        guard !alternates.isEmpty else { return }
        let work = DispatchWorkItem {
            showingAlternates = true
            KeyboardHaptics.softTap()
            onAlternatesBegan(options(alignLeading: alignLeading), alignLeading)
        }
        longPressWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.longPressDelay, execute: work)
    }

    private func ended() {
        longPressWork?.cancel()
        longPressWork = nil
        if showingAlternates {
            onAlternatesEnded(highlighted)
        } else if pressStarted != nil {
            onTap()
        }
        showingAlternates = false
        pressStarted = nil
    }
}
