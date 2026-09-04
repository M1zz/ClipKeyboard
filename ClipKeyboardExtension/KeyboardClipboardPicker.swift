//
//  KeyboardClipboardPicker.swift
//  ClipKeyboardExtension
//
//  복사한 것 중 **필요한 데까지만** 넣는 판.
//
//  왜 필요한가: 사용자가 보낸 말 그대로다.
//
//    "웹페이지에서 내용을 복사한 후 일부만 붙여넣고 싶을 때"
//
//  지금까지는 통째로 붙인 다음 남는 부분을 지워야 했다. 키보드에는 지우는 키도 없었으니
//  다른 키보드로 건너가서 지우고 돌아와야 했다. 넣어 주는 기능인데 그러면 넣어 주나 마나다.
//
//  ⚠️ **공백으로 자르지 않는다.** 중국어·일본어에는 띄어쓰기가 없어서 문장 하나가 통째로
//     한 덩어리가 된다. 이 요청을 보낸 사람이 쓰는 말이 바로 그 말이다.
//     `NLTokenizer` 는 그 말들을 알고, 한국어의 조사도 우리가 규칙을 적는 것보다 잘 끊는다.
//
//  고르는 법은 **시작을 누르고 끝을 누른다.** 낱낱을 하나씩 켜고 끄게 하면 열 번을 눌러야
//  한 문장이 되고, 고른 것들 사이에 무엇을 끼워 넣을지도 우리가 정해야 한다.
//  범위로 고르면 사이의 띄어쓰기·문장부호가 **원문 그대로** 따라온다.
//

import SwiftUI
import NaturalLanguage

// MARK: - 무엇 단위로 자를까

enum ClipboardSplitUnit: String, CaseIterable, Identifiable {
    case word
    case sentence
    case paragraph

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .word:      return NSLocalizedString("단어", comment: "Clipboard split unit: word")
        case .sentence:  return NSLocalizedString("문장", comment: "Clipboard split unit: sentence")
        case .paragraph: return NSLocalizedString("줄", comment: "Clipboard split unit: line")
        }
    }

    var tokenizerUnit: NLTokenUnit {
        switch self {
        case .word:      return .word
        case .sentence:  return .sentence
        case .paragraph: return .paragraph
        }
    }
}

/// 자른 조각 하나. 원문에서의 자리를 들고 있어야 **사이의 글자까지 원문 그대로** 이어 붙인다.
struct ClipboardPiece: Identifiable {
    let id: Int
    let text: String
    let range: Range<String.Index>
}

enum ClipboardSplitter {

    /// 판에 세울 조각 수의 상한. 키보드는 메모리가 빠듯하고, 천 개를 그려 봐야 아무도 못 고른다.
    static let maxPieces = 300
    /// 읽어 들일 글자 수의 상한.
    static let maxCharacters = 4000

    static func pieces(of text: String, unit: ClipboardSplitUnit) -> [ClipboardPiece] {
        let source = String(text.prefix(maxCharacters))
        let tokenizer = NLTokenizer(unit: unit.tokenizerUnit)
        tokenizer.string = source

        var out: [ClipboardPiece] = []
        tokenizer.enumerateTokens(in: source.startIndex..<source.endIndex) { range, _ in
            let piece = source[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty {
                out.append(ClipboardPiece(id: out.count, text: piece, range: range))
            }
            return out.count < maxPieces
        }
        return out
    }

    /// 고른 범위의 **원문 그대로.**
    ///
    /// ⚠️ 조각의 글자를 이어 붙이지 않는다. 사이의 띄어쓰기·쉼표·줄바꿈이 원문에 있던 그대로
    ///    따라와야 붙여넣은 글이 사람이 쓴 것처럼 읽힌다. 그래서 조각이 자기 자리를 들고 있다.
    static func text(from source: String, pieces: [ClipboardPiece], range: ClosedRange<Int>) -> String {
        guard let first = pieces.first(where: { $0.id == range.lowerBound }),
              let last = pieces.first(where: { $0.id == range.upperBound }),
              first.range.lowerBound <= last.range.upperBound else { return "" }
        return String(source[first.range.lowerBound..<last.range.upperBound])
    }
}

// MARK: - 판

struct KeyboardClipboardPicker: View {

    /// 복사돼 있던 글. 부르는 쪽이 이미 읽어서 넘긴다(전체 접근 확인도 그쪽 몫이다).
    let text: String
    let theme: AppTheme
    let onInsert: (String) -> Void
    let onClose: () -> Void

    @State private var unit: ClipboardSplitUnit = .word
    /// 처음 누른 자리와 마지막에 누른 자리. 둘 사이가 고른 범위다.
    @State private var anchor: Int?
    @State private var focus: Int?

    private var source: String { String(text.prefix(ClipboardSplitter.maxCharacters)) }
    private var pieces: [ClipboardPiece] { ClipboardSplitter.pieces(of: text, unit: unit) }

