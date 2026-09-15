//
//  UserStageSimulatorRestoreTests.swift
//  ClipKeyboardTests
//
//  단계를 끄면 **내 카테고리가 그대로 돌아오는가.**
//
//  이 시험이 있는 이유: 처음 만들 때 목록만 되돌리고 스위치를 빠뜨렸다. 되돌렸는데도
//  화면에서는 카테고리가 사라진 것으로 보였고, 쓰는 사람에게는 자기 카테고리가 지워진
//  것과 구별되지 않았다. 되돌리는 일은 **원래 있던 자리까지** 되돌려야 끝난 것이다.
//

import XCTest
@testable import ClipKeyboard

final class UserStageSimulatorRestoreTests: XCTestCase {

    private var defaults: UserDefaults? { AppGroup.defaults }

    private var savedCategories: [String]?
    private var savedFeature: Any?

    override func setUp() {
        super.setUp()
        savedCategories = defaults?.stringArray(forKey: DefaultsKey.userDefinedCategoriesV1)
        savedFeature = defaults?.object(forKey: DefaultsKey.categoryFeatureEnabledV1)
        defaults?.removeObject(forKey: DefaultsKey.userStageCategoryBackup)
        defaults?.removeObject(forKey: DefaultsKey.userStageCategoryFeatureBackup)
    }

    override func tearDown() {
        if let savedCategories {
            defaults?.set(savedCategories, forKey: DefaultsKey.userDefinedCategoriesV1)
        } else {
            defaults?.removeObject(forKey: DefaultsKey.userDefinedCategoriesV1)
        }
        if let savedFeature {
            defaults?.set(savedFeature, forKey: DefaultsKey.categoryFeatureEnabledV1)
        } else {
            defaults?.removeObject(forKey: DefaultsKey.categoryFeatureEnabledV1)
        }
        defaults?.removeObject(forKey: DefaultsKey.userStageCategoryBackup)
        defaults?.removeObject(forKey: DefaultsKey.userStageCategoryFeatureBackup)
        super.tearDown()
    }

    /// 카테고리를 쓰던 사람의 것이 목록도 스위치도 그대로 돌아온다.
    func testRestoresBothTheListAndTheSwitch() {
        defaults?.set(["업무", "개인"], forKey: DefaultsKey.userDefinedCategoriesV1)
        defaults?.set(true, forKey: DefaultsKey.categoryFeatureEnabledV1)

        UserStageSimulator.backupCategoriesForTesting()
        UserStageSimulator.applyCategoriesForTesting([])   // 카테고리 없는 단계를 흉내 낸다
        XCTAssertEqual(defaults?.stringArray(forKey: DefaultsKey.userDefinedCategoriesV1), [])
        XCTAssertEqual(defaults?.bool(forKey: DefaultsKey.categoryFeatureEnabledV1), false)

        UserStageSimulator.restoreCategoriesForTesting()
        XCTAssertEqual(defaults?.stringArray(forKey: DefaultsKey.userDefinedCategoriesV1), ["업무", "개인"])
        XCTAssertEqual(defaults?.bool(forKey: DefaultsKey.categoryFeatureEnabledV1), true)
    }

    /// **값이 없던 것은 없던 대로 돌려놓는다.**
    ///
    /// 이 스위치는 값이 아예 없으면 켜진 것으로 친다. 없던 것을 false 로 적어 두면
    /// 되돌릴 때 "사용자가 직접 껐다" 로 굳어, 원래 보이던 카테고리가 사라진다.
    func testRestoresTheAbsentSwitchAsAbsent() {
        defaults?.set(["업무"], forKey: DefaultsKey.userDefinedCategoriesV1)
        defaults?.removeObject(forKey: DefaultsKey.categoryFeatureEnabledV1)

        UserStageSimulator.backupCategoriesForTesting()
        UserStageSimulator.applyCategoriesForTesting([])
        UserStageSimulator.restoreCategoriesForTesting()

        // ⚠️ 키가 비어 있기를 요구하지 않는다. `CategoryStore` 는 값이 없으면 켜진 것으로
        //    보고 **그 자리에서 적어 둔다**(키보드 익스텐션이 이 키를 직접 읽기 때문이다).
        //    그래서 확인할 것은 저장 모양이 아니라 **결과**다. 원래 켜져 있던 사람에게
        //    카테고리가 다시 보이는가.
        let stored = defaults?.object(forKey: DefaultsKey.categoryFeatureEnabledV1) as? Bool
        XCTAssertNotEqual(stored, false,
                          "없던 값을 false 로 남기면 원래 보이던 카테고리가 사라진다")
        CategoryStore.shared.reloadFeatureState()
        XCTAssertTrue(CategoryStore.shared.isFeatureEnabled)
    }

    /// 단계를 여러 번 옮겨 다녀도 **처음 것**이 원본이다.
    func testKeepsTheFirstBackupWhileHoppingStages() {
        defaults?.set(["업무", "개인"], forKey: DefaultsKey.userDefinedCategoriesV1)
        defaults?.set(true, forKey: DefaultsKey.categoryFeatureEnabledV1)

        UserStageSimulator.backupCategoriesForTesting()
        UserStageSimulator.applyCategoriesForTesting(["여행"])
        UserStageSimulator.backupCategoriesForTesting()      // 두 번째 단계
        UserStageSimulator.applyCategoriesForTesting([])
        UserStageSimulator.restoreCategoriesForTesting()

        XCTAssertEqual(defaults?.stringArray(forKey: DefaultsKey.userDefinedCategoriesV1), ["업무", "개인"],
                       "시뮬레이터가 깔아 준 것이 원본으로 굳으면 안 된다")
    }
}
