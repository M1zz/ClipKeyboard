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

// MARK: - 클립키보드 하나로 쓰기

/// 다른 키보드를 빼고 이 키보드 하나로 쓰는 법. 설정 ▸ 키보드에서 온다.
///
/// 지구본과 마이크는 iOS 가 우리 판 **밖에** 그린다(`docs/postmortem/KEYBOARD_SYSTEM_CHROME_5_0_6.md`).
/// 앱이 끌 수 없어서, 앱이 할 수 있는 것은 **어디를 누르는지 말하는 것**뿐이다.
///
/// ⚠️ 그 띠는 키보드를 하나만 남기고 받아쓰기를 꺼도 남는다. 홈 버튼 없는 iPhone 에서 홈 막대와
///    겹치지 않게 iOS 가 늘 비워 두는 자리다. 그래서 "빼면 사라진다" 고 하지 않고 그 자리를 쓰는 법을 알린다.
struct OnlyThisKeyboardGuideView: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("클립키보드 하나로 써요", comment: "Only-this-keyboard guide headline"))
                        .font(.title2.weight(.bold))
                        .foregroundColor(theme.text)
                        .accessibilityAddTraits(.isHeader)
                    Text(NSLocalizedString("글은 자판으로 치고, 자주 쓰는 글은 단축어로 꺼내요. 다른 키보드로 오갈 일이 없어져요.",
                                           comment: "Only-this-keyboard guide subtitle"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                stepGroup(
                    title: NSLocalizedString("다른 키보드 빼기", comment: "Only-this-keyboard guide: remove other keyboards section"),
                    note: NSLocalizedString("클립키보드 하나만 남기면 지구본은 빠지지만, 맨 아래 띠는 남아요. 이모지를 쓰려면 이모티콘 키보드는 남겨 두세요.",
                                            comment: "Only-this-keyboard guide: removing other keyboards hides the globe key, but the bottom strip stays"),
                    steps: [
                        NSLocalizedString("설정 앱에서 일반 ▸ 키보드 ▸ 키보드를 열어요", comment: "Only-this-keyboard guide: open the keyboard list"),
                        NSLocalizedString("오른쪽 위 '편집'을 눌러요", comment: "Only-this-keyboard guide: tap Edit"),
                        NSLocalizedString("클립키보드만 남기고 나머지를 빼요", comment: "Only-this-keyboard guide: remove the other keyboards")
                    ])
                stepGroup(
                    title: NSLocalizedString("받아쓰기 끄기", comment: "Only-this-keyboard guide: turn off dictation section"),
                    note: NSLocalizedString("끄면 키보드 아래의 마이크가 사라져요. 말로 받아쓰기를 쓴다면 켜 두세요.",
                                            comment: "Only-this-keyboard guide: turning off dictation hides the microphone"),
                    steps: [
                        NSLocalizedString("설정 앱에서 일반 ▸ 키보드를 열어요", comment: "Only-this-keyboard guide: open keyboard settings"),
                        NSLocalizedString("아래쪽의 '받아쓰기 활성화'를 꺼요", comment: "Only-this-keyboard guide: turn off Enable Dictation")
                    ])
                stepGroup(
                    title: NSLocalizedString("맨 아래 띠 쓰기", comment: "Only-this-keyboard guide: using the bottom strip section"),
                    note: NSLocalizedString("홈 버튼이 없는 iPhone에서는 홈 막대와 겹치지 않게 iOS가 키보드 아래에 늘 띠를 비워 둬요. 키보드를 하나만 남기고 받아쓰기를 꺼도 남고, 접는 설정은 없어요. 어느 키보드든 이 띠 위에 올라가요. 그래서 이 자리를 쓰게 두는 편이 나아요.",
                                            comment: "Only-this-keyboard guide: why the bottom strip under the keyboard can never be removed on Face ID iPhones"),
                    steps: [
                        NSLocalizedString("설정 앱에서 일반 ▸ 키보드 ▸ 키보드 ▸ 새로운 키보드 추가를 눌러요", comment: "Only-this-keyboard guide: open Add New Keyboard"),
                        NSLocalizedString("'이모티콘'을 골라요. 지구본 대신 😀 키가 왼쪽에 서요", comment: "Only-this-keyboard guide: add the Emoji keyboard so the globe becomes an emoji key"),
                        NSLocalizedString("받아쓰기를 켜 두면 오른쪽에 마이크가 서요", comment: "Only-this-keyboard guide: keep dictation on to put the microphone on the right")
                    ])
                stepGroup(
                    title: NSLocalizedString("자판과 단축어 오가기", comment: "Only-this-keyboard guide: switching between typing and snippets"),
                    note: nil,
                    steps: [
                        NSLocalizedString("자판 위의 '단축어'를 누르면 단축어 판이 나와요", comment: "Only-this-keyboard guide: open snippets from the typing keyboard"),
                        NSLocalizedString("단축어 판의 키보드 키를 누르면 자판으로 돌아와요", comment: "Only-this-keyboard guide: back to typing from snippets"),
                        NSLocalizedString("자판의 언어 키로 언어를 바꿔요. 순서는 입력 언어에서 정해요", comment: "Only-this-keyboard guide: language key and order")
                    ])
                Text(NSLocalizedString("비밀번호 칸에서는 iOS 가 잠깐 기본 키보드를 띄워요. 앱이 바꿀 수 없는 일이에요.",
                                       comment: "Only-this-keyboard guide: password fields always use the system keyboard"))
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .background(theme.bg.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("클립키보드 하나로 쓰기", comment: "Only-this-keyboard guide title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stepGroup(title: String, note: String?, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(theme.text)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(steps.enumerated()), id: \.offset) { index, text in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(index + 1, format: .number)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.accentColor)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(theme.accentSoft))
                        .accessibilityHidden(true)
                    Text(text)
                        .font(.body)
                        .foregroundColor(theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            if let note {
                Text(note)
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
