//
//  CategoryCleanupNotice.swift
//  ClipKeyboard
//
//  "카테고리가 많아졌어요" 안내와, 거기서 곧장 정리로 넘어가는 문.
//
//  왜 생겼나: 한동안 동기화가 `memo.category` 문자열을 사용자 카테고리로 승격시켰다.
//  올릴 때는 교체, 받을 때는 더하기만 하는 비대칭이라 한 번 들어간 이름이 빠지지 않았고,
//  기기를 오갈수록 목록이 불어났다. 그 코드는 걷어냈지만(`CategorySnapshotStore.syncable`)
//  **이미 쌓인 목록은 저절로 줄지 않는다.**
//
//  ⚠️ 앱이 임의로 지우지 않는다. 어느 것이 사용자가 만든 것이고 어느 것이 불어난 것인지
//     앱은 구분할 수 없다. 할 수 있는 일은 **눈에 보이게 해 주고 정리할 자리로 데려다주는
//     것**까지다. 지우는 것은 사용자가 한다.
//

import SwiftUI

// MARK: - 언제 물어볼까

enum CategoryCleanupNudge {

    /// 이 정도는 되어야 "많다"고 말할 만하다. 열두어 개까지는 열심히 쓰는 사람의 모습이다.
    private static let manyCategories = 12
    /// 비어 있는 칸이 이만큼은 있어야 "정리할 것이 있다"고 말할 수 있다.
    /// 빈 칸이 한둘이면 그건 곧 쓸 자리를 미리 만들어 둔 것일 수 있다.
    private static let manyEmpty = 5

    /// 카테고리별 단축어 수. 빈 칸을 세는 데만 쓴다.
    static func emptyCategories(_ categories: [String], memos: [Memo]) -> [String] {
        let counts = Dictionary(grouping: memos, by: \.category).mapValues(\.count)
        return categories.filter { (counts[$0] ?? 0) == 0 }
    }

    /// 지금 물어볼 자리인가.
    ///
    /// 한 번 "괜찮다"고 한 사람에게 같은 말을 되풀이하지 않는다. 다만 그 뒤로 **또 크게
    /// 늘었다면** 한 번 더 말한다(그때는 사정이 달라진 것이다).
    static func shouldAsk(categoryCount: Int, emptyCount: Int) -> Bool {
        guard categoryCount >= manyCategories, emptyCount >= manyEmpty else { return false }
        let asked = UserDefaults.standard.integer(forKey: DefaultsKey.categoryCleanupAskedAtCount)
        guard asked > 0 else { return true }
        return categoryCount >= asked + 10
    }

    /// 물어봤다고 적어 둔다. 다음 기준선이 된다.
    static func markAsked(categoryCount: Int) {
        UserDefaults.standard.set(categoryCount, forKey: DefaultsKey.categoryCleanupAskedAtCount)
    }
}

// MARK: - 안내 화면

struct CategoryCleanupNotice: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    /// 지금 있는 사용자 카테고리 전부.
    let categories: [String]
    /// 그중 단축어가 하나도 없는 것.
    let empty: [String]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    emptyList
                    reassurance
                    actions
                }
                .padding(20)
            }
            .navigationTitle(NSLocalizedString("카테고리 정리", comment: "Category cleanup title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: AppSymbol.tagFill)
                .font(.largeTitle)
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)

            Text(NSLocalizedString("카테고리가 많아졌어요", comment: "Category cleanup headline"))
                .font(.title2.weight(.semibold))

            Text(String(format: NSLocalizedString("카테고리 %1$d개 가운데 %2$d개에는 단축어가 하나도 없어요. 안 쓰는 것을 정리하면 목록을 옆으로 넘길 때 훨씬 가벼워집니다.",
                                                  comment: "Category cleanup body"),
                        categories.count, empty.count))
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 무엇이 비어 있는지 실제로 보여 준다. 숫자만 들이밀면 "정말 그런가" 를 확인할 길이 없다.
    @ViewBuilder
    private var emptyList: some View {
        if !empty.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("비어 있는 카테고리", comment: "Empty categories section"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 6)],
                          alignment: .leading, spacing: 6) {
                    ForEach(empty.prefix(12), id: \.self) { name in
                        Text(name)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity)
                            .background(theme.surface, in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if empty.count > 12 {
                    Text(String(format: NSLocalizedString("그 밖에 %d개", comment: "More empty categories"),
                                empty.count - 12))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    /// 정리해도 잃는 것이 없다는 말. 이 한 줄이 없으면 아무도 첫 버튼을 못 누른다.
    private var reassurance: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: AppSymbol.infoCircle)
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            Text(NSLocalizedString("정리해도 단축어는 지워지지 않아요. 카테고리를 지우면 그 안에 있던 단축어는 기본 탭으로 옮겨 갑니다.",
                                   comment: "Category cleanup reassurance"))
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            NavigationLink {
                CategorySettings()
            } label: {
                Text(NSLocalizedString("카테고리 정리하기", comment: "Category cleanup primary action"))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: theme.radiusSm))
                    .foregroundColor(.white)
            }

            Button {
                dismiss()
            } label: {
                Text(NSLocalizedString("지금은 괜찮아요", comment: "Category cleanup dismiss"))
                    .font(.body)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
    }
}
