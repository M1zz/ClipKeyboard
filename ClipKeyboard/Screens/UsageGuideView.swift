//
//  UsageGuideView.swift
//  ClipKeyboard
//
//  디지털 노마드 프리랜서 관점의 활용 시나리오 모음. 각 시나리오는 탭 한 번으로
//  메모로 저장할 수 있도록 MemoAdd로 연결된다.
//

import SwiftUI

// MARK: - Model

/// 각 시나리오 하나.
private struct UsageScenario: Identifiable {
    let id = UUID()
    let titleKey: String       // 상황 제목
    let contextKey: String?    // 상대방이 던진 질문·맥락 (없으면 숨김)
    let exampleKey: String     // 보낼 내용 예시 (메모 저장 시 value로 사용)
    let feature: ScenarioFeature

    var title: String { NSLocalizedString(titleKey, comment: "Usage scenario title") }
    var context: String? {
        guard let key = contextKey else { return nil }
        return NSLocalizedString(key, comment: "Usage scenario context")
    }
    var example: String { NSLocalizedString(exampleKey, comment: "Usage scenario example") }
}

private enum ScenarioFeature: String {
    case memo, template, combo, smartClipboard

    var label: String {
        switch self {
        case .memo: return NSLocalizedString("Memo", comment: "Feature tag: memo")
        case .template: return NSLocalizedString("Template", comment: "Feature tag: template")
        case .combo: return NSLocalizedString("Combo", comment: "Feature tag: combo")
        case .smartClipboard: return NSLocalizedString("Smart Clipboard", comment: "Feature tag: smart clipboard")
        }
    }

    var color: Color {
        switch self {
        case .memo: return .blue
        case .template: return .orange
        case .combo: return .purple
        case .smartClipboard: return .green
        }
    }
}

/// 카테고리 (섹션).
private struct UsageCategory: Identifiable {
    let id = UUID()
    let emoji: String
    let titleKey: String
    let descKey: String
    let scenarios: [UsageScenario]

    var title: String { NSLocalizedString(titleKey, comment: "Usage category title") }
    var desc: String { NSLocalizedString(descKey, comment: "Usage category description") }
}

// MARK: - Data

