//
//  KeyboardDocumentState.swift
//  ClipKeyboardExtension
//
//  호스트 텍스트 필드 상태 관찰 - KeyboardViewController가 textDidChange에서 업데이트하고
//  KeyboardView (SwiftUI)가 ObservedObject로 구독.
//
//  hasText · 리턴 키 종류 · 빈 칸에서 리턴을 잠글지를 노출한다.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

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

    /// 호스트가 리턴 키에 무엇을 기대하는가. 위챗 입력창이면 `.send`, 사파리 검색창이면 `.search`.
    ///
    /// 왜 들고 있나: 리턴 키의 **이름을 우리가 짓지 않기 위해서**다. 우리가 할 수 있는 일은
    /// 줄바꿈을 넣는 것뿐이라, 그것이 '보내기'가 될지 '검색'이 될지는 호스트가 정한다.
    /// 호스트가 말한 대로 적어야 그 글자를 찾던 사람이 그 글자를 본다.
    @Published var returnKeyType: UIReturnKeyType = .default

    /// 호스트가 **빈 칸에서는 리턴을 잠가 달라**고 했는가(`enablesReturnKeyAutomatically`).
    ///
    /// 검색창·보내기창이 이것을 켠다. 시스템 키보드가 빈 검색창에서 `검색` 을 흐리게
    /// 잠그는 근거가 바로 이 값이고, 우리도 같은 값을 보고 같이 잠근다.
    ///
    /// 왜 필요한가: 리턴 키를 글이 없어도 세우기로 하고 나니(같은 줄의 지우기·X 와 맞추려고),
    /// 빈 검색창에 강조색 `검색` 이 눌리게 서 있었다. 눌러도 줄바꿈 하나가 들어갈 뿐이라
    /// 아무 일도 일어나지 않는다. 이름이 있는 키는 그 이름의 일을 할 것처럼 보인다.
    @Published var returnNeedsText: Bool = false

    /// 지금 리턴 키를 눌러도 소용없는가. **판정은 여기 하나뿐이다.**
    ///
    /// 앱 안의 무대는 그 트레잇을 켜지 않으므로 늘 거짓이고, 거기서는 줄바꿈이 제 일을 한다.
    var returnKeyIsLocked: Bool { returnNeedsText && !hasText }

    /// 키보드가 새 텍스트 필드에 나타날 때마다 증가.
    /// TypingKeyboardView가 이 값이 바뀌면 hangulComposer/cheonjiinInput 상태를 초기화해
    /// 이전 필드의 조합 중 음절이 새 필드로 '딸려오는' 버그를 방지한다.
    @Published var composerResetToken: Int = 0
}
