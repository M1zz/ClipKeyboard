//
//  ComboExecutionService.swift
//  Token memo
//
//  Created by Claude Code on 2025-12-06.
//  Phase 2: Combo Execution Service
//

import Foundation
import UIKit
import Combine

/// Combo 실행 상태
enum ComboExecutionState: Equatable {
    case idle
    case running(currentIndex: Int, totalCount: Int)
    case paused(currentIndex: Int)
    case completed
    case error(String)
}

/// Combo 실행 서비스
class ComboExecutionService: ObservableObject {
    static let shared = ComboExecutionService()

    @Published var state: ComboExecutionState = .idle
    @Published var currentItemIndex: Int = 0

    private var timer: Timer?
    private var currentCombo: Combo?
    private var currentItems: [ComboItem] = []

    private init() {}

    /// Combo 실행 시작
    /// - Parameter combo: 실행할 Combo
    func startCombo(_ combo: Combo) {
        guard state == .idle else {
            print("⚠️ Combo가 이미 실행 중입니다")
            return
        }

        currentCombo = combo
        currentItems = combo.items.sorted(by: { $0.order < $1.order })
        currentItemIndex = 0

        print("🎬 Combo '\(combo.title)' 실행 시작 (\(currentItems.count)개 항목, \(combo.interval)초 간격)")

        // 첫 번째 항목 즉시 실행
        executeCurrentItem()

        // 타이머 시작 (두 번째 항목부터)
        if currentItems.count > 1 {
            state = .running(currentIndex: 0, totalCount: currentItems.count)
            startTimer(interval: combo.interval)
        } else {
            // 항목이 1개면 바로 완료
            completeExecution()
        }
    }

    /// Combo 일시정지
    func pauseCombo() {
        guard case .running = state else { return }
        timer?.invalidate()
        timer = nil
        state = .paused(currentIndex: currentItemIndex)
        print("⏸ Combo 일시정지")
    }

    /// Combo 재개
    func resumeCombo() {
        guard case .paused = state, let combo = currentCombo else { return }
        state = .running(currentIndex: currentItemIndex, totalCount: currentItems.count)
        startTimer(interval: combo.interval)
        print("▶️ Combo 재개")
    }

    /// Combo 중지
    func stopCombo() {
        timer?.invalidate()
        timer = nil
        currentCombo = nil
        currentItems = []
        currentItemIndex = 0
        state = .idle
        print("⏹ Combo 중지")
    }

    // MARK: - Private Methods

    private func startTimer(interval: TimeInterval) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.executeNextItem()
        }
    }

    private func executeCurrentItem() {
        guard currentItemIndex < currentItems.count else {
            completeExecution()
            return
        }

        let item = currentItems[currentItemIndex]
        print("📋 [\(currentItemIndex + 1)/\(currentItems.count)] 실행 중: \(item.type.rawValue)")

        do {
            if let value = try MemoStore.shared.getComboItemValue(item) {
                // 클립보드에 복사
                UIPasteboard.general.string = value
                print("✅ 클립보드에 복사됨: \(value.prefix(50))...")

                // 알림 발송 (옵션)
                postNotification(for: item, value: value)
            } else {
                print("⚠️ 항목의 값을 가져올 수 없음")
            }
        } catch {
            print("❌ 항목 실행 실패: \(error)")
            state = .error(error.localizedDescription)
            stopCombo()
        }
    }

    private func executeNextItem() {
        currentItemIndex += 1

        if currentItemIndex < currentItems.count {
            state = .running(currentIndex: currentItemIndex, totalCount: currentItems.count)
            executeCurrentItem()
        } else {
            completeExecution()
        }
    }

    private func completeExecution() {
        timer?.invalidate()
        timer = nil
        state = .completed

        // 사용 횟수 증가
        if let combo = currentCombo {
            do {
                try MemoStore.shared.incrementComboUseCount(id: combo.id)
                print("🎉 Combo '\(combo.title)' 완료!")
            } catch {
                print("⚠️ 사용 횟수 업데이트 실패: \(error)")
            }
        }

        // 3초 후 상태 초기화
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if case .completed = self?.state {
                self?.stopCombo()
            }
        }
    }

    private func postNotification(for item: ComboItem, value: String) {
        NotificationCenter.default.post(
            name: .comboItemExecuted,
            object: nil,
            userInfo: [
                "itemType": item.type.rawValue,
                "value": value,
                "index": currentItemIndex,
                "total": currentItems.count
            ]
        )
    }

    /// 진행률 계산
    var progress: Double {
        guard currentItems.count > 0 else { return 0 }
        return Double(currentItemIndex) / Double(currentItems.count)
    }

    /// 현재 실행 중인 항목
    var currentItem: ComboItem? {
        guard currentItemIndex < currentItems.count else { return nil }
        return currentItems[currentItemIndex]
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let comboItemExecuted = Notification.Name("comboItemExecuted")
    static let comboCompleted = Notification.Name("comboCompleted")
}
