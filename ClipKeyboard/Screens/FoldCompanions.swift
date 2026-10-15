//
//  FoldCompanions.swift
//  ClipKeyboard
//
//  펼친 아이폰 듀오의 **손잡이 | 미리보기**. 설정 화면을 열면 그 화면이 고르는 쪽에 서고,
//  여기 있는 짝이 결과 쪽 판을 채운다(`FoldCompanionProviding`, DesignSystem/FoldNavigation.swift).
//
//  폰에서는 설정 화면 맨 위에 작게 얹던 미리보기다. 펴면 그 미리보기를 판 하나에 크게 세운다.
//  손잡이를 움직이면 옆 판이 그 자리에서 바뀐다.
//
//  ⚠️ 짝은 설정 화면의 `@State` 를 볼 수 없다. 모두 `@AppStorage` · 공용 객체를 직접 읽는다.
//

import SwiftUI

// MARK: - 키보드

/// 진짜 키보드(`KeyboardPreviewView`)를 판 폭에 맞춰 세운다. 판이 낮으면 통째로 줄여 담는다.
struct FoldKeyboardCompanion: View {
    var body: some View {
        FoldCompanionPane(title: NSLocalizedString("키보드 미리보기", comment: "Keyboard preview accessibility label")) {
            GeometryReader { proxy in
                KeyboardPreviewView(fitWidth: proxy.size.width, heightBudget: proxy.size.height)
                    .frame(width: proxy.size.width, alignment: .top)
            }
        }
    }
}

extension KeyboardLayoutSettings: FoldCompanionProviding {
    var foldCompanion: some View { FoldKeyboardCompanion() }
}

extension KeyColorSettingsView: FoldCompanionProviding {
    var foldCompanion: some View { FoldKeyboardCompanion() }
}

extension CategoryIconSettings: FoldCompanionProviding {
    var foldCompanion: some View { FoldKeyboardCompanion() }
}

extension CategorySettings: FoldCompanionProviding {
    var foldCompanion: some View { FoldKeyboardCompanion() }
}

// MARK: - 단축어 카드

/// 단축어 목록의 카드 모양. 판 폭에 맞춰 칸이 늘어난다(목록과 같은 셈).
struct FoldCardsCompanion: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        FoldCompanionPane(title: NSLocalizedString("미리보기", comment: "Preview")) {
            GeometryReader { proxy in
                let columns = max(2, min(4, Int((proxy.size.width + 12) / 162)))
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns),
                              spacing: 12) {
                        ForEach(Array(samples.prefix(columns * 3).enumerated()), id: \.offset) { _, sample in
                            MemoCardPreviewCell(title: sample.title, symbol: sample.symbol,
                                                color: sample.color, plusTemplate: sample.template)
                        }
                    }
                }
                .scrollEdgeEffectHidden(true, for: .all)
            }
        }
    }

    private var samples: [(title: String, symbol: String, color: Color, template: Bool)] {
        let snippet = NSLocalizedString("단축어", comment: "Snippet (saved key-value item) display name")
        let template = NSLocalizedString("단축어 + 템플릿", comment: "Memo + template sample")
        return (0..<12).map { i in
            let isTemplate = i % 3 == 1
            return (isTemplate ? template : snippet,
                    isTemplate ? "doc.text.fill" : "folder.fill",
                    [theme.accent, Color.blue, Color.pink, Color.orange][i % 4],
                    isTemplate)
        }
    }
}

extension DisplaySettingsView: FoldCompanionProviding {
    var foldCompanion: some View { FoldCardsCompanion() }
}

// MARK: - 단축어 스킨

/// 고른 스킨을 크게. 목록의 작은 견본(46 x 34)을 그대로 키운다. 카드 모양이 같아야 고르고 나서 놀라지 않는다.
struct FoldLivingSkinCompanion: View {
    @AppStorage(DefaultsKey.livingSkin, store: AppGroup.defaults)
    private var livingSkinRaw: String = LivingSkin.none.rawValue

