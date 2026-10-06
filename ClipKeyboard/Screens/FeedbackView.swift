//
//  FeedbackView.swift
//  ClipKeyboard
//
//  피드백 화면은 LeeoKit이 통째로 제공한다 - 여기는 앱 테마 주입용 얇은 래퍼만 남긴다.
//  실제 구현: LeeoKit/Sources/LeeoKit/Feedback/
//

import SwiftUI
import LeeoKit

struct FeedbackView: View {
    @Environment(\.appTheme) private var theme
    /// 어디서 열었는가. 자동 첨부 정보에 한 줄로 실린다.
    var origin: FeedbackOrigin = .settings
    /// 처음 고를 유형. 템플릿 화면에서 열면 제안으로 시작한다.
    var initialType: LeeoFeedbackType? = nil

    var body: some View {
        // 회신 정보(이름·이메일)는 선택 입력이다. 남기면 CloudKit 레코드와 메일 본문에 함께 실려
        // 답장할 곳이 생기고, 비워두면 예전처럼 익명 제출 그대로다.
        // 이메일이 없어도 답장은 설정 > 보낸 의견으로 닿는다(LeeoFeedbackReplies).
        LeeoFeedbackView<ClipKeyboardSpec>(initialType: initialType,
                                           showsContactFields: true,
                                           extraInfo: FeedbackContext.lines(origin: origin),
                                           emailFallback: { subject, body in
            #if os(iOS)
            if EmailController.canSendMail {
                EmailController.shared.sendEmail(subject: subject, body: body, to: Constants.developerEmail)
                return true
            }
            #endif
            return false
        })
        .leeoStyle(theme.leeoStyle)
    }
}

// MARK: - 어디서 왔는가

/// 의견 창을 연 자리. 받는 쪽은 이것으로 "어느 화면 얘기인지" 를 묻지 않고 안다.
///
/// ⚠️ rawValue 는 URL(`clipkeyboard://feedback?from=`)에 실린다. 키보드가 보내는 값이라 바꾸지 않는다.
enum FeedbackOrigin: String {
    case settings
    case nudge
    /// 앱의 템플릿 채우기 창.
    case templateFill = "template-fill"
    /// 키보드의 템플릿 빈칸 화면.
    case keyboardTemplate = "keyboard-template"

    var localizedName: String {
        switch self {
        case .settings:
            return NSLocalizedString("설정", comment: "Feedback origin: settings")
        case .nudge:
            return NSLocalizedString("의견 묻는 알림", comment: "Feedback origin: nudge alert")
        case .templateFill:
            return NSLocalizedString("템플릿 채우기", comment: "Feedback origin: template fill sheet")
        case .keyboardTemplate:
            return NSLocalizedString("키보드의 템플릿 빈칸", comment: "Feedback origin: keyboard template blanks")
        }
    }

    /// 템플릿 화면에서 왔으면 대개 "이렇게 바뀌면 좋겠다" 다.
    var suggestedType: LeeoFeedbackType? {
        switch self {
        case .templateFill, .keyboardTemplate: return .feature
        case .settings, .nudge: return nil
        }
    }
}

/// 자동 첨부 정보에 덧붙일 줄들. 의견 창에서 보내기 전에 사용자에게 그대로 보인다.
///
/// ⚠️ **사용자가 적은 내용은 넣지 않는다.** 단축어 본문, 빈칸 값, 카테고리 이름 같은 것.
///    묻지 않고 붙는 정보라서, 상태(켜짐·꺼짐·Pro)와 자리만 싣는다.
enum FeedbackContext {
    static func lines(origin: FeedbackOrigin,
                      isPro: Bool = ProFeatureManager.isPro,
                      keyboardEnabled: Bool? = KeyboardInstallState.enabledInSettingsIfKnown) -> [String] {
        var lines = [String(format: NSLocalizedString("보낸 곳: %@", comment: "Feedback auto info: origin"),
                            origin.localizedName)]
        var state = [isPro ? "Pro" : NSLocalizedString("무료", comment: "Feedback auto info: free plan")]
        switch keyboardEnabled {
        case .some(true):
            state.append(NSLocalizedString("키보드 켜짐", comment: "Feedback auto info: keyboard enabled"))
        case .some(false):
            state.append(NSLocalizedString("키보드 꺼짐", comment: "Feedback auto info: keyboard not enabled"))
        case .none:
            break
        }
        lines.append(state.joined(separator: " · "))
        return lines
    }
}

struct FeedbackInboxView: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        LeeoFeedbackInboxView<ClipKeyboardSpec>()
            .solidNavBar(theme.bg)
            .leeoStyle(theme.leeoStyle)
    }
}

extension AppTheme {
    /// LeeoKit 컴포넌트에 앱 테마 룩을 그대로 입히는 매핑.
    var leeoStyle: LeeoStyle {
        LeeoStyle(
            accent: accent,
            bg: bg,
            surface: surface,
            surfaceAlt: surfaceAlt,
            text: text,
            textMuted: textMuted,
            textFaint: textFaint,
            radiusSm: radiusSm,
            radiusLg: radiusLg
        )
    }
}
