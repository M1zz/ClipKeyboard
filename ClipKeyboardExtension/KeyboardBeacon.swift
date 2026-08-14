//
//  KeyboardBeacon.swift
//  ClipKeyboardExtension
//
//  키보드 익스텐션 사용 비콘 - App Group UserDefaults에 timestamp만 기록.
//  메인 앱이 launch 시 읽어 Analytics로 전송 (KeyboardBeaconReader, 현재 no-op).
//
//  익스텐션은 분석 SDK 없이 단순 write만 - 메모리·심사·프라이버시 리스크 회피.
//

import Foundation
#if os(iOS)
import UIKit
#endif

enum KeyboardBeacon {
    /// App Group container ID - 메인 앱과 동일.

    /// 마지막 키보드 사용 timestamp (Unix epoch seconds).
    static let lastUseKey = "kb.beacon.lastUse"

    /// 누적 사용 횟수 (메인 앱이 마지막으로 읽은 이후의 카운트).
    static let pendingUseCountKey = "kb.beacon.pendingCount"

    /// 키보드가 사용됨을 기록. viewDidAppear에서 한 번 호출.
    /// 비용: UserDefaults write 3개. 네트워크·SDK 사용 없음.
    static func recordUse() {
        guard let defaults = AppGroup.defaults else { return }
        let now = Date()
        defaults.set(now.timeIntervalSince1970, forKey: lastUseKey)
        let prev = defaults.integer(forKey: pendingUseCountKey)
        defaults.set(prev + 1, forKey: pendingUseCountKey)

        // 날짜별 원장 - 위 카운터엔 "언제"가 없어서 앱을 오랜만에 열면 그 사이 활동이
        // 하루로 뭉친다. 키보드만 쓰는 사람의 활동일은 이쪽으로만 살아남는다.
        KeyboardDayLedger.recordUse(at: now)
    }
}

/// iOS "전체 접근 허용" 상태 - 익스텐션 전역에서 읽는 단일 출처.
///
/// ⚠️ **`ProFeatureManager.hasFullAccess` 와 혼동 금지.** 그쪽은 Pro 결제 판정
///    (`isPro || isGrandfathered || isInTrial`)이고, 이쪽은 iOS 설정의 키보드 권한이다.
///    이름이 비슷해 지금까지 익스텐션이 진짜 권한을 한 번도 확인하지 않고 있었다.
///
/// 왜 필요한가: 전체 접근이 꺼져 있으면 `UIPasteboard` 읽기·쓰기가 iOS 차원에서 막힌다.
/// 확인 없이 호출하면 **아무 일도 안 일어나고 에러도 없다** - 사용자는 앱이 고장 난 줄 안다.
///
/// 값은 `KeyboardViewController` 가 `hasFullAccess`(UIInputViewController 프로퍼티)로 채운다.
/// 익스텐션은 한 프로세스에 하나뿐이라 static 으로 충분하다.
enum KeyboardCapability {
    private(set) static var hasFullAccess = false

    /// 지구본(다음 키보드) 키를 우리가 그려야 하는지.
    ///
    /// iOS가 시스템 차원에서 전환 UI를 제공하는 상황(예: 기기에 키보드가 하나뿐)에서는 false다.
    /// 커스텀 키보드는 이 값이 true일 때 **반드시** 전환 수단을 제공해야 한다(심사 요건).
    private(set) static var needsInputModeSwitchKey = false

    static func update(hasFullAccess granted: Bool, needsInputModeSwitchKey needsSwitch: Bool) {
        hasFullAccess = granted
        needsInputModeSwitchKey = needsSwitch
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

    /// 키보드 진입 시 한 번 호출 - 햅틱 엔진을 사전 깨워 첫 입력 지연 제거.
    static func prepare() {
        light.prepare()
        soft.prepare()
        medium.prepare()
    }

    // MARK: - 키 클릭음

    /// 시스템 키 클릭음. **또깍.**
    ///
    /// ⚠️ 커스텀 사운드 파일을 재생하지 않는다. `playInputClick()` 은 iOS가
    ///    **사용자의 설정 > 사운드 > 키보드 클릭음** 을 보고 재생 여부를 결정한다.
    ///    즉 소리를 꺼 둔 사람에게는 아무 일도 일어나지 않는다 - 회의 중에 우리 앱만
    ///    떠드는 사태가 구조적으로 불가능하다. (키보드에서 무단 사운드가 금물인 이유)
    ///
    /// ⚠️ 이게 동작하려면 입력 뷰 컨트롤러가 `UIInputViewAudioFeedback` 을 채택하고
    ///    `enableInputClicksWhenVisible` 을 true로 돌려줘야 한다.
    ///    (KeyboardViewController 하단 확장 참고)
    @inline(__always)
    static func click() {
        guard delightEnabled else { return }
        UIDevice.current.playInputClick()
    }

    @inline(__always)
    static func tap() {
        click()
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
    /// (익스텐션은 LeeoKit을 참조할 수 없어 값을 직접 읽는다 - 키는 DefaultsKey 단일 출처)
    static var delightEnabled: Bool {
        guard let value = AppGroup.defaults?
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
        UIDevice.current.playInputClick()
        medium.impactOccurred()
        medium.prepare()
    }
}
#endif