    var body: some View {
        FoldCompanionPane(title: NSLocalizedString("미리보기", comment: "Preview")) {
            GeometryReader { proxy in
                let scale = min(proxy.size.width / 46, proxy.size.height / 34) * 0.8
                LivingSkinPreview(skin: LivingSkin(rawValue: livingSkinRaw) ?? .none)
                    .scaleEffect(scale)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}

extension LivingSkinSettings: FoldCompanionProviding {
    var foldCompanion: some View { FoldLivingSkinCompanion() }
}

// MARK: - 첫 화면

/// 단축어 탭을 열었을 때 보일 것. 목록이면 카드, 키보드면 키보드.
struct FoldFirstScreenCompanion: View {
    @AppStorage(DefaultsKey.snippetsTabStyle)
    private var snippetsTabStyleRaw: String = SnippetsTabStyle.list.rawValue

    var body: some View {
        if SnippetsTabStyle(rawValue: snippetsTabStyleRaw) == .keyboard {
            FoldKeyboardCompanion()
        } else {
            FoldCardsCompanion()
        }
    }
}

extension FirstScreenSettingsView: FoldCompanionProviding {
    var foldCompanion: some View { FoldFirstScreenCompanion() }
}

// MARK: - 시트의 짝 (재료 | 결과)

/// 템플릿을 채우는 동안 완성될 문장. 아직 안 채운 빈칸은 강조 칩으로 남는다(`templateAwareAttributed`).
struct FoldFilledTextCompanion: View {
    @Environment(\.appTheme) private var theme
    let text: String

    var body: some View {
        ScrollView {
            Text(text.templateAwareAttributed(theme: theme))
                .font(.title3)
                .foregroundColor(theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radiusLg))
                .textSelection(.enabled)
        }
        .scrollEdgeEffectHidden(true, for: .all)
    }
}

/// 저장할 단축어가 목록 카드와 키보드에서 어떻게 보일지. 보안이면 값은 가린다.
struct FoldSnippetCompanion: View {
    struct Draft: Equatable {
        var title: String
        var value: String
        var isSecure: Bool
    }

    @Environment(\.appTheme) private var theme
    let draft: Draft

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MemoCardPreviewCell(title: draft.title.isEmpty
                                    ? NSLocalizedString("제목", comment: "Title field placeholder")
                                    : draft.title,
                                symbol: AppSymbol.docFill,
                                color: theme.accent,
                                plusTemplate: false)
                .frame(maxWidth: 220)

            Text(draft.isSecure
                 ? NSLocalizedString("보안 단축어라 값은 보이지 않아요", comment: "Fold result pane: secure snippet value is hidden")
                 : draft.value)
                .font(.body)
                .foregroundColor(draft.isSecure ? theme.textMuted : theme.text)
                .lineLimit(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radiusMd))
        }
    }
}

// MARK: - 안내 | 따라 하기

/// 키보드 설정 가이드의 짝. 가이드를 읽는 동안 옆 판에서 **지금 켜졌는지**가 실시간으로 바뀐다.
/// 설정 앱에 다녀오면 돌아오자마자 옆 판이 먼저 알려 준다.
struct FoldKeyboardSetupCompanion: View {
    @Environment(\.appTheme) private var theme
    @State private var usable = KeyboardInstallState.isUsable
    @State private var addedInSettings = KeyboardInstallState.isEnabledInSettings

