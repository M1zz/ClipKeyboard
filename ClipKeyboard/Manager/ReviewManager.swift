//
//  ReviewManager.swift
//  Token memo
//
//  Created by Claude on 2026/01/29.
//

import Foundation
import StoreKit

#if os(iOS)
import UIKit
#endif

/// 앱 리뷰 요청을 관리하는 매니저
/// Apple의 리뷰 요청 정책을 준수하여 적절한 타이밍에 리뷰를 요청합니다.
class ReviewManager {

    static let shared = ReviewManager()

    // MARK: - UserDefaults Keys (기존)

    private let lastReviewRequestDateKey = "lastReviewRequestDate"
    private let appLaunchCountKey = "appLaunchCount"
    private let memoCreatedCountKey = "memoCreatedCountForReview"
    private let hasRequestedReviewKey = "hasRequestedReview"
    private let hasRespondedToReviewKey = "hasRespondedToReview"

    // MARK: - UserDefaults Keys (새 트리거)

    private let keyFirstPasteReview = "hasRequestedReview_firstPaste"
    private let keyComboReview = "hasRequestedReview_combo"
    private let keyPowerUserReview = "hasRequestedReview_powerUser"
    private let keyInstallDate = "app_install_date"
    private let keyKeyboardUseCount = "keyboard_use_count"
    private let keyClipSaveCount = "clip_save_count"

    // MARK: - Review Request Conditions (기존)

    /// 리뷰 요청 최소 메모 생성 횟수 (Silent Partner 컨셉: 3개)
    private let minimumMemoCount = 3

    /// 리뷰 요청 최소 앱 실행 횟수 (Silent Partner 컨셉: 5회)
    private let minimumLaunchCount = 5

    /// 리뷰 요청 간격 (일)
    private let reviewRequestCooldown: TimeInterval = 90 * 24 * 60 * 60 // 90일

    private init() {
        // 설치일 기록 (최초 1회)
        if UserDefaults.standard.object(forKey: keyInstallDate) == nil {
            UserDefaults.standard.set(Date(), forKey: keyInstallDate)
            print("📊 [ReviewManager] 설치일 기록됨")
        }

        // 공유 파일(MemoStore, ComboExecutionService)에서 보내는 알림 구독
        NotificationCenter.default.addObserver(
            forName: .reviewTriggerComboCompleted, object: nil, queue: .main
        ) { [weak self] _ in
            self?.trackComboCompleted()
        }
        NotificationCenter.default.addObserver(
            forName: .reviewTriggerClipSaved, object: nil, queue: .main
        ) { [weak self] _ in
            self?.trackClipSaved()
        }
    }

    // MARK: - Public Methods (기존)

    /// 앱 실행 시 호출 - 실행 횟수 증가
    func incrementAppLaunchCount() {
        let currentCount = UserDefaults.standard.integer(forKey: appLaunchCountKey)
        UserDefaults.standard.set(currentCount + 1, forKey: appLaunchCountKey)
        print("📊 [ReviewManager] 앱 실행 횟수: \(currentCount + 1)")

        // 키보드 사용 카운트 동기화 (App Group → 표준 UserDefaults)
        syncKeyboardUseCount()
    }

    /// 메모 생성 시 호출 - 메모 생성 횟수 증가
    func incrementMemoCreatedCount() {
        let currentCount = UserDefaults.standard.integer(forKey: memoCreatedCountKey)
        UserDefaults.standard.set(currentCount + 1, forKey: memoCreatedCountKey)
        print("📊 [ReviewManager] 메모 생성 횟수: \(currentCount + 1)")
    }

    /// 리뷰 요청 시트를 표시할지 확인 (앱 실행 시 체크용)
    /// - Returns: 리뷰 요청 시트 표시 여부
    func shouldShowReview() -> Bool {
        // 사용자가 이미 응답했으면 다시 표시하지 않음
        let hasResponded = UserDefaults.standard.bool(forKey: hasRespondedToReviewKey)
        guard !hasResponded else {
            print("✅ [ReviewManager] 사용자가 이미 리뷰에 응답함")
            return false
        }

        // 앱 실행 횟수 확인
        let launchCount = UserDefaults.standard.integer(forKey: appLaunchCountKey)
        guard launchCount >= minimumLaunchCount else {
            print("🚀 [ReviewManager] 앱 실행 횟수 부족: \(launchCount)/\(minimumLaunchCount)")
            return false
        }

        // 메모 개수 확인 (실제 저장된 메모 수)
        let memoCount = (try? MemoStore.shared.load(type: .tokenMemo).count) ?? 0
        guard memoCount >= minimumMemoCount else {
            print("📝 [ReviewManager] 메모 개수 부족: \(memoCount)/\(minimumMemoCount)")
            return false
        }

        print("⭐️ [ReviewManager] 리뷰 요청 조건 충족")
        return true
    }

