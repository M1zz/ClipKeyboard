//
//  KeyboardOverlays.swift
//  ClipKeyboardExtension
//
//  KeyboardView에서 분리한 보조 뷰/모델:
//  ImageMemoButton, TemplateInputOverlay, PlaceholderInputView,
//  TypeVisualStyle, DisplayItem.
//

import SwiftUI
import UIKit

struct ImageMemoButton: View {
    let title: String
    let fileName: String
    let buttonHeight: Double
    let buttonFontSize: Double

    @Environment(\.colorScheme) private var colorScheme
    private var theme: AppTheme { AppTheme.resolve(kind: .paper, isDark: colorScheme == .dark) }

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: theme.radiusSm)
                .foregroundColor(Color(uiColor: .systemGray5))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: buttonHeight)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm))
            }

            // 텍스트 가독성을 위한 하단 그라디언트
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm))

            Text(title)
                .font(.system(size: buttonFontSize, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .padding(10)
        }
        .frame(height: buttonHeight)
        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
        .onAppear {
            guard image == nil, !fileName.isEmpty else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                let loaded = MemoStore.shared.loadImage(fileName: fileName)
                DispatchQueue.main.async { image = loaded }
            }
        }
    }
}

#Preview {
    KeyboardView()
}

// 템플릿 입력 오버레이
struct TemplateInputOverlay: View {
    @ObservedObject var state: TemplateInputState

    /// 누가 이 화면을 띄우고 있는가. **값이 없을 때 할 수 있는 일이 갈린다.**
    ///
    /// ⚠️ 앱 안(미리보기)에서는 여기서 바로 값을 적어 넣을 수 있다. 시스템 키보드를
    ///    올릴 수 있으니까. 진짜 키보드 익스텐션은 **자기가 키보드라서** 글자를 받을
    ///    자판을 따로 부를 수 없다. 그래서 그쪽에는 "앱에서 추가하고 오세요"로 안내한다.
    ///    같은 화면이지만 할 수 있는 일이 다른 것은 이 한 가지 때문이다.
    var hostKind: KeyboardHostKind = .keyboardExtension

    @Environment(\.colorScheme) private var colorScheme
    private var theme: AppTheme { AppTheme.resolve(kind: .paper, isDark: colorScheme == .dark) }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: 헤더 - 항상 보임: [00][000][0000] + 입력 + 닫기
            HStack(spacing: 8) {
                    Spacer()

                    // 숫자 플레이스홀더가 있을 때만 자릿수 패드 표시
                    if let numericPH = state.placeholders.first(where: { TemplateVariableProcessor.isNumericToken($0) }) {
                        HStack(spacing: 6) {
                            ForEach(["0", "00", "000", "0000"], id: \.self) { zeros in
                                let cur = state.inputs[numericPH] ?? ""
                                let inactive = cur.isEmpty || cur == "0"
                                Button {
                                    let v = state.inputs[numericPH] ?? ""
                                    guard !v.isEmpty && v != "0" else { return }
                                    guard v.count + zeros.count <= 13 else { return }
                                    state.inputs[numericPH] = v + zeros
                                    state.updateAllPlaceholdersFilled()
                                    KeyboardHaptics.tap()
                                } label: {
                                    Text(zeros)
                                        .font(.system(.footnote, design: .monospaced, weight: .semibold))
                                        .lineLimit(1)
                                        .fixedSize()
                                        .frame(height: 36)
                                        .padding(.horizontal, 10)
                                        .background(inactive ? theme.accent.opacity(0.05) : theme.accent.opacity(0.12))
                                        .foregroundColor(inactive ? theme.accent.opacity(0.35) : theme.accent)
                                        .cornerRadius(theme.radiusXs)
                                }
                                .disabled(inactive)
                            }
                        }
                    }

                    // 입력 버튼 (항상 노출)
                    Button {
                        completeInput()
                    } label: {
                        Text(NSLocalizedString("입력하기", comment: "Insert with template button"))
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundColor(theme.accentFg)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(state.allPlaceholdersFilled ? theme.accent : Color.gray.opacity(0.4))
                            .cornerRadius(theme.radiusSm)
                    }
                    .disabled(!state.allPlaceholdersFilled)

                    // 닫기
                    Button {
                        withAnimation {
                            state.isShowing = false
                            state.currentFocusedPlaceholder = nil
                        }
                    } label: {
                        Image(systemName: AppSymbol.xmarkCircleFill)
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))

