//
//  KeyboardBeacon.swift
//  ClipKeyboardExtension
//
//  키보드 익스텐션 사용 비콘 — App Group UserDefaults에 timestamp만 기록.
//  메인 앱이 launch 시 읽어 Analytics로 전송 (KeyboardBeaconReader, 현재 no-op).
//
//  익스텐션은 분석 SDK 없이 단순 write만 — 메모리·심사·프라이버시 리스크 회피.
//

import Foundation
#if os(iOS)
import UIKit
#endif

enum KeyboardBeacon {
    /// App Group container ID — 메인 앱과 동일.

    /// 마지막 키보드 사용 timestamp (Unix epoch seconds).
    static let lastUseKey = "kb.beacon.lastUse"

    /// 누적 사용 횟수 (메인 앱이 마지막으로 읽은 이후의 카운트).
    static let pendingUseCountKey = "kb.beacon.pendingCount"

    /// 키보드가 사용됨을 기록. viewDidAppear에서 한 번 호출.
    /// 비용: UserDefaults write 2개. 네트워크·SDK 사용 없음.
    static func recordUse() {
        guard let defaults = UserDefaults(suiteName: AppGroup.identifier) else { return }
        defaults.set(Date().timeIntervalSince1970, forKey: lastUseKey)
        let prev = defaults.integer(forKey: pendingUseCountKey)
        defaults.set(prev + 1, forKey: pendingUseCountKey)
    }
}

#if os(iOS)
/// 키 입력 햅틱 공유 인스턴스. UIImpactFeedbackGenerator를 매 키 입력마다 새로
/// 생성하면 첫 발생에 warm-up 비용이 누적되어 빠른 타이핑이 버벅임. 공유 인스턴스를
/// 미리 prepare() 해 두면 한 번의 시스템 호출로 즉시 햅틱 트리거.
enum KeyboardHaptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)

    /// 키보드 진입 시 한 번 호출 — 햅틱 엔진을 사전 깨워 첫 입력 지연 제거.
    static func prepare() {
        light.prepare()
        soft.prepare()
        medium.prepare()
    }

    @inline(__always)
    static func tap() {
        light.impactOccurred()
        light.prepare()
    }

    @inline(__always)
    static func softTap() {
        soft.impactOccurred()
        soft.prepare()
    }

    @inline(__always)
    static func mediumTap() {
        medium.impactOccurred()
        medium.prepare()
    }

    // MARK: - 날인

    /// 연출·햅틱 마스터 스위치. 메인 앱의 `Delight.isEnabled`와 **같은 키**를 읽는다.
    /// (익스텐션은 LeeoKit을 참조할 수 없어 값을 직접 읽는다 — 키는 DefaultsKey 단일 출처)
    static var delightEnabled: Bool {
        guard let value = UserDefaults(suiteName: AppGroup.identifier)?
            .object(forKey: DefaultsKey.delightEffectsEnabled) as? Bool else { return true }
        return value
    }

    /// 문구가 입력된 순간 = 도장을 찍은 순간.
    ///
    /// 이전에는 `UINotificationFeedbackGenerator(.success)`를 썼는데, 그건 "작업이 끝났다"는
    /// 알림 패턴이라 두세 번 울리는 느낌이 나고 하루 수십 번 반복하기엔 과하다.
    /// 도장은 가벼운 물건이 아니므로 **medium 한 번**으로 묵직하게 끝낸다.
    @inline(__always)
    static func stamp() {
        guard delightEnabled else { return }
        medium.impactOccurred()
        medium.prepare()
    }
}
#endif
