//
//  ReviewManagerTests.swift
//  ClipKeyboardTests
//
//  ReviewManager 카운트 영속 + 트리거 룰 테스트.
//  주의: 실제 SKStoreReviewController.requestReview는 외부 다이얼로그를 띄우므로 호출되더라도
//        시뮬레이터/CI에서는 빈도 제한 등 시스템 정책에 의해 무시된다. 여기서는 카운트 추적과
//        조건부 가드만 검증한다.
//

import XCTest
@testable import ClipKeyboard

final class ReviewManagerTests: XCTestCase {

    var sut: ReviewManager!

    override func setUp() {
        super.setUp()
        sut = ReviewManager.shared
        // 깨끗한 시작점 - resetReviewRequestData는 hasRespondedToReview를 클리어하지 않으므로 직접 제거
        sut.resetReviewRequestData()
        UserDefaults.standard.removeObject(forKey: "hasRespondedToReview")
    }

    override func tearDown() {
        sut.resetReviewRequestData()
        UserDefaults.standard.removeObject(forKey: "hasRespondedToReview")
        sut = nil
        super.tearDown()
    }

    // MARK: - 카운트 증가

    func testIncrementAppLaunchCount() {
        let before = UserDefaults.standard.integer(forKey: "appLaunchCount")
        sut.incrementAppLaunchCount()
        let after = UserDefaults.standard.integer(forKey: "appLaunchCount")
        XCTAssertEqual(after, before + 1)
    }

    func testIncrementMemoCreatedCount() {
        let before = UserDefaults.standard.integer(forKey: "memoCreatedCountForReview")
        sut.incrementMemoCreatedCount()
        let after = UserDefaults.standard.integer(forKey: "memoCreatedCountForReview")
        XCTAssertEqual(after, before + 1)
    }

    func testTrackKeyboardPaste_IncrementsCount() {
        let before = UserDefaults.standard.integer(forKey: "keyboard_use_count")
        sut.trackKeyboardPaste()
        let after = UserDefaults.standard.integer(forKey: "keyboard_use_count")
        XCTAssertEqual(after, before + 1)
    }

    func testTrackClipSaved_IncrementsCount() {
        let before = UserDefaults.standard.integer(forKey: "clip_save_count")
        sut.trackClipSaved()
        let after = UserDefaults.standard.integer(forKey: "clip_save_count")
        XCTAssertEqual(after, before + 1)
    }

    // MARK: - 응답 표시

    func testMarkReviewResponded_PersistsFlag() {
        sut.markReviewResponded()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasRespondedToReview"))
    }

    // MARK: - shouldShowReview 조건

    func testShouldShowReview_NotEnoughLaunches_False() {
        // 응답 안 됐고, 앱 실행 카운트 0이면 false
        XCTAssertFalse(sut.shouldShowReview())
    }

    func testShouldShowReview_AlreadyResponded_False() {
        sut.markReviewResponded()
        for _ in 0..<10 { sut.incrementAppLaunchCount() }
        XCTAssertFalse(sut.shouldShowReview(), "응답 완료 사용자에게는 다시 안 띄움")
    }

    // MARK: - 디버그 정보

    func testGetReviewRequestInfo_ReturnsString() {
        let info = sut.getReviewRequestInfo()
        XCTAssertFalse(info.isEmpty)
        XCTAssertTrue(info.contains("리뷰 요청 통계"))
    }

    // MARK: - 붙여넣기 경험 게이트
    //
    // 별점을 물어도 되는 사람인지 가리는 단 하나의 조건이다.
    // 앱 실행·단축어 생성만으로는 아직 값을 받은 게 아니라서 묻지 않는다.

    func testHasPastedFromKeyboard_FalseUntilFirstPaste() {
        AppGroup.defaults?.removeObject(forKey: DefaultsKey.keyboardPasteCount)
        XCTAssertFalse(sut.hasPastedFromKeyboard)

        sut.trackKeyboardPaste()
        XCTAssertTrue(sut.hasPastedFromKeyboard)
    }

    func testRequestReviewIfAppropriate_BlockedBeforeFirstPaste() {
        AppGroup.defaults?.removeObject(forKey: DefaultsKey.keyboardPasteCount)
        // 기존 조건(단축어 3개 + 실행 5회)은 모두 채운다
        for _ in 0..<3 { sut.incrementMemoCreatedCount() }
        for _ in 0..<5 { sut.incrementAppLaunchCount() }

        XCTAssertFalse(sut.requestReviewIfAppropriate())
        // 쿨다운·요청 플래그를 태우지 않았는지 - 붙여넣기 뒤에 다시 물을 수 있어야 한다
        XCTAssertNil(UserDefaults.standard.object(forKey: "lastReviewRequestDate"))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasRequestedReview"))
    }

    func testStackTrigger_DoesNotBurnFlagBeforeFirstPaste() {
        AppGroup.defaults?.removeObject(forKey: DefaultsKey.keyboardPasteCount)
        sut.trackStackCompleted()
        // 아직 자격이 없으므로 플래그도 세우지 않는다 (나중에 기회가 남아 있어야 한다)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasRequestedReview_combo"))

        sut.trackKeyboardPaste()
        sut.trackStackCompleted()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasRequestedReview_combo"))
    }

