//
//  QuickPatterns.swift
//  ClipKeyboard
//
//  새 메모 작성 허들을 낮추는 패턴 데이터 + 고스트 제안 카드.
//  계좌번호·주소·연락처처럼 예상되는 형식을 제목(키) + 구조화된 값 골격으로
//  미리 갖춰두고, 메인 화면에 "이런 메모는 어때요?" 흐릿한 카드로 제안한다.
//  로케일(ko/id/en)별로 실제 맥락에 맞는 골격을 제공한다.
//

import SwiftUI

/// 한 탭으로 채워지는 입력 형식.
struct QuickPattern: Identifiable {
    let id = UUID()
    let icon: String
    /// 제목(키) 제안.
    let title: String
    /// 값 골격 — 라벨만 둔 빈칸 또는 {플레이스홀더}.
    let scaffold: String

    static var defaults: [QuickPattern] {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        switch lang {
        case "ko": return korean
        case "id": return indonesian
        default:   return english
        }
    }

    private static let korean: [QuickPattern] = [
        QuickPattern(icon: "banknote.fill", title: "계좌번호",
                     scaffold: "은행: \n예금주: \n계좌번호: "),
        QuickPattern(icon: "creditcard.fill", title: "카드 정보",
                     scaffold: "카드번호: \n유효기간(MM/YY): "),
        QuickPattern(icon: "location.fill", title: "주소",
                     scaffold: "받는 분: \n연락처: \n주소: "),
        QuickPattern(icon: "person.crop.circle.fill", title: "연락처",
                     scaffold: "이름: \n전화: \n이메일: "),
        QuickPattern(icon: "wifi", title: "와이파이",
                     scaffold: "네트워크: \n비밀번호: "),
        QuickPattern(icon: "text.bubble.fill", title: "자기소개",
                     scaffold: "안녕하세요, {이름}입니다.\n{소속/직함}\n연락처: {연락처}"),
    ]

    private static let english: [QuickPattern] = [
        QuickPattern(icon: "banknote.fill", title: "Bank account",
                     scaffold: "Bank: \nName: \nAccount: "),
        QuickPattern(icon: "creditcard.fill", title: "Card info",
                     scaffold: "Card number: \nExpiry (MM/YY): "),
        QuickPattern(icon: "location.fill", title: "Address",
                     scaffold: "Recipient: \nPhone: \nAddress: "),
        QuickPattern(icon: "person.crop.circle.fill", title: "Contact",
                     scaffold: "Name: \nPhone: \nEmail: "),
        QuickPattern(icon: "wifi", title: "Wi-Fi",
                     scaffold: "Network: \nPassword: "),
        QuickPattern(icon: "text.bubble.fill", title: "Intro",
                     scaffold: "Hi, I'm {name}.\n{role / company}\nContact: {contact}"),
    ]

    private static let indonesian: [QuickPattern] = [
        QuickPattern(icon: "banknote.fill", title: "Rekening",
                     scaffold: "Bank: \nA/N: \nNo. Rekening: "),
        QuickPattern(icon: "creditcard.fill", title: "Kartu",
                     scaffold: "Nomor kartu: \nMasa berlaku (MM/YY): "),
        QuickPattern(icon: "location.fill", title: "Alamat",
                     scaffold: "Penerima: \nTelepon: \nAlamat: "),
        QuickPattern(icon: "person.crop.circle.fill", title: "Kontak",
                     scaffold: "Nama: \nTelepon: \nEmail: "),
        QuickPattern(icon: "wifi", title: "Wi-Fi",
                     scaffold: "Jaringan: \nKata sandi: "),
        QuickPattern(icon: "text.bubble.fill", title: "Perkenalan",
                     scaffold: "Halo, saya {nama}.\n{jabatan / perusahaan}\nKontak: {kontak}"),
    ]
}

/// 메인 화면에 흐릿하게 떠 있는 "고스트 메모" 제안 카드.
/// "이런 메모는 어때요?" — 추가(채워서 만들기) / 닫기(제안 끄기) 중 선택.
struct GhostMemoSuggestionCard: View {
    @Environment(\.appTheme) private var theme
    let pattern: QuickPattern
    let onAdd: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .accessibilityHidden(true)
                Text(NSLocalizedString("이런 메모는 어때요?", comment: "Ghost suggestion header"))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.textMuted)
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Image(systemName: pattern.icon)
                    .font(.body)
                    .foregroundColor(.blue)
                    .frame(width: 34, height: 34)
                    .background(Color.blue.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pattern.title)
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.text)
                    Text(previewText)
                        .font(.caption)
                        .foregroundColor(theme.textFaint)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button(action: onAdd) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("추가", comment: "Add"))
                            .font(.callout.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.blue)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityHint(String(format: NSLocalizedString("%@ 메모를 채워서 추가", comment: "VoiceOver: add ghost memo hint"), pattern.title))

                Button(action: onDismiss) {
                    Text(NSLocalizedString("닫기", comment: "Close / dismiss"))
                        .font(.callout)
                        .foregroundColor(theme.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(theme.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                .strokeBorder(theme.divider, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(format: NSLocalizedString("추천 메모 %@", comment: "VoiceOver: suggested memo"), pattern.title))
    }

    /// 값 골격을 한 줄 힌트로 — "은행: · 예금주: · 계좌번호:".
    private var previewText: String {
        pattern.scaffold
            .replacingOccurrences(of: "\n", with: " · ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
