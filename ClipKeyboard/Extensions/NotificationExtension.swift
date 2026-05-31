//
//  NotificationExtension.swift
//  ClipKeyboard
//
//  Created by Claude on 2025-11-28.
//

import Foundation

extension Notification.Name {
    static let showNewMemo = Notification.Name("showNewMemo")
    static let showClipboardHistory = Notification.Name("showClipboardHistory")
    static let showSettings = Notification.Name("showSettings")
    static let showMemoList = Notification.Name("showMemoList")
    static let showPaywall = Notification.Name("showPaywall")
    /// 기존 사용자가 데모 샘플 체험을 수락해 샘플이 삽입됨 → 리스트 리로드 트리거
    static let demoSamplesInserted = Notification.Name("demoSamplesInserted")
}