    private var selectedRange: ClosedRange<Int>? {
        guard let anchor, let focus else { return nil }
        return min(anchor, focus)...max(anchor, focus)
    }

    /// 고른 범위의 **원문 그대로.** 조각을 이어 붙이지 않는다 - 사이의 띄어쓰기와
    /// 문장부호가 원문에 있던 그대로 따라와야 붙여넣은 글이 자연스럽다.
    private var selectedText: String {
        guard let range = selectedRange else { return "" }
        return ClipboardSplitter.text(from: source, pieces: pieces, range: range)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            VStack(alignment: .leading, spacing: 8) {
                header
                pieceArea
                footer
            }
            .padding(12)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 머리

    private var header: some View {
        HStack(spacing: 8) {
            Picker("", selection: $unit) {
                ForEach(ClipboardSplitUnit.allCases) { unit in
                    Text(unit.localizedName).tag(unit)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            // 자르는 단위가 바뀌면 조각의 번호가 달라진다. 고른 것을 들고 있으면 엉뚱한 데가 잡힌다.
            .onChange(of: unit) { _, _ in
                anchor = nil
                focus = nil
            }

            Button(action: onClose) {
                Image(systemName: AppSymbol.xmarkCircleFill)
                    .font(.title3)
                    .foregroundColor(theme.textMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("닫기", comment: "Close paywall"))
        }
    }

    // MARK: - 조각들

    private var pieceArea: some View {
        ScrollView {
            KeyboardFlowLayout(spacing: 5) {
                ForEach(pieces) { piece in
                    chip(piece)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: .infinity)
    }

    private func chip(_ piece: ClipboardPiece) -> some View {
        let isSelected = selectedRange?.contains(piece.id) ?? false
        return Button {
            KeyboardHaptics.tap()
            tap(piece.id)
        } label: {
            Text(piece.text)
                .font(.footnote)
                .lineLimit(1)
                .foregroundColor(isSelected ? .white : theme.text)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isSelected ? theme.accent : theme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(piece.text)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// 시작을 누르고 끝을 누른다. 고른 안을 다시 누르면 거기서 새로 시작한다.
    private func tap(_ id: Int) {
        guard let range = selectedRange else {
            anchor = id
            focus = id
            return
        }
        if range.contains(id) {
            if range.lowerBound == range.upperBound {
                anchor = nil     // 하나뿐인 것을 다시 누르면 해제
                focus = nil
            } else {
                anchor = id      // 고른 안을 누르면 거기서 다시
                focus = id
            }
        } else {
            focus = id           // 밖을 누르면 거기까지 늘린다
        }
    }

    // MARK: - 발

    private var footer: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                if selectedText.isEmpty {
                    Text(NSLocalizedString("시작을 누르고 끝을 누르세요", comment: "Clipboard picker hint: tap start then end"))
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                } else {
                    Text(selectedText)
                        .font(.caption)
                        .foregroundColor(theme.text)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)

            Button {
                KeyboardHaptics.softTap()
                anchor = pieces.first?.id
                focus = pieces.last?.id
            } label: {
                Text(NSLocalizedString("전체", comment: "Category tab: all"))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(theme.accentSoft)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(pieces.isEmpty)

            Button {
                KeyboardHaptics.mediumTap()
                onInsert(selectedText)
            } label: {
                Text(NSLocalizedString("넣기", comment: "Clipboard picker: insert selected text"))
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(selectedText.isEmpty ? theme.textMuted.opacity(0.4) : theme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(selectedText.isEmpty)
        }
    }
}

// MARK: - 흐르는 배치

/// 줄이 모자라면 아래로 흐른다. 조각의 길이가 제각각이라 격자로는 못 담는다.
struct KeyboardFlowLayout: Layout {

    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: proposal.width ?? x, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - 누르고 있으면 되풀이하는 키

/// 지우기처럼 한 번으로는 모자란 키. 누르는 순간 한 번, 붙잡고 있으면 이어서.
///
/// ⚠️ `Button` 에 `LongPressGesture` 를 얹지 않는다. 둘이 같은 손짓을 두고 다퉈서
///    짧게 누른 것이 삼켜지는 날이 온다. 눌림을 `DragGesture` 하나로만 읽는다.
struct RepeatingKey<Label: View>: View {

    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var repeater = KeyRepeater()
    @State private var isPressed = false

    var body: some View {
        label()
            .opacity(isPressed ? 0.55 : 1)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        action()
                        repeater.start(action)
                    }
                    .onEnded { _ in
                        isPressed = false
                        repeater.stop()
                    }
            )
            .onDisappear { repeater.stop() }
    }
}

/// 되풀이의 박자. 첫 반복까지 뜸을 준다 - 안 그러면 짧게 누른 한 번이 연타로 샌다.
final class KeyRepeater {
    private var timer: Timer?

    func start(_ tick: @escaping () -> Void) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            tick()
            self?.timer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { _ in tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit { stop() }
}