    var body: some View {
        FoldCompanionPane(title: NSLocalizedString("키보드", comment: "iOS Settings: Keyboard")) {
            VStack(alignment: .leading, spacing: 16) {
                statusCard
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    stepRow(index: index, step: step)
                }
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text(NSLocalizedString("설정 열기", comment: "Open Settings button"))
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .task {
            while !Task.isCancelled {
                usable = KeyboardInstallState.isUsable
                addedInSettings = KeyboardInstallState.isEnabledInSettings
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }

    private var steps: [SetupStep] {
        SetupStep.all.filter { $0.kind == .addKeyboard || $0.kind == .fullAccess }
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: usable ? AppSymbol.checkmarkCircleFill : AppSymbol.keyboard)
                .font(.title2)
                .foregroundColor(usable ? .green : theme.textMuted)
            Text(usable
                 ? NSLocalizedString("키보드에서도 쓸 수 있어요", comment: "Keyboard tip title")
                 : NSLocalizedString("아직 다른 앱에서는 못 써요", comment: "Keyboard not set up banner title"))
                .font(.body.weight(.semibold))
                .foregroundColor(theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radiusLg))
        .animation(.easeOut(duration: 0.2), value: usable)
    }

    private func stepRow(index: Int, step: SetupStep) -> some View {
        let done = step.kind == .addKeyboard && addedInSettings
        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(done ? Color.green : theme.surfaceAlt)
                if done {
                    Image(systemName: AppSymbol.checkmark)
                        .font(.body.weight(.bold))
                        .foregroundColor(.white)
                } else {
                    Text(verbatim: "\(index + 1)")
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.text)
                }
            }
            .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(theme.text)
                Text(step.path.joined(separator: " › "))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
            }
        }
    }
}

// MARK: - 손잡이 | 미리보기 (나머지)

/// 날짜 · 시간 모양. **내 템플릿에 오늘을 넣은 모습**을 보여 준다. 그런 템플릿이 없으면 오늘 날짜 · 시간만.
/// 모양을 고르면 옆 판의 문장이 그 자리에서 바뀐다.
struct FoldTokenFormatCompanion: View {
    @Environment(\.appTheme) private var theme
    // 고른 모양이 바뀌면 다시 그린다. 값은 `TemplateVariableProcessor` 가 스스로 읽는다.
    @AppStorage(DateTokenFormat.storageKey, store: AppGroup.defaults) private var dateRaw = DateTokenFormat.automaticCase.rawValue
    @AppStorage(TimeTokenFormat.storageKey, store: AppGroup.defaults) private var timeRaw = TimeTokenFormat.automaticCase.rawValue
    @State private var templates: [Memo] = []

    var body: some View {
        FoldCompanionPane(title: NSLocalizedString("미리보기", comment: "Preview")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    sample(TokenFormatOption<DateTokenFormat>(raw: dateRaw).sampleText()
                           + "  " + TokenFormatOption<TimeTokenFormat>(raw: timeRaw).sampleText())
                    ForEach(templates) { memo in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(memo.title)
                                .font(.body.weight(.semibold))
                                .foregroundColor(theme.textMuted)
                            sample(TemplateVariableProcessor.process(memo.value))
                        }
                    }
                }
            }
            .scrollEdgeEffectHidden(true, for: .all)
        }
        .onAppear(perform: load)
        .onChange(of: dateRaw) { _, _ in load() }
        .onChange(of: timeRaw) { _, _ in load() }
    }

    private func sample(_ text: String) -> some View {
        Text(text)
            .font(.title3)
            .foregroundColor(theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radiusMd))
    }

    /// `{날짜}` · `{시간}` 이 든 내 단축어. 보안 단축어는 값을 꺼내 보이지 않으려고 뺀다.
    private func load() {
        let tokens = TemplateVariableProcessor.dateTokens + TemplateVariableProcessor.timeTokens
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        templates = Array(memos.filter { memo in
            !memo.isSecure && tokens.contains(where: { memo.value.contains($0) })
        }.prefix(6))
    }
}

extension TokenFormatSettingsView: FoldCompanionProviding {
    var foldCompanion: some View { FoldTokenFormatCompanion() }
}

