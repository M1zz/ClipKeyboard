//
//  FontSetting.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/06/07.
//

import SwiftUI

enum FontSize: CGFloat {
    case small = 16
    case medium = 20
    case large = 24
}


struct FontSetting: View {

    @Environment(\.appTheme) private var theme
    @State private var fontSize: CGFloat = UserDefaults.standard.object(forKey: "fontSize") as? CGFloat ?? 20.0

    var body: some View {
        VStack {
            Text(NSLocalizedString("이 사이즈로 내용이 보입니다.", comment: "Font size preview text"))
                .font(.system(size: fontSize))
                .padding()

            Slider(value: Binding(
                get: { self.fontSize },
                set: { self.fontSize = $0; saveFontSize() }
            ), in: 10...40, step: 2)
            .padding()
            .padding()
            .accessibilityLabel(NSLocalizedString("앱 내 폰트 크기", comment: "Font size slider label"))
            .accessibilityValue(String(format: NSLocalizedString("%d포인트", comment: "Font size value format"), Int(fontSize)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("앱 내 폰트 크기", comment: "App font size"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    
    func saveFontSize() {
        UserDefaults.standard.set(fontSize, forKey: "fontSize")
    }
}

struct FontSetting_Previews: PreviewProvider {
    static var previews: some View {
        FontSetting()
    }
}
