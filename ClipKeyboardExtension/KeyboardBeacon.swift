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

enum KeyboardBeacon {
    /// App Group container ID — 메인 앱과 동일.
    private static let appGroup = "group.com.Ysoup.TokenMemo"

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
