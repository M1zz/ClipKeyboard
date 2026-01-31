//
//  KeyboardView.swift
//  TokenKeyboard
//
//  Created by hyunho lee on 2023/10/03.
//

import SwiftUI
import UIKit

var showOnlyTemplates: Bool = false
var showOnlyFavorites: Bool = false
var selectedTheme: String? = nil  // 선택된 테마 필터

// 미리 정의된 값들 저장소 - 새로운 구조 사용
class PredefinedValuesStore {
    static let shared = PredefinedValuesStore()

    // PlaceholderValue 모델 (키보드 전용 - 메인 앱의 PlaceholderValue와 같은 구조)
    private struct KeyboardPlaceholderValue: Codable {
        var id: UUID
        var value: String
        var sourceMemoId: UUID
        var sourceMemoTitle: String
        var addedAt: Date
    }

    // UserDefaults에서 불러오기 (새로운 구조)
    func getValues(for placeholder: String) -> [String] {
        print("🔍 [PredefinedValuesStore] getValues 호출 - placeholder: \(placeholder)")
        let key = "placeholder_values_\(placeholder)"
        print("   Key: \(key)")

        // 새로운 형식으로 로드 시도
        if let data = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.data(forKey: key) {
            print("   ✅ 데이터 발견 - 크기: \(data.count) bytes")

            if let placeholderValues = try? JSONDecoder().decode([KeyboardPlaceholderValue].self, from: data) {
                let values = placeholderValues.map { $0.value }
                print("   ✅ 디코딩 성공 - \(values.count)개 값: \(values)")
                return values
            } else {
                print("   ❌ 디코딩 실패")
            }
        } else {
            print("   ⚠️ 새 형식 데이터 없음")
        }

        // 이전 형식 호환성 (마이그레이션)
        let oldKey = "predefined_\(placeholder)"
        print("   🔄 이전 형식 시도 - Key: \(oldKey)")

        if let saved = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?.stringArray(forKey: oldKey) {
            print("   ✅ 이전 형식에서 로드 - \(saved.count)개 값: \(saved)")
            return saved
        } else {
            print("   ⚠️ 이전 형식 데이터도 없음")
        }

        // 데이터가 없으면 빈 배열 반환
        print("   📭 데이터 없음 - 빈 배열 반환")
        return []
    }

