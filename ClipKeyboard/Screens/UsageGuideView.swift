//
//  UsageGuideView.swift
//  ClipKeyboard
//
//  활용 시나리오 모음. 로케일(ko/id/en)에 따라 해당 나라의 실제 사용 맥락으로
//  완전히 다른 콘텐츠를 제공한다. MemoAdd 화면의 "활용사례에서 영감 받기"에서도 재사용.
//

import SwiftUI

// MARK: - Model

/// 각 시나리오 하나.
/// internal — 메모 추가 화면(MemoAdd)의 활용사례 토글에서 재사용.
struct UsageScenario: Identifiable {
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
    // 로케일별 콘텐츠는 exampleKey 자체가 이미 해당 언어로 작성된 실제 텍스트
    var example: String { exampleKey }
}

enum ScenarioFeature: String {
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
struct UsageCategory: Identifiable {
    let id = UUID()
    let emoji: String
    let titleKey: String
    let descKey: String
    let scenarios: [UsageScenario]

    var title: String { NSLocalizedString(titleKey, comment: "Usage category title") }
    var desc: String { NSLocalizedString(descKey, comment: "Usage category description") }
}

// MARK: - Locale-aware Data

/// 현재 로케일에 맞는 활용사례 배열.
/// UsageGuideView 와 MemoAdd(UsageScenarioPickerSheet) 양쪽에서 참조.
var usageCategories: [UsageCategory] {
    let lang = Locale.current.language.languageCode?.identifier ?? "en"
    switch lang {
    case "ko": return UsageScenarioData.korean
    case "id": return UsageScenarioData.indonesian
    default:   return UsageScenarioData.english
    }
}

// MARK: - Korean Scenarios (ko)

private enum UsageScenarioData {