/// Apple Intelligence. **내 최근 복사가 어떻게 분류됐는지**를 보여 준다. 설정이 무슨 일을 하는지 예로 본다.
/// 보안에 해당하는 종류(카드 · 계좌 등)는 값을 가린다.
struct FoldAIClassificationCompanion: View {
    @Environment(\.appTheme) private var theme
    @AppStorage(DefaultsKey.aiClassificationEnabled, store: AppGroup.defaults) private var classificationOn = true
    @State private var clips: [SmartClipboardHistory] = []

    var body: some View {
        FoldCompanionPane(title: String(format: NSLocalizedString("최근 · %d일", comment: "Fold result pane: recent clips header. %d is the retention days"),
                                        SmartClipboardHistory.retentionDays)) {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(clips) { clip in
                        HStack(spacing: 12) {
                            Image(systemName: clip.detectedType.icon)
                                .font(.title3)
                                .foregroundColor(theme.accent)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(clip.detectedType.isSensitive ? String(repeating: "•", count: 8) : clip.content)
                                    .font(.body)
                                    .foregroundColor(theme.text)
                                    .lineLimit(1)
                                Text(clip.detectedType.localizedName)
                                    .font(.body)
                                    .foregroundColor(theme.textMuted)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radiusMd))
                    }
                }
            }
            .scrollEdgeEffectHidden(true, for: .all)
            .opacity(classificationOn ? 1 : 0.45)
            .animation(.easeOut(duration: 0.2), value: classificationOn)
        }
        .onAppear {
            let history = (try? MemoStore.shared.loadSmartClipboardHistory()) ?? []
            clips = Array(history.filter { $0.contentType == .text }.prefix(10))
        }
    }
}

extension AISettingsView: FoldCompanionProviding {
    var foldCompanion: some View { FoldAIClassificationCompanion() }
}

/// 언어 · 나에게 맞추기: 바꾸면 키보드에 서는 말과 붙박이 키가 달라진다. 진짜 키보드로 본다.
extension LanguageSettingsView: FoldCompanionProviding {
    var foldCompanion: some View { FoldKeyboardCompanion() }
}

extension UsageProfileSettingsView: FoldCompanionProviding {
    var foldCompanion: some View { FoldKeyboardCompanion() }
}

/// 사용 단계 흉내(개발용): 그 단계의 목록 모습.
extension UserStageSimulatorView: FoldCompanionProviding {
    var foldCompanion: some View { FoldCardsCompanion() }
}

/// 목록 배경. 고른 사진 위에 카드가 놓인 모습. 글자가 읽히는지 보며 고른다.
struct FoldListBackgroundCompanion: View {
    @AppStorage(DefaultsKey.listBackgroundImageV1, store: AppGroup.defaults)
    private var listBackgroundImage: String = ""
    /// 보여 줄 사진. nil 이면 모든 탭에 깐 배경(설정 값)을 쓴다. 탭마다 고르는 시트는 고른 것을 넘긴다.
    var name: String?

    private var shown: String { name ?? listBackgroundImage }

    var body: some View {
        ZStack {
            if !shown.isEmpty {
                GeometryReader { proxy in
                    BackgroundImageView(name: shown)
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
            }
            FoldCardsCompanion()
                .background(Color.clear)
        }
    }
}

extension ListBackgroundSettings: FoldCompanionProviding {
    var foldCompanion: some View { FoldListBackgroundCompanion() }
}

// MARK: - 재료 | 결과 (나머지)

/// 고른 줄들을 고른 차례대로. 사진에서 값 고르기 · 스택 가져오기가 쓴다.
struct FoldLinesCompanion: View {
    @Environment(\.appTheme) private var theme
    let lines: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .top, spacing: 10) {
                        Text(verbatim: "\(index + 1)")
                            .font(.body.weight(.semibold))
                            .foregroundColor(theme.accent)
                            .frame(width: 24, alignment: .trailing)
                        Text(line)
                            .font(.body)
                            .foregroundColor(theme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radiusMd))
                }
            }
        }
        .scrollEdgeEffectHidden(true, for: .all)
    }
}

