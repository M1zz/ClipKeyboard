//
//  HighlightedTextEditor.swift
//  ClipKeyboard
//

import SwiftUI

// `{변수}` 규칙(패턴·칩 색·중괄호 감추기)은 DesignSystem/TemplatePlaceholder.swift 한 곳에 있다.
// 이 입력칸도 거기서 그린다 - 편집 중인 글과 카드·키보드에 보이는 글이 같아 보여야 한다.

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
        // 그대로 붙여넣을 원문(이메일·계좌·주소)을 담는 필드 - 첫 글자 자동 대문자가
        // "leeo@…"를 "Leeo@…"로 조용히 바꿔 저장하던 문제. 자동 수정도 원문을 훼손한다.
        tv.autocapitalizationType = .none
        tv.autocorrectionType = .no
        tv.textStorage.delegate = context.coordinator
        tv.attributedText = Self.highlight(text)
        tv.accessibilityLabel = NSLocalizedString("내용", comment: "Content section header")
        tv.accessibilityHint = NSLocalizedString("붙여넣을 내용을 입력하세요. 나중에 채울 자리는 빈칸 이름을 중괄호로 감싸서 만들어요. 예: 이름", comment: "Content input field hint")
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        let isPlaceholderVisible = context.coordinator.isShowingPlaceholder && text.isEmpty
        if !isPlaceholderVisible && uiView.text != text {
            let oldText = uiView.text ?? ""
            let savedSelection = uiView.selectedRange
            uiView.attributedText = Self.highlight(text)
            let newLength = (text as NSString).length
            if text.hasPrefix(oldText) && newLength > (oldText as NSString).length {
                // 변수/이모지 삽입처럼 끝에 덧붙은 경우 - 커서를 새 텍스트 끝으로 옮겨
                // 곧바로 이어서 입력할 수 있게 한다(이전엔 커서가 앞으로 튀던 문제).
                uiView.selectedRange = NSRange(location: newLength, length: 0)
            } else {
                // 그 외(하이라이트 갱신 등)는 기존 커서 위치를 범위 보정해 유지.
                let loc = min(savedSelection.location, newLength)
                let len = min(savedSelection.length, newLength - loc)
                uiView.selectedRange = NSRange(location: loc, length: len)
            }
        }
        if uiView.keyboardType != keyboardType {
            uiView.keyboardType = keyboardType
            uiView.reloadInputViews()
        }
        context.coordinator.syncFocus(uiView, desired: isFocused)
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

    /// `{이름}` 을 칩으로. 그리는 규칙은 `NSMutableAttributedString.applyTemplateChipHighlight`
    /// 한 곳에 있고, 여기서는 **어떤 색으로** 칠할지만 정한다.
    ///
    /// ⚠️ 색은 테마 토큰을 따르지 않고 시스템 강조색이다. 이 입력칸은 UIKit 뷰라
    ///    SwiftUI 환경(@Environment(\.appTheme))이 닿지 않는다. 앱 테마를 바꿔도
    ///    편집칸 칩만 파랗게 남는 것이 걸리면 테마를 프로퍼티로 받아 내려주면 된다.
    static func applyTemplateVariableHighlight(to storage: NSMutableAttributedString) {
        let body = UIFont.preferredFont(forTextStyle: .body)
        storage.applyTemplateChipHighlight(
            accent: .systemBlue,
            accentSoft: UIColor.systemBlue.withAlphaComponent(0.12),
            font: .systemFont(ofSize: body.pointSize, weight: .semibold)
        )
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

        /// 우리가 스스로 first responder 를 바꾸는 중인가.
        /// 그때 오는 델리게이트 호출은 사용자가 낸 것이 아니므로 바인딩에 되쓰지 않는다.
        private var isSyncingFocus = false

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
            // 우리가 옮긴 것이면 바인딩은 이미 그 값이다. 다시 쓰면 갱신만 한 번 더 돈다.
            if !isSyncingFocus, parent.isFocused != true { parent.isFocused = true }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if !isSyncingFocus, parent.isFocused != false { parent.isFocused = false }
            refreshPlaceholderIfNeeded(textView, placeholder: parent.placeholder)
        }

        // MARK: - 포커스 맞추기

        /// 바인딩이 말하는 상태로 first responder 를 맞춘다.
        ///
        /// ⚠️ **`updateUIView` 안에서 곧바로 부르지 않는다.** `becomeFirstResponder()` 는
        ///    그 자리에서 `textViewDidBeginEditing` 을 부르고, 거기서 `@Binding` 을 쓰면
        ///    **뷰를 갱신하는 도중에 상태를 바꾸는 일**이 된다. 게다가 UIKit 이 호스팅 뷰에
        ///    first responder 가 바뀌었다고 알리면 SwiftUI 는 뷰 그래프를 통째로 다시
        ///    계산하는데(`_UIHostingView._didChange(toFirstResponder:)` →
        ///    `ViewGraphRootValueUpdater.updateGraph()`), 그 갱신이 다시 `updateUIView` 로
        ///    들어오면 고리가 닫힌다. 5.0.4 워치독 종료 리포트에서 심볼로 확인된 스택이
        ///    정확히 그 모양이다. → `docs/postmortem/WATCHDOG_SHARE_VIDEO_5_0_4.md`
        ///
        /// 그래서 한 박자 미뤄 **갱신 밖에서** 바꾸고, 그때 오는 델리게이트가 바인딩에
        /// 되쓰지 않도록 표시를 세워 둔다.
        func syncFocus(_ textView: UITextView, desired: Bool) {
            guard !isSyncingFocus, desired != textView.isFirstResponder else { return }
            isSyncingFocus = true
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self else { return }
                defer { self.isSyncingFocus = false }
                guard let textView, desired != textView.isFirstResponder else { return }
                if desired {
                    textView.becomeFirstResponder()
                } else {
                    textView.resignFirstResponder()
                }
            }
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