    /// 사용자가 리뷰 요청에 응답했음을 표시 (나중에/별점 남기기 모두 해당)
    func markReviewResponded() {
        UserDefaults.standard.set(true, forKey: hasRespondedToReviewKey)
        print("✅ [ReviewManager] 리뷰 응답 완료 표시")
    }

    /// 리뷰 요청 조건을 확인하고, 조건이 충족되면 리뷰를 요청합니다.
    /// - Returns: 리뷰 요청 여부
    @discardableResult
    func requestReviewIfAppropriate() -> Bool {
        guard shouldRequestReview() else {
            print("⏭️ [ReviewManager] 리뷰 요청 조건 미충족")
            return false
        }

        print("⭐️ [ReviewManager] 리뷰 요청 조건 충족 - 리뷰 요청")

        // 마지막 리뷰 요청 날짜 저장
        UserDefaults.standard.set(Date(), forKey: lastReviewRequestDateKey)
        UserDefaults.standard.set(true, forKey: hasRequestedReviewKey)

        // StoreKit의 리뷰 요청 (iOS 14+)
        requestSystemReview()

        return true
    }

    // MARK: - New Trigger Methods (최적 트리거)

    /// 키보드에서 붙여넣기 성공 시 호출
    /// 키보드 익스텐션에서 App Group UserDefaults로 기록 후, 메인 앱에서 동기화하여 호출
    func trackKeyboardPaste() {
        let count = UserDefaults.standard.integer(forKey: keyKeyboardUseCount) + 1
        UserDefaults.standard.set(count, forKey: keyKeyboardUseCount)
        print("📊 [ReviewManager] 키보드 사용 횟수: \(count)")

        // 트리거 1: 처음 붙여넣기 성공
        if count == 1 {
            requestReviewOnce(key: keyFirstPasteReview, delay: 2.0)
        }

        // 파워 유저 체크
        checkPowerUserMilestone()
    }

    /// 클립보드 저장 시 호출
    func trackClipSaved() {
        let count = UserDefaults.standard.integer(forKey: keyClipSaveCount) + 1
        UserDefaults.standard.set(count, forKey: keyClipSaveCount)
        print("📊 [ReviewManager] 클립 저장 횟수: \(count)")

        // 파워 유저 체크
        checkPowerUserMilestone()
    }

    /// Combo 완료 시 호출
    func trackComboCompleted() {
        print("📊 [ReviewManager] Combo 완료 트리거")
        requestReviewOnce(key: keyComboReview, delay: 1.5)
    }

    /// 리뷰 배너 표시 여부 확인
    var shouldShowBanner: Bool {
        let dismissed = UserDefaults.standard.bool(forKey: "review_banner_dismissed")
        if dismissed { return false }

        let laterDate = UserDefaults.standard.double(forKey: "review_banner_later_date")
        if laterDate > 0 && Date().timeIntervalSince1970 < laterDate { return false }

        return UserDefaults.standard.integer(forKey: keyClipSaveCount) >= 5
    }

    /// 배너에서 "나중에" 선택
    func dismissBannerTemporarily() {
        let laterDate = Date().addingTimeInterval(7 * 86400).timeIntervalSince1970
        UserDefaults.standard.set(laterDate, forKey: "review_banner_later_date")
        print("📊 [ReviewManager] 배너 7일 후 다시 표시")
    }

    /// 배너에서 "리뷰 남기기" 선택
    func dismissBannerPermanently() {
        UserDefaults.standard.set(true, forKey: "review_banner_dismissed")
        print("📊 [ReviewManager] 배너 영구 닫기")
    }

    // MARK: - Private Methods

    /// 파워 유저 마일스톤 체크
    /// 조건: 클립 10개 이상 + 설치 3일 경과 + 키보드 5회 이상 사용
    private func checkPowerUserMilestone() {
        guard !UserDefaults.standard.bool(forKey: keyPowerUserReview) else { return }

        guard let installDate = UserDefaults.standard.object(forKey: keyInstallDate) as? Date,
              Date().timeIntervalSince(installDate) > 3 * 86400 else { return }

        guard UserDefaults.standard.integer(forKey: keyKeyboardUseCount) >= 5 else { return }
        guard UserDefaults.standard.integer(forKey: keyClipSaveCount) >= 10 else { return }

        print("⭐️ [ReviewManager] 파워 유저 마일스톤 달성!")
        requestReviewOnce(key: keyPowerUserReview, delay: 1.0)
    }

