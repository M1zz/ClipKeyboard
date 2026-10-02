//
//  DefaultCategoryNamePrompt.swift
//  ClipKeyboard
//
//  앱이 깔아 준 카테고리 페이지 맨 위에 서서 "이름을 바꿀까요?" 를 묻는 카드.
//
//  ⚠️ 닫는 단추가 없다. **그대로 쓰기 · 이름 바꾸기 중 하나를 골라야** 걷힌다.
//     업무 · 개인은 앱이 지은 이름이라 사용자의 말이 아니다. 묻지 않고 두면 남이 지은
//     칸에 자기 것을 넣게 되고, 닫을 수 있게 하면 닫고 잊는다(요청: 그렇다 아니다를
//     반드시 선택하게 해줘).
//  ⚠️ 이름 바꾸기 창에서 취소하면 고른 것이 아니다. 카드는 그대로 남는다.
//

import SwiftUI
import LeeoKit

struct DefaultCategoryNamePrompt: View {
    let name: String
    let onKept: () -> Void
    let onRenamed: (String) -> Void

    @Environment(\.appTheme) private var theme
    @State private var showsRename = false
    @State private var draft = ""
    @State private var rejected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: AppSymbol.folderBadgePlus)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: NSLocalizedString("'%@' 이름을 바꿀까요?", comment: "Prompt on a category the app created: ask whether to rename it. %@ is the category name"), name))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.text)
                    Text(NSLocalizedString("앱이 처음에 만들어 둔 카테고리예요. 쓰시는 대로 이름을 정해 주세요.", comment: "Prompt on a category the app created: explanation"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    if rejected {
                        Text(NSLocalizedString("그 이름은 쓸 수 없어요. 이미 있거나 기본 탭과 같은 이름이에요.", comment: "Rename rejected: name already exists or is reserved"))
                            .font(.footnote)
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Button {
                    HapticManager.shared.light()
                    onKept()
                } label: {
                    Text(NSLocalizedString("그대로 쓰기", comment: "Keep the category name the app created"))
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(theme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.surfaceAlt)
                        .clipShape(Capsule())
                }
                Button {
                    HapticManager.shared.light()
                    draft = name
                    showsRename = true
                } label: {
                    Text(NSLocalizedString("이름 바꾸기", comment: "Rename placeholder title"))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.accentForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        .alert(NSLocalizedString("이름 바꾸기", comment: "Rename placeholder title"), isPresented: $showsRename) {
            TextField(NSLocalizedString("카테고리 이름", comment: "Category name placeholder"), text: $draft)
            Button(NSLocalizedString("바꾸기", comment: "Accept the edit-pattern suggestion")) { commitRename() }
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { }
        }
    }

    private func commitRename() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        // 같은 이름 그대로면 그대로 쓰기를 고른 것이다.
        if trimmed == name {
            onKept()
            return
        }
        if CategoryStore.shared.rename(from: name, to: trimmed) {
            HapticManager.shared.success()
            onRenamed(trimmed)
        } else {
            rejected = true
        }
    }
}
