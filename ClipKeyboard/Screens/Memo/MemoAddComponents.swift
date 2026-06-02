//
//  MemoAddComponents.swift
//  ClipKeyboard
//
//  MemoAdd에서 분리한 보조 입력 컴포넌트(토글 행/토큰 버튼/플레이스홀더 에디터/
//  붙여넣을 내용 입력). 메인 폼은 MemoAdd.swift 유지.
//

import SwiftUI
import UIKit

// MARK: - Toggle Option Row

struct ToggleOptionRow: View {
    let activeIcon: String
    let inactiveIcon: String
    let title: String
    let description: String
    let activeColor: Color
    @Binding var isOn: Bool

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack {
            Image(systemName: isOn ? activeIcon : inactiveIcon)
                .font(.title3)
                .foregroundColor(isOn ? activeColor : .secondary)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(description)
                    .font(.body)
                    .foregroundColor(theme.textMuted)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(theme.surfaceAlt)
        .cornerRadius(theme.radiusMd)
        // 행 전체를 단일 스위치로 묶어 VoiceOver가 "제목, 켬/끔, 스위치"로 읽게 함
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isOn
            ? NSLocalizedString("켬", comment: "Toggle state: on")
            : NSLocalizedString("끔", comment: "Toggle state: off")
        )
        .accessibilityHint(description)
        .modifier(ToggleTraitModifier())
    }
}

/// `.isToggle` 트레이트를 iOS 17+ 에서만 적용하는 modifier.
struct ToggleTraitModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content.accessibilityAddTraits(.isToggle)
        } else {
            content
        }
    }
}

// 플레이스홀더 값 편집기
// MARK: - Quick Insert Token Button

struct QuickInsertTokenButton: View {
    let token: String
    let isNumeric: Bool
    let action: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isNumeric ? "number" : "list.bullet")
                    .font(.system(.caption2, weight: .semibold))
                    .accessibilityHidden(true)
                Text(token)
                    .font(.body.weight(.medium))
            }
            .foregroundColor(isNumeric ? .blue : .green)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((isNumeric ? Color.blue : Color.green).opacity(0.1))
            .cornerRadius(theme.radiusSm)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusSm)
                    .strokeBorder((isNumeric ? Color.blue : Color.green).opacity(0.25), lineWidth: 1)
            )
        }
        .accessibilityLabel(token)
        .accessibilityHint(NSLocalizedString("탭하면 커서 위치에 변수가 삽입됩니다", comment: "Quick insert token button hint"))
    }
}

struct PlaceholderValueEditor: View {
    let placeholder: String
    @Binding var values: [String]
    @Environment(\.appTheme) private var theme
    @State private var newValue: String = ""
    @State private var isAdding: Bool = false

    private var isNumeric: Bool { TemplateVariableProcessor.isNumericToken(placeholder) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(placeholder.strippingTemplateBraces)
                    .font(.body)
                    .fontWeight(.semibold)

                // 타입 뱃지 — 숫자 입력 vs 선택지
                HStack(spacing: 4) {
                    Image(systemName: isNumeric ? "number" : "list.bullet")
                        .font(.system(.caption2, weight: .semibold))
                        .accessibilityHidden(true)
                    Text(isNumeric
                         ? NSLocalizedString("숫자 입력", comment: "Numeric placeholder badge")
                         : NSLocalizedString("선택지", comment: "Selection placeholder badge"))
                        .font(.system(.caption2, weight: .semibold))
                }
                .foregroundColor(isNumeric ? .blue : .green)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background((isNumeric ? Color.blue : Color.green).opacity(0.12))
                .cornerRadius(theme.radiusXs)

                Spacer()

                Button {
                    isAdding.toggle()
                } label: {
                    Image(systemName: isAdding ? "xmark.circle.fill" : "plus.circle.fill")
                        .foregroundColor(isAdding ? .red : .blue)
                }
                .accessibilityLabel(isAdding
                    ? NSLocalizedString("입력 취소", comment: "Cancel value input")
                    : NSLocalizedString("값 추가", comment: "Add combo value button"))
            }

