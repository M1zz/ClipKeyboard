//
//  ProStatusManager.swift
//  ClipKeyboard
//
//  Created by Claude on 2026/02/18.
//

import Foundation
import Combine

/// Pro 상태 및 무료 제한 관리
class ProStatusManager: ObservableObject {
    static let shared = ProStatusManager()
    
    // MARK: - 무료 제한 상수
    
    struct FreeLimits {
        static let maxMemos = 5           // 무료 메모 5개
        static let maxClipboardHistory = 30
        static let maxTemplates = 2
    }
    
    // MARK: - Published Properties
    
    @Published var isPro: Bool = false
    
    // MARK: - Private
    
    private let proStatusKey = "com.ysoup.tokenmemo.isPro"
    private let userDefaults = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    private init() {
        loadProStatus()
        
        // StoreManager에서 구매 완료 알림 수신
        NotificationCenter.default.publisher(for: .proStatusChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let isPro = notification.object as? Bool {
                    self?.isPro = isPro
                    self?.saveProStatus()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// 메모를 더 추가할 수 있는지 확인
    func canAddMemo(currentCount: Int) -> Bool {
        return isPro || currentCount < FreeLimits.maxMemos
    }
    
    /// 클립보드 히스토리를 더 저장할 수 있는지 확인
    func canAddClipboardHistory(currentCount: Int) -> Bool {
        return isPro || currentCount < FreeLimits.maxClipboardHistory
    }
    
    /// 템플릿을 더 추가할 수 있는지 확인
    func canAddTemplate(currentCount: Int) -> Bool {
        return isPro || currentCount < FreeLimits.maxTemplates
    }
    
    /// iCloud 백업 사용 가능 여부
    var canUseCloudBackup: Bool {
        return isPro
    }
    
    /// Combo 기능 사용 가능 여부
    var canUseCombo: Bool {
        return isPro
    }
    
    /// 보안 메모 사용 가능 여부
    var canUseSecureMemo: Bool {
        return isPro
    }
    
    /// 남은 무료 메모 개수
    func remainingFreeMemos(currentCount: Int) -> Int {
        if isPro { return Int.max }
        return max(0, FreeLimits.maxMemos - currentCount)
    }
    
    /// Pro 상태 설정 (StoreManager에서 호출)
    func setProStatus(_ isPro: Bool) {
        self.isPro = isPro
        saveProStatus()
        print("✅ [ProStatusManager] Pro 상태 변경: \(isPro)")
    }
    
    /// Pro 상태 복원 (앱 시작 시 또는 구매 복원 시)
    func restoreProStatus() {
        // StoreManager에서 구매 복원 후 호출됨
        loadProStatus()
    }
    
    // MARK: - Private Methods
    
    private func loadProStatus() {
        isPro = userDefaults?.bool(forKey: proStatusKey) ?? false
        print("📥 [ProStatusManager] Pro 상태 로드: \(isPro)")
    }
    
    private func saveProStatus() {
        userDefaults?.set(isPro, forKey: proStatusKey)
        userDefaults?.synchronize()
        print("💾 [ProStatusManager] Pro 상태 저장: \(isPro)")
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let proStatusChanged = Notification.Name("proStatusChanged")
}
