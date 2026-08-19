//
//  KeyboardSkin.swift
//  ClipKeyboard
//
//  키캡 **물성**(재질) 프리셋. 메인앱 설정 화면과 키보드 익스텐션이 같은 파일을 본다.
//
//  ⚠️ 스킨은 **색을 정하지 않는다.** 색은 이미 두 겹이 담당하고 있다
//     테마(Paper/Dusk)와 사용자 커스텀 키 색(keyboardCustomKeyHex).
//     스킨까지 색을 건드리면 셋이 서로 덮어쓰며 싸우고, "왜 내가 고른 색이 안 나오지"가 된다.
//     그래서 스킨이 정하는 건 **두께·빛·모서리·눌림**뿐이다.
//     덕분에 어떤 스킨을 골라도 사용자가 고른 색이 그대로 유지된다.
//
//  ⚠️ 기본값은 `.classic` - 키캡 이전의 생김새 그대로다. 키캡은 취향이 갈리는 변화라
//     **기본을 예전 모습에 두고 원하는 사람만 켜게** 한다. 업데이트했다고 남의 키보드
//     모양이 멋대로 바뀌면 안 된다.
//

import SwiftUI

enum KeyboardSkin: String, CaseIterable, Identifiable {
    /// **기본값.** 키캡 이전(4.4.3)의 모습 그대로 - 두께도 표면광도 없고,
    /// 카드는 눌리는 대신 푹신하게 부풀었다 돌아온다.
    ///
    /// ⚠️ 값을 바꾸지 말 것. "예전 그대로"라는 약속이 이 케이스의 존재 이유다(테스트로 고정).
    /// ⚠️ 키캡은 취향이 갈리는 변화라 **기본을 예전 모습에 두고 원하는 사람만 켜게** 한다.
    ///    쓰던 사람의 화면이 업데이트로 멋대로 바뀌지 않는 쪽이 항상 옳다.
    case classic
    /// 키캡 - 적당한 두께와 표면광.
    case standard
    /// 기계식 키보드 - 두꺼운 스커트, 각진 모서리, 깊게 떨어지는 그늘.
    case mechanical
    /// 납작 - 두께도 그림자도 없다. 가장 조용하고 시선을 안 끈다.
    case flat
    /// 말랑 - 아주 둥근 모서리에 부드러운 빛, 느리게 되돌아온다.
    case soft

    var id: String { rawValue }

    // MARK: - 지금은 꺼져 있다

    /// 스킨 고르기가 살아 있는가.
    ///
    /// ⚠️ **지금은 꺼져 있다.** 설정에서 고르는 자리를 감췄고, 저장된 값이 무엇이든
    ///    모두 `.classic`(예전 모습)으로 보인다. 고를 수 없는데 남의 화면만 달라져 있으면
    ///    "왜 내 것만 이렇지"가 되므로, 감추는 것과 되돌리는 것은 **함께** 일어나야 한다.
    ///
    /// 되살릴 때는 이 값 하나를 `true` 로. 스킨 코드·테스트는 그대로 남아 있다.
    static let isEnabled = false

    /// 저장된 값을 지금 규칙에 맞게 해석한다. **읽는 곳은 전부 이걸 거친다.**
    static func resolved(_ raw: String) -> KeyboardSkin {
        guard isEnabled else { return .classic }
        return KeyboardSkin(rawValue: raw) ?? .classic
    }

    // MARK: - 저장

    /// 현재 선택된 스킨. App Group에 있어 익스텐션도 같은 값을 읽는다.
    static var current: KeyboardSkin {
        let raw = AppGroup.defaults?
            .string(forKey: DefaultsKey.keyboardSkin) ?? ""
        return resolved(raw)
    }

    // MARK: - 물성

    /// 키캡 옆면 두께(pt). 눌렸을 때 이 거리만큼 내려앉아 바닥에 닿는다.
    /// 0이면 두께가 없어 눌림도 없다(납작).
    var skirtDepth: CGFloat {
        switch self {
        case .standard:   return 3
        case .mechanical: return 5
        case .flat:       return 0
        case .soft:       return 2
        case .classic:    return 0        // 예전엔 두께가 없었다
        }
    }

    /// 앱 카드용 두께. 카드는 키보다 크므로 한 단계 두껍게 잡아야 같은 비율로 보인다.
    /// 두께가 0인 스킨(납작)은 카드에서도 0 - 앱과 키보드가 같은 성격을 유지한다.
    var cardSkirtDepth: CGFloat {
        skirtDepth > 0 ? skirtDepth + 1 : 0
    }

