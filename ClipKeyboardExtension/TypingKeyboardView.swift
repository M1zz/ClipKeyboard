//
//  TypingKeyboardView.swift
//  ClipKeyboardExtension
//
//  자체 QWERTY/한글 타이핑 키보드. 사용자가 메모 외 텍스트를 직접 입력할 때
//  지구본 버튼으로 시스템 키보드 전환 없이 같은 익스텐션에서 입력 가능.
//

import SwiftUI

/// 타이핑 키보드 → host 입력 인터페이스. KeyboardViewController가 구현.
protocol TypingInputProxy: AnyObject {
    func insertText(_ text: String)
    func deleteBackward()
    func insertNewline()
    func advanceToNextInputMode()
    func cursorRight()
    func clearAll()
}

struct TypingKeyboardView: View {

    enum InputLang: String { case english, korean }
    enum InputLayer { case letters, numbers, symbols }
    enum KoreanLayout: String { case dubeolsik, cheonjiin }

    let proxy: TypingInputProxy
    @Binding var lang: InputLang

    @State private var layer: InputLayer = .letters
    @State private var isShiftOn: Bool = false
    @State private var isCapsLock: Bool = false
    @State private var hangulComposer = HangulComposer()
    @State private var cheonjiinInput = CheonjiinInput()
    @State private var deleteHoldActive = false
    @State private var deleteTimer: Timer? = nil

    /// 한글 레이아웃 — 사용자가 KeyboardLayoutSettings에서 선택. 기본 두벌식.
    @AppStorage("keyboardKoreanLayout", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo"))
    private var koreanLayoutRaw: String = KoreanLayout.dubeolsik.rawValue

    private var koreanLayout: KoreanLayout {
        KoreanLayout(rawValue: koreanLayoutRaw) ?? .dubeolsik
    }

    @Environment(\.colorScheme) var colorScheme

    private var theme: AppTheme {
        AppTheme.resolve(kind: .paper, isDark: colorScheme == .dark)
    }

    // MARK: - Body — Apple iOS 기본 키보드 스펙에 맞춤

    private let keyHeight: CGFloat = 42
    private let keySpacing: CGFloat = 6
    private let rowSpacing: CGFloat = 11
    private let keyFontSize: CGFloat = 22

    var body: some View {
        if lang == .korean && koreanLayout == .cheonjiin && layer == .letters {
            cheonjiinBody
        } else {
            standardBody
        }
    }

    private var standardBody: some View {
        VStack(spacing: rowSpacing) {
            ForEach(Array(currentRows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: keySpacing) {
                    if rowIndex == 2 && layer == .letters {
                        shiftKey
                    }
                    ForEach(Array(row.enumerated()), id: \.offset) { _, char in
                        letterKey(char)
                    }
                    if rowIndex == 2 && layer == .letters {
                        backspaceKey
                    }
                }
                .padding(.horizontal, rowIndex == 1 && layer == .letters ? 18 : 0)  // Apple: 둘째 행 살짝 안쪽
            }
            // 마지막 행 — 123 + 한/EN + 🌐 + space + return
            HStack(spacing: keySpacing) {
                layerToggleKey
                langToggleKey
                globeKey
                spaceKey
                returnKey
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(theme.surfaceAlt)
    }

    // MARK: - Layout data

    private var currentRows: [[String]] {
        switch (lang, layer) {
        case (.english, .letters):
            let r1 = ["q","w","e","r","t","y","u","i","o","p"]
            let r2 = ["a","s","d","f","g","h","j","k","l"]
            let r3 = ["z","x","c","v","b","n","m"]
            return shouldUppercase ? [r1, r2, r3].map { $0.map { $0.uppercased() } } : [r1, r2, r3]

        case (.korean, .letters):
            switch koreanLayout {
            case .dubeolsik:
                let r1 = ["ㅂ","ㅈ","ㄷ","ㄱ","ㅅ","ㅛ","ㅕ","ㅑ","ㅐ","ㅔ"]
                let r2 = ["ㅁ","ㄴ","ㅇ","ㄹ","ㅎ","ㅗ","ㅓ","ㅏ","ㅣ"]
                let r3 = ["ㅋ","ㅌ","ㅊ","ㅍ","ㅠ","ㅜ","ㅡ"]
                if shouldUppercase {
                    let shifted: [String: String] = [
                        "ㅂ":"ㅃ", "ㅈ":"ㅉ", "ㄷ":"ㄸ", "ㄱ":"ㄲ", "ㅅ":"ㅆ",
                        "ㅐ":"ㅒ", "ㅔ":"ㅖ"
                    ]
                    return [r1, r2, r3].map { row in row.map { shifted[$0] ?? $0 } }
                }
                return [r1, r2, r3]

            case .cheonjiin:
                // 천지인 3x3 (+ 모음 ㅣ ㅡ ㆍ + 자음 키 그룹)
                // 단순 자모 표시 — multi-tap 사이클은 다음 iteration
                return [
                    ["ㅣ","ㆍ","ㅡ"],
                    ["ㄱㅋ","ㄴㄹ","ㄷㅌ"],
                    ["ㅂㅍ","ㅅㅎ","ㅈㅊ","ㅇㅁ"]
                ]
            }

        case (_, .numbers):
            return [
                ["1","2","3","4","5","6","7","8","9","0"],
                ["-","/",":",";","(",")","$","&","@","\""],
                [".",",","?","!","'"]
            ]
        case (_, .symbols):
            return [
                ["[","]","{","}","#","%","^","*","+","="],
                ["_","\\","|","~","<",">","€","£","¥","•"],
                [".",",","?","!","'"]
            ]
        }
    }

    private var shouldUppercase: Bool { isShiftOn || isCapsLock }

    // MARK: - Keys

    // MARK: - Keys (Apple 스펙 — 흰색 raised key with shadow)

    private func keyBackground<Content: View>(width: CGFloat? = nil, fill: Color, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: width ?? .infinity, minHeight: keyHeight)
            .background(fill)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.18), radius: 0, x: 0, y: 1)
    }

