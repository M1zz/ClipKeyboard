//
//  MenuBarManager.swift
//  TokenMemo.tap
//
//  Created by Claude on 2025-11-28.
//

import AppKit
import SwiftUI

class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?

    private override init() {
        super.init()
    }

    func setupMenuBar() {
        // Status Bar 아이템 생성
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else {
            print("❌ [MenuBar] 버튼 생성 실패")
            return
        }

        // 아이콘 설정 — Mac-idiomatic SF Symbol 우선, 폴백으로 이모지.
        if let icon = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipKeyboard") {
            icon.isTemplate = true  // 라이트/다크 모드 자동 적응
            button.image = icon
        } else {
            button.title = "🛶"
        }

        // 메뉴 생성
        let menu = NSMenu()

        // 메뉴 아이템 추가 (로케일 따라 자동 번역)
        menu.addItem(withTitle: NSLocalizedString("Memo List", comment: "Menu: memo list"),
                     action: #selector(memoListAction), keyEquivalent: "k")
        menu.addItem(withTitle: NSLocalizedString("New Memo", comment: "Menu: new memo"),
                     action: #selector(newMemoAction), keyEquivalent: "n")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: NSLocalizedString("Clipboard History", comment: "Menu: clipboard history"),
                     action: #selector(clipboardHistoryAction), keyEquivalent: "h")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: NSLocalizedString("iCloud Backup", comment: "Menu: iCloud backup"),
                     action: #selector(cloudBackupAction), keyEquivalent: "b")
        menu.addItem(withTitle: NSLocalizedString("Preferences…", comment: "Menu: preferences"),
                     action: #selector(settingsAction), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: NSLocalizedString("Show Onboarding", comment: "Menu: show onboarding"),
                     action: #selector(onboardingAction), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: NSLocalizedString("Quit ClipKeyboard", comment: "Menu: quit"),
                     action: #selector(quitAction), keyEquivalent: "q")

        // 모든 메뉴 아이템의 타겟 설정
        for item in menu.items {
            item.target = self
        }

        statusItem?.menu = menu

        print("✅ [MenuBar] 메뉴바 아이콘 설정 완료")
    }

    // MARK: - Menu Actions

    @objc private func memoListAction() {
        print("📋 [MenuBar] 메모 목록 클릭")
        NotificationCenter.default.post(name: .showMemoList, object: nil)
        activateApp()
    }

    @objc private func newMemoAction() {
        print("📝 [MenuBar] 새 메모 클릭")
        NotificationCenter.default.post(name: .showNewMemo, object: nil)
        activateApp()
    }

    @objc private func clipboardHistoryAction() {
        print("📋 [MenuBar] 클립보드 히스토리 클릭")
        NotificationCenter.default.post(name: .showClipboardHistory, object: nil)
        activateApp()
    }

    @objc private func cloudBackupAction() {
        print("☁️ [MenuBar] iCloud 백업 클릭")
        NotificationCenter.default.post(name: .showCloudBackup, object: nil)
        activateApp()
    }

    @objc private func settingsAction() {
        print("⚙️ [MenuBar] 설정 클릭")
        NotificationCenter.default.post(name: .showSettings, object: nil)
        activateApp()
    }

    @objc private func onboardingAction() {
        print("👋 [MenuBar] 온보딩 다시 보기 클릭")
        WindowManager.shared.openOnboardingWindow()
        activateApp()
    }

    @objc private func quitAction() {
        print("👋 [MenuBar] 종료")
        NSApp.terminate(nil)
    }

    private func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }
}