    /// 카드가 **예전 방식(푹신하게 부풀었다 돌아오기)** 으로 반응해야 하는가.
    ///
    /// 두께가 0인 스킨은 카드가 내려앉을 바닥이 없다. 그대로 두면 눌러도 아무 반응이
    /// 없는 죽은 카드가 되므로, 키캡 이전에 쓰던 스케일 바운스로 되돌린다.
    var usesLegacyCardBounce: Bool { cardSkirtDepth == 0 }

    /// 스커트(옆면)의 그늘 농도. 키 색과 무관하게 검정을 깔아 만든다.
    func skirtOpacity(isDark: Bool) -> Double {
        switch self {
        case .standard:   return isDark ? 0.55 : 0.20
        case .mechanical: return isDark ? 0.70 : 0.30
        case .flat:       return 0
        case .soft:       return isDark ? 0.40 : 0.14
        case .classic:    return 0
        }
    }

    /// 윗면이 받는 빛의 세기. 위에서 아래로 흐르는 그라데이션의 시작 알파.
    func sheenOpacity(isDark: Bool) -> Double {
        switch self {
        case .standard:   return isDark ? 0.07 : 0.50
        case .mechanical: return isDark ? 0.10 : 0.62
        case .flat:       return 0
        case .soft:       return isDark ? 0.05 : 0.38
        case .classic:    return 0        // 표면광도 없었다
        }
    }

    /// 키가 바닥에 드리우는 그림자 농도.
    var shadowOpacity: Double {
        switch self {
        case .standard:   return 0.08
        case .mechanical: return 0.14
        case .flat:       return 0
        case .soft:       return 0.06
        case .classic:    return 0.08     // 예전 그림자 값 그대로
        }
    }

    /// 테마의 모서리 값을 스킨에 맞게 고쳐 쓴다.
    /// 테마가 정한 스케일을 버리지 않고 **비율로만** 조정한다.
    func cornerRadius(base: CGFloat) -> CGFloat {
        switch self {
        case .standard:   return base
        case .mechanical: return base * 0.55   // 각지게
        case .flat:       return base * 0.8
        case .soft:       return base * 1.5    // 아주 둥글게
        case .classic:    return base          // 테마 값 그대로 - 예전과 동일
        }
    }

    // MARK: - 눌림 곡선

    /// 내려가는 시간(초). 기계식 키는 travel이 거의 없다 - 짧을수록 또깍거린다.
    var pressDuration: Double {
        switch self {
        case .standard:   return 0.045
        case .mechanical: return 0.03
        case .flat:       return 0.06
        case .soft:       return 0.09
        case .classic:    return 0.06
        }
    }

    /// 되돌아오는 스프링. response가 클수록 느긋하고, damping이 작을수록 튕긴다.
    var releaseResponse: Double {
        switch self {
        case .standard:   return 0.20
        case .mechanical: return 0.16
        case .flat:       return 0.14
        case .soft:       return 0.34
        case .classic:    return 0.14
        }
    }

    var releaseDamping: Double {
        switch self {
        case .standard:   return 0.55
        case .mechanical: return 0.45   // 더 통통 튄다
        case .flat:       return 0.95   // 거의 안 튄다
        case .soft:       return 0.68
        case .classic:    return 0.95
        }
    }

    // MARK: - 표시

    var localizedName: String {
        switch self {
        case .classic:
            return NSLocalizedString("기본", comment: "Keyboard skin name: classic (default)")
        case .standard:
            return NSLocalizedString("키캡", comment: "Keyboard skin name: keycap")
        case .mechanical:
            return NSLocalizedString("기계식", comment: "Keyboard skin name: mechanical")
        case .flat:
            return NSLocalizedString("납작", comment: "Keyboard skin name: flat")
        case .soft:
            return NSLocalizedString("말랑", comment: "Keyboard skin name: soft")
        }
    }

    var localizedDescription: String {
        switch self {
        case .classic:
            return NSLocalizedString("평평한 기본 모습이에요. 카드가 푹신하게 반응해요.", comment: "Keyboard skin description: classic")
        case .standard:
            return NSLocalizedString("키가 도톰해지고 누르면 내려앉아요.", comment: "Keyboard skin description: keycap")
        case .mechanical:
            return NSLocalizedString("두껍고 각진 키. 누르는 맛이 가장 큽니다.", comment: "Keyboard skin description: mechanical")
        case .flat:
            return NSLocalizedString("두께도 그림자도 없어요. 가장 조용합니다.", comment: "Keyboard skin description: flat")
        case .soft:
            return NSLocalizedString("둥글고 부드럽게, 느리게 돌아와요.", comment: "Keyboard skin description: soft")
        }
    }
}

// MARK: - 악어 입속

