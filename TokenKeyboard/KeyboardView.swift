//
//  KeyboardView.swift
//  TokenKeyboard
//
//  Created by hyunho lee on 2023/10/03.
//

import SwiftUI

var showOnlyTemplates: Bool = false
var showOnlyFavorites: Bool = false

// 미리 정의된 값들 저장소
class PredefinedValuesStore {
    static let shared = PredefinedValuesStore()

    // UserDefaults에서 불러오기
    func getValues(for placeholder: String) -> [String] {
        let key = "predefined_\(placeholder)"
        if let saved = UserDefaults(suiteName: "group.com.hyunho.Token-memo")?.stringArray(forKey: key) {
            return saved
        }

        // 기본값
        switch placeholder {
        case "{이름}":
            return ["김철수", "이영희", "박민수", "최지은", "정하늘"]
        case "{회사명}":
            return ["삼성전자", "네이버", "카카오", "라인", "쿠팡"]
        case "{장소}":
            return ["서울", "강남", "홍대", "신촌", "판교"]
        default:
            return []
        }
    }

    func saveValues(_ values: [String], for placeholder: String) {
        let key = "predefined_\(placeholder)"
        UserDefaults(suiteName: "group.com.hyunho.Token-memo")?.set(values, forKey: key)
    }
}

// 템플릿 입력 상태 관리
class TemplateInputState: ObservableObject {
    @Published var isShowing: Bool = false
    @Published var placeholders: [String] = []
    @Published var inputs: [String: String] = [:]
    @Published var originalText: String = ""
    @Published var currentFocusedPlaceholder: String? = nil
}

struct KeyboardView: View {

    private var gridItemLayout = [GridItem(.adaptive(minimum: 130), spacing: 10)]

    @AppStorage("keyboardTheme") private var keyboardTheme: String = "system"
    @AppStorage("keyboardBackgroundColor") private var keyboardBackgroundColorHex: String = "F5F5F5"
    @AppStorage("keyboardKeyColor") private var keyboardKeyColorHex: String = "FFFFFF"

    @State private var showTemplatesOnly: Bool = false
    @State private var showFavoritesOnly: Bool = false

    @StateObject private var templateInputState = TemplateInputState()

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // 상단 액세서리 바
            HStack(spacing: 8) {
                Spacer()

                // 필터 버튼들
                HStack(spacing: 8) {
                    // 템플릿 필터 버튼
                    Button {
                        showTemplatesOnly.toggle()
                        showFavoritesOnly = false
                        showOnlyTemplates = showTemplatesOnly
                        showOnlyFavorites = false
                        NotificationCenter.default.post(name: NSNotification.Name("filterChanged"), object: nil)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showTemplatesOnly ? "doc.text.fill" : "doc.text")
                                .font(.system(size: 14))
                            Text("템플릿")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(showTemplatesOnly ? Color.blue : Color(.systemGray5))
                        .foregroundColor(showTemplatesOnly ? .white : (colorScheme == .dark ? .white : .black))
                        .cornerRadius(16)
                    }

                    // 즐겨찾기 필터 버튼
                    Button {
                        showFavoritesOnly.toggle()
                        showTemplatesOnly = false
                        showOnlyFavorites = showFavoritesOnly
                        showOnlyTemplates = false
                        NotificationCenter.default.post(name: NSNotification.Name("filterChanged"), object: nil)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                                .font(.system(size: 14))
                            Text("즐겨찾기")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(showFavoritesOnly ? Color.blue : Color(.systemGray5))
                        .foregroundColor(showFavoritesOnly ? .white : (colorScheme == .dark ? .white : .black))
                        .cornerRadius(16)
                    }

                    // 필터 초기화 버튼
                    if showTemplatesOnly || showFavoritesOnly {
                        Button {
                            showTemplatesOnly = false
                            showFavoritesOnly = false
                            showOnlyTemplates = false
                            showOnlyFavorites = false
                            NotificationCenter.default.post(name: NSNotification.Name("filterChanged"), object: nil)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.clear)

            // 메모 그리드
            ZStack {
                backgroundColor
                ScrollView {
                    LazyVGrid(columns: gridItemLayout, spacing: 10)  {
                        ForEach(clipKey.indices, id:\.self) { i in
                            Button {
                                UIImpactFeedbackGenerator().impactOccurred()
                                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "addTextEntry"), object: clipValue[i])
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .foregroundColor(keyColor)
                                        .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
                                    Text(clipKey[i])
                                        .foregroundStyle(Color(uiColor: .label))
                                        .lineLimit(1)
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 12)
                                        .font(.system(size: 15, weight: .semibold))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }
            .frame(width: UIScreen.main.bounds.size.width)
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
                   let placeholders = userInfo["placeholders"] as? [String] {
                    templateInputState.originalText = text
                    templateInputState.placeholders = placeholders
                    templateInputState.inputs = Dictionary(uniqueKeysWithValues: placeholders.map { ($0, "") })
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

            // 입력 카드
            VStack(spacing: 0) {
                // 헤더
                HStack {
                    Text("템플릿 입력")
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
                        ForEach(state.placeholders, id: \.self) { placeholder in
                            PlaceholderInputView(
                                placeholder: placeholder,
                                selectedValue: Binding(
                                    get: { state.inputs[placeholder] ?? "" },
                                    set: { state.inputs[placeholder] = $0 }
                                )
                            )
                        }
                    }
                    .padding()
                }
                .background(Color(UIColor.systemBackground))

                Divider()

                // 버튼
                HStack(spacing: 12) {
                    Button("취소") {
                        withAnimation {
                            state.isShowing = false
                            state.currentFocusedPlaceholder = nil
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(10)

                    Button("완료") {
                        completeInput()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(state.inputs.values.contains(where: { $0.isEmpty }) ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(state.inputs.values.contains(where: { $0.isEmpty }))
                }
                .padding()
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

    private var predefinedValues: [String] {
        PredefinedValuesStore.shared.getValues(for: placeholder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(placeholder.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: ""))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            if predefinedValues.isEmpty {
                Text("설정에서 값을 추가하세요")
                    .font(.caption)
                    .foregroundColor(.orange)
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
