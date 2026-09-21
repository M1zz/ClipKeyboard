//
//  UsageProfileSettingsView.swift
//  ClipKeyboard
//
//  설정 > 단축어 > **나에게 맞추기.** 앱이 이 사람을 어떤 쓰임새로 보고 있는지, 왜 그렇게 봤는지.
//
//  예전 이 자리는 "페르소나" 를 고르는 화면이었다. 이제 고르는 일은 앱이 한다
//  (`PersonaInference`). 이 화면이 하는 일은 둘뿐이다.
//
//  1. **무엇을 보고 그렇게 판단했는지 보여 준다.** 판단의 근거가 안 보이면 추천이 왜 바뀌었는지
//     사람이 알 길이 없고, 모르는 채로 바뀌는 화면은 고장으로 읽힌다.
//  2. **틀렸을 때 바로잡는 문.** 기본은 자동이고, 직접 정하면 그 뒤로는 그 값이 이긴다.
//     "자동" 을 다시 고르면 앱이 다시 알아본다.
//

import SwiftUI
import LeeoKit

struct UsageProfileSettingsView: View {

    @Environment(\.appTheme) private var theme
    @State private var result: PersonaInference.Result = .unknown
    @State private var override: Persona? = PersonaResolver.override

    var body: some View {
        List {
            summarySection
            if override == nil, result.isConfident, !result.evidence.isEmpty {
                evidenceSection
            }
            effectsSection
            editionSection
            overrideSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("나에게 맞추기", comment: "Usage profile settings title: the app adapts to how you use it"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .solidNavBar(theme.bg)
        .onAppear { result = PersonaResolver.evaluateNow() }
    }

    // MARK: - 지금 어떻게 보고 있나

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: shownPersona?.icon ?? AppSymbol.sparkles)
                        .font(.title3)
                        .foregroundColor(theme.accent)
                        .frame(width: 32)
                        .accessibilityHidden(true)
                    Text(summaryTitle)
                        .font(.headline)
                        .foregroundColor(theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(summaryDetail)
                    .font(.subheadline)
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        } footer: {
            Text(NSLocalizedString("저장하신 단축어의 제목·종류·빈칸 이름만 봐요. 기기 밖으로 보내지 않아요.",
                                   comment: "Usage profile settings: privacy note about what is inspected"))
        }
    }

    /// 화면에 세울 쓰임새. 직접 정했으면 그것, 아니면 확신할 때만.
    private var shownPersona: Persona? {
        override ?? (result.isConfident ? result.persona : nil)
    }

    private var summaryTitle: String {
        if let override {
            return String(format: NSLocalizedString("%@ 쓰임새로 직접 정해 두셨어요",
                                                    comment: "Usage profile: user fixed the persona manually. %@ = persona title"),
                          override.localizedTitle)
        }
        if let persona = shownPersona {
            return String(format: NSLocalizedString("%@ 쪽으로 쓰고 계신 것 같아요",
                                                    comment: "Usage profile: app inferred the persona. %@ = persona title"),
                          persona.localizedTitle)
        }
        return NSLocalizedString("아직 뚜렷한 쓰임새가 보이지 않아요",
                                 comment: "Usage profile: not enough signal to infer a persona")
    }

    private var summaryDetail: String {
        if override != nil {
            return NSLocalizedString("아래에서 '자동'을 고르시면 앱이 다시 알아서 맞춰요.",
                                     comment: "Usage profile: how to return to automatic")
        }
        if shownPersona != nil {
            return NSLocalizedString("따로 고르지 않으셔도 돼요. 단축어가 늘면 판단도 함께 바뀌어요.",
                                     comment: "Usage profile: inferred, no need to choose")
        }
        return NSLocalizedString("단축어를 몇 개 더 만드시면 그에 맞는 예시와 기능을 먼저 보여 드려요. 그때까지는 모두에게 맞는 것부터 보여 드려요.",
                                 comment: "Usage profile: not inferred yet, explains what happens later")
    }

    // MARK: - 왜 그렇게 봤나

    private var evidenceSection: some View {
        Section {
            ForEach(Array(result.evidence.prefix(5).enumerated()), id: \.offset) { _, evidence in
                Label(evidenceText(evidence), systemImage: evidenceIcon(evidence))
                    .font(.subheadline)
            }
        } header: {
            Text(NSLocalizedString("이렇게 알아봤어요", comment: "Usage profile: evidence section header"))
        }
    }

