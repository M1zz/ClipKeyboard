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

    /// 나눈 조각. **단위가 바뀔 때만** 다시 나눈다.
    ///
    /// ⚠️ 예전에는 계산 프로퍼티라 한 번 그릴 때 여섯 번 넘게 불렸고, 그때마다 자연어 토크나이저로
    ///    글 전체(최대 4,000자)를 다시 나눴다. 조각 하나를 누를 때마다 그만큼 돌았다.
    @State private var piecesCache = PiecesCache()
    private var pieces: [ClipboardPiece] {
        if piecesCache.unit != unit {
            piecesCache.pieces = ClipboardSplitter.pieces(of: text, unit: unit)
            piecesCache.unit = unit
        }
        return piecesCache.pieces
    }

    /// 참조 타입이라 그리는 중에 채워도 화면을 다시 그리게 하지 않는다.
    final class PiecesCache {
        var unit: ClipboardSplitUnit?
        var pieces: [ClipboardPiece] = []
    }

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
            .buttonStyle(.squish)
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
        .buttonStyle(.squish)
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
            .buttonStyle(.squish)
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
            .buttonStyle(.squish)
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

// MARK: - '최근' 탭: 복사한 것

/// 키보드 맨 앞 탭. 복사한 것을 **잠깐 쓰는 그릇**으로 보여 준다.
///
/// 왜 맨 앞인가: 사용자가 보낸 말 그대로다.
///
///   "I use the app about 70% for short term snippets and 30% for permanent snippets.
///    ... having the first page something like an inbox (that immediately appears in the keyboard)"
///
/// 단축어는 오래 두고 쓰는 것이고, 여기는 한 주·한 달 쓰고 버리는 것이다. 그런 사람에게는
/// 이쪽이 더 자주 열린다. 보관 기간은 `SmartClipboardHistory.retentionDays` 가 정한다.
///
/// **복사한 것이 저절로 선다.** 예전에는 맨 위의 저장 버튼을 눌러야 담겼는데, 사람들은 그
/// 버튼("복사한 글을 이 목록에 저장")이 아니라 복사한 글 자체를 보고 싶어 했다.
/// 담는 일은 `KeyboardView.collectCopiedTextIntoRecents` 가 한다.
///
/// **짧게 누르면 넣고, 길게 누르면 클립보드로, 왼쪽으로 밀면 지운다.**
struct KeyboardRecentClipsPanel: View {

    /// 보여 줄 것. 부르는 쪽이 보관 기간과 검색어로 이미 걸러서 넘긴다.
    let clips: [SmartClipboardHistory]
    let theme: AppTheme
    /// 단축어 키와 같은 키캡으로 그린다(물성 · 키 색 · 높이 · 글자 크기를 그대로 받는다).
    let skin: KeyboardSkin
    let keyColor: Color
    let keyHeight: CGFloat
    let fontSize: CGFloat
    /// 검색 중이면 빈 화면의 말이 달라진다.
    let isFiltering: Bool
    /// 전체 접근이 꺼져 있어 복사한 것을 못 읽는가(진짜 키보드만). 빈 화면이 그 사정을 말한다.
    let needsFullAccess: Bool
    let onInsert: (SmartClipboardHistory) -> Void
    let onCopy: (SmartClipboardHistory) -> Void
    let onDelete: (SmartClipboardHistory) -> Void
    /// 줄 오른쪽 + : 이 글을 단축어로 저장한다(앱의 저장 시트가 뜬다).
    let onSave: (SmartClipboardHistory) -> Void
    /// 한 줄을 밀고 있는 동안 참. 부르는 쪽은 그동안 탭을 넘기지 않는다.
    @Binding var isSwipingRow: Bool

