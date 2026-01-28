//
//  SettingView.swift
//  Token memo
//
//  Created by hyunho lee on 2023/06/05.
//

import SwiftUI
import StoreKit

struct SettingView: View {
    
    @Environment(\.requestReview) var requestReview
    
    var body: some View {
        List {
            Section("앱 설정") {
                NavigationLink(destination: ComboList()) {
                    Label("Combo 관리", systemImage: "arrow.triangle.2.circlepath.circle")
                        .badge("NEW")
                }

                NavigationLink(destination: TutorialView()) {
                    Text("클립키보드 사용방법")
                }

                NavigationLink(destination: KeyboardTutorialView()) {
                    Text("FAQ")
                }

                NavigationLink(destination: FontSetting()) {
                    Text("앱 내 폰트 크기 변경")
                }

                NavigationLink(destination: ThemeSettings()) {
                    Text("키보드 테마 설정")
                }

                NavigationLink(destination: KeyboardLayoutSettings()) {
                    Label("키보드 레이아웃 설정", systemImage: "rectangle.grid.2x2")
                        .badge("NEW")
                }

                NavigationLink(destination: CopyPasteView()) {
                    Text("붙여넣기 알림 켜기/끄기")
                }
            }

            Section("데이터 관리") {
                NavigationLink(destination: CloudBackupView()) {
                    Label("iCloud 백업 및 복구", systemImage: "icloud.and.arrow.up")
                }
            }

            Section("통계 및 정보") {
                NavigationLink(destination: UsageStatistics()) {
                    Label("사용 통계", systemImage: "chart.bar.fill")
                }
            }

            Section("지원") {
                NavigationLink(destination: ReviewWriteView()) {
                    Text("리뷰 및 평점 매기기")
                }

                NavigationLink(destination: ContactView()) {
                    Text("개발자에게 연락하기")
                }
            }

            Section("앱 정보") {
                HStack {
                    Text("버전")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.primary)
                }
            }
        }
    }

    // 앱 버전 정보를 Info.plist에서 자동으로 가져오기
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
}

struct CopyPasteView: View {

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("📋 붙여넣기 허용 설정")
                        .font(.headline)
                        .padding(.bottom, 4)

                    Text("앱 실행 시 '붙여넣기 허용' 팝업이 뜬 경우, 아래 경로로 설정을 변경할 수 있습니다.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section(header: Text("설정 경로")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                            .foregroundColor(.blue)
                        Text("설정")
                            .fontWeight(.medium)
                    }

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.leading, 8)

                    HStack(spacing: 8) {
                        Image(systemName: "app.fill")
                            .foregroundColor(.blue)
                        Text("클립 키보드")
                            .fontWeight(.medium)
                    }

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.leading, 8)

                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundColor(.blue)
                        Text("다른 앱에서 붙여넣기")
                            .fontWeight(.medium)
                    }
                }
                .padding(.vertical, 8)
            }

            Section(header: Text("옵션 설명")) {
                VStack(alignment: .leading, spacing: 16) {
                    // 묻기
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("묻기")
                                .font(.headline)
                            Text("복사/붙여넣기 시 매번 팝업이 표시됩니다.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // 거부
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("거부")
                                .font(.headline)
                            Text("자동 붙여넣기가 차단됩니다. 하지만 길게 눌러서 수동으로 붙여넣기는 가능합니다.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
                                Text("허용")
                                    .font(.headline)
                                Text("(권장)")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            Text("팝업 없이 복사한 텍스트를 바로 확인하고 붙여넣을 수 있습니다. 클립보드 자동 분류 기능을 사용하려면 이 옵션을 권장합니다.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
                        Text("설정으로 이동")
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                    }
                }
            }
        }
        .navigationTitle("붙여넣기 알림 설정")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ReviewWriteView: View {
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Button("Open Web Page") {
                
            }
            .onAppear(perform: {
                dismiss()

                if let url = URL(string: "https://apps.apple.com/app/id1543660502?action=write-review") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            })
        }
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

                if let url = URL(string: "https://leeo75.notion.site/ClipKeyboard-tutorial-70624fccc524465f99289c89bd0261a4?pvs=4") {
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

                EmailController.shared.sendEmail(subject: "클립 키보드에 관해 문의드릴 것이 있습니다", body: "안녕하세요 저는 클립키보드의 사용자입니다.", to: "clipkeyboard@gmail.com")
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
        UIApplication.shared.windows.first?.rootViewController
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
