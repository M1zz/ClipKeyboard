//
//  DataManagerTests.swift
//  ClipKeyboardTests
//
//  레거시 DataManager 영속성 테스트.
//  - 온보딩/유스케이스 선택 플래그가 UserDefaults에 동기화되는지
//  - textEntries가 App Group UserDefaults에 저장되는지
//

import XCTest
@testable import ClipKeyboard

final class DataManagerTests: XCTestCase {

    // 다른 테스트의 영속 상태에 영향을 주지 않도록 원래 값을 백업/복원
    private var originalOnboarding: Bool = false
    private var originalUseCase: Bool = false
    private var originalEntries: [String]?

    override func setUp() {
        super.setUp()
        originalOnboarding = UserDefaults.standard.bool(forKey: "onboarding")
        originalUseCase = UserDefaults.standard.bool(forKey: "useCaseSelection")
        originalEntries = UserDefaults(suiteName: AppConfig.appGroup)?.stringArray(forKey: "entries")
    }

    override func tearDown() {
        UserDefaults.standard.set(originalOnboarding, forKey: "onboarding")
        UserDefaults.standard.set(originalUseCase, forKey: "useCaseSelection")
        if let entries = originalEntries {
            UserDefaults(suiteName: AppConfig.appGroup)?.set(entries, forKey: "entries")
        } else {
            UserDefaults(suiteName: AppConfig.appGroup)?.removeObject(forKey: "entries")
        }
        super.tearDown()
    }

    // MARK: - Onboarding 플래그

    func testDidShowOnboarding_WriteThrough() {
        let manager = DataManager()
        manager.didShowOnboarding = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "onboarding"))

        manager.didShowOnboarding = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "onboarding"))
    }

    func testDidShowUseCaseSelection_WriteThrough() {
        let manager = DataManager()
        manager.didShowUseCaseSelection = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "useCaseSelection"))

        manager.didShowUseCaseSelection = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "useCaseSelection"))
    }

    // MARK: - textEntries

    func testTextEntries_PersistToAppGroup() {
        let manager = DataManager()
        manager.textEntries = ["entry1", "entry2"]

        let stored = UserDefaults(suiteName: AppConfig.appGroup)?.stringArray(forKey: "entries")
        XCTAssertEqual(stored, ["entry1", "entry2"])
    }

    func testTextEntries_LoadOnInit() {
        UserDefaults(suiteName: AppConfig.appGroup)?.set(["preset1", "preset2", "preset3"], forKey: "entries")

        let manager = DataManager()
        XCTAssertEqual(manager.textEntries, ["preset1", "preset2", "preset3"])
    }

    // MARK: - AppConfig 상수

    func testAppGroup_ExpectedValue() {
        XCTAssertEqual(AppConfig.appGroup, "group.com.Ysoup.TokenMemo")
    }

    func testEmailSupport_NotEmpty() {
        XCTAssertFalse(AppConfig.emailSupport.isEmpty)
        XCTAssertTrue(AppConfig.emailSupport.contains("@"))
    }
}
