//
//  UsageStatistics.swift
//  Token memo
//
//  Created by Claude Code
//

import SwiftUI

struct UsageStatistics: View {
    @State private var memos: [Memo] = []
    @State private var sortBy: SortOption = .usage

    enum SortOption: String, CaseIterable {
        case usage = "사용 빈도"
        case recent = "최근 사용"
        case category = "테마"

        var localizedName: String {
            return NSLocalizedString(self.rawValue, comment: "Sort option")
        }
    }

    var sortedMemos: [Memo] {
        switch sortBy {
        case .usage:
            return memos.sorted { $0.clipCount > $1.clipCount }
        case .recent:
            return memos.sorted { $0.lastEdited > $1.lastEdited }
        case .category:
            return memos.sorted { $0.category < $1.category }
        }
    }

    var totalUsage: Int {
        memos.reduce(0) { $0 + $1.clipCount }
    }

    var categoryCounts: [String: Int] {
        Dictionary(grouping: memos, by: { $0.category })
            .mapValues { $0.count }
    }

    var body: some View {
        List {
            Section(header: Text("전체 통계")) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("전체 메모")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(memos.count)개")
                            .font(.title2)
                            .bold()
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("총 사용 횟수")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(totalUsage)회")
                            .font(.title2)
                            .bold()
                    }
                }
                .padding(.vertical, 8)
            }

            Section(header: Text("테마별 통계")) {
                ForEach(categoryCounts.sorted(by: { $0.value > $1.value }), id: \.key) { category, count in
                    HStack {
                        Text(category)
                        Spacer()
                        Text("\(count)개")
                            .foregroundColor(.gray)
                    }
                }
            }

            Section(header: HStack {
                Text("메모별 통계")
                Spacer()
                Picker("정렬", selection: $sortBy) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.localizedName).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }) {
                ForEach(sortedMemos) { memo in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(memo.title)
                                .font(.headline)

                            Spacer()

                            if memo.clipCount > 0 {
                                Label("\(memo.clipCount)", systemImage: "chart.bar.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }

                        HStack(spacing: 12) {
                            Text(categoryLocalizedName(memo.category))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)

                            Text(formatDate(memo.lastEdited))
                                .font(.caption)
                                .foregroundColor(.gray)

                            if memo.isSecure {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }

                            if memo.isTemplate {
                                Image(systemName: "doc.text.fill")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("사용 통계")
        .onAppear {
            loadMemos()
        }
    }

    private func loadMemos() {
        do {
            memos = try MemoStore.shared.load(type: .tokenMemo)
        } catch {
            print("Error loading memos: \(error)")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

    /// 카테고리명을 다국어 지원 이름으로 변환
    private func categoryLocalizedName(_ category: String) -> String {
        // 카테고리가 ClipboardItemType의 rawValue와 일치하는지 확인
        if let type = ClipboardItemType.allCases.first(where: { $0.rawValue == category }) {
            return type.localizedName
        }
        // 일치하지 않으면 카테고리명을 그대로 번역 시도
        return NSLocalizedString(category, comment: "Category name")
    }
}

struct UsageStatistics_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            UsageStatistics()
        }
    }
}
