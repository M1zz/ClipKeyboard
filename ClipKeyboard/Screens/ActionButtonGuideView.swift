//
//  ActionButtonGuideView.swift
//  ClipKeyboard
//
//  "버튼 한 번으로 담기" 를 거는 법. 설정 ▸ 키보드에서 온다.
//
//  복사하고 동작 버튼(아이폰 왼쪽 위)을 누르면 방금 복사한 글이 키보드 '최근'에 담긴다
//  (`CaptureClipboardIntent` → `ClipboardCapture`). 버튼에 거는 일은 iOS 설정에서 사람이 해야 해서
//  앱이 할 수 있는 것은 **어디를 누르는지 말하는 것**뿐이다.
//
//  ⚠️ 동작 버튼이 없는 기종(아이폰 15 Pro 이전)이 많다. 그 사람에게는 제어 센터를 먼저 말한다.
//

import SwiftUI
import LeeoKit

// MARK: - 동작 버튼이 있는 기종인가

enum ActionButtonSupport {

    /// 이 기기에 동작 버튼이 있는가.
    static var isAvailable: Bool { hasActionButton(model: modelIdentifier) }

    /// 기종 식별자(`iPhone16,1` 같은 것)로 가린다. **순수 함수**라 시험으로 고정한다.
    ///
    /// 동작 버튼은 iPhone 15 Pro · 15 Pro Max(`iPhone16,1` · `iPhone16,2`)에서 처음 나왔고
    /// 그 뒤 나온 아이폰(`iPhone17,*` 부터)에는 모두 있다. 15 · 15 Plus(`iPhone15,4` · `15,5`)에는 없다.
    static func hasActionButton(model: String) -> Bool {
        guard model.hasPrefix("iPhone") else { return false }
        let parts = model.dropFirst("iPhone".count).split(separator: ",")
        guard parts.count == 2, let major = Int(parts[0]), let minor = Int(parts[1]) else { return false }
        if major >= 17 { return true }
        return major == 16 && (minor == 1 || minor == 2)
    }

    private static var modelIdentifier: String {
        #if targetEnvironment(simulator)
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        #endif
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}

// MARK: - 화면

struct ActionButtonGuideView: View {
    @Environment(\.appTheme) private var theme

    @State private var showFullAccessGuide = false
    /// '지금 해 보기' 의 결과. 화면 아래에 한 줄로 말한다.
    @State private var tryResult: ClipboardCapture.Outcome?

    private let hasActionButton = ActionButtonSupport.isAvailable

