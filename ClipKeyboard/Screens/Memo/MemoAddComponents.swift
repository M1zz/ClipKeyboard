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
    /// 저장해 둔 값의 개수. nil 이면 숫자를 붙이지 않는다(아직 안 쓰는 빈칸).
    var valueCount: Int? = nil
    /// **색으로 가르는 두 갈래.** 내가 이미 쓰는 빈칸인가, 앱이 권하는 빈칸인가.
    ///
    /// ⚠️ 둘을 같은 색으로 두면 안 된다. 하나는 누르는 순간 **예전 값이 따라오는 것**이고
    ///    다른 하나는 이름만 들어가는 것이라, 결과가 다르다. 결과가 다르면 보이는 것도 달라야 한다.
    var tone: Tone = .suggested
    let action: () -> Void

    enum Tone {
        /// 이미 쓰고 있는 빈칸 - 키컬러.
        case mine
        /// 앱이 권하는 빈칸 - 회색.
        case suggested
    }

    @Environment(\.appTheme) private var theme

    private var foreground: Color { tone == .mine ? theme.accent : .secondary }
    private var background: Color { tone == .mine ? theme.accentSoft : Color.secondary.opacity(0.12) }
    private var border: Color {
        tone == .mine ? theme.accent.opacity(0.45) : Color.secondary.opacity(0.25)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isNumeric ? "number" : "list.bullet")
                    .font(.system(.caption2, weight: .semibold))
                    .accessibilityHidden(true)
                // 중괄호 없이 변수명만 칩으로 표시(삽입은 {…} 형태 그대로).
                Text(token.strippingTemplateBraces)
                    .font(.body.weight(.medium))
                if let valueCount, valueCount > 0 {
                    Text("\(valueCount)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(theme.accent.opacity(0.18)))
                }
            }
            .foregroundColor(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(background)
            .cornerRadius(theme.radiusSm)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusSm)
                    .strokeBorder(border, lineWidth: 1)
            )
        }
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(tone == .mine
            ? NSLocalizedString("탭하면 이 빈칸이 들어가고, 저장해 둔 값도 함께 따라옵니다",
                                comment: "Insert existing placeholder hint")
            : NSLocalizedString("탭하면 커서 자리에 빈칸이 들어갑니다",
                                comment: "Quick insert token button hint"))
    }

    private var accessibilityText: String {
        guard let valueCount, valueCount > 0 else { return token }
        return String(format: NSLocalizedString("%1$@, 저장된 값 %2$d개",
                                                comment: "Placeholder chip with value count (a11y)"),
                      token.strippingTemplateBraces, valueCount)
    }
}

// MARK: - 이미 쓰는 빈칸

/// 이미 쓰고 있는 빈칸을 늘어놓고, 눌러서 그대로 가져다 쓰게 한다.
///
/// 왜 필요한가: 빈칸의 값은 **이름으로** 묶인다(`placeholder_values_{이름}`). 그래서 다른
/// 단축어에서 쓰던 `{회사명}` 을 그대로 치면 값이 따라온다. 문제는 그걸 알려 주는 자리가
/// 없어서, 이름을 조금 다르게 적는 순간(`{회사 이름}`) 값이 갈라진다는 것이다.
/// 목록으로 내밀면 손으로 칠 일이 없어지고, 이름도 갈라지지 않는다.
///
/// ⚠️ 값이 있는 빈칸이 앞에 온다(`PlaceholderCatalog` 가 정렬한다). 처음 쓰는 사람에게는
///    아무것도 안 보인다 - 빈 목록에 자리를 내주지 않는다.
struct UsedPlaceholderBar: View {
    let onInsert: (String) -> Void

    @Environment(\.appTheme) private var theme
    @State private var items: [PlaceholderSummary] = []

