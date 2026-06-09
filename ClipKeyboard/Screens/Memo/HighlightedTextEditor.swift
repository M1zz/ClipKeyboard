//
//  HighlightedTextEditor.swift
//  ClipKeyboard
//

import SwiftUI

extension String {
    var strippingTemplateBraces: String {
        replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
    }
}

#if os(iOS)
/// `[Your Name]` 같은 더미 placeholder를 빨간색으로 syntax highlight하는 입력칸.
struct HighlightedTextEditor: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    @Binding var isFocused: Bool

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = .preferredFont(forTextStyle: .body)
        tv.backgroundColor = .clear
        tv.textContainerInset = .init(top: 12, left: 8, bottom: 12, right: 8)
        tv.isScrollEnabled = true
        tv.keyboardType = keyboardType
        tv.textStorage.delegate = context.coordinator
        tv.attributedText = Self.highlight(text)
        tv.accessibilityLabel = NSLocalizedString("내용", comment: "Content section header")
        tv.accessibilityHint = NSLocalizedString("붙여넣을 내용을 입력하세요. 나중에 채울 칸은 변수명을 중괄호로 감싸서 만들어요. 예: 이름", comment: "Content input field hint")
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        let isPlaceholderVisible = context.coordinator.isShowingPlaceholder && text.isEmpty
        if !isPlaceholderVisible && uiView.text != text {
            let savedSelection = uiView.selectedRange
            uiView.attributedText = Self.highlight(text)
            uiView.selectedRange = savedSelection
        }
        if uiView.keyboardType != keyboardType {
            uiView.keyboardType = keyboardType
            uiView.reloadInputViews()
        }
        if isFocused && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
        context.coordinator.refreshPlaceholderIfNeeded(uiView, placeholder: placeholder)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    static func highlight(_ raw: String) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: raw,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label
            ]
        )
        applyDummyPlaceholderHighlight(to: result)
        applyTemplateVariableHighlight(to: result)
        return result
    }

    /// `{이름}` 같은 템플릿 변수를 코드가 아니라 칩처럼 보이게 — 강조색 + 은은한 배경.
    /// 편집 가능한 입력칸이므로 중괄호는 텍스트에 남기되, `{`·`}` 글자만 투명색으로 처리해
    /// 화면에는 칩 배경 안에 변수명만 보이게 한다(4.3.0 스타일 — 중괄호 노출 X).
    static func applyTemplateVariableHighlight(to storage: NSMutableAttributedString) {
        let pattern = "\\{[^}]+\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        regex.enumerateMatches(in: storage.string, range: fullRange) { match, _, _ in
            guard let range = match?.range, range.length >= 2 else { return }
            // 토큰 전체에 칩 배경 + 강조색.
            storage.addAttributes([
                .foregroundColor: UIColor.systemBlue,
                .backgroundColor: UIColor.systemBlue.withAlphaComponent(0.12),
                .font: UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .semibold)
            ], range: range)
            // 여는/닫는 중괄호 글자만 투명 처리 — 배경(칩)은 유지되어 좌우 여백처럼 보인다.
            storage.addAttribute(.foregroundColor, value: UIColor.clear,
                                 range: NSRange(location: range.location, length: 1))
            storage.addAttribute(.foregroundColor, value: UIColor.clear,
                                 range: NSRange(location: range.location + range.length - 1, length: 1))
        }
    }

    static func applyDummyPlaceholderHighlight(to storage: NSMutableAttributedString) {
        let pattern = "\\[[^\\]]+\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        regex.enumerateMatches(in: storage.string, range: fullRange) { match, _, _ in
            guard let range = match?.range else { return }
            storage.addAttributes([
                .foregroundColor: UIColor.systemRed,
                .font: UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .semibold)
            ], range: range)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate, NSTextStorageDelegate {
        var parent: HighlightedTextEditor
        var isShowingPlaceholder = false

        init(_ parent: HighlightedTextEditor) {
            self.parent = parent
        }

        // MARK: - UITextViewDelegate

        func textViewDidChange(_ textView: UITextView) {
            if isShowingPlaceholder { return }
            parent.text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if isShowingPlaceholder {
                textView.attributedText = HighlightedTextEditor.highlight("")
                isShowingPlaceholder = false
            }
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
            refreshPlaceholderIfNeeded(textView, placeholder: parent.placeholder)
        }

        // MARK: - NSTextStorageDelegate

        func textStorage(_ textStorage: NSTextStorage,
                         willProcessEditing editedMask: NSTextStorage.EditActions,
                         range editedRange: NSRange,
                         changeInLength delta: Int) {
            guard editedMask.contains(.editedCharacters), !isShowingPlaceholder else { return }
            let fullRange = NSRange(location: 0, length: textStorage.length)
            textStorage.removeAttribute(.foregroundColor, range: fullRange)
            textStorage.removeAttribute(.backgroundColor, range: fullRange)
            textStorage.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
            HighlightedTextEditor.applyDummyPlaceholderHighlight(to: textStorage)
            HighlightedTextEditor.applyTemplateVariableHighlight(to: textStorage)
        }

        // MARK: - Placeholder

        func refreshPlaceholderIfNeeded(_ textView: UITextView, placeholder: String) {
            let isEmpty = (parent.text.isEmpty)
            let isFocused = textView.isFirstResponder
            if isEmpty && !isFocused && !placeholder.isEmpty {
                textView.attributedText = NSAttributedString(
                    string: placeholder,
                    attributes: [
                        .font: UIFont.preferredFont(forTextStyle: .body),
                        .foregroundColor: UIColor.placeholderText
                    ]
                )
                isShowingPlaceholder = true
            } else if isShowingPlaceholder {
                textView.attributedText = HighlightedTextEditor.highlight(parent.text)
                isShowingPlaceholder = false
            }
        }
    }
}
#endif
