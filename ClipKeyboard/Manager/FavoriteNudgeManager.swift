//
//  FavoriteNudgeManager.swift
//  ClipKeyboard
//
//  Created by Claude on 2026/02/18.
//

import Foundation

/// 즐겨찾기 넛지 애니메이션 상태 관리
/// - 최대 3회 노출 후 자동 종료
/// - 즐겨찾기 1개 등록 시 종료
/// - 최초 설치 또는 새 버전 업데이트 시 노출
class FavoriteNudgeManager {
    static let shared = FavoriteNudgeManager()

    private let nudgeCountKey = "favoriteNudgeShownCount"
    private let nudgeVersionKey = "favoriteNudgeVersion"
    private let maxNudgeCount = 3
    private let nudgeTargetVersion = "3.1.3"

    // ReviewManager에서 사용하는 동일한 키
    private let keyInstallDate = "app_install_date"

    private init() {}

    // MARK: - Public Methods

    /// 넛지를 표시해야 하는지 여부
    var shouldShowNudge: Bool {
        // 1) 이미 즐겨찾기가 있으면 표시 안 함
        if MemoStore.shared.hasFavoriteMemo() { return false }

        // 2) 3회 이상 노출했으면 표시 안 함
        if shownCount >= maxNudgeCount { return false }

        // 3) 최초 설치(7일 이내) 또는 이 버전이 처음인 경우
        return isRecentInstall || isNewVersion
    }

    /// 넛지 노출 횟수 기록
    func recordNudgeShown() {
        let current = shownCount
        UserDefaults.standard.set(current + 1, forKey: nudgeCountKey)
        print("💝 [FavoriteNudgeManager] 넛지 노출 기록: \(current + 1)/\(maxNudgeCount)")

        // 현재 버전 기록
        UserDefaults.standard.set(currentAppVersion, forKey: nudgeVersionKey)
    }

    /// 버전 변경 시 카운트 리셋
    func resetIfNeeded() {
        let savedVersion = UserDefaults.standard.string(forKey: nudgeVersionKey) ?? ""
        if savedVersion != nudgeTargetVersion {
            UserDefaults.standard.set(0, forKey: nudgeCountKey)
            print("🔄 [FavoriteNudgeManager] 버전 변경 감지 (\(savedVersion) → \(nudgeTargetVersion)) - 카운트 리셋")
        }
    }

    // MARK: - Private Helpers

    /// 현재까지 노출된 횟수
    private var shownCount: Int {
        return UserDefaults.standard.integer(forKey: nudgeCountKey)
    }

    /// 최초 설치 후 7일 이내인지 확인
    private var isRecentInstall: Bool {
        guard let installDate = UserDefaults.standard.object(forKey: keyInstallDate) as? Date else {
            // 설치 날짜가 없으면 최초 설치로 간주
            return true
        }
        let daysSinceInstall = Date().timeIntervalSince(installDate) / 86400
        return daysSinceInstall <= 7
    }

    /// 새 버전인지 확인 (nudgeTargetVersion과 저장된 버전 비교)
    private var isNewVersion: Bool {
        let savedVersion = UserDefaults.standard.string(forKey: nudgeVersionKey) ?? ""
        return savedVersion != nudgeTargetVersion
    }

    /// 현재 앱 버전
    private var currentAppVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}
