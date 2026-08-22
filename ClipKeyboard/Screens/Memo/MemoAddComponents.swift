//
//  MemoAddComponents.swift
//  ClipKeyboard
//
//  MemoAdd에서 분리한 보조 입력 컴포넌트(토글 행/토큰 버튼/플레이스홀더 에디터/
//  붙여넣을 내용 입력). 메인 폼은 MemoAdd.swift 유지.
//

import SwiftUI
import UIKit
import LeeoKit

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
                // 중괄호 없이 변수명만 칩으로 표시(삽입은 {…} 형태 그대로).
                Text(token.strippingTemplateBraces)
                    .font(.body.weight(.medium))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(theme.radiusSm)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusSm)
                    .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
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

                // 타입 뱃지 - 숫자 입력 vs 선택지
                HStack(spacing: 4) {
                    Image(systemName: isNumeric ? "number" : "list.bullet")
                        .font(.system(.caption2, weight: .semibold))
                        .accessibilityHidden(true)
                    Text(isNumeric
                         ? NSLocalizedString("숫자 입력", comment: "Numeric placeholder badge")
                         : NSLocalizedString("선택지", comment: "Selection placeholder badge"))
                        .font(.system(.caption2, weight: .semibold))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(theme.radiusXs)

                Spacer()

                Button {
                    isAdding.toggle()
                } label: {
                    Image(systemName: isAdding ? "xmark.circle.fill" : "plus.circle.fill")
                        .foregroundColor(isAdding ? .red : .accentColor)
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
                                    Image(systemName: AppSymbol.xmarkCircleFill)
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                }
                                .accessibilityLabel(String(format: NSLocalizedString("%@ 삭제", comment: "Delete value"), value))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.1))
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
                            .background(newValue.isEmpty ? Color.gray : Color.accentColor)
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
    /// v4.0.8: 키보드 toolbar "다음" 버튼 - 다음 필드(제목)로 focus 이동.
    /// nil이면 버튼 숨김.
    var onNext: (() -> Void)?
    /// "+" 칩 - 내용(값)을 하나 더 추가. 값이 여러 개면 콤보가 된다는 걸
    /// 입력 전부터 알려주는 힌트 버튼. nil이면 숨김.
    var onAddContent: (() -> Void)?
    /// 템플릿 작성 모드 - 숫자형 카테고리여도 글자/{변수}를 칠 수 있게 기본 키보드를 강제한다.
    var forceTextKeyboard: Bool = false

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// v4.0.8: 현재 value가 카테고리의 샘플 값과 동일한지 - 매번 판정.
    /// 사용자가 수정하면 자동으로 false. 우연히 샘플과 같아지면 다시 true (드문 케이스).
    private var isSampleValue: Bool {
        Constants.isSampleValue(value, forCategory: selectedCategory)
    }

    @State private var showImagePicker = false
    @State private var showToast = false
    @State private var toastMessage = ""

    // 사진 속 글자로 값 채우기 - 사진을 **붙이는** 것(attachedImages)과 다른 일이다.
    // 저쪽은 그림을 값으로 삼고, 이쪽은 그림에서 글자만 꺼내 텍스트 값으로 넣는다.
    @State private var showTextPhotoLibrary = false
    @State private var showTextCamera = false
    @State private var isRecognizingText = false
    /// 읽어낸 줄들 - 값이 있으면 고르는 시트가 뜬다.
    @State private var recognizedLines: [String]?
    @State private var showNoTextFound = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 라벨 - 이 값이 단축어를 탭했을 때 붙여넣어지는 내용.
            Text(NSLocalizedString("붙여넣을 내용", comment: "Content label: what gets pasted when user taps the memo"))
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(theme.textMuted)

            // 값 채우기 버튼 - 각자 한 줄 폭을 반씩 차지하는 명확한 보더 버튼.
            // (예전엔 라벨과 한 줄에 눌려 폭이 없어 글자가 세로로 깨졌음.)
            HStack(spacing: 10) {
                Button {
                    pasteFromClipboard()
                } label: {
                    Label(NSLocalizedString("붙여넣기", comment: "Paste clipboard value chip"),
                          systemImage: AppSymbol.docOnClipboard)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                .accessibilityLabel(NSLocalizedString("클립보드 값 가져오기", comment: "Paste value from clipboard"))

                // 사진 속 글자 → 값. 계좌번호·카드번호처럼 **보고 옮겨 적던 것**이
                // 이 앱에 들어오는 가장 흔한 경로라, 붙여넣기 바로 옆에 둔다.
                Menu {
                    Button {
                        showTextPhotoLibrary = true
                    } label: {
                        Label(NSLocalizedString("사진 보관함에서", comment: "Read text from photo library"),
                              systemImage: AppSymbol.photo)
                    }
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            showTextCamera = true
                        } label: {
                            Label(NSLocalizedString("카메라로 찍어서", comment: "Read text using the camera"),
                                  systemImage: AppSymbol.cameraViewfinder)
                        }
                    }
                } label: {
                    // ⚠️ 칩 하나에 4글자를 넘기지 말 것 - 세 칸으로 나눈 폭이라 말줄임으로 잘린다.
                    //    "사진 …"류를 쓰지 않는 이유는 하나 더 있다: 옆 칩이 '이미지'라
                    //    둘 다 사진 이야기로 읽혀 무엇이 다른지 흐려진다. 여기는 **글자**를 가져온다.
                    Label(NSLocalizedString("글자 읽기", comment: "Fill the value from text in a photo"),
                          systemImage: AppSymbol.textViewfinder)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                .disabled(isRecognizingText)
                .accessibilityLabel(NSLocalizedString("사진에서 글자를 읽어 값으로 넣기",
                                                      comment: "Fill value from text in a photo (a11y)"))

                Button {
                    showImagePicker = true
                } label: {
                    Label(NSLocalizedString("이미지", comment: "Add image chip"),
                          systemImage: AppSymbol.photo)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                .accessibilityLabel(NSLocalizedString("사진 라이브러리에서 선택", comment: "Select from photo library"))
            }

            // 인식은 몇 초 걸릴 수 있다 - 아무 반응이 없으면 눌린 줄 모르고 다시 누른다.
            if isRecognizingText {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(NSLocalizedString("사진에서 글자를 읽는 중…", comment: "Recognizing text in photo"))
                        .font(.subheadline)
                        .foregroundColor(theme.textMuted)
                }
                .accessibilityElement(children: .combine)
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
                                    Image(systemName: AppSymbol.photoBadgePlus)
                                    Text(NSLocalizedString("이미지 변경", comment: "Change image"))
                                }
                                .font(.body)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundColor(.accentColor)
                                .cornerRadius(theme.radiusSm)
                            }

                            Button {
                                withAnimation(reduceMotion ? nil : .default) { attachedImages.removeAll() }
                            } label: {
                                HStack {
                                    Image(systemName: AppSymbol.trash)
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
                    // 아직 이미지 미선택 - 큰 placeholder
                    Button {
                        showImagePicker = true
                    } label: {
                        VStack(spacing: 16) {
                            Image(systemName: AppSymbol.photoOnRectangleAngled)
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))

                            Text(NSLocalizedString("이미지를 선택하세요", comment: "Select an image"))
                                .font(.headline)
                                .foregroundColor(theme.textMuted)

                            Text(NSLocalizedString("탭하여 사진 선택", comment: "Tap to select photo"))
                                .font(.body)
                                .foregroundColor(.accentColor.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .background(theme.surfaceAlt)
                        .cornerRadius(theme.radiusMd)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.radiusMd)
                                .strokeBorder(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
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
                                    Label(NSLocalizedString("변경", comment: "Change image"), systemImage: AppSymbol.photoBadgePlus)
                                        .font(.body)
                                        .foregroundColor(.accentColor)
                                }
                                Button {
                                    withAnimation(reduceMotion ? nil : .default) { attachedImages.removeAll() }
                                } label: {
                                    Label(NSLocalizedString("제거", comment: "Remove image"), systemImage: AppSymbol.trash)
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

                // v4.0.8: 샘플 값이면 안내 배너 - "수정해서 사용하세요"
                if isSampleValue {
                    HStack(spacing: 8) {
                        Image(systemName: AppSymbol.pencilTip)
                            .font(.body)
                            .foregroundColor(.orange)
                        Text(NSLocalizedString("샘플: 수정해서 사용하세요", comment: "Sample value hint"))
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

                // 이미지를 값으로 첨부하면 텍스트 값 입력은 비활성화(숨김) - 이미지가 곧 값.
                if attachedImages.isEmpty {
                // 텍스트 테마: syntax highlighting + 동적 높이 입력칸.
                // [Your Name] 같은 더미 placeholder는 빨간 굵은 글씨로 강조 - 사용자가
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
                .accessibilityLabel(NSLocalizedString("붙여넣을 내용", comment: "Content label: what gets pasted when user taps the memo"))
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
                    // 붙여넣을 원문 - 자동 수정이 내용을 훼손하지 않게.
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(theme.surfaceAlt)
                    .cornerRadius(theme.radiusMd)
                    .accessibilityLabel(NSLocalizedString("붙여넣을 내용", comment: "Content label: what gets pasted when user taps the memo"))
                    .onChange(of: value) { _, newValue in
                        if !newValue.isEmpty {
                            let classification = ClipboardClassificationService.shared.classify(content: newValue)
                            autoDetectedType = classification.type
                            autoDetectedConfidence = classification.confidence
                        }
                    }
                #endif
                }

                // 큰 "이미지 추가" 버튼은 "내용 추가"(콤보 단계 추가, MemoAdd 쪽)로 대체됨.
                // 이미지 첨부는 헤더 우측 아이콘(클립보드/사진 라이브러리)으로 계속 가능.
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
        // 사진 속 글자 읽기 - 고른 사진은 **첨부하지 않는다.** 글자만 꺼내 쓰고 사진은 버린다.
        .sheet(isPresented: $showTextPhotoLibrary) {
            ImagePickerView { image in recognizeText(in: image) }
        }
        .sheet(isPresented: $showTextCamera) {
            ImagePickerView(sourceType: .camera) { image in recognizeText(in: image) }
        }
        .sheet(isPresented: Binding(
            get: { recognizedLines != nil },
            set: { if !$0 { recognizedLines = nil } }
        )) {
            if let lines = recognizedLines {
                PhotoValuePicker(
                    lines: lines,
                    onPick: { picked in
                        value = picked
                        showToastMessage(NSLocalizedString("사진에서 값을 넣었습니다", comment: "Filled value from photo toast"))
                    },
                    onAppend: { line in
                        // 두 줄짜리 주소처럼 여러 줄이 한 값일 때 - 줄바꿈으로 잇는다.
                        value = value.isEmpty ? line : value + "\n" + line
                    }
                )
            }
        }
        .alert(NSLocalizedString("글자를 찾지 못했어요", comment: "No text found in photo alert title"),
               isPresented: $showNoTextFound) {
            Button(NSLocalizedString("확인", comment: "Confirm")) {}
        } message: {
            Text(NSLocalizedString("사진에서 읽을 수 있는 글자가 없었어요. 글자가 크고 또렷하게 나온 사진으로 다시 해보세요.",
                                   comment: "No text found in photo alert message"))
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

    /// 고른 사진에서 글자를 읽어 **고르는 시트**로 넘긴다.
    ///
    /// ⚠️ 읽은 것을 값에 곧바로 쏟아붓지 않는다. 카드 한 장에서도 카드사 이름·영문 이름·
    ///    유효기간이 함께 읽히는데, 전부 넣으면 사용자가 지우는 일을 하게 된다
    ///    손으로 치는 것보다 나을 게 없다. 줄을 늘어놓고 **하나를 집게** 해야 사진이 입력을 대신한다.
    ///
    /// ⚠️ 사진 자체는 첨부하지 않는다. 여기서 사진은 글자를 담아 온 그릇일 뿐이고,
    ///    첨부는 옆의 '이미지' 버튼이 하는 다른 일이다.
    private func recognizeText(in image: UIImage?) {
        guard let image else { return }
        isRecognizingText = true
        OCRService.shared.recognizeText(from: image) { texts in
            isRecognizingText = false
            let lines = texts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !lines.isEmpty else {
                showNoTextFound = true
                return
            }
            recognizedLines = lines
        }
    }

    /// 클립보드 값 가져오기 - 텍스트가 있으면 값으로 넣고, 이미지면 이미지로 첨부한다.
    private func pasteFromClipboard() {
        #if os(iOS)
        if let text = UIPasteboard.general.string,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            value = text
            showToastMessage(NSLocalizedString("클립보드 값을 가져왔습니다", comment: "Pasted clipboard text into value toast"))
            return
        }
        guard UIPasteboard.general.hasImages else {
            showToastMessage(NSLocalizedString("클립보드가 비어 있습니다", comment: "Clipboard empty toast"))
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
        // 템플릿 작성 중이거나 본문에 {변수}가 있으면 글자 입력이 필요하므로 항상 기본 키보드.
        if forceTextKeyboard || value.contains("{") { return .default }
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
                    Text(NSLocalizedString("이미지에서 인식한 텍스트예요. 단축어 값으로 담을 줄을 골라주세요.", comment: "OCR picker subtitle"))
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
                    .foregroundColor(isOn ? .accentColor : theme.textFaint)
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
                    .stroke(isOn ? Color.accentColor.opacity(0.5) : theme.divider, lineWidth: isOn ? 1.5 : 0.5)
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
                .background(count > 0 ? Color.accentColor : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(count == 0)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
}