            // 값 목록
            if !values.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(values, id: \.self) { value in
                            HStack(spacing: 6) {
                                Text(value)
                                    .font(.body)

                                Button {
                                    values.removeAll { $0 == value }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(theme.radiusMd)
                        }
                    }
                }
            }

            // 값 추가
            if isAdding {
                HStack(spacing: 8) {
                    TextField(NSLocalizedString("값 입력", comment: "Placeholder value input"), text: $newValue)
                        .clipRoundedField()
                        .font(.body)

                    Button {
                        if !newValue.isEmpty && !values.contains(newValue) {
                            values.append(newValue)
                            newValue = ""
                            isAdding = false
                        }
                    } label: {
                        Text(NSLocalizedString("추가", comment: "Add"))
                            .font(.body)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(newValue.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(theme.radiusSm)
                    }
                    .disabled(newValue.isEmpty)
                }
            }
        }
        .padding()
        .background(theme.surface)
        .cornerRadius(theme.radiusSm)
    }
}

// MARK: - Content Input Section

struct ContentInputSection: View {
    @Binding var value: String
    let selectedCategory: String
    @Binding var isFocused: Bool
    @Binding var autoDetectedType: ClipboardItemType?
    @Binding var autoDetectedConfidence: Double
    @Binding var attachedImages: [ImageWrapper]
    /// v4.0.8: 키보드 toolbar "다음" 버튼 — 다음 필드(제목)로 focus 이동.
    /// nil이면 버튼 숨김.
    var onNext: (() -> Void)? = nil

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// v4.0.8: 현재 value가 카테고리의 샘플 값과 동일한지 — 매번 판정.
    /// 사용자가 수정하면 자동으로 false. 우연히 샘플과 같아지면 다시 true (드문 케이스).
    private var isSampleValue: Bool {
        Constants.isSampleValue(value, forCategory: selectedCategory)
    }

    @State private var showImagePicker = false
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(NSLocalizedString("붙여넣을 내용", comment: "Content label — what gets pasted when user taps the memo"))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(theme.textMuted)

                Spacer()

                // 이미지 첨부 버튼 — 항상 표시
                HStack(spacing: 8) {
                    Button {
                        pasteImageFromClipboard()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.body)
                            .padding(6)
                            .background(Color.purple.opacity(0.1))
                            .foregroundColor(.purple)
                            .cornerRadius(theme.radiusXs)
                    }
                    .accessibilityLabel(NSLocalizedString("클립보드에서 이미지 붙여넣기", comment: "Paste image from clipboard"))