    var body: some View {
        Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("이미 쓰는 빈칸", comment: "Placeholders already in use label"))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textMuted)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(items) { item in
                                QuickInsertTokenButton(token: item.token,
                                                       isNumeric: item.isNumeric,
                                                       valueCount: item.valueCount,
                                                       tone: .mine) {
                                    onInsert(item.token)
                                    #if os(iOS)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    #endif
                                }
                            }
                        }
                        .padding(.horizontal, 1)   // 테두리가 잘리지 않게
                    }

                    Text(NSLocalizedString("누르면 그 빈칸이 들어가고, 예전에 넣어 둔 값도 함께 따라와요",
                                           comment: "Placeholders already in use hint"))
                        .font(.caption)
                        .foregroundColor(theme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        items = PlaceholderCatalog.insertable(from: memos)
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
    /// 처음 만드는 사람을 짚어 주는 중이면 지금 걸음(`MemoAddCoach.swift`).
    /// 이 칸은 **값을 가져오는 줄**과 **실제 내용**으로 나뉘어서 걸음도 둘이다.
    var coachStep: MemoAddCoachStep?

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
    /// 읽어낸 줄들 - 값이 있으면 **줄 목록에서** 고르는 시트가 뜬다.
    /// (문지르기가 어려운 사람을 위한 길. 평소엔 아래 `smearSource` 쪽으로 간다.)
    @State private var recognizedLines: [String]?
    /// 읽어낸 사진과 글자 자리 - 값이 있으면 **문질러 담는** 화면이 뜬다.
    @State private var smearSource: SmearSource?
    @State private var showNoTextFound = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 라벨 - 이 값이 단축어를 탭했을 때 붙여넣어지는 내용.
            HStack(spacing: 8) {
                Text(NSLocalizedString("붙여넣을 내용", comment: "Content label: what gets pasted when user taps the memo"))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(theme.textMuted)

                Spacer()

                // 클립보드에 있는 것을 그대로 담는다. **무엇인지 맞히지 않는다.**
                //
                // `PasteButton` 은 시스템이 붙여넣기를 대신 처리하므로 "붙여넣기 허용?"
                // 프롬프트가 뜨지 않는다. 우리가 `UIPasteboard` 를 직접 읽으면 매번 묻는다.
                PasteButton(payloadType: String.self) { strings in
                    guard let first = strings.first, !first.isEmpty else { return }
                    // 이미 적은 것을 지우지 않는다. 비어 있을 때만 채우고, 아니면 뒤에 잇는다.
                    value = value.isEmpty ? first : value + "\n" + first
                }
                .labelStyle(.titleAndIcon)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
            }

            // 값을 채우는 두 길. **글자를 가져오는 것**과 **그림을 붙이는 것**은 다른 일이다.
            //
            // ⚠️ 예전엔 칩 셋(붙여넣기·글자 읽기·이미지)이 한 줄을 나눠 가져 글자가 잘렸고,
            //    잘리고 남은 "글자 읽기 / 이미지"는 둘 다 사진 이야기로 읽혀 무엇이 다른지
            //    흐렸다. 한 줄에 하나씩 놓고, 이름 옆에 **무엇이 값이 되는지**를 적는다.
            //
            // ⚠️ 붙여넣기는 위 라벨 오른쪽의 `PasteButton` 이 맡는다. 예전에는 이 자리에
            //    칩으로 있다가, 화면 위쪽 제안 배너가 대신하면서 빠졌다. 그 배너를
            //    없앤 지금(클립보드를 훔쳐보고 갈래를 맞히던 일이다) 다시 눈에 보이는
            //    자리가 필요하다. 본문을 길게 눌러 붙이는 길도 그대로 있다.
            VStack(spacing: 8) {
                // 사진 속 글자 → 값. 계좌번호·카드번호처럼 **보고 옮겨 적던 것**이
                // 이 앱에 들어오는 가장 흔한 경로라 위에 둔다.
                Menu {
                    Section {
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
                    } header: {
                        // 사진을 고르기 **전에** 무슨 일이 일어나는지 알려 준다.
                        // 찍고 나서야 알면, 필요한 글자가 안 나오게 찍은 뒤다.
                        Text(NSLocalizedString("필요한 글자만 손가락으로 문질러 담아요",
                                               comment: "Read-text menu header: smear to pick"))
                    }
                } label: {
                    sourceRow(
                        symbol: AppSymbol.textViewfinder,
                        title: NSLocalizedString("스캔해서 글자 넣기", comment: "Scan text into the value row title"),
                        caption: NSLocalizedString("사진 속 글자만 읽어 와요. 사진은 저장되지 않아요",
                                                   comment: "Scan text into the value row caption")
                    )
                }
                .disabled(isRecognizingText)

                // 그림 자체가 값이 되는 길. 위와 달리 사진이 **남는다.**
                Button {
                    showImagePicker = true
                } label: {
                    sourceRow(
                        symbol: AppSymbol.photoBadgePlus,
                        title: NSLocalizedString("이미지 붙이기", comment: "Attach image row title"),
                        caption: NSLocalizedString("사진을 그대로 담아요. 누르면 사진이 복사돼요",
                                                   comment: "Attach image row caption")
                    )
                }
                .buttonStyle(.plain)
            }
            // 두 줄을 **한 덩어리로** 짚는다. 줄마다 따로 빛나면 둘 중 하나를 꼭
            // 골라야 하는 것처럼 보이는데, 여기는 안 골라도 되는 자리다.
            .memoAddCoachRipple(coachStep == .inputMethod, radius: theme.radiusMd)

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
                .memoAddCoachRipple(coachStep == .content, radius: theme.radiusMd)
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
        // 문질러 담기 - 사진에서 **필요한 곳만** 손가락으로 쓸어 담는 기본 길.
        .sheet(item: $smearSource) { source in
            SmearTextPickerView(
                image: source.image,
                layout: source.layout,
                onPick: { picked in
                    value = picked
                    showToastMessage(NSLocalizedString("사진에서 값을 넣었습니다", comment: "Filled value from photo toast"))
                },
                onSwitchToLineList: {
                    // 문지르기 어려운 사람(VoiceOver·손 떨림)을 위한 다른 길.
                    // ⚠️ 시트가 닫히는 중에 다음 시트를 띄우면 삼켜진다 - 닫힘을 기다렸다 연다.
                    let lines = source.layout.plainLines
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        recognizedLines = lines
                    }
                }
            )
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

    /// 값을 채우는 길 한 줄. 이름만으로는 둘이 헷갈린다 - **무엇이 값이 되는지**를 함께 적는다.
    ///
    /// ⚠️ 글자를 자르지 않는다. 큰 글씨(Dynamic Type)에서도 설명이 접혀 내려갈 뿐
    ///    말줄임으로 사라지지 않아야, 두 길의 차이가 끝까지 읽힌다.
    private func sourceRow(symbol: String, title: String, caption: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.accent)
                .frame(width: 34, height: 34)
                .background(Circle().fill(theme.accentSoft))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.text)
                Text(caption)
                    .font(.caption)
                    .foregroundColor(theme.textMuted)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: AppSymbol.chevronRight)
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.textFaint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(title)
        .accessibilityHint(caption)
    }

    /// 고른 사진에서 글자를 읽어 **문질러 담는 화면**으로 넘긴다.
    ///
    /// ⚠️ 읽은 것을 값에 곧바로 쏟아붓지 않는다. 카드 한 장에서도 카드사 이름·영문 이름·
    ///    유효기간이 함께 읽히는데, 전부 넣으면 사용자가 지우는 일을 하게 된다
    ///    손으로 치는 것보다 나을 게 없다. 필요한 곳만 **손가락으로 쓸어 담게** 해야
    ///    사진이 입력을 대신한다.
    ///
    /// ⚠️ 사진 자체는 첨부하지 않는다. 여기서 사진은 글자를 담아 온 그릇일 뿐이고,
    ///    첨부는 옆의 '이미지' 버튼이 하는 다른 일이다.
    private func recognizeText(in image: UIImage?) {
        guard let image else { return }
        isRecognizingText = true
        // 글자만이 아니라 **글자가 어디에 있는지**까지 읽는다 - 손가락으로 고르려면 자리가 필요하다.
        OCRService.shared.recognizeLayout(from: image) { layout in
            isRecognizingText = false
            guard !layout.isEmpty else {
                showNoTextFound = true
                return
            }
            smearSource = SmearSource(image: image, layout: layout)
        }
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
                    .foregroundColor(isOn ? Color.checkGreen : theme.textFaint)
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

// MARK: - 배운 캐럿 자리 스위치

/// 키보드가 스스로 배운 "넣은 뒤 캐럿이 설 자리"를 끄고 켜는 줄.
///
/// ⚠️ 이건 **끄는 스위치이지 켜는 스위치가 아니다.** 켜는 일은 사용자가 같은 자리로
///    세 번 돌아갔을 때 앱이 알아서 한다. 여기까지 오는 사람은 "왜 커서가 여기 서지?"를
///    묻는 사람이라, 답 한 줄과 되돌리는 길만 있으면 된다.
///
/// ⚠️ `CursorMemory` 는 관찰 가능한 물건이 아니라(App Group UserDefaults 다) 상태를
///    여기서 들고 있어야 스위치가 즉시 반응한다.
struct CursorMemoryToggleRow: View {
    let memoId: UUID
    @State private var isOn: Bool = true

    var body: some View {
        ToggleOptionRow(
            activeIcon: AppSymbol.textCursor,
            inactiveIcon: AppSymbol.textCursor,
            title: NSLocalizedString("넣은 뒤 커서 자리 기억", comment: "Learned caret position toggle"),
            description: NSLocalizedString("여기서 자주 이어 쓰셔서 커서를 그 자리에 세워요", comment: "Learned caret position toggle description"),
            activeColor: .accentColor,
            isOn: Binding(
                get: { isOn },
                set: { newValue in
                    isOn = newValue
                    if newValue { CursorMemory.turnOn(for: memoId) }
                    else { CursorMemory.turnOff(for: memoId) }
                }
            )
        )
        .onAppear { isOn = !(CursorMemory.learned(for: memoId)?.off ?? false) }
    }
}
