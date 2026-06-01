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

    @State private var image: UIImage? = nil

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

    @Environment(\.colorScheme) private var colorScheme
    private var theme: AppTheme { AppTheme.resolve(kind: .paper, isDark: colorScheme == .dark) }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: 헤더 — 항상 보임: [00][000][0000] + 입력 + 닫기
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
                                        .background(inactive ? Color.blue.opacity(0.05) : Color.blue.opacity(0.12))
                                        .foregroundColor(inactive ? Color.blue.opacity(0.35) : Color.blue)
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
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(state.allPlaceholdersFilled ? Color.blue : Color.gray.opacity(0.4))
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
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))

                Divider()

                // MARK: 컬러 프리뷰
                coloredPreviewText
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
                                Image(systemName: "questionmark.circle")
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
                                    placeholder: placeholder,
                                    selectedValue: Binding(
                                        get: { state.inputs[placeholder] ?? "" },
                                        set: { newValue in
                                            state.inputs[placeholder] = newValue
                                            state.updateAllPlaceholdersFilled()
                                            let hasNumeric = state.placeholders.contains { TemplateVariableProcessor.isNumericToken($0) }
                                            if state.allPlaceholdersFilled && !hasNumeric {
                                                completeInput()
                                            }
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

    private struct PreviewSegment {
        let text: String
        let isValue: Bool
    }

    private func parseSegments() -> [PreviewSegment] {
        let original = state.originalText
        var segments: [PreviewSegment] = []
        guard let regex = try? NSRegularExpression(pattern: "\\{([^}]+)\\}") else {
            return [PreviewSegment(text: original, isValue: false)]
        }
        var lastEnd = original.startIndex
        for match in regex.matches(in: original, range: NSRange(original.startIndex..., in: original)) {
            guard let range = Range(match.range, in: original) else { continue }
            if lastEnd < range.lowerBound {
                segments.append(PreviewSegment(text: String(original[lastEnd..<range.lowerBound]), isValue: false))
            }
            let key = String(original[range])
            let value = state.inputs[key] ?? ""
            segments.append(PreviewSegment(text: value.isEmpty ? key : value, isValue: !value.isEmpty))
            lastEnd = range.upperBound
        }
        if lastEnd < original.endIndex {
            segments.append(PreviewSegment(text: String(original[lastEnd...]), isValue: false))
        }
        return segments
    }

    private var coloredPreviewText: Text {
        let base: Text = state.baseMemoValue.isEmpty ? Text("") : Text(state.baseMemoValue + "\n")
        return parseSegments().reduce(base) { acc, seg in
            seg.isValue
                ? Text("\(acc)\(Text(seg.text).foregroundColor(Color(UIColor.systemGreen)).bold())")
                : Text("\(acc)\(Text(seg.text))")
        }
    }

    private func completeInput() {
        var userInfo: [String: Any] = [
            "text": state.originalText,
            "inputs": state.inputs
        ]
        if let baseId = state.baseMemoId { userInfo["baseMemoId"] = baseId }
        if let templateId = state.templateId { userInfo["memoId"] = templateId }
        NotificationCenter.default.post(
            name: NSNotification.Name("templateInputComplete"),
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
    let placeholder: String
    @Binding var selectedValue: String
    let templateId: UUID?

    @Environment(\.colorScheme) private var colorScheme
    private var theme: AppTheme { AppTheme.resolve(kind: .paper, isDark: colorScheme == .dark) }

    private var predefinedValues: [String] {
        let storedValues = PredefinedValuesStore.shared.getValuesForTemplate(placeholder: placeholder, templateId: templateId)
        return storedValues
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
                ForEach(["1","2","3","4","5","6","7","8","9"], id: \.self) { digit in
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
                                    .background(selectedValue == value ? Color.blue.opacity(0.2) : Color(UIColor.systemGray5))
                                    .foregroundColor(selectedValue == value ? .blue : .primary)
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
            Image(systemName: "delete.left")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(UIColor.systemGray4))
                .foregroundColor(.primary)
                .cornerRadius(theme.radiusXs)
        }
    }

    // MARK: - Text predefined (existing flow)

    @ViewBuilder
    private var textPredefinedSection: some View {
        if predefinedValues.isEmpty {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(NSLocalizedString("No saved values", comment: "Placeholder values empty title"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }

                Text(String(format: NSLocalizedString("Open the app to add values for '%@' in placeholder settings", comment: "Placeholder values empty hint"), placeholder.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(theme.radiusXs)
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
                                .background(selectedValue == value ? Color.blue : Color(UIColor.systemGray5))
                                .foregroundColor(selectedValue == value ? .white : .primary)
                                .cornerRadius(theme.radiusLg)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Type Visual Style (색맹 보조 — 색 + dash 패턴)

/// 메모 타입 시각 표현. 테두리 색 + dash 패턴 차이로 색약·색맹 사용자도
/// 패턴만으로 구분 가능.
struct TypeVisualStyle {
    let color: Color
    let lineWidth: CGFloat
    let dash: [CGFloat]
}

// MARK: - DisplayItem

/// 메모 그리드 1셀. 같은 메모가 attached template으로 2셀로 expand될 때
/// useTemplate 값으로 구분. id는 (memoId, useTemplate) 합성으로 SwiftUI ForEach 충돌 방지.
struct DisplayItem: Identifiable {
    let memo: Memo
    let useTemplate: Bool
    var id: String { "\(memo.id.uuidString)-\(useTemplate ? "t" : "n")" }
}

