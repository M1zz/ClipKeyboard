//
//  CardSurfaceEffects.swift
//  ClipKeyboard
//
//  카드 한 장의 표면과 두께, 그리고 눌렸을 때의 반응.
//  목록 화면 파일에 같이 살던 것을 꺼냈다. 이것들은 목록의 일부가 아니라
//  "카드는 어떻게 생겼고 어떻게 눌리는가" 라는 이 앱의 표면 언어라서,
//  다른 카드면에서도 그대로 쓸 수 있어야 한다.
//

import SwiftUI

/// 카드 글자 뒤에 까는 할로 - **필요할 때만 깐다.**
///
/// ⚠️ `color` 가 nil 이면 `compositingGroup` 째로 건너뛴다. 이게 이 뷰의 전부다.
///    할로는 유리 너머로 사진이나 카테고리 색이 비칠 때 글자를 붙잡아 주려고 있는데,
///    민 바탕(배경 사진 없음 + 무색 카드) 위에서는 테마 배경색과 **같은 색**이라
///    보이지도 않는다. 그런데 `compositingGroup` 은 카드마다 화면 밖 합성을 한 번씩
///    더 만든다 - 목록에 들어갈 때마다 카드 수만큼 공짜로 내는 값이었다.
struct CardTextHalo: ViewModifier {
    let color: Color?

    func body(content: Content) -> some View {
        if let color {
            content
                .compositingGroup()
                .shadow(color: color, radius: 4, x: 0, y: 0)
        } else {
            content
        }
    }
}
