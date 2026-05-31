//
//  PersonaQuickAddView.swift
//  ClipKeyboard
//

import SwiftUI

// MARK: - Persona Quick Add (비즈니스·학생·일반 페르소나용 빠른 등록 위자드)

struct PersonaQuickAddView: View {
    let persona: Persona
    let onComplete: () -> Void

    @State private var field1Text = ""
    @State private var field2Text = ""
    @Environment(\.appTheme) private var theme

    private struct FieldConfig {
        let label1: String
        let placeholder1: String
        let label2: String
        let placeholder2: String
        let memo1Title: String
        let memo1Category: String
        let memo2Title: String
        let memo2Category: String
        let autocapitalize1: TextInputAutocapitalization
    }

    private var config: FieldConfig {
        switch persona {
        case .business:
            return FieldConfig(
                label1: NSLocalizedString("회사 이메일", comment: "Business quick add: work email label"),
                placeholder1: NSLocalizedString("예: john@company.com", comment: "Business quick add: work email placeholder"),
                label2: NSLocalizedString("회사명 (선택 사항)", comment: "Business quick add: company name label"),
                placeholder2: NSLocalizedString("예: Acme Corporation", comment: "Business quick add: company name placeholder"),
                memo1Title: NSLocalizedString("회사 이메일", comment: "Business memo title: work email"),
                memo1Category: NSLocalizedString("회사 이메일", comment: "Business memo category: work email"),
                memo2Title: NSLocalizedString("회사명", comment: "Business memo title: company name"),
                memo2Category: NSLocalizedString("명함 정보", comment: "Business memo category: business card"),
                autocapitalize1: .never
            )
        case .student:
            return FieldConfig(
                label1: NSLocalizedString("학번", comment: "Student quick add: student ID label"),
                placeholder1: NSLocalizedString("예: 2024123456", comment: "Student quick add: student ID placeholder"),
                label2: NSLocalizedString("학교 이메일 (선택 사항)", comment: "Student quick add: school email label"),
                placeholder2: NSLocalizedString("예: student@university.ac.kr", comment: "Student quick add: school email placeholder"),
                memo1Title: NSLocalizedString("학번", comment: "Student memo title: student ID"),
                memo1Category: NSLocalizedString("학번", comment: "Student memo category: student ID"),
                memo2Title: NSLocalizedString("학교 이메일", comment: "Student memo title: school email"),
                memo2Category: NSLocalizedString("학교 이메일", comment: "Student memo category: school email"),
                autocapitalize1: .never
            )
        case .general:
            return FieldConfig(
                label1: NSLocalizedString("휴대폰 번호", comment: "General quick add: phone number label"),
                placeholder1: NSLocalizedString("예: 010-1234-5678", comment: "General quick add: phone number placeholder"),
                label2: NSLocalizedString("자주 쓰는 이메일 (선택 사항)", comment: "General quick add: email label"),
                placeholder2: NSLocalizedString("예: me@email.com", comment: "General quick add: email placeholder"),
                memo1Title: NSLocalizedString("휴대폰 번호", comment: "General memo title: phone"),
                memo1Category: NSLocalizedString("전화번호", comment: "General memo category: phone"),
                memo2Title: NSLocalizedString("이메일", comment: "General memo title: email"),
                memo2Category: NSLocalizedString("이메일", comment: "General memo category: email"),
                autocapitalize1: .never
            )
        case .nomad:
            // Nomad는 NomadQuickSetupView를 사용
            return FieldConfig(
                label1: "", placeholder1: "", label2: "", placeholder2: "",
                memo1Title: "", memo1Category: "", memo2Title: "", memo2Category: "",
                autocapitalize1: .never
            )
        }
    }

    private var canRegister: Bool {
        !field1Text.trimmingCharacters(in: .whitespaces).isEmpty ||
        !field2Text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            progressHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(NSLocalizedString("첫 번째 메모를 추가해볼까요?", comment: "Persona quick add step title"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.text)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)

                    Text(NSLocalizedString("입력하지 않아도 돼요. 언제든지 앱에서 추가할 수 있어요.", comment: "Persona quick add step subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(theme.textMuted)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)

                    PersonaInputSection(
                        label: config.label1,
                        placeholder: config.placeholder1,
                        text: $field1Text,
                        autocapitalization: config.autocapitalize1
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    PersonaInputSection(
                        label: config.label2,
                        placeholder: config.placeholder2,
                        text: $field2Text,
                        autocapitalization: .never
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    Spacer(minLength: 32)

                    HStack(spacing: 12) {
                        Button {
                            onComplete()
                        } label: {
                            Text(NSLocalizedString("건너뛰기", comment: "Skip persona quick add"))
                                .font(.subheadline)
                                .foregroundStyle(theme.textMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                        }

                        Button {
                            saveAndFinish()
                        } label: {
                            Text(canRegister
                                 ? NSLocalizedString("등록하기", comment: "Register button for persona quick add")
                                 : NSLocalizedString("건너뛰기", comment: "Skip persona quick add"))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                }
                .padding(.top, 4)
            }
        }
        .background(theme.bg.ignoresSafeArea())
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(Color.accentColor)
                .frame(width: 28, height: 6)
            Spacer()
            Button(NSLocalizedString("건너뛰기", comment: "Skip persona quick add")) { onComplete() }
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Save

    private func saveAndFinish() {
        var newMemos: [Memo] = []
        let v1 = field1Text.trimmingCharacters(in: .whitespaces)
        let v2 = field2Text.trimmingCharacters(in: .whitespaces)

        if !v1.isEmpty {
            newMemos.append(Memo(title: config.memo1Title, value: v1, category: config.memo1Category))
        }
        if !v2.isEmpty {
            newMemos.append(Memo(title: config.memo2Title, value: v2, category: config.memo2Category))
        }

        if !newMemos.isEmpty {
            do {
                var existing = (try? MemoStore.shared.load(type: .memo)) ?? []
                existing.insert(contentsOf: newMemos, at: 0)
                try MemoStore.shared.save(memos: existing, type: .memo)
                ReviewManager.shared.trackClipSaved()
                print("✅ [PersonaQuickAdd] \(newMemos.count)개 메모 저장 완료 (persona=\(persona.rawValue))")
            } catch {
                print("❌ [PersonaQuickAdd] 메모 저장 실패: \(error)")
            }
        }

        onComplete()
    }
}

// MARK: - Input Field

private struct PersonaInputSection: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var autocapitalization: TextInputAutocapitalization = .never
    @FocusState private var isFocused: Bool
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.textMuted)

            TextField(placeholder, text: $text)
                .focused($isFocused)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusSm)
                        .strokeBorder(isFocused ? Color.accentColor : theme.divider, lineWidth: 1.5)
                )
        }
    }
}
