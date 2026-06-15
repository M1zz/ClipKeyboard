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
    /// 커스텀 플레이스홀더 값 채우기 시트 대상 메모.
    @State private var fillMemo: Memo?

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

        // 검색 필터 — 보안 메모는 제목으로만(값은 암호문이라 검색 제외).
        if !searchText.isEmpty {
            filtered = filtered.filter {
                if $0.title.localizedCaseInsensitiveContains(searchText) { return true }
                if $0.isSecure { return false }
                return $0.value.localizedCaseInsensitiveContains(searchText)
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
                        Image(systemName: AppSymbol.docOnClipboardFill)
                            .font(.system(.body))
                            .foregroundStyle(.blue)

                        Text(NSLocalizedString("메모", comment: "Memos section header"))
                            .font(.headline)
                            .bold()

                        Spacer()

                        Text("\(filteredMemos.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // 카테고리 선택
                        Picker("", selection: $selectedCategory) {
                            ForEach(categories, id: \.self) { category in
                                Text(category == "전체" ? NSLocalizedString("전체", comment: "All categories") : (ClipboardItemType(rawValue: category)?.localizedName ?? category)).tag(category)
                            }
                        }
                        .frame(width: 80)
                        .controlSize(.small)
                    }

                    // 컴팩트 검색 바
                    HStack(spacing: 4) {
                        Image(systemName: AppSymbol.magnifyingglass)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField(NSLocalizedString("검색", comment: "Search placeholder"), text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.caption)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: AppSymbol.xmarkCircleFill)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(MacRadius.xs)
                }
                .padding(8)

                Divider()

                // 무료 유저: 숨겨진 메모 배너
                if isFreeUser && hiddenMemoCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: AppSymbol.lockFill)
                            .font(.system(.caption))
                        Text(String(format: NSLocalizedString("%d개 메모 잠김 — iOS에서 Pro 구매 시 동기화됩니다", comment: "Locked memos banner"), hiddenMemoCount))
                            .font(.system(.caption))
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
                                } else if memo.isSecure {
                                    // 보안 메모: Touch ID 인증 + 복호화 후 복사
                                    MacSecureAccess.resolveForPaste(memo) { resolved in
                                        if let resolved { copyToClipboard(resolved) }
                                    }
                                } else if memo.hasCustomPlaceholders {
                                    fillMemo = memo
                                } else {
                                    copyToClipboard(memo.resolvedForPaste())
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
        }
        .frame(minWidth: 360, minHeight: 420)
        .sheet(item: $fillMemo) { memo in
            MacTemplateFillSheet(memo: memo) { resolved, paste in
                copyToClipboard(resolved)
                if paste {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        DirectPasteHelper.pasteToFrontmostApp()
                    }
                }
            }
        }
        .onAppear {
            print("✅ [MemoListView] onAppear - 뷰 활성화")
            isViewActive = true
            loadMemos()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataRestored)) { _ in
            // iCloud 자동/수동 복원 직후 목록 갱신.
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

            Text(searchText.isEmpty ? NSLocalizedString("메모 없음", comment: "No memos") : NSLocalizedString("검색 결과 없음", comment: "No search results"))
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
                            ForEach(Array(imageFileNames.prefix(3).enumerated()), id: \.offset) { _, fileName in
                                if let image = MemoStore.shared.loadImage(fileName: fileName) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 30, height: 30)
                                        .clipped()
                                        .cornerRadius(MacRadius.xs)
                                }
                            }

                            if imageFileNames.count > 3 {
                                Text("+\(imageFileNames.count - 3)")
                                    .font(.system(.caption2))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if memo.contentType == .mixed && !memo.value.isEmpty {
                        Text(memo.isSecure ? AttributedString(MacSecureAccess.maskedPreview(memo)) : memo.value.templateChipAttributed())
                            .font(.system(.caption))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(memo.isSecure ? AttributedString(MacSecureAccess.maskedPreview(memo)) : memo.value.templateChipAttributed())
                        .font(.system(.caption))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(isHovering ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(MacRadius.xs)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onCopy()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(memo.macAccessibilityLabel)
        .accessibilityHint(NSLocalizedString("탭하면 복사", comment: "Tap to copy hint"))
    }
}

#Preview {
    MemoListView()
}
