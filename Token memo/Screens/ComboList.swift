//
//  ComboList.swift
//  Token memo
//
//  Created by Claude Code on 2025-12-06.
//  Phase 2: Combo System
//

import SwiftUI

struct ComboList: View {
    @State private var combos: [Combo] = []
    @State private var showAddCombo = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var editingCombo: Combo? = nil

    var body: some View {
        NavigationStack {
            Group {
                if combos.isEmpty {
                    EmptyComboView()
                } else {
                    List {
                        ForEach(combos) { combo in
                            ComboRowView(combo: combo) {
                                // 실행
                                executeCombo(combo)
                            } onEdit: {
                                // 편집
                                editingCombo = combo
                            }
                        }
                        .onDelete(perform: deleteCombo)
                    }
                }
            }
            .navigationTitle("Combo")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            addTestData()
                        } label: {
                            Label("테스트 데이터 추가", systemImage: "wand.and.stars")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddCombo = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddCombo) {
                ComboAddEditView(combo: nil) { newCombo in
                    do {
                        try MemoStore.shared.addCombo(newCombo)
                        loadCombos()
                        showToast(message: "Combo '\(newCombo.title)' 생성됨")
                    } catch {
                        showToast(message: "저장 실패: \(error.localizedDescription)")
                    }
                }
            }
            .sheet(item: $editingCombo) { combo in
                ComboAddEditView(combo: combo) { updatedCombo in
                    do {
                        try MemoStore.shared.updateCombo(updatedCombo)
                        loadCombos()
                        showToast(message: "Combo '\(updatedCombo.title)' 수정됨")
                    } catch {
                        showToast(message: "저장 실패: \(error.localizedDescription)")
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if showToast {
                    ToastView(message: toastMessage)
                        .padding(.bottom, 50)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear {
                loadCombos()
            }
        }
    }

    private func loadCombos() {
        do {
            combos = try MemoStore.shared.loadCombos()
            // 즐겨찾기 > 최근 사용 순으로 정렬
            combos.sort { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite {
                    return lhs.isFavorite
                }
                if let lhsDate = lhs.lastUsed, let rhsDate = rhs.lastUsed {
                    return lhsDate > rhsDate
                }
                return (lhs.lastUsed != nil) && (rhs.lastUsed == nil)
            }
        } catch {
            print("❌ Combo 로드 실패: \(error)")
        }
    }

    private func deleteCombo(at offsets: IndexSet) {
        for index in offsets {
            let combo = combos[index]
            do {
                try MemoStore.shared.deleteCombo(id: combo.id)
                showToast(message: "Combo '\(combo.title)' 삭제됨")
            } catch {
                showToast(message: "삭제 실패: \(error.localizedDescription)")
            }
        }
        combos.remove(atOffsets: offsets)
    }

    private func executeCombo(_ combo: Combo) {
        ComboExecutionService.shared.startCombo(combo)
        showToast(message: "Combo '\(combo.title)' 실행 중... (\(combo.items.count)개 항목, \(Int(combo.interval))초 간격)")
    }

    private func showToast(message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }

    private func addTestData() {
        // 테스트 시나리오 1: 회원가입 정보
        let signupData = [
            "홍길동",
            "hong@example.com",
            "010-1234-5678",
            "06234",
            "서울특별시 강남구 테헤란로 123"
        ]

        // 테스트 시나리오 2: 배송 정보
        let shippingData = [
            "김철수",
            "010-9876-5432",
            "13579",
            "부산광역시 해운대구 해운대로 456",
            "문 앞에 놓아주세요"
        ]

        // 클립보드 히스토리에 추가
        do {
            var allItems: [ComboItem] = []
            var order = 0

            // 회원가입 데이터 추가
            for data in signupData {
                try MemoStore.shared.addToSmartClipboardHistory(content: data)
                let history = try MemoStore.shared.loadSmartClipboardHistory()
                if let item = history.first(where: { $0.content == data }) {
                    let comboItem = ComboItem(
                        type: .clipboardHistory,
                        referenceId: item.id,
                        order: order,
                        displayTitle: String(data.prefix(20)),
                        displayValue: data
                    )
                    allItems.append(comboItem)
                    order += 1
                }
            }

            // 회원가입 Combo 생성
            let signupCombo = Combo(
                title: "회원가입 정보",
                items: allItems,
                interval: 2.0
            )
            try MemoStore.shared.addCombo(signupCombo)

            // 배송 정보 추가
            allItems = []
            order = 0
            for data in shippingData {
                try MemoStore.shared.addToSmartClipboardHistory(content: data)
                let history = try MemoStore.shared.loadSmartClipboardHistory()
                if let item = history.first(where: { $0.content == data }) {
                    let comboItem = ComboItem(
                        type: .clipboardHistory,
                        referenceId: item.id,
                        order: order,
                        displayTitle: String(data.prefix(20)),
                        displayValue: data
                    )
                    allItems.append(comboItem)
                    order += 1
                }
            }

            // 배송 정보 Combo 생성
            let shippingCombo = Combo(
                title: "배송 정보",
                items: allItems,
                interval: 2.0
            )
            try MemoStore.shared.addCombo(shippingCombo)

            loadCombos()
            showToast(message: "✨ 테스트 데이터 추가 완료! (2개 Combo, 10개 항목)")
        } catch {
            showToast(message: "❌ 테스트 데이터 추가 실패: \(error.localizedDescription)")
        }
    }
}

// MARK: - Empty View

struct EmptyComboView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.2.circlepath.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            Text("Combo가 없습니다")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Text("여러 메모를 순서대로 자동 입력하는\nCombo를 만들어보세요")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Combo Row

struct ComboRowView: View {
    let combo: Combo
    let onExecute: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // 타이틀
                    Text(combo.title)
                        .font(.headline)

                    Spacer()

                    // 즐겨찾기
                    if combo.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }

                    // 실행 버튼
                    Button(action: onExecute) {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // 항목 수 및 간격 정보
                HStack(spacing: 12) {
                    Label("\(combo.items.count)개 항목", systemImage: "list.bullet")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label("\(Int(combo.interval))초 간격", systemImage: "timer")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if combo.useCount > 0 {
                        Label("\(combo.useCount)회 사용", systemImage: "chart.bar.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // 항목 미리보기 (최대 3개)
                if !combo.items.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(combo.items.prefix(3)) { item in
                            ComboItemChip(item: item)
                        }

                        if combo.items.count > 3 {
                            Text("+\(combo.items.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Combo Item Chip

struct ComboItemChip: View {
    let item: ComboItem

    var iconName: String {
        switch item.type {
        case .memo:
            return "doc.text"
        case .clipboardHistory:
            return "doc.on.clipboard"
        case .template:
            return "doc.text.fill"
        }
    }

    var colorName: Color {
        switch item.type {
        case .memo:
            return .blue
        case .clipboardHistory:
            return .green
        case .template:
            return .purple
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: iconName)
                .font(.caption2)
            Text(item.type.localizedName)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(colorName.opacity(0.2))
        .foregroundColor(colorName)
        .cornerRadius(4)
    }
}

// MARK: - Toast View

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.body)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.8))
            .cornerRadius(10)
    }
}

// MARK: - Add/Edit View (Placeholder)

struct ComboAddEditView: View {
    let combo: Combo?
    let onSave: (Combo) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var title: String = ""
    @State private var interval: TimeInterval = 2.0
    @State private var selectedItems: [ComboItem] = []
    @State private var isFavorite: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("Combo 이름", text: $title)

                    HStack {
                        Text("간격")
                        Spacer()
                        Picker("", selection: $interval) {
                            Text("1초").tag(1.0)
                            Text("2초").tag(2.0)
                            Text("3초").tag(3.0)
                            Text("5초").tag(5.0)
                        }
                        .pickerStyle(.menu)
                    }

                    Toggle("즐겨찾기", isOn: $isFavorite)
                }

                Section("항목 (\(selectedItems.count)개)") {
                    if selectedItems.isEmpty {
                        Text("항목을 추가해주세요")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(selectedItems) { item in
                            HStack {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(.gray)
                                ComboItemChip(item: item)
                                Spacer()
                                if let title = item.displayTitle {
                                    Text(title)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }

                    // TODO: 항목 추가 버튼
                    Button("항목 추가") {
                        // TODO: 항목 선택 화면으로 이동
                    }
                }
            }
            .navigationTitle(combo == nil ? "Combo 추가" : "Combo 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveCombo()
                    }
                    .disabled(title.isEmpty || selectedItems.isEmpty)
                }
            }
            .onAppear {
                if let combo = combo {
                    title = combo.title
                    interval = combo.interval
                    selectedItems = combo.items
                    isFavorite = combo.isFavorite
                }
            }
        }
    }

    private func saveCombo() {
        let newCombo = Combo(
            id: combo?.id ?? UUID(),
            title: title,
            items: selectedItems,
            interval: interval,
            isFavorite: isFavorite
        )
        onSave(newCombo)
        dismiss()
    }
}

#Preview {
    ComboList()
}
