//
//  IconPickerSheet.swift
//  ClipKeyboard
//
//  단축어 · 카테고리 아이콘 고르기. 이모지 · 심볼 · 내 그림 세 갈래를 한 화면에 둔다.
//  내 그림은 사진에서 올리고, 한 번 올린 것은 다른 단축어 · 카테고리에서도 다시 고른다.
//

import SwiftUI
import PhotosUI
import LeeoKit

struct IconPickerSheet: View {
    /// 시트 제목 (단축어 이름이나 카테고리 이름).
    let title: String
    let current: SnippetIcon?
    /// 고르면 부른다. nil 은 "아이콘 없애기".
    let onPick: (SnippetIcon?) -> Void

    enum Source: Hashable, CaseIterable {
        case emoji, symbol, image

        var localizedName: String {
            switch self {
            case .emoji:  return NSLocalizedString("이모지", comment: "Icon picker tab: emoji")
            case .symbol: return NSLocalizedString("심볼", comment: "Icon picker tab: SF Symbols")
            case .image:  return NSLocalizedString("내 그림", comment: "Icon picker tab: images the user uploaded")
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @ScaledMetric(relativeTo: .title) private var cell: CGFloat = 48

    @State private var source: Source
    @State private var uploads: [String] = SnippetIconStore.saved()
    @State private var photoItem: PhotosPickerItem?
    @State private var isImporting = false

    init(title: String, current: SnippetIcon?, onPick: @escaping (SnippetIcon?) -> Void) {
        self.title = title
        self.current = current
        self.onPick = onPick
        // 지금 고른 것이 있는 갈래에서 연다.
        switch current {
        case .symbol: _source = State(initialValue: .symbol)
        case .image:  _source = State(initialValue: .image)
        default:      _source = State(initialValue: .emoji)
        }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: cell + 8), spacing: 10)]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(NSLocalizedString("아이콘", comment: "Icon picker title"), selection: $source) {
                    ForEach(Source.allCases, id: \.self) { Text($0.localizedName).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch source {
                        case .emoji:  emojiContent
                        case .symbol: symbolContent
                        case .image:  imageContent
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if current != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(NSLocalizedString("아이콘 없애기", comment: "Icon picker: remove the icon")) {
                            pick(nil)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    GlassCircleButton(AppSymbol.xmark, role: .secondary,
                                      label: NSLocalizedString("닫기", comment: "Close")) {
                        dismiss()
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            importPhoto(item)
        }
    }

    // MARK: - Emoji

    @ViewBuilder
    private var emojiContent: some View {
        ForEach(EmojiCategory.allCases, id: \.self) { category in
            let emojis = category.emojis
            if !emojis.isEmpty {
                sectionTitle(category.localizedName)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(emojis, id: \.self) { emoji in
                        tile(selected: current == .emoji(emoji), label: emoji) {
                            rememberRecentEmoji(emoji)
                            pick(.emoji(emoji))
                        } content: {
                            Text(emoji).font(.system(size: cell * 0.62))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Symbol

    private var symbolContent: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(symbolCatalog.flatMap(\.symbols), id: \.self) { symbol in
                tile(selected: current == .symbol(symbol), label: symbol) {
                    pick(.symbol(symbol))
                } content: {
                    Image(systemName: symbol)
                        .font(.title2)
                        .foregroundStyle(theme.text)
                }
            }
        }
    }

    // MARK: - My Images

    @ViewBuilder
    private var imageContent: some View {
        Text(NSLocalizedString("올린 그림은 다른 단축어와 카테고리에서도 다시 고를 수 있어요. 길게 누르면 지울 수 있어요.", comment: "Icon picker: uploaded images footer"))
            .font(.body)
            .foregroundStyle(theme.textMuted)

        LazyVGrid(columns: columns, spacing: 10) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(theme.textFaint, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    if isImporting {
                        ProgressView()
                    } else {
                        Image(systemName: AppSymbol.plus)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(theme.textMuted)
                    }
                }
                .frame(width: cell, height: cell)
                .contentShape(Rectangle())
            }
            .disabled(isImporting)
            .accessibilityLabel(NSLocalizedString("사진에서 올리기", comment: "Icon picker: upload an image from Photos"))

            ForEach(uploads, id: \.self) { file in
                tile(selected: current == .image(file),
                     label: NSLocalizedString("내 그림", comment: "Icon picker tab: images the user uploaded")) {
                    pick(.image(file))
                } content: {
                    SnippetIconView(icon: .image(file), size: cell - 6)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        SnippetIconStore.remove(file)
                        uploads.removeAll { $0 == file }
                    } label: {
                        Label(NSLocalizedString("삭제", comment: "Delete"), systemImage: AppSymbol.trash)
                    }
                }
            }
        }
    }

    // MARK: - Parts

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.body.weight(.semibold))
            .foregroundStyle(theme.textMuted)
    }

    private func tile<Content: View>(selected: Bool, label: String,
                                     action: @escaping () -> Void,
                                     @ViewBuilder content: () -> Content) -> some View {
        Button(action: action) {
            content()
                .frame(width: cell, height: cell)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? theme.accent.opacity(0.18) : theme.surface)
                }
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(theme.accent, lineWidth: 2)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.squish)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Actions

    private func pick(_ icon: SnippetIcon?) {
        HapticManager.shared.selection()
        onPick(icon)
        dismiss()
    }

    private func rememberRecentEmoji(_ emoji: String) {
        var recents = UserDefaults.standard.stringArray(forKey: DefaultsKey.recentEmojis) ?? []
        recents.removeAll { $0 == emoji }
        recents.insert(emoji, at: 0)
        UserDefaults.standard.set(Array(recents.prefix(30)), forKey: DefaultsKey.recentEmojis)
    }

    private func importPhoto(_ item: PhotosPickerItem) {
        isImporting = true
        Task {
            defer {
                isImporting = false
                photoItem = nil
            }
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let file = SnippetIconStore.add(image) else {
                    print("❌ [IconPickerSheet.importPhoto] 그림을 읽지 못했다")
                    return
                }
                uploads.insert(file, at: 0)
                pick(.image(file))
            } catch {
                print("❌ [IconPickerSheet.importPhoto] \(error)")
            }
        }
    }
}