    private func evidenceText(_ evidence: PersonaInference.Evidence) -> String {
        switch evidence.kind {
        case .type(let type):
            return String(format: NSLocalizedString("%1$@ 값이 든 단축어 %2$d개",
                                                    comment: "Usage profile evidence: N snippets contain a detected value type, e.g. IBAN"),
                          type.localizedName, evidence.count)
        case .keyword(let word):
            return String(format: NSLocalizedString("'%1$@' 낱말이 든 단축어 %2$d개",
                                                    comment: "Usage profile evidence: N snippets contain a word"),
                          word, evidence.count)
        case .placeholder(let name):
            return String(format: NSLocalizedString("빈칸 '%@'",
                                                    comment: "Usage profile evidence: a template blank with this name"),
                          name)
        case .category(let name):
            return String(format: NSLocalizedString("카테고리 '%@'",
                                                    comment: "Usage profile evidence: a user category with this name"),
                          name)
        case .earlierChoice:
            return NSLocalizedString("전에 직접 고르신 유형",
                                     comment: "Usage profile evidence: the persona the user picked in an older version")
        }
    }

    private func evidenceIcon(_ evidence: PersonaInference.Evidence) -> String {
        switch evidence.kind {
        case .type(let type): return type.icon
        case .keyword: return AppSymbol.textQuote
        case .placeholder: return AppSymbol.textCursor
        case .category: return AppSymbol.folder
        case .earlierChoice: return AppSymbol.personCropCircleBadgeCheckmark
        }
    }

    // MARK: - 무엇이 달라지나

    private var effectsSection: some View {
        Section {
            effectRow(AppSymbol.bagFill,
                      NSLocalizedString("단축어 마트와 카테고리 제안이 쓰임새에 맞는 것부터 나와요",
                                        comment: "Usage profile effect: shortcut mart and category suggestions"))
            effectRow(AppSymbol.pinFill,
                      NSLocalizedString("계좌·학번처럼 불쑥 묻는 것은 키보드 빠른 줄 같은 자리에 늘 세워 둬요",
                                        comment: "Usage profile effect: request-type snippets pinned to the keyboard quick row"))
            effectRow(AppSymbol.calendarBadgeClock,
                      NSLocalizedString("매주·매달 같은 때 쓰는 단축어는 그때가 오면 키보드 맨 앞에 서요",
                                        comment: "Usage profile effect: rhythm-based quick row"))
            effectRow(AppSymbol.lockFill,
                      NSLocalizedString("사진에서 읽은 여권·카드 번호는 Face ID로 잠가 둬요",
                                        comment: "Usage profile effect: lock sensitive values read from photos"))
        } header: {
            Text(NSLocalizedString("이렇게 맞춰 드려요", comment: "Usage profile: effects section header"))
        } footer: {
            Text(NSLocalizedString("쓸 수 있는 기능과 한도는 쓰임새와 상관없이 같아요. 먼저 보여 드리는 순서만 바뀌어요.",
                                   comment: "Usage profile: effects never change limits or access"))
        }
    }

    // MARK: - 지금 판의 필수 단축어

    /// 지금 판(`PersonaEdition`). 직접 정했으면 그것, 아니면 앱이 알아본 것(확신할 때만).
    private var edition: PersonaEdition.Kind {
        if let override {
            return PersonaEdition.kind(for: FeatureFit.Profile(persona: override, isConfident: true))
        }
        return PersonaEdition.kind(for: FeatureFit.Profile(persona: result.persona, isConfident: result.isConfident))
    }

    private var editionSection: some View {
        Section {
            ForEach(PersonaEdition.essentials(for: edition)) { essential in
                VStack(alignment: .leading, spacing: 2) {
                    Text(essential.emoji + " " + essential.title)
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.text)
                    Text(essential.moment)
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text(NSLocalizedString("먼저 챙겨 드리는 세 가지", comment: "Usage profile: section listing the three essential snippets for the current usage profile"))
        } footer: {
            Text(NSLocalizedString("목록 맨 위 카드에서 빈칸만 채우면 저장돼요. 쓰임새가 바뀌면 세 가지도 바뀌어요.",
                                   comment: "Usage profile: essentials section footer"))
        }
    }

    private func effectRow(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - 직접 정하기

    private var overrideSection: some View {
        Section {
            overrideRow(nil,
                        title: NSLocalizedString("자동 (추천)", comment: "Usage profile: automatic option"),
                        icon: AppSymbol.sparkles)
            ForEach(Persona.allCases, id: \.self) { persona in
                overrideRow(persona, title: persona.localizedTitle, icon: persona.icon)
            }
        } header: {
            Text(NSLocalizedString("직접 정하기", comment: "Usage profile: manual override section header"))
        } footer: {
            Text(NSLocalizedString("앱의 판단이 틀렸을 때만 고르세요.",
                                   comment: "Usage profile: manual override footer"))
        }
    }

    private func overrideRow(_ persona: Persona?, title: String, icon: String) -> some View {
        Button {
            HapticManager.shared.selection()
            override = persona
            PersonaResolver.override = persona
            // 판이 바뀌면 키보드 붙박이도 새 판의 것으로 곧바로.
            UserStateStore.shared.refresh()
        } label: {
            HStack {
                Label(title, systemImage: icon)
                    .foregroundColor(theme.text)
                Spacer()
                if override == persona {
                    Image(systemName: AppSymbol.checkmark)
                        .foregroundColor(theme.accent)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityAddTraits(override == persona ? .isSelected : [])
    }
}
