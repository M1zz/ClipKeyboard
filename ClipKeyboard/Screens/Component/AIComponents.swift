//
//  AIComponents.swift
//  ClipKeyboard
//
//  Apple Intelligence 기반 UI 컴포넌트:
//  - SuggestedActionChips: 클립보드 항목의 타입/AI 예측 기반 단축 액션 바
//  - TranslationSheet: 온디바이스 번역 시트
//

import SwiftUI

// MARK: - Suggested Action (단축 액션 모델)

/// 클립보드 항목에 제안되는 단축 액션 하나.
struct SuggestedAction: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let perform: () -> Void
}

// MARK: - Suggested Action Chips

/// 클립보드 항목 아래에 표시되는 단축 액션 칩 바.
/// 1) 타입이 자명한 항목(URL/이메일/전화/주소)은 즉시 결정되는 액션을,
/// 2) 일반 텍스트는 AI의 "붙여넣을 앱" 예측 결과를 칩으로 보여준다.
/// 3) AI 사용 가능 시 모든 텍스트 항목에 "번역" 칩 제공.
struct SuggestedActionChips: View {
    let item: SmartClipboardHistory
    var onSaveAsMemo: () -> Void
    var onTranslate: () -> Void

    @Environment(\.appTheme) private var theme
    /// AI 예측 결과 (일반 텍스트 전용, 비동기 로드)
    @State private var aiPrediction: PasteTargetPrediction?

    private var displayType: ClipboardItemType {
        item.userCorrectedType ?? item.detectedType
    }

    private var aiEnabled: Bool {
        AppleIntelligenceService.shared.isAvailable
            && AppleIntelligenceService.actionSuggestionsEnabled
    }

