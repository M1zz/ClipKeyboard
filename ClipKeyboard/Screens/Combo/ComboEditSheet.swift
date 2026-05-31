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

    private let comboInfoTip = ComboInfoTip()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 콤보를 탭해 처음 열었을 때 동작 방식 안내
                TipView(comboInfoTip)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // 헤더 정보
                headerSection

                Divider()

                // 값 목록
                if comboValues.isEmpty {
                    emptyStateView
                } else {
                    valueListSection
                }

                Divider()

                // 하단 입력 영역
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

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        resetIndex()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .accessibilityLabel(NSLocalizedString("순서 초기화", comment: "Reset combo index button"))
                    .accessibilityHint(NSLocalizedString("다음 항목을 첫 번째로 재설정합니다", comment: "Reset combo index hint"))
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

    private var valueListSection: some View {
        List {
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
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Add Value Section

    private var addValueSection: some View {
        HStack(spacing: 10) {
            TextField(NSLocalizedString("새 값 입력", comment: "New value input"), text: $newValueText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit {
                    addValue()
                }

            Button {
                addValue()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
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

    private func resetIndex() {
        currentComboIndex = 0
        saveChanges()
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
