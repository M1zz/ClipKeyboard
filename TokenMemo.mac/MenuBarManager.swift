//
//  MenuBarManager.swift
//  TokenMemo.mac
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

        // 아이콘 설정 (이모지만 사용)
        button.title = "🛶"

        // 메뉴 생성
        let menu = NSMenu()

        // 메뉴 아이템 추가
        menu.addItem(withTitle: "메모 목록", action: #selector(memoListAction), keyEquivalent: "k")
        menu.addItem(withTitle: "새 메모", action: #selector(newMemoAction), keyEquivalent: "n")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "클립보드 히스토리", action: #selector(clipboardHistoryAction), keyEquivalent: "h")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "iCloud 백업", action: #selector(cloudBackupAction), keyEquivalent: "b")
        menu.addItem(withTitle: "설정", action: #selector(settingsAction), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "종료", action: #selector(quitAction), keyEquivalent: "q")

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

    @objc private func quitAction() {
        print("👋 [MenuBar] 종료")
        NSApp.terminate(nil)
    }

    private func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }
}
