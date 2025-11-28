//
//  MemoListView.swift
//  TokenMemo.mac
//
//  Created by Claude on 2025-11-28.
//

import SwiftUI
import AppKit

struct MemoListView: View {
    @State private var memos: [Memo] = []
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "전체"

    var categories: [String] {
        var cats = Set(memos.map { $0.category })
        cats.insert("전체")
        return Array(cats).sorted()
    }

    var filteredMemos: [Memo] {
        var filtered = memos

        // 카테고리 필터
        if selectedCategory != "전체" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }

        // 검색 필터
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.value.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered.sorted { $0.lastEdited > $1.lastEdited }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 컴팩트 헤더
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.blue)

                        Text("메모")
                            .font(.headline)
                            .bold()

                        Spacer()

                        Text("\(filteredMemos.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // 카테고리 선택
                        Picker("", selection: $selectedCategory) {
                            ForEach(categories, id: \.self) { category in
                                Text(category).tag(category)
                            }
                        }
                        .frame(width: 80)
                        .controlSize(.small)
                    }

                    // 컴팩트 검색 바
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("검색", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.caption)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
                }
                .padding(8)

                Divider()

                // 리스트
                if filteredMemos.isEmpty {
                    CompactEmptyListView
                } else {
                    List {
                        ForEach(filteredMemos) { memo in
                            CompactMemoItemRow(memo: memo) {
                                copyToClipboard(memo.value)
                                showToast(message: memo.title)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }

            // 토스트 메시지
            VStack {
                Spacer()
                if showToast {
                    Text(toastMessage)
                        .font(.caption)
                        .padding(6)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: showToast)
        }
        .frame(width: 350, height: 450)
        .onAppear {
            loadMemos()
        }
    }

    // MARK: - Empty View

    private var CompactEmptyListView: some View {
        VStack(spacing: 8) {
            Image(systemName: searchText.isEmpty ? "doc.text.magnifyingglass" : "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text(searchText.isEmpty ? "메모 없음" : "검색 결과 없음")
                .font(.caption)
                .bold()
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadMemos() {
        do {
            memos = try MemoStore.shared.load(type: .tokenMemo)
            print("📝 [MemoList] \(memos.count)개 메모 로드됨")
        } catch {
            print("❌ [MemoList] 메모 로드 실패: \(error)")
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func showToast(message: String) {
        let preview = message.prefix(30)
        toastMessage = "[\(preview)\(message.count > 30 ? "..." : "")] 클립보드에 복사되었습니다"
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }
}

// MARK: - Compact Memo Item Row

struct CompactMemoItemRow: View {
    let memo: Memo
    let onCopy: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            // 아이콘
            Image(systemName: memo.isFavorite ? "star.fill" :
                  memo.isSecure ? "lock.fill" : "doc.text")
                .foregroundStyle(memo.isFavorite ? .yellow : .blue)
                .font(.caption)
                .frame(width: 16)

            // 콘텐츠
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(memo.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Spacer()

                    if isHovering {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }

                Text(memo.value)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(isHovering ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onCopy()
        }
    }
}

#Preview {
    MemoListView()
}