private let usageCategories: [UsageCategory] = [
    // 1. 결제·금융
    UsageCategory(
        emoji: "💰",
        titleKey: "Banking & Payments",
        descKey: "Wire transfers, VAT, invoicing — save once, tap forever.",
        scenarios: [
            UsageScenario(
                titleKey: "New client wire transfer info",
                contextKey: "Please send your banking details for wire transfer.",
                exampleKey: "Name: [Your Name]\nIBAN: [Your IBAN]\nSWIFT: [Your SWIFT/BIC]\nAddress: [Your Registered Address]\nVAT ID: [Your VAT Number]",
                feature: .combo
            ),
            UsageScenario(
                titleKey: "Wise / PayPal quick share",
                contextKey: "Can you send your Wise details?",
                exampleKey: "Wise email: you@example.com\nPayPal: you@example.com\n(Prefer Wise — faster + lower fees for {currency})",
                feature: .memo
            ),
            UsageScenario(
                titleKey: "Invoice summary",
                contextKey: nil,
                exampleKey: "Invoice #{invoice_no} · {currency} {amount}\nDue: {due_date}\nPayment: Wise ([email])",
                feature: .template
            ),
        ]
    ),

    // 2. 타임존
    UsageCategory(
        emoji: "🌏",
        titleKey: "Timezone & availability",
        descKey: "Explaining your time, once.",
        scenarios: [
            UsageScenario(
                titleKey: "Quick timezone reply",
                contextKey: "When can we jump on a call?",
                exampleKey: "Hi {client}, I'm in GMT+{offset} right now ({city}). I can do {time_window}. Calendly: {link}",
                feature: .template
            ),
            UsageScenario(
                titleKey: "Signing off for the night",
                contextKey: "Urgent DM at 10pm",
                exampleKey: "Hi! Signing off for the night ({time} in {city}, GMT+{offset}). Will reply first thing tomorrow.",
                feature: .template
            ),
            UsageScenario(
                titleKey: "Crossing borders update",
                contextKey: nil,
                exampleKey: "Quick heads-up: I'm crossing borders today ({from} → {to}), so replies will be slower until ~{eta}. Everything is on track on my end.",
                feature: .template
            ),
        ]
    ),

    // 3. 비원어민 프로페셔널 영어
    UsageCategory(
        emoji: "✍️",
        titleKey: "Professional English",
        descKey: "30 non-native-speaker-friendly templates.",
        scenarios: [
            UsageScenario(
                titleKey: "Proposal follow-up (3 days silent)",
                contextKey: "Sent a proposal but no reply yet",
                exampleKey: "Hi {client}, just wanted to follow up on the proposal I sent Monday. Happy to jump on a quick call if anything needs clarifying.\n\nBest, {name}",
                feature: .template
            ),
            UsageScenario(
                titleKey: "Payment reminder (overdue)",
                contextKey: "Invoice is past due",
                exampleKey: "Hi {client}, just a kind reminder about invoice #{invoice_no} (due {due_date}, now {days} days overdue). Let me know if there's any issue on your end — happy to help resolve.",
                feature: .template
            ),
            UsageScenario(
                titleKey: "Scope pushback (politely)",
                contextKey: "Client requests something outside scope",
                exampleKey: "Hi {client}, happy to take this on — it falls outside our original scope ({original_scope}), so I'll send an updated quote for this add-on. Does that work?",
                feature: .template
            ),
            UsageScenario(
                titleKey: "Delivery delay heads-up",
                contextKey: nil,
                exampleKey: "Hi {client}, giving you a heads-up — {reason}, so I'm pushing the delivery to {new_date}. I'll send a progress preview tomorrow so you're not left in the dark.",
                feature: .template
            ),
            UsageScenario(
                titleKey: "Asking for testimonial",
                contextKey: "After successful project wrap-up",
                exampleKey: "Hi {client}, if you enjoyed working together, a short testimonial (2–3 sentences) for my site would mean a lot. No pressure at all — only if it's easy.",
                feature: .template
            ),
        ]
    ),

    // 4. 플랫폼별 반복
    UsageCategory(
        emoji: "📧",
        titleKey: "Per-platform shortcuts",
        descKey: "Upwork, LinkedIn, Gmail — templates that ship.",
        scenarios: [
            UsageScenario(
                titleKey: "Upwork proposal intro",
                contextKey: "Writing cover letters in bulk",
                exampleKey: "Hi {client_name}, I noticed you're hiring for {role}. I've worked on similar projects for {reference} — here's a quick overview: {portfolio}. Open to a 15-min chat?",
                feature: .template
            ),
            UsageScenario(
                titleKey: "LinkedIn cold DM",
                contextKey: nil,
                exampleKey: "Hi {name}, noticed you're hiring for {role} at {company}. I've worked on similar projects for {reference_client} — here's a quick overview: {portfolio_link}. Open to a 15-min chat this week?",
                feature: .template
            ),
            UsageScenario(
                titleKey: "Gmail: new client onboarding",
                contextKey: nil,
                exampleKey: "Welcome aboard, {client}! Here's what to expect:\n\n1. Calendly for our first sync: {calendly}\n2. Banking info below (if paying by wire)\n3. Slack channel invite coming in 24h\n4. Progress demos every Thursday\n\nLooking forward to working together!",
                feature: .combo
            ),
        ]
    ),

    // 5. 노마드 라이프
    UsageCategory(
        emoji: "🏦",
        titleKey: "Nomad life essentials",
        descKey: "Wifi drops, visa runs, location questions.",
        scenarios: [
            UsageScenario(
                titleKey: "Wifi dropped — back online",
                contextKey: "Client is waiting for you",
                exampleKey: "Hi team, wifi at my co-working just dropped. Back online now from a backup spot. Ready to continue whenever you are.",
                feature: .memo
            ),
            UsageScenario(
                titleKey: "\"Where are you based?\" answer",
                contextKey: "New client asks out of curiosity",
                exampleKey: "Based nowhere in particular — currently in {city}. I've set up for async-first communication so timezones usually don't matter, but I'll give you a clear window when I'm reachable.",
                feature: .template
            ),
        ]
    ),

    // 6. 스마트 클립보드
    UsageCategory(
        emoji: "🧠",
        titleKey: "Smart Clipboard",
        descKey: "Auto-classifies what you copy — find it later instantly.",
        scenarios: [
            UsageScenario(
                titleKey: "Client's IBAN → filed automatically",
                contextKey: "Copy IBAN from Wise / Revolut",
                exampleKey: "Copy any IBAN — the app auto-tags it as \"IBAN\". Find it later under the IBAN filter without searching.",
                feature: .smartClipboard
            ),
            UsageScenario(
                titleKey: "Stripe dashboard links",
                contextKey: "Sending payment confirmation link",
                exampleKey: "Copied Stripe URLs are auto-tagged as \"URL\". Pull them up anytime from the clipboard history.",
                feature: .smartClipboard
            ),
            UsageScenario(
                titleKey: "VAT / Tax ID detection",
                contextKey: nil,
                exampleKey: "Copy a VAT number in format PT123456789 or EU123456789 — the app recognizes it as \"VAT / Tax ID\" and masks on display.",
                feature: .smartClipboard
            ),
        ]
    ),
]