/// 단축어 줄을 **악어 입속 이빨처럼** 보이게 하는 장치.
///
/// ⚠️ 기본은 꺼짐이 아니라 **새로 시작한 사람만 켜짐**이다(`seedDefaultIfNeeded`).
///    쓰던 사람의 키보드가 업데이트로 멋대로 바뀌면 안 된다는 규칙은 스킨과 같다.
///    대신 새로 오는 사람에게는 이것이 이 앱의 첫인상이므로 켠 채로 시작한다.
///
/// ⚠️ **색은 건드리지 않는다.** 스킨과 같은 규칙이다 - 사용자가 고른 키 색이
///    그대로 유지되어야 한다. 이 장치가 바꾸는 건 **키의 윤곽과 그 위의 잇몸**뿐이다.
///    (흰 기본 키색이 이미 상아색으로 읽히므로 색을 덮을 이유도 없다)
enum ToothStyle {

    /// 지금 켜져 있는가. App Group 이라 익스텐션도 같은 값을 본다.
    static var isOn: Bool {
        AppGroup.defaults?.bool(forKey: DefaultsKey.keyboardToothStyle) ?? false
    }

    static func set(_ on: Bool) {
        AppGroup.defaults?.set(on, forKey: DefaultsKey.keyboardToothStyle)
    }

    /// 새 설치에 한 번만 켜 준다. 쓰던 사람에게는 손대지 않는다.
    static func seedDefaultIfNeeded(startedFresh: Bool) {
        guard let d = AppGroup.defaults,
              d.object(forKey: DefaultsKey.keyboardToothStyle) == nil else { return }
        d.set(startedFresh, forKey: DefaultsKey.keyboardToothStyle)
    }
}

/// 키캡 윤곽. 평소엔 둥근 사각형, 이빨 장치가 켜지면 **아래로 좁아지는 송곳니**.
///
/// ⚠️ 아래를 뾰족하게 깎지 않고 **살짝만 좁힌다.** 진짜 삼각형으로 만들면 키 이름이
///    잘려 나가고, 좁은 화면에서 두 줄짜리 제목이 통째로 사라진다. 이빨로 읽히는 데에는
///    아랫변이 조금 좁고 아래 모서리가 더 둥근 것으로 충분하다 - 나머지는 잇몸이 맡는다.
struct KeycapShape: InsettableShape {
    let radius: CGFloat
    let tooth: Bool
    /// `strokeBorder` 가 안쪽으로 물러날 때 쓰는 여백.
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> KeycapShape {
        KeycapShape(radius: radius, tooth: tooth, inset: inset + amount)
    }

    func path(in outer: CGRect) -> Path {
        let rect = outer.insetBy(dx: inset, dy: inset)
        guard tooth else {
            return Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
        }
        // 아랫변을 양쪽에서 조금씩 좁힌다. 좁은 키에서 과하게 좁아지지 않게 상한을 둔다.
        let inset = min(rect.width * 0.09, 11)
        let rTop = min(radius, rect.height / 2)
        let rBot = min(radius * 1.5, (rect.width - inset * 2) / 2, rect.height / 2)

        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rTop))
        p.addQuadCurve(to: CGPoint(x: rect.minX + rTop, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - rTop, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rTop),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - rBot))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - inset - rBot, y: rect.maxY),
                       control: CGPoint(x: rect.maxX - inset, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + inset + rBot, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + inset, y: rect.maxY - rBot),
                       control: CGPoint(x: rect.minX + inset, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// 이빨 줄 위에 얹히는 **잇몸**. 아랫변이 물결처럼 늘어져 그 아래 키들이 이빨로 읽힌다.
///
/// ⚠️ 물결 개수를 열 수에 맞추지 않는다. 열 수는 사용자가 1~5로 바꾸는데, 잇몸이
///    거기 맞춰 출렁이면 열을 바꿀 때마다 다른 생물이 된다. 폭에 비례한 **일정한 간격**으로
///    그려 어떤 열 수에서도 같은 입으로 보이게 한다.
struct GumShape: Shape {
    /// 물결 하나의 목표 폭(pt). 실제로는 폭에 맞춰 정수 개로 반올림된다.
    static let scallopWidth: CGFloat = 26

    func path(in rect: CGRect) -> Path {
        let count = max(3, Int((rect.width / Self.scallopWidth).rounded()))
        let w = rect.width / CGFloat(count)
        let drop = min(rect.height * 0.55, 9)
        let baseY = rect.maxY - drop

        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: baseY))
        for i in stride(from: count - 1, through: 0, by: -1) {
            let x0 = rect.minX + CGFloat(i) * w
            p.addQuadCurve(to: CGPoint(x: x0, y: baseY),
                           control: CGPoint(x: x0 + w / 2, y: baseY + drop * 2))
        }
        p.closeSubpath()
        return p
    }
}