                    Button {
                        showImagePicker = true
                    } label: {
                        Image(systemName: "photo")
                            .font(.body)
                            .padding(6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(theme.radiusXs)
                    }
                    .accessibilityLabel(NSLocalizedString("사진 라이브러리에서 선택", comment: "Select from photo library"))
                }
            }

            if selectedCategory == "이미지" {
                // ── "이미지" 카테고리: 풀-이미지 모드 ──
                if let firstImage = attachedImages.first {
                    VStack(spacing: 12) {
                        Image(uiImage: firstImage.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .cornerRadius(theme.radiusMd)
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.radiusMd)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        HStack(spacing: 12) {
                            Button {
                                showImagePicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "photo.badge.plus")
                                    Text(NSLocalizedString("이미지 변경", comment: "Change image"))
                                }
                                .font(.body)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(theme.radiusSm)
                            }

                            Button {
                                withAnimation(reduceMotion ? nil : .default) { attachedImages.removeAll() }
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text(NSLocalizedString("이미지 제거", comment: "Remove image"))
                                }
                                .font(.body)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(theme.radiusSm)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                } else {
                    // 아직 이미지 미선택 — 큰 placeholder
                    Button {
                        showImagePicker = true
                    } label: {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))

                            Text(NSLocalizedString("이미지를 선택하세요", comment: "Select an image"))
                                .font(.headline)
                                .foregroundColor(theme.textMuted)

                            Text(NSLocalizedString("탭하여 사진 선택", comment: "Tap to select photo"))
                                .font(.body)
                                .foregroundColor(.blue.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .background(theme.surfaceAlt)
                        .cornerRadius(theme.radiusMd)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.radiusMd)
                                .strokeBorder(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // 일반 카테고리: 텍스트 + 선택적 이미지 첨부
                if let firstImage = attachedImages.first {
                    HStack(spacing: 10) {
                        Image(uiImage: firstImage.image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 72, height: 72)
                            .cornerRadius(theme.radiusSm)
                            .clipped()

                        VStack(alignment: .leading, spacing: 6) {
                            Text(NSLocalizedString("배경 이미지", comment: "Attached image label"))
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                            HStack(spacing: 8) {
                                Button {
                                    showImagePicker = true
                                } label: {
                                    Label(NSLocalizedString("변경", comment: "Change image"), systemImage: "photo.badge.plus")
                                        .font(.body)
                                        .foregroundColor(.blue)
                                }
                                Button {
                                    withAnimation(reduceMotion ? nil : .default) { attachedImages.removeAll() }
                                } label: {
                                    Label(NSLocalizedString("제거", comment: "Remove image"), systemImage: "trash")
                                        .font(.body)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(theme.surfaceAlt)
                    .cornerRadius(theme.radiusMd)
                }

                // v4.0.8: 샘플 값이면 안내 배너 — "수정해서 사용하세요"
                if isSampleValue {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil.tip")
                            .font(.body)
                            .foregroundColor(.orange)
                        Text(NSLocalizedString("샘플 — 수정해서 사용하세요", comment: "Sample value hint"))
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        Spacer()
                        Button {
                            value = ""
                        } label: {
                            Text(NSLocalizedString("지우기", comment: "Clear sample"))
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(theme.radiusXs)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(theme.radiusSm)
                }

                // 이미지를 값으로 첨부하면 텍스트 값 입력은 비활성화(숨김) — 이미지가 곧 값.
                if attachedImages.isEmpty {
                // 텍스트 테마: syntax highlighting + 동적 높이 입력칸.
                // [Your Name] 같은 더미 placeholder는 빨간 굵은 글씨로 강조 — 사용자가
                // "여기는 직접 수정해야 한다"는 걸 즉시 인지. iOS TextField는 attributed
                // 표시를 지원 안 해 UITextView wrapper로 처리.
                #if os(iOS)
                HighlightedTextEditor(
                    text: $value,
                    placeholder: placeholderText,
                    keyboardType: keyboardTypeForTheme,
                    isFocused: $isFocused
                )
                .frame(minHeight: 60, maxHeight: 240)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(theme.surfaceAlt)
                .cornerRadius(theme.radiusMd)
                .onChange(of: value) { _, newValue in
                    if !newValue.isEmpty {
                        let classification = ClipboardClassificationService.shared.classify(content: newValue)
                        autoDetectedType = classification.type
                        autoDetectedConfidence = classification.confidence
                    }
                }
                #else
                TextField(placeholderText, text: $value, axis: .vertical)
                    .font(.body)
                    .lineLimit(2...10)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(theme.surfaceAlt)
                    .cornerRadius(theme.radiusMd)
                    .onChange(of: value) { _, newValue in
                        if !newValue.isEmpty {
                            let classification = ClipboardClassificationService.shared.classify(content: newValue)
                            autoDetectedType = classification.type
                            autoDetectedConfidence = classification.confidence
                        }
                    }
                #endif
                }

                // 일반 카테고리에서 이미지 미첨부 시 큰 "이미지 추가" 탭 버튼.
                // 헤더 우측 작은 아이콘만으로는 인지율이 낮아 별도 노출.
                if attachedImages.isEmpty {
                    Button {
                        showImagePicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.body)
                            Text(NSLocalizedString("이미지 추가", comment: "Add image button on memo add screen"))
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.surfaceAlt)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.radiusMd)
                                .strokeBorder(Color.blue.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                        .cornerRadius(theme.radiusMd)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(NSLocalizedString("이미지 추가", comment: "Add image button on memo add screen"))
                    .padding(.top, 4)
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView { image in
                if let image = image {
                    withAnimation(reduceMotion ? nil : .default) {
                        attachedImages.append(ImageWrapper(image: image))
                        value = "" // 이미지를 값으로 쓰므로 텍스트 값은 비운다.
                    }
                }
            }
        }
        .overlay(
            // Toast 메시지
            VStack {
                if showToast {
                    Text(toastMessage)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(theme.radiusSm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
                Spacer()
            }
            .animation(.easeInOut, value: showToast)
        )
    }

    private func pasteImageFromClipboard() {
        #if os(iOS)
        guard UIPasteboard.general.hasImages else {
            showToastMessage(NSLocalizedString("클립보드에 이미지가 없습니다", comment: ""))
            return
        }

        let image = UIPasteboard.general.image
            ?? UIPasteboard.general.data(forPasteboardType: "public.png").flatMap(UIImage.init)
            ?? UIPasteboard.general.data(forPasteboardType: "public.jpeg").flatMap(UIImage.init)

        if let image {
            withAnimation(reduceMotion ? nil : .default) {
                attachedImages.append(ImageWrapper(image: image))
                value = "" // 이미지를 값으로 쓰므로 텍스트 값은 비운다.
            }
            showToastMessage(NSLocalizedString("이미지를 추가했습니다", comment: ""))
        } else {
            showToastMessage(NSLocalizedString("이미지 형식을 지원하지 않습니다", comment: ""))
        }
        #endif
    }

    // 이미지 클립보드에 복사
    private func copyImageToClipboard(_ image: UIImage) {
        #if os(iOS)
        UIPasteboard.general.image = image
        showToastMessage(NSLocalizedString("이미지를 복사했습니다", comment: ""))
        #endif
    }

    // Toast 메시지 표시
    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }

    private var placeholderText: String {
        guard let type = ClipboardItemType(rawValue: selectedCategory) else {
            return NSLocalizedString("내용을 입력하세요", comment: "Default placeholder")
        }

        switch type {
        case .email: return "example@email.com"
        case .phone: return "010-1234-5678"
        case .address: return NSLocalizedString("서울시 강남구 테헤란로 123", comment: "Address placeholder")
        case .url: return "https://example.com"
        case .creditCard: return "1234-5678-9012-3456"
        case .bankAccount: return "123-456789-12-345"
        case .passportNumber: return "M12345678"
        case .declarationNumber: return "P123456789012"
        case .postalCode: return "12345"
        case .name: return NSLocalizedString("홍길동", comment: "Name placeholder")
        case .birthDate: return "1990-01-01"
        case .taxID: return "123-45-6789"
        case .insuranceNumber: return "A12345678"
        case .vehiclePlate: return NSLocalizedString("12가1234", comment: "Vehicle plate placeholder")
        case .ipAddress: return "192.168.0.1"
        case .membershipNumber: return "M123456"
        case .trackingNumber: return "1Z999AA10123456784"
        case .confirmationCode: return "ABC123XYZ"
        case .medicalRecord: return "MR-2024-001"
        case .employeeID: return "E12345"
        default: return NSLocalizedString("내용을 입력하세요", comment: "Default placeholder")
        }
    }

    private var keyboardTypeForTheme: UIKeyboardType {
        guard let type = ClipboardItemType(rawValue: selectedCategory) else {
            return .default
        }

        switch type {
        case .email: return .emailAddress
        case .phone, .creditCard, .bankAccount, .postalCode, .taxID, .insuranceNumber: return .numberPad
        case .ipAddress: return .decimalPad
        case .url: return .URL
        case .birthDate: return .numberPad
        default: return .default
        }
    }
}

// MARK: - OCR Text Picker Sheet

/// 캡쳐/첨부 이미지에서 OCR로 인식된 텍스트 중 메모 값으로 담을 줄을 고르는 시트.
/// 여러 줄을 선택해 합칠 수 있다(예: 주소처럼 여러 줄로 나뉜 값).
struct OCRTextPickerSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let candidates: [String]
    /// 선택한 줄들을 값으로 담는다.
    let onApply: ([String]) -> Void

    @State private var selected: Set<Int> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("이미지에서 인식한 텍스트예요. 메모 값으로 담을 줄을 골라주세요.", comment: "OCR picker subtitle"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                        .padding(.bottom, 4)

                    ForEach(Array(candidates.enumerated()), id: \.offset) { index, line in
                        row(index: index, line: line)
                    }

                    Spacer(minLength: 90)
                }
                .padding(16)
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("값 선택", comment: "OCR picker title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("취소", comment: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("모두", comment: "OCR picker: select all")) {
                        if selected.count == candidates.count {
                            selected.removeAll()
                        } else {
                            selected = Set(candidates.indices)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                applyButton
            }
        }
    }

    private func row(index: Int, line: String) -> some View {
        let isOn = selected.contains(index)
        return Button {
            HapticManager.shared.light()
            if isOn { selected.remove(index) } else { selected.insert(index) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(.title3))
                    .foregroundColor(isOn ? .blue : theme.textFaint)
                    .accessibilityHidden(true)
                Text(line)
                    .font(.body)
                    .foregroundColor(theme.text)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                    .stroke(isOn ? Color.blue.opacity(0.5) : theme.divider, lineWidth: isOn ? 1.5 : 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(line)
        .accessibilityHint(NSLocalizedString("탭하면 값에 담기/제외", comment: "VoiceOver: toggle OCR line"))
    }

    private var applyButton: some View {
        let count = selected.count
        return Button {
            let lines = candidates.enumerated()
                .filter { selected.contains($0.offset) }
                .map { $0.element }
            onApply(lines)
            dismiss()
        } label: {
            Text(count > 0
                 ? String(format: NSLocalizedString("선택한 %d줄 담기", comment: "OCR picker apply button (count)"), count)
                 : NSLocalizedString("줄을 골라주세요", comment: "OCR picker apply button (none)"))
                .font(.body.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(count > 0 ? Color.blue : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(count == 0)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
}
