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
    private init() {}

    // MARK: - UserDefaults Keys

    private let lastReviewRequestDateKey = "lastReviewRequestDate"
    private let appLaunchCountKey = "appLaunchCount"
    private let memoCreatedCountKey = "memoCreatedCountForReview"
    private let hasRequestedReviewKey = "hasRequestedReview"

    // MARK: - Review Request Conditions

    /// 리뷰 요청 최소 메모 생성 횟수
    private let minimumMemoCount = 10

    /// 리뷰 요청 최소 앱 실행 횟수
    private let minimumLaunchCount = 5

    /// 리뷰 요청 간격 (일)
    private let reviewRequestCooldown: TimeInterval = 90 * 24 * 60 * 60 // 90일

    // MARK: - Public Methods

    /// 앱 실행 시 호출 - 실행 횟수 증가
    func incrementAppLaunchCount() {
        let currentCount = UserDefaults.standard.integer(forKey: appLaunchCountKey)
        UserDefaults.standard.set(currentCount + 1, forKey: appLaunchCountKey)
        print("📊 [ReviewManager] 앱 실행 횟수: \(currentCount + 1)")
    }

    /// 메모 생성 시 호출 - 메모 생성 횟수 증가
    func incrementMemoCreatedCount() {
        let currentCount = UserDefaults.standard.integer(forKey: memoCreatedCountKey)
        UserDefaults.standard.set(currentCount + 1, forKey: memoCreatedCountKey)
        print("📊 [ReviewManager] 메모 생성 횟수: \(currentCount + 1)")
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
        #if os(iOS)
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
        #endif

        return true
    }

    /// 리뷰 요청 조건을 확인합니다.
    /// - Returns: 리뷰 요청 가능 여부
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

        var info = """
        📊 리뷰 요청 통계
        - 메모 생성 횟수: \(memoCount)/\(minimumMemoCount)
        - 앱 실행 횟수: \(launchCount)/\(minimumLaunchCount)
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
        print("🔄 [ReviewManager] 리뷰 요청 데이터 초기화 완료")
    }
}