    var body: some View {
        let actions = builtActions
        if !actions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(actions) { action in
                        chip(action)
                    }
                }
            }
            .task(id: item.id) {
                await loadAIPredictionIfNeeded()
            }
        }
    }

    private func chip(_ action: SuggestedAction) -> some View {
        Button(action: action.perform) {
            HStack(spacing: 4) {
                Image(systemName: action.icon)
                    .font(.caption2)
                    .accessibilityHidden(true)
                Text(action.label)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(theme.accentSoft)
            .foregroundColor(theme.accent)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.label)
    }

    // MARK: - Action Builders

    private var builtActions: [SuggestedAction] {
        guard item.contentType == .text else { return [] }
        var actions: [SuggestedAction] = []
        let content = item.content.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) 타입 기반 즉시 액션 (AI 불필요 - 모든 기기에서 동작)
        switch displayType {
        case .url:
            actions.append(SuggestedAction(
                label: NSLocalizedString("브라우저에서 열기", comment: "Suggested action: open in browser"),
                icon: "safari"
            ) { openURL(normalizedWebURL(content)) })
        case .email:
            actions.append(SuggestedAction(
                label: NSLocalizedString("메일 쓰기", comment: "Paste target action: compose mail"),
                icon: "envelope"
            ) { openURL(URL(string: "mailto:\(content)")) })
        case .phone:
            let digits = content.filter { $0.isNumber || $0 == "+" }
            actions.append(SuggestedAction(
                label: NSLocalizedString("전화 걸기", comment: "Suggested action: call"),
                icon: "phone"
            ) { openURL(URL(string: "tel:\(digits)")) })
            actions.append(SuggestedAction(
                label: NSLocalizedString("메시지 보내기", comment: "Paste target action: send message"),
                icon: "message"
            ) { openURL(URL(string: "sms:\(digits)")) })
        case .address:
            let query = content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            actions.append(SuggestedAction(
                label: NSLocalizedString("지도에서 보기", comment: "Suggested action: open in maps"),
                icon: "map"
            ) { openURL(URL(string: "https://maps.apple.com/?q=\(query)")) })
        default:
            // 2) 일반 텍스트 - AI 예측 결과가 있으면 칩 추가
            if let prediction = aiPrediction, prediction != .none {
                actions.append(aiAction(for: prediction, content: content))
            }
        }

        // 3) 번역 칩 - AI 사용 가능하면 모든 텍스트 항목에 제공
        if AppleIntelligenceService.shared.isAvailable, !content.isEmpty {
            actions.append(SuggestedAction(
                label: NSLocalizedString("번역", comment: "Suggested action: translate"),
                icon: "translate"
            ) { onTranslate() })
        }

        return actions
    }

    private func aiAction(for prediction: PasteTargetPrediction, content: String) -> SuggestedAction {
        let encoded = content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        switch prediction {
        case .mail:
            return SuggestedAction(label: prediction.actionLabel, icon: prediction.icon) {
                openURL(URL(string: "mailto:?body=\(encoded)"))
            }
        case .messages:
            return SuggestedAction(label: prediction.actionLabel, icon: prediction.icon) {
                openURL(URL(string: "sms:&body=\(encoded)"))
            }
        case .calendar:
            // 이벤트 프리필은 불가 - 텍스트를 클립보드에 두고 캘린더만 연다.
            return SuggestedAction(label: prediction.actionLabel, icon: prediction.icon) {
                UIPasteboard.general.string = content
                openURL(URL(string: "calshow:"))
            }
        case .webSearch:
            return SuggestedAction(label: prediction.actionLabel, icon: prediction.icon) {
                openURL(URL(string: "https://www.google.com/search?q=\(encoded)"))
            }
        case .notes:
            return SuggestedAction(label: prediction.actionLabel, icon: prediction.icon) {
                onSaveAsMemo()
            }
        case .none:
            return SuggestedAction(label: "", icon: "") {}
        }
    }

    /// ⚠️ `@MainActor` - `await` 뒤에서 `@State`(`aiPrediction`)를 고친다.
    @MainActor
    private func loadAIPredictionIfNeeded() async {
        guard aiEnabled, aiPrediction == nil,
              item.contentType == .text,
              displayType == .text || displayType == .name else { return }
        aiPrediction = await AppleIntelligenceService.shared.predictPasteTarget(item.content)
    }

    // MARK: - Helpers

    private func normalizedWebURL(_ raw: String) -> URL? {
        if raw.lowercased().hasPrefix("http://") || raw.lowercased().hasPrefix("https://") {
            return URL(string: raw)
        }
        return URL(string: "https://\(raw)")
    }

    private func openURL(_ url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Translation Sheet

/// 온디바이스 번역 시트 - 원문/번역 결과 표시, 언어 선택, 복사/메모 저장.
struct TranslationSheet: View {
    let sourceText: String
    /// 번역 결과를 메모로 저장할 때 호출 (nil이면 저장 버튼 숨김)
    var onSaveAsMemo: ((String) -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var targetLanguage: AITranslationLanguage = AppleIntelligenceService.translationTargetLanguage
    @State private var translatedText: String = ""
    @State private var isTranslating = false
    @State private var errorMessage: String?
    @State private var didCopy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 원문
                    sectionCard(
                        title: NSLocalizedString("원문", comment: "Translation: source text label"),
                        text: sourceText
                    )

                    // 대상 언어 선택
                    HStack {
                        Image(systemName: "translate")
                            .foregroundColor(theme.accent)
                            .accessibilityHidden(true)
                        Picker(NSLocalizedString("번역 언어", comment: "Translation target language picker"),
                               selection: $targetLanguage) {
                            ForEach(AITranslationLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        Spacer()
                    }

                    // 번역 결과
                    if isTranslating {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(NSLocalizedString("번역 중…", comment: "Translating progress label"))
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    } else if let errorMessage {
                        Label(errorMessage, systemImage: AppSymbol.xmarkCircleFill)
                            .font(.body)
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                    } else if !translatedText.isEmpty {
                        sectionCard(
                            title: NSLocalizedString("번역 결과", comment: "Translation: result label"),
                            text: translatedText,
                            highlighted: true
                        )

                        actionButtons
                    }

                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("번역", comment: "Suggested action: translate"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("닫기", comment: "Close")) { dismiss() }
                }
            }
            .task(id: targetLanguage) { await translate() }
        }
    }

    private func sectionCard(title: String, text: String, highlighted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(theme.textMuted)
            Text(text)
                .font(.body)
                .foregroundColor(theme.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(highlighted ? theme.accentSoft : theme.surfaceAlt)
                .cornerRadius(theme.radiusSm)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                UIPasteboard.general.string = translatedText
                withAnimation { didCopy = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { didCopy = false }
                }
            } label: {
                Label(didCopy
                      ? NSLocalizedString("복사됨!", comment: "Copied confirmation")
                      : NSLocalizedString("복사", comment: "Copy translation button"),
                      systemImage: didCopy ? AppSymbol.checkmarkCircleFill : "doc.on.doc")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(theme.accent)
                    .foregroundColor(.white)
                    .cornerRadius(theme.radiusSm)
            }
            .buttonStyle(.plain)

            if let onSaveAsMemo {
                Button {
                    onSaveAsMemo(translatedText)
                    dismiss()
                } label: {
                    Label(NSLocalizedString("단축어로 저장", comment: "Paste target action: save as memo"),
                          systemImage: AppSymbol.squareAndArrowDown)
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.surfaceAlt)
                        .foregroundColor(theme.text)
                        .cornerRadius(theme.radiusSm)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// ⚠️ `@MainActor` - `await` 뒤에서 `@State` 를 고친다.
    @MainActor
    private func translate() async {
        isTranslating = true
        errorMessage = nil
        defer { isTranslating = false }
        do {
            translatedText = try await AppleIntelligenceService.shared.translate(sourceText, to: targetLanguage)
        } catch {
            translatedText = ""
            errorMessage = error.localizedDescription
        }
    }
}
