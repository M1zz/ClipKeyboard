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
        tv.accessibilityHint = NSLocalizedString("붙여넣을 내용을 입력하세요. {변수명} 형식으로 템플릿 변수를 추가할 수 있습니다.", comment: "Content input field hint")
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
        return result
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
            textStorage.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
            HighlightedTextEditor.applyDummyPlaceholderHighlight(to: textStorage)
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
