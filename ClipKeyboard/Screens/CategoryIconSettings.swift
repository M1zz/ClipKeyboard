//
//  CategoryIconSettings.swift
//  ClipKeyboard
//
//  키보드 카테고리 탭에 표시되는 SF Symbol을 사용자가 직접 고르는 설정 화면.
//  선택값은 App Group UserDefaults(userCategoryIcons_v1)에 [카테고리명: 심볼명] 형태로 저장.
//

import SwiftUI
import LeeoKit

// MARK: - Storage

private let kIconsKey  = "userCategoryIcons_v1"
private let kCatsKey   = "userDefinedCategories_v1"

private func loadCustomIcons() -> [String: String] {
    UserDefaults(suiteName: AppGroup.identifier)?.dictionary(forKey: kIconsKey) as? [String: String] ?? [:]
}

private func saveCustomIcons(_ dict: [String: String]) {
    UserDefaults(suiteName: AppGroup.identifier)?.set(dict, forKey: kIconsKey)
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
        UserDefaults(suiteName: AppGroup.identifier)?.stringArray(forKey: kCatsKey) ?? []
    }

    var body: some View {
        List {
            Section {
                ForEach(categories, id: \.self) { cat in
                    Button {
                        pickingForCategory = cat
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: icons[cat] ?? defaultIcon(for: cat, in: categories))
                                .font(.title3)
                                .foregroundColor(defaultColor(for: cat, in: categories))
                                .frame(width: 28)
                                .accessibilityHidden(true)
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
                Text(NSLocalizedString("키보드에서 카테고리 탭에 표시되는 아이콘을 변경합니다.", comment: "Category icon settings footer"))
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
                SymbolPickerSheet(
                    category: cat,
                    current: icons[cat]
                ) { symbol in
                    icons[cat] = symbol
                    saveCustomIcons(icons)
                    pickingForCategory = nil
                }
            }
        }
    }
}

// MARK: - Symbol Picker Sheet

struct SymbolPickerSheet: View {
    @Environment(\.appTheme) private var theme
    let category: String
    let current: String?
    let onSelect: (String) -> Void

    @State private var search = ""
    @Environment(\.dismiss) private var dismiss

    private var allSymbols: [String] { symbolCatalog.flatMap(\.symbols) }

    private var filtered: [String] {
        guard !search.isEmpty else { return [] }
        return allSymbols.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 검색 결과 또는 카탈로그 섹션
                    if !search.isEmpty {
                        if filtered.isEmpty {
                            Text(NSLocalizedString("검색 결과 없음", comment: "No symbol search results"))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            symbolGrid(symbols: filtered)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                        }
                    } else {
                        ForEach(symbolCatalog) { section in
                            Text(section.id)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 16)
                                .padding(.top, 20)
                                .padding(.bottom, 6)
                            symbolGrid(symbols: section.symbols)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: NSLocalizedString("심볼 이름 검색", comment: "Symbol name search prompt"))
            .navigationTitle(category)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("취소", comment: "Cancel")) { dismiss() }
                }
            }
        }
    }

    private func symbolGrid(symbols: [String]) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(symbols, id: \.self) { symbol in
                Button {
                    onSelect(symbol)
                } label: {
                    Image(systemName: symbol)
                        .font(.title2)
                        .frame(width: 48, height: 48)
                        .background(current == symbol ? Color.blue : Color(.systemGray5))
                        .foregroundColor(current == symbol ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(symbol)
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
    let palette: [Color] = [.blue, .green, .orange, .purple, .teal, .indigo, .cyan]
    let idx = list.firstIndex(of: category) ?? 0
    return palette[idx % palette.count]
}

/// 카테고리 심볼 — 사용자 지정(userCategoryIcons_v1) 우선, 없으면 기본 팔레트.
/// 카드·메뉴·키보드 프리뷰가 모두 이 한 가지 규칙을 공유한다.
func categorySymbol(for category: String, in list: [String]) -> String {
    if let custom = UserDefaults(suiteName: AppGroup.identifier)?
        .dictionary(forKey: DefaultsKey.userCategoryIconsV1) as? [String: String],
       let symbol = custom[category] {
        return symbol
    }
    return defaultIcon(for: category, in: list)
}

/// 카테고리 색 — 사용자 지정(userCategoryColors_v1) 우선, 없으면 기본 팔레트.
func categoryTint(for category: String, in list: [String]) -> Color {
    if let custom = UserDefaults(suiteName: AppGroup.identifier)?
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
