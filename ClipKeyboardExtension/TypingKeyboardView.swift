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
//     누를 때 솟는 미리보기 풍선만은 키 위에 그린다. 맨 윗줄 풍선은 띠 높이 안에서 끝낸다.
//  ⚠️ 키 크기는 판의 폭과 높이로 계산한다. 키보드 높이 설정 · 언어(3줄 · 4줄)가 달라도 넘치지 않는다.
//

import SwiftUI
import UIKit

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

    /// 저장된 문자열을 언어 목록으로. 비어 있으면 그 사람의 언어 + 영어(`userLanguageCodes`).
    ///
    /// ⚠️ 예전 설정에서 "한국어 입력" 을 켜 둔 사람(`keyboardKoreanEnabled`)은 기기 언어가 무엇이든
    ///    한국어를 넣는다. 켜 둔 것을 업데이트가 빼앗지 않게.
    static func languages(from raw: String, koreanWasEnabled: Bool = AppGroup.defaults?.bool(forKey: DefaultsKey.keyboardKoreanEnabled) ?? false) -> [TypingLanguage] {
        let parsed = raw.split(separator: ",").compactMap { TypingLanguage(rawValue: String($0)) }
        var unique: [TypingLanguage] = []
        for lang in parsed where !unique.contains(lang) { unique.append(lang) }
        guard unique.isEmpty else { return unique }
        var picked = TypingLanguage.defaults(userLanguages: userLanguageCodes())
        if koreanWasEnabled && !picked.contains(.ko) { picked.insert(.ko, at: 0) }
        return picked
    }

    /// 그 사람의 언어 코드, 앞이 먼저다: 앱에서 고른 언어 → 기기 언어 → iOS 에 켜 둔 키보드의 언어.
    ///
    /// ⚠️ 켜 둔 키보드 목록(`AppleKeyboards`)은 앱만 읽을 수 있다. 앱이 `noteEnabledKeyboards()` 로
    ///    App Group 에 적어 둔 것을 본다. 앱을 아직 안 열었으면 그 몫은 빈다.
    static func userLanguageCodes(defaults: UserDefaults? = AppGroup.defaults,
                                  preferred: [String] = Locale.preferredLanguages) -> [String] {
        var codes: [String] = []
        if let app = defaults?.string(forKey: DefaultsKey.appLanguage),
           !app.isEmpty, app != AppLanguage.system.rawValue {
            codes.append(app)
        }
        codes += preferred
        codes += defaults?.stringArray(forKey: DefaultsKey.keyboardUserKeyboardLanguages) ?? []
        return codes
    }

    /// iOS 에 켜 둔 키보드의 언어를 App Group 에 적는다. 앱이 처음 뜰 때 부른다.
    /// 키보드는 이 목록을 스스로 못 읽는다(`AppleKeyboards` 는 앱의 표준 UserDefaults 에만 비친다).
    static func noteEnabledKeyboards(_ keyboards: [String]? = UserDefaults.standard.array(forKey: "AppleKeyboards") as? [String],
                                     defaults: UserDefaults? = AppGroup.defaults) {
        guard let keyboards else { return }
        let codes = TypingLanguage.languageCodes(fromAppleKeyboards: keyboards)
        guard defaults?.stringArray(forKey: DefaultsKey.keyboardUserKeyboardLanguages) != codes else { return }
        defaults?.set(codes, forKey: DefaultsKey.keyboardUserKeyboardLanguages)
    }

    /// 기존 사용자의 처음 목록을 한 번 저장해 둔다. 앱과 키보드가 각자 처음 뜰 때 부른다(한 번만 돈다).
    ///
    /// 왜: 처음 목록이 "기기 언어 + 영어" 에서 "앱 언어 · 기기 언어 · 켜 둔 키보드의 언어 + 영어" 로 바뀌었다.
    /// 목록은 설정에서 손대기 전까지 저장되지 않고 뜰 때마다 계산되므로, 그냥 바꾸면 이미 쓰던 사람의
    /// 언어 키가 업데이트한 날 말없이 다른 순서로 돈다. 그래서 **키보드를 이미 띄운 적이 있는 사람**은
    /// 예전 목록을 저장해 그대로 둔다.
    ///
    /// ⚠️ 키보드에서는 `keyboardExtensionDidLoad` 를 적기 **전에** 불러야 한다. 그 값이 "예전에 띄운 적 있음" 의 증거다.
    static func keepLegacyDefaultIfNeeded(defaults: UserDefaults? = AppGroup.defaults,
                                          preferred: [String] = Locale.preferredLanguages) {
        guard let defaults, !defaults.bool(forKey: DefaultsKey.keyboardTypingDefaultsSettled) else { return }
        defaults.set(true, forKey: DefaultsKey.keyboardTypingDefaultsSettled)
        let stored = defaults.string(forKey: languagesKey) ?? ""
        guard stored.isEmpty, defaults.bool(forKey: DefaultsKey.keyboardExtensionDidLoad) else { return }
        var legacy = TypingLanguage.deviceLanguages(preferred: preferred)
        if defaults.bool(forKey: DefaultsKey.keyboardKoreanEnabled) && !legacy.contains(.ko) { legacy.insert(.ko, at: 0) }
        defaults.set(raw(from: legacy), forKey: languagesKey)
        print("🔄 [TypingPrefs.keepLegacyDefaultIfNeeded] 기존 사용자의 입력 언어를 그대로 둔다: \(raw(from: legacy))")
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


/// 글자를 치는 자판.
///
/// ⚠️ **모양은 iOS 기본 키보드를 잰 값으로 그린다**(`NativeKeyMetrics` · `NativeKeyStyle`).
///    사용자는 하루 수천 번 기본 키보드를 친다. 키 간격 · 모서리 · 색 · 글자 크기가 조금만 달라도
///    "뭔가 어색한 키보드" 로 느끼고 쓰던 키보드로 돌아간다. 값을 바꾸려면 시뮬레이터에서
///    기본 키보드와 나란히 찍어 보고 바꾼다.
/// ⚠️ 키가 받는 자리는 **보이는 키보다 넓다.** 키 사이 틈까지 반씩 나눠 받는다(기본 키보드와 같다).
///    예전에는 보이는 키만 받아서 틈을 누르면 아무 일도 없었다.
struct TypingKeyboardPanel: View {

    let proxy: TypingInputProxy
    let theme: AppTheme
    /// 호스트가 말한 리턴 키 이름. 보이스오버가 읽는다.
    let returnKeyName: String?
    /// 호스트가 고른 리턴 키 종류. 기본 키보드처럼 그림으로 그린다.
    let returnKeyType: UIReturnKeyType
    /// 빈 칸에서 리턴을 잠그는가.
    let returnLocked: Bool
    /// 커서가 문장 첫머리인가(`KeyboardDocumentState.startsSentence`). 바뀌면 Shift 를 다시 정한다.
    let startsSentence: Bool
    /// 시스템 지구본(다음 키보드)을 받는 투명 단추. iOS 가 요구하는 기기에서만 받는다.
    /// 키 모양은 여기서 그리고, 손가락은 이 단추가 받는다(`handleInputModeList`).
    let globeOverlay: AnyView?
    /// 단축어 판으로.
    let onShowSnippets: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(TypingPrefs.languagesKey, store: AppGroup.defaults) private var languagesRaw: String = ""
    @AppStorage(TypingPrefs.currentKey, store: AppGroup.defaults) private var currentRaw: String = ""
    @AppStorage(TypingPrefs.koreanLayoutKey, store: AppGroup.defaults)
    private var koreanLayoutRaw: String = KoreanTypingLayout.dubeolsik.rawValue

    @StateObject private var session = TypingSession()
    @State private var layer: Layer = .letters
    @State private var shift: ShiftState = .off
    /// 바로 전에 Shift 를 누른 때. 두 번 빨리 누르면 대문자 고정(기본 키보드와 같다).
    @State private var lastShiftTap: Date?
    /// 길게 눌러 고르는 중인 키와 그 후보, 지금 손가락이 가리키는 칸.
    @State private var alternates: AlternatePick?
    /// 판 폭. 길게 누른 키가 왼쪽 반인지 오른쪽 반인지 가를 때 쓴다.
    @State private var panelWidth: CGFloat = 0
    /// 천지인 문장부호 키(.,?!)를 이어 누르는 중인가. 같은 키를 빨리 누르면 다음 부호로 바뀐다.
    @State private var punctuationCycle: (index: Int, at: Date)?

    enum Layer { case letters, numbers, symbols }
    enum ShiftState { case off, once, locked }

    private var style: NativeKeyStyle { NativeKeyStyle(isDark: colorScheme == .dark) }

    private var languages: [TypingLanguage] { TypingPrefs.languages(from: languagesRaw) }

    private var language: TypingLanguage {
        if let current = TypingLanguage(rawValue: currentRaw), languages.contains(current) { return current }
        return languages.first ?? .en
    }

    private var koreanLayout: KoreanTypingLayout {
        KoreanTypingLayout(rawValue: koreanLayoutRaw) ?? .dubeolsik
    }

    private var usesCheonjiin: Bool { language == .ko && koreanLayout == .cheonjiin && layer == .letters }

    /// 한 줄에 놓는 칸 수. 보통 10칸, 11 · 12칸 언어(독일어 · 태국어 …)는 그만큼 좁힌다.
    private var columns: Int {
        let rows = letterRows
        return max(10, rows.prefix(max(rows.count - 1, 1)).map(\.count).max() ?? 10)
    }

    var body: some View {
        GeometryReader { geo in
            let metrics = NativeKeyMetrics(size: geo.size,
                                           rowCount: usesCheonjiin ? 4 : letterRows.count + 1,
                                           columns: usesCheonjiin ? 5 : columns)
            VStack(spacing: 0) {
                topStrip(metrics: metrics)
                    .frame(height: metrics.stripHeight)
                    .padding(.horizontal, NativeKeyMetrics.sideInset + metrics.gapX / 2)
                if usesCheonjiin {
                    cheonjiinGrid(metrics: metrics)
                } else {
                    keyRows(metrics: metrics)
                }
            }
            .padding(.horizontal, NativeKeyMetrics.sideInset)
            .padding(.bottom, NativeKeyMetrics.bottomInset)
            .onAppear { panelWidth = geo.size.width }
            .onChange(of: geo.size.width) { _, width in panelWidth = width }
        }
        .coordinateSpace(name: TypingLetterKeySpace.name)
        .onAppear {
            session.prepare(language: language, proxy: proxy, koreanLayout: koreanLayout)
            updateAutoShift()
        }
        .onChange(of: currentRaw) { _, _ in languageDidChange() }
        .onChange(of: languagesRaw) { _, _ in languageDidChange() }
        .onChange(of: koreanLayoutRaw) { _, _ in languageDidChange() }
        .onChange(of: startsSentence) { _, _ in updateAutoShift() }
    }

    // MARK: - 맨 위 띠

    /// 맨 위 띠: 길게 누르는 중이면 그 글자들, 후보가 있으면 후보, 아니면 단축어 판으로 가는 키.
    /// 기본 키보드의 예측 막대 자리다. 맨 윗줄 키의 미리보기 풍선도 이 자리로 올라온다.
    @ViewBuilder
    private func topStrip(metrics: NativeKeyMetrics) -> some View {
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
                        .foregroundColor(style.label)
                        .padding(.horizontal, 12)
                        .frame(height: min(32, metrics.stripHeight - 10))
                        .background(style.fill(.letter, pressed: false))
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
                            .foregroundColor(style.label)
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

    private func alternateStrip(_ pick: AlternatePick, metrics: NativeKeyMetrics) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(pick.options.enumerated()), id: \.offset) { index, option in
                Text(option)
                    .font(.system(size: metrics.letterFontSize))
                    .foregroundColor(index == pick.highlighted ? .white : style.label)
                    .frame(width: metrics.keyWidth, height: min(metrics.keyHeight, metrics.stripHeight - 6))
                    .background(
                        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                            .fill(index == pick.highlighted ? style.accent : style.fill(.letter, pressed: false))
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

    private func keyRows(metrics: NativeKeyMetrics) -> some View {
        let rows = letterRows
        let lastIndex = rows.count - 1
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index == lastIndex {
                    lastLetterRow(row, rowIndex: index, metrics: metrics)
                } else {
                    centeredRow(row, rowIndex: index, metrics: metrics)
                }
            }
            bottomRow(metrics: metrics)
        }
    }

    /// 윗줄들. 칸이 모자라는 줄(QWERTY 둘째 줄)은 가운데로 모으고, 양 끝 키가 남는 자리까지 받는다.
    private func centeredRow(_ row: [String], rowIndex: Int, metrics: NativeKeyMetrics) -> some View {
        let pitch = metrics.pitch
        let side = max(0, (metrics.usableWidth - pitch * CGFloat(row.count)) / 2)
        return HStack(spacing: 0) {
            ForEach(Array(row.enumerated()), id: \.offset) { i, key in
                letterKey(key, metrics: metrics, rowIndex: rowIndex, width: pitch,
                          leadExtra: i == 0 ? side : 0,
                          trailExtra: i == row.count - 1 ? side : 0)
            }
        }
        .frame(width: metrics.usableWidth, height: metrics.rowPitch)
    }

    /// 마지막 글자 줄: 왼쪽 끝 Shift(또는 #+= · 123), 오른쪽 끝 지우기, 글자는 그 사이 가운데.
    private func lastLetterRow(_ row: [String], rowIndex: Int, metrics: NativeKeyMetrics) -> some View {
        let edge = metrics.edgeKeyWidth
        let between = metrics.usableWidth - edge * 2
        let preferred = row.count <= 5 ? metrics.pitch * 1.4 : metrics.pitch
        let pitch = min(preferred, between / CGFloat(max(row.count, 1)))
        let side = max(0, (between - pitch * CGFloat(row.count)) / 2)
        return HStack(spacing: 0) {
            Group {
                if layer == .letters {
                    if hasShiftKey {
                        shiftKey(metrics: metrics, width: edge)
                    } else {
                        Color.clear.frame(width: edge)
                    }
                } else {
                    symbolsToggleKey(metrics: metrics, width: edge)
                }
            }
            ForEach(Array(row.enumerated()), id: \.offset) { i, key in
                letterKey(key, metrics: metrics, rowIndex: rowIndex, width: pitch,
                          leadExtra: i == 0 ? side : 0,
                          trailExtra: i == row.count - 1 ? side : 0)
            }
            backspaceKey(metrics: metrics, width: edge)
        }
        .frame(width: metrics.usableWidth, height: metrics.rowPitch)
    }

    /// 맨 아랫줄: 123 · (지구본) · (언어) · 스페이스 · 리턴. 기본 키보드는 2.5 : 5 : 2.5 칸이다.
    private func bottomRow(metrics: NativeKeyMetrics) -> some View {
        let unit = metrics.usableWidth / 10
        let sideKeys = (globeOverlay != nil ? 1 : 0) + (languages.count > 1 ? 1 : 0)
        let layerWidth = sideKeys == 0 ? unit * 2.5 : unit * 1.25
        let returnWidth = unit * 2.5
        let spaceWidth = metrics.usableWidth - layerWidth - unit * 1.25 * CGFloat(sideKeys) - returnWidth
        return HStack(spacing: 0) {
            layerKey(metrics: metrics, width: layerWidth)
            if let globeOverlay { globeKey(globeOverlay, metrics: metrics, width: unit * 1.25, height: metrics.rowPitch) }
            if languages.count > 1 { languageKey(metrics: metrics, width: unit * 1.25, height: metrics.rowPitch) }
            spaceKey(metrics: metrics, width: spaceWidth, label: nil)
            returnKey(metrics: metrics, width: returnWidth, height: metrics.rowPitch)
        }
        .frame(width: metrics.usableWidth, height: metrics.rowPitch)
    }

    // MARK: - 키 모양

    /// 키 한 칸. `width` · `height` 는 손가락이 받는 자리, 보이는 키는 틈만큼 안으로 들인다.
    private func cell<Face: View>(width: CGFloat, height: CGFloat, metrics: NativeKeyMetrics,
                                  leadExtra: CGFloat = 0, trailExtra: CGFloat = 0,
                                  @ViewBuilder face: () -> Face) -> some View {
        face()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, metrics.gapX / 2)
            .padding(.vertical, metrics.gapY / 2)
            .padding(.leading, leadExtra)
            .padding(.trailing, trailExtra)
            .frame(width: width + leadExtra + trailExtra, height: height)
            .contentShape(Rectangle())
    }

    /// 보이는 키: 둥근 판 위에 글자나 그림.
    private func keyFace<Label: View>(_ label: Label, kind: NativeKeyStyle.Kind, pressed: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(style.fill(kind, pressed: pressed))
                .shadow(color: style.shadow, radius: 0, x: 0, y: 1)
            label
        }
    }

    private func textLabel(_ text: String, size: CGFloat, color: Color? = nil, tracking: CGFloat = 0) -> some View {
        Text(text)
            .font(.system(size: size))
            .tracking(tracking)
            .foregroundColor(color ?? style.label)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private func symbolLabel(_ name: String, size: CGFloat, color: Color? = nil) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .regular))
            .foregroundColor(color ?? style.label)
    }

    // MARK: - 키

    private func letterKey(_ key: String, metrics: NativeKeyMetrics, rowIndex: Int, width: CGFloat,
                           leadExtra: CGFloat = 0, trailExtra: CGFloat = 0) -> some View {
        TypingLetterKey(
            key: key,
            alternates: layer == .letters ? language.alternates(for: key) : [],
            cellWidth: width,
            leadExtra: leadExtra,
            trailExtra: trailExtra,
            metrics: metrics,
            style: style,
            // 맨 윗줄 풍선은 띠 안에서 끝나야 한다(키보드 확장은 제 영역 밖에 못 그린다).
            maxRise: rowIndex == 0 ? metrics.stripHeight + metrics.gapY / 2 - 2 : metrics.rowPitch * 1.4,
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
        )
        .accessibilityLabel(key)
    }

    private func shiftKey(metrics: NativeKeyMetrics, width: CGFloat) -> some View {
        // ⚠️ 기본 키보드처럼 **누르는 순간** 바뀐다. 한 번은 다음 글자만, 빨리 두 번은 고정.
        PressableKey(firesOnTouchDown: true, action: {
            KeyboardHaptics.softTap()
            let now = Date()
            let quickSecond = lastShiftTap.map { now.timeIntervalSince($0) < 0.35 } ?? false
            switch shift {
            case .off: shift = .once
            case .once: shift = quickSecond ? .locked : .off
            case .locked: shift = .off
            }
            lastShiftTap = now
        }) { pressed in
            cell(width: width, height: metrics.rowPitch, metrics: metrics) {
                keyFace(symbolLabel(shift == .locked ? "capslock.fill" : (shift == .once ? "shift.fill" : "shift"),
                                    size: metrics.symbolFontSize),
                        kind: .control, pressed: pressed)
            }
        }
        .accessibilityLabel(NSLocalizedString("Shift", comment: "Typing keyboard: shift key"))
        .accessibilityAddTraits(shift != .off ? .isSelected : [])
    }

    private func backspaceKey(metrics: NativeKeyMetrics, width: CGFloat, height: CGFloat? = nil) -> some View {
        PressableKey(firesOnTouchDown: true, repeats: true, action: {
            KeyboardHaptics.tap()
            session.engine?.backspace()
            session.refresh()
            updateAutoShift()
        }) { pressed in
            cell(width: width, height: height ?? metrics.rowPitch, metrics: metrics) {
                keyFace(symbolLabel(AppSymbol.deleteLeft, size: metrics.symbolFontSize), kind: .control, pressed: pressed)
            }
        }
        .accessibilityLabel(NSLocalizedString("지우기", comment: "Backspace key"))
    }

    private func symbolsToggleKey(metrics: NativeKeyMetrics, width: CGFloat) -> some View {
        PressableKey(action: {
            KeyboardHaptics.softTap()
            layer = layer == .numbers ? .symbols : .numbers
        }) { pressed in
            cell(width: width, height: metrics.rowPitch, metrics: metrics) {
                keyFace(textLabel(layer == .numbers ? "#+=" : "123", size: metrics.smallControlFontSize),
                        kind: .control, pressed: pressed)
            }
        }
        .accessibilityLabel(layer == .numbers
                            ? NSLocalizedString("기호", comment: "Typing keyboard: switch to symbols")
                            : NSLocalizedString("숫자", comment: "Typing keyboard: switch to numbers"))
    }

    private func layerKey(metrics: NativeKeyMetrics, width: CGFloat, height: CGFloat? = nil, label: String? = nil) -> some View {
        PressableKey(action: {
            KeyboardHaptics.softTap()
            session.engine?.commit()
            session.refresh()
            layer = layer == .letters ? .numbers : .letters
            shift = .off
            updateAutoShift()
        }) { pressed in
            cell(width: width, height: height ?? metrics.rowPitch, metrics: metrics) {
                keyFace(textLabel(label ?? (layer == .letters ? "123" : lettersLabel), size: metrics.controlFontSize),
                        kind: .control, pressed: pressed)
            }
        }
        .accessibilityLabel(layer == .letters
                            ? NSLocalizedString("숫자", comment: "Typing keyboard: switch to numbers")
                            : NSLocalizedString("글자", comment: "Typing keyboard: switch to letters"))
    }

    /// 숫자 층에서 글자로 돌아가는 키의 이름(그 언어 글자로). 기본 키보드와 같은 낱말이다.
    private var lettersLabel: String {
        switch language {
        case .ko: return "한글"
        case .ja: return "あいう"
        case .zhHans: return "拼音"
        case .zhHant: return "注音"
        case .ru: return "АБВ"
        case .el: return "ΑΒΓ"
        case .th: return "กขค"
        default: return "ABC"
        }
    }

    /// 다음 언어로. 이름은 **갈 곳**을 적는다(누르면 그 언어가 된다).
    private func languageKey(metrics: NativeKeyMetrics, width: CGFloat, height: CGFloat) -> some View {
        let next = nextLanguage
        return PressableKey(action: {
            KeyboardHaptics.softTap()
            currentRaw = next.rawValue
        }) { pressed in
            cell(width: width, height: height, metrics: metrics) {
                keyFace(textLabel(next == .en ? "ABC" : next.shortLabel, size: metrics.controlFontSize),
                        kind: .control, pressed: pressed)
            }
        }
        .accessibilityLabel(next.nativeName)
        .accessibilityHint(NSLocalizedString("입력 언어를 바꿉니다", comment: "Typing keyboard: language key hint"))
    }

    /// 지구본. 모양은 우리가 그리고 손가락은 위에 얹은 시스템 단추가 받는다.
    private func globeKey(_ overlay: AnyView, metrics: NativeKeyMetrics, width: CGFloat, height: CGFloat) -> some View {
        cell(width: width, height: height, metrics: metrics) {
            keyFace(symbolLabel(AppSymbol.globe, size: metrics.symbolFontSize), kind: .control, pressed: false)
        }
        .overlay(overlay)
    }

    private var nextLanguage: TypingLanguage {
        guard let index = languages.firstIndex(of: language) else { return languages.first ?? .en }
        return languages[(index + 1) % languages.count]
    }

    /// 스페이스. 기본 키보드(iOS 26)는 이름을 적지 않는다. 천지인 판만 "스페이스" 라고 적는다.
    private func spaceKey(metrics: NativeKeyMetrics, width: CGFloat, height: CGFloat? = nil, label: String?) -> some View {
        PressableKey(action: {
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
            updateAutoShift()
        }) { pressed in
            cell(width: width, height: height ?? metrics.rowPitch, metrics: metrics) {
                keyFace(textLabel(label ?? "", size: metrics.smallControlFontSize), kind: .letter, pressed: pressed)
            }
        }
        .accessibilityLabel(NSLocalizedString("스페이스", comment: "Spacebar (ko)"))
    }

    /// 리턴. 기본 키보드처럼 종류마다 그림으로 그린다(줄바꿈 · 다음 · 완료 · 이동 · 검색 · 보내기).
    private func returnKey(metrics: NativeKeyMetrics, width: CGFloat, height: CGFloat) -> some View {
        let glyph = NativeReturnGlyph(returnKeyType)
        return PressableKey(action: {
            KeyboardHaptics.tap()
            session.engine?.commit()
            session.refresh()
            proxy.insertNewline()
            updateAutoShift()
        }) { pressed in
            cell(width: width, height: height, metrics: metrics) {
                keyFace(symbolLabel(glyph.symbol, size: metrics.symbolFontSize,
                                    color: glyph.isAccent ? .white : nil),
                        kind: glyph.isAccent ? .accent : .control, pressed: pressed)
            }
        }
        .opacity(returnLocked ? 0.4 : 1)
        .disabled(returnLocked)
        .accessibilityLabel(returnKeyName ?? NSLocalizedString("리턴 키", comment: "Return key accessibility label"))
    }

    // MARK: - 천지인

    /// 천지인 판. iOS 한국어 10키와 같은 5칸 4줄이다.
    ///
    ///     #123 | ㅣ  | ㆍ  | ㅡ   | 지우기
    ///     ABC  | ㄱㅋ | ㄴㄹ | ㄷㅌ  | 리턴(두 줄)
    ///     지구본| ㅂㅍ | ㅅㅎ | ㅈㅊ  |
    ///     (두 줄)| →  | ㅇㅁ | .,?! | 스페이스
    ///
    /// ⚠️ 왼쪽 아래 긴 키는 기본 키보드에서 다음 키보드로 가는 자리다. 지구본이 필요 없는 기기에서는
    ///    그 자리에 단축어 판으로 가는 키를 세운다(우리 키보드의 '다음 판' 이다).
    private func cheonjiinGrid(metrics: NativeKeyMetrics) -> some View {
        let w = metrics.usableWidth / 5
        let h = metrics.rowPitch
        return HStack(spacing: 0) {
            VStack(spacing: 0) {
                layerKey(metrics: metrics, width: w, height: h, label: "#123")
                cheonjiinLanguageKey(metrics: metrics, width: w, height: h)
                cheonjiinTallKey(metrics: metrics, width: w, height: h * 2)
            }
            VStack(spacing: 0) {
                cheonjiinKey("ㅣ", metrics: metrics, width: w)
                cheonjiinKey("ㄱㅋ", metrics: metrics, width: w)
                cheonjiinKey("ㅂㅍ", metrics: metrics, width: w)
                cheonjiinAdvanceKey(metrics: metrics, width: w)
            }
            VStack(spacing: 0) {
                cheonjiinKey("ㆍ", metrics: metrics, width: w)
                cheonjiinKey("ㄴㄹ", metrics: metrics, width: w)
                cheonjiinKey("ㅅㅎ", metrics: metrics, width: w)
                cheonjiinKey("ㅇㅁ", metrics: metrics, width: w)
            }
            VStack(spacing: 0) {
                cheonjiinKey("ㅡ", metrics: metrics, width: w)
                cheonjiinKey("ㄷㅌ", metrics: metrics, width: w)
                cheonjiinKey("ㅈㅊ", metrics: metrics, width: w)
                cheonjiinPunctuationKey(metrics: metrics, width: w)
            }
            VStack(spacing: 0) {
                backspaceKey(metrics: metrics, width: w)
                returnKey(metrics: metrics, width: w, height: h * 2)
                spaceKey(metrics: metrics, width: w, label: NSLocalizedString("스페이스", comment: "Spacebar (ko)"))
            }
        }
        .frame(width: metrics.usableWidth, height: h * 4)
    }

    /// 천지인의 "ABC": 다음 언어로. 언어가 하나뿐이면 기호 층(#+=)으로 가는 키가 된다.
    @ViewBuilder
    private func cheonjiinLanguageKey(metrics: NativeKeyMetrics, width: CGFloat, height: CGFloat) -> some View {
        if languages.count > 1 {
            languageKey(metrics: metrics, width: width, height: height)
        } else {
            PressableKey(action: {
                KeyboardHaptics.softTap()
                session.engine?.commit()
                session.refresh()
                layer = .symbols
            }) { pressed in
                cell(width: width, height: height, metrics: metrics) {
                    keyFace(textLabel("#+=", size: metrics.controlFontSize), kind: .control, pressed: pressed)
                }
            }
            .accessibilityLabel(NSLocalizedString("기호", comment: "Typing keyboard: switch to symbols"))
        }
    }

    /// 왼쪽 아래 긴 키: 지구본이 필요한 기기면 지구본, 아니면 단축어 판으로.
    @ViewBuilder
    private func cheonjiinTallKey(metrics: NativeKeyMetrics, width: CGFloat, height: CGFloat) -> some View {
        if let globeOverlay {
            globeKey(globeOverlay, metrics: metrics, width: width, height: height)
        } else {
            snippetsKey(metrics: metrics, width: width, height: height)
        }
    }

    private func snippetsKey(metrics: NativeKeyMetrics, width: CGFloat, height: CGFloat) -> some View {
        PressableKey(action: {
            KeyboardHaptics.softTap()
            session.engine?.commit()
            onShowSnippets()
        }) { pressed in
            cell(width: width, height: height, metrics: metrics) {
                keyFace(symbolLabel(AppSymbol.squareGrid2x2, size: metrics.symbolFontSize), kind: .control, pressed: pressed)
            }
        }
        .accessibilityLabel(NSLocalizedString("단축어", comment: "Typing keyboard: switch to the snippet keys"))
        .accessibilityHint(NSLocalizedString("단축어 키 판으로 바꿉니다", comment: "Typing keyboard: snippets button hint"))
    }

    /// 자모 키. 기본 10키처럼 두 자모 사이를 띄워 적고, 누르면 풍선 대신 키 색이 바뀐다.
    private func cheonjiinKey(_ key: String, metrics: NativeKeyMetrics, width: CGFloat) -> some View {
        PressableKey(action: { type(key) }) { pressed in
            cell(width: width, height: metrics.rowPitch, metrics: metrics) {
                // ⚠️ 글꼴의 ㅡ 는 글자 칸 아래쪽에 앉아 키 가운데보다 4pt 쯤 낮게 보인다.
                //    기본 10키는 획을 키 한가운데에 둔다.
                keyFace(textLabel(key.map(String.init).joined(separator: " "), size: metrics.letterFontSize)
                            .offset(y: key == "ㅡ" ? -metrics.keyHeight * 0.1 : 0),
                        kind: .letter, pressed: pressed)
            }
        }
        .accessibilityLabel(key)
    }

    /// → 키: 같은 자음 키를 이어서 칠 때 앞 글자를 끊는다(ㄱ → ㄱ 이 ㅋ 이 되지 않게).
    /// 조합 중이 아니면 커서를 한 칸 옮긴다(기본 10키와 같다).
    private func cheonjiinAdvanceKey(metrics: NativeKeyMetrics, width: CGFloat) -> some View {
        PressableKey(action: {
            KeyboardHaptics.tap()
            session.engine?.input(CheonjiinInput.advanceKey)
            session.refresh()
        }) { pressed in
            cell(width: width, height: metrics.rowPitch, metrics: metrics) {
                keyFace(symbolLabel("arrow.right", size: metrics.symbolFontSize), kind: .letter, pressed: pressed)
            }
        }
        .accessibilityLabel(NSLocalizedString("다음 글자", comment: "Cheonjiin keyboard: finish the current consonant so the same key starts a new one"))
    }

    /// .,?! 키: 빨리 이어 누르면 . → , → ? → ! 로 바뀐다(기본 10키와 같다).
    private func cheonjiinPunctuationKey(metrics: NativeKeyMetrics, width: CGFloat) -> some View {
        PressableKey(action: {
            KeyboardHaptics.tap()
            let marks = [".", ",", "?", "!"]
            let now = Date()
            if let cycle = punctuationCycle, now.timeIntervalSince(cycle.at) < 0.8 {
                let next = (cycle.index + 1) % marks.count
                proxy.deleteBackward()
                proxy.insertText(marks[next])
                punctuationCycle = (next, now)
            } else {
                session.engine?.commit()
                proxy.insertText(marks[0])
                punctuationCycle = (0, now)
            }
            session.refresh()
        }) { pressed in
            cell(width: width, height: metrics.rowPitch, metrics: metrics) {
                keyFace(textLabel(".,?!", size: metrics.smallControlFontSize, tracking: 2), kind: .letter, pressed: pressed)
            }
        }
        .accessibilityLabel(NSLocalizedString("문장 부호", comment: "Cheonjiin keyboard: punctuation key"))
    }

    // MARK: - 넣기

    private func type(_ key: String) {
        KeyboardHaptics.tap()
        punctuationCycle = nil
        session.engine?.input(key)
        session.refresh()
        if shift == .once { shift = .off }
        updateAutoShift()
    }

    /// 기본 키보드처럼 문장 첫 글자(빈 칸 · 마침표 뒤 · 줄 바뀐 뒤)에서 Shift 를 저절로 켠다.
    ///
    /// ⚠️ 대소문자가 있는 언어의 글자 층에서만. 고정(caps lock)은 건드리지 않는다.
    ///    입력칸이 대문자를 원하지 않으면(이메일 · 주소 칸) 켜지 않는다.
    private func updateAutoShift() {
        guard layer == .letters, language.hasCase, shift != .locked else { return }
        let wants = Self.wantsCapital(before: proxy.typingContextBefore,
                                      rule: proxy.typingAutocapitalization)
        shift = wants ? .once : .off
    }

    /// - Parameter before: 커서 앞 글. 빈 입력칸에서 iOS 는 nil 을 주므로 nil 은 빈 글로 본다.
    static func wantsCapital(before: String?, rule: UITextAutocapitalizationType) -> Bool {
        let before = before ?? ""
        switch rule {
        case .none: return false
        case .allCharacters: return true
        case .words:
            guard let last = before.last else { return true }
            return last.isWhitespace
        case .sentences:
            if before.isEmpty || before.last == "\n" { return true }
            guard before.last?.isWhitespace == true else { return false }
            let trimmed = before.trimmingCharacters(in: .whitespaces)
            guard let end = trimmed.last else { return true }
            return ".!?\n".contains(end)
        @unknown default: return false
        }
    }

    private func languageDidChange() {
        session.engine?.commit()
        layer = .letters
        shift = .off
        alternates = nil
        punctuationCycle = nil
        session.prepare(language: language, proxy: proxy, koreanLayout: koreanLayout)
        updateAutoShift()
    }
}

