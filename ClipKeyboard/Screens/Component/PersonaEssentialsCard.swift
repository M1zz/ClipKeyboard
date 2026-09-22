//
//  PersonaEssentialsCard.swift
//  ClipKeyboard
//
//  목록 맨 위 **필수 단축어 세 칸.** 알아본 쓰임새(판)마다 칸이 다르다(`PersonaEdition`).
//
//  이미 비슷한 것을 저장해 두었으면 그 칸은 찬 것으로 보인다. 빈 칸을 누르면 마트의
//  빈칸 채우기 판(`ShortcutMartFillView`)이 그 판의 문장으로 열린다. 세 칸이 다 차면 카드는
//  스스로 물러난다. 닫으면 **그 판에서는** 다시 뜨지 않는다. 쓰임새가 달라져 판이 바뀌면
//  새 판의 카드가 한 번 선다.
//
//  ⚠️ 무료 칸이 없으면 채우기 판을 열지 않고 페이월로 보낸다. 채우기 판은 한도를 보지 않는다
//     (마트에서 담는 길과 같다). 여기서 막지 않으면 11번째가 이 카드로 새어 들어간다.
//

import SwiftUI
import LeeoKit

struct PersonaEssentialsCardContainer: View {
    let memos: [Memo]
    /// 목록을 다 읽었는가. 읽기 전에 세우면 "빈 칸 셋" 이 잠깐 번쩍인다.
    let hasLoaded: Bool
    /// 휴면이거나 막 돌아왔는가.
    let isAwayOrJustBack: Bool
    /// 무료 칸이 없을 때. 목록이 페이월을 띄운다.
    let onNeedsRoom: () -> Void

    @State private var kind: PersonaEdition.Kind = .everyone
    @State private var coverage: [String: UUID] = [:]
    @State private var dismissedKinds: Set<PersonaEdition.Kind> = PersonaEditionStore.dismissed
    @State private var picked: PersonaEdition.Essential?

    private var essentials: [PersonaEdition.Essential] { PersonaEdition.essentials(for: kind) }

    private var isShowing: Bool {
        PersonaEdition.showsShelf(PersonaEdition.ShelfContext(
            kind: kind,
            covered: essentials.filter { coverage[$0.id] != nil }.count,
            total: essentials.count,
            dismissed: dismissedKinds,
            ownMemoCount: ProFeatureManager.ownMemoCount(memos),
            isAwayOrJustBack: isAwayOrJustBack,
            hasLoaded: hasLoaded
        ))
    }

    /// 목록이 바뀌었는지 가늠하는 값. 제목을 고쳐도 칸이 찰 수 있어 제목까지 본다.
    private var memoSignature: [String] {
        memos.map { $0.id.uuidString + $0.title }
    }

    var body: some View {
        DismissibleRow(isShowing: isShowing) {
            PersonaEssentialsCard(kind: kind,
                                  essentials: essentials,
                                  coverage: coverage,
                                  onPick: pick,
                                  onDismiss: dismiss)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
        // 그리는 자리에서 분류를 돌리지 않는다 - 몇 번 그릴지는 SwiftUI 가 정한다.
        .task(id: memoSignature) { recompute() }
        .sheet(item: $picked) { essential in
            ShortcutMartFillView(
                item: ShortcutMartItem(emoji: essential.emoji,
                                       categoryTitle: "",
                                       title: essential.title,
                                       example: essential.example,
                                       feature: TemplateVariableProcessor.extractCustomTokens(in: essential.example).isEmpty
                                           ? .snippet : .template),
                onUse: {},
                onSaved: { memoID in
                    PersonaEditionStore.link(essential.id, to: memoID)
                    // 붙박이를 곧바로 다시 적는다. 키보드를 내리자마자 그 칸이 첫 줄에 있어야 한다.
                    UserStateStore.shared.refresh()
                }
            )
        }
    }

    private func recompute() {
        kind = PersonaEditionStore.currentKind
        coverage = PersonaEditionStore.coverage(memos: memos,
                                                sampleIDs: ProFeatureManager.sampleMemoIds,
                                                kind: kind)
    }

    private func pick(_ essential: PersonaEdition.Essential) {
        HapticManager.shared.light()
        guard ProFeatureManager.canAddMemo(currentCount: ProFeatureManager.ownMemoCount(memos)) else {
            onNeedsRoom()
            return
        }
        picked = essential
    }

    private func dismiss() {
        PersonaEditionStore.dismiss(kind)
        dismissedKinds.insert(kind)
    }
}

// MARK: - 카드

struct PersonaEssentialsCard: View {
    let kind: PersonaEdition.Kind
    let essentials: [PersonaEdition.Essential]
    let coverage: [String: UUID]
    let onPick: (PersonaEdition.Essential) -> Void
    let onDismiss: () -> Void

    @Environment(\.appTheme) private var theme

    private var coveredCount: Int { essentials.filter { coverage[$0.id] != nil }.count }

    private var icon: String {
        switch kind {
        case .everyone: return AppSymbol.sparkles
        case .general: return Persona.general.icon
        case .nomad: return Persona.nomad.icon
        case .business: return Persona.business.icon
        case .student: return Persona.student.icon
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            VStack(spacing: 8) {
                ForEach(essentials) { essential in
                    row(essential)
                }
            }
        }
        .padding(14)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                .stroke(theme.accent.opacity(0.30), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(theme.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(PersonaEdition.headline(for: kind))
                    .font(.headline)
                    .foregroundColor(theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(String(format: NSLocalizedString("%1$d / %2$d 채움", comment: "Essentials card progress: N of M essential snippets saved"),
                            coveredCount, essentials.count))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            Button(action: onDismiss) {
                Image(systemName: AppSymbol.xmark)
                    .font(.body.weight(.semibold))
                    .foregroundColor(theme.textFaint)
                    .padding(6)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(NSLocalizedString("닫기", comment: "Close / dismiss"))
        }
    }

    private func row(_ essential: PersonaEdition.Essential) -> some View {
        let isCovered = coverage[essential.id] != nil
        return Button {
            onPick(essential)
        } label: {
            HStack(spacing: 10) {
                Text(essential.emoji)
                    .font(.title3)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(essential.title)
                        .font(.body.weight(.semibold))
                        .foregroundColor(isCovered ? theme.textMuted : theme.text)
                    Text(essential.moment)
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: isCovered ? AppSymbol.checkmarkCircleFill : AppSymbol.plusCircleFill)
                    .font(.title3)
                    .foregroundColor(isCovered ? .green : theme.accent)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceAlt.opacity(isCovered ? 0.4 : 1))
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isCovered)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isCovered
                            ? NSLocalizedString("저장해 두셨어요", comment: "VoiceOver: essential snippet already saved")
                            : NSLocalizedString("아직 없어요", comment: "VoiceOver: essential snippet not saved yet"))
        .accessibilityHint(isCovered ? "" : NSLocalizedString("탭하면 빈칸만 채워서 저장해요", comment: "VoiceOver: tap to fill the blanks and save this essential snippet"))
    }
}
