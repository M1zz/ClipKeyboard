//
//  FeedbackView.swift
//  ClipKeyboard
//

import SwiftUI

// MARK: - Feedback Type

enum FeedbackType: String, CaseIterable {
    case bug      = "bug"
    case feature  = "feature"
    case question = "question"
    case other    = "other"

    var localizedName: String {
        switch self {
        case .bug:      return NSLocalizedString("버그 신고", comment: "Feedback type: bug report")
        case .feature:  return NSLocalizedString("기능 제안", comment: "Feedback type: feature request")
        case .question: return NSLocalizedString("사용 방법 문의", comment: "Feedback type: usage question")
        case .other:    return NSLocalizedString("기타", comment: "Feedback type: other")
        }
    }

    var icon: String {
        switch self {
        case .bug:      return "ladybug"
        case .feature:  return "lightbulb"
        case .question: return "questionmark.circle"
        case .other:    return "ellipsis.bubble"
        }
    }

    var emailSubject: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return "[\(localizedName)] ClipKeyboard \(version)"
    }
}

// MARK: - Feedback View

struct FeedbackView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: FeedbackType = .bug
    @State private var message: String = ""
    @State private var showMailFallback = false
    @State private var didSend = false

    private let deviceInfo: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        #if os(iOS)
        let device = UIDevice.current
        return "App \(version) | \(device.model) | \(device.systemName) \(device.systemVersion)"
        #else
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "App \(version) | macOS \(os.majorVersion).\(os.minorVersion)"
        #endif
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    typeSelector
                    messageEditor
                    deviceInfoCard
                    sendButton
                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("피드백 보내기", comment: "Feedback view title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("닫기", comment: "Close")) { dismiss() }
                }
            }
            .alert(
                NSLocalizedString("메일 앱을 열 수 없습니다", comment: "Mail unavailable alert title"),
                isPresented: $showMailFallback
            ) {
                Button(NSLocalizedString("다른 메일 앱으로 열기", comment: "Open with another mail app"), action: openMailtoURL)
                Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("Mail 앱이 설정되어 있지 않습니다. mailto: 링크로 다른 메일 앱을 열겠습니까?", comment: "Mail unavailable alert message"))
            }
            .overlay(alignment: .center) {
                if didSend { sentConfirmation }
            }
        }
    }

    // MARK: - Type Selector

    private var typeSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("문의 유형", comment: "Feedback type label"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(theme.text)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(FeedbackType.allCases, id: \.self) { type in
                    typeChip(type)
                }
            }
        }
    }

    private func typeChip(_ type: FeedbackType) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedType = type }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.subheadline)
                Text(type.localizedName)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(selectedType == type ? theme.accent : theme.surfaceAlt)
            .foregroundColor(selectedType == type ? .white : theme.text)
            .cornerRadius(theme.radiusSm)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusSm)
                    .stroke(selectedType == type ? theme.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedType == type ? .isSelected : [])
        .accessibilityLabel(type.localizedName)
    }

    // MARK: - Message Editor

    private var messageEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("내용", comment: "Feedback message label"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(theme.text)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $message)
                    .font(.body)
                    .frame(minHeight: 140)
                    .padding(10)
                    .background(theme.surfaceAlt)
                    .cornerRadius(theme.radiusSm)
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel(NSLocalizedString("피드백 내용", comment: "Feedback content field a11y label"))
                    .accessibilityHint(NSLocalizedString("불편하신 점이나 제안 사항을 자유롭게 적어주세요", comment: "Feedback content field hint"))

                if message.isEmpty {
                    Text(placeholderText)
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var placeholderText: String {
        switch selectedType {
        case .bug:
            return NSLocalizedString("어떤 상황에서 문제가 발생했는지 알려주세요.\n예) 메모를 저장할 때 앱이 종료됩니다.", comment: "Bug report placeholder")
        case .feature:
            return NSLocalizedString("어떤 기능이 있으면 좋겠나요?\n예) 메모를 폴더로 묶는 기능이 필요해요.", comment: "Feature request placeholder")
        case .question:
            return NSLocalizedString("어떤 부분이 궁금하신가요?\n예) 클립보드 히스토리는 어떻게 보나요?", comment: "Usage question placeholder")
        case .other:
            return NSLocalizedString("자유롭게 의견을 남겨주세요.", comment: "Other feedback placeholder")
        }
    }

    // MARK: - Device Info Card

    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("자동 첨부 정보", comment: "Auto-attached info section label"))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(theme.textMuted)

            Text(deviceInfo)
                .font(.caption)
                .foregroundColor(theme.textMuted)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surfaceAlt)
                .cornerRadius(theme.radiusSm)
        }
    }

    // MARK: - Send Button

    private var sendButton: some View {
        let isDisabled = message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Button(action: sendFeedback) {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                Text(NSLocalizedString("보내기", comment: "Send feedback button"))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isDisabled ? theme.textMuted.opacity(0.3) : theme.accent)
            .foregroundColor(.white)
            .cornerRadius(theme.radiusSm)
        }
        .disabled(isDisabled)
        .accessibilityLabel(NSLocalizedString("피드백 보내기", comment: "Send feedback a11y label"))
        .accessibilityHint(isDisabled
            ? NSLocalizedString("내용을 입력하면 활성화됩니다", comment: "Send button disabled hint")
            : NSLocalizedString("탭하면 메일 앱으로 전송됩니다", comment: "Send button enabled hint"))
    }

    // MARK: - Sent Confirmation Overlay

    private var sentConfirmation: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)
            Text(NSLocalizedString("피드백을 보냈습니다!\n소중한 의견 감사합니다 🙏", comment: "Feedback sent confirmation message"))
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(theme.text)
        }
        .padding(32)
        .background(theme.surface)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
        .padding(40)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // MARK: - Send Logic

    private func sendFeedback() {
        let body = buildEmailBody()
        #if os(iOS)
        if EmailController.canSendMail {
            EmailController.shared.sendEmail(
                subject: selectedType.emailSubject,
                body: body,
                to: Constants.developerEmail
            )
            handleSent()
        } else {
            showMailFallback = true
        }
        #else
        openMailtoURL()
        handleSent()
        #endif
    }

    private func buildEmailBody() -> String {
        "\(message)\n\n---\n\(deviceInfo)"
    }

    private func openMailtoURL() {
        let raw = "mailto:\(Constants.developerEmail)?subject=\(selectedType.emailSubject)&body=\(buildEmailBody())"
        guard let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encoded) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }

    private func handleSent() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { didSend = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { dismiss() }
    }
}
