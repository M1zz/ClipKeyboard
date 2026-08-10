//
//  RefundReceipt.swift
//  ClipKeyboard
//
//  **환급 영수증** - 금고 컨셉의 종이 쪽.
//
//  금고가 "얼마가 쌓였나"라면 영수증은 "무엇으로 벌었나"다. 잔고만 보여주면 숫자를 믿을
//  근거가 없는데, 줄 단위로 쪼개 놓으면 사용자가 자기 손으로 검산할 수 있다.
//  그래서 이 화면의 값어치는 합계가 아니라 **줄 항목**에 있다.
//
//  ⚠️ 기간을 나누지 않는다. 기기에 쌓인 값이 평생 누적(`clipCount`,
//     `totalTimeSavedSeconds`)뿐이라 "이번 달"을 만들려면 없는 데이터를 지어내야 한다.
//     그래서 발행일만 찍고 합계는 **누적**이라고 정직하게 쓴다.
//
//  ⚠️ 이 종이는 **공유 대상**이다. 문구의 내용(value)은 한 글자도 들어가지 않는다.
//     제목만 들어가고, 보안 문구는 제목조차 `UsagePassport.displayLabel` 이 가린다.
//
//  ⚠️ 다크 모드에서도 종이색 그대로다. 영수증은 물건이라, 어두워지면 영수증이 아니게 된다.
//

import SwiftUI

// MARK: - 내용 (순수 값 - 테스트 가능)

struct RefundReceipt: Equatable, Identifiable {

    /// 발행 시각이 곧 이 종이의 정체다 - 다시 뽑으면 다른 장이다.
    var id: Date { issuedAt }

    struct Line: Equatable, Identifiable {
        let id: UUID
        /// 문구 이름. 보안 문구는 이미 가려진 대체 문구가 들어온다.
        let label: String
        let useCount: Int
        /// 이 줄이 돌려준 시간(초).
        let earnedSeconds: Double
    }

    let issuedAt: Date
    /// 이 종이가 끊긴 기간.
    let period: RefundPeriod
    /// 영수증에 찍히는 기간 이름 - "2026년 8월" 처럼 실제 달을 쓴다.
    let periodLabel: String
    /// 다시 치지 않은 총 횟수.
    let totalUses: Int
    /// 환급 시간(초).
    let totalSeconds: Double
    /// 줄 항목 - 많이 번 순.
    let lines: [Line]
    /// 줄에 못 실린 나머지 문구 수. 0이면 안 찍는다.
    let remainderCount: Int
    /// 합계가 기간 전체를 못 덮을 때, 실제로 세기 시작한 날.
    ///
    /// 예전부터 쓰던 사용자에게는 월 원장 이전 기록이 없다. 그 사람의 지난달을 그냥
    /// 0원으로 찍으면 **거짓말**이라, 언제부터 센 값인지 종이에 밝힌다.
    let coverageStartedAt: Date?

    /// 영수증 한 장에 찍을 줄 수 상한. 넘치면 종이가 아니라 명세서가 된다.
    static let lineLimit = 6

    /// 여권 요약에서 **전체 기간** 영수증을 뽑는다.
    ///
    /// 정렬 기준이 여권(사용 횟수)과 **다르다**. 영수증은 금액 순이라야 말이 된다
    /// 짧은 문구를 500번 쓴 것보다 긴 문구를 50번 쓴 쪽이 더 많이 돌려줬을 수 있다.
    static func make(from summary: UsagePassport.Summary,
                     issuedAt: Date,
                     periodLabel: String = RefundPeriod.allTime.label(),
                     limit: Int = lineLimit) -> RefundReceipt {

        let earning = summary.stamps
            .filter { $0.earnedSeconds > 0 }
            .sorted { lhs, rhs in
                if lhs.earnedSeconds != rhs.earnedSeconds { return lhs.earnedSeconds > rhs.earnedSeconds }
                return lhs.useCount > rhs.useCount
            }

        let kept = Array(earning.prefix(max(0, limit)))

        return RefundReceipt(
            issuedAt: issuedAt,
            period: .allTime,
            periodLabel: periodLabel,
            totalUses: summary.totalUses,
            totalSeconds: summary.timeSavedSeconds,
            lines: kept.map { Line(id: $0.id,
                                   label: $0.label,
                                   useCount: $0.useCount,
                                   earnedSeconds: $0.earnedSeconds) },
            remainderCount: max(0, earning.count - kept.count),
            // 전체는 평생 누적을 그대로 쓰므로 언제나 완전하다 - 밝힐 게 없다.
            coverageStartedAt: nil
        )
    }

