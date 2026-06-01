//
//  NotificationExtension.swift
//  ClipKeyboard.tap
//
//  Created by Claude on 2025-11-28.
//

import Foundation

extension Notification.Name {
    static let showNewMemo = Notification.Name("showNewMemo")
    static let showClipboardHistory = Notification.Name("showClipboardHistory")
    static let showSettings = Notification.Name("showSettings")
    static let showMemoList = Notification.Name("showMemoList")
    static let showCloudBackup = Notification.Name("showCloudBackup")
    static let openMemoListWindow = Notification.Name("openMemoListWindow")
    /// iCloud에서 데이터를 복원(자동/수동)한 뒤 열려 있는 화면을 새로고침.
    static let dataRestored = Notification.Name("dataRestored")
}