    // MARK: - 트리거 1회 한정성

    func testFirstPaste_OnlyMarkedOnce() {
        sut.trackKeyboardPaste()  // 1회 → firstPaste 트리거 발동
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasRequestedReview_firstPaste"))

        // 이후 호출은 새로 발동하지 않음 (UserDefaults 플래그 유지)
        sut.trackKeyboardPaste()
        sut.trackKeyboardPaste()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasRequestedReview_firstPaste"))
    }

    func testTrackStackCompleted_MarksFlag() {
        sut.trackKeyboardPaste()  // 리뷰 요청의 전제 조건
        sut.trackStackCompleted()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasRequestedReview_combo"))
    }

    // MARK: - reset

    func testResetReviewRequestData_ClearsAllKeys() {
        sut.incrementAppLaunchCount()
        sut.incrementMemoCreatedCount()
        sut.trackKeyboardPaste()
        sut.trackClipSaved()
        sut.markReviewResponded()

        sut.resetReviewRequestData()

        XCTAssertEqual(UserDefaults.standard.integer(forKey: "appLaunchCount"), 0)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "memoCreatedCountForReview"), 0)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "keyboard_use_count"), 0)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "clip_save_count"), 0)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasRequestedReview_firstPaste"))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasRequestedReview_combo"))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasRequestedReview_powerUser"))
        XCTAssertNil(UserDefaults.standard.object(forKey: "review.purchase.launchCount"))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasLeftReview"))
    }

    // MARK: - 결제 뒤 (2026-11)

    /// 돈을 낸 사람에게 별점을 안 묻고 있었다. 결제한 **다음** 실행에 한 번 묻는다.
    func test_결제한_다음_실행에_별점을_묻는다() {
        sut.trackKeyboardPaste()                       // 붙여넣기 경험은 있어야 한다
        sut.incrementAppLaunchCount()                  // 실행 1회, 단축어 0개: 기존 조건은 못 채운다
        XCTAssertFalse(sut.shouldShowReview(), "결제 전에는 기존 조건대로 안 묻는다")

        sut.trackPurchase(productID: "com.Ysoup.TokenMemo.pro")
        XCTAssertFalse(sut.shouldShowReview(), "결제한 바로 그 실행에는 묻지 않는다")

        sut.incrementAppLaunchCount()                  // 다음 실행
        XCTAssertTrue(sut.shouldShowReview(), "실행 횟수 · 단축어 개수와 상관없이 묻는다")
    }

    func test_결제했어도_붙여넣기_경험이_없으면_안_묻는다() {
        AppGroup.defaults?.removeObject(forKey: DefaultsKey.keyboardPasteCount)
        sut.incrementAppLaunchCount()
        sut.trackPurchase(productID: "com.Ysoup.TokenMemo.plus.yearly")
        sut.incrementAppLaunchCount()
        XCTAssertFalse(sut.shouldShowReview())
    }

    func test_나중에_라고_했던_사람에게도_결제_뒤에는_한_번_더_묻는다() {
        sut.trackKeyboardPaste()
        sut.markReviewResponded()                      // "나중에"
        sut.incrementAppLaunchCount()
        sut.trackPurchase(productID: "com.Ysoup.TokenMemo.pro")
        sut.incrementAppLaunchCount()
        XCTAssertTrue(sut.shouldShowReview())
    }

    func test_별점을_남긴_사람에게는_결제_뒤에도_안_묻는다() {
        sut.trackKeyboardPaste()
        sut.markReviewResponded(leftReview: true)
        sut.incrementAppLaunchCount()
        sut.trackPurchase(productID: "com.Ysoup.TokenMemo.pro")
        sut.incrementAppLaunchCount()
        XCTAssertFalse(sut.shouldShowReview())
        XCTAssertNil(UserDefaults.standard.object(forKey: "review.purchase.launchCount"), "트리거 자체를 세우지 않는다")
    }

    func test_결제_트리거는_시트를_띄우면_한_번으로_끝난다() {
        sut.trackKeyboardPaste()
        sut.incrementAppLaunchCount()
        sut.trackPurchase(productID: "com.Ysoup.TokenMemo.pro")
        sut.incrementAppLaunchCount()
        XCTAssertTrue(sut.shouldShowReview())

        sut.noteReviewSheetShown()                     // 실행 창이 띄웠다
        sut.markReviewResponded()                      // "나중에"
        sut.incrementAppLaunchCount()
        XCTAssertFalse(sut.shouldShowReview(), "다음 실행마다 또 뜨지 않는다")
    }

    func test_두_번_사도_한_번만_묻는다() {
        sut.trackKeyboardPaste()
        sut.incrementAppLaunchCount()
        sut.trackPurchase(productID: "com.Ysoup.TokenMemo.slots5")
        sut.incrementAppLaunchCount()
        sut.trackPurchase(productID: "com.Ysoup.TokenMemo.pro.upgrade")  // 같은 실행에 하나 더 샀다
        XCTAssertTrue(sut.shouldShowReview(), "첫 결제 기준으로 이미 다음 실행이다. 둘째 결제가 미루지 않는다")
    }
}