    // 특정 템플릿에서 사용하는 값만 필터링
    func getValuesForTemplate(placeholder: String, templateId: UUID?) -> [String] {
        print("\n🔍 [PredefinedValuesStore] getValuesForTemplate 호출")
        print("   플레이스홀더: \(placeholder)")
        print("   템플릿 ID: \(templateId?.uuidString ?? "nil")")

        // clipMemos 배열 상태 확인
        print("   📚 clipMemos 배열: \(clipMemos.count)개")
        for (index, memo) in clipMemos.enumerated() {
            print("      [\(index)] ID: \(memo.id.uuidString)")
            print("          제목: \(memo.title)")
            print("          플레이스홀더 값 개수: \(memo.placeholderValues.count)")
            if !memo.placeholderValues.isEmpty {
                for (key, vals) in memo.placeholderValues {
                    print("              \(key): \(vals)")
                }
            }
        }

        // 먼저 Memo 객체에서 직접 가져오기 시도
        if let templateId = templateId {
            print("   🔎 템플릿 ID로 검색 중: \(templateId.uuidString)")

            if let memo = clipMemos.first(where: { $0.id == templateId }) {
                print("   ✅ Memo 객체에서 찾음: \(memo.title)")
                print("      Memo의 모든 플레이스홀더 값: \(memo.placeholderValues)")

                if let values = memo.placeholderValues[placeholder], !values.isEmpty {
                    print("   ✅ Memo에 저장된 값 발견: \(values)")
                    return values
                } else {
                    print("   ⚠️ Memo에 '\(placeholder)' 값 없음")
                    print("      사용 가능한 키: \(memo.placeholderValues.keys)")
                }
            } else {
                print("   ❌ templateId로 Memo를 찾을 수 없음!")
                print("      검색한 ID: \(templateId.uuidString)")
                print("      clipMemos의 ID들:")
                for memo in clipMemos {
                    print("         - \(memo.id.uuidString) (\(memo.title))")
                }
            }
        } else {
            print("   ⚠️ templateId가 nil입니다")
        }

        // Memo에 없으면 UserDefaults 확인 (기존 로직)
        let key = "placeholder_values_\(placeholder)"
        print("   🔍 UserDefaults 확인 - Key: \(key)")

        if let userDefaults = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo"),
           let data = userDefaults.data(forKey: key),
           let placeholderValues = try? JSONDecoder().decode([KeyboardPlaceholderValue].self, from: data) {
            print("   ✅ UserDefaults에서 디코딩 성공 - 총 \(placeholderValues.count)개")

            // 템플릿 ID로 필터링
            if let templateId = templateId {
                let filtered = placeholderValues.filter { $0.sourceMemoId == templateId }
                print("   📊 템플릿 ID로 필터링: \(filtered.count)개")

                if !filtered.isEmpty {
                    let values = filtered.map { $0.value }
                    print("   ✅ 필터링된 값 반환: \(values)")
                    return values
                }
            }

            // 필터링된 값이 없으면 전체 값 반환
            let allValues = placeholderValues.map { $0.value }
            print("   ℹ️ 전체 값 반환: \(allValues)")
            return allValues
        }

        // 저장된 데이터가 없으면 빈 배열 반환 (iOS 앱에서 관리하는 값만 사용)
        print("   ⚠️ 저장된 플레이스홀더 값 없음 - iOS 앱에서 값을 추가하세요")
        return []
    }

}

// 템플릿 입력 상태 관리
class TemplateInputState: ObservableObject {
    @Published var isShowing: Bool = false
    @Published var placeholders: [String] = []
    @Published var inputs: [String: String] = [:]
    @Published var originalText: String = ""
    @Published var currentFocusedPlaceholder: String? = nil
    @Published var allPlaceholdersFilled: Bool = false
    @Published var templateId: UUID? = nil  // 현재 편집 중인 템플릿 ID

    func updateAllPlaceholdersFilled() {
        allPlaceholdersFilled = !inputs.values.contains(where: { $0.isEmpty })
    }
}

struct KeyboardView: View {

    // 테마 목록 - ClipboardItemType enum에서 가져오기
    private var availableThemes: [String] {
        ClipboardItemType.allCases.map { $0.rawValue }
    }

    // 테마의 다국어 표시명을 가져오는 헬퍼 함수
    private func localizedThemeName(_ theme: String) -> String {
        if let type = ClipboardItemType(rawValue: theme) {
            return type.localizedName
        }
        return theme
    }

