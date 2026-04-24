//
//  ComboEditSheet.swift
//  ClipKeyboard
//
//  Created by Leeo on 2/18/26.
//

import SwiftUI

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
                        .font(.callout)
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
                let memos = try MemoStore.shared.load(type: .tokenMemo)
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                .font(.system(size: 16))
                .foregroundColor(.orange)

            Text(String(format: NSLocalizedString("Combo 값 %d개", comment: "Combo value count"), comboValues.count))
                .font(.subheadline)
                .foregroundColor(theme.textMuted)

            Spacer()

            if !comboValues.isEmpty {
                Text(String(format: NSLocalizedString("다음: %d번째", comment: "Next index"), currentComboIndex + 1))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
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
                .font(.subheadline)
                .foregroundColor(theme.textMuted)

            Text(NSLocalizedString("아래에서 값을 추가하세요", comment: "Add values below"))
                .font(.caption)
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
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(index == currentComboIndex ? .white : theme.textMuted)
                        .frame(width: 28, height: 28)
                        .background(index == currentComboIndex ? Color.orange : theme.surfaceAlt)
                        .cornerRadius(14)

                    // 값
                    Text(value)
                        .font(.body)
                        .lineLimit(2)

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
                            .cornerRadius(6)
                    }
                }
                .padding(.vertical, 4)
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
            var memos = try MemoStore.shared.load(type: .tokenMemo)
            if let index = memos.firstIndex(where: { $0.id == memo.id }) {
                memos[index].comboValues = comboValues
                memos[index].currentComboIndex = currentComboIndex
                try MemoStore.shared.save(memos: memos, type: .tokenMemo)
                print("✅ [ComboEditSheet] 저장 완료 - 값 \(comboValues.count)개, 인덱스: \(currentComboIndex)")
            }
        } catch {
            print("❌ [ComboEditSheet] 저장 실패: \(error)")
        }
    }
}
