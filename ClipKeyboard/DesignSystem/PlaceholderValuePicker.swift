//
//  PlaceholderValuePicker.swift
//  ClipKeyboard / ClipKeyboardExtension
//
//  빈칸에 저장해 둔 값을 **어떤 모양으로 늘어놓을지.** 키보드와 앱의 채우기 창이 같이 본다.
//
//  왜 필요한가: 값은 가로 칩 한 줄로만 나왔다. 이름·금액처럼 짧은 값에는 그게 가장 빠르다.
//  그런데 주소·자기소개·메일 문단처럼 긴 값은 **칩 하나가 화면보다 넓어져서**, 한 값을 다
//  읽으려면 옆으로 한참 밀어야 했고 다음 값이 어디서 시작하는지도 안 보였다.
//  ("List blanks vertically. Scrolling blanks horizontally is a bit difficult when the blanks are long.")
//
//  정한 것:
//   - 값 하나라도 길면 그 빈칸은 **세로 목록**이다. 한 줄에 값 하나, 두 줄까지 보인다.
//   - 모두 짧으면 지금처럼 가로 칩이다. 짧은 값을 쓰는 사람에게는 아무것도 바뀌지 않는다.
//   - 설정으로 두지 않는다. 고를 일이 아니라 값이 정하는 일이다.
//
//  ⚠️ 빈칸마다 따로 정한다. 주소 빈칸이 목록이 된다고 같은 템플릿의 이름 빈칸까지 목록이
//     되면, 짧은 값의 빠른 칩을 잃는다.
//
//  ⚠️ 길이는 **글자 수가 아니라 눈에 보이는 너비**로 잰다. 한글·한자·가나는 영문 두 자만큼
//     넓다. 글자 수로 재면 같은 너비의 한국어 주소가 영어 주소보다 짧다고 판정된다.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 모양 정하기

enum PlaceholderValueLayout: Equatable {
    /// 가로로 미는 칩 한 줄.
    case chips
    /// 위에서 아래로, 한 줄에 값 하나.
    case list

    /// 이 너비(영문 한 자 = 1)를 넘으면 긴 값이다.
    /// 키보드 폭에서 칩 하나가 한 줄의 절반을 넘기 시작하는 자리다.
    static let longValueWidth = 20

    /// 저장된 값들(과 다음 번호)을 보고 모양을 정한다.
    static func resolve(for values: [String]) -> PlaceholderValueLayout {
        values.contains(where: isLong) ? .list : .chips
    }

    /// 긴 값인가. 줄바꿈이 들어 있으면 길이와 상관없이 길다 - 칩은 한 줄로 눌러 버린다.
    static func isLong(_ value: String) -> Bool {
        value.contains(where: \.isNewline) || displayWidth(of: value) > longValueWidth
    }

    /// 눈에 보이는 너비. 한글·한자·가나·전각 문자는 2, 나머지는 1.
    static func displayWidth(of value: String) -> Int {
        value.unicodeScalars.reduce(0) { $0 + (isWide($1) ? 2 : 1) }
    }

    private static func isWide(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x1100...0x115F,   // 한글 자모
             0x2E80...0x303E,   // CJK 부수 · 구두점
             0x3041...0x33FF,   // 가나 · 호환 자모
             0x3400...0x4DBF,   // CJK 확장 A
             0x4E00...0x9FFF,   // CJK 통합 한자
             0xAC00...0xD7A3,   // 한글 음절
             0xF900...0xFAFF,   // CJK 호환 한자
             0xFF00...0xFF60,   // 전각 문자
             0xFFE0...0xFFE6:
            return true
        default:
            return false
        }
    }
}

// MARK: - 세로 목록

