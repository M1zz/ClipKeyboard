//
//  EmojiPicker.swift
//  ClipKeyboard
//

import SwiftUI

enum EmojiCategory: String, CaseIterable {
    case recent = "최근"
    case smileys = "표정"
    case gestures = "손짓"
    case animals = "동물"
    case food = "음식"
    case activities = "활동"
    case symbols = "기호"

    var icon: String {
        switch self {
        case .recent: return "clock.fill"
        case .smileys: return "face.smiling"
        case .gestures: return "hand.raised.fill"
        case .animals: return "pawprint.fill"
        case .food: return "fork.knife"
        case .activities: return "sportscourt.fill"
        case .symbols: return "heart.fill"
        }
    }

    var localizedName: String {
        return NSLocalizedString(self.rawValue, comment: "Emoji category name")
    }

    var emojis: [String] {
        switch self {
        case .recent:
            return UserDefaults.standard.stringArray(forKey: DefaultsKey.recentEmojis) ?? []
        case .smileys:
            return ["😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙", "🥲", "😋", "😛", "😜", "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔", "🤐", "🤨", "😐", "😑", "😶", "😏", "😒", "🙄", "😬", "😌", "😔", "😪", "🤤", "😴", "😷", "🤒", "🤕", "🥵", "🥶", "😎", "🤓", "🧐"]
        case .gestures:
            return ["👋", "🤚", "🖐", "✋", "🖖", "👌", "🤌", "🤏", "✌️", "🤞", "🤟", "🤘", "🤙", "👈", "👉", "👆", "👇", "☝️", "👍", "👎", "✊", "👊", "🤛", "🤜", "👏", "🙌", "👐", "🤲", "🤝", "🙏"]
        case .animals:
            return ["🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🙈", "🙉", "🙊", "🐒", "🐔", "🐧", "🐦", "🐤", "🐣", "🐥", "🦆", "🦅", "🦉", "🦇", "🐺", "🐗", "🐴", "🦄", "🐝", "🐛", "🦋", "🐌", "🐞", "🐢", "🐍", "🦎", "🦖", "🦕", "🐙", "🦑", "🦐", "🦞", "🦀", "🐡", "🐠", "🐟", "🐬", "🐳", "🐋", "🦈"]
        case .food:
            return ["🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", "🥒", "🌶", "🌽", "🥕", "🧄", "🧅", "🥔", "🍠", "🥐", "🍞", "🥖", "🥨", "🧀", "🥚", "🍳", "🥞", "🥓", "🍗", "🍖", "🌭", "🍔", "🍟", "🍕", "🥪", "🌮", "🌯", "🥗", "🍝", "🍜", "🍲", "🍛", "🍣", "🍱", "🍤", "🍙", "🍚"]
        case .activities:
            return ["⚽️", "🏀", "🏈", "⚾️", "🎾", "🏐", "🏉", "🎱", "🏓", "🏸", "🏒", "🏑", "🥅", "⛳️", "🏹", "🎣", "🥊", "🥋", "🎽", "🛹", "🛼", "⛸", "🥌", "🎿", "⛷", "🏂", "🤼", "🤸", "⛹️", "🤺", "🤾", "🏌️"]
        case .symbols:
            return ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "☮️", "✝️", "☪️", "🕉", "☸️", "✡️", "🔯", "🕎", "☯️", "⛎", "♈️", "♉️", "♊️", "♋️", "♌️", "♍️", "♎️", "♏️", "♐️", "♑️", "♒️", "♓️", "⚛️", "✴️", "💮"]
        }
    }
}

struct EmojiPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedCategory: EmojiCategory = .smileys

    let onEmojiSelected: (String) -> Void

    /// Dynamic Type에 맞춰 이모지 글자 크기를 함께 키운다(기본 32pt 기준).
    @ScaledMetric(relativeTo: .title) private var emojiSize: CGFloat = 32

    /// 이모지 크기에 따라 열을 자동 재배치 — 큰 글자 크기에서 7열 고정으로 잘리지 않도록 adaptive.
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: emojiSize + 12), spacing: 8)]
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(EmojiCategory.allCases, id: \.self) { category in
                            if category == .recent && category.emojis.isEmpty {
                                EmptyView()
                            } else {
                                CategoryTabButton(
                                    category: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                        selectedCategory = category
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(theme.surface)

                Divider()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(selectedCategory.emojis, id: \.self) { emoji in
                            Button {
                                selectEmoji(emoji)
                            } label: {
                                Text(emoji)
                                    .font(.system(size: emojiSize))
                            }
                            .buttonStyle(EmojiButtonStyle())
                            // 이모지 자체를 VoiceOver 라벨로 노출(이름 읽힘) + 버튼 트레잇 명시.
                            .accessibilityLabel(emoji)
                            .accessibilityAddTraits(.isButton)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(NSLocalizedString("이모지 선택", comment: "Emoji picker title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("완료", comment: "Done button")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func selectEmoji(_ emoji: String) {
        var recents = UserDefaults.standard.stringArray(forKey: DefaultsKey.recentEmojis) ?? []
        recents.removeAll { $0 == emoji }
        recents.insert(emoji, at: 0)
        if recents.count > 30 {
            recents = Array(recents.prefix(30))
        }
        UserDefaults.standard.set(recents, forKey: DefaultsKey.recentEmojis)

        onEmojiSelected(emoji)
        dismiss()
    }
}

struct CategoryTabButton: View {
    @Environment(\.appTheme) private var theme
    let category: EmojiCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.system(.title3))
                    .accessibilityHidden(true)
                Text(category.localizedName)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .blue : .secondary)
            .frame(width: 60)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusSm)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        // 카테고리 이름만 읽고, 선택 상태를 VoiceOver에 노출(아이콘은 장식이라 숨김).
        .accessibilityElement(children: .combine)
        .accessibilityLabel(category.localizedName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct EmojiButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.2 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
