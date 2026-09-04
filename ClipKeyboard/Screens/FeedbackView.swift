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

    var body: some View {
        // 회신 정보(이름·이메일)는 선택 입력이다. 남기면 CloudKit 레코드와 메일 본문에 함께 실려
        // 답장할 곳이 생기고, 비워두면 예전처럼 익명 제출 그대로다.
        LeeoFeedbackView<ClipKeyboardSpec>(showsContactFields: true, emailFallback: { subject, body in
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
