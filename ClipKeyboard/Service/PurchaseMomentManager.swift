//
//  PurchaseMomentManager.swift
//  ClipKeyboard
//
//  **결제가 말이 되는 순간**을 판단한다.
//
//  사람이 돈을 꺼내는 조건은 셋 중 하나다.
//   ① 비용이 몸에 닿았다      - 열 번째 칸에서 막혔다 (`ProFeatureManager.canAddMemo`)
//   ② 이미 쌓아 둔 것이 있다   - 여기서 떠나는 비용이 결제액보다 커졌다
//   ③ 잃을 게 생겼다          - 기기를 바꾼다, 카드번호가 잠기지 않은 채 들어 있다
//
//  ①은 예전부터 페이월이 붙잡고 있었다. 이 파일은 ②와 ③을 붙잡는다.
//
//  ⚠️ **순간은 각각 평생 한 번이다.** 두 번 보여 준 순간부터 그것은 제안이 아니라 광고다.
//     띄웠다는 기록은 화면을 여는 그 자리에서 남긴다(닫는 방법과 무관하게 1회를 보장).
//
//  ⚠️ 판단은 **순수 함수**(`dueMoment(now:context:)`)로 두고, 기기 상태를 읽는 일은
//     `dueMomentNow()` 가 한다. 그래야 시험이 주변에 남은 App Group 값에 흔들리지 않는다
//     (반값 제안에서 실제로 그랬다. `DiscountOfferManager` 의 같은 자리 참고).
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// 결제를 꺼내기 좋은 자리들. 각각 한 번씩만 온다.
enum PurchaseMoment: String, CaseIterable, Sendable {
    /// 카드번호·주민번호처럼 가려야 할 것을 방금 저장했다. → 생체잠금
    case sensitiveSaved
    /// 같은 계정에서 두 번째 기기가 나타났다. → 두 대째(동기화)
    case secondDevice
    /// 쌓아 둔 것은 많은데 백업이 한 번도 없다. → 평생(백업)
    case noBackup

    /// 따로 정한 차례가 없을 때의 차례. `sensitiveSaved` 가 먼저인 이유는 그것만 **유효기간이 있어서**다.
    /// 쓰임새마다 다른 차례는 `FeatureFit.purchaseMomentOrder` 가 정한다.
    static let defaultOrder: [PurchaseMoment] = [.sensitiveSaved, .secondDevice, .noBackup]

    /// 이 순간이 페이월에 건네는 한도 종류. 페이월의 머리말과 애널리틱스가 이걸 본다.
    var limitType: ProFeatureManager.LimitType {
        switch self {
        case .sensitiveSaved: return .biometricLock
        case .secondDevice: return .deviceSync
        case .noBackup: return .cloudBackup
        }
    }
}

enum PurchaseMomentManager {

    // MARK: - 상수

    /// 민감한 것을 저장한 뒤 이 시간 안에만 말을 건다.
    /// 불안은 저장하는 그 순간 가장 크고, 하루가 지나면 사라진다.
    /// 지난 불안을 들춰내는 것은 제안이 아니라 겁주기다.
    static let sensitiveWindowHours = 24

    /// 백업 이야기를 꺼내기 전에 필요한 단축어 개수.
    /// 이만큼 쌓였다는 건 여기서 떠나는 비용이 실제로 생겼다는 뜻이다.
    static let noBackupMemoThreshold = 20

    /// 백업 이야기를 꺼내기 전에 필요한 사용 일수.
    /// 설치 첫 달에는 잃을 것이 아직 없다.
    static let noBackupInstallDays = 30

    private static var defaults: UserDefaults? { AppGroup.defaults }

    // MARK: - 판정

    /// 판정 입력을 한 덩어리로 - 순수 함수로 두어 그대로 시험한다.
    struct Context {
        /// 이미 Pro 인가(구매·그랜드파더·체험 포함).
        var hasPro: Bool
        /// 동기화를 이미 쓸 수 있는가(Pro 이거나 두 대째를 샀다).
        var hasSync: Bool
        /// 이미 띄운 순간들.
        var shownMoments: Set<PurchaseMoment>
        /// 가려야 할 것을 마지막으로 저장한 시각.
        var sensitiveSavedAt: Date?
        /// 이 계정에서 본 기기 수.
        var knownDeviceCount: Int
        /// 이 사람이 직접 만든 단축어 개수.
        var ownMemoCount: Int
        /// 마지막 백업 시각(한 번도 없으면 nil).
        var lastBackupAt: Date?
        /// 앱을 처음 연 날.
        var installedAt: Date?
        /// 어떤 차례로 볼지. 빠진 순간은 보지 않는다(`FeatureFit.purchaseMomentOrder`).
        var order: [PurchaseMoment] = PurchaseMoment.defaultOrder
    }

    /// 지금 꺼낼 순간이 있으면 그것을 돌려준다 - **순수 함수.**
    ///
    /// 차례(`context.order`)가 곧 우선순위다. 기본 차례에서 `sensitiveSaved` 가 먼저인 이유는
    /// 그것만 **유효기간이 있어서**다. 나머지 둘은 내일 꺼내도 조건이 그대로지만, 이건 내일이면 사라진다.
    static func dueMoment(now: Date = Date(), context: Context) -> PurchaseMoment? {
        context.order.first { moment in
            !context.shownMoments.contains(moment) && isDue(moment, now: now, context: context)
        }
    }

