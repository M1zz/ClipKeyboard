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
        print("🗑️ [WindowManager] removeWindow - 참조 제거 시작: \(key)")

        // 안전하게 참조 제거 (이미 해제된 객체에 접근하지 않음)
        let hadWindow = windows[key] != nil
        let hadDelegate = delegates[key] != nil

        print("   └─ 윈도우 존재: \(hadWindow)")
        print("   └─ 델리게이트 존재: \(hadDelegate)")

        windows.removeValue(forKey: key)
        print("   └─ windows에서 제거 완료")

        delegates.removeValue(forKey: key)
        print("   └─ delegates에서 제거 완료")

        print("✅ [WindowManager] removeWindow - 완료: \(key)")
        print("   └─ 남은 윈도우 수: \(windows.count)")
    }

    func openNewMemoWindow() {
        print("📝 [WindowManager] 새 메모 윈도우 열기")

        let windowKey = "new-memo"

        // 기존 윈도우가 있으면 포커스
        if let existingWindow = windows[windowKey] {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("✅ [WindowManager] 기존 윈도우 포커스")
            return
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
        window.identifier = NSUserInterfaceItemIdentifier(windowKey)
        window.level = .floating

        // 델리게이트 설정
        let delegate = WindowDelegate(windowKey: windowKey, manager: self)
        window.delegate = delegate

        // 윈도우와 델리게이트 참조 저장
        windows[windowKey] = window
        delegates[windowKey] = delegate

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        print("✅ [WindowManager] 새 윈도우 생성 완료")
    }

    func openClipboardHistoryWindow() {
        print("📋 [WindowManager] 클립보드 히스토리 윈도우 열기")

        let windowKey = "clipboard-history"

        // 기존 윈도우가 있으면 포커스
        if let existingWindow = windows[windowKey] {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("✅ [WindowManager] 기존 윈도우 포커스")
            return
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
        window.identifier = NSUserInterfaceItemIdentifier(windowKey)
        window.level = .floating

        // 델리게이트 설정
        let delegate = WindowDelegate(windowKey: windowKey, manager: self)
        window.delegate = delegate

        // 윈도우와 델리게이트 참조 저장
        windows[windowKey] = window
        delegates[windowKey] = delegate

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        print("✅ [WindowManager] 새 윈도우 생성 완료")
    }

    func openSettingsWindow() {
        print("⚙️ [WindowManager] 설정 윈도우 열기")

        let windowKey = "settings"

        // 기존 윈도우가 있으면 포커스
        if let existingWindow = windows[windowKey] {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("✅ [WindowManager] 기존 윈도우 포커스")
            return
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
        window.identifier = NSUserInterfaceItemIdentifier(windowKey)
        window.level = .floating

        // 델리게이트 설정
        let delegate = WindowDelegate(windowKey: windowKey, manager: self)
        window.delegate = delegate

        // 윈도우와 델리게이트 참조 저장
        windows[windowKey] = window
        delegates[windowKey] = delegate

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        print("✅ [WindowManager] 새 윈도우 생성 완료")
    }

    func openCloudBackupWindow() {
        print("☁️ [WindowManager] iCloud 백업 윈도우 열기")

        let windowKey = "cloud-backup"

        // 기존 윈도우가 있으면 포커스
        if let existingWindow = windows[windowKey] {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("✅ [WindowManager] 기존 윈도우 포커스")
            return
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
        window.identifier = NSUserInterfaceItemIdentifier(windowKey)
        window.level = .floating

        // 델리게이트 설정
        let delegate = WindowDelegate(windowKey: windowKey, manager: self)
        window.delegate = delegate

        // 윈도우와 델리게이트 참조 저장
        windows[windowKey] = window
        delegates[windowKey] = delegate

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        print("✅ [WindowManager] 새 윈도우 생성 완료")
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

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        print("🔒 [WindowDelegate] windowShouldClose - 윈도우 닫기 요청: \(windowKey)")

        // 윈도우를 즉시 닫지 않고, 뷰를 안전하게 정리한 후 숨김
        DispatchQueue.main.async {
            print("   └─ contentViewController 정리 시작")

            // contentViewController를 먼저 정리
            if let viewController = sender.contentViewController {
                viewController.view.removeFromSuperview()
                sender.contentViewController = nil
                print("      └─ contentViewController 제거 완료")
            }

            // 짧은 지연 후 참조 제거 및 윈도우 닫기
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                print("   └─ 딕셔너리에서 참조 제거")
                self?.manager?.removeWindow(key: self?.windowKey ?? "")

                // delegate를 nil로 설정하여 순환 참조 방지
                print("   └─ delegate 제거")
                sender.delegate = nil

                // 윈도우 숨기기 (close 대신 orderOut 사용)
                sender.orderOut(nil)
                print("✅ [WindowDelegate] 윈도우 숨김 완료")
            }
        }

        print("⏸️ [WindowDelegate] windowShouldClose - 닫기 보류 (비동기 처리)")
        return false  // 일단 닫지 않고, 나중에 orderOut으로 숨김
    }

    func windowWillClose(_ notification: Notification) {
        print("🗑️ [WindowDelegate] windowWillClose - 윈도우 닫힘 시작: \(windowKey)")
        print("✅ [WindowDelegate] windowWillClose - 완료 (참조는 이미 제거됨)")
    }
}
