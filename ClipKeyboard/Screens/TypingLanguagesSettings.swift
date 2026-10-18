//
//  TypingLanguagesSettings.swift
//  ClipKeyboard
//
//  설정 > 키보드 > 입력 언어. 자판에서 칠 언어를 켜고 순서를 정한다.
//
//  ⚠️ 키보드의 언어 키는 이 순서대로 돈다. 맨 위 언어가 처음 열 때의 언어다.
//  ⚠️ 언어 이름은 번역하지 않는다(`TypingLanguage.nativeName`). 그 아래 줄에 iOS 가
//     지금 화면 언어로 붙여 준 이름을 단다. 둘 다 있어야 누구나 제 언어를 찾는다.
//

import SwiftUI

struct TypingLanguagesSettings: View {
    @AppStorage(TypingPrefs.languagesKey, store: AppGroup.defaults) private var languagesRaw: String = ""
    @AppStorage(TypingPrefs.currentKey, store: AppGroup.defaults) private var currentRaw: String = ""
    @AppStorage(KeyboardPrefs.koreanLayout.key, store: AppGroup.defaults)
    private var koreanLayoutRaw: String = KeyboardPrefs.koreanLayout.fallback

    @State private var languages: [TypingLanguage] = []

    private var available: [TypingLanguage] {
        TypingLanguage.allCases.filter { !languages.contains($0) }
            .sorted { $0.nativeName.localizedCaseInsensitiveCompare($1.nativeName) == .orderedAscending }
    }

    var body: some View {
        List {
            Section {
                ForEach(languages) { lang in
                    row(lang)
                }
                .onMove { from, to in
                    languages.move(fromOffsets: from, toOffset: to)
                    save()
                }
                .onDelete { offsets in
                    // 하나는 남긴다. 언어가 없으면 자판이 칠 것이 없다.
                    guard languages.count - offsets.count >= 1 else { return }
                    languages.remove(atOffsets: offsets)
                    save()
                }
            } header: {
                Text(NSLocalizedString("켜 둔 언어", comment: "Typing languages: enabled section header"))
            } footer: {
                Text(NSLocalizedString("키보드의 언어 키가 이 순서대로 바뀌어요. 끌어서 순서를 바꾸고, 밀어서 뺄 수 있어요.",
                                       comment: "Typing languages: enabled section footer"))
            }

            if languages.contains(.ko) {
                Section {
                    Picker(NSLocalizedString("한국어 레이아웃", comment: "Korean layout picker label"), selection: $koreanLayoutRaw) {
                        Text(NSLocalizedString("두벌식", comment: "Korean layout: dubeolsik")).tag(KoreanTypingLayout.dubeolsik.rawValue)
                        Text(NSLocalizedString("천지인", comment: "Korean layout: cheonjiin")).tag(KoreanTypingLayout.cheonjiin.rawValue)
                    }
                }
            }

            if languages.contains(where: \.needsConversionDictionary) {
                Section {
                    Text(NSLocalizedString("일본어는 가나, 중국어는 병음·주음까지 칠 수 있어요. 한자로 바꾸는 사전은 다음 업데이트에서 필요할 때 받아 쓰게 돼요.",
                                           comment: "Typing languages: CJK conversion dictionary is coming later"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(available) { lang in
                    Button {
                        withAnimation {
                            languages.append(lang)
                            save()
                        }
                    } label: {
                        HStack {
                            labels(lang)
                            Spacer()
                            Image(systemName: AppSymbol.plusCircleFill)
                                .foregroundStyle(Color.accentColor)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(NSLocalizedString("이 언어를 키보드에 더합니다", comment: "Typing languages: add language hint"))
                }
            } header: {
                Text(NSLocalizedString("더할 수 있는 언어", comment: "Typing languages: available section header"))
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle(NSLocalizedString("입력 언어", comment: "Settings: typing languages screen title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { languages = TypingPrefs.languages(from: languagesRaw) }
    }

    private func row(_ lang: TypingLanguage) -> some View {
        labels(lang)
            .accessibilityElement(children: .combine)
    }

    private func labels(_ lang: TypingLanguage) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(lang.nativeName)
            if let localized = Locale.current.localizedString(forIdentifier: lang.rawValue),
               localized != lang.nativeName {
                Text(localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 저장하고, 예전 키(검색칸 자판이 보는 것)도 맞춘다.
    private func save() {
        languagesRaw = TypingPrefs.raw(from: languages)
        if let current = TypingLanguage(rawValue: currentRaw), !languages.contains(current) {
            currentRaw = languages.first?.rawValue ?? ""
        }
        // 검색칸 자판은 아직 한/영 둘만 안다. 한국어가 켜져 있으면 한/EN 키를 보이게 한다.
        let defaults = AppGroup.defaults
        defaults?.set(languages.contains(.ko), forKey: KeyboardPrefs.koreanEnabled.key)
        defaults?.set(languages.first == .ko ? "korean" : "english", forKey: KeyboardPrefs.typingLang.key)
    }
}