    static let korean: [UsageCategory] = [

        // 1. 송금 & 계좌
        UsageCategory(
            emoji: "💰",
            titleKey: "송금 & 계좌",
            descKey: "계좌번호, 카카오페이, 토스 — 한 번 저장, 탭으로 전달.",
            scenarios: [
                UsageScenario(
                    titleKey: "계좌번호 공유",
                    contextKey: "계좌번호 알려주세요",
                    exampleKey: "은행: 카카오뱅크\n예금주: [이름]\n계좌번호: [계좌번호]\n\n(토스/카카오페이도 가능합니다 🙏)",
                    feature: .memo
                ),
                UsageScenario(
                    titleKey: "정산 요청",
                    contextKey: "이번 달 정산 어떻게 해?",
                    exampleKey: "안녕하세요! {월}월 정산 내역 보내드립니다.\n금액: {금액}원\n입금 계좌: 카카오뱅크 [계좌번호] ([이름])\n\n확인 부탁드립니다 😊",
                    feature: .template
                ),
                UsageScenario(
                    titleKey: "청구서 요약",
                    contextKey: nil,
                    exampleKey: "청구서 #{번호}\n금액: {금액}원 (VAT 포함)\n납기: {납기일}\n입금 계좌: [은행] [계좌번호] ([예금주])",
                    feature: .template
                ),
                UsageScenario(
                    titleKey: "N빵 정산",
                    contextKey: "오늘 밥값 얼마야?",
                    exampleKey: "오늘 총 {총금액}원이에요!\n{인원}명이니까 1인당 {1인금액}원 🙏\n카카오뱅크 [계좌번호] ([이름])으로 보내주세요~",
                    feature: .template
                ),
            ]
        ),

        // 2. 직장 & 업무
        UsageCategory(
            emoji: "💼",
            titleKey: "직장 & 업무",
            descKey: "부재중 답장, 회의 안내, 업무 보고 — 반복 문구를 탭 한 번으로.",
            scenarios: [
                UsageScenario(
                    titleKey: "부재중 자동응답",
                    contextKey: nil,
                    exampleKey: "안녕하세요. {날짜}부터 {날짜}까지 부재중입니다.\n급한 업무는 {담당자}({연락처})에게 연락 주세요.\n복귀 후 빠르게 회신하겠습니다. 감사합니다.",
                    feature: .template
                ),
                UsageScenario(
                    titleKey: "회의 일정 안내",
                    contextKey: nil,
                    exampleKey: "안녕하세요 {이름}님,\n\n아래 일정으로 미팅 요청드립니다.\n📅 일시: {날짜} {시간}\n📍 장소: {장소}\n📌 안건: {안건}\n\n참석 가능 여부 확인 부탁드립니다 😊",
                    feature: .template
                ),
                UsageScenario(
                    titleKey: "주간 업무 보고",
                    contextKey: nil,
                    exampleKey: "안녕하세요.\n금주 업무 진행 현황 보고드립니다.\n\n✅ 완료: {완료사항}\n🔄 진행 중: {진행중}\n📋 다음 주 예정: {예정사항}\n\n문의사항 있으시면 말씀해 주세요.",
                    feature: .template
                ),
                UsageScenario(
                    titleKey: "협업 제안",
                    contextKey: nil,
                    exampleKey: "안녕하세요 {담당자}님,\n\n{프로젝트}와 관련하여 협업을 제안드리고자 연락드립니다.\n저는 {회사/이름}에서 {업무}를 담당하고 있습니다.\n\n간단히 통화 가능하실까요? 편하신 시간 알려주세요.\n감사합니다.",
                    feature: .template
                ),
            ]
        ),

        // 3. 일상 & 배달
        UsageCategory(
            emoji: "🚚",
            titleKey: "일상 & 배달",
            descKey: "배송지, 약속 잡기, 자주 쓰는 주소 — 저장해두면 편합니다.",
            scenarios: [
                UsageScenario(
                    titleKey: "배송지 주소",
                    contextKey: "배송지 주소 알려주세요",
                    exampleKey: "[우편번호]\n[주소]\n[상세주소]\n\n받는 분: [이름]\n연락처: [전화번호]",
                    feature: .memo
                ),
                UsageScenario(
                    titleKey: "약속 잡기",
                    contextKey: "언제 시간 되세요?",
                    exampleKey: "{날짜} {시간}에 {장소}에서 어떠세요? 안 되시면 말씀해 주세요 😊",
                    feature: .template
                ),
                UsageScenario(
                    titleKey: "지각 알림",
                    contextKey: "어디야?",
                    exampleKey: "죄송해요! {분}분 정도 늦을 것 같아요. 먼저 가 계세요 🙏",
                    feature: .template
                ),
            ]
        ),

        // 4. 공식 & 소개
        UsageCategory(
            emoji: "✍️",
            titleKey: "공식 & 소개",
            descKey: "자기소개, 이메일 서명, 첫인사 — 인상을 남기는 문구를 저장.",
            scenarios: [
                UsageScenario(
                    titleKey: "자기소개",
                    contextKey: nil,
                    exampleKey: "안녕하세요, [이름]입니다.\n[직함/소속]에서 [업무]를 맡고 있습니다.\n연락처: [이메일] / [전화번호]\n\n잘 부탁드립니다 🙏",
                    feature: .memo
                ),
                UsageScenario(
                    titleKey: "이메일 서명",
                    contextKey: nil,
                    exampleKey: "[이름]\n[직책] | [회사명]\n📧 [이메일]\n📞 [전화번호]\n🌐 [홈페이지]",
                    feature: .memo
                ),
                UsageScenario(
                    titleKey: "감사 인사",
                    contextKey: "프로젝트 마무리 후",
                    exampleKey: "안녕하세요 {이름}님,\n\n이번 프로젝트 함께해 주셔서 진심으로 감사드립니다.\n덕분에 좋은 결과를 낼 수 있었습니다.\n\n앞으로도 좋은 인연 이어갔으면 합니다 😊",
                    feature: .template
                ),
            ]
        ),

        // 5. 스마트 클립보드
        UsageCategory(
            emoji: "🧠",
            titleKey: "스마트 클립보드",
            descKey: "복사한 내용이 자동 분류돼요 — 나중에 필터로 바로 찾기.",
            scenarios: [
                UsageScenario(
                    titleKey: "계좌번호 자동 인식",
                    contextKey: "계좌번호 복사 후",
                    exampleKey: "복사한 계좌번호가 자동으로 '계좌번호'로 분류됩니다. 나중에 필터에서 바로 찾으세요.",
                    feature: .smartClipboard
                ),
                UsageScenario(
                    titleKey: "전화번호 감지",
                    contextKey: "연락처 복사 후",
                    exampleKey: "010으로 시작하는 번호를 복사하면 '전화번호'로 자동 태그됩니다.",
                    feature: .smartClipboard
                ),
                UsageScenario(
                    titleKey: "주민번호·카드번호 마스킹",
                    contextKey: nil,
                    exampleKey: "민감한 번호는 목록에서 ••••로 가려져 표시됩니다. 필요할 때만 탭해서 사용하세요.",
                    feature: .smartClipboard
                ),
            ]
        ),
    ]

    // MARK: - Indonesian Scenarios (id)

