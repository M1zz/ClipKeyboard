//
//  KeyboardDocumentState.swift
//  ClipKeyboardExtension
//
//  호스트 텍스트 필드 상태 관찰 - KeyboardViewController가 textDidChange에서 업데이트하고
//  KeyboardView (SwiftUI)가 ObservedObject로 구독.
//
//  현재는 hasText만 노출 (X 버튼 표시/숨김 결정용).
//

import Foundation
import Combine

/// 이 키보드를 **누가 띄우고 있는가.**
///
/// 같은 `KeyboardView`가 두 곳에서 산다 - 진짜 키보드 익스텐션(메시지 앱 위)과
/// 메인 앱 안의 무대(`InAppKeyboardStage`). 둘은 할 수 있는 일이 다르다:
/// 앱 안에서는 클립보드가 항상 열려 있어 **복사 버튼**을 보여줄 수 있고,
/// 지구본(다음 키보드)은 아무 의미가 없다.
///
/// ⚠️ 기본값은 `.keyboardExtension` - 이 타입이 생기기 전 동작 그대로다.
///    익스텐션 쪽 호출부는 한 줄도 바뀌지 않는다.
enum KeyboardHostKind {
    /// 진짜 키보드 익스텐션. 호스트 앱의 텍스트 필드에 넣는다.
    case keyboardExtension
    /// 메인 앱 안의 미리보기 무대. 앱이 소유한 입력창에 넣는다.
    case inApp
}

final class KeyboardDocumentState: ObservableObject {
    /// 호스트 텍스트 필드에 입력된 텍스트가 있는지.
    /// false면 KeyboardView의 X(clear all) 버튼 등 텍스트가 있어야 의미있는 UI를 숨김.
    @Published var hasText: Bool = false

    /// 키보드가 새 텍스트 필드에 나타날 때마다 증가.
    /// TypingKeyboardView가 이 값이 바뀌면 hangulComposer/cheonjiinInput 상태를 초기화해
    /// 이전 필드의 조합 중 음절이 새 필드로 '딸려오는' 버그를 방지한다.
    @Published var composerResetToken: Int = 0
}