// MARK: - 리턴 키 그림

/// 리턴 키 종류 → 기본 키보드(iOS 26)가 그리는 그림.
/// 줄바꿈 · 다음은 다른 조작 키와 같은 색, 끝내는 동작(이동 · 검색 · 보내기 · 완료)은 파란 키다.
struct NativeReturnGlyph {
    let symbol: String
    let isAccent: Bool

    init(_ type: UIReturnKeyType) {
        switch type {
        case .next, .continue: symbol = "chevron.right"; isAccent = false
        case .done: symbol = "checkmark"; isAccent = true
        case .go, .join, .route: symbol = "arrow.right"; isAccent = true
        case .search, .google, .yahoo: symbol = "magnifyingglass"; isAccent = true
        case .send: symbol = "arrow.up"; isAccent = true
        default: symbol = AppSymbol.returnLeft; isAccent = false
        }
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

/// 기본 키보드를 잰 치수(iPhone 17 Pro · iOS 27 시뮬레이터, 2026-10).
///
///     폭 402pt: 바깥 여백 3.67 + 10칸(칸 39.5) , 보이는 키 33.3 · 틈 6
///     줄 간격 54pt: 보이는 키 42.3 · 틈 11.7, 모서리 8.5(연속 곡선)
///     맨 아랫줄 123 : 스페이스 : 리턴 = 2.5 : 5 : 2.5 칸, 셋째 줄 Shift · 지우기 = 1.31 칸
///
/// ⚠️ 판 높이는 단축어 판과 같이 쓴다(`KeyboardHeightBook`). 그래서 줄 간격을 그대로 박지 않고
///    남는 높이로 나누되, 키가 기본 키보드보다 지나치게 커지지 않게 줄 간격에 상한을 두고
///    나머지는 맨 위 띠(예측 막대 자리)에 준다.
struct NativeKeyMetrics {
    static let sideInset: CGFloat = 3.67
    static let bottomInset: CGFloat = 0
    /// 줄 간격의 상한. 기본 10키 판의 키(46pt)보다 커지지 않게.
    static let maxRowPitch: CGFloat = 58
    /// 맨 위 띠의 최소 높이. 단축어 키(32pt)가 들어가고, 남는 높이는 키 줄이 먼저 가져간다.
    /// (우리 판은 기본 키보드보다 15pt 쯤 낮게 잡힌다. 띠를 줄여야 키가 기본 키보드 크기에 가까워진다)
    static let minStripHeight: CGFloat = 38

    let size: CGSize
    let rowCount: Int
    let columns: Int

    var usableWidth: CGFloat { max(0, size.width - Self.sideInset * 2) }

    /// 한 칸(손가락이 받는 폭).
    var pitch: CGFloat { usableWidth / CGFloat(max(columns, 1)) }

    /// 키 사이 가로 틈. 칸이 좁은 언어(12칸)는 틈도 줄인다.
    var gapX: CGFloat { min(6, pitch * 0.152) }

    /// 보이는 글자 키 폭.
    var keyWidth: CGFloat { pitch - gapX }

    /// Shift · 지우기 · #+= 칸 폭.
    var edgeKeyWidth: CGFloat { (usableWidth / 10) * 1.31 }

    /// 줄 하나의 높이(손가락이 받는 높이).
    var rowPitch: CGFloat {
        let usable = size.height - Self.minStripHeight - Self.bottomInset
        return max(34, min(usable / CGFloat(max(rowCount, 1)), Self.maxRowPitch))
    }

    /// 남는 높이는 맨 위 띠로.
    var stripHeight: CGFloat {
        max(Self.minStripHeight, size.height - Self.bottomInset - rowPitch * CGFloat(rowCount))
    }

    /// 줄 사이 세로 틈.
    var gapY: CGFloat { min(11.67, rowPitch * 0.216) }

    var keyHeight: CGFloat { rowPitch - gapY }

    /// 키 글자 크기를 줄이기 시작하는 키 높이. 이보다 높으면 기본 키보드와 같은 크기로 그린다.
    ///
    /// ⚠️ 예전에는 크기를 "키 높이 × 비율" 로 정하고 비율을 기본 키보드의 키(42.3pt)에 맞췄다.
    ///    우리 키는 판이 낮아 40.5pt 쯤이라 글자가 21pt 로 그려졌고, 기본 키보드(22pt)보다
    ///    획이 가늘고 연해 보였다(사용자: "볼드같이 진하게 그려진 것도 똑같아?").
    ///    시뮬레이터에서 같은 글자를 굵기 · 크기별로 그려 기본 키보드 스크린샷과 맞춰 보니
    ///    굵기는 같은 regular 이고 크기만 1pt 작았다. 키가 이보다 낮을 때(가로 화면)만 줄인다.
    static let fullSizeKeyHeight: CGFloat = 38

    private var fontScale: CGFloat { min(1, keyHeight / Self.fullSizeKeyHeight) }

    /// 글자 키(라틴 대문자 높이 15.3pt = 22pt, regular).
    var letterFontSize: CGFloat { 22 * fontScale }
    /// 123 · ABC 같은 글자 조작 키.
    var controlFontSize: CGFloat { 18 * fontScale }
    /// #+= · 스페이스 같은 작은 이름.
    var smallControlFontSize: CGFloat { 16 * fontScale }
    /// Shift · 지우기 · 리턴 그림.
    var symbolFontSize: CGFloat { 20 * fontScale }
}

/// 기본 키보드의 키 색. iOS 26 부터는 조작 키도 글자 키와 같은 색이고 그림자가 없다.
/// 그 전 iOS 는 조작 키가 어둡고 아래에 1pt 그림자가 있었다(그 기기에서는 그쪽이 '기본' 이다).
struct NativeKeyStyle {
    enum Kind { case letter, control, accent }

    let isDark: Bool

    private var isModern: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    var cornerRadius: CGFloat { isModern ? 8.5 : 5 }

    var label: Color { isDark ? .white : .black }

    var accent: Color { Color(uiColor: .systemBlue) }

    var shadow: Color {
        isModern ? .clear : .black.opacity(isDark ? 0.5 : 0.3)
    }

    func fill(_ kind: Kind, pressed: Bool) -> Color {
        if kind == .accent {
            return pressed ? accent.opacity(0.7) : accent
        }
        if isModern {
            // 잰 값: 라이트 흰색 · 다크 (70, 70, 70). 눌린 글자 키는 라이트 (229, 229, 229).
            if isDark { return Color(white: pressed ? 0.43 : 0.275) }
            return pressed ? Color(white: 0.898) : .white
        }
        switch (kind, isDark) {
        case (.letter, false): return pressed ? Color(red: 0.67, green: 0.69, blue: 0.73) : .white
        case (.letter, true): return Color(white: pressed ? 0.27 : 0.42)
        default:
            if isDark { return Color(white: pressed ? 0.42 : 0.27) }
            return pressed ? .white : Color(red: 0.67, green: 0.69, blue: 0.73)
        }
    }
}

// MARK: - 누르는 키

/// 조작 키 · 천지인 키. 누르고 있는 동안 키 색이 바뀐다(기본 키보드는 줄어들지 않는다).
///
/// ⚠️ 손가락은 `DragGesture` 로 받으므로 보이스오버에는 따로 동작을 단다.
private struct PressableKey<Face: View>: View {
    /// 누르는 순간 일한다(Shift · 지우기). 아니면 뗄 때(기본 키보드의 나머지 키).
    var firesOnTouchDown = false
    /// 누르고 있으면 되풀이한다(지우기).
    var repeats = false
    let action: () -> Void
    @ViewBuilder let face: (_ pressed: Bool) -> Face

    @State private var pressed = false
    @State private var repeater = KeyRepeater()

    var body: some View {
        face(pressed)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !pressed else { return }
                        pressed = true
                        if firesOnTouchDown { action() }
                        if repeats { repeater.start(action) }
                    }
                    .onEnded { _ in
                        pressed = false
                        repeater.stop()
                        if !firesOnTouchDown { action() }
                    }
            )
            .onDisappear { repeater.stop() }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }
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

/// 글자 키. 누르면 키 위로 미리보기 풍선이 뜨고(기본 키보드와 같다) 뗄 때 글자가 들어간다.
/// 길게 누르면 맨 위 띠에 다른 글자를 띄우고 옆으로 밀어 고른다.
private struct TypingLetterKey: View {
    let key: String
    let alternates: [String]
    /// 손가락이 받는 폭. 양 끝 키는 `leadExtra` · `trailExtra` 만큼 더 받는다.
    let cellWidth: CGFloat
    let leadExtra: CGFloat
    let trailExtra: CGFloat
    let metrics: NativeKeyMetrics
    let style: NativeKeyStyle
    /// 풍선이 키 위로 솟을 수 있는 높이. 맨 윗줄은 띠 안에서 끝나야 한다.
    let maxRise: CGFloat
    let panelWidth: CGFloat
    let onTap: () -> Void
    let onAlternatesBegan: (_ options: [String], _ alignLeading: Bool) -> Void
    let onAlternatesMoved: (Int) -> Void
    let onAlternatesEnded: (Int) -> Void

