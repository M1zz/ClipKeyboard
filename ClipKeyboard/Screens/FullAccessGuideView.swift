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

// MARK: - 지금 켜져 있나

/// 전체 접근이 켜져 있는지 앱이 아는 만큼.
///
/// ⚠️ 앱은 이 값을 **직접 물을 수 없다.** iOS 가 알려 주는 곳은 키보드 익스텐션이 뜰 때
///    (`KeyboardViewController.viewWillAppear`) 하나뿐이고, 익스텐션이 그때 App Group 에 적는다.
///    그래서 설정에서 켜고 돌아와도 키보드가 한 번 뜨기 전까지는 지난 값(꺼짐)이 남는다.
///    예전에는 그 값을 그대로 "꺼짐" 으로 보여서, 방금 켠 사람에게 안 켜졌다고 말했다.
///
/// 그래서 셋으로 말한다.
///  · 켜짐: 키보드가 마지막으로 뜰 때 켜져 있었다
///  · 확인 중: 이 앱이 설정을 열어 준 뒤다. 켰을 수 있으니 꺼졌다고 단정하지 않는다
///  · 꺼짐: 그 밖
///
/// ⚠️ 키보드가 같은 기기의 다른 프로세스에서 값을 적으므로 `@AppStorage` 는 바뀐 것을 모른다.
///    보이는 동안 `watch()` 로 다시 읽는다.
@MainActor
final class FullAccessStatus: ObservableObject {
    static let shared = FullAccessStatus()

    enum State: Equatable {
        case on, checking, off
    }

    @Published private(set) var state: State = .off

    /// 설정을 열어 준 뒤 이만큼은 "확인 중" 으로 둔다. 그 안에 키보드를 안 띄웠으면 꺼진 것으로 돌아간다.
    static let checkingWindow: TimeInterval = 10 * 60

    private init() {
        refresh()
    }

    /// 키보드가 마지막으로 적은 값을 다시 읽는다. true 일 때만 믿는다(`DefaultsKey.keyboardFullAccessGranted`).
    func refresh(now: Date = Date()) {
        let granted = AppGroup.defaults?.bool(forKey: DefaultsKey.keyboardFullAccessGranted) ?? false
        let openedAt = UserDefaults.standard.double(forKey: DefaultsKey.fullAccessSettingsOpenedAt)
        let next = Self.state(granted: granted,
                              openedSettingsAt: openedAt > 0 ? Date(timeIntervalSince1970: openedAt) : nil,
                              now: now)
        guard next != state else { return }
        if state == .checking, next == .on {
            HapticManager.shared.success()
            print("✅ [FullAccessStatus.refresh] 전체 접근이 켜진 것을 확인")
        }
        state = next
    }

    /// 이 앱이 설정을 열어 준다. 돌아오면 "확인 중" 이다.
    func noteOpenedSettings(now: Date = Date()) {
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: DefaultsKey.fullAccessSettingsOpenedAt)
        refresh(now: now)
    }

    /// 보이는 동안 1초마다 다시 읽는다. `.task { await FullAccessStatus.shared.watch() }`
    func watch() async {
        while !Task.isCancelled {
            refresh()
            try? await Task.sleep(for: .seconds(1))
        }
    }

    /// 순수한 판정. 시험이 직접 부른다.
    nonisolated static func state(granted: Bool, openedSettingsAt: Date?, now: Date) -> State {
        if granted { return .on }
        if let openedSettingsAt, now.timeIntervalSince(openedSettingsAt) < checkingWindow { return .checking }
        return .off
    }

    /// 설정 줄 오른쪽에 붙이는 말.
    var label: String {
        switch state {
        case .on:       return NSLocalizedString("켜짐", comment: "Full Access status: on")
        case .checking: return NSLocalizedString("확인 중", comment: "Full Access status: just came back from Settings, not confirmed yet")
        case .off:      return NSLocalizedString("꺼짐", comment: "Full Access status: off")
        }
    }
}

// MARK: - 여기서 확인하기

/// 키보드를 한 번 띄워 전체 접근을 확인하는 칸. 이 칸에서 클립키보드가 뜨면 그 순간 키보드가 값을 적는다.
///
/// ⚠️ 칸에 친 글은 어디에도 쓰지 않는다. 키보드를 부르는 자리일 뿐이다.
struct FullAccessCheckField: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject private var status = FullAccessStatus.shared
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(status.state == .checking
                 ? NSLocalizedString("켜셨다면 키보드를 한 번 띄우면 바로 '켜짐'으로 바뀌어요. iOS가 키보드가 뜰 때만 알려 줘서요.",
                                     comment: "Full Access check: explain why status is still being checked")
                 : NSLocalizedString("이미 켰는데 꺼짐으로 보이면, 아래 칸에서 키보드를 한 번 띄워 보세요.",
                                     comment: "Full Access check: hint when status says off"))
                .font(.footnote)
                .foregroundColor(theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            TextField(NSLocalizedString("여기를 누르고 지구본으로 클립키보드 고르기",
                                        comment: "Full Access check field placeholder: tap here and switch to this keyboard with the globe key"),
                      text: $text)
                .focused($focused)
                .autocorrectionDisabled()
                .padding(12)
                .background(theme.surfaceAlt, in: RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
        }
        .onChange(of: status.state) { _, state in
            // 켜진 것을 봤으면 키보드를 내린다. 할 일이 끝났다.
            if state == .on { focused = false }
        }
    }
}

// MARK: - 안내

struct FullAccessGuideView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var status = FullAccessStatus.shared

    private var isGranted: Bool { status.state == .on }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    benefits
                    privacyNote
                    steps
                    if !isGranted { FullAccessCheckField() }
                }
                .padding(20)
            }
            .task { await status.watch() }
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
                .animation(.easeInOut(duration: 0.2), value: isGranted)
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
                // 돌아오면 "꺼짐" 이 아니라 "확인 중" 이다. 켜고 왔을 수 있다.
                status.noteOpenedSettings()
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
