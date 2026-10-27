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
    /// 미리 고를 버그 분류. 선물 화면에서 열면 결제로 시작한다.
    var initialCategory: LeeoBugCategory? = nil
    /// 자동 첨부 정보에 더할 줄들(선물의 결제 번호 · 코드 같은 것, `LeeoGiftStore.supportLines`).
    var extraLines: [String] = []

    var body: some View {
        // 회신 정보(이름·이메일)는 선택 입력이다. 남기면 CloudKit 레코드와 메일 본문에 함께 실려
        // 답장할 곳이 생기고, 비워두면 예전처럼 익명 제출 그대로다.
        // 이메일이 없어도 답장은 설정 > 보낸 의견으로 닿는다(LeeoFeedbackReplies).
        LeeoFeedbackView<ClipKeyboardSpec>(initialType: initialType,
                                           showsContactFields: true,
                                           extraInfo: FeedbackContext.lines(origin: origin) + extraLines,
                                           categoryInfo: { await FeedbackContext.lines(for: $0) },
                                           initialCategory: initialCategory,
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
    /// Pro 선물하기 · 선물 코드 입력 화면의 "선물이 잘 안 되나요?".
    case gift

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
        case .gift:
            return NSLocalizedString("선물하기", comment: "Feedback origin: gift screens")
        }
    }

    /// 템플릿 화면에서 왔으면 대개 "이렇게 바뀌면 좋겠다" 다.
    var suggestedType: LeeoFeedbackType? {
        switch self {
        case .templateFill, .keyboardTemplate: return .feature
        case .gift: return .bug
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

    /// 버그 분류를 고르면 덧붙이는 줄. LeeoKit 이 모르는 **이 앱의 권한 길**을 싣는다.
    ///
    /// ⚠️ 결제 분류에서 이 줄이 없으면 "결제는 없는데 Pro 였다" 를 가릴 수 없다. Apple 은 결제만
    ///    돌려주고, 체험 · 예전 무료 혜택 · 무료 사용 횟수는 이 기기에만 있다(2026-10 태국어 문의:
    ///    재설치 뒤 Pro 소실, 복원은 "없음"). 읽는 법: LeeoKit `docs/BUG_CATEGORIES.md` 3번.
    ///
    /// 개발자가 읽는 줄이라 번역하지 않는다(LeeoKit 진단 줄과 같은 꼴).
    static func lines(for category: LeeoBugCategory) async -> [String] {
        switch category {
        case .purchase, .dataLoss:
            return await MainActor.run { [accessLine()] }
        case .sync:
            return await MainActor.run {
                [accessLine(), "[sync] available=\(ProFeatureManager.isSyncAvailable) twoDevice=\(TwoDevicePack.isPurchased)"]
            }
        case .widget:
            let keyboard = KeyboardInstallState.enabledInSettingsIfKnown.map { $0 ? "on" : "off" } ?? "unknown"
            return ["[keyboard] enabled=\(keyboard)"]
        case .crash, .slow, .notification, .display, .other:
            return []
        }
    }

    /// 지금 열려 있는 권한이 **어느 길로** 열렸는가. 결제 · 영수증 날짜 · 체험 · 무료 사용 · 기기에만 있던 혜택.
    @MainActor
    static func accessLine() -> String {
        let revokedAt = AppGroup.defaults?.double(forKey: ProFeatureManager.existingFreeUserRevokedAtKey) ?? 0
        let parts = [
            "paid=\(ProFeatureManager.isPro)",
            "grandfathered=\(ProFeatureManager.hasGrandfatheredPurchase)",
            "deviceOnlyFree=\(ProFeatureManager.wasExistingFreeUser)",
            "deviceOnlyFreeRevoked=\(revokedAt > 0)",
            "trial=\(ProFeatureManager.isInTrial ? "\(ProFeatureManager.trialDaysRemaining)d" : (ProFeatureManager.hasStartedTrial ? "used" : "never"))",
            "freeUse=\(FreeUse.uses)/\(FreeUse.threshold)",
            "slots=\(SlotPack.ownedPacks)",
            "testFlight=\(ProFeatureManager.isTestFlight)"
        ]
        return "[access] " + parts.joined(separator: " ")
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

/// LeeoKit 화면에 지금 앱 테마를 입힌다. 시트처럼 `theme` 을 손에 쥐지 않은 자리에서 쓴다.
private struct LeeoThemed: ViewModifier {
    @Environment(\.appTheme) private var theme
    func body(content: Content) -> some View { content.leeoStyle(theme.leeoStyle) }
}

extension View {
    func leeoThemed() -> some View { modifier(LeeoThemed()) }
}
