//
//  ClipboardHistoryView.swift
//  TokenMemo.tap
//
//  Created by Claude on 2025-11-28.
//

import SwiftUI
import AppKit

struct ClipboardHistoryView: View {
    @State private var clipboardHistory: [ClipboardHistory] = []
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var searchText: String = ""

    var filteredHistory: [ClipboardHistory] {
        if searchText.isEmpty {
            return clipboardHistory
        }
        return clipboardHistory.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 헤더
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("클립보드 히스토리")
                                .font(.title)
                                .bold()

                            Text("\(clipboardHistory.count)개의 항목")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            clearAll()
                        } label: {
                            Label("전체 삭제", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .disabled(clipboardHistory.isEmpty)
                    }

                    // 검색 바
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("검색...", text: $searchText)
                            .textFieldStyle(.plain)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()

                Divider()

                // 리스트
                if filteredHistory.isEmpty {
                    EmptyListView
                } else {
                    List {
                        ForEach(filteredHistory) { item in
                            ClipboardItemRow(item: item) {
                                // 클립보드에 복사
                                if item.contentType == .image {
                                    copyImageToClipboard(item)
                                    showToast(message: "이미지")
                                } else {
                                    copyToClipboard(item.content)
                                    showToast(message: item.content)
                                }
                            } onSave: {
                                // 메모로 저장
                                saveToMemo(item)
                            } onDelete: {
                                // 삭제
                                deleteItem(item)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }

            // Toast 메시지
            VStack {
                Spacer()
                if showToast {
                    Text(toastMessage)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onTapGesture {
                            showToast = false
                        }
                }
            }
            .animation(.easeInOut, value: showToast)
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            loadHistory()
        }
    }

    // MARK: - Empty View

    private var EmptyListView: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(searchText.isEmpty ? "클립보드 히스토리 없음" : "검색 결과 없음")
                .font(.title2)
                .bold()

            Text(searchText.isEmpty ?
                 "복사한 내용이 자동으로 여기에 저장됩니다\n(최대 100개, 7일간 유지)" :
                 "'\(searchText)'와 일치하는 항목이 없습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadHistory() {
        do {
            clipboardHistory = try MemoStore.shared.loadClipboardHistory()
            print("📋 [ClipboardHistory] \(clipboardHistory.count)개 항목 로드됨")
        } catch {
            print("❌ [ClipboardHistory] 로드 실패: \(error)")
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func copyImageToClipboard(_ item: ClipboardHistory) {
        guard let imageFileName = item.imageFileName,
              let image = MemoStore.shared.loadImage(fileName: imageFileName) else {
            print("❌ [ClipboardHistory] 이미지 로드 실패")
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    private func showToast(message: String) {
        let preview = message.prefix(30)
        toastMessage = "[\(preview)\(message.count > 30 ? "..." : "")] 클립보드에 복사되었습니다"
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }

    private func deleteItem(_ item: ClipboardHistory) {
        clipboardHistory.removeAll { $0.id == item.id }
        do {
            try MemoStore.shared.saveClipboardHistory(history: clipboardHistory)
            print("🗑️ [ClipboardHistory] 항목 삭제됨")
        } catch {
            print("❌ [ClipboardHistory] 삭제 실패: \(error)")
        }
    }

    private func clearAll() {
        clipboardHistory.removeAll()
        do {
            try MemoStore.shared.saveClipboardHistory(history: [])
            print("🗑️ [ClipboardHistory] 전체 삭제됨")
        } catch {
            print("❌ [ClipboardHistory] 전체 삭제 실패: \(error)")
        }
    }

    private func saveToMemo(_ item: ClipboardHistory) {
        do {
            var memos = try MemoStore.shared.load(type: .tokenMemo)
            let newMemo = Memo(
                title: item.contentType == .image ? "이미지" : String(item.content.prefix(30)),
                value: item.content,
                lastEdited: Date(),
                imageFileName: item.imageFileName,
                contentType: item.contentType
            )
            memos.append(newMemo)
            try MemoStore.shared.save(memos: memos, type: .tokenMemo)

            toastMessage = "메모로 저장되었습니다"
            showToast = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showToast = false
            }

            print("💾 [ClipboardHistory] 메모로 저장됨")
        } catch {
            print("❌ [ClipboardHistory] 메모 저장 실패: \(error)")
        }
    }
}

// MARK: - Clipboard Item Row

struct ClipboardItemRow: View {
    let item: ClipboardHistory
    let onCopy: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // 콘텐츠
            VStack(alignment: .leading, spacing: 6) {
                if item.contentType == .image {
                    // 이미지 표시
                    if let imageFileName = item.imageFileName,
                       let image = MemoStore.shared.loadImage(fileName: imageFileName) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 150)
                            .cornerRadius(8)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                            Text("이미지를 불러올 수 없습니다")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    // 텍스트 표시
                    Text(item.content)
                        .font(.system(size: 14))
                        .lineLimit(3)
                        .foregroundStyle(.primary)
                }

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(formatDate(item.copiedAt))
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)

                    if item.isTemporary {
                        Text("임시")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }

                    if item.contentType == .image {
                        Text("이미지")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            // 액션 버튼들 (hover 시에만 표시)
            if isHovering {
                HStack(spacing: 8) {
                    Button {
                        onSave()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .help("메모로 저장")

                    Button {
                        onCopy()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("클립보드에 복사")

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("삭제")
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isHovering ? Color.gray.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onCopy()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    ClipboardHistoryView()
}
