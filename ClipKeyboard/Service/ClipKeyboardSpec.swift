//
//  ClipKeyboardSpec.swift
//  ClipKeyboard
//
//  LeeoKit 계약(LeeoAppSpec) 준수 — 이 앱의 공통 기능 설정값 단일 소스.
//  피드백 시스템 구현은 전부 LeeoKit에 있고, 앱은 이 설정만 제공한다.
//
//  ⚠️ recordType/구독 ID는 CloudKit Dashboard·기존 사용자 기기와의 계약이다 — 변경 금지.
//  컨테이너는 공용 피드백 허브(FeedbackHub)로 전환됨 — appIdentifier로 앱을 구분한다.
//  (전환 전 자기 컨테이너 iCloud.com.Ysoup.TokenMemo에 쌓인 기존 피드백은 허브 인박스에 나타나지 않는다.)
//

import Foundation
import LeeoKit

enum ClipKeyboardSpec: LeeoAppSpec {
    static let appName = "ClipKeyboard"
    static let developerEmail = Constants.developerEmail

    /// ClipKeyboard.entitlements에 iCloud.com.Ysoup.FeedbackHub 컨테이너가 있어야 한다.
    /// 공용 피드백 허브(FeedbackHub)로 수집 — appIdentifier로 앱을 구분한다.
    /// (백업은 CloudKitBackupService가 iCloud.com.Ysoup.TokenMemo에서 계속 담당한다.)
    static let feedback = LeeoFeedbackConfig(
        containerIdentifier: "iCloud.com.Ysoup.FeedbackHub",
        appIdentifier: "com.Ysoup.TokenMemo"
    )

    /// 인앱 결제(프로 일회성 잠금해제) — StoreKit 2 엔진은 LeeoKit(LeeoStore)이 담당한다.
    /// StoreManager 파사드가 이 구성을 그대로 넘겨 상품 로드·구매·복원·권한 추적을 위임한다.
    ///
    /// ⚠️ productID 는 App Store Connect·기존 사용자 영수증과의 계약이다 — 변경 금지.
    /// cacheSuiteName 을 앱 그룹으로 두어 권한 캐시(leeo.paywall.owned/grandfathered)가
    /// 공유 그룹에 저장되게 한다. (키보드 익스텐션이 읽는 Pro 키 `clipkeyboard_is_pro` 는
    /// 이와 별개로 StoreManager 가 store.hasPro 를 계속 미러링한다.)
    /// ⚠️ 타입을 반드시 옵셔널로 명시한다 — `LeeoAppSpec`의 요구사항이 `LeeoPaywallConfig?` 라
    /// 비옵셔널로 선언하면 witness 로 인정되지 않고 프로토콜 기본값(`nil`)이 쓰인다.
    /// 그러면 `StoreManager.init`의 `ClipKeyboardSpec.paywall!` 이 nil 을 강제 언랩해 **앱이 실행 즉시 크래시**한다.
    static let paywall: LeeoPaywallConfig? = LeeoPaywallConfig(
        productIDs: [StoreManager.proProductID],
        cacheSuiteName: AppGroup.identifier
    )
}
