//
//  KeyLabelTruncation.swift
//  ClipKeyboard
//
//  **키 이름이 길 때 어떻게 접는가.**
//
//  키 폭은 레이아웃이 정하고 이름은 그 안에서 잘린다. 자르지 않을 방법은 없으니
//  남는 문제는 **어디를 자를 것인가**다.
//
//  ⚠️ 기본이 '가운데 접기'인 이유: 이 앱의 이름은 앞이 겹치는 경우가 흔하다
//     ("신한 계좌번호 예금주", "신한 계좌번호 이체용"). 꼬리를 자르면 둘 다
//     "신한 계좌번호…"가 되어 **키만 보고는 구분할 수 없다.** 뒤를 살리면 구분된다.
//
//  ⚠️ App Group 에 저장한다 - 키보드 익스텐션이 렌더에 쓴다.
//

import SwiftUI

enum KeyLabelTruncation: String, CaseIterable, Identifiable {
    /// 앞뒤를 남기고 가운데를 접는다 (기본).
    case middle
    /// 두 줄로 보여준다. 정보는 더 남지만 키가 높아지거나 답답해진다.
    case twoLines
    /// 한 줄을 지키되 글자를 줄인다. 짧은 키와 크기가 달라 줄이 들쭉날쭉해 보인다.
    case shrink

    var id: String { rawValue }

    static var current: KeyLabelTruncation {
        let raw = AppGroup.defaults?
            .string(forKey: DefaultsKey.keyLabelTruncation) ?? ""
        return KeyLabelTruncation(rawValue: raw) ?? .middle
    }

    var localizedName: String {
        switch self {
        case .middle:   return NSLocalizedString("가운데 접기", comment: "Key label truncation: middle")
        case .twoLines: return NSLocalizedString("두 줄로", comment: "Key label truncation: two lines")
        case .shrink:   return NSLocalizedString("글자 줄이기", comment: "Key label truncation: shrink to fit")
        }
    }

    var localizedDescription: String {
        switch self {
        case .middle:
            return NSLocalizedString("앞뒤를 남기고 가운데만 줄여요. 앞이 비슷한 이름끼리도 구분돼요.",
                                     comment: "Key label truncation description: middle")
        case .twoLines:
            return NSLocalizedString("두 줄까지 보여줘요. 더 많이 보이지만 키가 답답해질 수 있어요.",
                                     comment: "Key label truncation description: two lines")
        case .shrink:
            return NSLocalizedString("한 줄을 지키면서 글자를 조금 줄여요.",
                                     comment: "Key label truncation description: shrink")
        }
    }

    /// 미리보기에 쓰는 보기 문구 - 고르기 전에 결과를 보여준다.
    static let sampleTitle = NSLocalizedString("신한 계좌번호 예금주",
                                               comment: "Key label truncation preview sample")
}

// MARK: - 적용

extension View {
    /// 키 이름에 접기 방식을 적용한다. 두 종류의 키가 **같은 규칙**을 따르도록 한 곳에 둔다.
    func keyLabelTruncation(_ style: KeyLabelTruncation) -> some View {
        modifier(KeyLabelTruncationModifier(style: style))
    }
}

struct KeyLabelTruncationModifier: ViewModifier {
    let style: KeyLabelTruncation

    func body(content: Content) -> some View {
        switch style {
        case .middle:
            content.lineLimit(1).truncationMode(.middle)
        case .twoLines:
            content.lineLimit(2).truncationMode(.tail)
        case .shrink:
            // 0.65 아래로는 옆 키와 크기 차이가 눈에 띄게 벌어져 줄이 어지러워진다.
            content.lineLimit(1).truncationMode(.tail).minimumScaleFactor(0.65)
        }
    }
}