    /// 순간 하나의 조건.
    private static func isDue(_ moment: PurchaseMoment, now: Date, context: Context) -> Bool {
        switch moment {
        case .sensitiveSaved:
            guard !context.hasPro, let savedAt = context.sensitiveSavedAt else { return false }
            let elapsed = now.timeIntervalSince(savedAt)
            return elapsed >= 0 && elapsed <= TimeInterval(sensitiveWindowHours) * 3600
        case .secondDevice:
            return !context.hasSync && context.knownDeviceCount >= 2
        case .noBackup:
            guard !context.hasPro,
                  context.lastBackupAt == nil,
                  context.ownMemoCount >= noBackupMemoThreshold,
                  let installedAt = context.installedAt else { return false }
            return now.timeIntervalSince(installedAt) >= TimeInterval(noBackupInstallDays) * 86_400
        }
    }

    /// 지금 이 기기의 실제 상태로 위 판정을 돌린다.
    /// - Parameter ownMemoCount: 샘플을 뺀 **자기 것만** 센 개수(`ProFeatureManager.ownMemoCount`).
    @MainActor
    static func dueMomentNow(ownMemoCount: Int) -> PurchaseMoment? {
        dueMoment(context: Context(
            hasPro: ProFeatureManager.hasFullAccess,
            hasSync: ProFeatureManager.isSyncAvailable,
            shownMoments: shownMoments,
            sensitiveSavedAt: sensitiveSavedAt,
            knownDeviceCount: knownDeviceCount,
            ownMemoCount: ownMemoCount,
            lastBackupAt: UserDefaults.standard.object(forKey: DefaultsKey.lastBackupDate) as? Date,
            installedAt: UserDefaults.standard.object(forKey: DefaultsKey.appInstallDate) as? Date,
            order: FeatureFit.purchaseMomentOrder(PersonaResolver.profile)
        ))
    }

    // MARK: - 기록

    /// 이미 띄운 순간들.
    static var shownMoments: Set<PurchaseMoment> {
        let raw = defaults?.stringArray(forKey: DefaultsKey.purchaseMomentsShown) ?? []
        return Set(raw.compactMap(PurchaseMoment.init(rawValue:)))
    }

    /// 띄웠다고 못박는다 - 화면을 여는 그 자리에서 부른다.
    static func markShown(_ moment: PurchaseMoment) {
        var shown = shownMoments
        guard shown.insert(moment).inserted else { return }
        defaults?.set(shown.map(\.rawValue), forKey: DefaultsKey.purchaseMomentsShown)
        print("📌 [PurchaseMoment] 노출 기록: \(moment.rawValue)")
    }

    /// 가려야 할 것을 저장했다 - 분류 결과가 민감할 때 저장하는 자리에서 부른다.
    ///
    /// ⚠️ **무엇을 저장했는지는 남기지 않는다.** 남기는 것은 시각 하나뿐이다.
    ///    민감한 값을 다루는 자리에서 그 값을 또 어딘가에 적는 것은 그 자체로 사고다.
    static func noteSensitiveSaved() {
        defaults?.set(Date().timeIntervalSince1970, forKey: DefaultsKey.sensitiveSavedAt)
    }

    /// 가려야 할 것을 마지막으로 저장한 시각.
    static var sensitiveSavedAt: Date? {
        let raw = defaults?.double(forKey: DefaultsKey.sensitiveSavedAt) ?? 0
        return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
    }

    // MARK: - 기기 세기

    /// 이 계정에서 본 기기 수. iCloud 키·값 저장소에 쌓인 식별자를 센다.
    static var knownDeviceCount: Int {
        knownDeviceIDs.count
    }

    private static var knownDeviceIDs: [String] {
        NSUbiquitousKeyValueStore.default.array(forKey: DefaultsKey.knownDeviceIDs) as? [String] ?? []
    }

    /// 이 기기를 명단에 올린다 - 앱 시작에서 한 번 부른다.
    ///
    /// 왜 iCloud 인가: 두 번째 기기가 생겼다는 사실은 **한 기기 안에서는 알 수 없다.**
    /// 같은 Apple ID 의 다른 기기가 남긴 자국을 봐야만 안다.
    ///
    /// ⚠️ 담는 것은 `identifierForVendor` 뿐이다. 기기 이름도 모델명도 담지 않는다
    ///    (그건 이 판단에 필요 없고, 필요 없는 것을 담는 순간 그것은 수집이 된다).
    /// - Returns: 이번 호출로 명단이 둘 이상이 됐으면 true.
    @discardableResult
    static func registerThisDevice() -> Bool {
        #if canImport(UIKit)
        guard let id = UIDevice.current.identifierForVendor?.uuidString else { return false }
        #else
        guard let id = Optional(ProcessInfo.processInfo.globallyUniqueString) else { return false }
        #endif
        var ids = knownDeviceIDs
        guard !ids.contains(id) else { return ids.count >= 2 }
        ids.append(id)
        // 명단이 끝없이 길어지지 않게 마지막 다섯만 남긴다. 판단에 필요한 건 "둘 이상인가"뿐이다.
        if ids.count > 5 { ids = Array(ids.suffix(5)) }
        let store = NSUbiquitousKeyValueStore.default
        store.set(ids, forKey: DefaultsKey.knownDeviceIDs)
        store.synchronize()
        print("📱 [PurchaseMoment] 기기 명단 \(ids.count)대")
        return ids.count >= 2
    }

    // MARK: - 진단

    /// 개발 중에 되돌린다(설정 > 개발자 화면).
    static func resetForTesting() {
        defaults?.removeObject(forKey: DefaultsKey.purchaseMomentsShown)
        defaults?.removeObject(forKey: DefaultsKey.sensitiveSavedAt)
        NSUbiquitousKeyValueStore.default.removeObject(forKey: DefaultsKey.knownDeviceIDs)
    }
}
