//
//  LivingSkin.swift
//  ClipKeyboard
//
//  **생활 레이어** — 카드 위에 사는 것. 물성 스킨(KeyboardSkin)과는 다른 층이다.
//
//  물성(두께·빛·모서리·눌림)은 손이 느끼는 것이고, 생활 레이어는 눈이 보는 것이다.
//  층이 달라서 서로 안 싸운다 — 기계식 키캡 위에 픽셀 마을이 자랄 수 있다.
//
//  ⚠️ **앱 전용.** 키보드 익스텐션에는 넣지 않는다. 익스텐션은 메모리 상한(대략 60MB)이
//     있어 상시 그림·타이머를 감당하지 못하고, 남의 앱 위에서 무언가 돌아다니면
//     입력을 방해한다.
//
//  ⚠️ 기본값은 `.none`. 업데이트했다고 남의 화면에 갑자기 새가 날아다니면 안 된다.
//
//  ⚠️ 두 갈래를 구분해서 보라 — **남는 것**(마을·발자국)은 사용 기록에서 그려지므로
//     정지 화면이고 배터리를 안 쓴다. **흐르는 것**(새·고양이)은 타이머가 필요하다.
//     그래서 흐르는 쪽만 저전력 모드·동작 줄이기에서 멈춘다.
//

import SwiftUI

enum LivingSkin: String, CaseIterable, Identifiable {
    /// 아무것도 살지 않음 (기본).
    case none
    /// 쓸수록 카드 위에 동전이 쌓인다 — 아낀 시간이 잔고가 된다.
    case vault
    /// 세 번 쓸 때마다 돌이 깨지고 보석이 하나 나온다.
    case geode
    /// 쓸수록 카드 위에 픽셀 마을이 자란다.
    case village
    /// 눈 덮인 카드에 발자국이 하나씩 남는다.
    case snow
    /// 가끔 새가 날아와 앉았다 간다.
    case bird
    /// 가끔 고양이가 카드 사이를 지나간다.
    case cat

    var id: String { rawValue }

    // MARK: - 저장

    static var current: LivingSkin {
        let raw = UserDefaults(suiteName: AppGroup.identifier)?
            .string(forKey: DefaultsKey.livingSkin) ?? ""
        return LivingSkin(rawValue: raw) ?? .none
    }

    // MARK: - 성격

    /// 사용 기록에서 그려지는가(= 정지 화면, 스크린샷에 남음, 배터리 0).
    var isPersistent: Bool {
        switch self {
        case .vault, .geode, .village, .snow: return true
        case .none, .bird, .cat: return false
        }
    }

    /// 타이머로 돌아다니는 손님인가(= 흐르는 것).
    var isVisitor: Bool {
        switch self {
        case .bird, .cat: return true
        case .none, .vault, .geode, .village, .snow: return false
        }
    }

    /// 손님이 다시 찾아오기까지의 간격(초).
    ///
    /// 상시로 돌리지 않는 이유: 하루에 수십 번 여는 도구에서 무언가 늘 움직이면
    /// 셋째 날부터는 귀여움이 아니라 소음이 된다. **어쩌다 마주치는 것**이라야 반갑다.
    var visitInterval: TimeInterval {
        switch self {
        case .bird: return 90
        case .cat:  return 70
        default:    return .infinity
        }
    }

    /// 손님이 머무는 시간(초).
    var visitDuration: TimeInterval {
        switch self {
        case .bird: return 4.5
        case .cat:  return 6.0
        default:    return 0
        }
    }

    // MARK: - 표시

    var localizedName: String {
        switch self {
        case .none:    return NSLocalizedString("없음", comment: "Living skin name: none")
        case .vault:   return NSLocalizedString("금고", comment: "Living skin name: vault")
        case .geode:   return NSLocalizedString("정동석", comment: "Living skin name: geode")
        case .village: return NSLocalizedString("픽셀 마을", comment: "Living skin name: pixel village")
        case .snow:    return NSLocalizedString("눈과 발자국", comment: "Living skin name: snow and footprints")
        case .bird:    return NSLocalizedString("새", comment: "Living skin name: bird")
        case .cat:     return NSLocalizedString("고양이", comment: "Living skin name: cat")
        }
    }

    var localizedDescription: String {
        switch self {
        case .none:
            return NSLocalizedString("카드만 깔끔하게 보여요.", comment: "Living skin description: none")
        case .vault:
            return NSLocalizedString("아낀 시간이 동전으로 쌓여요. 오래 쓴 문구일수록 금괴가 늘어나요.", comment: "Living skin description: vault")
        case .geode:
            return NSLocalizedString("쓸 때마다 돌에 금이 가고, 세 번째에 깨지면서 보석이 나와요.", comment: "Living skin description: geode")
        case .village:
            return NSLocalizedString("쓸수록 카드 위에 싹이 트고 나무와 집이 들어서요.", comment: "Living skin description: village")
        case .snow:
            return NSLocalizedString("눈 덮인 카드에 쓸 때마다 발자국이 하나씩 남아요.", comment: "Living skin description: snow")
        case .bird:
            return NSLocalizedString("가끔 새가 날아와 카드에 앉았다 가요.", comment: "Living skin description: bird")
        case .cat:
            return NSLocalizedString("가끔 고양이가 카드 사이를 지나가요.", comment: "Living skin description: cat")
        }
    }

    /// 목록에 함께 보여줄 성격 꼬리표 — 고르기 전에 무엇을 얻고 잃는지 알려준다.
    var localizedTrait: String? {
        switch self {
        case .vault:
            return NSLocalizedString("아낀 시간만큼 쌓여요", comment: "Living skin trait: vault balance")
        case .geode:
            return NSLocalizedString("세 번마다 보석 하나", comment: "Living skin trait: geode")
        case .village, .snow:
            return NSLocalizedString("사용 기록으로 남아요", comment: "Living skin trait: persistent")
        case .bird, .cat:
            return NSLocalizedString("가끔 잠깐 나타나요", comment: "Living skin trait: occasional visitor")
        case .none:
            return nil
        }
    }
}
