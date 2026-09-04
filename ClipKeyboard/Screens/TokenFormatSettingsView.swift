//
//  TokenFormatSettingsView.swift
//  ClipKeyboard
//
//  `{날짜}` · `{시간}` 을 어떤 모양으로 넣을지 고르는 화면.
//
//  왜 고르는 목록만으로 모자란가: 준비해 둔 대여섯 가지로 세상이 날짜를 적는 법을 다 덮을 수
//  없다. "8월 31일 (월)" 이나 "31.08.26" 으로 쓰고 싶은 사람은 늘 있고, 그 사람은 넣어 준
//  날짜를 매번 손으로 고쳐 써 왔다. 날짜를 넣어 주는 기능인데 그러면 넣어 주나 마나다.
//
//  ⚠️ 사용자에게 "ICU 패턴을 적으세요" 라고 하면 아무도 못 적는다. 그래서 이 화면은
//     조각을 눌러 넣게 하고, 적는 동안 **오늘 날짜를 그 모양으로 계속 그려서** 보여준다.
//     패턴 글자("MM/dd/yyyy")는 개발자만 읽는다. 08/31/2026 은 누구나 읽는다.
//
//  ⚠️ 고른 값과 만든 서식은 App Group 에 적힌다. 표준 UserDefaults 에 적으면
//     **키보드 익스텐션은 영영 못 본다** - `{날짜}` 를 실제로 넣는 자리가 거기다.
//

import SwiftUI

// MARK: - 고르는 화면

struct TokenFormatSettingsView<Format: TokenFormat>: View {

    private let title: String
    private let chips: [TokenFormatField.Chip]

    /// 고른 값. 준비된 보기면 rawValue, 만든 서식이면 `custom:` + 패턴.
    @AppStorage private var raw: String
    /// 만든 서식들. 화면에서 더하고 지우므로 `@State` 로 들고 다시 그린다.
    @State private var customs: [String]
    @State private var showEditor = false

    @Environment(\.appTheme) private var theme

    init(title: String, chips: [TokenFormatField.Chip], of format: Format.Type) {
        self.title = title
        self.chips = chips
        _raw = AppStorage(wrappedValue: Format.automaticCase.rawValue,
                          Format.storageKey,
                          store: AppGroup.defaults)
        _customs = State(initialValue: Format.customPatterns)
    }

    var body: some View {
        List {
            Section {
                ForEach(Array(Format.allCases)) { format in
                    row(TokenFormatOption<Format>(builtin: format))
                }
            } header: {
                Text(NSLocalizedString("준비된 모양", comment: "Token format section: built-in formats"))
            }

            Section {
                ForEach(customs, id: \.self) { pattern in
                    row(TokenFormatOption<Format>(customPattern: pattern))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                remove(pattern)
                            } label: {
                                Label(NSLocalizedString("삭제", comment: "Delete"), systemImage: AppSymbol.trash)
                            }
                        }
                }
                if customs.count < Format.maxCustomPatterns {
                    Button {
                        showEditor = true
                    } label: {
                        Label(NSLocalizedString("내 모양 만들기", comment: "Add a custom token format"),
                              systemImage: AppSymbol.plusCircle)
                    }
                }
            } header: {
                Text(NSLocalizedString("내가 만든 모양", comment: "Token format section: custom formats"))
            } footer: {
                Text(customs.isEmpty
                     ? NSLocalizedString("원하는 모양이 없으면 직접 만들 수 있어요. 만든 모양은 키보드에서도 그대로 쓰입니다.",
                                         comment: "Custom token format footer, empty state")
                     : NSLocalizedString("왼쪽으로 밀면 지울 수 있어요.",
                                         comment: "Custom token format footer, swipe to delete"))
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditor) {
            TokenFormatEditor<Format>(chips: chips) { pattern in
                guard Format.addCustomPattern(pattern) else { return }
                customs = Format.customPatterns
                raw = TokenFormatOption<Format>(customPattern: pattern).raw   // 만들자마자 그것으로
            }
        }
    }

    // MARK: - 한 줄

    /// 보기 하나. **오늘을 그 모양으로 그려서** 이름 자리에 놓는다.
    private func row(_ option: TokenFormatOption<Format>) -> some View {
        Button {
            raw = option.raw
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.sampleText())
                        .foregroundColor(theme.text)
                    if let pattern = option.customPattern {
                        Text(pattern)
                            .font(.caption)
                            .foregroundColor(theme.textMuted)
                    }
                }
                Spacer(minLength: 0)
                if option.raw == raw {
                    Image(systemName: AppSymbol.checkmark)
                        .foregroundColor(theme.accent)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(option.raw == raw ? [.isSelected] : [])
    }

    private func remove(_ pattern: String) {
        Format.removeCustomPattern(pattern)
        customs = Format.customPatterns
        raw = Format.selection.raw   // 지운 것이 고른 것이었으면 자동으로 돌아온다
    }
}

