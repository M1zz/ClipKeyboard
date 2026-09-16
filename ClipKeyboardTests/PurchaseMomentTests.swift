//
//  PurchaseMomentTests.swift
//  ClipKeyboardTests
//
//  결제 순간이 **언제 오고 언제 안 오는지**를 못박는다.
//
//  왜 시험으로 붙잡는가: 이 판정이 틀리면 두 방향 모두 사고다.
//   · 너무 자주 오면 → 결제 창이 따라다니는 앱이 된다. 순간은 각각 평생 한 번이어야 한다.
//   · 안 오면       → 정작 알려야 할 때(백업이 없다, 가려야 할 것이 들어 있다) 말을 못 한다.
//
//  판정을 순수 함수로 떼어 둔 이유가 이것이라, 그 계약을 여기서 고정한다.
//  (상태를 읽는 `dueMomentNow` 는 App Group 에 남은 값에 흔들리므로 시험하지 않는다.
//   반값 제안에서 실제로 그랬다. `DiscountOfferManagerTests` 의 같은 자리 참고.)
//

import Testing
import Foundation
@testable import ClipKeyboard

@Suite("PurchaseMoment, 결제가 말이 되는 자리")
struct PurchaseMomentTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func hoursAgo(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }
    private func daysAgo(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }

    /// 기본은 "아무 일도 없는" 무료 사용자. 각 시험은 한 조건만 바꿔 그 조건의 힘을 본다.
    private func due(hasPro: Bool = false,
                     hasSync: Bool = false,
                     shown: Set<PurchaseMoment> = [],
                     sensitiveHoursAgo: Double? = nil,
                     devices: Int = 1,
                     memos: Int = 0,
                     backupDaysAgo: Double? = nil,
                     installedDaysAgo: Double? = 60) -> PurchaseMoment? {
        PurchaseMomentManager.dueMoment(now: now, context: .init(
            hasPro: hasPro,
            hasSync: hasSync,
            shownMoments: shown,
            sensitiveSavedAt: sensitiveHoursAgo.map { hoursAgo($0) },
            knownDeviceCount: devices,
            ownMemoCount: memos,
            lastBackupAt: backupDaysAgo.map { daysAgo($0) },
            installedAt: installedDaysAgo.map { daysAgo($0) }
        ))
    }

    // MARK: - 아무 일도 없을 때

    @Test("평소에는 아무 말도 하지 않는다")
    func silentByDefault() {
        #expect(due() == nil)
    }

    @Test("이미 Pro 인 사람에게는 팔 것이 없다")
    func nothingToSellToProUsers() {
        #expect(due(hasPro: true, sensitiveHoursAgo: 1) == nil)
        #expect(due(hasPro: true, memos: 50, backupDaysAgo: nil) == nil)
    }

    // MARK: - 가려야 할 것을 저장했다

    @Test("방금 저장했으면 생체잠금을 권한다")
    func offersLockRightAfterSaving() {
        #expect(due(sensitiveHoursAgo: 0) == .sensitiveSaved)
        #expect(due(sensitiveHoursAgo: 23) == .sensitiveSaved)
    }

    /// 불안은 저장하는 그 순간 가장 크고 하루가 지나면 사라진다.
    /// 지난 불안을 들춰내는 것은 제안이 아니라 겁주기다.
    @Test("하루가 지나면 그 이야기는 꺼내지 않는다")
    func theWindowCloses() {
        #expect(due(sensitiveHoursAgo: 25) == nil)
        #expect(due(sensitiveHoursAgo: 24 * 30) == nil)
    }

    @Test("한 번 말했으면 다시 말하지 않는다")
    func saysItOnce() {
        #expect(due(shown: [.sensitiveSaved], sensitiveHoursAgo: 1) == nil)
    }

    // MARK: - 두 번째 기기

    @Test("기기가 둘이 되면 두 대째를 내민다")
    func offersSyncOnSecondDevice() {
        #expect(due(devices: 2) == .secondDevice)
        #expect(due(devices: 3) == .secondDevice)
    }

    @Test("기기가 하나면 꺼내지 않는다. 혼자 쓰는 사람에게 동기화는 팔 것이 아니다")
    func notForSingleDevice() {
        #expect(due(devices: 1) == nil)
    }

    /// ⚠️ Pro 는 이미 동기화를 여는 것에 들어 있다. 그 사람에게 또 파는 것은 사기다.
    @Test("이미 동기화를 쓸 수 있으면 두 대째를 팔지 않는다")
    func neverSellsSyncTwice() {
        #expect(due(hasSync: true, devices: 2) == nil)
        #expect(due(hasPro: true, hasSync: true, devices: 2) == nil)
    }

    // MARK: - 백업이 없다

    @Test("쌓인 것은 많고 백업은 없으면 그 사실을 말한다")
    func mentionsBackupWhenThereIsSomethingToLose() {
        #expect(due(memos: 20, installedDaysAgo: 30) == .noBackup)
        #expect(due(memos: 40, installedDaysAgo: 100) == .noBackup)
    }

    @Test("한 번이라도 백업했으면 말하지 않는다")
    func silentWhenBackupExists() {
        #expect(due(memos: 40, backupDaysAgo: 90) == nil)
    }

    @Test("아직 쌓인 것이 없으면 말하지 않는다. 잃을 것이 없는 사람에게 겁을 주지 않는다")
    func silentWithLittleToLose() {
        #expect(due(memos: 19, installedDaysAgo: 60) == nil)
    }

    @Test("설치 첫 달에는 말하지 않는다")
    func waitsAMonth() {
        #expect(due(memos: 40, installedDaysAgo: 29) == nil)
        #expect(due(memos: 40, installedDaysAgo: nil) == nil)
    }

    // MARK: - 순서

    /// `sensitiveSaved` 만 **유효기간이 있다.** 나머지 둘은 내일 꺼내도 조건이 그대로지만
    /// 이건 내일이면 사라진다. 그래서 겹치면 이쪽이 먼저다.
    @Test("셋이 겹치면 사라질 것부터 말한다")
    func theExpiringOneGoesFirst() {
        #expect(due(sensitiveHoursAgo: 1, devices: 2, memos: 40) == .sensitiveSaved)
        // 그것을 이미 말했으면 그 다음.
        #expect(due(shown: [.sensitiveSaved], sensitiveHoursAgo: 1, devices: 2, memos: 40) == .secondDevice)
        #expect(due(shown: [.sensitiveSaved, .secondDevice], sensitiveHoursAgo: 1, devices: 2, memos: 40) == .noBackup)
        // 셋 다 말했으면 끝이다. 되풀이하지 않는다.
        #expect(due(shown: [.sensitiveSaved, .secondDevice, .noBackup],
                    sensitiveHoursAgo: 1, devices: 2, memos: 40) == nil)
    }

    // MARK: - 순간과 파는 물건

    /// 순간마다 파는 물건이 다르다. 같은 페이월을 띄우면 기기 문제로 온 사람에게
    /// 단축어 개수 이야기를 하게 된다.
    @Test("순간은 저마다 다른 것을 판다")
    func eachMomentSellsItsOwnThing() {
        #expect(PurchaseMoment.sensitiveSaved.limitType == .biometricLock)
        #expect(PurchaseMoment.secondDevice.limitType == .deviceSync)
        #expect(PurchaseMoment.noBackup.limitType == .cloudBackup)
    }
}
