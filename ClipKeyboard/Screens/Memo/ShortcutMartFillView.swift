//
//  ShortcutMartFillView.swift
//  ClipKeyboard
//
//  마트에서 하나를 골라 **빈칸만 내 것으로 채우는** 자리.
//
//  ⚠️ 비운 칸은 지우지 않고 `{변수}` 그대로 남긴다. 그래야 매번 달라지는 것(금액·날짜)은
//     쓸 때 채우는 칸으로 남고, 늘 같은 것(내 이름·계좌번호)만 붙박이가 된다.
//     전부 채우기를 강요하면 "이번 달 금액"을 지금 정해야 하는 이상한 일이 된다.
//
//  ⚠️ 채운 값은 플레이스홀더 값 저장소에 남긴다 - 다음에 같은 칸을 만나면 한 번 눌러 끝난다.
//     (`MemoStore.addPlaceholderValue`, 키는 `{이름}`처럼 중괄호를 포함한 토큰)
//

import SwiftUI
import LeeoKit

struct ShortcutMartFillView: View {
    let item: ShortcutMartItem
    /// 담기 완료 - 마트가 개수를 센다.
    var onUse: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    /// 칸별로 사용자가 적은 값. 비어 있으면 그 칸은 변수로 남는다.
    @State private var inputs: [String: String] = [:]
    @State private var showSaveError = false
    @FocusState private var focused: String?

    var body: some View {
        NavigationStack {
            Form {
                previewSection

                if item.blanks.isEmpty {
                    Section {
                        Text(NSLocalizedString("채울 것 없이 바로 쓸 수 있어요.",
                                               comment: "Shortcut mart fill: nothing to fill"))
                            .font(.callout)
                            .foregroundColor(theme.textMuted)
                    }
                } else {
                    ForEach(item.blanks, id: \.self) { blank in
                        blankSection(blank)
                    }
                }
            }
            .navigationTitle(item.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .solidNavBar(theme.bg)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("이거 쓰기", comment: "Shortcut mart: use this one")) { use() }
                        .fontWeight(.semibold)
                }
            }
            .alert(NSLocalizedString("추가 실패", comment: "Starter pack add failed alert title"),
                   isPresented: $showSaveError) {
                Button(NSLocalizedString("확인", comment: "Confirm")) {}
            } message: {
                Text(NSLocalizedString("단축어를 추가하지 못했습니다. 잠시 후 다시 시도해주세요.",
                                       comment: "Starter pack add failed alert message"))
            }
        }
    }

    // MARK: - 미리보기

    /// 채우는 대로 문장이 완성돼 간다 - 무엇을 만들고 있는지 눈으로 확인되지 않으면
    /// 빈칸 채우기는 그냥 서식 작성이 된다.
    private var previewSection: some View {
        Section {
            Text(filledValue.templateChipAttributed(theme: theme, font: .callout))
                .font(.callout)
                .foregroundColor(theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        } header: {
            Text(NSLocalizedString("이렇게 저장돼요", comment: "Shortcut mart fill: preview header"))
        } footer: {
            if !item.blanks.isEmpty {
                Text(NSLocalizedString("비워 둔 칸은 쓸 때마다 채우는 칸으로 남아요. 늘 같은 것만 지금 적으세요.",
                                       comment: "Shortcut mart fill: blank policy footer"))
            }
        }
    }

    // MARK: - 빈칸 하나

    private func blankSection(_ blank: String) -> some View {
        // 저장된 값이 있으면 눌러서 바로 채운다 - 두 번째부터는 타이핑이 필요 없다.
        let remembered = MemoStore.shared.loadPlaceholderValues(for: blank)

        return Section {
            TextField(NSLocalizedString("비워 두면 변수로 남아요", comment: "Shortcut mart fill: field placeholder"),
                      text: Binding(get: { inputs[blank] ?? "" },
                                    set: { inputs[blank] = $0 }))
                .focused($focused, equals: blank)

            if !remembered.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(remembered.prefix(6)) { saved in
                            Button {
                                inputs[blank] = saved.value
                                HapticManager.shared.light()
                            } label: {
                                Text(saved.value)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(theme.surfaceAlt, in: Capsule())
                                    .foregroundColor(theme.text)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
            }
        } header: {
            // 중괄호는 사용자에게 보여주지 않는다 - 앱 어디서도 `{ }`를 노출하지 않는 규칙.
            Text(blank.trimmingCharacters(in: CharacterSet(charactersIn: "{}")))
        }
    }

    // MARK: - 값 만들기

    /// 채운 것만 갈아 끼운 본문. 비운 칸은 `{변수}` 그대로 남는다.
    private var filledValue: String {
        var result = item.example
        for blank in item.blanks {
            let typed = (inputs[blank] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !typed.isEmpty else { continue }
            result = result.replacingOccurrences(of: blank, with: typed)
        }
        return result
    }

    private func use() {
        let value = filledValue
        // 남은 변수만 템플릿 변수로 - 다 채웠으면 평범한 단축어가 된다.
        let remaining = TemplateVariableProcessor.extractCustomTokens(in: value)
        let memo = Memo(title: item.title, value: value, templateVariables: remaining)

        do {
            var memos = try MemoStore.shared.load(type: .memo)
            memos.insert(memo, at: 0)
            try MemoStore.shared.save(memos: memos, type: .memo)

            // 적은 값을 기억해 둔다 - 다음에 같은 칸을 만나면 눌러서 끝난다.
            for blank in item.blanks {
                let typed = (inputs[blank] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !typed.isEmpty else { continue }
                MemoStore.shared.addPlaceholderValue(typed,
                                                     for: blank,
                                                     sourceMemoId: memo.id,
                                                     sourceMemoTitle: memo.title)
            }

            NotificationCenter.default.post(name: .demoSamplesInserted, object: nil)
            #if os(iOS)
            HapticManager.shared.success()
            #endif
            print("✅ [ShortcutMart] '\(item.title)' 담기 완료 (남은 변수 \(remaining.count)개)")
            onUse()
            dismiss()
        } catch {
            // 실패하면 닫지 않는다 - 채워 둔 것을 잃지 않게.
            print("❌ [ShortcutMart.use] 저장 실패: \(error)")
            #if os(iOS)
            HapticManager.shared.error()
            #endif
            showSaveError = true
        }
    }
}