    @AppStorage("keyboardTheme") private var keyboardTheme: String = "system"
    @AppStorage("keyboardBackgroundColor") private var keyboardBackgroundColorHex: String = "F5F5F5"
    @AppStorage("keyboardKeyColor") private var keyboardKeyColorHex: String = "FFFFFF"
    @AppStorage("keyboardColumnCount", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var keyboardColumnCount: Int = 2
    @AppStorage("keyboardButtonHeight", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var buttonHeight: Double = 40.0
    @AppStorage("keyboardButtonFontSize", store: UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")) private var buttonFontSize: Double = 15.0

    // 동적 그리드 레이아웃 (열 개수에 따라 변경)
    private var gridItemLayout: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: max(1, min(5, keyboardColumnCount)))
    }

    @State private var showTemplatesOnly: Bool = false
    @State private var showFavoritesOnly: Bool = false
    @State private var selectedThemeFilter: String? = nil  // 선택된 테마 필터
    @State private var selectedTab: Int = 0  // 0: 메모, 1: Combo

    @StateObject private var templateInputState = TemplateInputState()

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // 탭 선택
            Picker("", selection: $selectedTab) {
                Text(NSLocalizedString("메모", comment: "Memo tab")).tag(0)
                Text(NSLocalizedString("Combo", comment: "Combo tab")).tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // 탭 내용
            if selectedTab == 0 {
                // 메모 그리드
                ZStack {
                    backgroundColor
                    ScrollView {
                        LazyVGrid(columns: gridItemLayout, spacing: 10)  {
                            ForEach(clipKey.indices, id:\.self) { i in
                                Button {
                                    UIImpactFeedbackGenerator().impactOccurred()
                                    // 메모 ID 포함해서 알림 전송
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name(rawValue: "addTextEntry"),
                                        object: clipValue[i],
                                        userInfo: ["memoId": clipMemoId[i]]
                                    )
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .foregroundColor(keyColor)
                                            .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
                                        Text(clipKey[i])
                                            .foregroundStyle(Color(uiColor: .label))
                                            .lineLimit(1)
                                            .padding(.vertical, (buttonHeight - buttonFontSize) / 2)
                                            .padding(.horizontal, 12)
                                            .font(.system(size: buttonFontSize, weight: .semibold))
                                    }
                                    .frame(height: buttonHeight)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }
                .frame(width: UIScreen.main.bounds.size.width)
            } else {
                // Combo 뷰
                ComboKeyboardView()
            }
        }
        .overlay(
            Group {
                if templateInputState.isShowing {
                    TemplateInputOverlay(state: templateInputState)
                }
            }
        )
        .onAppear {
            // 템플릿 입력 알림 구독
            NotificationCenter.default.addObserver(forName: NSNotification.Name("showTemplateInput"), object: nil, queue: .main) { notification in
                if let userInfo = notification.userInfo,
                   let text = userInfo["text"] as? String,
                   let placeholders = userInfo["placeholders"] as? [String],
                   let memoId = userInfo["memoId"] as? UUID {

                    print("🔍 템플릿 입력 요청 받음")
                    print("   메모 ID: \(memoId)")
                    print("   플레이스홀더: \(placeholders)")

                    templateInputState.originalText = text
                    templateInputState.placeholders = placeholders
                    templateInputState.templateId = memoId  // 템플릿 ID 저장

                    // 저장된 값들 불러오기 - 템플릿별로 필터링하여 첫 번째 값을 기본값으로 설정
                    var initialInputs: [String: String] = [:]

                    for placeholder in placeholders {
                        print("   🔍 [KeyboardView] 플레이스홀더 값 로드 시도: \(placeholder)")
                        // 템플릿 ID로 필터링된 값 로드
                        let values = PredefinedValuesStore.shared.getValuesForTemplate(placeholder: placeholder, templateId: memoId)
                        print("   📊 [KeyboardView] \(placeholder): \(values.count)개 - \(values)")

                        if let firstValue = values.first, !firstValue.isEmpty {
                            initialInputs[placeholder] = firstValue
                            print("   ✅ [KeyboardView] \(placeholder) 기본값 설정: \(firstValue)")
                        } else {
                            initialInputs[placeholder] = ""
                            print("   ⚠️ [KeyboardView] \(placeholder) 값 없음 - 빈 문자열 설정")
                        }
                    }

                    templateInputState.inputs = initialInputs
                    templateInputState.updateAllPlaceholdersFilled()

                    print("   초기 입력값: \(initialInputs)")

                    // 항상 템플릿 값 선택 UI 표시
                    print("🎨 템플릿 값 선택 UI 표시")
                    withAnimation {
                        templateInputState.isShowing = true
                    }
                }
            }
        }
    }

    private var backgroundColor: Color {
        if keyboardTheme == "시스템" {
            return .clear
        } else if keyboardTheme == "라이트" {
            return .clear
        } else if keyboardTheme == "다크" {
            return .clear
        } else if keyboardTheme == "커스텀" {
            return Color(hex: keyboardBackgroundColorHex) ?? .clear
        }
        return .clear
    }

    private var defaultKeyboardBackground: Color {
        .clear
    }

    private var keyColor: Color {
        if keyboardTheme == "시스템" {
            return defaultKeyColor
        } else if keyboardTheme == "라이트" {
            return .white
        } else if keyboardTheme == "다크" {
            return Color(red: 0.17, green: 0.17, blue: 0.18)
        } else if keyboardTheme == "커스텀" {
            return Color(hex: keyboardKeyColorHex) ?? defaultKeyColor
        }
        return defaultKeyColor
    }

    private var defaultKeyColor: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.0)
                : .white
        })
    }
}

