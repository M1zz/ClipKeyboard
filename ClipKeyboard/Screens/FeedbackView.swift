//
//  FeedbackView.swift
//  ClipKeyboard
//
//  피드백 화면은 LeeoKit이 통째로 제공한다 - 여기는 앱 테마 주입용 얇은 래퍼만 남긴다.
//  실제 구현: LeeoKit/Sources/LeeoKit/Feedback/
//

import SwiftUI
import CloudKit
import LeeoKit

struct FeedbackView: View {
    @Environment(\.appTheme) private var theme
    /// 어디서 열었는가. 자동 첨부 정보에 한 줄로 실린다.
    var origin: FeedbackOrigin = .settings
    /// 처음 고를 유형. 템플릿 화면에서 열면 제안으로 시작한다.
    var initialType: LeeoFeedbackType? = nil
    /// 미리 고를 버그 분류.
    var initialCategory: LeeoBugCategory? = nil
    /// 자동 첨부 정보에 더할 줄들.
    var extraLines: [String] = []
    /// iCloud 를 쓸 수 없어 보내면 메일 앱이 열리는 상황인가.
    @State private var opensMail = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // 회신 정보(이름·이메일)는 선택 입력이다. 남기면 CloudKit 레코드와 메일 본문에 함께 실려
        // 답장할 곳이 생기고, 비워두면 예전처럼 익명 제출 그대로다.
        // 이메일이 없어도 답장은 설정 > 보낸 의견으로 닿는다(LeeoFeedbackReplies).
        //
        // ⚠️ 메일 길은 LeeoKit 내장 작성 창에 맡긴다. 예전 `emailFallback` 은 창을 띄우자마자 "보냄" 으로 처리해
        //    메일을 보내기 전에 완료 표시가 떴고, 붙인 사진도 빠졌다.
        LeeoFeedbackView<ClipKeyboardSpec>(initialType: initialType,
                                           showsContactFields: true,
                                           extraInfo: FeedbackContext.lines(origin: origin) + extraLines,
                                           categoryInfo: { await FeedbackContext.lines(for: $0) },
                                           initialCategory: initialCategory)
        .leeoStyle(theme.leeoStyle)
        .safeAreaInset(edge: .top, spacing: 0) {
            if opensMail { mailNotice }
        }
        // 설정에서 iCloud 에 로그인하고 돌아오면 안내가 사라지게 다시 본다.
        .task(id: scenePhase) {
            let container = await CloudKitContainer.resolve(ClipKeyboardSpec.feedback.containerIdentifier)
            let status = try? await container.accountStatus()
            opensMail = FeedbackContext.opensMail(iCloud: status)
        }
    }

    /// 왜 메일 앱이 열리는지 누르기 전에 말한다. 사용자: "메일 앱은 왜 열리는건지 어떤 상황인지 알려줘".
    private var mailNotice: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(NSLocalizedString("지금은 iCloud를 쓸 수 없어요", comment: "Feedback notice title: iCloud is not available, so feedback goes through Mail"))
                .font(.subheadline.weight(.semibold))
            Text(NSLocalizedString("보내기를 누르면 메일 앱이 열려요. 메일에서 한 번 더 보내야 전달돼요. iCloud에 로그인하면 앱에서 바로 보내져요.", comment: "Feedback notice body: why the Mail app opens when sending feedback, and how to avoid it"))
                .font(.caption)
                .foregroundColor(theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.bg)
        .accessibilityElement(children: .combine)
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
    /// 보내기가 메일 앱으로 넘어가는가. LeeoKit 은 iCloud 계정이 쓸 수 있는 상태가 아니면 메일로 넘긴다.
    /// 상태를 아직 모르면(nil) 묻지 않은 것이라 말하지 않는다.
    static func opensMail(iCloud status: CKAccountStatus?) -> Bool {
        guard let status else { return false }
        return status != .available
    }

    static func lines(origin: FeedbackOrigin,
                      plan: AccessTier = currentPlan,
                      keyboardEnabled: Bool? = KeyboardInstallState.enabledInSettingsIfKnown) -> [String] {
        var lines = [String(format: NSLocalizedString("보낸 곳: %@", comment: "Feedback auto info: origin"),
                            origin.localizedName)]
        var state = [planName(plan)]
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

    /// 이 사람이 가진 요금제. 설정의 요금제 칸과 같은 답을 낸다.
    ///
    /// ⚠️ 사용자 신고: "Pro 활성화인데 무료 키보드 켜짐". 예전 줄은 결제 키(`isPro`)만 봐서,
    ///    설정이 "Pro 활성화됨" 으로 보여 주는 예전 구매자도 무료로 적혔다.
    ///    무료 사용 기간과 체험은 가진 요금제가 아니므로 여기서 올리지 않는다(`accessLine` 이 따로 적는다).
    static var currentPlan: AccessTier {
        plan(purchased: ProFeatureManager.purchasedTier, grandfathered: ProFeatureManager.isGrandfathered)
    }

    static func plan(purchased: AccessTier, grandfathered: Bool) -> AccessTier {
        grandfathered ? max(purchased, .pro) : purchased
    }

    private static func planName(_ plan: AccessTier) -> String {
        switch plan {
        case .free:        return NSLocalizedString("무료", comment: "Feedback auto info: free plan")
        case .plus:        return "Plus"
        case .pro, .master: return "Pro"
        }
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