    /// 특정 트리거에 대해 1회만 리뷰 요청
    private func requestReviewOnce(key: String, delay: TimeInterval) {
        guard !UserDefaults.standard.bool(forKey: key) else {
            print("⏭️ [ReviewManager] 이미 요청됨: \(key)")
            return
        }
        UserDefaults.standard.set(true, forKey: key)
        print("⭐️ [ReviewManager] 리뷰 요청 예약: \(key) (딜레이: \(delay)s)")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.requestSystemReview()
        }
    }

    /// StoreKit 시스템 리뷰 요청
    private func requestSystemReview() {
        #if os(iOS)
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
            print("⭐️ [ReviewManager] 시스템 리뷰 다이얼로그 요청됨")
        }
        #endif
    }

    /// 키보드 익스텐션의 사용 카운트를 App Group에서 동기화
    private func syncKeyboardUseCount() {
        guard let groupDefaults = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo") else { return }

        let groupCount = groupDefaults.integer(forKey: "keyboard_paste_count")
        let localCount = UserDefaults.standard.integer(forKey: keyKeyboardUseCount)

        if groupCount > localCount {
            let diff = groupCount - localCount
            print("📊 [ReviewManager] 키보드 사용 \(diff)회 동기화 (App Group → Local)")

            for _ in 0..<diff {
                trackKeyboardPaste()
            }
        }
    }

    /// 리뷰 요청 조건을 확인합니다. (기존 조건 기반)
    private func shouldRequestReview() -> Bool {
        // 1. 메모 생성 횟수 확인
        let memoCount = UserDefaults.standard.integer(forKey: memoCreatedCountKey)
        guard memoCount >= minimumMemoCount else {
            print("📝 [ReviewManager] 메모 생성 횟수 부족: \(memoCount)/\(minimumMemoCount)")
            return false
        }

        // 2. 앱 실행 횟수 확인
        let launchCount = UserDefaults.standard.integer(forKey: appLaunchCountKey)
        guard launchCount >= minimumLaunchCount else {
            print("🚀 [ReviewManager] 앱 실행 횟수 부족: \(launchCount)/\(minimumLaunchCount)")
            return false
        }

        // 3. 쿨다운 기간 확인
        if let lastRequestDate = UserDefaults.standard.object(forKey: lastReviewRequestDateKey) as? Date {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequestDate)
            guard timeSinceLastRequest >= reviewRequestCooldown else {
                let daysRemaining = Int((reviewRequestCooldown - timeSinceLastRequest) / (24 * 60 * 60))
                print("⏰ [ReviewManager] 쿨다운 기간 중: \(daysRemaining)일 남음")
                return false
            }
        }

        return true
    }

    /// 리뷰 요청 통계 정보 반환 (디버깅용)
    func getReviewRequestInfo() -> String {
        let memoCount = UserDefaults.standard.integer(forKey: memoCreatedCountKey)
        let launchCount = UserDefaults.standard.integer(forKey: appLaunchCountKey)
        let hasRequested = UserDefaults.standard.bool(forKey: hasRequestedReviewKey)
        let lastRequestDate = UserDefaults.standard.object(forKey: lastReviewRequestDateKey) as? Date
        let keyboardUseCount = UserDefaults.standard.integer(forKey: keyKeyboardUseCount)
        let clipSaveCount = UserDefaults.standard.integer(forKey: keyClipSaveCount)

        var info = """
        📊 리뷰 요청 통계
        - 메모 생성 횟수: \(memoCount)/\(minimumMemoCount)
        - 앱 실행 횟수: \(launchCount)/\(minimumLaunchCount)
        - 키보드 사용 횟수: \(keyboardUseCount)
        - 클립 저장 횟수: \(clipSaveCount)
        - 리뷰 요청 여부: \(hasRequested ? "예" : "아니오")
        """

        if let lastDate = lastRequestDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            info += "\n- 마지막 요청: \(formatter.string(from: lastDate))"
        }

        return info
    }

    /// 리뷰 요청 데이터 초기화 (디버깅용)
    func resetReviewRequestData() {
        UserDefaults.standard.removeObject(forKey: lastReviewRequestDateKey)
        UserDefaults.standard.removeObject(forKey: appLaunchCountKey)
        UserDefaults.standard.removeObject(forKey: memoCreatedCountKey)
        UserDefaults.standard.removeObject(forKey: hasRequestedReviewKey)
        UserDefaults.standard.removeObject(forKey: keyFirstPasteReview)
        UserDefaults.standard.removeObject(forKey: keyComboReview)
        UserDefaults.standard.removeObject(forKey: keyPowerUserReview)
        UserDefaults.standard.removeObject(forKey: keyKeyboardUseCount)
        UserDefaults.standard.removeObject(forKey: keyClipSaveCount)
        UserDefaults.standard.removeObject(forKey: "review_banner_dismissed")
        UserDefaults.standard.removeObject(forKey: "review_banner_later_date")
        print("🔄 [ReviewManager] 리뷰 요청 데이터 초기화 완료")
    }
}