    /// 월 원장에서 **한 달치** 영수증을 뽑는다.
    ///
    /// - Parameters:
    ///   - earned: 문구별 돌려준 초.
    ///   - uses: 문구별 쓴 횟수. 초에서 역산하지 않는다 - 문구를 고친 순간부터 어긋난다.
    ///   - memos: 이름을 붙이기 위한 현재 문구들. 그 사이 지운 문구는 이름 없이 합쳐진다.
    ///   - totalUses: 그 달의 총 사용 횟수(일별 횟수 합). 줄 합과 다를 수 있다
    ///     원장 이전부터 쌓이던 값이라 더 완전하다.
    static func make(period: RefundPeriod,
                     periodLabel: String,
                     earned: [UUID: Double],
                     uses: [UUID: Int],
                     memos: [Memo],
                     totalUses: Int,
                     issuedAt: Date,
                     coverageStartedAt: Date? = nil,
                     limit: Int = lineLimit) -> RefundReceipt {

        let byID = Dictionary(memos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // 지운 문구는 하나로 합친다. 줄마다 "지운 문구"가 여러 개 뜨면 무엇이 무엇인지 알 수 없다.
        var named: [Line] = []
        var deletedSeconds: Double = 0
        var deletedUses = 0

        for (id, seconds) in earned where seconds > 0 {
            let count = uses[id] ?? 0
            if let memo = byID[id] {
                named.append(Line(id: id,
                                  label: UsagePassport.displayLabel(for: memo),
                                  useCount: count,
                                  earnedSeconds: seconds))
            } else {
                deletedSeconds += seconds
                deletedUses += count
            }
        }

        if deletedSeconds > 0 {
            named.append(Line(id: UUID(uuidString: "00000000-0000-0000-0000-0000DE1E7ED0") ?? UUID(),
                              label: NSLocalizedString("지운 문구", comment: "Receipt line for deleted shortcuts"),
                              useCount: deletedUses,
                              earnedSeconds: deletedSeconds))
        }

        let sorted = named.sorted { lhs, rhs in
            if lhs.earnedSeconds != rhs.earnedSeconds { return lhs.earnedSeconds > rhs.earnedSeconds }
            return lhs.useCount > rhs.useCount
        }
        let kept = Array(sorted.prefix(max(0, limit)))

        return RefundReceipt(
            issuedAt: issuedAt,
            period: period,
            periodLabel: periodLabel,
            totalUses: totalUses,
            // 기간 합계는 **줄의 합**이다. 평생 누적을 쓰면 그 달 것이 아니게 된다.
            totalSeconds: earned.values.reduce(0, +),
            lines: kept,
            remainderCount: max(0, sorted.count - kept.count),
            coverageStartedAt: coverageStartedAt
        )
    }

    /// 기기에 쌓인 값으로 영수증 한 장을 끊는다.
    static func issue(period: RefundPeriod,
                      memos: [Memo],
                      now: Date = Date(),
                      calendar: Calendar = .current) -> RefundReceipt {

        guard let month = period.month(from: now, calendar: calendar) else {
            let summary = UsagePassport.summary(memos: memos,
                                                timeSavedSeconds: KeyboardUsageTracker.totalTimeSavedSeconds(),
                                                limit: lineLimit * 3)
            return make(from: summary, issuedAt: now, periodLabel: period.label(from: now, calendar: calendar))
        }

        // 원장이 이 달 중간에 시작했다면 합계가 달 전체를 못 덮는다 - 종이에 밝힌다.
        var coverage: Date?
        if let started = RefundLedger.startedAt,
           let interval = calendar.dateInterval(of: .month, for: month),
           started > interval.start {
            coverage = started
        }

        return make(period: period,
                    periodLabel: period.label(from: now, calendar: calendar),
                    earned: RefundLedger.entries(forMonthOf: month),
                    uses: RefundLedger.uses(forMonthOf: month),
                    memos: memos,
                    totalUses: RefundLedger.useCount(forMonthOf: month, calendar: calendar),
                    issuedAt: now,
                    coverageStartedAt: coverage)
    }

    // MARK: 표시 문구

    /// "1시간 3분" · "26분" · "45초" - 줄 금액용 짧은 형식.
    /// `UsagePassport.timeSavedText` 는 1분 미만을 nil 로 버리는데, 줄에서는
    /// 빈칸이 되면 안 되므로 초까지 적는다.
    static func durationText(seconds: Double) -> String {
        let total = Int(max(0, seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60

        if hours > 0 {
            return String(format: NSLocalizedString("%d시간 %d분", comment: "Duration: hours and minutes"), hours, minutes)
        }
        if minutes > 0 {
            return String(format: NSLocalizedString("%d분", comment: "Duration: minutes only"), minutes)
        }
        return String(format: NSLocalizedString("%d초", comment: "Duration: seconds only"), total)
    }
}

// MARK: - 종이 모양

/// 아래위가 톱니로 잘린 영수증 종이.
/// 모서리를 둥글게 하면 카드가 되어버린다 - 종이로 읽히게 하는 건 **찢긴 가장자리**다.
struct ReceiptPaperShape: Shape {
    /// 톱니 하나의 너비(pt).
    var tooth: CGFloat = 9

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let depth = tooth * 0.55
        let count = max(2, Int(rect.width / tooth))
        let step = rect.width / CGFloat(count)

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + depth))
        for i in 0..<count {                                   // 위쪽 톱니
            let x = rect.minX + step * CGFloat(i)
            path.addLine(to: CGPoint(x: x + step / 2, y: rect.minY))
            path.addLine(to: CGPoint(x: x + step, y: rect.minY + depth))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - depth))
        for i in stride(from: count, to: 0, by: -1) {          // 아래쪽 톱니
            let x = rect.minX + step * CGFloat(i)
            path.addLine(to: CGPoint(x: x - step / 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: x - step, y: rect.maxY - depth))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - 종이

struct RefundReceiptView: View {
    let receipt: RefundReceipt

    /// 종이 고정 폭. 화면 폭을 따라가면 기기마다 다른 영수증이 나와서
    /// 공유된 이미지들이 서로 다른 물건처럼 보인다.
    static let paperWidth: CGFloat = 320

    private let ink = Color(red: 0.16, green: 0.15, blue: 0.14)
    private let inkFaint = Color(red: 0.45, green: 0.43, blue: 0.40)
    private let paper = Color(red: 0.96, green: 0.94, blue: 0.90)
    private let brand = Color(red: 0.13, green: 0.36, blue: 0.27)

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            lineItems
            divider
            total
            footer
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .padding(.bottom, 22)
        .frame(width: Self.paperWidth)
        .background(ReceiptPaperShape().fill(paper))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: 머리말

    private var header: some View {
        VStack(spacing: 8) {
            VaultHero(isOpen: true, pixel: 2)

            Text(NSLocalizedString("환급 영수증", comment: "Refund receipt title"))
                .font(.system(.headline, design: .monospaced).weight(.bold))
                .kerning(2)
                .foregroundColor(ink)

            // 기간은 제목만큼 크게 - 나중에 이 종이를 다시 봤을 때 언제 것인지가 먼저 읽혀야 한다.
            Text(receipt.periodLabel)
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundColor(brand)

            Text(issuedText)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(inkFaint)
        }
        .padding(.bottom, 14)
    }

    // MARK: 줄 항목

    private var lineItems: some View {
        VStack(spacing: 7) {
            ForEach(receipt.lines) { line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(line.label)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(String(format: NSLocalizedString("×%d", comment: "Receipt: use count multiplier"), line.useCount))
                        .foregroundColor(inkFaint)
                    Spacer(minLength: 4)
                    Text(RefundReceipt.durationText(seconds: line.earnedSeconds))
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(ink)
                .monospacedDigit()
            }

            if receipt.remainderCount > 0 {
                HStack {
                    Text(String(format: NSLocalizedString("그 밖에 문구 %d개", comment: "Receipt: remaining shortcuts line"),
                                receipt.remainderCount))
                    Spacer(minLength: 0)
                }
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(inkFaint)
            }

            if receipt.lines.isEmpty {
                Text(NSLocalizedString("아직 환급된 줄이 없어요", comment: "Receipt: empty line items"))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(inkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: 합계

    private var total: some View {
        VStack(spacing: 6) {
            HStack {
                Text(receipt.period == .allTime
                     ? NSLocalizedString("누적 환급 합계", comment: "Receipt: total label")
                     : NSLocalizedString("이 기간 환급 합계", comment: "Receipt: period total label"))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(inkFaint)
                Spacer(minLength: 0)
            }
            HStack(alignment: .firstTextBaseline) {
                Spacer(minLength: 0)
                Text(RefundReceipt.durationText(seconds: receipt.totalSeconds))
                    .font(.system(size: 27, weight: .heavy, design: .monospaced))
                    .foregroundColor(brand)
                    .monospacedDigit()
            }
            HStack {
                Text(String(format: NSLocalizedString("다시 치지 않은 횟수 %d번", comment: "Receipt: total uses line"),
                            receipt.totalUses))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(inkFaint)
                    .monospacedDigit()
                Spacer(minLength: 0)
            }
        }
        .padding(.top, 12)
    }

    // MARK: 꼬리말

    private var footer: some View {
        VStack(spacing: 6) {
            // 기간을 다 못 덮는 종이는 반드시 그렇다고 밝힌다. 안 밝히면 0원이 사실처럼 읽힌다.
            if let started = receipt.coverageStartedAt {
                Text(String(format: NSLocalizedString("%@부터 센 금액이에요.", comment: "Receipt: partial coverage note"),
                            coverageText(started)))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(inkFaint)
            }
            Text(NSLocalizedString("기기 안에서만 계산했어요. 어디에도 보내지 않았어요.", comment: "Receipt: privacy footnote"))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(inkFaint)
        }
        .multilineTextAlignment(.center)
        .padding(.top, 16)
    }

    private func coverageText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: 부품

    private var divider: some View {
        // 실선이 아니라 점선 - 영수증의 구분선은 도장 찍힌 종이가 아니라 인쇄된 점선이다.
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            .foregroundColor(inkFaint.opacity(0.6))
            .frame(height: 1)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }

    private var issuedText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: receipt.issuedAt)
    }

    private var accessibilityText: String {
        String(format: NSLocalizedString("환급 영수증. 누적 환급 합계 %1$@, 다시 치지 않은 횟수 %2$d번.",
                                         comment: "Receipt accessibility summary"),
               RefundReceipt.durationText(seconds: receipt.totalSeconds),
               receipt.totalUses)
    }
}

// MARK: - 뽑기 (이미지로 굽기)

#if canImport(UIKit)

/// 뽑은 영수증을 보여주는 시트. 여기서 **가져갈 수 있어야** 뽑은 보람이 있다
/// 공유 시트 하나로 사진 저장·파일 저장·인쇄·전송이 전부 갈린다.
struct RefundReceiptSheet: View {
    let memos: [Memo]
    /// 발행 시각. 시트를 여는 동안 고정한다 - 기간을 바꿀 때마다 시각이 흔들리면
    /// 같은 자리에서 뽑은 종이들이 서로 다른 물건이 된다.
    let issuedAt: Date
    var initialPeriod: RefundPeriod = .thisMonth

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var period: RefundPeriod
    /// 미리 구워 둔다. ShareLink 를 누른 뒤에 굽면 시트가 한 박자 늦게 뜬다.
    @State private var baked: UIImage?

    init(memos: [Memo], issuedAt: Date, initialPeriod: RefundPeriod = .thisMonth) {
        self.memos = memos
        self.issuedAt = issuedAt
        self.initialPeriod = initialPeriod
        _period = State(initialValue: initialPeriod)
    }

    private var receipt: RefundReceipt {
        RefundReceipt.issue(period: period, memos: memos, now: issuedAt)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker(NSLocalizedString("기간", comment: "Refund period picker label"), selection: $period) {
                        ForEach(RefundPeriod.allCases) { candidate in
                            Text(candidate.localizedName).tag(candidate)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)

                    RefundReceiptView(receipt: receipt)
                        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("환급 영수증", comment: "Refund receipt title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("닫기", comment: "Close button")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if let baked {
                        let image = Image(uiImage: baked)
                        ShareLink(item: image,
                                  preview: SharePreview(NSLocalizedString("환급 영수증", comment: "Refund receipt title"),
                                                        image: image)) {
                            Label(NSLocalizedString("가져가기", comment: "Share/save the receipt"),
                                  systemImage: AppSymbol.squareAndArrowUp)
                        }
                    } else {
                        ProgressView()
                    }
                }
            }
        }
        // 기간을 바꾸면 굽은 이미지도 다시 굽는다 - 안 그러면 화면과 다른 종이를 내보낸다.
        .task(id: period) {
            baked = nil                                  // 굽는 동안 옛 종이를 내보내지 않도록
            baked = RefundReceiptView.render(receipt)
        }
    }
}

extension RefundReceiptView {
    /// 영수증을 이미지로 굽는다. 공유 시트에서 저장·인쇄·전송이 전부 여기서 갈린다.
    ///
    /// ⚠️ `@MainActor` - ImageRenderer 는 뷰를 실제로 그린다.
    @MainActor
    static func render(_ receipt: RefundReceipt, scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: RefundReceiptView(receipt: receipt))
        renderer.scale = scale
        renderer.isOpaque = false
        return renderer.uiImage
    }
}
#endif
