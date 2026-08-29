//
//  LanguageSettingsView.swift
//  ClipKeyboard
//
//  앱 언어 고르기. 고르는 즉시 바뀐다 - 앱을 껐다 켜라고 시키지 않는다.
//  실제 전환은 `AppLanguage` 가 한다(번들을 앞에 세우는 방식, 그쪽 머리말 참고).
//

import SwiftUI

struct LanguageSettingsView: View {
    @Environment(\.appTheme) private var theme
    @State private var selection: AppLanguage = AppLanguage.current

    var body: some View {
        List {
            Section {
                ForEach(AppLanguage.available) { language in
                    Button {
                        guard language != selection else { return }
                        selection = language
                        AppLanguage.select(language)
                    } label: {
                        HStack {
                            Text(language.displayName)
                                .foregroundColor(theme.text)
                            Spacer()
                            if language == selection {
                                Image(systemName: "checkmark")
                                    .foregroundColor(theme.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(language == selection ? [.isButton, .isSelected] : .isButton)
                }
            } footer: {
                // 키보드는 다른 프로세스라, 이미 떠 있는 키보드는 다음에 열 때부터 바뀐다.
                Text(NSLocalizedString("고르는 즉시 앱에 적용돼요. 키보드는 다음에 열 때부터 바뀝니다.",
                                       comment: "Language settings footer"))
                    .font(.body)
            }
        }
        .navigationTitle(NSLocalizedString("언어", comment: "Settings: app language"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
