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

