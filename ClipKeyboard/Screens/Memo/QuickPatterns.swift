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
import LeeoKit

/// 한 탭으로 채워지는 입력 형식.
struct QuickPattern: Identifiable {
    let id = UUID()
    let icon: String
    /// 제목(키) 제안.
    let title: String
    /// 값 골격 - 라벨만 둔 빈칸 또는 {플레이스홀더}.
    let scaffold: String

    static var defaults: [QuickPattern] {
        let lang = AppLanguage.contentLanguageCode
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
                     scaffold: "안녕하세요, {이름}입니다.\n{소속/직함}\n연락처: {연락처}")
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
                     scaffold: "Hi, I'm {name}.\n{role / company}\nContact: {contact}")
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
                     scaffold: "Halo, saya {nama}.\n{jabatan / perusahaan}\nKontak: {kontak}")
    ]
}

// MARK: - 이름으로 내용 짐작하기

/// 사람이 적은 **이름**("회사 이메일", "송금 계좌")에서 무엇을 담을지 읽고, 최근 복사해 둔 글 가운데
/// 같은 종류를 골라 붙여넣을 내용 아래에 세운다. 누르면 그 글이 내용이 된다.
///
/// 사용자 요청에서 왔다: "사용자가 입력한 Name shown on keyboard 로 그 아래쪽의 Content to paste 를 예측해 볼 수 있을까?"
/// ⚠️ 새로 읽어 오는 것은 없다. 이미 기기에 쌓인 복사 기록(`SmartClipboardHistory`, 자동 분류 결과)만 본다.
///    클립보드를 지금 읽으면 iOS 가 붙여넣기 허락을 묻는다.
/// ⚠️ 지어내지 않는다. 이름만으로 값을 만들 수는 없다(이메일 주소는 그 사람만 안다). 맞는 기록이 없으면 아무것도 세우지 않는다.
enum ContentPrediction {

    /// 이름에 이 말이 들어 있으면 그 종류다. **긴 말부터** 본다("우편번호" 가 "번호" 보다, "IP주소" 가 "주소" 보다 먼저).
    /// 종류의 표시 이름(지금 언어)과 한국어 이름은 따로 적지 않아도 함께 본다(`type(forTitle:)`).
    static let keywords: [ClipboardItemType: [String]] = [
        .email: ["이메일", "메일", "email", "e-mail", "mail", "邮箱", "郵箱", "メール", "почта"],
        .phone: ["전화", "휴대폰", "핸드폰", "폰번호", "연락처", "phone", "mobile", "cell", "tel", "电话", "電話", "手机", "телефон"],
        .address: ["주소", "배송지", "address", "地址", "住所", "адрес"],
        .bankAccount: ["계좌", "통장", "송금", "입금", "account", "bank", "账号", "帳號", "口座", "счёт", "счет"],
        .creditCard: ["카드번호", "카드", "card", "卡号", "カード"],
        .url: ["링크", "홈페이지", "사이트", "주소창", "url", "link", "website", "网址", "リンク"],
        .postalCode: ["우편번호", "zip", "postal", "postcode", "邮编", "郵便番号"],
        .ipAddress: ["ip주소", "ip address"],
        .passportNumber: ["여권", "passport", "护照", "パスポート"],
        .trackingNumber: ["송장", "운송장", "tracking"],
        .vehiclePlate: ["차량번호", "차번호", "번호판", "plate"],
        .iban: ["iban"],
        .swift: ["swift", "bic"],
        .cryptoWallet: ["지갑", "wallet"],
        .paypalLink: ["paypal"],
    ]

    /// 이름이 말하는 종류. 모르면 nil.
    static func type(forTitle title: String) -> ClipboardItemType? {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count >= 2 else { return nil }
        // 말과 종류를 짝지어 긴 말부터 늘어놓는다.
        let table = ClipboardItemType.allCases.filter { $0 != .text && $0 != .image }
            .flatMap { type in ((keywords[type] ?? []) + [type.rawValue, type.localizedName]).map { ($0, type) } }
            .sorted { $0.0.count > $1.0.count }
        return table.first { contains(name, $0.0) }?.1
    }

    /// 로마자 말은 **낱말째** 맞춘다("Hotel" 의 tel 이 전화가 되지 않게). 한글 · 한자 · 가나는 띄어 쓰지 않고
    /// 붙여 쓰는 일이 많아("회사메일") 글자 안에서 찾는다.
    private static func contains(_ name: String, _ word: String) -> Bool {
        let options: String.CompareOptions = [.caseInsensitive, .widthInsensitive, .diacriticInsensitive]
        guard word.unicodeScalars.allSatisfy({ $0.isASCII }) else { return name.range(of: word, options: options) != nil }
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b"
        return name.range(of: pattern, options: options.union(.regularExpression)) != nil
    }

    /// 이름에 맞는 최근 복사 글. 새것부터, 같은 글은 한 번만.
    static func candidates(forTitle title: String, history: [SmartClipboardHistory], limit: Int = 3) -> [String] {
        guard let type = type(forTitle: title) else { return [] }
        var seen = Set<String>()
        return history
            .filter { $0.contentType == .text && ($0.userCorrectedType ?? $0.detectedType) == type }
            .sorted { $0.copiedAt > $1.copiedAt }
            .map { $0.content.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .prefix(limit)
            .map { $0 }
    }

    /// 칩에 보일 글. 남이 보면 곤란한 종류(카드 · 계좌 …)는 끝 네 자리만 보인다.
    static func preview(_ value: String, type: ClipboardItemType) -> String {
        let oneLine = value.replacingOccurrences(of: "\n", with: " ")
        guard type.isSensitive, oneLine.count > 4 else { return oneLine }
        return "•••• " + oneLine.suffix(4)
    }
}

/// 붙여넣을 내용 아래의 칩 줄. 내용이 비어 있고 이름에 맞는 복사 기록이 있을 때만 선다.
struct ContentPredictionRow: View {
    let title: String
    @Binding var value: String

    @Environment(\.appTheme) private var theme
    /// 복사 기록은 화면이 뜰 때 한 번 읽는다. 이름을 칠 때마다 파일을 열지 않는다.
    @State private var history: [SmartClipboardHistory] = []

    var body: some View {
        Group {
            if value.isEmpty, let type = ContentPrediction.type(forTitle: title) {
                let picks = ContentPrediction.candidates(forTitle: title, history: history)
                if !picks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(format: NSLocalizedString("최근 복사한 %@", comment: "Memo add: label above suggested values copied recently. %@ = kind of value, e.g. Email"),
                                    type.localizedName))
                            .font(.footnote)
                            .foregroundColor(theme.textMuted)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(picks, id: \.self) { pick in
                                    chip(pick, type: type)
                                }
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .task { history = (try? ClipboardHistoryStore.shared.load()) ?? [] }
    }

    private func chip(_ pick: String, type: ClipboardItemType) -> some View {
        let shown = ContentPrediction.preview(pick, type: type)
        return Button {
            HapticManager.shared.light()
            value = pick
        } label: {
            Label(shown, systemImage: AppSymbol.docOnClipboard)
                .font(.subheadline)
                .lineLimit(1)
                .frame(maxWidth: 240)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.surfaceAlt, in: Capsule())
                .foregroundColor(theme.text)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(shown)
        .accessibilityHint(NSLocalizedString("붙여넣을 내용에 넣어요", comment: "Memo add: hint for a suggested recent copy chip"))
    }
}
