//
//  NomadQuickSetupView.swift
//  ClipKeyboard
//

import SwiftUI

// MARK: - Focus Type

enum NomadFocus: CaseIterable {
    case transfer, travel, identity, all

    var icon: String {
        switch self {
        case .transfer: return "🏦"
        case .travel:   return "🛂"
        case .identity: return "🪪"
        case .all:      return "🌐"
        }
    }

    var title: String {
        switch self {
        case .transfer: return NSLocalizedString("국제 송금", comment: "Nomad focus: wire transfer")
        case .travel:   return NSLocalizedString("비자·여행", comment: "Nomad focus: visa & travel")
        case .identity: return NSLocalizedString("신원 확인", comment: "Nomad focus: identity")
        case .all:      return NSLocalizedString("전부 다", comment: "Nomad focus: all types")
        }
    }

    var subtitle: String {
        switch self {
        case .transfer: return "IBAN, SWIFT/BIC"
        case .travel:   return NSLocalizedString("여권번호, 비자", comment: "Nomad focus subtitle: travel")
        case .identity: return NSLocalizedString("여권번호, ID 번호", comment: "Nomad focus subtitle: identity")
        case .all:      return NSLocalizedString("송금·여행·신원 모두", comment: "Nomad focus subtitle: all")
        }
    }

    var showIBANFirst: Bool { self == .transfer }
}

// MARK: - Main View

struct NomadQuickSetupView: View {
    let onComplete: () -> Void

    @State private var step = 1
    @State private var selectedFocus: NomadFocus = .all
    @State private var ibanText = ""
    @State private var passportText = ""
    @Environment(\.appTheme) private var theme

    private var canRegister: Bool {
        !ibanText.trimmingCharacters(in: .whitespaces).isEmpty ||
        !passportText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
            Group {
                if step == 1 { step1View }
                else { step2View }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            ))
        }
        .animation(.easeInOut(duration: 0.25), value: step)
        .background(theme.bg.ignoresSafeArea())
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        HStack(spacing: 6) {
            ForEach([1, 2], id: \.self) { idx in
                Capsule()
                    .fill(idx <= step ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: idx == step ? 28 : 8, height: 6)
            }
            Spacer()
            Button(NSLocalizedString("건너뛰기", comment: "Skip nomad wizard")) { onComplete() }
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .animation(.spring(response: 0.3), value: step)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Step 1: Focus Selection

    private var step1View: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("무엇을 가장 자주 입력하나요?", comment: "Nomad wizard step 1 title"))
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.text)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

            Text(NSLocalizedString("자주 쓰는 정보를 먼저 등록해드릴게요.", comment: "Nomad wizard step 1 subtitle"))
                .font(.subheadline)
                .foregroundStyle(theme.textMuted)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(NomadFocus.allCases, id: \.self) { focus in
                    NomadFocusCard(focus: focus, isSelected: selectedFocus == focus) {
                        withAnimation(.spring(response: 0.2)) { selectedFocus = focus }
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Button {
                step = 2
            } label: {
                Text(NSLocalizedString("다음", comment: "Next step button"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
    }

    // MARK: - Step 2: Info Input

    private var step2View: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(NSLocalizedString("첫 번째 메모를 추가해볼까요?", comment: "Nomad wizard step 2 title"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.text)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)

                Text(NSLocalizedString("입력하지 않아도 돼요. 언제든지 앱에서 추가할 수 있어요.", comment: "Nomad wizard step 2 subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(theme.textMuted)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)

                if selectedFocus.showIBANFirst {
                    ibanInputField
                    passportInputField
                } else {
                    passportInputField
                    ibanInputField
                }

                Spacer(minLength: 32)

                HStack(spacing: 12) {
                    Button {
                        onComplete()
                    } label: {
                        Text(NSLocalizedString("건너뛰기", comment: "Skip nomad wizard"))
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
                             ? NSLocalizedString("등록하기", comment: "Register button for nomad setup")
                             : NSLocalizedString("건너뛰기", comment: "Skip nomad wizard"))
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

    private var ibanInputField: some View {
        NomadInputSection(
            label: NSLocalizedString("IBAN (선택 사항)", comment: "IBAN input label"),
            placeholder: NSLocalizedString("예: DE89 3704 0044 0532 0130 00", comment: "IBAN placeholder"),
            text: $ibanText
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var passportInputField: some View {
        NomadInputSection(
            label: NSLocalizedString("여권번호 (선택 사항)", comment: "Passport number input label"),
            placeholder: NSLocalizedString("예: M12345678", comment: "Passport number placeholder"),
            text: $passportText
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Save

    private func saveAndFinish() {
        var newMemos: [Memo] = []

        let iban = ibanText.trimmingCharacters(in: .whitespaces)
        let passport = passportText.trimmingCharacters(in: .whitespaces)

        if !iban.isEmpty {
            newMemos.append(Memo(title: "IBAN", value: iban, category: "IBAN"))
        }
        if !passport.isEmpty {
            newMemos.append(Memo(
                title: NSLocalizedString("여권번호", comment: "Passport memo title"),
                value: passport,
                category: NSLocalizedString("여권번호", comment: "Passport category name")
            ))
        }

        if !newMemos.isEmpty {
            do {
                var existing = (try? MemoStore.shared.load(type: .memo)) ?? []
                existing.insert(contentsOf: newMemos, at: 0)
                try MemoStore.shared.save(memos: existing, type: .memo)
                ReviewManager.shared.trackClipSaved()
                print("✅ [NomadQuickSetup] \(newMemos.count)개 메모 저장 완료")
            } catch {
                print("❌ [NomadQuickSetup] 메모 저장 실패: \(error)")
            }
        }

        onComplete()
    }
}

// MARK: - Focus Card

private struct NomadFocusCard: View {
    let focus: NomadFocus
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(focus.icon)
                    .font(.largeTitle)
                Text(focus.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : theme.text)
                    .multilineTextAlignment(.center)
                Text(focus.subtitle)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color.accentColor.opacity(0.8) : theme.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusMd)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusMd)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Input Field

private struct NomadInputSection: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.textMuted)

            TextField(placeholder, text: $text)
                .focused($isFocused)
                .textInputAutocapitalization(.characters)
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
