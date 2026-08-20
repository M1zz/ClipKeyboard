//
//  CategorySettings.swift
//  ClipKeyboard
//
//  사용자 카테고리 관리 - 추가/이름변경/삭제/순서변경.
//  CategoryStore (App Group 영구 저장)와 연동.
//

import SwiftUI
import LeeoKit

struct CategorySettings: View {
    @StateObject private var store = CategoryStore.shared
    @State private var newCategoryName: String = ""
    @State private var renaming: String?
    @State private var renameText: String = ""
    @State private var showResetAlert = false
    @Environment(\.appTheme) private var theme

    /// 카테고리별 단축어 개수 - 화면에 들어올 때·바뀔 때만 센다.
    /// (행마다 저장소를 읽으면 카테고리 수만큼 파일을 열게 된다)
    @State private var counts: [String: Int] = [:]

    /// 숨기려다 멈춰 세운 카테고리 - 안에 단축어가 들어 있는 경우.
    @State private var blockedHide: String?
    /// 옮기기 시트를 띄운 카테고리. (`String` 은 Identifiable 이 아니라 감싼다)
    @State private var movingFrom: MoveRequest?

    /// 옮기기 시트에 넘길 출처.
    private struct MoveRequest: Identifiable {
        let id = UUID()
        let source: String
    }
    /// 옮긴 결과 안내("N개를 □□로 옮겼어요").
    @State private var moveResult: String?

