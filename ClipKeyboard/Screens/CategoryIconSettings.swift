//
//  CategoryIconSettings.swift
//  ClipKeyboard
//
//  카테고리 아이콘을 고르는 설정 화면. 심볼 · 이모지 · 내 그림 가운데서 고른다(`IconPickerSheet`).
//  선택값은 App Group UserDefaults(userCategoryIcons_v1)에 [카테고리명: 아이콘 글자] 형태로 저장.
//  아이콘 글자는 `SnippetIcon.raw` 다. 예전 값(심볼 이름)은 그대로 심볼로 읽힌다.
//

import SwiftUI
import LeeoKit

// MARK: - Storage

private let kIconsKey  = "userCategoryIcons_v1"
private let kCatsKey   = "userDefinedCategories_v1"

private func loadCustomIcons() -> [String: String] {
    AppGroup.defaults?.dictionary(forKey: kIconsKey) as? [String: String] ?? [:]
}

private func saveCustomIcons(_ dict: [String: String]) {
    AppGroup.defaults?.set(dict, forKey: kIconsKey)
    CategorySnapshotStore.notifyChanged()
}

// MARK: - Symbol Catalog

struct SymbolSection: Identifiable {
    let id: String
    let symbols: [String]
}

let symbolCatalog: [SymbolSection] = [
    SymbolSection(id: "General", symbols: [
        "folder.fill", "tag.fill", "bookmark.fill", "star.fill", "doc.fill",
        "tray.fill", "archivebox.fill", "note.text", "paperclip", "pin.fill",
        "flag.fill", "bell.fill", "house.fill", "link", "list.bullet",
        "square.grid.2x2.fill", "rectangle.stack.fill", "externaldrive.fill"
    ]),
    SymbolSection(id: "People", symbols: [
        "person.fill", "person.2.fill", "person.crop.circle.fill",
        "figure.walk", "figure.run", "hands.clap.fill", "hand.raised.fill"
    ]),
    SymbolSection(id: "Communication", symbols: [
        "phone.fill", "envelope.fill", "message.fill",
        "bubble.left.fill", "at", "video.fill", "mic.fill", "megaphone.fill"
    ]),
    SymbolSection(id: "Finance", symbols: [
        "creditcard.fill", "banknote", "dollarsign.circle.fill",
        "cart.fill", "bag.fill", "chart.bar.fill", "building.columns.fill",
        "chart.pie.fill", "percent"
    ]),
    SymbolSection(id: "Travel", symbols: [
        "airplane", "car.fill", "bus", "train.side.front.car",
        "bicycle", "map.fill", "location.fill", "globe", "suitcase.fill", "compass.drawing"
    ]),
    SymbolSection(id: "Time", symbols: [
        "clock.fill", "calendar", "alarm.fill", "timer", "hourglass", "stopwatch.fill"
    ]),
    SymbolSection(id: "Health", symbols: [
        "heart.fill", "cross.fill", "staroflife.fill", "pills.fill",
        "bandage.fill", "stethoscope", "figure.strengthtraining.traditional"
    ]),
    SymbolSection(id: "Education", symbols: [
        "book.fill", "graduationcap.fill", "pencil", "newspaper.fill",
        "text.book.closed.fill", "lightbulb.fill", "brain.head.profile"
    ]),
    SymbolSection(id: "Media", symbols: [
        "photo.fill", "music.note", "film.fill",
        "gamecontroller.fill", "headphones", "tv.fill", "camera.fill"
    ]),
    SymbolSection(id: "Security & Tech", symbols: [
        "lock.fill", "key.fill", "wifi", "iphone", "desktopcomputer",
        "gear", "qrcode", "shield.fill", "antenna.radiowaves.left.and.right"
    ])
]

// MARK: - Main View

struct CategoryIconSettings: View {
    @State private var icons: [String: String] = loadCustomIcons()
    @State private var pickingForCategory: String?
    @Environment(\.appTheme) private var theme

    private var categories: [String] {
        AppGroup.defaults?.stringArray(forKey: kCatsKey) ?? []
    }

    var body: some View {
        List {
            Section {
                ForEach(categories, id: \.self) { cat in
                    Button {
                        pickingForCategory = cat
                    } label: {
                        HStack(spacing: 14) {
                            SnippetIconView(icon: SnippetIcon(raw: icons[cat]) ?? .symbol(defaultIcon(for: cat, in: categories)),
                                            size: 28,
                                            tint: categoryTint(for: cat, in: categories))
                            Text(cat)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: AppSymbol.chevronRight)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel(String(format: NSLocalizedString("%@, 아이콘 변경", comment: "Category row a11y: change icon"), cat))
                }
            } footer: {
                Text(NSLocalizedString("카테고리 칸과 단축어 카드에 보일 아이콘을 고릅니다. 이모지나 사진에서 올린 그림도 쓸 수 있어요.", comment: "Category icon settings footer"))
                    .font(.body)
            }

            if !icons.isEmpty {
                Section {
                    Button(role: .destructive) {
                        icons = [:]
                        saveCustomIcons([:])
                    } label: {
                        Label(NSLocalizedString("기본값으로 초기화", comment: "Reset icons to default"), systemImage: AppSymbol.arrowCounterclockwise)
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("카테고리 아이콘", comment: "Category icons screen title"))
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .sheet(isPresented: Binding(
            get: { pickingForCategory != nil },
            set: { if !$0 { pickingForCategory = nil } }
        )) {
            if let cat = pickingForCategory {
                IconPickerSheet(title: cat, current: SnippetIcon(raw: icons[cat])) { picked in
                    icons[cat] = picked?.raw
                    saveCustomIcons(icons)
                    pickingForCategory = nil
                }
            }
        }
    }
}

// MARK: - Helpers

func defaultIcon(for category: String, in list: [String]) -> String {
    let palette = ["folder.fill", "bookmark.fill", "tag.fill", "briefcase.fill",
                   "star.fill", "heart.circle.fill", "person.fill", "house.fill"]
    let idx = list.firstIndex(of: category) ?? 0
    return palette[idx % palette.count]
}

func defaultColor(for category: String, in list: [String]) -> Color {
    let palette = Color.categoryPalette
    let idx = list.firstIndex(of: category) ?? 0
    return palette[idx % palette.count]
}

/// 카테고리 심볼 - 사용자 지정(userCategoryIcons_v1) 우선, 없으면 기본 팔레트.
/// 카드·메뉴·키보드 프리뷰가 모두 이 한 가지 규칙을 공유한다.
/// ⚠️ 심볼만 돌려준다. 이모지 · 그림을 고른 카테고리는 심볼만 그릴 수 있는 자리(메뉴 등)에서
///    기본 심볼로 물러난다. 고른 아이콘 그대로 그리려면 `customCategoryIcon(for:)`.
func categorySymbol(for category: String, in list: [String]) -> String {
    if let symbol = customCategoryIcon(for: category)?.symbolName {
        return symbol
    }
    return defaultIcon(for: category, in: list)
}

/// 카테고리 색 - 사용자 지정(userCategoryColors_v1) 우선, 없으면 기본 팔레트.
func categoryTint(for category: String, in list: [String]) -> Color {
    if let custom = AppGroup.defaults?
        .dictionary(forKey: DefaultsKey.userCategoryColorsV1) as? [String: String],
       let hex = custom[category], let c = Color(hex: hex) {
        return c
    }
    return defaultColor(for: category, in: list)
}

// MARK: - Preview

#Preview {
    NavigationStack { CategoryIconSettings() }
}
