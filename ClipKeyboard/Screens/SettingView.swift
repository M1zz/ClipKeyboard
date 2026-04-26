//
//  SettingView.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/06/05.
//

import SwiftUI
import StoreKit

struct SettingView: View {
    
    @Environment(\.requestReview) var requestReview
    @Environment(\.appTheme) private var theme
    @ObservedObject private var proManager = StoreManager.shared
    @State private var showPaywall = false
    
    var body: some View {
        List {
            // Pro 섹션
            if !proManager.isPro {
                Section {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            Image(systemName: "star.circle.fill")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("Pro 업그레이드", comment: "Pro upgrade"))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(NSLocalizedString("무제한 메모, iCloud 백업 등", comment: "Pro features"))
                                    .font(.caption)
                                    .foregroundColor(theme.textMuted)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(theme.textMuted)
                        }
                    }
                }
            } else {
                Section {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Text(NSLocalizedString("Pro 활성화됨", comment: "Pro activated"))
                            .font(.headline)
                        
                        Spacer()
                    }
                }
            }
            
            // 키보드 섹션 (5개)
            Section(NSLocalizedString("키보드", comment: "Keyboard section")) {
                Button {
                    HapticManager.shared.light()
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text(NSLocalizedString("키보드 설정", comment: "Keyboard settings"))
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption)
                            .foregroundColor(theme.textMuted)
                    }
                }

                NavigationLink(destination: KeyboardLayoutSettings()) {
                    Text(NSLocalizedString("키보드 레이아웃", comment: "Keyboard layout"))
                }

                NavigationLink(destination: ThemeSettings()) {
                    Text(NSLocalizedString("키보드 테마", comment: "Keyboard theme"))
                }

                NavigationLink(destination: FontSetting()) {
                    Text(NSLocalizedString("앱 내 폰트 크기", comment: "App font size"))
                }
            }

            // 데이터 섹션 (2개)
            Section(NSLocalizedString("데이터", comment: "Data section")) {
                // iCloud 동기화는 CloudBackupView 안에 있다고 가정
                NavigationLink(destination: CloudBackupView()) {
                    Label(NSLocalizedString("백업 및 복원", comment: "Backup and restore"), systemImage: "icloud.and.arrow.up")
                }
            }

            // 정보 섹션 (4개)
            Section(NSLocalizedString("정보", comment: "Info section")) {
                NavigationLink(destination: CopyPasteView()) {
                    Text(NSLocalizedString("붙여넣기 알림 설정", comment: "Paste notification settings title"))
                }

                NavigationLink(destination: UsageGuideView()) {
                    Text(NSLocalizedString("활용 사례", comment: "Use cases / usage scenarios"))
                }

                NavigationLink(destination: TutorialView()) {
                    Text(NSLocalizedString("사용 가이드", comment: "User guide"))
                }

                NavigationLink(destination: ReviewWriteView()) {
                    Text(NSLocalizedString("리뷰 남기기", comment: "Leave review"))
                }

                NavigationLink(destination: ContactView()) {
                    Text(NSLocalizedString("문의하기", comment: "Contact"))
                }
            }

            // v4.3 Redesign: 테마 선택 섹션
            Section(NSLocalizedString("Appearance", comment: "Settings section: appearance")) {
                NavigationLink(destination: ThemePickerView()) {
                    HStack {
                        Label(NSLocalizedString("Theme", comment: "Settings: theme picker"), systemImage: "paintpalette")
                        Spacer()
                        Text(AppThemePreference.shared.kind.displayName)
                            .foregroundColor(theme.textMuted)
                            .font(.subheadline)
                    }
                }
                NavigationLink(destination: AppearanceModePickerView()) {
                    HStack {
                        Label(NSLocalizedString("Appearance mode", comment: "Settings: appearance mode"), systemImage: "circle.lefthalf.filled")
                        Spacer()
                        Text(AppThemePreference.shared.mode.displayName)
                            .foregroundColor(theme.textMuted)
                            .font(.subheadline)
                    }
                }
            }

            #if !targetEnvironment(macCatalyst)
            Section(NSLocalizedString("Use on other devices", comment: "Cross-device section")) {
                NavigationLink(destination: MacAppIntroView()) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 32, height: 32)
                            Image(systemName: "macbook")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("ClipKeyboard for Mac", comment: "Mac app intro title"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(NSLocalizedString("Menu bar access · Global hotkey · iCloud sync", comment: "Mac promo subtitle"))
                                .font(.caption)
                                .foregroundColor(theme.textMuted)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            #endif

            Section(NSLocalizedString("앱 정보", comment: "App info section")) {
                HStack {
                    Text(NSLocalizedString("버전", comment: "Version label"))
                        .foregroundColor(theme.textMuted)
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.primary)
                }
            }
        }
        .listStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(theme.bg.ignoresSafeArea())
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // 앱 버전 정보를 Info.plist에서 자동으로 가져오기
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
}

