//
//  BulkImportView.swift
//  ClipKeyboard
//
//  타 메모장에서 와장창 옮길 때 — 텍스트 통째로 붙여넣고 자동 분할로 일괄 저장.
//
//  분할 규칙 (우선순위 내림차순):
//  1) `---` / `===` 구분선 (Markdown style)
//  2) 빈 줄 두 개 이상 (\n\n+)
//  3) 줄바꿈 한 줄 (한 줄당 한 메모)
//
//  각 항목 자동 타이틀:
//  - ClipboardClassificationService로 타입 감지 (IBAN, Email, URL 등)
//  - 감지 실패 시 본문 첫 줄(40자 cap)
//

import SwiftUI

struct BulkImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    enum SplitMode: String, CaseIterable {
        case auto, separator, blankLine, oneLinePerMemo

        var label: String {
            switch self {
            case .auto: return NSLocalizedString("Auto", comment: "Bulk import: auto split mode")
            case .separator: return NSLocalizedString("--- separator", comment: "Bulk import: marker split mode")
            case .blankLine: return NSLocalizedString("Blank line", comment: "Bulk import: blank line split")
            case .oneLinePerMemo: return NSLocalizedString("One per line", comment: "Bulk import: line split")
            }
        }
    }

    struct Draft: Identifiable {
        let id = UUID()
        var title: String
        var value: String
        var include: Bool = true
    }

    @State private var pasteText: String = ""
    @State private var splitMode: SplitMode = .auto
    @State private var drafts: [Draft] = []
    @State private var savedCount: Int? = nil

    var body: some View {
        NavigationStack {
            Form {
                if savedCount == nil {
                    pasteSection
                    if !drafts.isEmpty {
                        previewSection
                    }
                } else {
                    successSection
                }
            }
            .navigationTitle(NSLocalizedString("Bulk import", comment: "Bulk import screen title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if savedCount == nil {
                        Button(saveButtonLabel) {
                            saveAll()
                        }
                        .disabled(selectedCount == 0)
                        .fontWeight(.semibold)
                    } else {
                        Button(NSLocalizedString("Done", comment: "Done")) { dismiss() }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var pasteSection: some View {
        Section {
            TextEditor(text: $pasteText)
                .frame(minHeight: 140)
                .font(.system(size: 14))
                .onChange(of: pasteText) { _ in regenerate() }
            HStack(spacing: 8) {
                Button {
                    if let s = UIPasteboard.general.string {
                        pasteText = s
                    }
                } label: {
                    Label(NSLocalizedString("Paste from clipboard", comment: "Bulk import: paste"),
                          systemImage: "doc.on.clipboard")
                }
                Spacer()
                Picker("", selection: $splitMode) {
                    ForEach(SplitMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: splitMode) { _ in regenerate() }
            }
        } header: {
            Text(NSLocalizedString("Paste your notes", comment: "Bulk import: paste header"))
        } footer: {
            Text(NSLocalizedString("App will split the text and let you review each memo before saving.",
                                   comment: "Bulk import: paste footer"))
        }
    }

    private var previewSection: some View {
        Section {
            ForEach($drafts) { $draft in
                draftRow(draft: $draft)
            }
        } header: {
            HStack {
                Text(String(format: NSLocalizedString("%d memos detected", comment: "Bulk import preview header"), drafts.count))
                Spacer()
                if drafts.contains(where: { !$0.include }) {
                    Button(NSLocalizedString("Select all", comment: "Bulk import: select all")) {
                        for i in drafts.indices { drafts[i].include = true }
                    }
                    .font(.caption)
                } else {
                    Button(NSLocalizedString("Deselect all", comment: "Bulk import: deselect all")) {
                        for i in drafts.indices { drafts[i].include = false }
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func draftRow(draft: Binding<Draft>) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                draft.wrappedValue.include.toggle()
            } label: {
                Image(systemName: draft.wrappedValue.include ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(draft.wrappedValue.include ? .accentColor : .secondary)
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                TextField(NSLocalizedString("Title", comment: "Title field"), text: draft.title)
                    .font(.system(size: 14, weight: .semibold))
                Text(draft.wrappedValue.value)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .opacity(draft.wrappedValue.include ? 1.0 : 0.4)
        }
        .padding(.vertical, 4)
    }

    private var successSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.green)
                Text(String(format: NSLocalizedString("Imported %d memos", comment: "Bulk import success"), savedCount ?? 0))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    // MARK: - Logic

    private var selectedCount: Int { drafts.filter(\.include).count }

    private var saveButtonLabel: String {
        if selectedCount == 0 { return NSLocalizedString("Save", comment: "Save") }
        return String(format: NSLocalizedString("Save %d", comment: "Save with count"), selectedCount)
    }

    private func regenerate() {
        let trimmed = pasteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { drafts = []; return }
        let chunks = split(trimmed, mode: resolveMode(for: trimmed))
        drafts = chunks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { chunk in
                Draft(title: makeTitle(for: chunk), value: chunk)
            }
    }

    private func resolveMode(for text: String) -> SplitMode {
        if splitMode != .auto { return splitMode }
        if text.range(of: #"^\s*(---|===)\s*$"#, options: [.regularExpression, .anchored]) != nil ||
            text.contains("\n---\n") || text.contains("\n===\n") {
            return .separator
        }
        if text.contains("\n\n") { return .blankLine }
        return .oneLinePerMemo
    }

    private func split(_ text: String, mode: SplitMode) -> [String] {
        switch mode {
        case .auto, .separator:
            // 구분선 (--- / ===) 우선, 그 다음 빈 줄
            let stage1 = splitByRegex(text, pattern: #"\n[-=]{3,}\n"#)
            return stage1.flatMap { splitByRegex($0, pattern: #"\n\s*\n"#) }
        case .blankLine:
            return splitByRegex(text, pattern: #"\n\s*\n"#)
        case .oneLinePerMemo:
            return text.components(separatedBy: "\n")
        }
    }

    /// 정규식 기반 분할 (NSRegularExpression — iOS 13+ 호환).
    private func splitByRegex(_ text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [text]
        }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return [text] }
        var pieces: [String] = []
        var cursor = text.startIndex
        for m in matches {
            guard let r = Range(m.range, in: text) else { continue }
            pieces.append(String(text[cursor..<r.lowerBound]))
            cursor = r.upperBound
        }
        pieces.append(String(text[cursor...]))
        return pieces
    }

    private func makeTitle(for value: String) -> String {
        // 1) 자동 타입 감지
        let result = ClipboardClassificationService.shared.classify(content: value)
        if result.confidence >= 0.7 {
            return result.type.localizedName
        }
        // 2) 첫 줄 (40자 cap)
        let firstLine = value.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? value
        if firstLine.count <= 40 { return firstLine }
        return String(firstLine.prefix(37)) + "…"
    }

    private func saveAll() {
        let toSave = drafts.filter { $0.include && !$0.value.isEmpty }
        guard !toSave.isEmpty else { return }

        do {
            var existing = (try? MemoStore.shared.load(type: .memo)) ?? []
            for d in toSave {
                let title = d.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let detected = ClipboardClassificationService.shared.classify(content: d.value)
                let category = detected.confidence >= 0.7 ? detected.type.rawValue : "기본"
                let memo = Memo(
                    title: title.isEmpty ? d.value.prefix(20).trimmingCharacters(in: .whitespacesAndNewlines) : title,
                    value: d.value,
                    category: category
                )
                existing.append(memo)
            }
            try MemoStore.shared.save(memos: existing, type: .memo)
            AnalyticsService.logBulkImported(count: toSave.count)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            savedCount = toSave.count
        } catch {
            print("❌ [BulkImport] save failed: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

#Preview {
    BulkImportView()
}
