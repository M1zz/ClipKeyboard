//
//  ContentView.swift
//  TokenMemo.tap
//
//  Created by hyunho lee on 11/28/25.
//

import SwiftUI

struct ContentView: View {
    @State private var showNewMemoSheet = false
    @State private var showClipboardHistorySheet = false
    @State private var showSettingsSheet = false
    @State private var showCloudBackupSheet = false
    @State private var observerTokens: [NSObjectProtocol] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("클립키보드")
                    .font(.largeTitle)
                    .bold()

                Text("macOS 전용 메모 앱")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Divider()
                    .padding(.vertical)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "keyboard")
                        Text("전역 단축키: ⌃⌥K")
                        Spacer()
                        Text("메모 목록 표시")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Image(systemName: "menubar.rectangle")
                        Text("메뉴바 아이콘: 🛶")
                        Spacer()
                        Text("언제든지 접근 가능")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Image(systemName: "command")
                        Text("앱 메뉴: 클립키보드")
                        Spacer()
                        Text("모든 기능 사용")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                Spacer()

                Text("창을 닫아도 앱은 백그라운드에서 계속 실행됩니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .frame(minWidth: 500, minHeight: 400)
            .navigationTitle("클립키보드")
        }
        .sheet(isPresented: $showNewMemoSheet) {
            Text("새 메모 화면")
                .frame(width: 400, height: 300)
        }
        .sheet(isPresented: $showClipboardHistorySheet) {
            ClipboardHistoryView()
        }
        .sheet(isPresented: $showSettingsSheet) {
            Text("설정 화면")
                .frame(width: 400, height: 300)
        }
        .sheet(isPresented: $showCloudBackupSheet) {
            CloudBackupView()
        }
        .onAppear {
            setupNotifications()
        }
        .onDisappear {
            observerTokens.forEach { NotificationCenter.default.removeObserver($0) }
            observerTokens.removeAll()
        }
    }

    private func setupNotifications() {
        guard observerTokens.isEmpty else { return }
        print("🎯 [ContentView] 알림 리스너 등록")

        let t1 = NotificationCenter.default.addObserver(
            forName: .showMemoList,
            object: nil,
            queue: .main
        ) { _ in
            print("📋 [ContentView] 메모 목록 윈도우 열기 요청")
            NotificationCenter.default.post(name: .openMemoListWindow, object: nil)
        }

        let t2 = NotificationCenter.default.addObserver(
            forName: .showNewMemo,
            object: nil,
            queue: .main
        ) { [self] _ in
            print("📝 [ContentView] 새 메모 표시")
            showNewMemoSheet = true
        }

        let t3 = NotificationCenter.default.addObserver(
            forName: .showClipboardHistory,
            object: nil,
            queue: .main
        ) { [self] _ in
            print("📋 [ContentView] 클립보드 히스토리 표시")
            showClipboardHistorySheet = true
        }

        let t4 = NotificationCenter.default.addObserver(
            forName: .showSettings,
            object: nil,
            queue: .main
        ) { [self] _ in
            print("⚙️ [ContentView] 설정 표시")
            showSettingsSheet = true
        }

        let t5 = NotificationCenter.default.addObserver(
            forName: .showCloudBackup,
            object: nil,
            queue: .main
        ) { [self] _ in
            print("☁️ [ContentView] 클라우드 백업 표시")
            showCloudBackupSheet = true
        }

        observerTokens = [t1, t2, t3, t4, t5]
    }
}

#Preview {
    ContentView()
}
