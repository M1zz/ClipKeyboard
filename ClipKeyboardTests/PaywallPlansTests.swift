//
//  PaywallPlansTests.swift
//  ClipKeyboardTests
//
//  페이월 세 칸(무료 · Plus · Pro)이 사람마다 무엇을 파는지 고정한다(`PaywallPlanRules`).
//
//  왜 필요한가: 트림 권한은 5.1.11 에 들어갔는데 페이월은 Pro 하나만 팔았다. Plus 는 살 길이 없었다.
//  거꾸로 업그레이드 값이 아무에게나 보이면 정가보다 싼 뒷문이 된다.
//

import Testing
@testable import ClipKeyboard

@Suite("페이월 세 칸")
struct PaywallPlansTests {

    private func states(_ purchased: AccessTier, permanentPro: Bool = false, upgrade: Bool = false)
        -> (plus: PaywallPlanState, pro: PaywallPlanState) {
        (PaywallPlanRules.state(of: .plus, purchased: purchased, hasPermanentPro: permanentPro, upgradeEligible: upgrade),
         PaywallPlanRules.state(of: .pro, purchased: purchased, hasPermanentPro: permanentPro, upgradeEligible: upgrade))
    }

    @Test("아무것도 안 산 사람은 Plus 와 Pro 를 정가로 고르고, 처음엔 Pro 가 골라져 있다")
    func freeUserBuysEitherAtFullPrice() {
        let s = states(.free)
        #expect(s.plus == .buy)
        #expect(s.pro == .buy)
        #expect(PaywallPlanRules.initialSelection(purchased: .free, hasPermanentPro: false, upgradeEligible: false) == .pro)
    }

    @Test("Plus 를 산 사람은 Plus 가 사용 중이고 Pro 는 업그레이드 값이다")
    func plusOwnerUpgrades() {
        let s = states(.plus, upgrade: true)
        #expect(s.plus == .owned)
        #expect(s.pro == .upgrade)
        #expect(PaywallPlanRules.initialSelection(purchased: .plus, hasPermanentPro: false, upgradeEligible: true) == .pro)
    }

    @Test("칸 팩만 산 사람도 Pro 는 업그레이드 값, Plus 는 정가")
    func slotPackOwnerUpgrades() {
        let s = states(.free, upgrade: true)
        #expect(s.plus == .buy)
        #expect(s.pro == .upgrade)
    }

    @Test("Pro(산 것 · 그랜드파더)는 아무것도 팔지 않는다")
    func proOwnerBuysNothing() {
        for s in [states(.pro), states(.free, permanentPro: true), states(.master)] {
            #expect(s.plus == .included)
            #expect(s.pro == .owned)
        }
        #expect(PaywallPlanRules.initialSelection(purchased: .pro, hasPermanentPro: true, upgradeEligible: false) == nil)
    }
}