// MARK: - View

struct UsageGuideView: View {
    @Environment(\.appTheme) private var theme
    @State private var expanded: Set<UUID> = Set(usageCategories.prefix(1).map { $0.id })

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroHeader

                ForEach(usageCategories) { category in
                    categorySection(category: category)
                }

                Spacer(minLength: 40)
            }
            .padding(16)
        }
        .background(theme.bg.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("Usage scenarios", comment: "Screen title: usage guide"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Subviews

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("Your day as a remote freelancer", comment: "Usage guide hero title"))
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundColor(theme.text)
            Text(NSLocalizedString("18 moments where ClipKeyboard saves you minutes — or rescues a mistake.", comment: "Usage guide hero subtitle"))
                .font(.system(size: 14))
                .foregroundColor(theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func categorySection(category: UsageCategory) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                HapticManager.shared.soft()
                withAnimation(.easeInOut(duration: 0.22)) {
                    if expanded.contains(category.id) {
                        expanded.remove(category.id)
                    } else {
                        expanded.insert(category.id)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Text(category.emoji)
                        .font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(theme.text)
                        Text(category.desc)
                            .font(.system(size: 12))
                            .foregroundColor(theme.textMuted)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: expanded.contains(category.id) ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textFaint)
                }
                .padding(14)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())

            if expanded.contains(category.id) {
                VStack(spacing: 10) {
                    ForEach(category.scenarios) { scenario in
                        scenarioCard(scenario)
                    }
                }
                .padding(.top, 10)
            }
        }
    }

    private func scenarioCard(_ scenario: UsageScenario) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Text(scenario.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.text)
                Spacer()
                featureBadge(scenario.feature)
            }

            if let context = scenario.context {
                HStack(spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 10))
                        .foregroundColor(theme.textFaint)
                    Text(context)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textMuted)
                        .italic()
                }
            }

            Text(scenario.example)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(theme.text)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .textSelection(.enabled)

            HStack(spacing: 8) {
                NavigationLink {
                    MemoAdd(
                        insertedKeyword: scenario.title,
                        insertedValue: scenario.example
                    )
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text(NSLocalizedString("Save as memo", comment: "CTA: save scenario as memo"))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.blue)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    HapticManager.shared.light()
                    #if os(iOS)
                    UIPasteboard.general.string = scenario.example
                    #endif
                } label: {
                    Text(NSLocalizedString("Copy", comment: "CTA: copy scenario text"))
                        .font(.system(size: 13))
                        .foregroundColor(theme.textMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }
        }
        .padding(14)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.divider, lineWidth: 0.5)
        )
    }

    private func featureBadge(_ feature: ScenarioFeature) -> some View {
        Text(feature.label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(feature.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(feature.color.opacity(0.12))
            .clipShape(Capsule())
    }
}

#if DEBUG
struct UsageGuideView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            UsageGuideView()
        }
    }
}
#endif
