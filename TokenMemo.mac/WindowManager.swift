//
//  WindowManager.swift
//  TokenMemo.mac
//
//  Created by Claude on 2025-11-28.
//

import SwiftUI
import AppKit

class WindowManager {
    static let shared = WindowManager()

    // 윈도우 참조를 유지하여 메모리 해제 문제 방지
    private var windows: [String: NSWindow] = [:]
    private var delegates: [String: WindowDelegate] = [:]

    private init() {
        setupNotifications()
    }

    private func setupNotifications() {
        // 메모 목록
        NotificationCenter.default.addObserver(
            forName: .openMemoListWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.openMemoListWindow()
        }

        NotificationCenter.default.addObserver(
            forName: .showMemoList,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.openMemoListWindow()
        }

        // 새 메모
        NotificationCenter.default.addObserver(
            forName: .showNewMemo,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.openNewMemoWindow()
        }

        // 클립보드 히스토리
        NotificationCenter.default.addObserver(
            forName: .showClipboardHistory,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.openClipboardHistoryWindow()
        }

        // 설정
        NotificationCenter.default.addObserver(
            forName: .showSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.openSettingsWindow()
        }

        // iCloud 백업
        NotificationCenter.default.addObserver(
            forName: .showCloudBackup,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.openCloudBackupWindow()
        }
    }

    func openMemoListWindow() {
        print("📋 [WindowManager] 메모 목록 윈도우 열기 시도")

        let windowKey = "memo-list"

        // 기존 윈도우가 있으면 포커스
        if let existingWindow = windows[windowKey] {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("✅ [WindowManager] 기존 윈도우 포커스")
            return
        }

        // 새 윈도우 생성 - 컴팩트 크기 (350x450)
        let contentView = MemoListView()
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 450),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.setFrameAutosaveName("MemoListWindow")
        window.contentViewController = hostingController
        window.title = "메모 목록"
        window.identifier = NSUserInterfaceItemIdentifier(windowKey)
        window.level = .floating

        // 델리게이트 설정하여 윈도우 닫힐 때 정리
        let delegate = WindowDelegate(windowKey: windowKey, manager: self)
        window.delegate = delegate

        // 윈도우와 델리게이트 참조 저장
        windows[windowKey] = window
        delegates[windowKey] = delegate

        window.makeKeyAndOrderFront(nil)

        // 앱 활성화
        NSApp.activate(ignoringOtherApps: true)

        print("✅ [WindowManager] 새 윈도우 생성 완료")
    }

    // 윈도우가 닫힐 때 호출
    fileprivate func removeWindow(key: String) {
        windows.removeValue(forKey: key)
        delegates.removeValue(forKey: key)
        print("🗑️ [WindowManager] 윈도우 및 델리게이트 제거: \(key)")
    }

    func openNewMemoWindow() {
        print("📝 [WindowManager] 새 메모 윈도우 열기")

        // 기존 윈도우 확인
        for window in NSApp.windows {
            if window.identifier?.rawValue == "new-memo" {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }

        // TODO: 새 메모 뷰 구현 필요
        let contentView = Text("새 메모 화면")
            .frame(width: 400, height: 300)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.contentViewController = hostingController
        window.title = "새 메모"
        window.identifier = NSUserInterfaceItemIdentifier("new-memo")
        window.makeKeyAndOrderFront(nil)
        window.level = .floating

        NSApp.activate(ignoringOtherApps: true)
    }

    func openClipboardHistoryWindow() {
        print("📋 [WindowManager] 클립보드 히스토리 윈도우 열기")

        // 기존 윈도우 확인
        for window in NSApp.windows {
            if window.identifier?.rawValue == "clipboard-history" {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }

        let contentView = ClipboardHistoryView()
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.contentViewController = hostingController
        window.title = "클립보드 히스토리"
        window.identifier = NSUserInterfaceItemIdentifier("clipboard-history")
        window.makeKeyAndOrderFront(nil)
        window.level = .floating

        NSApp.activate(ignoringOtherApps: true)
    }

    func openSettingsWindow() {
        print("⚙️ [WindowManager] 설정 윈도우 열기")

        // 기존 윈도우 확인
        for window in NSApp.windows {
            if window.identifier?.rawValue == "settings" {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }

        // TODO: 설정 뷰 구현 필요
        let contentView = Text("설정 화면")
            .frame(width: 500, height: 400)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.contentViewController = hostingController
        window.title = "설정"
        window.identifier = NSUserInterfaceItemIdentifier("settings")
        window.makeKeyAndOrderFront(nil)
        window.level = .floating

        NSApp.activate(ignoringOtherApps: true)
    }

    func openCloudBackupWindow() {
        print("☁️ [WindowManager] iCloud 백업 윈도우 열기")

        // 기존 윈도우 확인
        for window in NSApp.windows {
            if window.identifier?.rawValue == "cloud-backup" {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }

        let contentView = CloudBackupView()
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.contentViewController = hostingController
        window.title = "iCloud 백업"
        window.identifier = NSUserInterfaceItemIdentifier("cloud-backup")
        window.makeKeyAndOrderFront(nil)
        window.level = .floating

        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Window Delegate

class WindowDelegate: NSObject, NSWindowDelegate {
    let windowKey: String
    weak var manager: WindowManager?

    init(windowKey: String, manager: WindowManager) {
        self.windowKey = windowKey
        self.manager = manager
        super.init()
    }

    func windowWillClose(_ notification: Notification) {
        print("🔒 [WindowDelegate] 윈도우 닫힘: \(windowKey)")
        manager?.removeWindow(key: windowKey)
    }
}