struct CopyPasteView: View {

    @Environment(\.appTheme) private var theme

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("📋 붙여넣기 허용 설정", comment: "Paste permission settings title"))
                        .font(.headline)
                        .padding(.bottom, 4)

                    Text(NSLocalizedString("앱 실행 시 '붙여넣기 허용' 팝업이 뜬 경우, 아래 경로로 설정을 변경할 수 있습니다.", comment: "Paste permission settings description"))
                        .font(.subheadline)
                        .foregroundColor(theme.textMuted)
                }
                .padding(.vertical, 8)
            }

            Section(header: Text(NSLocalizedString("설정 경로", comment: "Settings path section header"))) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                            .foregroundColor(.blue)
                        Text(NSLocalizedString("설정", comment: "Settings"))
                            .fontWeight(.medium)
                    }

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(theme.textFaint)
                        .padding(.leading, 8)

                    HStack(spacing: 8) {
                        Image(systemName: "app.fill")
                            .foregroundColor(.blue)
                        Text(NSLocalizedString("클립키보드", comment: "ClipKeyboard app name"))
                            .fontWeight(.medium)
                    }

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(theme.textFaint)
                        .padding(.leading, 8)

                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundColor(.blue)
                        Text(NSLocalizedString("다른 앱에서 붙여넣기", comment: "Paste from other apps"))
                            .fontWeight(.medium)
                    }
                }
                .padding(.vertical, 8)
            }

            Section(header: Text(NSLocalizedString("옵션 설명", comment: "Options description section header"))) {
                VStack(alignment: .leading, spacing: 16) {
                    // 묻기
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("묻기", comment: "Ask option"))
                                .font(.headline)
                            Text(NSLocalizedString("복사/붙여넣기 시 매번 팝업이 표시됩니다.", comment: "Ask option description"))
                                .font(.subheadline)
                                .foregroundColor(theme.textMuted)
                        }
                    }

                    Divider()

                    // 거부
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("거부", comment: "Deny option"))
                                .font(.headline)
                            Text(NSLocalizedString("자동 붙여넣기가 차단됩니다. 하지만 길게 눌러서 수동으로 붙여넣기는 가능합니다.", comment: "Deny option description"))
                                .font(.subheadline)
                                .foregroundColor(theme.textMuted)
                        }
                    }

                    Divider()

                    // 허용 (권장)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(NSLocalizedString("허용", comment: "Allow option"))
                                    .font(.headline)
                                Text(NSLocalizedString("(권장)", comment: "Recommended badge"))
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            Text(NSLocalizedString("팝업 없이 복사한 텍스트를 바로 확인하고 붙여넣을 수 있습니다. 클립보드 자동 분류 기능을 사용하려면 이 옵션을 권장합니다.", comment: "Allow option description"))
                                .font(.subheadline)
                                .foregroundColor(theme.textMuted)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                Button(action: {
                    if let url = URL.init(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text(NSLocalizedString("설정으로 이동", comment: "Go to Settings button"))
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("붙여넣기 알림 설정", comment: "Paste notification settings title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ReviewWriteView: View {

    @Environment(\.dismiss) var dismiss
    @Environment(\.requestReview) var requestReview
    @Environment(\.appTheme) private var theme
    @State private var showingOptions = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("⭐️ 리뷰 및 평점 매기기", comment: "Review and rating header"))
                        .font(.headline)
                        .padding(.bottom, 4)

                    Text(NSLocalizedString("클립키보드가 마음에 드셨나요? 여러분의 리뷰는 앱을 더 발전시키는 데 큰 도움이 됩니다.", comment: "Review description"))
                        .font(.subheadline)
                        .foregroundColor(theme.textMuted)
                }
                .padding(.vertical, 8)
            }

            Section {
                Button(action: {
                    // StoreKit의 in-app 리뷰 요청 (iOS 14+)
                    requestReview()
                    // 1초 후 화면 닫기
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        dismiss()
                    }
                }) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("앱 내에서 리뷰 작성", comment: "In-app review button"))
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(NSLocalizedString("빠르고 간편하게 리뷰를 남길 수 있습니다 (권장)", comment: "In-app review description"))
                                .font(.caption)
                                .foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(theme.textMuted)
                    }
                    .padding(.vertical, 4)
                }

                Button(action: {
                    dismiss()
                    // App Store 리뷰 페이지로 직접 이동
                    if let url = URL(string: Constants.appStoreReviewURL) {
                        #if os(iOS)
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        #elseif os(macOS)
                        NSWorkspace.shared.open(url)
                        #endif
                    }
                }) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("App Store에서 리뷰 작성", comment: "App Store review button"))
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(NSLocalizedString("App Store 페이지에서 직접 작성합니다", comment: "App Store review description"))
                                .font(.caption)
                                .foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption)
                            .foregroundColor(theme.textMuted)
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text(NSLocalizedString("리뷰는 다른 사용자에게 앱을 추천하는 데 도움이 되며, 개발자에게는 큰 힘이 됩니다.", comment: "Review footer message"))
                    .font(.caption)
                    .foregroundColor(theme.textMuted)
            }
        }
        .navigationTitle(NSLocalizedString("리뷰 및 평점", comment: "Review navigation title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct TutorialView: View {
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Button("Open Web Page") {
                
            }
            .onAppear(perform: {
                dismiss()

                if let url = URL(string: Constants.tutorialURL) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            })
        }
    }
}

