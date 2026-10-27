//
//  ClipKeyboardSpec.swift
//  ClipKeyboard
//
//  LeeoKit 계약(LeeoAppSpec) 준수 - 이 앱의 공통 기능 설정값 단일 소스.
//  피드백 시스템 구현은 전부 LeeoKit에 있고, 앱은 이 설정만 제공한다.
//
//  ⚠️ recordType/구독 ID는 CloudKit Dashboard·기존 사용자 기기와의 계약이다 - 변경 금지.
//  컨테이너는 공용 피드백 허브(FeedbackHub)로 전환됨 - appIdentifier로 앱을 구분한다.
//  (전환 전 자기 컨테이너 iCloud.com.Ysoup.TokenMemo에 쌓인 기존 피드백은 허브 인박스에 나타나지 않는다.)
//

import Foundation
import LeeoKit

enum ClipKeyboardSpec: LeeoAppSpec {
    static let appName = "ClipKeyboard"
    static let developerEmail = Constants.developerEmail

    /// ClipKeyboard.entitlements에 iCloud.com.Ysoup.FeedbackHub 컨테이너가 있어야 한다.
    /// 공용 피드백 허브(FeedbackHub)로 수집 - appIdentifier로 앱을 구분한다.
    /// (백업은 CloudKitBackupService가 iCloud.com.Ysoup.TokenMemo에서 계속 담당한다.)
    static let feedback = LeeoFeedbackConfig(
        containerIdentifier: "iCloud.com.Ysoup.FeedbackHub",
        appIdentifier: "com.Ysoup.TokenMemo",
        // 버그와 제안에 화면을 붙여 받는다. 사진 필드(screenshot1~3)가 허브 Production 에
        // 없으면 LeeoKit 이 사진만 빼고 다시 보내므로 글은 늘 간다.
        acceptsScreenshots: true
    )

    /// App Store 숫자 ID - "리뷰 남기기" 딥링크와 앱 소개(LeeoFamilyCatalog)의 자기 식별에 쓴다.
    /// 이 값이 없으면 소개 화면이 자기 자신을 걸러내지 못한다.
    static let appStoreID: String? = Constants.appStoreID

    /// 법적·지원 링크 - LeeoKit 3.0 계약 필수 항목.
    /// ⚠️ 개인정보 처리방침 주소는 **App Store Connect 에 등록한 것과 같아야 한다**
    ///    (`Constants` 가 단일 출처이므로 여기서 다시 적지 않고 그 값을 쓴다).
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: Constants.privacyPolicyURL)!,
        supportURL: URL(string: Constants.supportURL)!,
        termsURL: URL(string: Constants.termsOfUseURL)!,
        // 계정을 만들지 않는다 - 데이터는 사용자의 iCloud/기기에만 있다.
        createsAccounts: false,
        marketingURL: URL(string: Constants.supportURL)!
    )

    /// 수익모델 - 무료로 쓰다가 **Plus · Pro 를 연 구독이나 평생으로** 산다(2026-10 요금제 개편).
    ///
    /// 이 한 줄에서 페이월 필요 여부 · 복원 의무 · 약관 고지 · 게이트 정책이 따라 나온다.
    /// `paywall` 을 따로 선언하지 않는 이유가 그것이다(선언하면 이 값과 어긋날 수 있고,
    /// 어긋나면 LeeoKit 프리플라이트가 `paywall.contradiction` 으로 잡는다).
    ///
    /// ⚠️ productID 는 App Store Connect · 기존 사용자 영수증과의 계약이다. 변경 금지.
    /// ⚠️ `productIDs` 는 **지금 파는 것**만이다. 판매를 멈춘 반값 Pro · 체험용 마스터는 여기 없지만
    ///    `entitlementIDs` 에는 남는다. 산 사람의 권한은 판매 목록이 아니라 권한 목록이 지킨다.
    /// ⚠️ **Pro 로 인정할 상품을 손으로 못박는다**(`AccessTier.proOrHigherProductIDs`). 기본값이
    ///    "파는 상품 전체" 라, 그대로 두면 Plus · 칸 팩 · 두 대째 결제가 평생 Pro 를 열어 버린다.
    ///    그 사고는 되돌릴 수도 없다(이미 권한을 받은 사람에게서 도로 뺏을 방법이 없다).
    ///    **플러스는 Pro 가 아니다.** 플러스가 들어가면 백업 · 잠금 · 동기화가 열린다.
    /// ⚠️ 언제나 평생 패스 상품(`<번들>.forever` …)은 여기 넣지 않는다. `LeeoForeverPass` 가 따로 판정한다.
    /// ⚠️ cacheSuiteName 을 앱 그룹으로 둬야 권한 캐시(leeo.paywall.owned/grandfathered)가
    ///    공유 그룹에 저장된다. (키보드 익스텐션이 읽는 트림 · Pro 키는 StoreManager 가 따로 새긴다.)
    static let monetization = LeeoMonetization.freemiumSubscription(
        LeeoSubscriptionConfig(
            productIDs: [AccessTier.plusProductID,
                         AccessTier.plusYearlyProductID,
                         AccessTier.proProductID,
                         AccessTier.proYearlyProductID,
                         ProUpgrade.productID,
                         AccessTier.proGraduateProductID,
                         SlotPack.consumableProductID,
                         TwoDevicePack.productID],
            termsURL: URL(string: Constants.termsOfUseURL)!,
            entitlementIDs: AccessTier.proOrHigherProductIDs,
            gate: LeeoGatePolicy(
                freeLimits: ["shortcut": ProFeatureManager.freeMemoLimit],
                warnWhenRemaining: 3
            ),
            cacheSuiteName: AppGroup.identifier,
            // Pro 선물하기. 보내는 사람은 소모성 선물 상품을 사고, 받는 사람은 정가 Pro 를 산 것과 같아진다
            // (`AccessTier` 가 `com.Ysoup.TokenMemo.pro` 를 보고 프로 트림을 연다).
            // 선물 기록은 피드백과 같은 허브 컨테이너의 공개 DB 에 둔다. entitlements 에 이미 있다.
            // ⚠️ 선물 상품은 productIDs · entitlementIDs 에 넣지 않는다. 넣으면 선물을 산 사람이 Pro 가 된다.
            gift: LeeoGiftConfig(
                productID: StoreManager.giftProductID,
                grantsProductID: StoreManager.proProductID,
                containerIdentifier: "iCloud.com.Ysoup.FeedbackHub"
            ),
            // 팁(응원). 이미 다 가진 사람이 더 내고 싶을 때. 아무것도 열지 않는 소모성 상품이다.
            // ⚠️ 이것도 productIDs · entitlementIDs 에 넣지 않는다(사전 점검 `tip.sellsPro`).
            tipJar: LeeoTipJarConfig(productIDs: StoreManager.tipProductIDs)
        )
    )
}
