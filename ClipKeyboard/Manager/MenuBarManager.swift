//
//  MenuBarManager.swift
//  Token memo
//
//  Created by Claude on 2025-11-28.
//

#if targetEnvironment(macCatalyst)
import UIKit
import SwiftUI

class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var statusItem: AnyObject?

    private override init() {
        super.init()
    }

    func setupMenuBar() {
        // NSStatusBar를 사용하여 메뉴바 아이템 생성
        guard let statusBarClass = NSClassFromString("NSStatusBar") else {
            print("❌ [MenuBar] NSStatusBar 클래스를 찾을 수 없음")
            return
        }

        // systemStatusBar 가져오기
        let systemBarSelector = NSSelectorFromString("systemStatusBar")
        guard let systemBar = Self.performSelector(on: statusBarClass as AnyObject, selector: systemBarSelector) else {
            print("❌ [MenuBar] systemStatusBar를 가져올 수 없음")
            return
        }

        // statusItemWithLength 호출 (-1은 가변 길이)
        let statusItemSelector = NSSelectorFromString("statusItemWithLength:")
        guard let statusItem = Self.performSelectorWithCGFloat(on: systemBar, selector: statusItemSelector, value: -1) else {
            print("❌ [MenuBar] statusItem 생성 실패")
            return
        }

        self.statusItem = statusItem

        // 버튼 가져오기
        let buttonSelector = NSSelectorFromString("button")
        guard let button = Self.performSelector(on: statusItem, selector: buttonSelector) else {
            print("❌ [MenuBar] button 가져오기 실패")
            return
        }

        // 타이틀 설정
        let titleSelector = NSSelectorFromString("setTitle:")
        _ = Self.performSelectorWithObject(on: button, selector: titleSelector, object: "📋" as NSString)

        // 메뉴 생성 및 설정
        createMenu(for: statusItem)

        print("✅ [MenuBar] 메뉴바 아이콘 설정 완료")
    }

    private func createMenu(for statusItem: AnyObject) {
        guard let menuClass = NSClassFromString("NSMenu") else {
            print("❌ [MenuBar] NSMenu 클래스를 찾을 수 없음")
            return
        }

        // NSMenu 생성
        let initSelector = NSSelectorFromString("init")
        guard let menu = Self.performSelector(on: menuClass.alloc() as AnyObject, selector: initSelector) else {
            print("❌ [MenuBar] 메뉴 생성 실패")
            return
        }

        // 메뉴 아이템 추가
        addMenuItem(to: menu, title: "메모 목록", action: #selector(memoListAction), key: "k")
        //addMenuItem(to: menu, title: "새 메모", action: #selector(newMemoAction), key: "n")
        addSeparator(to: menu)
        addMenuItem(to: menu, title: "클립보드 히스토리", action: #selector(clipboardHistoryAction), key: "h")
        addSeparator(to: menu)
        //addMenuItem(to: menu, title: "설정", action: #selector(settingsAction), key: ",")
        addSeparator(to: menu)
        addMenuItem(to: menu, title: "종료", action: #selector(quitAction), key: "q")

        // 메뉴를 statusItem에 연결
        let setMenuSelector = NSSelectorFromString("setMenu:")
        _ = Self.performSelectorWithObject(on: statusItem, selector: setMenuSelector, object: menu)

        print("✅ [MenuBar] 메뉴 생성 완료")
    }

    private func addMenuItem(to menu: AnyObject, title: String, action: Selector, key: String) {
        guard let menuItemClass = NSClassFromString("NSMenuItem") else { return }

        // NSMenuItem 생성
        let allocSelector = NSSelectorFromString("alloc")
        guard let allocMethod = (menuItemClass as AnyObject).method(for: allocSelector) else { return }

        typealias AllocFunction = @convention(c) (AnyObject, Selector) -> AnyObject
        let allocFunc = unsafeBitCast(allocMethod, to: AllocFunction.self)
        let allocated = allocFunc(menuItemClass as AnyObject, allocSelector)

        // 초기화
        let initSelector = NSSelectorFromString("initWithTitle:action:keyEquivalent:")
        typealias InitFunction = @convention(c) (AnyObject, Selector, NSString, Selector, NSString) -> AnyObject
        let initMethod = unsafeBitCast(allocated.method(for: initSelector), to: InitFunction.self)
        let menuItem = initMethod(allocated, initSelector, title as NSString, action, key as NSString)

        // 타겟 설정
        let setTargetSelector = NSSelectorFromString("setTarget:")
        _ = Self.performSelectorWithObject(on: menuItem, selector: setTargetSelector, object: self)

        // 메뉴에 추가
        let addItemSelector = NSSelectorFromString("addItem:")
        _ = Self.performSelectorWithObject(on: menu, selector: addItemSelector, object: menuItem)
    }

    private func addSeparator(to menu: AnyObject) {
        guard let menuItemClass = NSClassFromString("NSMenuItem") else { return }

        let separatorSelector = NSSelectorFromString("separatorItem")
        guard let separator = Self.performSelector(on: menuItemClass as AnyObject, selector: separatorSelector) else {
            return
        }

        let addItemSelector = NSSelectorFromString("addItem:")
        _ = Self.performSelectorWithObject(on: menu, selector: addItemSelector, object: separator)
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

    @objc private func settingsAction() {
        print("⚙️ [MenuBar] 설정 클릭")
        NotificationCenter.default.post(name: .showSettings, object: nil)
        activateApp()
    }

    @objc private func quitAction() {
        print("👋 [MenuBar] 종료")
        exit(0)
    }

    private func activateApp() {
        // 앱을 포그라운드로 가져오기
        guard let applicationClass = NSClassFromString("NSApplication") else { return }

        let sharedSelector = NSSelectorFromString("sharedApplication")
        guard let sharedApp = Self.performSelector(on: applicationClass as AnyObject, selector: sharedSelector) else {
            return
        }

        let activateSelector = NSSelectorFromString("activateIgnoringOtherApps:")
        typealias ActivateFunction = @convention(c) (AnyObject, Selector, Bool) -> Void
        let activateMethod = unsafeBitCast(sharedApp.method(for: activateSelector), to: ActivateFunction.self)
        activateMethod(sharedApp, activateSelector, true)
    }

    // MARK: - Helper Methods

    private static func performSelector(on object: AnyObject, selector: Selector) -> AnyObject? {
        guard object.responds(to: selector) else { return nil }
        return object.perform(selector)?.takeUnretainedValue()
    }

    private static func performSelectorWithObject(on object: AnyObject, selector: Selector, object param: AnyObject) -> AnyObject? {
        guard object.responds(to: selector) else { return nil }
        return object.perform(selector, with: param)?.takeUnretainedValue()
    }

    private static func performSelectorWithCGFloat(on object: AnyObject, selector: Selector, value: CGFloat) -> AnyObject? {
        guard object.responds(to: selector) else { return nil }

        typealias Function = @convention(c) (AnyObject, Selector, CGFloat) -> AnyObject?
        let method = unsafeBitCast(object.method(for: selector), to: Function.self)
        return method(object, selector, value)
    }
}
#endif