    static let indonesian: [UsageCategory] = [

        // 1. Transfer & Pembayaran
        UsageCategory(
            emoji: "💰",
            titleKey: "Transfer & Pembayaran",
            descKey: "Rekening BCA, GoPay, OVO — simpan sekali, kirim dengan satu ketukan.",
            scenarios: [
                UsageScenario(
                    titleKey: "Nomor rekening bank",
                    contextKey: "Bisa kirim nomor rekeningnya?",
                    exampleKey: "Bank: BCA / Mandiri / BNI\nA/N: [Nama Lengkap]\nNo. Rekening: [Nomor Rekening]\n\nBisa juga transfer ke GoPay/OVO: [Nomor HP] 🙏",
                    feature: .memo
                ),
                UsageScenario(
                    titleKey: "Tagihan bulanan",
                    contextKey: nil,
                    exampleKey: "Halo {nama},\n\nTagihan bulan {bulan}: Rp {jumlah}\nRekening tujuan: BCA [nomor] a/n [nama]\nJatuh tempo: {tanggal}\n\nMohon segera dikonfirmasi. Terima kasih 🙏",
                    feature: .template
                ),
                UsageScenario(
                    titleKey: "Konfirmasi sudah transfer",
                    contextKey: "Sudah ditransfer belum?",
                    exampleKey: "Sudah saya transfer ya {nama}, nominal Rp {jumlah}. Mohon dicek kembali 🙏",
                    feature: .template
                ),
                UsageScenario(
                    titleKey: "Patungan / split bill",
                    contextKey: "Berapa bagian saya?",
                    exampleKey: "Total tadi Rp {total} untuk {jumlah} orang.\nJadi per orang Rp {perorang} ya 😊\nBisa transfer ke GoPay/OVO [nomor] a/n [nama]",
                    feature: .template
                ),
            ]
        ),

        // 2. Profesional & Kerja
        UsageCategory(
            emoji: "💼",
            titleKey: "Profesional & Kerja",
            descKey: "Perkenalan, izin, follow-up email — template siap pakai.",
            scenarios: [
                UsageScenario(
                    titleKey: "Perkenalan diri",
                    contextKey: nil,
                    exampleKey: "Halo, saya [Nama].\nSaya bekerja sebagai [Jabatan] di [Perusahaan].\nBisa dihubungi di [Email] atau [No. HP].\n\nSenang berkenalan! 😊",
                    feature: .memo
                ),
                UsageScenario(
                    titleKey: "Izin tidak masuk",
                    contextKey: nil,
                    exampleKey: "Permisi {atasan}, saya {nama} ingin mengajukan izin tidak masuk pada {tanggal} karena {alasan}. Pekerjaan saya pastikan tetap berjalan. Terima kasih atas pengertiannya 🙏",
                    feature: .template
                ),
                UsageScenario(
                    titleKey: "Follow-up proposal",
                    contextKey: "Proposal dikirim tapi belum ada balasan",
                    exampleKey: "Halo {nama},\n\nSaya ingin menindaklanjuti proposal yang saya kirimkan {hari} lalu mengenai {topik}. Apakah ada pertanyaan yang bisa saya bantu jelaskan?\n\nTerima kasih atas waktunya 🙏\n{nama saya}",
                    feature: .template
                ),
                UsageScenario(
                    titleKey: "Tanda tangan email",
                    contextKey: nil,
                    exampleKey: "[Nama Lengkap]\n[Jabatan] | [Perusahaan]\n📧 [Email]\n📞 [No. HP]\n🌐 [Website]",
                    feature: .memo
                ),
            ]
        ),

        // 3. Belanja & Pengiriman
        UsageCategory(
            emoji: "🛒",
            titleKey: "Belanja & Pengiriman",
            descKey: "Alamat pengiriman Tokopedia/Shopee — satu ketukan, langsung salin.",
            scenarios: [
                UsageScenario(
                    titleKey: "Alamat pengiriman",
                    contextKey: "Alamat pengirimannya ke mana?",
                    exampleKey: "Nama: [Nama Lengkap]\nNo. HP: [Nomor HP]\nAlamat: [Jalan, No. Rumah]\nKelurahan: [Kelurahan], Kecamatan: [Kecamatan]\nKota: [Kota], Kode Pos: [Kode Pos]",
                    feature: .memo
                ),
                UsageScenario(
                    titleKey: "Cek status pesanan",
                    contextKey: nil,
                    exampleKey: "Halo, saya mau menanyakan pesanan saya dengan nomor order [nomor]. Sudah sampai mana ya? Estimasi tiba kapan? Terima kasih 🙏",
                    feature: .memo
                ),
                UsageScenario(
                    titleKey: "Komplain produk",
                    contextKey: nil,
                    exampleKey: "Halo, saya menerima pesanan [nama produk] dengan nomor order [nomor] namun {masalah}. Mohon bantuannya untuk proses {solusi yang diinginkan}. Terima kasih 🙏",
                    feature: .template
                ),
            ]
        ),

        // 4. Komunikasi Sehari-hari
        UsageCategory(
            emoji: "📱",
            titleKey: "Komunikasi Sehari-hari",
            descKey: "Konfirmasi janji, tidak bisa angkat, pesan tidak tersedia.",
            scenarios: [
                UsageScenario(
                    titleKey: "Konfirmasi janji temu",
                    contextKey: "Jadi ketemu jam berapa?",
                    exampleKey: "Oke {nama}! Ketemu jam {waktu} di {tempat} ya. Sampai ketemu! 😊",
                    feature: .template
                ),
                UsageScenario(
                    titleKey: "Tidak bisa angkat telepon",
                    contextKey: nil,
                    exampleKey: "Maaf {nama}, saya sedang tidak bisa menerima telepon saat ini. Ada yang bisa dibantu via chat? Akan saya balas segera 🙏",
                    feature: .template
                ),
                UsageScenario(
                    titleKey: "Terlambat",
                    contextKey: "Kamu di mana?",
                    exampleKey: "Maaf ya {nama}, saya terlambat sekitar {menit} menit. Mohon tunggu sebentar 🙏",
                    feature: .template
                ),
            ]
        ),

        // 5. Smart Clipboard
        UsageCategory(
            emoji: "🧠",
            titleKey: "Smart Clipboard",
            descKey: "Teks yang disalin otomatis diklasifikasikan — temukan kapan saja.",
            scenarios: [
                UsageScenario(
                    titleKey: "Nomor rekening terdeteksi otomatis",
                    contextKey: "Setelah menyalin nomor rekening",
                    exampleKey: "Nomor rekening yang disalin otomatis dikategorikan sebagai 'Rekening Bank'. Temukan kapan saja lewat filter.",
                    feature: .smartClipboard
                ),
                UsageScenario(
                    titleKey: "Nomor HP tersimpan rapi",
                    contextKey: nil,
                    exampleKey: "Nomor HP yang disalin otomatis ditandai sebagai 'Nomor Telepon'. Tidak perlu khawatir tercecer.",
                    feature: .smartClipboard
                ),
            ]
        ),
    ]