/// 긴 값을 고르는 세로 목록. 키보드(`PlaceholderInputView`)와 앱(`TemplateFillRow`)이 같이 쓴다.
///
/// ⚠️ 고른 줄은 칩과 **같은 색**이다(강조색 바탕). 모양이 칩에서 줄로 바뀌어도
///    "무엇을 골랐나"를 읽는 법은 같아야 한다. 색만으로 말하지 않도록 체크 표시를 함께 둔다.
///
/// ⚠️ `visibleLimit` 를 주면 그만큼만 보이고 나머지는 "더 보기" 로 펼친다. 키보드는 높이가
///    정해져 있어 값이 열 개면 다른 빈칸을 다 밀어낸다. 고른 값이 접힌 쪽에 있으면 처음부터
///    펼쳐 둔다 - 고른 것이 안 보이면 "이 칸은 채웠나?" 에 답할 수 없다.
struct PlaceholderValueList<RowDecoration: View>: View {
    let values: [String]
    /// 다음 차례 값(`PlaceholderSequence`). 맨 위에 "다음" 이라고 적혀 선다.
    let nextValue: String?
    @Binding var selection: String
    let theme: AppTheme
    var visibleLimit: Int? = nil
    var onSelect: () -> Void = {}
    /// 줄 위에 얹을 것(튜토리얼의 파형 등). 값과 고른 여부를 받는다.
    @ViewBuilder var decoration: (_ value: String, _ isSelected: Bool) -> RowDecoration

    @State private var expanded = false

    private var hiddenCount: Int {
        guard let limit = visibleLimit else { return 0 }
        // 하나 숨기려고 "1개 더" 단추를 두느니 그냥 보여 준다.
        return values.count > limit + 1 ? values.count - limit : 0
    }

    private var showsAll: Bool {
        if expanded || hiddenCount == 0 { return true }
        // 고른 값이 접힌 쪽에 있으면 펼친 채로 보여 준다.
        guard let limit = visibleLimit, let index = values.firstIndex(of: selection) else { return false }
        return index >= limit
    }

    private var shownValues: [String] {
        guard !showsAll, let limit = visibleLimit else { return values }
        return Array(values.prefix(limit))
    }

    var body: some View {
        VStack(spacing: 6) {
            if let next = nextValue {
                row(next, label: String(format: NSLocalizedString("다음 %@", comment: "Placeholder chip: next value in a sequence, e.g. next invoice number"), next),
                    isNext: true)
                    .accessibilityLabel(String(format: NSLocalizedString("다음 차례 값 %@", comment: "Accessibility: next value in a sequence"), next))
            }
            ForEach(shownValues, id: \.self) { value in
                row(value, label: value, isNext: false)
            }
            if hiddenCount > 0 {
                moreButton
            }
        }
    }

    private func row(_ value: String, label: String, isNext: Bool) -> some View {
        let isSelected = selection == value
        return Button {
            selection = value
            onSelect()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if isNext {
                    Image(systemName: AppSymbol.plusCircle)
                }
                Text(label)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(systemName: AppSymbol.checkmark)
                        .font(.body.weight(.semibold))
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundColor(isSelected ? theme.accentFg : (isNext ? theme.accent : .primary))
            .background(
                RoundedRectangle(cornerRadius: theme.radiusSm, style: .continuous)
                    .fill(isSelected ? theme.accent : (isNext ? theme.accentSoft : Color(UIColor.systemGray5)))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay { decoration(value, isSelected) }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var moreButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(showsAll
                     ? NSLocalizedString("접기", comment: "Placeholder value list: collapse")
                     : String(format: NSLocalizedString("%lld개 더 보기", comment: "Placeholder value list: show N more values"), hiddenCount))
                Image(systemName: showsAll ? AppSymbol.chevronUp : AppSymbol.chevronDown)
            }
            .font(.body.weight(.medium))
            .foregroundColor(theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension PlaceholderValueList where RowDecoration == EmptyView {
    init(values: [String],
         nextValue: String?,
         selection: Binding<String>,
         theme: AppTheme,
         visibleLimit: Int? = nil,
         onSelect: @escaping () -> Void = {}) {
        self.init(values: values, nextValue: nextValue, selection: selection, theme: theme,
                  visibleLimit: visibleLimit, onSelect: onSelect) { _, _ in EmptyView() }
    }
}
