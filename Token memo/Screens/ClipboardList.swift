//
//  ClipboardList.swift
//  Token memo
//
//  Created by hyunho lee on 2023/06/03.
//

import SwiftUI

struct ClipboardList: View {

    @State private var clipboardHistory: [ClipboardHistory] = []
    @State private var loadedData: [ClipboardHistory] = []

    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var showActive: Bool = false
    
    var body: some View {
        ZStack {
            List {
                if clipboardHistory.isEmpty {
                    EmptyListView
                } else {
                    ForEach(clipboardHistory) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                UIPasteboard.general.string = item.content
                                showToast(message: item.content)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.content)
                                        .font(.system(size: 14))
                                        .lineLimit(2)
                                        .foregroundColor(.primary)

                                    HStack {
                                        Text(formatDate(item.copiedAt))
                                            .font(.caption)
                                            .foregroundColor(.gray)

                                        Spacer()

                                        if item.isTemporary {
                                            Text("임시")
                                                .font(.caption)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.2))
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading) {
                                Button {
                                    saveToMemo(item)
                                } label: {
                                    Label("저장", systemImage: "square.and.arrow.down")
                                }
                                .tint(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("클립보드 히스토리")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        clearAll()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .onAppear {
                loadHistory()
            }
            
            VStack {
                Spacer()
                if showToast {
                    Group {
                        Text(toastMessage)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(.gray)
                            .cornerRadius(8)
                            .padding()
                            .foregroundColor(.white)
                    }
                    .onTapGesture {
                        showToast = false
                    }
                }
            }
            .animation(.easeInOut(duration: 0.5), value: showToast)
            .transition(.opacity)
        }
    }
    
    /// Empty list view
    private var EmptyListView: some View {
        VStack(spacing: 5) {
            Image(systemName: "eyes").font(.system(size: 45)).padding(10)
            Text("클립보드 히스토리 없음")
                .font(.system(size: 22)).bold()
            Text("복사한 내용이 자동으로 여기에 저장됩니다 (최대 100개, 7일간 유지)").opacity(0.7)
        }.multilineTextAlignment(.center).padding(30)
    }

    private func showToast(message: String) {
        toastMessage = "[\(message)] 이 복사되었습니다."
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showToast = false
        }
    }

    private func loadHistory() {
        do {
            clipboardHistory = try MemoStore.shared.loadClipboardHistory()
            loadedData = clipboardHistory
        } catch {
            print("Error loading clipboard history: \(error)")
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        clipboardHistory.remove(atOffsets: offsets)
        do {
            try MemoStore.shared.saveClipboardHistory(history: clipboardHistory)
        } catch {
            print("Error deleting clipboard history: \(error)")
        }
    }

    private func clearAll() {
        clipboardHistory.removeAll()
        do {
            try MemoStore.shared.saveClipboardHistory(history: [])
        } catch {
            print("Error clearing clipboard history: \(error)")
        }
    }

    private func saveToMemo(_ item: ClipboardHistory) {
        do {
            var memos = try MemoStore.shared.load(type: .tokenMemo)
            let newMemo = Memo(
                title: String(item.content.prefix(30)),
                value: item.content,
                lastEdited: Date()
            )
            memos.append(newMemo)
            try MemoStore.shared.save(memos: memos, type: .tokenMemo)
            showToast(message: "메모로 저장되었습니다")
        } catch {
            print("Error saving to memo: \(error)")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

struct ClipboardList_Previews: PreviewProvider {
    static var previews: some View {
        ClipboardList()
    }
}