    @State private var pressStarted: Date?
    @State private var showingAlternates = false
    @State private var highlighted = 0
    @State private var longPressWork: DispatchWorkItem?
    /// 이 키의 보이는 판이 판 전체에서 어디에 있는가. 풍선이 가장자리 밖으로 나가지 않게 쓴다.
    @State private var keyFrame: CGRect = .zero

    private static var longPressDelay: TimeInterval { 0.4 }

    private var showsPopup: Bool { pressStarted != nil && !showingAlternates }

    var body: some View {
        let visualWidth = cellWidth - metrics.gapX
        ZStack {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(style.fill(.letter, pressed: pressStarted != nil))
                .shadow(color: style.shadow, radius: 0, x: 0, y: 1)
            Text(key)
                .font(.system(size: metrics.letterFontSize))
                .foregroundColor(style.label)
        }
        .frame(width: visualWidth, height: metrics.keyHeight)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { keyFrame = geo.frame(in: .named(TypingLetterKeySpace.name)) }
                    .onChange(of: geo.frame(in: .named(TypingLetterKeySpace.name))) { _, frame in keyFrame = frame }
            }
        )
        .overlay(alignment: .bottom) {
            if showsPopup { popup(visualWidth: visualWidth) }
        }
        .padding(.leading, metrics.gapX / 2 + leadExtra)
        .padding(.trailing, metrics.gapX / 2 + trailExtra)
        .frame(width: cellWidth + leadExtra + trailExtra, height: metrics.rowPitch)
        .contentShape(Rectangle())
        .zIndex(showsPopup ? 1 : 0)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    if pressStarted == nil { began(alignLeading: isLeadingHalf) }
                    if showingAlternates {
                        let step = metrics.keyWidth + 4
                        let raw = Int((value.translation.width / step).rounded())
                        let options = options
                        let index = min(max(raw, 0), options.count - 1)
                        if index != highlighted {
                            highlighted = index
                            onAlternatesMoved(index)
                        }
                    }
                }
                .onEnded { _ in ended() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isKeyboardKey)
        .accessibilityAction { onTap() }
    }

    /// 미리보기 풍선. iOS 26 기본 키보드처럼 키에서 떨어진 둥근 판이 키 위에 뜨고, 키는 눌린 색이 된다.
    ///
    /// 잰 값: 풍선 폭 = 키 폭 x 1.72, 높이 = 키 높이 x 1.53, 키 윗변과 3pt 띄움, 글자 약 38pt.
    /// ⚠️ 맨 윗줄은 위로 띠 높이만큼만 솟을 수 있어 그만큼 낮게 그린다(확장은 제 영역 밖에 못 그린다).
    private func popup(visualWidth: CGFloat) -> some View {
        let lift: CGFloat = 3
        let width = visualWidth * 1.72
        let height = max(metrics.keyHeight, min(metrics.keyHeight * 1.53, maxRise - lift))
        // 가장자리 키는 풍선을 안쪽으로 민다.
        var dx: CGFloat = 0
        if panelWidth > 0 {
            let half = width / 2
            let leftOver = (keyFrame.midX - half) - 1
            let rightOver = panelWidth - 1 - (keyFrame.midX + half)
            if leftOver < 0 { dx = -leftOver } else if rightOver < 0 { dx = rightOver }
        }
        return Text(key)
            .font(.system(size: min(metrics.letterFontSize * 1.75, height * 0.62)))
            .foregroundColor(style.label)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius * 1.4, style: .continuous)
                    .fill(style.fill(.letter, pressed: false))
                    .shadow(color: .black.opacity(style.isDark ? 0.45 : 0.18), radius: 3, x: 0, y: 1)
            )
            .offset(x: dx, y: -(metrics.keyHeight + lift))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var isLeadingHalf: Bool { keyFrame.midX < panelWidth / 2 }

    private var options: [String] { [key] + alternates }

    private func began(alignLeading: Bool) {
        pressStarted = Date()
        highlighted = 0
        guard !alternates.isEmpty else { return }
        let work = DispatchWorkItem {
            showingAlternates = true
            KeyboardHaptics.softTap()
            onAlternatesBegan(options, alignLeading)
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
