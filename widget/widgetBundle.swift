//
//  widgetBundle.swift
//  widget
//
//  Created by hyunho lee on 2/1/26.
//

import WidgetKit
import SwiftUI

@main
struct ClipKeyboardWidgetBundle: WidgetBundle {
    var body: some Widget {
        FavoriteMemoWidget()
        QuickNoteLockWidget()
        if #available(iOS 18.0, *) {
            QuickNoteControl()
            // 앱을 열지 않고 정해 둔 값을 복사하는 제어센터 버튼.
            CopyValueControl()
        }
    }
}
