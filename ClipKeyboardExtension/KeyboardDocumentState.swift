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
import LeeoKit
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
    /// 설정 > 키보드 레이아웃의 미리보기. **진짜 키보드와 똑같이 보여야 하는** 자리다.
    /// 앱 안에서 돌지만 누를 수 없고, 모양은 익스텐션을 따른다.
    case settingsPreview
}

// MARK: - 자리마다 다른 것 (한 곳에서만 정한다)

/// 세 자리가 **무엇이 다른가**를 여기 한 곳에 모은다.
///
/// ⚠️ **모양은 세 자리 모두 같다.** 진짜 키보드 · 키보드 탭(무대) · 설정 미리보기가 같은
///    위줄(카테고리 탭 · … 로 접힌 조작 키 서랍, 보내기도 서랍 안), 같은 카테고리 탭 조건, 같은 시스템 키보드 바탕으로 선다.
///    예전에는 모양도 자리마다 갈라 두었고(`hostKind == .inApp` 열 군데), 그래서 설정에서 켠
///    보내기가 실제 키보드에서는 … 뒤에 숨고, 키보드 탭은 실물과 다르게 생겼다.
///    모양을 가르고 싶어지면 먼저 그게 정말 실물과 달라야 하는 일인지 묻는다.
///
/// ⚠️ `KeyboardView` 안에서 `hostKind == .inApp` 을 직접 비교하지 않는다. 다른 것은
///    **하는 일**뿐이고, 그것도 아래 속성으로만 가른다. 새로 갈라야 할 것이 생기면 여기
///    속성을 하나 더하고, 세 자리의 값을 모두 적는다.
extension KeyboardHostKind {

    /// 메인 앱 프로세스 안에서 도는가. 클립보드가 늘 열려 있고, 입력창이 우리 것이다.
    var runsInsideApp: Bool { self != .keyboardExtension }

    /// 접은 조작 키를 **펼친 채로** 시작하는가. 설정 미리보기는 서랍을 열어 둔다 -
    /// 모양은 진짜 키보드 그대로이면서, 지금 켜고 끄는 키가 어디에 서는지 보여야 한다.
    var startsWithControlKeysExpanded: Bool { self == .settingsPreview }

    // MARK: 하는 일

    /// 붙여넣기 전에 전체 접근 권한을 확인해야 하는가(익스텐션만).
    var requiresFullAccessForPaste: Bool { !runsInsideApp }

    /// 길게 누르면 복사하는가(앱 안). 아니면 값을 크게 펼친다(익스텐션).
    var longPressCopies: Bool { runsInsideApp }

    /// 이미지 단축어를 누르면 입력창에 그림까지 넣어 보이는가(앱 안 - 입력창이 우리 것이다).
    var insertsImageIntoOwnField: Bool { runsInsideApp }

    /// 빈칸 채우기 창 아래를 앱의 탭바만큼 비우는가.
    var reservesTabBarSpace: Bool { runsInsideApp }

    /// 빈칸 채우기 창에 "이번에만 / 별로 저장" 안내와 버튼을 보이는가.
    var showsOneOffValueHint: Bool { runsInsideApp }

    /// 검색으로 헤매는지 재는가(진짜 키보드의 세션 기록이 있을 때만 뜻이 있다).
    var tracksSearchStruggle: Bool { !runsInsideApp }
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

// MARK: - 키보드 크래시 루프 가드

/// 키보드가 뜰 때마다 같은 자리에서 죽으면, 다음부터 단축어 판 없이 **최소 화면**으로 뜬다.
///
/// 왜: 5.1.5 에서 키보드가 켤 때마다 죽는 사고가 있었다(2026-09-26 문의). 앱에는
/// `LaunchGuard` 가 있었지만 키보드에는 아무것도 없어서, 사용자는 앱을 지우고 다시 깔 때까지
/// 키보드를 한 번도 못 썼다. 두 번 연달아 끝까지 못 뜨면 세이프 모드로 연다.
///
/// ⚠️ 키보드(쓰는 쪽)와 앱(허브로 보내는 쪽)이 **같은 이름 · 같은 App Group** 을 봐야 한다.
///    그래서 만드는 곳을 여기 하나로 둔다. 앱은 끝나지 못한 횟수를 `launch_incomplete:keyboard`
///    로 보낸다(`ClipKeyboardApp` 의 분석 단계). 릴리즈 건강 카드가 그 이벤트를 불안정 신호로 읽는다.
enum KeyboardCrashGuard {
    static func make() -> LeeoCrashLoopGuard {
        LeeoCrashLoopGuard(name: "keyboard", defaults: AppGroup.defaults ?? .standard)
    }
}
