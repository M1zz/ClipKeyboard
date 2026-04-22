//
//  CatIcon.swift
//  ClipKeyboard
//
//  카테고리별 hue-tinted 둥근 사각 아이콘. design-handoff OKLCH 팔레트를
//  HSB 근사값으로 변환해 light/dark 모두 대응.
//

import SwiftUI

/// 디자인 핸드오프의 6개 카테고리.
enum ClipCategory: String, CaseIterable {
    case address, email, phone, url, card, text

    /// `ClipboardItemType` → 디자인 카테고리 매핑. handoff에 없는 타입은 text로.
    static func from(itemType: ClipboardItemType?) -> ClipCategory {
        guard let t = itemType else { return .text }
        switch t {
        case .address: return .address
        case .email: return .email
        case .phone: return .phone
        case .url, .paypalLink: return .url
        case .creditCard, .bankAccount, .iban, .swift, .vat: return .card
        default: return .text
        }
    }

    var systemSymbol: String {
        switch self {
        case .address: return "mappin.and.ellipse"
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .url: return "link"
        case .card: return "creditcard.fill"
        case .text: return "text.alignleft"
        }
    }

    var localizedLabel: String {
        switch self {
        case .address: return NSLocalizedString("Address", comment: "Category: address")
        case .email: return NSLocalizedString("Email", comment: "Category: email")
        case .phone: return NSLocalizedString("Phone", comment: "Category: phone")
        case .url: return NSLocalizedString("Link", comment: "Category: link")
        case .card: return NSLocalizedString("Card", comment: "Category: card")
        case .text: return NSLocalizedString("Text", comment: "Category: text")
        }
    }
}

/// OKLCH 기반 hue/chroma를 HSB로 근사. handoff의 catHue map과 매칭.
private struct CategoryHue {
    let hue: Double       // 0.0–1.0 (SwiftUI HSB)
    let chroma: Double    // 0.0–1.0 근사
}

private extension ClipCategory {
    var hue: CategoryHue {
        switch self {
        // handoff: OKLCH hue angles → degrees → normalized
        case .address: return .init(hue: 280.0 / 360, chroma: 0.15)  // purple
        case .email:   return .init(hue: 210.0 / 360, chroma: 0.14)  // blue
        case .phone:   return .init(hue: 150.0 / 360, chroma: 0.14)  // green
        case .url:     return .init(hue: 30.0  / 360, chroma: 0.15)  // orange
        case .card:    return .init(hue: 340.0 / 360, chroma: 0.15)  // pink
        case .text:    return .init(hue: 60.0  / 360, chroma: 0.12)  // yellow
        }
    }

    /// 배경색 — 옅은 틴트.
    func backgroundColor(isDark: Bool) -> Color {
        let h = hue
        if isDark {
            // oklch(0.3, chroma*0.6, hue) 근사 — 어둡고 낮은 채도
            return Color(hue: h.hue, saturation: h.chroma * 2.0, brightness: 0.25)
        } else {
            // oklch(0.92, chroma*0.5, hue) 근사 — 매우 옅은 틴트
            return Color(hue: h.hue, saturation: h.chroma * 1.2, brightness: 0.96)
        }
    }

    /// 전경(아이콘) 색 — 중간 채도.
    func foregroundColor(isDark: Bool) -> Color {
        let h = hue
        if isDark {
            // oklch(0.85, chroma, hue) 근사
            return Color(hue: h.hue, saturation: h.chroma * 2.2, brightness: 0.82)
        } else {
            // oklch(0.5, chroma, hue) 근사
            return Color(hue: h.hue, saturation: h.chroma * 3.2, brightness: 0.55)
        }
    }
}

struct CatIcon: View {
    let category: ClipCategory
    var size: CGFloat = 40

    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(category.backgroundColor(isDark: theme.isDark))
            Image(systemName: category.systemSymbol)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundColor(category.foregroundColor(isDark: theme.isDark))
        }
        .frame(width: size, height: size)
    }
}