    /// 지우기 버튼이 열려 있는 줄. 한 번에 하나만 연다.
    @State private var openRowId: UUID?
    /// 지금 밀고 있는 줄과 그 거리(왼쪽이 음수).
    @State private var draggingId: UUID?
    @State private var dragOffset: CGFloat = 0
    /// 길게 눌러 복사한 줄. 손을 뗄 때 오는 누르기를 한 번 삼킨다(단축어 키의 `InAppLongPressCopy` 와 같다).
    @State private var suppressedTapId: UUID?
    /// 줄을 민 손짓이 끝난 때. 민 손을 떼는 순간 버튼이 눌린 것으로 읽히지 않게 한다.
    @State private var lastSwipeEnd = Date.distantPast

    /// 밀어서 드러나는 지우기 버튼의 폭.
    private static let deleteWidth: CGFloat = 76
    /// 이만큼 끝까지 밀면 버튼을 누르지 않아도 지운다(iOS 목록과 같은 손짓).
    private static let fullSwipeDistance: CGFloat = 170

    /// 줄 오른쪽 + 가 차지하는 폭. 줄의 글은 이만큼 비켜 선다.
    private static let saveButtonWidth: CGFloat = 40

    var body: some View {
        if clips.isEmpty {
            emptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(clips) { clip in
                        swipeRow(clip)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 10)
            }
            // 카테고리 줄과 같은 이유(키보드는 낮아서 가장자리 흐림이 첫 줄을 덮는다).
            .scrollEdgeEffectHidden(true, for: .all)
        }
    }

    /// 한 줄로 보일 글. 남이 보면 곤란한 것(카드번호·계좌)은 끝 네 자리만.
    ///
    /// ⚠️ 분류는 앞부분만 본다. 키보드에 긴 글이 복사돼 있어도 정규식이 그 전부를 훑지 않게.
    static func maskedPreview(_ text: String) -> String {
        let head = String(text.prefix(300))
        let oneLine = head.split(whereSeparator: \.isNewline).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        let type = ClipboardClassificationService.shared.classify(content: head).type
        guard type.isSensitive else { return oneLine }
        return "\u{2022}\u{2022}\u{2022}\u{2022} " + String(head.filter { !$0.isWhitespace }.suffix(4))
    }

    // MARK: - 밀어서 지우기

    private func restingOffset(_ clip: SmartClipboardHistory) -> CGFloat {
        openRowId == clip.id ? -Self.deleteWidth : 0
    }

    private func offset(_ clip: SmartClipboardHistory) -> CGFloat {
        draggingId == clip.id ? dragOffset : restingOffset(clip)
    }

    /// 한 줄 + 그 뒤에 숨은 지우기 버튼.
    ///
    /// ⚠️ `List` 의 swipeActions 를 쓰지 않는다. 이 판은 옆으로 밀어 탭을 넘기는 판이라,
    ///    목록의 손짓과 탭 넘기기가 같은 손짓을 두고 다툰다. 줄을 민 손짓은 여기서 잡고
    ///    `isSwipingRow` 로 알려, 부르는 쪽이 그때만 탭을 넘기지 않는다.
    /// ⚠️ 손짓은 `simultaneousGesture` 로 단다. 우선 손짓으로 달면 위아래 스크롤이 먹힌다.
    private func swipeRow(_ clip: SmartClipboardHistory) -> some View {
        let current = offset(clip)
        return ZStack(alignment: .trailing) {
            if current < 0 {
                Button {
                    delete(clip)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "trash.fill")
                            .font(.subheadline.weight(.semibold))
                        Text(NSLocalizedString("Delete", comment: "Delete button"))
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(.white)
                    .frame(width: max(Self.deleteWidth, -current))
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                    .clipShape(KeycapShape(radius: keycapRadius))
                }
                .buttonStyle(.plain)
            }
            row(clip)
                .offset(x: current)
        }
        .simultaneousGesture(swipeGesture(clip))
    }

    private func swipeGesture(_ clip: SmartClipboardHistory) -> some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                let w = value.translation.width
                let h = value.translation.height
                if draggingId != clip.id {
                    // 위아래로 미는 것은 스크롤이다. 닫힌 줄을 오른쪽으로 미는 것은 탭 넘기기다.
                    guard abs(w) > abs(h) * 1.2 else { return }
                    guard w < 0 || openRowId == clip.id else { return }
                    if openRowId != clip.id { openRowId = nil }
                    draggingId = clip.id
                    isSwipingRow = true
                }
                dragOffset = min(0, restingOffset(clip) + w)
            }
            .onEnded { value in
                guard draggingId == clip.id else { return }
                let final = restingOffset(clip) + value.translation.width
                if final < -Self.fullSwipeDistance {
                    delete(clip)
                } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        openRowId = final < -Self.deleteWidth / 2 ? clip.id : nil
                        draggingId = nil
                    }
                }
                lastSwipeEnd = Date()
                // 탭 넘기기 쪽 손짓도 같은 순간에 끝난다. 그쪽이 먼저든 나중이든 이 값을 보게 한 박자 늦춘다.
                DispatchQueue.main.async { isSwipingRow = false }
            }
    }

    private func delete(_ clip: SmartClipboardHistory) {
        withAnimation(.easeOut(duration: 0.2)) {
            openRowId = nil
            draggingId = nil
        }
        onDelete(clip)
    }

    // MARK: - 키캡

    /// 단축어 키와 같은 값(`KeyboardView.keycapRadius` · `keycapSkirtColor`).
    private var keycapRadius: CGFloat { skin.cornerRadius(base: theme.radiusMd) }
    private var keycapShape: KeycapShape { KeycapShape(radius: keycapRadius) }
    /// 단축어 키와 같은 키캡이되, 줄이 넓어 **얕게** 눌린다(`RowPressButtonStyle` 주석).
    private var keycapStyle: KeycapButtonStyle {
        KeycapButtonStyle(skin: skin, cornerRadius: keycapRadius,
                          skirtColor: Color.black.opacity(skin.skirtOpacity(isDark: theme.isDark)),
                          squishScale: SquishPress.rowScale)
    }

    /// 단축어 키의 면(`memoButtonLabel`): 키 색 + 윗면 빛 + 그림자.
    private var keycapFace: some View {
        keycapShape
            .foregroundColor(keyColor)
            .overlay(
                keycapShape.fill(LinearGradient(
                    colors: [Color.white.opacity(skin.sheenOpacity(isDark: theme.isDark)), .clear],
                    startPoint: .top, endPoint: .center))
            )
            .shadow(color: Color.black.opacity(skin.shadowOpacity), radius: 2, y: 1)
    }

    // MARK: - 한 줄

    /// 한 줄. 키캡 전체가 넣기 단추이고, 오른쪽 끝에 단축어로 저장하는 + 가 얹힌다.
    ///
    /// ⚠️ 예전에는 그 자리에 "4초 전" 같은 복사한 때가 있었다. 최근은 30일 안의 것만 서고
    ///    새것이 위에 오므로 때는 순서가 이미 말해 준다. 그보다 "이건 계속 쓰겠다" 싶은 글을
    ///    그 자리에서 단축어로 옮기는 길이 없었다(길게 누르기는 복사다).
    /// ⚠️ + 는 넣기 단추 **바깥**에 얹는다. 단추 안의 단추는 눌림이 바깥 단추로 새어 글이 같이 들어간다.
    private func row(_ clip: SmartClipboardHistory) -> some View {
        ZStack(alignment: .trailing) {
            insertButton(clip)
            saveButton(clip)
                .padding(.trailing, 4)
        }
    }

    private func saveButton(_ clip: SmartClipboardHistory) -> some View {
        Button {
            guard draggingId == nil, Date().timeIntervalSince(lastSwipeEnd) > 0.3, openRowId == nil else { return }
            KeyboardHaptics.tap()
            onSave(clip)
        } label: {
            Image(systemName: AppSymbol.plus)
                .font(.system(size: fontSize * 0.82, weight: .semibold))
                .foregroundColor(theme.accent)
                .frame(width: 30, height: 30)
                .background(Circle().fill(theme.accentSoft))
                .frame(width: Self.saveButtonWidth, height: max(keyHeight, 44))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("단축어로 저장", comment: "Save to memo sheet title"))
    }

    private func insertButton(_ clip: SmartClipboardHistory) -> some View {
        let type = clip.userCorrectedType ?? clip.detectedType
        return Button {
            tap(clip)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: fontSize * 0.82, weight: .semibold))
                    .foregroundColor(theme.textMuted)
                    .frame(width: 18)
                    .accessibilityHidden(true)

                Text(preview(clip, type: type))
                    .font(.system(size: fontSize))
                    .foregroundColor(theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 오른쪽 + 자리(`saveButton`). 글이 그 밑으로 들어가지 않게 비워 둔다.
                Color.clear
                    .frame(width: Self.saveButtonWidth - 8, height: 1)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: keyHeight)
            .background(keycapFace)
            .contentShape(Rectangle())
        }
        .buttonStyle(keycapStyle)
        .onLongPressGesture(minimumDuration: 0.4) {
            suppressedTapId = clip.id
            onCopy(clip)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(NSLocalizedString("눌러서 넣습니다. 길게 누르면 클립보드에 복사합니다",
                                             comment: "Keyboard recent tab: row hint"))
        .accessibilityAction(named: Text(NSLocalizedString("Copy to clipboard", comment: "Context menu: copy"))) {
            onCopy(clip)
        }
        .accessibilityAction(named: Text(NSLocalizedString("단축어로 저장", comment: "Save to memo sheet title"))) {
            onSave(clip)
        }
        .accessibilityAction(named: Text(NSLocalizedString("Delete", comment: "Delete button"))) {
            delete(clip)
        }
    }

    private func tap(_ clip: SmartClipboardHistory) {
        if suppressedTapId == clip.id {
            suppressedTapId = nil
            return
        }
        // 밀던 손을 뗀 것은 누른 것이 아니다.
        guard draggingId == nil, Date().timeIntervalSince(lastSwipeEnd) > 0.3 else { return }
        // 지우기 버튼이 열려 있으면 누른 것은 닫으라는 뜻이다. 그때 글을 넣으면 놀란다.
        if openRowId != nil {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { openRowId = nil }
            return
        }
        KeyboardHaptics.tap()
        onInsert(clip)
    }

    /// 목록에 보일 글. 카드번호·계좌처럼 남이 보면 곤란한 것은 **끝 네 자리만** 보인다.
    /// 넣을 때는 원문 그대로 들어간다. 키보드는 남 앞에서도 열리는 자리라서다.
    private func preview(_ clip: SmartClipboardHistory, type: ClipboardItemType) -> String {
        let text = clip.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard type.isSensitive else { return text }
        let tail = String(text.filter { !$0.isWhitespace }.suffix(4))
        return "\u{2022}\u{2022}\u{2022}\u{2022} " + tail
    }

    // MARK: - 빈 화면

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: isFiltering ? "magnifyingglass" : AppSymbol.tray)
                .font(.title2)
                .foregroundColor(theme.textFaint)
            Text(isFiltering
                 ? NSLocalizedString("Try a shorter keyword or clear the filter.", comment: "Empty hint: search")
                 : NSLocalizedString("아직 담아 둔 것이 없어요", comment: "Keyboard recent tab: empty title"))
                .font(.footnote.weight(.semibold))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)
            if !isFiltering {
                // 위에 버튼이 없어졌으니 "버튼을 누르면" 이 아니다. 복사하면 저절로 선다.
                // 전체 접근이 꺼져 있으면 저절로 못 서므로 그 사정을 먼저 말한다.
                Text(needsFullAccess
                     ? NSLocalizedString("설정 > 키보드에서 '전체 접근 허용'을 켜주세요", comment: "Full Access required toast")
                     : String(format: NSLocalizedString("복사한 글이 %d일 동안 남아요",
                                                        comment: "What's new 5.1.8 retention title. %d is the number of days"),
                              SmartClipboardHistory.retentionDays))
                    .font(.caption2)
                    .foregroundColor(theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }
}