                Divider()

                // MARK: 컬러 프리뷰
                Text(previewText)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(theme.radiusXs)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                // MARK: 플레이스홀더 입력 (스크롤)
                ScrollView {
                    VStack(spacing: 16) {
                        if state.placeholders.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: AppSymbol.questionmarkCircle)
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text(NSLocalizedString("No template variables", comment: "Empty state: no template variables"))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(NSLocalizedString("This template has no values to set.\nPlease try again.", comment: "Empty state: no template variables hint"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(40)
                        } else {
                            ForEach(state.placeholders, id: \.self) { placeholder in
                                PlaceholderInputView(
                                    hostKind: hostKind,
                                    placeholder: placeholder,
                                    // ⚠️ 값을 고른다고 **바로 넣지 않는다.**
                                    //
                                    //    예전에는 마지막 빈칸이 채워지는 순간 곧바로
                                    //    `completeInput()` 이 돌아 화면이 닫혔다. 그래서 위에
                                    //    있는 미리보기가 무엇을 위해 있는 것인지 알 수 없었다
                                    //    바뀌는 장면이 안 보이고 결과만 남으니까.
                                    //
                                    //    이 화면이 가르치려는 것이 바로 그 장면이다.
                                    //    "{이름} 자리에 고객님이 들어가는구나"를 **눈으로 본 뒤에**
                                    //    입력하기를 누르는 것과, 눌렀더니 글이 들어가 있는 것은
                                    //    같은 결과지만 배우는 것이 다르다.
                                    //
                                    //    고르는 일과 넣는 일을 떼어 놓으면 고쳐 볼 수도 있다.
                                    //    "대표님으로 바꿔 볼까"가 가능해진다.
                                    selectedValue: Binding(
                                        get: { state.inputs[placeholder] ?? "" },
                                        set: { newValue in
                                            state.inputs[placeholder] = newValue
                                            state.updateAllPlaceholdersFilled()
                                        }
                                    ),
                                    templateId: state.templateId
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(Color(UIColor.systemBackground))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }

    /// 넣으면 이렇게 된다 - **실제로 들어갈 것**을 그린다.
    ///
    /// ⚠️ 예전에는 `inputs` 에 없는 토큰을 전부 빈칸으로 그렸다. 그런데 `{날짜}` 같은
    ///    자동 변수는 넣는 순간 시스템이 채운다. 그래서 화면에는 **구멍이 둘로 보이는데
    ///    채우는 칸은 하나**뿐이었고, 하나가 빠진 것처럼 읽혔다. 빠진 적은 없었다
    ///    미리보기가 결과와 다른 그림을 그리고 있었을 뿐이다.
    ///
    /// ⚠️ 색이 셋인 이유: **누가 채웠는지가 다르다.**
    ///    · 내가 고른 값 - 초록. 내가 한 일이다.
    ///    · 알아서 채워진 값 - 흐린 글자. 손댈 것이 없다는 뜻이다.
    ///    · 아직 빈칸 - 칩. 여기가 내가 할 일이다.
    ///    셋을 같은 색으로 칠하면 "그래서 내가 뭘 해야 하지"가 화면에서 사라진다.
    private var previewText: AttributedString {
        let font: Font = .subheadline
        var out = AttributedString()
        if !state.baseMemoValue.isEmpty {
            out += state.baseMemoValue.templateAwareAttributed(theme: theme, font: font)
            out += AttributedString("\n")
        }
        for seg in TemplatePlaceholder.previewSegments(of: state.originalText,
                                                       inputs: state.inputs,
                                                       clipboard: clipboardPreview) {
            switch seg.kind {
            case .filled:
                var filled = AttributedString(seg.text)
                filled.foregroundColor = Color(UIColor.systemGreen)
                filled.font = font.weight(.semibold)
                out += filled
            case .automatic:
                var auto = AttributedString(seg.text)
                auto.foregroundColor = theme.textMuted
                auto.font = font
                out += auto
            case .blank, .plain:
                out += seg.text.templateAwareAttributed(theme: theme, font: font)
            }
        }
        return out
    }

    /// `{클립보드}` 가 있을 때만 읽는다 - iOS 는 읽을 때마다 붙여넣기 프롬프트를 띄울 수 있다.
    private var clipboardPreview: String? {
        guard TemplateVariableProcessor.containsClipboardToken(state.originalText) else { return nil }
        return UIPasteboard.general.string
    }

    private func completeInput() {
        var userInfo: [String: Any] = [
            "text": state.originalText,
            "inputs": state.inputs
        ]
        if let baseId = state.baseMemoId { userInfo["baseMemoId"] = baseId }
        if let templateId = state.templateId { userInfo["memoId"] = templateId }
        NotificationCenter.default.post(
            name: Notification.Name.templateInputComplete,
            object: nil,
            userInfo: userInfo
        )
        withAnimation {
            state.isShowing = false
            state.currentFocusedPlaceholder = nil
            state.baseMemoId = nil
        }
    }
}

// 플레이스홀더 입력 뷰 (선택 방식 + 숫자 토큰 직접 입력)
struct PlaceholderInputView: View {
    let hostKind: KeyboardHostKind
    let placeholder: String
    @Binding var selectedValue: String
    let templateId: UUID?

    @Environment(\.colorScheme) private var colorScheme
    private var theme: AppTheme { AppTheme.resolve(kind: .paper, isDark: colorScheme == .dark) }

    /// 여기서 방금 적어 넣은 값 - 저장소를 다시 읽게 만드는 방아쇠.
    ///
    /// ⚠️ `predefinedValues` 는 계산 프로퍼티라 저장소만 바꿔서는 화면이 안 바뀐다.
    ///    (SwiftUI 는 저장소를 지켜보지 않는다) 이 값이 바뀌어야 다시 그린다.
    @State private var addedValues: [String] = []
    /// 값을 적는 칸. 앱 안에서만 쓰인다.
    @State private var draftValue: String = ""
    @FocusState private var draftFocused: Bool

    private var predefinedValues: [String] {
        _ = addedValues   // 방금 적어 넣은 것이 있으면 다시 읽는다
        return PredefinedValuesStore.shared.getValuesForTemplate(placeholder: placeholder,
                                                                 templateId: templateId)
    }

    /// 적어 넣고 **곧바로 고른 것으로 둔다.** 적은 뒤에 한 번 더 눌러야 한다면
    /// 적는 일이 끝나지 않은 것처럼 느껴진다.
    private func commitDraft() {
        let value = draftValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        PredefinedValuesStore.shared.addValue(value,
                                              for: placeholder,
                                              sourceMemoId: templateId,
                                              sourceMemoTitle: placeholder.strippingTemplateBraces)
        addedValues.append(value)
        selectedValue = value
        draftValue = ""
        draftFocused = false
        KeyboardHaptics.tap()
    }

    /// v4.0.8: 토큰명에 금액/amount/qty 등 키워드가 있으면 numeric 직접 입력 모드.
    private var isNumericToken: Bool {
        TemplateVariableProcessor.isNumericToken(placeholder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isNumericToken {
                numericInputSection
            } else {
                textPredefinedSection
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Numeric input
    // 자릿수 패드(00·000·0000) + 1-9 수평 스크롤.

    @ViewBuilder
    private var numericInputSection: some View {
        VStack(spacing: 8) {
            // 전체 너비: [1][2][3][4][5][6][7][8][9][⌫]
            HStack(spacing: 6) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9"], id: \.self) { digit in
                    numericScrollKey(digit)
                }
                numericScrollBackspace
            }

            // 사전 저장 값 빠른 선택
            if !predefinedValues.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(predefinedValues, id: \.self) { value in
                            Button {
                                selectedValue = value
                                KeyboardHaptics.tap()
                            } label: {
                                Text(value)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(selectedValue == value ? theme.accent.opacity(0.2) : Color(UIColor.systemGray5))
                                    .foregroundColor(selectedValue == value ? theme.accent : .primary)
                                    .cornerRadius(theme.radiusSm)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func numericScrollKey(_ digit: String) -> some View {
        Button {
            guard selectedValue.count + digit.count <= 13 else { return }
            if selectedValue.isEmpty && digit == "00" {
                selectedValue = "0"
            } else if selectedValue == "0" {
                selectedValue = digit == "0" || digit == "00" ? "0" : digit
            } else {
                selectedValue += digit
            }
            KeyboardHaptics.tap()
        } label: {
            Text(digit)
                .font(.system(.headline, design: .monospaced, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(UIColor.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(theme.radiusXs)
        }
    }

    @ViewBuilder
    private var numericScrollBackspace: some View {
        Button {
            if !selectedValue.isEmpty { selectedValue.removeLast() }
            KeyboardHaptics.tap()
        } label: {
            Image(systemName: AppSymbol.deleteLeft)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(UIColor.systemGray4))
                .foregroundColor(.primary)
                .cornerRadius(theme.radiusXs)
        }
    }

    // MARK: - 값이 아직 없을 때

    /// 고를 값이 하나도 없는 자리.
    ///
    /// ⚠️ 예전에는 여기가 **막다른 길**이었다. "저장된 값이 없어요 / 앱에서 추가하세요"만
    ///    적혀 있어서, 앱 안에서 이 화면을 보고 있는 사람에게도 앱으로 가라고 했다.
    ///    이미 앱인데.
    ///
    /// ⚠️ 앱 안에서는 여기서 바로 적어 넣는다. 진짜 익스텐션에서는 그럴 수 없어서
    ///    (자기가 키보드라 글자를 받을 자판을 부를 수 없다) 예전 안내를 그대로 둔다.
    @ViewBuilder
    private var emptyValuesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: AppSymbol.exclamationmarkTriangleFill)
                    .font(.caption)
                    .foregroundColor(.orange)
                Text(NSLocalizedString("No saved values", comment: "Placeholder values empty title"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }

            if hostKind == .inApp {
                Text(String(format: NSLocalizedString("'%@' 자리에 넣을 값을 여기서 바로 만들 수 있어요.",
                                                      comment: "Placeholder inline add hint"),
                            placeholder.strippingTemplateBraces))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    TextField(String(format: NSLocalizedString("%@ 값",
                                                               comment: "Placeholder value field prompt"),
                                     placeholder.strippingTemplateBraces),
                              text: $draftValue)
                        .textFieldStyle(.plain)
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(theme.radiusSm)
                        .focused($draftFocused)
                        .submitLabel(.done)
                        .onSubmit { commitDraft() }

                    Button(action: commitDraft) {
                        Text(NSLocalizedString("추가", comment: "Add placeholder value button"))
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(theme.accentFg)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(draftValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? Color.gray.opacity(0.4) : theme.accent)
                            .cornerRadius(theme.radiusSm)
                    }
                    .disabled(draftValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                Text(String(format: NSLocalizedString("Open the app to add values for '%@' in placeholder settings", comment: "Placeholder values empty hint"), placeholder.strippingTemplateBraces))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(theme.radiusXs)
    }

    // MARK: - Text predefined (existing flow)

    @ViewBuilder
    private var textPredefinedSection: some View {
        if predefinedValues.isEmpty {
            emptyValuesSection
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(predefinedValues, id: \.self) { value in
                        Button {
                            selectedValue = value
                            KeyboardHaptics.tap()
                        } label: {
                            Text(value)
                                .font(.footnote.weight(selectedValue == value ? .semibold : .regular))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedValue == value ? theme.accent : Color(UIColor.systemGray5))
                                .foregroundColor(selectedValue == value ? theme.accentFg : .primary)
                                .cornerRadius(theme.radiusLg)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 가리키는 키의 파형

/// 튜토리얼이 가리키는 키에서 **밖으로 번져 나가는 파형.**
///
/// ⚠️ 예전에는 테두리 한 줄에 그림자였다. 그런데 이 키보드에는 이미 테두리가 여럿이다
///    카테고리 색 테두리, 콤보 점선, 키캡 자체의 윤곽. 거기에 테두리를 하나 더 얹으면
///    **"또 하나의 테두리"**로 읽히지 눈이 끌려가지 않는다. 가만히 있는 것은 배경이 된다.
///
/// ⚠️ 파형은 **키 밖으로 나간다.** 키 안에서 일어나는 일은 키의 생김새로 읽히지만,
///    바깥으로 번지는 것은 주변과 다른 사건이라 주변시로도 잡힌다. 화면에서 이것만
///    움직이면 눈은 반드시 그리로 간다.
///
/// ⚠️ 키 자체는 **덮지 않는다.** 파형은 윤곽선만 그리고 속은 비운다 - 글자를 가리면
///    무엇을 누르라는 건지 읽을 수가 없다.
///
/// ⚠️ 움직임 줄이기를 켠 사람에게는 번지지 않는다. 대신 **가만히 있는 두 겹**을 둔다
///    움직임을 뺀다고 표시까지 없애면 그 사람만 무엇을 누를지 모르게 된다.
struct KeyRipple: View {
    let shape: KeycapShape
    let color: Color

    /// 한 겹이 태어나서 사라지기까지(초).
    private static let period: Double = 1.6
    /// 몇 겹이 동시에 번지는가. 셋이면 끊기지 않고 이어져 보인다.
    private static let ringCount = 3
    /// 얼마나 멀리 번지는가(pt). 옆 키를 침범하지 않는 선.
    private static let reach: CGFloat = 14

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                still
            } else {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ForEach(0..<Self.ringCount, id: \.self) { i in
                            ring(progress: phase(t, index: i))
                        }
                        // 가운데 한 겹은 늘 남아 있다 - 파형이 잦아든 순간에도
                        // 가리키는 것이 무엇인지 사라지지 않는다.
                        shape.strokeBorder(color.opacity(0.9), lineWidth: 2.5)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// 겹마다 시작을 어긋나게 해 물결이 이어지게 한다.
    private func phase(_ t: TimeInterval, index: Int) -> Double {
        let offset = Double(index) / Double(Self.ringCount)
        return ((t / Self.period) + offset).truncatingRemainder(dividingBy: 1)
    }

    /// 한 겹 - 밖으로 나가며 옅어지고 가늘어진다.
    private func ring(progress p: Double) -> some View {
        let spread = Self.reach * CGFloat(p)
        return shape
            .strokeBorder(color.opacity(0.55 * (1 - p)), lineWidth: 3 * (1 - p) + 0.5)
            .padding(-spread)
    }

    /// 움직임 없이도 "여기"가 읽히게 - 굵은 한 겹과 옅은 한 겹.
    private var still: some View {
        ZStack {
            shape.strokeBorder(color.opacity(0.25), lineWidth: 2).padding(-7)
            shape.strokeBorder(color, lineWidth: 3)
        }
    }
}

// MARK: - Type Visual Style
// `TypeVisualStyle` 과 타입별 규칙은 DesignSystem/MemoTypeStyle.swift 로 옮겼다.
// 앱 카드와 키보드 키가 같은 파일을 봐야 두 화면이 갈라지지 않는다.

// MARK: - DisplayItem

/// 메모 그리드 1셀. 같은 메모가 attached template으로 2셀로 expand될 때
/// useTemplate 값으로 구분. id는 (memoId, useTemplate) 합성으로 SwiftUI ForEach 충돌 방지.
struct DisplayItem: Identifiable {
    let memo: Memo
    let useTemplate: Bool
    var id: String { "\(memo.id.uuidString)-\(useTemplate ? "t" : "n")" }
}