    var body: some View {
        Form {
            // Header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: AppSymbol.tagFill)
                            .font(.title2)
                            .foregroundColor(.accentColor)
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("Manage categories", comment: "Category settings header"))
                            .font(.headline)
                    }
                    Text(NSLocalizedString("Add your own categories or remove ones you don't use. Defaults vary by region.",
                                           comment: "Category settings description"))
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            // 기본 탭 - 앱이 항상 제공하는 탭(전체/즐겨찾기)의 표시 여부.
            // (구 카테고리 관리 시트에 있던 즐겨찾기 토글을 이 단일 화면으로 통합)
            Section {
                HStack {
                    Label {
                        Text(NSLocalizedString("전체", comment: "Category: all"))
                    } icon: {
                        Image(systemName: AppSymbol.squareGrid2x2Fill)
                            .foregroundColor(.accentColor)
                    }
                    Spacer()
                    Text(NSLocalizedString("항상 표시", comment: "Category always visible"))
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                Toggle(isOn: favoritesVisibleBinding) {
                    Label {
                        Text(NSLocalizedString("즐겨찾기", comment: "Category: favorites"))
                    } icon: {
                        Image(systemName: AppSymbol.heartFill)
                            .foregroundColor(.clipFavorite)
                    }
                }
                .accessibilityLabel(NSLocalizedString("즐겨찾기 탭 표시", comment: "Favorites tab visibility toggle a11y"))
            } header: {
                Text(NSLocalizedString("기본", comment: "Category section: built-in"))
            }

            // 기본 제공 카테고리 (타입별 모아보기) - 앱이 미리 만들어 둔 카테고리. 켜면 탭으로 노출.
            Section {
                ForEach(BuiltInCategory.allCases, id: \.self) { builtIn in
                    Toggle(isOn: builtInBinding(builtIn)) {
                        Label {
                            Text(builtIn.displayName)
                        } icon: {
                            Image(systemName: builtIn.icon)
                                .foregroundColor(builtIn.tint)
                        }
                    }
                    .accessibilityLabel(String(format: NSLocalizedString("%@ 카테고리 표시", comment: "Built-in category toggle a11y"), builtIn.displayName))
                }
            } header: {
                Text(NSLocalizedString("기본 제공 카테고리", comment: "Built-in categories section header"))
            } footer: {
                Text(NSLocalizedString("앱이 미리 만들어 둔 카테고리예요. 켜면 목록 상단 탭에 나타나 해당 종류의 단축어만 모아 볼 수 있어요.", comment: "Built-in categories section footer"))
                    .font(.body)
            }

            // Add new
            Section {
                HStack {
                    TextField(NSLocalizedString("New category name", comment: "Add category placeholder"),
                              text: $newCategoryName)
                        .textInputAutocapitalization(.words)
                    Button(NSLocalizedString("Add", comment: "Add")) {
                        if store.add(newCategoryName) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            newCategoryName = ""
                        } else {
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        }
                    }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            } header: {
                Text(NSLocalizedString("Add new", comment: "Add new section header"))
            }

            // Existing list
            Section {
                ForEach(store.allCategories, id: \.self) { category in
                    categoryRow(category)
                }
                .onMove { source, destination in
                    store.move(from: source, to: destination)
                }
                .onDelete { indices in
                    for idx in indices {
                        let name = store.allCategories[idx]
                        if !store.remove(name) {
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        }
                    }
                }
            } header: {
                HStack {
                    Text(String(format: NSLocalizedString("%d categories", comment: "Categories count header"),
                                store.allCategories.count))
                    Spacer()
                    EditButton().font(.body)
                }
            } footer: {
                Text(NSLocalizedString("Long-press to drag and reorder. Swipe left to delete (protected ones can't be removed).",
                                       comment: "Categories footer hint"))
                    .font(.body)
            }

            // 카테고리 아이콘 - 예전에는 설정 화면에서 형제 행이었다. 카테고리를 만들다가
            // 아이콘을 고르는 흐름이 자연스러워 여기로 들여왔다.
            Section {
                NavigationLink(destination: CategoryIconSettings()) {
                    Label(NSLocalizedString("카테고리 아이콘", comment: "Category icon settings"),
                          systemImage: AppSymbol.squareGrid2x2Fill)
                }
            }

            // Remove all
            if !store.allCategories.isEmpty {
                Section {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: AppSymbol.trash)
                                .accessibilityHidden(true)
                            Text(NSLocalizedString("Remove all categories", comment: "Remove all categories button"))
                        }
                    }
                    .accessibilityHint(NSLocalizedString("모든 카테고리를 삭제합니다. 단축어는 유지됩니다.", comment: "Remove all categories hint"))
                }
            }
        }
        .navigationTitle(NSLocalizedString("Categories", comment: "Categories nav title"))
        .onAppear {
            store.reload() // 키보드 컨텍스트 메뉴 등 다른 경로의 변경 반영 (통일된 단일 목록)
            recountMemos()
        }
        .onReceive(NotificationCenter.default.publisher(for: .memoDataChanged)) { _ in
            recountMemos()
        }
        // 안에 든 것이 있는 카테고리는 숨기지 못한다 - 이유를 말하고, 할 수 있는 일을 준다.
        .alert(hideBlockedTitle, isPresented: hideBlockedBinding) {
            Button(NSLocalizedString("다른 카테고리로 옮기기", comment: "Move all snippets to another category")) {
                movingFrom = blockedHide.map { MoveRequest(source: $0) }
                blockedHide = nil
            }
            Button(NSLocalizedString("그냥 둘게요", comment: "Keep the category visible"), role: .cancel) {
                blockedHide = nil
            }
        } message: {
            Text(NSLocalizedString("숨기면 이 단축어들이 탭에서 사라져서 찾기 어려워져요. 먼저 다른 카테고리로 옮기면 숨길 수 있어요.",
                                   comment: "Category hide blocked message"))
        }
        .sheet(item: $movingFrom) { request in
            CategoryBulkMoveSheet(
                source: request.source,
                count: counts[request.source] ?? 0,
                destinations: moveDestinations(excluding: request.source)
            ) { destination in
                let moved = moveAllMemos(from: request.source, to: destination)
                movingFrom = nil
                guard moved > 0 else { return }
                // 비었으니 이제 숨길 수 있다 - 원래 하려던 일을 대신 마쳐 준다.
                store.setVisible(request.source, false)
                recountMemos()
                moveResult = String(format: NSLocalizedString("%1$d개를 %2$@(으)로 옮기고 %3$@ 탭을 숨겼어요",
                                                              comment: "Bulk move result"),
                                    moved, destination, request.source)
            } onCancel: {
                movingFrom = nil
            }
        }
        .alert(NSLocalizedString("옮겼어요", comment: "Bulk move done title"),
               isPresented: moveResultBinding) {
            Button(NSLocalizedString("확인", comment: "Confirm")) { moveResult = nil }
        } message: {
            Text(moveResult ?? "")
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .solidNavBar(theme.bg)
        .alert(NSLocalizedString("Remove all categories?", comment: "Remove all categories alert title"),
               isPresented: $showResetAlert) {
            Button(NSLocalizedString("Cancel", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("Remove all", comment: "Remove all"), role: .destructive) {
                store.removeAll()
            }
        } message: {
            Text(NSLocalizedString("All categories will be deleted. Your memos are kept (they just won't have a category tab).",
                                   comment: "Remove all categories alert message"))
        }
    }

    @ViewBuilder
    private func categoryRow(_ category: String) -> some View {
        let isProtected = CategoryStore.protectedCategories.contains(category)
        HStack(spacing: 12) {
            if renaming == category {
                TextField(category, text: $renameText, onCommit: {
                    if store.rename(from: category, to: renameText) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    renaming = nil
                })
                .clipRoundedField()
                .accessibilityLabel(NSLocalizedString("새 카테고리 이름", comment: "Rename category field"))
                Button(NSLocalizedString("Done", comment: "Done")) {
                    if store.rename(from: category, to: renameText) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    renaming = nil
                }
                .font(.body)
            } else {
                // 색 편집 - 커스텀 카테고리만. 시스템 ColorPicker로 직접 지정.
                if !isProtected {
                    ColorPicker(selection: colorBinding(category), supportsOpacity: false) { EmptyView() }
                        .labelsHidden()
                        .frame(width: 28)
                        .accessibilityLabel(String(format: NSLocalizedString("%@ 색상", comment: "Category color picker"), category))
                }
                Text(NSLocalizedString(category, comment: "Category name"))
                    .foregroundColor(isProtected ? .secondary : .primary)
                // 몇 개가 들어 있는지 - 토글을 끄려다 막히기 **전에** 보여야 납득이 된다.
                if let count = counts[category], count > 0 {
                    Text(String(format: NSLocalizedString("%d개", comment: "count unit"), count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isProtected {
                    Image(systemName: AppSymbol.lockFill)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .accessibilityLabel(NSLocalizedString("기본 카테고리 (삭제 불가)", comment: "Protected category lock icon"))
                } else {
                    Button {
                        renaming = category
                        renameText = category
                    } label: {
                        Image(systemName: AppSymbol.pencil)
                            .font(.body)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(NSLocalizedString("이름 변경", comment: "Rename category button"))
                    .accessibilityHint(String(format: NSLocalizedString("%@ 카테고리 이름을 변경합니다", comment: "Rename category hint"), category))
                    // 표시 토글 - 탭에 노출할지(켜짐=표시).
                    Toggle("", isOn: visibleBinding(category))
                        .labelsHidden()
                        .accessibilityLabel(String(format: NSLocalizedString("%@ 탭 표시", comment: "Category visibility toggle"), category))
                }
            }
        }
    }

    // MARK: - Bindings (색/표시)

    private func colorBinding(_ category: String) -> Binding<Color> {
        Binding(
            get: { categoryTint(for: category, in: store.allCategories) },
            set: { newColor in store.setColorHex(newColor.toHex(), for: category) }
        )
    }

    /// 표시 토글.
    ///
    /// ⚠️ **안에 든 것이 있으면 끄지 못한다.** 탭이 사라진 카테고리의 단축어는 목록에서
    ///    갈 길이 없어져, 사용자에게는 "단축어가 없어졌다"로 보인다(실제로 여기서 온
    ///    문의가 그 모양이었다). 그래서 그냥 막지 않고 - 막기만 하면 고장으로 읽힌다 -
    ///    왜 못 끄는지 말하고, 한 번에 옮길 길을 같이 준다.
    private func visibleBinding(_ category: String) -> Binding<Bool> {
        Binding(
            get: { store.isVisible(category) },
            set: { newValue in
                if newValue == false, (counts[category] ?? 0) > 0 {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    blockedHide = category
                    return
                }
                store.setVisible(category, newValue)
            }
        )
    }

    // MARK: - 개수 세기 / 한 번에 옮기기

    /// 카테고리별 단축어 개수를 다시 센다.
    private func recountMemos() {
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        counts = Dictionary(grouping: memos, by: \.category).mapValues(\.count)
    }

    /// 옮겨 갈 수 있는 곳.
    ///
    /// ⚠️ **숨긴 카테고리는 뺀다.** 안 보이는 탭으로 옮기는 것은 아무도 원해서 하는 일이 아니다
    ///    (기본 탭이 받아 주므로 사라지지는 않지만, 옮긴 사람은 그 탭을 찾다가 없어서 당황한다).
    ///    보호 카테고리(기본/텍스트/이미지)는 늘 받을 수 있다.
    private func moveDestinations(excluding source: String) -> [String] {
        let all = CategoryStore.protectedCategories.sorted() + store.allCategories
        return all.filter { $0 != source && store.isVisible($0) }
    }

    /// 한 카테고리의 단축어를 통째로 다른 카테고리로 옮긴다.
    /// - Returns: 실제로 옮긴 개수(실패하면 0).
    private func moveAllMemos(from source: String, to destination: String) -> Int {
        var memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        var moved = 0
        for index in memos.indices where memos[index].category == source {
            memos[index].category = destination
            memos[index].lastEdited = Date()
            moved += 1
        }
        guard moved > 0 else { return 0 }
        do {
            try MemoStore.shared.save(memos: memos, type: .memo)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            print("✅ [CategorySettings.moveAllMemos] \(source) → \(destination) \(moved)개 이동")
            return moved
        } catch {
            print("❌ [CategorySettings.moveAllMemos] 저장 실패: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return 0
        }
    }

    // MARK: - 알림 바인딩

    private var hideBlockedTitle: String {
        guard let blockedHide else { return "" }
        return String(format: NSLocalizedString("%1$@에 단축어 %2$d개가 있어요",
                                                comment: "Category hide blocked title: name and count"),
                      blockedHide, counts[blockedHide] ?? 0)
    }

    private var hideBlockedBinding: Binding<Bool> {
        Binding(get: { blockedHide != nil }, set: { if !$0 { blockedHide = nil } })
    }

    private var moveResultBinding: Binding<Bool> {
        Binding(get: { moveResult != nil }, set: { if !$0 { moveResult = nil } })
    }

    /// 즐겨찾기 탭 표시 여부 - 커스텀 카테고리와 동일한 hidden 집합("__favorites__" 키)을 쓴다.
    private var favoritesVisibleBinding: Binding<Bool> {
        Binding(
            get: { store.isVisible("__favorites__") },
            set: { store.setVisible("__favorites__", $0) }
        )
    }

    private func builtInBinding(_ builtIn: BuiltInCategory) -> Binding<Bool> {
        Binding(
            get: { store.isBuiltInEnabled(builtIn.rawValue) },
            set: { store.setBuiltInEnabled(builtIn.rawValue, $0) }
        )
    }
}

// MARK: - 한 번에 옮기기 시트

/// "이 카테고리에 있는 것을 한 번에 다른 카테고리로 옮길래요?"에 답하는 화면.
///
/// ⚠️ 고를 것이 **하나뿐**이다(어디로 보낼지). 여기서 개별 선택까지 하게 만들면
///    한 번에 옮기려던 이유가 사라진다. 골라서 옮기는 일은 목록 화면이 한다.
private struct CategoryBulkMoveSheet: View {
    let source: String
    let count: Int
    let destinations: [String]
    let onMove: (String) -> Void
    let onCancel: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var selected: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(String(format: NSLocalizedString("%1$@에 있는 단축어 %2$d개를 옮길 곳을 고르세요",
                                                          comment: "Bulk move sheet description"),
                                source, count))
                        .font(.body)
                        .foregroundColor(theme.text)
                }

                Section {
                    ForEach(destinations, id: \.self) { destination in
                        Button {
                            selected = destination
                        } label: {
                            HStack {
                                Text(NSLocalizedString(destination, comment: "Category name"))
                                    .foregroundColor(.primary)
                                Spacer()
                                if selected == destination {
                                    Image(systemName: AppSymbol.checkmark)
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text(NSLocalizedString("옮길 곳", comment: "Bulk move destination section header"))
                } footer: {
                    Text(NSLocalizedString("옮기고 나면 이 카테고리 탭은 숨겨져요. 단축어는 그대로 있어요.",
                                           comment: "Bulk move sheet footer"))
                        .font(.body)
                }
            }
            .navigationTitle(NSLocalizedString("한 번에 옮기기", comment: "Bulk move sheet title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("취소", comment: "Cancel")) { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("옮기기", comment: "Move")) {
                        if let selected { onMove(selected) }
                    }
                    .fontWeight(.semibold)
                    .disabled(selected == nil)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategorySettings()
    }
}
