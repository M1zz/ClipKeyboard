//
//  GlobalHotkeyManager.swift
//  Token memo
//
//  Created by Claude on 2025-11-28.
//

#if targetEnvironment(macCatalyst)
import UIKit

class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private var eventMonitor: Any?

    private init() {}

    func registerGlobalHotkey() {
        // Mac Catalyst에서는 완전한 전역 핫키를 사용할 수 없습니다
        // 메뉴 단축키(⌘⇧X)를 사용하거나 메뉴바 아이콘을 클릭하세요

        print("ℹ️  [Global Hotkey] Mac Catalyst는 전역 핫키를 지원하지 않습니다")
        print("ℹ️  [Global Hotkey] 메뉴 단축키 ⌘⇧X를 사용하거나 메뉴바 아이콘 📋을 클릭하세요")

        // 로컬 이벤트 모니터는 등록하지 않음 (macOS 네이티브 앱과 충돌 방지)
    }

    func unregisterGlobalHotkey() {
        guard let monitor = eventMonitor else { return }

        guard let nsEventClass = NSClassFromString("NSEvent") else {
            return
        }

        let removeMonitorSelector = NSSelectorFromString("removeMonitor:")
        guard nsEventClass.responds(to: removeMonitorSelector) else {
            return
        }

        typealias RemoveMonitorFunction = @convention(c) (AnyObject, Selector, AnyObject) -> Void
        let removeMonitorMethod = unsafeBitCast(
            (nsEventClass as AnyObject).method(for: removeMonitorSelector),
            to: RemoveMonitorFunction.self
        )

        removeMonitorMethod(nsEventClass as AnyObject, removeMonitorSelector, monitor as AnyObject)
        self.eventMonitor = nil
        print("🔓 [Local Hotkey] 로컬 이벤트 모니터 해제")
    }

    deinit {
        unregisterGlobalHotkey()
    }
}
#endif
