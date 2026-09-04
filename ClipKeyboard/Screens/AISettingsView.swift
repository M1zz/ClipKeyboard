//
//  AISettingsView.swift
//  ClipKeyboard
//
//  Apple Intelligence(온디바이스 AI) 기능 설정 - iOS 26+ Apple Intelligence 기기 전용.
//  분류 보강 / 붙여넣기 앱 제안 / 번역 기본 언어를 관리한다.
//

import SwiftUI

struct AISettingsView: View {
    @Environment(\.appTheme) private var theme

    @AppStorage(DefaultsKey.aiClassificationEnabled, store: AppGroup.defaults)
    private var classificationEnabled: Bool = true
    @AppStorage(DefaultsKey.aiActionSuggestionsEnabled, store: AppGroup.defaults)
    private var actionSuggestionsEnabled: Bool = true
    @AppStorage(DefaultsKey.aiTranslationTargetLang, store: AppGroup.defaults)
    private var translationTargetLang: String = AppTranslation.key(for: AppTranslation.defaultTarget)
    /// 이 기기가 실제로 번역할 수 있는 언어. 손으로 든 목록이 아니라 시스템이 답한 것.
    @State private var translationLanguages: [Locale.Language] = []

    private var availability: AIAvailability {
        AppleIntelligenceService.shared.availability
    }

    var body: some View {
        List {
            // 사용 가능 상태
            Section {
                HStack(spacing: 12) {
                    Image(systemName: availability == .available
                          ? AppSymbol.checkmarkCircleFill
                          : AppSymbol.infoCircle)
                        .font(.title3)
                        .foregroundColor(availability == .available ? Color.checkGreen : .orange)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Apple Intelligence", comment: "AI settings status row title"))
                            .font(.body)
                        Text(availability.localizedDescription)
                            .font(.caption)
                            .foregroundColor(theme.textMuted)
                    }
                }
                .accessibilityElement(children: .combine)
            } footer: {
                Text(NSLocalizedString("모든 AI 처리는 기기 안에서만 이루어져요. 텍스트가 기기 밖으로 전송되지 않습니다.", comment: "AI on-device privacy footer"))
                    .font(.body)
            }

            // 스마트 분류
            Section {
                Toggle(isOn: $classificationEnabled) {
                    Label(NSLocalizedString("AI 스마트 분류", comment: "AI classification toggle"),
                          systemImage: AppSymbol.sparkles)
                }
                .disabled(availability != .available)
            } footer: {
                Text(NSLocalizedString("정규식으로 확신하기 어려운 클립보드 항목(주소, 이름, 송장번호 등)을 온디바이스 AI가 다시 분류해요.", comment: "AI classification footer"))
                    .font(.body)
            }

            // 붙여넣기 앱 제안
            Section {
                Toggle(isOn: $actionSuggestionsEnabled) {
                    Label(NSLocalizedString("붙여넣기 앱 제안", comment: "AI paste target suggestion toggle"),
                          systemImage: AppSymbol.wandAndSparkles)
                }
                .disabled(availability != .available)
            } footer: {
                Text(NSLocalizedString("복사한 텍스트를 어디에 붙여넣을지 예측해서 메일 쓰기, 메시지 보내기, 웹 검색 같은 단축 액션을 제안해요.", comment: "AI paste target footer"))
                    .font(.body)
            }

            // 번역 기본 언어
            //
            // ⚠️ 이 칸만 `availability` 를 안 본다. 번역은 Apple Intelligence 가 아니라
            //    `Translation` 이 하므로, 그것을 못 켜는 기기에서도 된다.
            Section {
                Picker(selection: $translationTargetLang) {
                    ForEach(translationLanguages, id: \.self) { lang in
                        Text(AppTranslation.displayName(of: lang))
                            .tag(AppTranslation.key(for: lang))
                    }
                } label: {
                    Label(NSLocalizedString("기본 번역 언어", comment: "Default translation language picker"),
                          systemImage: "translate")
                }
                .disabled(translationLanguages.isEmpty)
            } header: {
                Text(NSLocalizedString("번역", comment: "Suggested action: translate"))
            } footer: {
                Text(NSLocalizedString("클립보드 히스토리의 텍스트 항목에서 '번역' 버튼을 누르면 이 언어로 번역해요. 무료이고, 언어 자료를 한 번 받아 두면 오프라인에서도 됩니다. Apple Intelligence 를 못 켜는 기기에서도 동작해요.", comment: "AI translation footer"))
                    .font(.body)
            }
        }
        .task { translationLanguages = await AppTranslation.supportedLanguages() }
        .navigationTitle(NSLocalizedString("Apple Intelligence", comment: "AI settings status row title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .solidNavBar(theme.bg)
    }
}
