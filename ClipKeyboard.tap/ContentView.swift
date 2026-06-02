import SwiftUI

struct ContentView: View {
    @State private var showNewMemoSheet = false
    @State private var showClipboardHistorySheet = false
    @State private var showSettingsSheet = false
    @State private var showCloudBackupSheet = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                
                Text(NSLocalizedString("클립키보드", comment: "App name"))
                    .font(.largeTitle)
                    .bold()
                
                Text(NSLocalizedString("macOS 전용 메모 앱", comment: "App tagline"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Divider()
                    .padding(.vertical)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "keyboard")
                        Text(NSLocalizedString("전역 단축키: ⌃⌥K", comment: "Global hotkey description"))
                        Spacer()
                        Text(NSLocalizedString("메모 목록 표시", comment: "Show memo list label"))
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "menubar.rectangle")
                        Text(NSLocalizedString("메뉴바 아이콘: 🛶", comment: "Menu bar icon description"))
                        Spacer()
                        Text(NSLocalizedString("언제든지 접근 가능", comment: "Always accessible label"))
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "command")
                        Text(NSLocalizedString("앱 메뉴: 클립키보드", comment: "App menu description"))
                        Spacer()
                        Text(NSLocalizedString("모든 기능 사용", comment: "All features label"))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(MacRadius.sm)
                
                Spacer()
                
                Text(NSLocalizedString("창을 닫아도 앱은 백그라운드에서 계속 실행됩니다", comment: "Background run hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .frame(minWidth: 500, minHeight: 400)
            .navigationTitle(NSLocalizedString("클립키보드", comment: "App name"))
        }
        .sheet(isPresented: $showNewMemoSheet) {
            Text(NSLocalizedString("새 메모 화면", comment: "New memo screen placeholder"))
                .frame(width: 400, height: 300)
        }
        .sheet(isPresented: $showClipboardHistorySheet) {
            ClipboardHistoryView()
        }
        .sheet(isPresented: $showSettingsSheet) {
            Text(NSLocalizedString("설정 화면", comment: "Settings screen placeholder"))
                .frame(width: 400, height: 300)
        }
        .sheet(isPresented: $showCloudBackupSheet) {
            CloudBackupView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showMemoList)) { _ in
            NotificationCenter.default.post(name: .openMemoListWindow, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showNewMemo)) { _ in
            showNewMemoSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showClipboardHistory)) { _ in
            showClipboardHistorySheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
            showSettingsSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCloudBackup)) { _ in
            showCloudBackupSheet = true
        }
    }
}