struct ContactView: View {
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Button("Send Email") {
                
            }
            .onAppear(perform: {
                dismiss()

                EmailController.shared.sendEmail(
                    subject: NSLocalizedString("클립키보드에 관해 문의드릴 것이 있습니다", comment: "Email subject"),
                    body: NSLocalizedString("안녕하세요 저는 클립키보드의 사용자입니다.", comment: "Email body"),
                    to: Constants.developerEmail
                )
            })
        }
    }
}

#if canImport(MessageUI)
import MessageUI

class EmailController: NSObject, MFMailComposeViewControllerDelegate {
    public static let shared = EmailController()
    private override init() { }

    func sendEmail(subject:String, body:String, to:String){
        // Check if the device is able to send emails
        if !MFMailComposeViewController.canSendMail() {
           print("This device cannot send emails.")
           return
        }
        // Create the email composer
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = self
        mailComposer.setToRecipients([to])
        mailComposer.setSubject(subject)
        mailComposer.setMessageBody(body, isHTML: false)
        EmailController.getRootViewController()?.present(mailComposer, animated: true, completion: nil)
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        EmailController.getRootViewController()?.dismiss(animated: true, completion: nil)
    }

    static func getRootViewController() -> UIViewController? {
        // In SwiftUI 2.0
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.rootViewController
    }
}
#else
// macOS fallback - EmailController는 사용하지 않음
class EmailController: NSObject {
    public static let shared = EmailController()
    private override init() { }

    func sendEmail(subject:String, body:String, to:String){
        // macOS에서는 mailto URL 스킴 사용
        let urlString = "mailto:\(to)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let url = URL(string: urlString) {
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
}
#endif

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}
