//
//  FeatureFit.swift
//  ClipKeyboard
//
//  **알아본 쓰임새에 따라 무엇을 내놓을지.** 판단만 하고, 화면은 부르는 쪽이 띄운다.
//
//  나눈 이유: 쓰임새를 알아보는 일(`PersonaInference`)과 그걸로 무엇을 바꿀지는 다른 질문이다.
//  한 곳에 섞으면 "노마드로 보는 기준" 을 고치려다 "노마드에게 무엇을 보여 주나" 가 같이 바뀐다.
//  `UserState` 와 화면 게이트를 떼어 놓은 것과 같은 이유다(USER_STATE_MODEL.md 9절).
//
//  | 무엇 | 누구에게 | 왜 |
//  | --- | --- | --- |
//  | 반값 제안을 꺼내지 않는다 | 학생으로 확신 | 돈을 가장 적게 쓰는 사람이다. 한도 앞에서 값을 들이밀면 떠난다 |
//  | 친구에게 알리기를 한 번 권한다 | 학생으로 확신 + 손에 붙음 | 이 사람에게 맞는 보답은 결제가 아니라 조별과제 방에 한 줄이다 |
//  | 사진에서 읽은 민감한 값을 잠근다 | 잠금을 쓸 수 있는 사람 전부 | 여권·카드를 찍는 순간이 잠가야 할 순간이다 |
//  | 단축어 마트를 내 쓰임새로 먼저 거른다 | 확신이 있을 때만 | 확신 없이 거르면 엉뚱한 진열대만 보인다 |
//  | 결제 순간의 차례를 바꾼다 (5.1.5) | 확신이 있을 때만 | 사람마다 "잃으면 안 되는 것" 이 다르다 |
//
//  ⚠️ **막는 것은 여기 없다.** 한도·결제·기능 잠금은 쓰임새와 상관없이 같다. 여기는 오직
//     "무엇을 먼저 꺼내 보일지" 만 정한다. 학생도 한도에 닿으면 똑같이 막힌다.
//

import Foundation

enum FeatureFit {

    /// 판단에 쓰는 쓰임새 한 덩어리(`PersonaResolver.profile`).
    struct Profile: Equatable {
        var persona: Persona
        var isConfident: Bool

        static let unknown = Profile(persona: .general, isConfident: false)
    }

    // MARK: - 반값 제안

    /// 반값 제안을 꺼내도 되는가.
    static func allowsDiscountOffer(_ profile: Profile) -> Bool {
        !(profile.isConfident && profile.persona == .student)
    }

    // MARK: - 친구에게 알리기

    struct ShareContext: Equatable {
        var profile: Profile
        /// 자기 단축어를 쓴 횟수(`UserStateFacts.uses`).
        var uses: Int
        /// 쓴 날의 수.
        var activeDays: Int
        /// 이미 권했는가. 평생 한 번이다.
        var alreadyShown: Bool
        /// 휴면이거나 막 돌아왔는가 - 돌아온 첫 화면에 부탁부터 꺼내지 않는다.
        var isAwayOrJustBack: Bool
    }

    enum ShareThreshold {
        /// 이만큼은 써 봐야 남에게 권할 말이 생긴다.
        static let uses = 15
        /// 하루에 몰아 쓴 게 아니라 며칠에 걸쳐 쓴 사람.
        static let activeDays = 5
    }

    /// 친구에게 알리기를 권할 때인가 - **순수 함수.**
    static func isShareMomentDue(_ context: ShareContext) -> Bool {
        guard !context.alreadyShown, !context.isAwayOrJustBack else { return false }
        guard context.profile.isConfident, context.profile.persona == .student else { return false }
        return context.uses >= ShareThreshold.uses && context.activeDays >= ShareThreshold.activeDays
    }

    // MARK: - 사진에서 읽은 값

    /// 사진에서 읽어 담은 값을 보안 단축어로 돌릴까 - **순수 함수.**
    ///
    /// 여권·카드는 대개 **사진으로** 들어온다. 손으로 칠 때는 이미 분류가 잠금을 켜 주는데
    /// (`MemoAddViewModel` 의 붙여넣기 경로), 사진에서 담는 길은 그걸 지나지 않았다.
    ///
    /// ⚠️ 잠금을 못 쓰는 사람(무료)에게는 켜지 않는다. 켜진 채로 저장하려다 결제 창이 뜨면
    ///    사진에서 값을 담은 것이 곧 결제 요구가 된다. 그 사람에게는 저장 뒤의 순간
    ///    (`PurchaseMoment.sensitiveSaved`)이 따로 있다.
    static func shouldLockValueFromPhoto(type: ClipboardItemType,
                                         confidence: Double,
                                         lockAvailable: Bool,
                                         alreadySecure: Bool) -> Bool {
        guard lockAvailable, !alreadySecure else { return false }
        return type.isSensitive && confidence >= 0.7
    }

    // MARK: - 결제 순간의 차례

    /// 결제 순간(`PurchaseMoment`)을 어떤 차례로 볼지 - **순수 함수.**
    ///
    /// 지도(PERSONA_JOURNEY_MAP 6절 다섯째)에서 결제가 말이 되는 순간은 사람마다 달랐다.
    ///
    /// | 판 | 차례 | 왜 |
    /// | --- | --- | --- |
    /// | 모름 · 일반 | 보안 → 두 대째 → 백업 | 계좌·주민번호를 저장한 직후의 불안이 가장 진하다. 예전 그대로 |
    /// | 노마드 | 두 대째 → 보안 → 백업 | 인보이스는 맥에서 쓴다. 두 번째 기기가 곧 값을 치를 이유다 |
    /// | 직장인 | 두 대째 → 백업 → 보안 | 회사 맥, 그리고 가장 빨리 쌓는 사람이라 잃을 것이 먼저 생긴다 |
    /// | 학생 | 없음 | 이 사람에게 맞는 보답은 결제가 아니라 공유다(`isShareMomentDue`) |
    ///
    /// ⚠️ 차례만 바꾼다. 순간마다 평생 한 번, 조건(24시간·20개·30일)은 `PurchaseMomentManager` 가
    ///    그대로 본다. 학생도 한도에 닿으면 페이월은 똑같이 뜬다. 여기서 빠지는 것은 **먼저 말 거는 배너**뿐이다.
    static func purchaseMomentOrder(_ profile: Profile) -> [PurchaseMoment] {
        guard profile.isConfident else { return PurchaseMoment.defaultOrder }
        switch profile.persona {
        case .general: return PurchaseMoment.defaultOrder
        case .nomad: return [.secondDevice, .sensitiveSaved, .noBackup]
        case .business: return [.secondDevice, .noBackup, .sensitiveSaved]
        case .student: return []
        }
    }

    // MARK: - 단축어 마트

    /// 마트를 열 때 내 쓰임새로 걸러서 보여 줄 수 있는가. 확신이 있을 때만이다.
    static func martFilterPersona(_ profile: Profile) -> Persona? {
        profile.isConfident ? profile.persona : nil
    }
}
