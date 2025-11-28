//
//  NotificationExtension.swift
//  TokenMemo.mac
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
}