    /// 키보드가 마지막으로 뜰 때 본 값(`FullAccessGuideView` 와 같다).
    private var fullAccessGranted: Bool {
        AppGroup.defaults?.bool(forKey: DefaultsKey.keyboardFullAccessGranted) ?? false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                flow
                if hasActionButton {
                    actionButtonSteps
                    controlCenterSteps
                } else {
                    controlCenterSteps
                    actionButtonSteps
                }
                tips
            }
            .padding(20)
        }
        .background(theme.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { tryNowButton }
        .navigationTitle(NSLocalizedString("버튼 한 번으로 담기", comment: "Action Button capture guide title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFullAccessGuide) { FullAccessGuideView() }
    }

    // MARK: - 머리말

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("복사하고, 버튼만 누르세요", comment: "Action Button guide headline"))
                .font(.title2.weight(.bold))
                .foregroundColor(theme.text)
                .accessibilityAddTraits(.isHeader)
            Text(String(format: NSLocalizedString("방금 복사한 글이 키보드 '최근'에 바로 담겨요. 저장할지 묻지 않고, 담긴 글은 %d일 뒤 저절로 지워져요.",
                                                  comment: "Action Button guide subtitle. %d is the number of days temporary clipboard items are kept"),
                        SmartClipboardHistory.retentionDays))
                .font(.body)
                .foregroundColor(theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 복사 → 버튼 → 키보드. 무엇이 일어나는지를 글보다 먼저 그림으로.
    private var flow: some View {
        HStack(spacing: 6) {
            flowTile(AppSymbol.docOnDoc, NSLocalizedString("복사", comment: "Action Button guide flow: copy"))
            flowArrow
            flowTile(hasActionButton ? AppSymbol.buttonProgrammable : AppSymbol.switch2,
                     NSLocalizedString("버튼", comment: "Action Button guide flow: press the button"))
            flowArrow
            flowTile(AppSymbol.keyboard, NSLocalizedString("키보드에서 꺼내기", comment: "Action Button guide flow: use it from the keyboard"))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(NSLocalizedString("복사하고 버튼을 누르면 키보드에서 꺼내 쓸 수 있어요",
                                              comment: "Action Button guide flow, VoiceOver"))
    }

    private func flowTile(_ symbol: String, _ title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundColor(.accentColor)
                .frame(height: 30)
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 92)
        .padding(.horizontal, 6)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
    }

    private var flowArrow: some View {
        Image(systemName: AppSymbol.chevronForward)
            .font(.footnote.weight(.bold))
            .foregroundColor(theme.textMuted)
    }

    // MARK: - 거는 법

    private var actionButtonSteps: some View {
        stepGroup(
            title: NSLocalizedString("동작 버튼에 걸기", comment: "Action Button guide: section title for Action Button setup"),
            note: hasActionButton ? nil : NSLocalizedString("iPhone 15 Pro 이후 모델의 왼쪽 위 버튼이에요.",
                                                            comment: "Action Button guide: which iPhones have the Action Button"),
            steps: [
                NSLocalizedString("설정 앱에서 '동작 버튼'을 열어요", comment: "Action Button setup step 1"),
                NSLocalizedString("옆으로 넘겨 '제어 항목'에 두고, '제어 항목 선택'을 눌러요", comment: "Action Button setup step 2: swipe to Controls and tap Choose a Control"),
                NSLocalizedString("'클립보드 담기'를 찾아 골라요", comment: "Action Button / Control Center setup: pick the Capture Clipboard control")
            ])
    }

    private var controlCenterSteps: some View {
        stepGroup(
            title: hasActionButton
                ? NSLocalizedString("제어 센터에 두어도 돼요", comment: "Action Button guide: Control Center setup as an alternative")
                : NSLocalizedString("제어 센터에 두기", comment: "Action Button guide: Control Center setup as the main way"),
            note: nil,
            steps: [
                NSLocalizedString("화면 오른쪽 위에서 쓸어내려 제어 센터를 열어요", comment: "Control Center setup step 1"),
                NSLocalizedString("빈 곳을 길게 누르고 '제어 항목 추가'를 눌러요", comment: "Control Center setup step 2"),
                NSLocalizedString("'클립보드 담기'를 찾아 골라요", comment: "Action Button / Control Center setup: pick the Capture Clipboard control")
            ])
    }

    private func stepGroup(title: String, note: String?, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(theme.text)
                .accessibilityAddTraits(.isHeader)
            if let note {
                Text(note)
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
            }
            ForEach(Array(steps.enumerated()), id: \.offset) { index, text in
                stepRow(index + 1, text)
            }
        }
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(number, format: .number)
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

    // MARK: - 막힐 때

    /// 처음 써 볼 때 걸리는 두 곳. 붙여넣기 팝업과, 키보드가 '최근'을 못 보는 경우.
    private var tips: some View {
        VStack(alignment: .leading, spacing: 0) {
            FoldLink(destination: CopyPasteView()) {
                tipLabel(AppSymbol.docOnClipboard,
                         NSLocalizedString("누를 때마다 '붙여넣기 허용?'이 떠요", comment: "Action Button guide tip: paste permission prompt every time"))
            }
            .padding(.vertical, 12)
            if !fullAccessGranted {
                Divider()
                Button {
                    HapticManager.shared.light()
                    showFullAccessGuide = true
                } label: {
                    tipLabel(AppSymbol.lockShieldFill,
                             NSLocalizedString("키보드에서 '최근'을 보려면 전체 접근 허용을 켜 주세요", comment: "Action Button guide tip: Full Access is needed to see Recent in the keyboard"))
                }
                .buttonStyle(.plain)
                .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 16)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
    }

    private func tipLabel(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundColor(.accentColor)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundColor(theme.text)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: AppSymbol.chevronForward)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }

    // MARK: - 지금 해 보기

    /// 버튼을 걸기 전에 무엇이 일어나는지 여기서 바로 본다. 버튼이 하는 일과 **같은 길**(`ClipboardCapture`)을 탄다.
    private var tryNowButton: some View {
        VStack(spacing: 8) {
            if let tryResult {
                Text(ClipboardCapture.message(for: tryResult))
                    .font(.footnote)
                    .foregroundColor(isSuccess(tryResult) ? theme.text : .orange)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .transition(.opacity)
            }
            Button {
                HapticManager.shared.light()
                ClipboardCapture.capture { outcome in
                    if isSuccess(outcome) { HapticManager.shared.success() } else { HapticManager.shared.warning() }
                    withAnimation { tryResult = outcome }
                    UIAccessibility.post(notification: .announcement, argument: ClipboardCapture.message(for: outcome))
                }
            } label: {
                Text(NSLocalizedString("복사해 둔 글로 지금 해 보기", comment: "Action Button guide: try capturing the current clipboard now"))
                    .font(.headline)
                    .foregroundStyle(Color.accentForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
            }
            .buttonStyle(.squish)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .background(theme.bg.opacity(0.94))
    }

    private func isSuccess(_ outcome: ClipboardCapture.Outcome) -> Bool {
        if case .captured = outcome { return true }
        return false
    }
}
