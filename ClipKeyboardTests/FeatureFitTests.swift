//
//  FeatureFitTests.swift
//  ClipKeyboardTests
//
//  알아본 쓰임새로 "무엇을 먼저 꺼내 보일지". 막는 것은 여기 없다는 것도 함께 확인한다.
//

import Testing
import Foundation
@testable import ClipKeyboard

struct FeatureFitTests {

    private let student = FeatureFit.Profile(persona: .student, isConfident: true)
    private let unsureStudent = FeatureFit.Profile(persona: .student, isConfident: false)
    private let nomad = FeatureFit.Profile(persona: .nomad, isConfident: true)

    // MARK: - 반값 제안

    @Test("학생으로 확신할 때만 반값 제안을 거둔다")
    func discountOffer() {
        #expect(!FeatureFit.allowsDiscountOffer(student))
        #expect(FeatureFit.allowsDiscountOffer(unsureStudent))
        #expect(FeatureFit.allowsDiscountOffer(nomad))
        #expect(FeatureFit.allowsDiscountOffer(.unknown))
    }

    // MARK: - 친구에게 알리기

    private func share(_ profile: FeatureFit.Profile, uses: Int = 20, days: Int = 6,
                       shown: Bool = false, away: Bool = false) -> Bool {
        FeatureFit.isShareMomentDue(.init(profile: profile, uses: uses, activeDays: days,
                                          alreadyShown: shown, isAwayOrJustBack: away))
    }

    @Test("손에 붙은 학생에게 한 번 권한다")
    func shareForSettledStudent() {
        #expect(share(student))
    }

    @Test("확신이 없거나 학생이 아니면 권하지 않는다")
    func shareNeedsConfidentStudent() {
        #expect(!share(unsureStudent))
        #expect(!share(nomad))
    }

    @Test("덜 썼거나, 이미 권했거나, 막 돌아왔으면 권하지 않는다")
    func shareGuards() {
        #expect(!share(student, uses: FeatureFit.ShareThreshold.uses - 1))
        #expect(!share(student, days: FeatureFit.ShareThreshold.activeDays - 1))
        #expect(!share(student, shown: true))
        #expect(!share(student, away: true))
    }

    // MARK: - 사진에서 읽은 값

    @Test("사진에서 읽은 여권·카드 번호는 잠근다")
    func locksSensitivePhotoValues() {
        #expect(FeatureFit.shouldLockValueFromPhoto(type: .passportNumber, confidence: 0.9, lockAvailable: true, alreadySecure: false))
        #expect(FeatureFit.shouldLockValueFromPhoto(type: .creditCard, confidence: 0.95, lockAvailable: true, alreadySecure: false))
    }

    @Test("주소·전화번호, 흐린 분류, 잠금을 못 쓰는 사람, 이미 잠근 것은 건드리지 않는다")
    func photoLockGuards() {
        #expect(!FeatureFit.shouldLockValueFromPhoto(type: .address, confidence: 0.9, lockAvailable: true, alreadySecure: false))
        #expect(!FeatureFit.shouldLockValueFromPhoto(type: .creditCard, confidence: 0.5, lockAvailable: true, alreadySecure: false))
        #expect(!FeatureFit.shouldLockValueFromPhoto(type: .creditCard, confidence: 0.9, lockAvailable: false, alreadySecure: false))
        #expect(!FeatureFit.shouldLockValueFromPhoto(type: .creditCard, confidence: 0.9, lockAvailable: true, alreadySecure: true))
    }

    // MARK: - 단축어 마트

    @Test("마트는 확신할 때만 거른다")
    func martFilter() {
        #expect(FeatureFit.martFilterPersona(nomad) == .nomad)
        #expect(FeatureFit.martFilterPersona(unsureStudent) == nil)
    }
}
