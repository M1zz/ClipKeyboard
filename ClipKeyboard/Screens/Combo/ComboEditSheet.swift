//
//  ComboEditSheet.swift
//  ClipKeyboard
//
//  Created by Leeo on 2/18/26.
//

import SwiftUI
import TipKit

// MARK: - Combo Sheet Resolver

struct ComboSheetResolver: View {
    let comboId: UUID
    let allMemos: [Memo]
    let onDismiss: () -> Void
    @Environment(\.appTheme) private var theme

    @State private var loadedMemo: Memo? = nil
    @State private var isLoading: Bool = false

    var body: some View {
        Group {
            if let memo = loadedMemo {
                ComboEditSheet(memo: memo, onDismiss: onDismiss)
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)

                    Text(NSLocalizedString("불러오는 중...", comment: "Loading"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.bg)
            }
        }
        .onAppear {
            print("🎬 [ComboSheetResolver] onAppear - ID: \(comboId)")
            loadMemo()
        }
    }

    private func loadMemo() {
        guard !isLoading else { return }
        isLoading = true

        // 1. 메모리에서 찾기
        if let memo = allMemos.first(where: { $0.id == comboId }) {
            print("✅ [ComboSheetResolver] 메모리에서 찾음: \(memo.title)")
            loadedMemo = memo
            isLoading = false
            return
        }

        // 2. 파일에서 로드
        print("🔍 [ComboSheetResolver] 메모리에 없음 - 파일에서 로드")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let memos = try MemoStore.shared.load(type: .memo)
                if let memo = memos.first(where: { $0.id == comboId }) {
                    DispatchQueue.main.async {
                        print("✅ [ComboSheetResolver] 파일에서 찾음: \(memo.title)")
                        loadedMemo = memo
                        isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        print("❌ [ComboSheetResolver] 메모를 찾을 수 없음")
                        isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print("❌ [ComboSheetResolver] 로드 실패: \(error)")
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Combo Edit Sheet

struct ComboEditSheet: View {
    let memo: Memo
    let onDismiss: () -> Void
    @Environment(\.appTheme) private var theme

    @State private var comboValues: [String] = []
    @State private var currentComboIndex: Int = 0
    @State private var newValueText: String = ""
    /// 연습 미리보기에 쌓인 출력 (실제 입력처럼 시뮬레이션)
    @State private var practiceOutput: String = ""
    /// 연습 영역 펼침 여부 — 기본 접힘(화면 답답함 해소, 고정 노출 안 함)
    @State private var showPractice: Bool = false

    private let comboInfoTip = ComboInfoTip()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 안내·헤더·값·연습을 모두 하나의 스크롤로 — 고정하지 않고 상하로 흐른다.
                List {
                    // 콤보 동작 안내 — 고정하지 않고 함께 스크롤되어 내려간다.
                    TipView(comboInfoTip)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    // 헤더 정보
                    headerSection
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    if comboValues.isEmpty {
                        emptyStateView
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        // 값 목록 (드래그 재정렬 + 스와이프 삭제)
                        comboValueRows

                        // 연습 — 값 아래에 이어서, 함께 스크롤된다.
                        practiceSection
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
                .scrollContentBackground(.hidden)
                .background(theme.bg)

                Divider()

                // 하단 입력 영역 (입력 바만 고정)
                addValueSection
            }
            .navigationTitle(memo.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbarBackground(theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("닫기", comment: "Close")) {
                        onDismiss()
                    }
                }

            }
            .onAppear {
                comboValues = memo.comboValues
                currentComboIndex = memo.currentComboIndex
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Image(systemName: "repeat")
                .font(.body)
                .foregroundColor(.orange)

            Text(String(format: NSLocalizedString("Combo 값 %d개", comment: "Combo value count"), comboValues.count))
                .font(.body)
                .foregroundColor(theme.textMuted)

            Spacer()

            if !comboValues.isEmpty {
                Text(String(format: NSLocalizedString("다음: %d번째", comment: "Next index"), currentComboIndex + 1))
                    .font(.body)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(theme.radiusSm)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))

            Text(NSLocalizedString("값이 없습니다", comment: "No values"))
                .font(.body)
                .foregroundColor(theme.textMuted)

            Text(NSLocalizedString("아래에서 값을 추가하세요", comment: "Add values below"))
                .font(.body)
                .foregroundColor(theme.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Value List

    private var comboValueRows: some View {
        ForEach(Array(comboValues.enumerated()), id: \.offset) { index, value in
                HStack(spacing: 12) {
                    // 번호
                    Text("\(index + 1)")
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundColor(index == currentComboIndex ? .white : theme.textMuted)
                        .frame(width: 28, height: 28)
                        .background(index == currentComboIndex ? Color.orange : theme.surfaceAlt)
                        .cornerRadius(theme.radiusMd)
                        .accessibilityHidden(true)

                    // 값
                    Text(value)
                        .font(.body)
                        .lineLimit(3)

                    Spacer()

                    // "다음" 배지
                    if index == currentComboIndex {
                        Text(NSLocalizedString("다음", comment: "Next badge"))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(theme.radiusXs)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    index == currentComboIndex
                        ? String(format: NSLocalizedString("%d번, %@, 다음 예정", comment: "Combo row: next"), index + 1, value)
                        : String(format: NSLocalizedString("%d번, %@", comment: "Combo row"), index + 1, value)
                )
                // 스위치 컨트롤: 드래그 재정렬 불가 → 커스텀 액션으로 이동/삭제 제공
                .accessibilityAction(named: NSLocalizedString("위로 이동", comment: "Move combo value up")) {
                    guard index > 0 else { return }
                    moveValues(from: IndexSet([index]), to: index - 1)
                }
                .accessibilityAction(named: NSLocalizedString("아래로 이동", comment: "Move combo value down")) {
                    guard index < comboValues.count - 1 else { return }
                    moveValues(from: IndexSet([index]), to: index + 2)
                }
                .accessibilityAction(named: NSLocalizedString("삭제", comment: "Delete combo value")) {
                    deleteValues(at: IndexSet([index]))
                }
            }
        .onDelete(perform: deleteValues)
        .onMove(perform: moveValues)
    }

    // MARK: - Practice Section

    /// "다음 값 입력"을 누르면 Next 표시된 값이 미리보기에 쌓이고 Next가 다음으로 이동한다.
    /// 사용자가 Combo가 실제로 어떻게 순서대로 입력되는지 직접 체험하게 한다.
    private var practiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 접기/펼치기 헤더 — 평소엔 접혀 있어 공간을 차지하지 않는다.
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showPractice.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Label(NSLocalizedString("연습", comment: "Practice section label"), systemImage: "play.circle.fill")
                            .font(.body.weight(.semibold))
                            .foregroundColor(theme.textMuted)
                        Image(systemName: showPractice ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(theme.textFaint)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint(NSLocalizedString("콤보가 순서대로 입력되는 흐름을 연습해 봅니다", comment: "Practice disclosure hint"))
                Spacer()
                if showPractice, !practiceOutput.isEmpty {
                    Button { practiceReset() } label: {
                        Label(NSLocalizedString("처음으로", comment: "Reset practice"), systemImage: "arrow.counterclockwise")
                            .font(.body)
                            .foregroundColor(.orange)
                    }
                    .accessibilityHint(NSLocalizedString("연습을 처음부터 다시 시작합니다", comment: "Reset practice hint"))
                }
            }

            if showPractice {
            // 미리보기 — 입력된 값이 순서대로 쌓인다
            ScrollView {
                Text(practiceOutput.isEmpty
                     ? NSLocalizedString("아래 버튼을 누르면 Combo 값이 순서대로 입력되는 걸 볼 수 있어요", comment: "Practice preview placeholder")
                     : practiceOutput)
                    .font(.body)
                    .foregroundColor(practiceOutput.isEmpty ? theme.textMuted : theme.text)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(height: 64)
            .padding(12)
            .background(theme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))

            // "다음 값 입력" — Next 표시된 값을 미리보기에 추가하고 Next를 다음으로 이동
            Button { insertNext() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.to.line")
                    Text(NSLocalizedString("다음 값 입력", comment: "Insert next combo value (practice)"))
                    Spacer()
                    if currentComboIndex < comboValues.count {
                        Text(comboValues[currentComboIndex])
                            .lineLimit(1)
                            .opacity(0.85)
                    }
                }
                .font(.body.weight(.semibold))
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
            }
            .accessibilityLabel(NSLocalizedString("다음 값 입력", comment: "Insert next combo value (practice)"))
            .accessibilityHint(NSLocalizedString("Next로 표시된 값을 미리보기에 추가하고 다음 값으로 넘어갑니다", comment: "Insert next practice hint"))
            }   // if showPractice
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Add Value Section

    private var addValueSection: some View {
        HStack(spacing: 10) {
            TextField(NSLocalizedString("새 값 입력", comment: "New value input"), text: $newValueText)
                .clipRoundedField()
                .submitLabel(.done)
                .onSubmit {
                    addValue()
                }

            Button {
                addValue()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(.title))
                    .foregroundColor(newValueText.isEmpty ? .gray : .orange)
            }
            .disabled(newValueText.isEmpty)
            .accessibilityLabel(NSLocalizedString("값 추가", comment: "Add combo value button"))
            .accessibilityHint(NSLocalizedString("입력한 값을 Combo 목록에 추가합니다", comment: "Add combo value hint"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func addValue() {
        let trimmed = newValueText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        comboValues.append(trimmed)
        newValueText = ""
        saveChanges()
    }

    private func deleteValues(at offsets: IndexSet) {
        // 삭제되는 인덱스가 currentComboIndex에 영향을 주는지 확인
        let deletedIndices = Array(offsets)
        comboValues.remove(atOffsets: offsets)

        // currentComboIndex 조정
        if comboValues.isEmpty {
            currentComboIndex = 0
        } else {
            // 삭제된 인덱스 중 현재 인덱스보다 작은 것의 개수만큼 감소
            let smallerCount = deletedIndices.filter { $0 < currentComboIndex }.count
            currentComboIndex = max(0, currentComboIndex - smallerCount)

            if currentComboIndex >= comboValues.count {
                currentComboIndex = 0
            }
        }

        saveChanges()
    }

    private func moveValues(from source: IndexSet, to destination: Int) {
        // 이동 전 현재 인덱스의 값을 기억
        let currentValue = currentComboIndex < comboValues.count ? comboValues[currentComboIndex] : nil

        comboValues.move(fromOffsets: source, toOffset: destination)

        // 이동 후 기억한 값의 새 인덱스를 찾아 currentComboIndex 업데이트
        if let currentValue = currentValue,
           let newIndex = comboValues.firstIndex(of: currentValue) {
            currentComboIndex = newIndex
        }

        saveChanges()
    }

    /// 연습: Next로 표시된 값을 미리보기에 추가하고 Next를 다음으로 이동(끝이면 처음으로 순환).
    private func insertNext() {
        guard !comboValues.isEmpty else { return }
        let idx = currentComboIndex < comboValues.count ? currentComboIndex : 0
        // 실제 콤보 입력처럼 옆으로 이어 붙인다(개행 없이) — 텍스트필드에 타이핑하듯.
        practiceOutput += comboValues[idx]
        currentComboIndex = (idx + 1) % comboValues.count
        saveChanges()
        HapticManager.shared.selection()
    }

    /// 연습 초기화: 미리보기를 비우고 Next를 첫 값으로 되돌린다.
    private func practiceReset() {
        practiceOutput = ""
        currentComboIndex = 0
        saveChanges()
        HapticManager.shared.light()
    }

    private func saveChanges() {
        do {
            var memos = try MemoStore.shared.load(type: .memo)
            if let index = memos.firstIndex(where: { $0.id == memo.id }) {
                memos[index].comboValues = comboValues
                memos[index].currentComboIndex = currentComboIndex
                try MemoStore.shared.save(memos: memos, type: .memo)
                print("✅ [ComboEditSheet] 저장 완료 - 값 \(comboValues.count)개, 인덱스: \(currentComboIndex)")
            }
        } catch {
            print("❌ [ComboEditSheet] 저장 실패: \(error)")
        }
    }
}
