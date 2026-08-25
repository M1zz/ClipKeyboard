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
    private var translationTargetLang: String = AITranslationLanguage.systemDefault.rawValue

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
            Section {
                Picker(selection: $translationTargetLang) {
                    ForEach(AITranslationLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                } label: {
                    Label(NSLocalizedString("기본 번역 언어", comment: "Default translation language picker"),
                          systemImage: "translate")
                }
                .disabled(availability != .available)
            } header: {
                Text(NSLocalizedString("번역", comment: "Suggested action: translate"))
            } footer: {
                Text(NSLocalizedString("클립보드 히스토리의 텍스트 항목에서 '번역' 버튼을 누르면 이 언어로 번역해요. 번역은 무료이며 오프라인에서도 동작해요.", comment: "AI translation footer"))
                    .font(.body)
            }
        }
        .navigationTitle(NSLocalizedString("Apple Intelligence", comment: "AI settings status row title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .solidNavBar(theme.bg)
    }
}