// MARK: - 만드는 화면

/// 서식을 직접 만든다. 적는 동안 결과가 위에서 계속 바뀐다.
private struct TokenFormatEditor<Format: TokenFormat>: View {

    let chips: [TokenFormatField.Chip]
    /// 쓸 만한 패턴이 만들어졌을 때만 불린다.
    var onSave: (String) -> Void

    @State private var pattern = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    private var isValid: Bool { Format.isValidPattern(pattern) }

    private var preview: String {
        let clean = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return "" }
        return TokenFormatOption<Format>(customPattern: clean).string(from: Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                // 결과가 먼저다. 패턴 글자가 아니라 이것을 보고 만든다.
                Section {
                    Text(preview.isEmpty
                         ? NSLocalizedString("아래에서 조각을 눌러 보세요", comment: "Token format editor: empty preview hint")
                         : preview)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(preview.isEmpty ? theme.textMuted : theme.accent)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        .accessibilityLabel(preview.isEmpty
                                            ? NSLocalizedString("아래에서 조각을 눌러 보세요", comment: "Token format editor: empty preview hint")
                                            : String(format: NSLocalizedString("미리보기 %@", comment: "Token format editor: preview label"), preview))
                }

                Section {
                    TextField(NSLocalizedString("예: yyyy년 M월 d일", comment: "Token format editor: pattern field placeholder. Keep the ICU pattern letters (yyyy, M, d) exactly as they are, they are code, not words"),
                              text: $pattern)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !pattern.isEmpty && !isValid {
                        Label(NSLocalizedString("날짜나 시각 조각이 하나는 들어가야 해요", comment: "Token format editor: invalid pattern hint"),
                              systemImage: AppSymbol.xmarkCircle)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } header: {
                    Text(NSLocalizedString("서식", comment: "Token format editor: pattern section"))
                }

                Section {
                    chipGrid(chips.map { ($0.pattern, "\($0.label) \(sample(of: $0.pattern))") })
                } header: {
                    Text(NSLocalizedString("조각", comment: "Token format editor: field chips section"))
                }

                Section {
                    chipGrid(TokenFormatField.separators.map { ($0, $0 == " " ? "␣" : $0) })
                } header: {
                    Text(NSLocalizedString("사이 글자", comment: "Token format editor: separator chips section"))
                }
            }
            .navigationTitle(NSLocalizedString("내 모양 만들기", comment: "Add a custom token format"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("취소", comment: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("저장", comment: "Save")) {
                        onSave(pattern.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    /// 조각 하나가 오늘 무엇으로 찍히는지. "연도 2026" 처럼 보여주려고 쓴다.
    private func sample(of pattern: String) -> String {
        TokenFormatOption<Format>(customPattern: pattern).string(from: Date())
    }

    private func chipGrid(_ items: [(pattern: String, label: String)]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.pattern) { item in
                    Button {
                        pattern += item.pattern
                    } label: {
                        Text(item.label)
                            .font(.callout)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(theme.accentSoft)
                            .foregroundColor(theme.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
