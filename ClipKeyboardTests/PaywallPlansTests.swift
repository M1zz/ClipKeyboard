//
//  PaywallPlansTests.swift
//  ClipKeyboardTests
//
//  페이월 세 칸(무료 · Plus · Pro)이 사람마다 무엇을 파는지 고정한다(`PaywallPlanRules`).
//
//  왜 필요한가: 트림 권한은 5.1.11 에 들어갔는데 페이월은 Pro 하나만 팔았다. Plus 는 살 길이 없었다.
//  거꾸로 업그레이드 값이 아무에게나 보이면 정가보다 싼 뒷문이 된다.
//

import Foundation
import Testing
import LeeoKit
@testable import ClipKeyboard

@Suite("페이월 세 칸")
struct PaywallPlansTests {

    private func states(_ purchased: AccessTier, permanentPro: Bool = false, upgrade: Bool = false)
        -> (plus: PaywallPlanState, pro: PaywallPlanState) {
        let access = PaywallAccess(purchased: purchased, hasPermanentPro: permanentPro, upgradeEligible: upgrade)
        return (access[.plus], access[.pro])
    }

    @Test("아무것도 안 산 사람은 Plus 와 Pro 를 정가로 고르고, 처음엔 연 구독이 골라져 있다")
    func freeUserBuysEitherAtFullPrice() {
        let s = states(.free)
        #expect(s.plus == .buy)
        #expect(s.pro == .buy)
        #expect(PaywallPlanRules.initialTerm(s.plus) == .yearly)
        #expect(PaywallPlanRules.initialTerm(s.pro) == .yearly)
    }

    @Test("Plus 평생을 산 사람은 Plus 가 사용 중이고 Pro 평생은 올리기 값이다")
    func plusOwnerUpgrades() {
        let s = states(.plus, upgrade: true)
        #expect(s.plus == .owned)
        #expect(s.pro == .upgrade)
        #expect(PaywallPlanRules.initialTerm(s.pro) == .lifetime)
        #expect(PaywallPlanRules.productID(for: .pro, s.pro, term: .lifetime) == AccessTier.plusToProProductID)
        #expect(PaywallPlanRules.productID(for: .pro, s.pro, term: .yearly) == AccessTier.proYearlyProductID)
    }

    @Test("Plus 연 구독 · 칸 팩만 산 사람은 올리기 값을 못 본다(Pro 는 정가)")
    func subscribersAndPackOwnersPayFullPrice() {
        let subscriber = states(.plus, upgrade: false)
        #expect(subscriber.plus == .owned)
        #expect(subscriber.pro == .buy)
        #expect(PaywallPlanRules.productID(for: .pro, subscriber.pro, term: .lifetime) == AccessTier.proProductID)
        #expect(states(.free, upgrade: false).pro == .buy)
    }

    @Test("칸마다 연 구독과 평생이 결제할 상품")
    func termsMapToProducts() {
        #expect(PaywallPlanRules.productID(for: .plus, .buy, term: .yearly) == AccessTier.plusYearlyProductID)
        #expect(PaywallPlanRules.productID(for: .plus, .buy, term: .lifetime) == AccessTier.plusProductID)
        #expect(PaywallPlanRules.productID(for: .pro, .buy, term: .yearly) == AccessTier.proYearlyProductID)
        #expect(PaywallPlanRules.productID(for: .pro, .buy, term: .lifetime) == AccessTier.proProductID)
        // 가진 칸은 아무것도 팔지 않는다.
        for term in LeeoPlanTerm.allCases {
            #expect(PaywallPlanRules.productID(for: .plus, .owned, term: term) == nil)
            #expect(PaywallPlanRules.productID(for: .pro, .owned, term: term) == nil)
            #expect(PaywallPlanRules.productID(for: .plus, .included, term: term) == nil)
        }
        // 판 상품은 산 칸을 그대로 연다(카드에 적은 칸과 결제하는 칸이 같다).
        for plan in PaywallPlan.allCases {
            for term in LeeoPlanTerm.allCases {
                let id = PaywallPlanRules.productID(for: plan, .buy, term: term)!
                #expect(AccessTier.purchased(from: [id]) == (plan == .plus ? .plus : .pro))
            }
        }
    }

    @Test("Pro(산 것 · 구독 · 그랜드파더)는 아무것도 팔지 않는다")
    func proOwnerBuysNothing() {
        for s in [states(.pro), states(.free, permanentPro: true), states(.master)] {
            #expect(s.plus == .included)
            #expect(s.pro == .owned)
        }
    }

    @Test("비교표 칸은 VoiceOver 에 숫자와 포함 여부를 말한다(글자 칸이 없어 잘리지 않는다)")
    func comparisonCellsSpeak() {
        #expect(PaywallComparisonTable.spoken(.count(10)) == 10.formatted())
        #expect(PaywallComparisonTable.spoken(.unlimited) == NSLocalizedString("무제한", comment: "Unlimited"))
        #expect(PaywallComparisonTable.spoken(.included) != PaywallComparisonTable.spoken(.excluded))
    }
}
