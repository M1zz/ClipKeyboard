//
//  FullAccessGuideView.swift
//  ClipKeyboard
//
//  키보드의 "전체 접근 허용" 을 켜는 법. 키보드의 안내 줄(`KeyboardView.fullAccessBanner`)과
//  키보드 설정의 한 줄이 여기로 온다(`clipkeyboard://fullaccess`).
//
//  ⚠️ 키보드 익스텐션이 낯선 사람이 많다. "전체 접근" 이라는 말만 던지면 무섭게 들리고,
//     어디서 켜는지도 모른다. 그래서 **무엇이 좋아지는지 → 무엇을 안 하는지 → 어디를 누르는지**
//     순서로 말한다.
//

import SwiftUI
import LeeoKit

struct FullAccessGuideView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    /// 키보드가 마지막으로 뜰 때 본 값. true 일 때만 믿는다(`DefaultsKey.keyboardFullAccessGranted`).
    private var isGranted: Bool {
        AppGroup.defaults?.bool(forKey: DefaultsKey.keyboardFullAccessGranted) ?? false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    benefits
                    privacyNote
                    steps
                }
                .padding(20)
            }
            .background(theme.bg.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { openSettingsButton }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    GlassCircleButton(AppSymbol.xmark, role: .secondary,
                                      label: NSLocalizedString("닫기", comment: "Close / dismiss")) {
                        dismiss()
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("전체 접근 허용 켜기", comment: "Full Access guide title"))
                .font(.title2.weight(.bold))
                .foregroundColor(theme.text)
                .accessibilityAddTraits(.isHeader)
            Text(isGranted
                 ? NSLocalizedString("지금 켜져 있어요. 키보드의 모든 기능을 쓸 수 있어요.", comment: "Full Access guide: already on")
                 : NSLocalizedString("단축어 넣기는 지금도 돼요. 켜면 아래 기능이 더 열려요.", comment: "Full Access guide: subtitle when off"))
                .font(.body)
                .foregroundColor(theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow(AppSymbol.handTap,
                       NSLocalizedString("키를 누를 때 진동", comment: "Full Access benefit: haptics"))
            benefitRow(AppSymbol.docOnClipboard,
                       NSLocalizedString("복사한 글을 키보드에서 바로 꺼내기", comment: "Full Access benefit: recent clipboard"))
            benefitRow(AppSymbol.docOnDoc,
                       NSLocalizedString("단축어를 길게 눌러 복사하기", comment: "Full Access benefit: copy memo"))
            benefitRow(AppSymbol.textCursor,
                       NSLocalizedString("템플릿의 클립보드 빈칸 채우기", comment: "Full Access benefit: clipboard placeholder"))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
    }

    private func benefitRow(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundColor(.accentColor)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .foregroundColor(theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 이름이 무섭게 들리는 만큼 **안 하는 것**을 분명히 말한다. 개인정보 처리방침과 같은 말이다.
    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: AppSymbol.lockShieldFill)
                .font(.body.weight(.semibold))
                .foregroundColor(theme.textMuted)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(NSLocalizedString("이름은 iOS가 정한 것이에요. 치는 글자와 단축어 내용은 어디로도 보내지 않고 이 기기에만 남아요.",
                                   comment: "Full Access guide: privacy reassurance"))
                .font(.footnote)
                .foregroundColor(theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("켜는 법", comment: "Keyboard banner: how to turn on Full Access"))
                .font(.headline)
                .foregroundColor(theme.text)
            stepRow(1, NSLocalizedString("아래 단추로 설정을 열어요", comment: "Full Access step 1"))
            stepRow(2, NSLocalizedString("'키보드'를 눌러요", comment: "Full Access step 2"))
            stepRow(3, NSLocalizedString("'전체 접근 허용'을 켜고 '허용'을 눌러요", comment: "Full Access step 3"))
        }
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.accentColor)
                .frame(width: 28, height: 28)
                .background(Circle().fill(theme.accentSoft))
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .foregroundColor(theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Action

    /// 이 앱의 설정 화면을 연다. 거기 '키보드' 줄 안에 전체 접근 스위치가 있다.
    private var openSettingsButton: some View {
        Button {
            HapticManager.shared.light()
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            Text(NSLocalizedString("설정 열기", comment: "Open Settings button"))
                .font(.headline)
                .foregroundStyle(Color.accentForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
        }
        .buttonStyle(.squish)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}