#Preview {
    KeyboardView()
}

// 템플릿 입력 오버레이
struct TemplateInputOverlay: View {
    @ObservedObject var state: TemplateInputState

    var body: some View {
        ZStack {
            // 배경 dimming
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        state.isShowing = false
                        state.currentFocusedPlaceholder = nil
                    }
                }

            // 입력 카드
            VStack(spacing: 0) {
                // 헤더
                HStack {
                    Text("템플릿 값 선택")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button(action: {
                        withAnimation {
                            state.isShowing = false
                            state.currentFocusedPlaceholder = nil
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))

                Divider()

                // 입력 필드들
                ScrollView {
                    VStack(spacing: 16) {
                        if state.placeholders.isEmpty {
                            // 플레이스홀더가 없는 경우
                            VStack(spacing: 12) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)

                                Text("템플릿 변수가 없습니다")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("이 템플릿에는 설정할 값이 없어요.\n다시 시도해주세요.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(40)
                        } else {
                            ForEach(state.placeholders, id: \.self) { placeholder in
                                PlaceholderInputView(
                                    placeholder: placeholder,
                                    selectedValue: Binding(
                                        get: { state.inputs[placeholder] ?? "" },
                                        set: { newValue in
                                            state.inputs[placeholder] = newValue
                                            state.updateAllPlaceholdersFilled()
                                            // 모든 값이 채워졌으면 자동으로 입력
                                            if state.allPlaceholdersFilled {
                                                completeInput()
                                            }
                                        }
                                    ),
                                    templateId: state.templateId  // 템플릿 ID 전달
                                )
                            }

                            // 안내 메시지 - 하단으로 이동
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)

                                Text("값을 선택하면 자동으로 입력됩니다")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                .background(Color(UIColor.systemBackground))
            }
            .frame(maxWidth: 350, maxHeight: 300)
            .cornerRadius(16)
            .shadow(radius: 20)
        }
    }

    private func completeInput() {
        // 완료 알림 전송
        NotificationCenter.default.post(
            name: NSNotification.Name("templateInputComplete"),
            object: nil,
            userInfo: [
                "text": state.originalText,
                "inputs": state.inputs
            ]
        )

        withAnimation {
            state.isShowing = false
            state.currentFocusedPlaceholder = nil
        }
    }
}

// 플레이스홀더 입력 뷰 (선택 방식)
struct PlaceholderInputView: View {
    let placeholder: String
    @Binding var selectedValue: String
    let templateId: UUID?  // 템플릿 ID 추가

    private var predefinedValues: [String] {
        // 템플릿 ID로 필터링된 값 로드
        let storedValues = PredefinedValuesStore.shared.getValuesForTemplate(placeholder: placeholder, templateId: templateId)

        // iOS 앱에서 관리하는 저장된 값만 반환
        return storedValues
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(placeholder.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                if !selectedValue.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            if predefinedValues.isEmpty {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("값이 등록되지 않았습니다")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }

                    Text("앱을 열어 플레이스홀더 관리에서\n'\(placeholder.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))' 값을 추가해주세요")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(predefinedValues, id: \.self) { value in
                            Button {
                                selectedValue = value
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(value)
                                    .font(.system(size: 14, weight: selectedValue == value ? .semibold : .regular))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(selectedValue == value ? Color.blue : Color(UIColor.systemGray5))
                                    .foregroundColor(selectedValue == value ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.systemGray6).opacity(0.5))
        .cornerRadius(10)
    }
}

// Color extension for hex support (needed for keyboard target)
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
