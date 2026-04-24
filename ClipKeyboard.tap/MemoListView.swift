//
//  MemoListView.swift
//  ClipKeyboard.tap
//
//  Created by Claude on 2025-11-28.
//

import SwiftUI
import AppKit

struct MemoListView: View {
    @State private var memos: [Memo] = []
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "전체"
    @State private var isViewActive: Bool = true

    var categories: [String] {
        var cats = Set(memos.map { $0.category })
        cats.insert("전체")
        return Array(cats).sorted()
    }

    private var isFreeUser: Bool { !MacProManager.isPro }
    private var hiddenMemoCount: Int {
        guard isFreeUser else { return 0 }
        return max(0, memos.count - MacProManager.freeMemoLimit)
    }

    var filteredMemos: [Memo] {
        var filtered = memos

        // 무료 유저: 표시 한도 적용 (정렬 후 상위 N개만)
        if isFreeUser {
            filtered = Array(filtered.sorted { $0.lastEdited > $1.lastEdited }.prefix(MacProManager.freeMemoLimit))
        }

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

        if isFreeUser { return filtered }
        return filtered.sorted { $0.lastEdited > $1.lastEdited }
    }

    var body: some View {
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

                // 무료 유저: 숨겨진 메모 배너
                if isFreeUser && hiddenMemoCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                        Text(String(format: NSLocalizedString("%d개 메모 잠김 — iOS에서 Pro 구매 시 동기화됩니다", comment: "Locked memos banner"), hiddenMemoCount))
                            .font(.system(size: 11))
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.85))
                }

                // 리스트
                if filteredMemos.isEmpty {
                    CompactEmptyListView
                } else {
                    List {
                        ForEach(filteredMemos) { memo in
                            CompactMemoItemRow(memo: memo) {
                                if memo.contentType == .image {
                                    copyImageToClipboard(memo)
                                } else {
                                    copyToClipboard(memo.value)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
        }
        .frame(minWidth: 360, minHeight: 420)
        .onAppear {
            print("✅ [MemoListView] onAppear - 뷰 활성화")
            isViewActive = true
            loadMemos()
        }
        .onDisappear {
            print("⚠️ [MemoListView] onDisappear - 뷰 비활성화 시작")
            isViewActive = false
            print("✅ [MemoListView] onDisappear - 뷰 비활성화 완료")
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
        print("📂 [MemoListView] loadMemos - 메모 로드 시작")
        do {
            memos = try MemoStore.shared.load(type: .memo)
            print("✅ [MemoListView] loadMemos - \(memos.count)개 메모 로드 완료")
        } catch {
            print("❌ [MemoListView] loadMemos - 메모 로드 실패: \(error)")
        }
    }

    private func copyToClipboard(_ text: String) {
        print("📋 [MemoListView] copyToClipboard - 클립보드 복사 시작")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        print("✅ [MemoListView] copyToClipboard - 클립보드 복사 완료")
    }

    private func copyImageToClipboard(_ memo: Memo) {
        guard let imageFileName = memo.imageFileName,
              let image = MemoStore.shared.loadImage(fileName: imageFileName) else {
            print("❌ [MemoListView] 이미지 로드 실패")
            return
        }

        print("📸 [MemoListView] copyImageToClipboard - 이미지 클립보드 복사 시작")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        print("✅ [MemoListView] copyImageToClipboard - 이미지 클립보드 복사 완료")
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
            Image(systemName: memo.contentType == .image ? "photo" :
                  memo.isFavorite ? "star.fill" :
                  memo.isSecure ? "lock.fill" : "doc.text")
                .foregroundStyle(memo.contentType == .image ? .purple :
                                memo.isFavorite ? .yellow : .blue)
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
                        Image(systemName: memo.contentType == .image ? "photo" : "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }

                if memo.contentType == .image || memo.contentType == .mixed {
                    // 이미지 미리보기
                    let imageFileNames = memo.imageFileNames.isEmpty && memo.imageFileName != nil
                        ? [memo.imageFileName!]
                        : memo.imageFileNames

                    if !imageFileNames.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(imageFileNames.prefix(3).enumerated()), id: \.offset) { index, fileName in
                                if let image = MemoStore.shared.loadImage(fileName: fileName) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 30, height: 30)
                                        .clipped()
                                        .cornerRadius(4)
                                }
                            }

                            if imageFileNames.count > 3 {
                                Text("+\(imageFileNames.count - 3)")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if memo.contentType == .mixed && !memo.value.isEmpty {
                        Text(memo.value)
                            .font(.system(size: 10))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(memo.value)
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
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