    // MARK: - English Scenarios (en / default)

    static let english: [UsageCategory] = [

        // 1. Banking & Payments
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

        // 2. Timezone & Availability
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

        // 3. Professional English
        UsageCategory(
            emoji: "✍️",
            titleKey: "Professional English",
            descKey: "Non-native-speaker-friendly templates that ship.",
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

        // 4. Per-platform shortcuts
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

        // 5. Nomad life essentials
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

        // 6. Smart Clipboard
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
}

// MARK: - View

struct UsageGuideView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        .toolbarBackground(theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
        .accessibilityElement(children: .combine)
    }

    private func categorySection(category: UsageCategory) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                HapticManager.shared.soft()
                let isExpanding = !expanded.contains(category.id)
                let animation: Animation = reduceMotion
                    ? .linear(duration: 0.1)
                    : .easeInOut(duration: 0.22)
                withAnimation(animation) {
                    if expanded.contains(category.id) {
                        expanded.remove(category.id)
                    } else {
                        expanded.insert(category.id)
                    }
                }
                // VoiceOver: 펼침/접힘 상태 알림
                #if os(iOS)
                if UIAccessibility.isVoiceOverRunning {
                    let state = isExpanding
                        ? NSLocalizedString("펼침", comment: "VoiceOver: expanded")
                        : NSLocalizedString("접힘", comment: "VoiceOver: collapsed")
                    UIAccessibility.post(notification: .announcement, argument: "\(category.title), \(state)")
                }
                #endif
            } label: {
                HStack(spacing: 10) {
                    Text(category.emoji)
                        .font(.system(size: 22))
                        .accessibilityHidden(true)
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
                        .accessibilityHidden(true)
                }
                .padding(14)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(category.title)
            .accessibilityHint(category.desc)
            .accessibilityAddTraits(expanded.contains(category.id) ? [.isButton] : [.isButton])

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
                        .accessibilityHidden(true)
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
                .accessibilityLabel(
                    String(format: NSLocalizedString("%@ 메모로 저장", comment: "VoiceOver: save scenario as memo"), scenario.title)
                )

                Button {
                    HapticManager.shared.light()
                    #if os(iOS)
                    UIPasteboard.general.string = scenario.example
                    if UIAccessibility.isVoiceOverRunning {
                        UIAccessibility.post(notification: .announcement, argument: NSLocalizedString("복사됨", comment: "VoiceOver: copied"))
                    }
                    #endif
                } label: {
                    Text(NSLocalizedString("Copy", comment: "CTA: copy scenario text"))
                        .font(.system(size: 13))
                        .foregroundColor(theme.textMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(NSLocalizedString("템플릿 텍스트 복사", comment: "VoiceOver: copy template text"))

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
        .accessibilityElement(children: .contain)
    }

    private func featureBadge(_ feature: ScenarioFeature) -> some View {
        Text(feature.label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(feature.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(feature.color.opacity(0.12))
            .clipShape(Capsule())
            .accessibilityHidden(true)
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