/// 번역 시트의 짝: 원문. 시트는 번역을, 옆 판은 원문을 보여서 둘을 맞춰 본다.
struct FoldSourceTextCompanion: View {
    @Environment(\.appTheme) private var theme
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.title3)
                .foregroundColor(theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radiusLg))
                .textSelection(.enabled)
        }
        .scrollEdgeEffectHidden(true, for: .all)
    }
}

/// 빈칸 이름 바꾸기의 짝: 이 빈칸을 쓰는 단축어들이 **바뀐 뒤** 어떻게 읽히는지.
/// 바꾸기 전에 영향받는 곳을 본다. 보안 단축어는 제목만.
struct FoldPlaceholderRenameCompanion: View {
    struct Draft: Equatable {
        let token: String
        let newName: String
        let memoIDs: [UUID]
    }

    @Environment(\.appTheme) private var theme
    let draft: Draft
    @State private var memos: [Memo] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(memos) { memo in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(memo.title)
                            .font(.body.weight(.semibold))
                            .foregroundColor(theme.textMuted)
                        if !memo.isSecure {
                            Text(renamed(memo.value).templateAwareAttributed(theme: theme))
                                .font(.body)
                                .foregroundColor(theme.text)
                                .lineLimit(4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radiusMd))
                }
            }
        }
        .scrollEdgeEffectHidden(true, for: .all)
        .onAppear {
            let all = (try? MemoStore.shared.load(type: .memo)) ?? []
            let ids = Set(draft.memoIDs)
            memos = all.filter { ids.contains($0.id) }
        }
    }

    private func renamed(_ value: String) -> String {
        let name = draft.newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return value }
        return value.replacingOccurrences(of: draft.token, with: "{\(name)}")
    }
}

// MARK: - 안내 | 따라 하기 (나머지)

/// 설정 앱에서 따라 갈 길. 읽는 쪽 옆에 갈 길과 바로 가는 단추가 선다.
struct FoldSettingsPathCompanion: View {
    @Environment(\.appTheme) private var theme
    let steps: [String]
    /// 마지막에 고를 것. 예: 허용 (권장)
    let finalChoice: String?

    var body: some View {
        FoldCompanionPane(title: NSLocalizedString("설정 경로", comment: "Settings path section header")) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 12) {
                        Text(verbatim: "\(index + 1)")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(theme.accent, in: Circle())
                        Text(step)
                            .font(.body.weight(.semibold))
                            .foregroundColor(theme.text)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radiusMd))
                }
                if let finalChoice {
                    HStack(spacing: 12) {
                        Image(systemName: AppSymbol.checkmarkCircleFill)
                            .font(.title3)
                            .foregroundColor(.green)
                            .frame(width: 28)
                        Text(finalChoice)
                            .font(.body.weight(.semibold))
                            .foregroundColor(theme.text)
                    }
                    .padding(12)
                }
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text(NSLocalizedString("설정으로 이동", comment: "Go to Settings button"))
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

extension CopyPasteView: FoldCompanionProviding {
    var foldCompanion: some View {
        FoldSettingsPathCompanion(
            steps: [
                NSLocalizedString("설정", comment: "Settings"),
                NSLocalizedString("ClipKeyboard", comment: "ClipKeyboard app name"),
                NSLocalizedString("다른 앱에서 붙여넣기", comment: "Paste from other apps"),
            ],
            finalChoice: NSLocalizedString("허용", comment: "Allow option") + " "
                + NSLocalizedString("(권장)", comment: "Recommended badge"))
    }
}

/// 손쉬운 사용: 켜 보면 카드가 어떻게 바뀌는지(색 없이 구분 · 굵은 글자 등이 카드에 그대로 비친다).
extension AccessibilityGuideView: FoldCompanionProviding {
    var foldCompanion: some View { FoldCardsCompanion() }
}
