//
//  KeyboardDocumentState.swift
//  ClipKeyboardExtension
//
//  호스트 텍스트 필드 상태 관찰 — KeyboardViewController가 textDidChange에서 업데이트하고
//  KeyboardView (SwiftUI)가 ObservedObject로 구독.
//
//  현재는 hasText만 노출 (X 버튼 표시/숨김 결정용).
//

import Foundation
import Combine

final class KeyboardDocumentState: ObservableObject {
    /// 호스트 텍스트 필드에 입력된 텍스트가 있는지.
    /// false면 KeyboardView의 X(clear all) 버튼 등 텍스트가 있어야 의미있는 UI를 숨김.
    @Published var hasText: Bool = false
}
