//
//  AccessibilityGuideView.swift
//  ClipKeyboard
//
//  ClipKeyboard가 지원하는 손쉬운 사용 기능 안내.
//  VoiceOver 감지 시 자동 표시, 설정에서도 언제든 진입 가능.
//

import SwiftUI

struct AccessibilityGuideView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    ForEach(features) { feature in
                        FeatureCard(feature: feature)
                    }
                    testingSection
                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("손쉬운 사용", comment: "Accessibility guide navigation title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("확인", comment: "Dismiss accessibility guide")) {
                        dismiss()
                    }
                }
            }
            .solidNavBar(theme.bg)
            #endif
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("ClipKeyboard는 모든 사용자를 위해 설계됐습니다", comment: "Accessibility guide hero title"))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(theme.text)
            Text(NSLocalizedString("시각·운동·청각 보조 기능을 함께 지원합니다. 아래 기능들은 iPhone 설정 → 손쉬운 사용에서 켤 수 있습니다.", comment: "Accessibility guide hero description"))
                .font(.body)
                .foregroundColor(theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Features Data

    private var features: [A11yFeature] {[
        A11yFeature(
            icon: "figure.walk.circle.fill",
            iconColor: .blue,
            title: NSLocalizedString("VoiceOver", comment: "Feature: VoiceOver"),
            body: NSLocalizedString(
                "메모 목록에서 한 번 탭하면 카테고리·제목·내용을 읽어줍니다. 이중 탭하면 클립보드에 복사됩니다.\n\n위아래로 쓸어 넘기면 '즐겨찾기 추가', '삭제' 같은 추가 액션을 선택할 수 있습니다.",
                comment: "VoiceOver feature description"
            ),
            tip: NSLocalizedString("설정 → 손쉬운 사용 → VoiceOver", comment: "VoiceOver settings path")
        ),
        A11yFeature(
            icon: "mic.fill",
            iconColor: .purple,
            title: NSLocalizedString("음성 명령", comment: "Feature: Voice Control"),
            body: NSLocalizedString(
                "'탭 메모 검색'처럼 화면에 보이는 이름을 그대로 말해 조작합니다. 모든 버튼과 입력 필드에 읽기 가능한 이름이 지정되어 있습니다.",
                comment: "Voice Control feature description"
            ),
            tip: NSLocalizedString("설정 → 손쉬운 사용 → 음성 명령", comment: "Voice Control settings path")
        ),
        A11yFeature(
            icon: "textformat.size",
            iconColor: .orange,
            title: NSLocalizedString("더 큰 텍스트", comment: "Feature: Larger Text"),
            body: NSLocalizedString(
                "시스템 텍스트 크기를 키우면 메모 제목·내용 미리보기·배지가 함께 커집니다. 앱 내 글꼴 크기 슬라이더로 키보드만 별도 조정도 가능합니다.",
                comment: "Larger Text feature description"
            ),
            tip: NSLocalizedString("설정 → 디스플레이 및 밝기 → 텍스트 크기", comment: "Larger Text settings path")
        ),
        A11yFeature(
            icon: "moon.fill",
            iconColor: Color(hue: 0.7, saturation: 0.6, brightness: 0.7),
            title: NSLocalizedString("다크 모드", comment: "Feature: Dark Mode"),
            body: NSLocalizedString(
                "Dusk·Paper 두 테마 모두 다크 모드를 완전히 지원합니다. 시스템 설정을 따르거나 앱 내에서 직접 선택할 수 있습니다.",
                comment: "Dark Mode feature description"
            ),
            tip: NSLocalizedString("설정 → 디스플레이 및 밝기 → 다크", comment: "Dark Mode settings path")
        ),
        A11yFeature(
            icon: "eye.fill",
            iconColor: .green,
            title: NSLocalizedString("색상 없이 구별", comment: "Feature: Differentiate Without Color"),
            body: NSLocalizedString(
                "이 설정을 켜면 '메모 구분 표시'가 자동으로 켜져, 색에만 의존하지 않도록 메모 타입(템플릿·콤보·보안) 아이콘·테두리와 즐겨찾기·카테고리 심볼이 표시됩니다. 앱 설정 → 디스플레이 → 메모 표시에서 직접 켤 수도 있어요.",
                comment: "Differentiate Without Color feature description"
            ),
            tip: NSLocalizedString("설정 → 손쉬운 사용 → 디스플레이 및 텍스트 크기 → 색상 없이 구별", comment: "Differentiate Without Color settings path")
        ),
        A11yFeature(
            icon: "wand.and.stars",
            iconColor: .pink,
            title: NSLocalizedString("동작 줄이기", comment: "Feature: Reduce Motion"),
            body: NSLocalizedString(
                "즐겨찾기 추가 시 나타나는 하트 애니메이션이 '동작 줄이기' 설정을 자동으로 따릅니다. 켜져 있으면 이동·스케일 없이 페이드만 사용합니다.",
                comment: "Reduce Motion feature description"
            ),
            tip: NSLocalizedString("설정 → 손쉬운 사용 → 동작 → 동작 줄이기", comment: "Reduce Motion settings path")
        )
    ]}

    // MARK: - Testing Section

    private var testingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                NSLocalizedString("테스트 방법", comment: "Accessibility testing section header"),
                systemImage: AppSymbol.checkmarkShieldFill
            )
            .font(.headline)
            .foregroundColor(theme.text)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(testSteps, id: \.self) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: AppSymbol.chevronRightCircleFill)
                            .font(.body)
                            .foregroundColor(theme.accent)
                            .padding(.top, 2)
                            .accessibilityHidden(true)
                        Text(step)
                            .font(.body)
                            .foregroundColor(theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .background(theme.surfaceAlt)
        .cornerRadius(theme.radiusMd)
    }

    private var testSteps: [String] {[
        NSLocalizedString(
            "VoiceOver: 메모 행에서 한 번 탭 → 읽기 확인. 이중 탭 → '복사됨' 알림 확인.",
            comment: "Test step: VoiceOver"
        ),
        NSLocalizedString(
            "음성 명령: '탭 메모 검색' 또는 '확인 탭' 말하기 → 반응 확인.",
            comment: "Test step: Voice Control"
        ),
        NSLocalizedString(
            "더 큰 텍스트: 설정에서 텍스트 크기 최대로 → 앱 메모 목록에서 텍스트 크기 확인.",
            comment: "Test step: Larger Text"
        ),
        NSLocalizedString(
            "다크 모드: 제어 센터에서 다크 모드 전환 → 배경·텍스트 색상 변경 확인.",
            comment: "Test step: Dark Mode"
        ),
        NSLocalizedString(
            "색상 필터: 설정 → 손쉬운 사용 → 색상 필터(적록색맹) 후 배지 구분 확인.",
            comment: "Test step: Color filters"
        ),
        NSLocalizedString(
            "동작 줄이기: 설정 ON 후 즐겨찾기 추가 → 하트가 이동 없이 페이드 확인.",
            comment: "Test step: Reduce Motion"
        )
    ]}
}

// MARK: - Feature Card

private struct A11yFeature: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let body: String
    let tip: String
}

private struct FeatureCard: View {
    let feature: A11yFeature
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: feature.icon)
                    .font(.title3)
                    .foregroundColor(feature.iconColor)
                    .frame(width: 36, height: 36)
                    .background(feature.iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm, style: .continuous))
                    .accessibilityHidden(true)
                Text(feature.title)
                    .font(.headline)
                    .foregroundColor(theme.text)
            }
            Text(feature.body)
                .font(.body)
                .foregroundColor(theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Image(systemName: AppSymbol.gear)
                    .font(.caption2)
                    .foregroundColor(theme.textFaint)
                    .accessibilityHidden(true)
                Text(feature.tip)
                    .font(.body)
                    .foregroundColor(theme.textFaint)
            }
        }
        .padding(16)
        .background(theme.surface)
        .cornerRadius(theme.radiusMd)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(feature.title). \(feature.body). \(NSLocalizedString("설정 경로", comment: "")): \(feature.tip)")
    }
}

#if DEBUG
#Preview {
    AccessibilityGuideView()
}
#endif
