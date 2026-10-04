//
//  AppInfoSettingsView.swift
//  ClipKeyboard
//
//  설정 > 함께 쓰면 좋은 앱
//

import SwiftUI
import LeeoKit

/// 함께 쓰면 좋은 앱 - 같은 사람이 만든 맥 앱과 다른 앱들.
///
/// ⚠️ 예전 이름은 "앱 정보" 였고 처리방침·약관·버전도 여기 있었다. 이름만 보고는 안에
///    다른 앱 소개가 있는 줄 아무도 몰랐다. 이름을 안에 든 것으로 바꾸고, 처리방침·약관·버전은
///    "사용법과 문의" 맨 아래로 옮겼다(`HelpSettingsView.legalSection`).
///    타입 이름은 그대로 둔다(프로젝트 파일과 두 타겟의 참조를 건드리지 않으려고).
struct AppInfoSettingsView: View {

    @Environment(\.appTheme) private var theme

    var body: some View {
        List {
            familySection
        }
        .settingsCategoryChrome(title: NSLocalizedString("함께 쓰면 좋은 앱", comment: "Settings section: other apps by the same developer that pair well with this one"))
    }

    // MARK: - 섹션

    /// 같은 사람이 만든 다른 것들.
    private var familySection: some View {
        Section {
            #if !targetEnvironment(macCatalyst)
            NavigationLink(destination: MacAppIntroView()) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: theme.radiusSm)
                            // 고른 키컬러를 따라간다 - 흑백을 고른 사람의 설정에서
                            // 이 타일만 혼자 주황으로 남으면 그것만 다른 앱에서 온 것처럼 보인다.
                            .fill(LinearGradient(colors: [theme.accent,
                                                          theme.accent.mixed(with: .black, amount: 0.7)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                        Image(systemName: AppSymbol.macbook)
                            .font(.body.weight(.semibold))
                            .foregroundColor(theme.accentFg)
                            .accessibilityHidden(true)
                    }
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("ClipKeyboard for Mac", comment: "Mac app intro title"))
                            .font(.body).fontWeight(.semibold)
                        Text(NSLocalizedString("Menu bar access · Global hotkey · iCloud sync", comment: "Mac promo subtitle"))
                            .font(.body).foregroundColor(theme.textMuted)
                    }
                }
                .padding(.vertical, 4)
            }
            #endif
            // 같은 사람이 만든 다른 앱. 목록·문구·이야기·아이콘은 LeeoKit 카탈로그 한 곳에 있어서
            // 앱을 새로 내도 여기 코드는 그대로다(LeeoFamilyCatalog).
            LeeoFamilySettingsRow<ClipKeyboardSpec>()
                .leeoStyle(theme.leeoStyle)
        }
    }
}
