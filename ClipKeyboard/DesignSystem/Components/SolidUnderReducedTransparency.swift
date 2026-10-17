//
//  SolidUnderReducedTransparency.swift
//  ClipKeyboard
//
//  뒤가 비치는 판(머티리얼 · 반투명 표면)을 '투명도 줄이기'에서는 불투명한 테마 표면으로 바꾼다.
//
//  왜: 비치는 판 위의 글자는 뒤에 무엇이 깔리느냐(목록 배경 사진, 스크롤되는 카드)에 따라
//  대비가 흔들린다. 설정 ▸ 손쉬운 사용 ▸ 디스플레이 및 텍스트 크기 ▸ 투명도 줄이기를 켠 사람은
//  그 흔들림 때문에 켠 것이라, 그때는 단색 판으로 보여 준다.
//
//  ⚠️ 시스템 유리(`glassEffect`)는 이 설정을 스스로 따른다. 여기서 다루는 것은 앱이 직접
//     칠한 머티리얼과 `opacity` 를 낮춘 표면뿐이다.
//

import SwiftUI

/// 모양 하나를 머티리얼로 칠하되, 투명도 줄이기에서는 테마 표면색으로 칠한다.
///
/// `.background { ... }` 안이나 `Capsule().fill(...)` 자리에 그대로 둔다.
struct TranslucentFill<S: Shape>: View {
    let material: Material
    let shape: S

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.appTheme) private var theme

    init(_ material: Material, in shape: S) {
        self.material = material
        self.shape = shape
    }

    var body: some View {
        if reduceTransparency {
            shape.fill(theme.surface)
        } else {
            shape.fill(material)
        }
    }
}

extension TranslucentFill where S == Rectangle {
    init(_ material: Material) {
        self.init(material, in: Rectangle())
    }
}

extension View {
    /// `.background(.regularMaterial)` 대신 쓴다. 투명도 줄이기에서는 불투명한 테마 표면이 깔린다.
    func translucentBackground(_ material: Material) -> some View {
        background { TranslucentFill(material) }
    }
}
