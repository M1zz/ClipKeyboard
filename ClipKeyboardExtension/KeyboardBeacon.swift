//
//  KeyboardBeacon.swift
//  ClipKeyboardExtension
//
//  키보드 익스텐션 사용 비콘 — App Group UserDefaults에 timestamp만 기록.
//  메인 앱이 launch 시 읽어 Firebase Analytics로 전송 (KeyboardBeaconReader).
//
//  익스텐션은 분석 SDK 없이 단순 write만 — 메모리·심사·프라이버시 리스크 회피.
//

import Foundation
#if os(iOS)
import UIKit
#endif

enum KeyboardBeacon {
    /// App Group container ID — 메인 앱과 동일.
    private static let appGroup = AppGroup.identifier

    /// 마지막 키보드 사용 timestamp (Unix epoch seconds).
    static let lastUseKey = "kb.beacon.lastUse"

    /// 누적 사용 횟수 (메인 앱이 마지막으로 읽은 이후의 카운트).
    static let pendingUseCountKey = "kb.beacon.pendingCount"

    /// 키보드가 사용됨을 기록. viewDidAppear에서 한 번 호출.
    /// 비용: UserDefaults write 2개. 네트워크·SDK 사용 없음.
    static func recordUse() {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
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
}
#endif