    private func letterKey(_ char: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            sendCharacter(char)
            if isShiftOn && !isCapsLock { isShiftOn = false }
        } label: {
            keyBackground(fill: theme.surface) {
                Text(char)
                    .font(.system(size: keyFontSize, weight: .regular))
                    .foregroundColor(theme.text)
            }
        }
    }

    private var shiftKey: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            if isCapsLock {
                isCapsLock = false
                isShiftOn = false
            } else if isShiftOn {
                isCapsLock = true
            } else {
                isShiftOn = true
            }
        } label: {
            keyBackground(width: 42, fill: isShiftOn || isCapsLock ? Color.blue : theme.divider) {
                Image(systemName: isCapsLock ? "capslock.fill" : (isShiftOn ? "shift.fill" : "shift"))
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(isShiftOn || isCapsLock ? .white : theme.text)
            }
        }
    }

    private var backspaceKey: some View {
        keyBackground(width: 42, fill: theme.divider) {
            Image(systemName: "delete.left")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(theme.text)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in startDeleteHold() }
                .onEnded { _ in stopDeleteHold() }
        )
    }

    private func startDeleteHold() {
        guard !deleteHoldActive else { return }
        deleteHoldActive = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        performDelete()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard self.deleteHoldActive else { return }
            self.deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                DispatchQueue.main.async {
                    if self.deleteHoldActive {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        self.performDelete()
                    } else {
                        self.deleteTimer?.invalidate()
                        self.deleteTimer = nil
                    }
                }
            }
        }
    }

    private func stopDeleteHold() {
        deleteHoldActive = false
        deleteTimer?.invalidate()
        deleteTimer = nil
    }

    private func performDelete() {
        if lang == .korean && layer == .letters {
            if koreanLayout == .cheonjiin {
                if hangulComposer.proxy == nil {
                    hangulComposer.proxy = HangulProxyAdapter(typing: proxy)
                    cheonjiinInput.composer = hangulComposer
                }
                cheonjiinInput.backspace()
            } else {
                hangulComposer.backspace()
            }
        } else {
            proxy.deleteBackward()
        }
    }

    private var layerToggleKey: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            if lang == .korean { cheonjiinInput.commit(); hangulComposer.commit() }
            switch layer {
            case .letters: layer = .numbers
            case .numbers, .symbols: layer = .letters
            }
        } label: {
            keyBackground(width: 44, fill: theme.divider) {
                Text(layer == .letters ? "123" : "ABC")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(theme.text)
            }
        }
    }

    /// 한/EN 버튼 — 3단계 cycle: 영어 → 두벌식 → 천지인 → 영어 ...
    /// 길게 누르면 직접 메뉴로 선택 가능 (Menu).
    private var langToggleKey: some View {
        Menu {
            Button {
                cycleSetLang(.english, layout: nil)
            } label: {
                Label(NSLocalizedString("English", comment: "Language: English"), systemImage: lang == .english ? "checkmark" : "abc")
            }
            Button {
                cycleSetLang(.korean, layout: .dubeolsik)
            } label: {
                Label(NSLocalizedString("한국어 (두벌식)", comment: "Language: Korean dubeolsik"), systemImage: (lang == .korean && koreanLayout == .dubeolsik) ? "checkmark" : "keyboard")
            }
            Button {
                cycleSetLang(.korean, layout: .cheonjiin)
            } label: {
                Label(NSLocalizedString("한국어 (천지인)", comment: "Language: Korean cheonjiin"), systemImage: (lang == .korean && koreanLayout == .cheonjiin) ? "checkmark" : "keyboard")
            }
        } label: {
            keyBackground(width: 32, fill: theme.divider) {
                Text(currentLangLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.text)
            }
        } primaryAction: {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            cycleNext()
        }
    }

    /// 현재 모드 라벨: EN / 한 / 천
    private var currentLangLabel: String {
        if lang == .english { return "EN" }
        return koreanLayout == .cheonjiin ? "천" : "한"
    }

    /// 한 단계 cycle: 영어 → 두벌식 → 천지인 → 영어 ...
    private func cycleNext() {
        // 진행 중인 컴포지션 commit
        if lang == .korean { cheonjiinInput.commit(); hangulComposer.commit() }

        switch (lang, koreanLayout) {
        case (.english, _):
            lang = .korean
            koreanLayoutRaw = KoreanLayout.dubeolsik.rawValue
        case (.korean, .dubeolsik):
            koreanLayoutRaw = KoreanLayout.cheonjiin.rawValue
        case (.korean, .cheonjiin):
            lang = .english
        }
        layer = .letters
    }

    /// Menu에서 직접 선택
    private func cycleSetLang(_ newLang: InputLang, layout: KoreanLayout?) {
        if lang == .korean { cheonjiinInput.commit(); hangulComposer.commit() }
        lang = newLang
        if let layout { koreanLayoutRaw = layout.rawValue }
        layer = .letters
    }

    /// 시스템 키보드 전환 — Apple 가이드라인상 모든 커스텀 키보드는 이 버튼 필수.
    private var globeKey: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            if lang == .korean { cheonjiinInput.commit(); hangulComposer.commit() }
            proxy.advanceToNextInputMode()
        } label: {
            keyBackground(width: 32, fill: theme.divider) {
                Image(systemName: "globe")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(theme.text)
            }
        }
    }

    private var spaceKey: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if lang == .korean { cheonjiinInput.commit(); hangulComposer.commit() }
            proxy.insertText(" ")
        } label: {
            keyBackground(fill: theme.surface) {
                Text(lang == .english ?
                     NSLocalizedString("space", comment: "Spacebar (en)") :
                     NSLocalizedString("스페이스", comment: "Spacebar (ko)"))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(theme.textMuted)
            }
        }
    }

    private var returnKey: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if lang == .korean { cheonjiinInput.commit(); hangulComposer.commit() }
            proxy.insertNewline()
        } label: {
            keyBackground(width: 64, fill: Color.blue) {
                Image(systemName: "return")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Send

    private func sendCharacter(_ char: String) {
        if lang == .korean && layer == .letters {
            // Composer proxy 셋업 — proxy가 nil일 때만 (재생성 방지)
            if hangulComposer.proxy == nil {
                hangulComposer.proxy = HangulProxyAdapter(typing: proxy)
                cheonjiinInput.composer = hangulComposer
            }

            switch koreanLayout {
            case .dubeolsik:
                if let first = char.first {
                    hangulComposer.input(first)
                }
            case .cheonjiin:
                cheonjiinInput.tap(char)
            }
        } else {
            // 영문·숫자·기호 — 직접 입력
            proxy.insertText(char)
        }
    }

    // MARK: - 천지인 전용 레이아웃 (iOS 표준 5열 그리드)

    /// 행 1: #123 | ㅣ | ㆍ | ㅡ | ⌫
    /// 행 2: ABC  | ㄱㅋ | ㄴㄹ | ㄷㅌ | ↵(tall)
    /// 행 3: 한글(tall) | ㅂㅍ | ㅅㅎ | ㅈㅊ | ↵(cont)
    /// 행 4: 한글(cont)  | →   | ㅇㅁ | .,?! | 스페이스
    private var cheonjiinBody: some View {
        GeometryReader { geo in
            let hPad: CGFloat = 4
            let avail = geo.size.width - hPad * 2
            let colW = (avail - keySpacing * 4) / 5
            let tallH = keyHeight * 2 + rowSpacing

            VStack(spacing: rowSpacing) {
                // 행 1
                HStack(spacing: keySpacing) {
                    cjLayerKey(w: colW)
                    cjVowelKey("ㅣ", w: colW)
                    cjVowelKey("ㆍ", w: colW)
                    cjVowelKey("ㅡ", w: colW)
                    cjDeleteKey(w: colW)
                }

                // 행 2-4
                HStack(alignment: .top, spacing: keySpacing) {
                    // 왼쪽 열: ABC + 한글(tall)
                    VStack(spacing: rowSpacing) {
                        cjABCKey(w: colW)
                        cjHangulKey(w: colW, h: tallH)
                    }
                    .frame(width: colW)

                    // 가운데 3열: 자음 3행
                    VStack(spacing: rowSpacing) {
                        HStack(spacing: keySpacing) {
                            cjConKey("ㄱㅋ", w: colW)
                            cjConKey("ㄴㄹ", w: colW)
                            cjConKey("ㄷㅌ", w: colW)
                        }
                        HStack(spacing: keySpacing) {
                            cjConKey("ㅂㅍ", w: colW)
                            cjConKey("ㅅㅎ", w: colW)
                            cjConKey("ㅈㅊ", w: colW)
                        }
                        HStack(spacing: keySpacing) {
                            cjArrowKey(w: colW)
                            cjConKey("ㅇㅁ", w: colW)
                            cjSymKey(w: colW)
                        }
                    }
                    .frame(width: colW * 3 + keySpacing * 2)

                    // 오른쪽 열: ↵(tall) + 스페이스
                    VStack(spacing: rowSpacing) {
                        cjReturnKey(w: colW, h: tallH)
                        cjSpaceKey(w: colW)
                    }
                    .frame(width: colW)
                }
            }
            .padding(.horizontal, hPad)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .frame(height: keyHeight * 4 + rowSpacing * 3 + 12)
        .background(theme.surfaceAlt)
    }

    // MARK: - 천지인 키 헬퍼

    private func cjBox<C: View>(w: CGFloat, h: CGFloat = 42, fill: Color, @ViewBuilder _ c: () -> C) -> some View {
        c()
            .frame(width: w, height: h)
            .background(fill)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.18), radius: 0, x: 0, y: 1)
    }

    private func cjVowelKey(_ char: String, w: CGFloat) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            sendCharacter(char)
        } label: {
            cjBox(w: w, fill: theme.surface) {
                Text(char)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(theme.text)
            }
        }
    }

    private func cjConKey(_ label: String, w: CGFloat) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            sendCharacter(label)
        } label: {
            cjBox(w: w, fill: theme.surface) {
                Text(label)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(theme.text)
            }
        }
    }

    // #123 — 숫자/기호 레이어로 전환
    private func cjLayerKey(w: CGFloat) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            cheonjiinInput.commit()
            hangulComposer.commit()
            layer = .numbers
        } label: {
            cjBox(w: w, fill: theme.divider) {
                Text("#123")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(theme.text)
            }
        }
    }

    // ABC — 영어 QWERTY로 전환
    private func cjABCKey(w: CGFloat) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            cycleSetLang(.english, layout: nil)
        } label: {
            cjBox(w: w, fill: theme.divider) {
                Text("ABC")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(theme.text)
            }
        }
    }

    // 한글 — 레이아웃 전환 메뉴 (tall, 행 3-4)
    private func cjHangulKey(w: CGFloat, h: CGFloat) -> some View {
        Menu {
            Button {
                cycleSetLang(.korean, layout: .dubeolsik)
            } label: {
                Label(NSLocalizedString("한국어 (두벌식)", comment: "Language: Korean dubeolsik"),
                      systemImage: "keyboard")
            }
            Button {
                cycleSetLang(.english, layout: nil)
            } label: {
                Label(NSLocalizedString("English", comment: "Language: English"),
                      systemImage: "abc")
            }
        } label: {
            cjBox(w: w, h: h, fill: theme.divider) {
                Text(NSLocalizedString("한글", comment: "Korean mode key"))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(theme.text)
            }
        }
    }

    // ⌫ 삭제 (hold-to-repeat 공유)
    private func cjDeleteKey(w: CGFloat) -> some View {
        cjBox(w: w, fill: theme.divider) {
            Image(systemName: "delete.left")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(theme.text)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in startDeleteHold() }
                .onEnded { _ in stopDeleteHold() }
        )
    }

    // ↵ 리턴 (tall, 행 2-3)
    private func cjReturnKey(w: CGFloat, h: CGFloat) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            cheonjiinInput.commit()
            hangulComposer.commit()
            proxy.insertNewline()
        } label: {
            cjBox(w: w, h: h, fill: Color.blue) {
                Image(systemName: "return")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    // 스페이스
    private func cjSpaceKey(w: CGFloat) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            cheonjiinInput.commit()
            hangulComposer.commit()
            proxy.insertText(" ")
        } label: {
            cjBox(w: w, fill: theme.surface) {
                Text(NSLocalizedString("스페이스", comment: "Spacebar (ko)"))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(theme.textMuted)
            }
        }
    }

    // → 커서 오른쪽 이동
    private func cjArrowKey(w: CGFloat) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            cheonjiinInput.commit()
            hangulComposer.commit()
            proxy.cursorRight()
        } label: {
            cjBox(w: w, fill: theme.divider) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(theme.text)
            }
        }
    }

    // .,?! — 숫자/기호 레이어로 전환
    private func cjSymKey(w: CGFloat) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            cheonjiinInput.commit()
            hangulComposer.commit()
            layer = .numbers
        } label: {
            cjBox(w: w, fill: theme.divider) {
                Text(".,?!")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(theme.text)
            }
        }
    }
}

/// HangulComposer는 자체 proxy를 쓰니, TypingInputProxy를 HangulInputProxy로 어댑트.
private final class HangulProxyAdapter: HangulInputProxy {
    let typing: TypingInputProxy
    init(typing: TypingInputProxy) { self.typing = typing }
    func insertText(_ text: String) { typing.insertText(text) }
    func deleteBackward() { typing.deleteBackward() }
}
