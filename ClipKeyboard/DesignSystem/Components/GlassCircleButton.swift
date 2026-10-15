//
//  GlassCircleButton.swift
//  ClipKeyboard
//
//  이 앱의 시그니처 버튼. 목록 탭 머리의 + · 화면 전환 · 금고가 쓰는 **맑은 유리 서클**이다.
//  화면 머리(네비게이션 바, 직접 그린 머리말, 전체 화면의 닫기)에 서는 아이콘 버튼은
//  모두 이것을 쓴다. 모양·크기·색을 화면마다 다시 적지 않는다.
//

import SwiftUI

// MARK: - Tokens

/// 유리 서클의 규격. **값은 여기 한 곳에만 둔다.**
///
/// ⚠️ 예전에는 목록 툴바, 무대 머리말, 각 화면 툴바가 제각각 적었다. 목록은 44pt 유리 서클,
///    다른 화면은 맨몸 아이콘이나 회색 원, `xmark.circle.fill` 이라 같은 역할의 버튼이
///    화면마다 다른 앱에서 온 것처럼 보였다.
enum GlassCircle {
    /// 지름. 손가락이 닿는 최소 크기(44pt)와 같다.
    static let diameter: CGFloat = 44

    /// 나란히 선 서클 사이 간격. 음수로 두면 서클끼리 겹쳐 한 덩어리로 읽힌다.
    static let spacing: CGFloat = 6

    /// 아이콘 글꼴. 굵기는 semibold 하나다.
    static let iconFont: Font = .body.weight(.semibold)

    /// 유리. 하단 탭바와 같은 맑은 유리에 눌림 반응을 켠다.
    static let glass: Glass = .clear.interactive()
}

// MARK: - Role

/// 서클의 아이콘 색을 정하는 역할. 모양은 같고 **색만** 다르다.
enum GlassCircleRole {
    /// 추가·전환·저장처럼 앞으로 나아가는 일. 강조색.
    case primary
    /// 닫기·초기화·더보기처럼 곁의 일. 흐린 글자색.
    case secondary
}

// MARK: - Modifier

/// 아무 아이콘 뷰나 시그니처 서클로 감싼다. Menu 라벨처럼 Button 이 아닌 자리에서 쓴다.
private struct GlassCircleModifier: ViewModifier {
    let role: GlassCircleRole

    @Environment(\.appTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .font(GlassCircle.iconFont)
            .foregroundStyle(iconColor)
            .frame(width: GlassCircle.diameter, height: GlassCircle.diameter)
            .contentShape(Circle())
            .glassEffect(GlassCircle.glass, in: Circle())
    }

    /// ⚠️ 색을 직접 칠하므로 `.disabled` 가 저절로 흐려지지 않는다. 눌러도 안 되는 버튼이
    ///    멀쩡한 색으로 서 있으면 누른 사람은 앱이 멈춘 줄 안다.
    private var iconColor: Color {
        guard isEnabled else { return theme.textFaint.opacity(0.6) }
        switch role {
        case .primary: return .accentColor
        case .secondary: return theme.textMuted
        }
    }
}

extension View {
    /// 시그니처 유리 서클로 감싼다(`GlassCircle`).
    func glassCircle(_ role: GlassCircleRole = .primary) -> some View {
        modifier(GlassCircleModifier(role: role))
    }
}

// MARK: - Label

/// Menu 라벨용 서클 아이콘.
struct GlassCircleLabel: View {
    let systemImage: String
    var role: GlassCircleRole = .primary

    var body: some View {
        Image(systemName: systemImage)
            .glassCircle(role)
    }
}

// MARK: - Button

/// 시그니처 유리 서클 버튼.
///
/// ```swift
/// GlassCircleButton(AppSymbol.plus, label: NSLocalizedString("단축어 추가", comment: "")) { ... }
/// GlassCircleButton(AppSymbol.xmark, role: .secondary, label: NSLocalizedString("닫기", comment: "")) { dismiss() }
/// ```
///
/// 툴바에 둘 때는 그 `ToolbarItem` 에 `.sharedBackgroundVisibility(.hidden)` 을 붙인다.
/// 안 붙이면 시스템이 감싸는 유리 알약 위에 서클이 한 겹 더 얹혀 두 겹 유리가 된다.
///
/// 쓰지 않는 자리: 배너 안의 작은 닫기, 입력칸 지우기, 타일 위 지우기 단추.
/// 그것들은 화면 머리가 아니라 **내용의 일부**라 내용 크기에 맞춘다.
struct GlassCircleButton: View {
    let systemImage: String
    var role: GlassCircleRole = .primary
    let label: String
    let action: () -> Void

    init(_ systemImage: String,
         role: GlassCircleRole = .primary,
         label: String,
         action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.role = role
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            GlassCircleLabel(systemImage: systemImage, role: role)
        }
        .buttonStyle(.squish)
        .accessibilityLabel(label)
    }
}

// MARK: - Cluster

/// 서클 여럿을 나란히 세운다. 간격은 `GlassCircle.spacing` 하나다.
struct GlassCircleCluster<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: GlassCircle.spacing) { content }
    }
}
