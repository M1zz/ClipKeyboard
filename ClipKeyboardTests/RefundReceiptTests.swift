//
//  RefundReceiptTests.swift
//  ClipKeyboardTests
//
//  환급 영수증의 계약을 고정한다.
//
//  가장 중요한 세 지점:
//   ① **줄은 금액 순이다** - 여권은 사용 횟수 순이지만 영수증은 돌려준 시간 순이라야
//      말이 된다. 짧은 문구를 500번 쓴 것보다 긴 문구를 50번 쓴 쪽이 더 많이 돌려줬을 수 있다.
//   ② **줄 수에 상한이 있다** - 없으면 영수증이 아니라 명세서가 된다.
//   ③ **0원짜리 줄은 안 찍는다** - 만들어만 두고 안 쓴 문구가 영수증에 오르면 거짓말이다.
//

import Testing
import Foundation
@testable import ClipKeyboard

@Suite("RefundReceipt: 환급 영수증")
struct RefundReceiptTests {

    private static let issued = Date(timeIntervalSince1970: 1_770_000_000)

    /// 글자수 40 · n회 → 회당 9초.
    private func memo(_ title: String, uses: Int, characters: Int = 40, secure: Bool = false) -> Memo {
        var m = Memo(title: title,
                     value: String(repeating: "가", count: characters),
                     isSecure: secure)
        m.clipCount = uses
        return m
    }

    private func receipt(_ memos: [Memo], limit: Int = RefundReceipt.lineLimit) -> RefundReceipt {
        let summary = UsagePassport.summary(memos: memos, timeSavedSeconds: 12_345, limit: 50)
        return RefundReceipt.make(from: summary, issuedAt: Self.issued, limit: limit)
    }

    // MARK: - 줄 항목

    @Test("줄은 사용 횟수가 아니라 돌려준 시간 순으로 놓인다")
    func linesSortByRefundNotUseCount() {
        // 짧은 문구를 많이 쓴 쪽 vs 긴 문구를 적게 쓴 쪽.
        let short = memo("짧게 많이", uses: 50, characters: 12)   // (12/4-1)=2초 × 50 = 100초
        let long  = memo("길게 적게", uses: 10, characters: 400)  // (400/4-1)=99초 × 10 = 990초

        let lines = receipt([short, long]).lines
        #expect(lines.map(\.label) == ["길게 적게", "짧게 많이"])
    }

    @Test("한 번도 안 쓴 문구는 줄에 안 오른다. 0원짜리 영수증 줄은 거짓말이다")
    func unusedNeverGetsALine() {
        let lines = receipt([memo("쓴것", uses: 3), memo("안쓴것", uses: 0)]).lines
        #expect(lines.map(\.label) == ["쓴것"])
    }

    @Test("탭 오버헤드보다 짧아 벌이가 0인 문구도 줄에 안 오른다")
    func zeroEarningNeverGetsALine() {
        let lines = receipt([memo("너무짧음", uses: 100, characters: 2)]).lines
        #expect(lines.isEmpty)
    }

    @Test("줄 수는 상한을 넘지 않고, 남은 개수는 따로 센다")
    func lineLimitAndRemainder() {
        let memos = (1...10).map { memo("문구\($0)", uses: $0) }
        let made = receipt(memos, limit: 4)

        #expect(made.lines.count == 4)
        #expect(made.remainderCount == 6)
    }

    @Test("상한 안에 다 들어가면 나머지는 0, 있지도 않은 '그 밖에'를 찍지 않는다")
    func noRemainderWhenAllFit() {
        let made = receipt([memo("하나", uses: 1), memo("둘", uses: 2)], limit: 6)
        #expect(made.remainderCount == 0)
    }

    // MARK: - 합계

    @Test("합계는 여권이 준 누적 값을 그대로 쓴다. 줄을 더해 만들지 않는다")
    func totalComesFromTracker() {
        // 줄에 안 실린 문구도 실제로는 시간을 벌었다. 줄 합으로 총계를 만들면 그만큼 사라진다.
        let made = receipt((1...20).map { memo("문구\($0)", uses: $0) }, limit: 3)
        #expect(made.totalSeconds == 12_345)
    }

    @Test("총 사용 횟수는 모든 문구를 더한 값이다")
    func totalUsesCountsEverything() {
        let made = receipt([memo("가", uses: 3), memo("나", uses: 4), memo("다", uses: 0)])
        #expect(made.totalUses == 7)
    }

    @Test("발행 시각이 그대로 실린다. 영수증은 뽑은 순간의 것이다")
    func issuedAtIsCarried() {
        #expect(receipt([memo("가", uses: 1)]).issuedAt == Self.issued)
        #expect(receipt([memo("가", uses: 1)]).id == Self.issued)
    }

    // MARK: - 표시 문구

    @Test("줄 금액은 1분 미만이어도 빈칸이 되지 않는다")
    func shortDurationsStillPrint() {
        #expect(RefundReceipt.durationText(seconds: 0) == "0초")
        #expect(RefundReceipt.durationText(seconds: 45) == "45초")
    }

    @Test("분·시간 단위가 사람이 읽는 형태로 나온다")
    func durationFormatting() {
        #expect(RefundReceipt.durationText(seconds: 60) == "1분")
        #expect(RefundReceipt.durationText(seconds: 1_620) == "27분")
        #expect(RefundReceipt.durationText(seconds: 3_780) == "1시간 3분")
    }

    @Test("음수가 들어와도 음수 시간을 찍지 않는다")
    func negativeNeverPrints() {
        #expect(RefundReceipt.durationText(seconds: -500) == "0초")
    }

    // MARK: - 기간 영수증 (월 원장에서)

    private func monthReceipt(earned: [UUID: Double],
                              uses: [UUID: Int],
                              memos: [Memo],
                              totalUses: Int = 0,
                              coverage: Date? = nil,
                              limit: Int = RefundReceipt.lineLimit) -> RefundReceipt {
        RefundReceipt.make(period: .thisMonth,
                           periodLabel: "2026년 8월",
                           earned: earned,
                           uses: uses,
                           memos: memos,
                           totalUses: totalUses,
                           issuedAt: Self.issued,
                           coverageStartedAt: coverage,
                           limit: limit)
    }

    @Test("기간 합계는 줄의 합이다. 평생 누적을 쓰면 그 달 것이 아니게 된다")
    func periodTotalIsSumOfLines() {
        let a = memo("가", uses: 0), b = memo("나", uses: 0)
        let made = monthReceipt(earned: [a.id: 120, b.id: 300],
                                uses: [a.id: 10, b.id: 5],
                                memos: [a, b])
        #expect(made.totalSeconds == 420)
    }

    @Test("줄의 횟수는 원장이 센 값이다. 초에서 역산하지 않는다")
    func lineUseCountComesFromLedger() {
        let a = memo("가", uses: 999)   // 평생 횟수는 999지만 이 달엔 7번
        let made = monthReceipt(earned: [a.id: 63], uses: [a.id: 7], memos: [a])
        #expect(made.lines.first?.useCount == 7)
    }

    @Test("지운 문구는 한 줄로 합쳐진다. '지운 문구'가 여러 줄이면 뭐가 뭔지 모른다")
    func deletedShortcutsMergeIntoOneLine() {
        let alive = memo("살아있음", uses: 0)
        let gone1 = UUID(), gone2 = UUID()

        let made = monthReceipt(earned: [alive.id: 10, gone1: 50, gone2: 70],
                                uses: [alive.id: 1, gone1: 5, gone2: 7],
                                memos: [alive])

        let deleted = made.lines.filter { $0.label == "지운 문구" }
        #expect(deleted.count == 1)
        #expect(deleted.first?.earnedSeconds == 120)
        #expect(deleted.first?.useCount == 12)
    }

    @Test("총 사용 횟수는 따로 받는다. 원장 이전부터 쌓이던 값이라 줄 합보다 완전하다")
    func totalUsesIsIndependentOfLines() {
        let a = memo("가", uses: 0)
        let made = monthReceipt(earned: [a.id: 10], uses: [a.id: 1], memos: [a], totalUses: 42)
        #expect(made.totalUses == 42)
    }

    @Test("덮지 못한 기간은 종이에 밝힌다. 안 밝히면 0원이 사실처럼 읽힌다")
    func partialCoverageIsCarried() {
        let started = Date(timeIntervalSince1970: 1_769_000_000)
        let made = monthReceipt(earned: [:], uses: [:], memos: [], coverage: started)
        #expect(made.coverageStartedAt == started)
    }

    @Test("전체 영수증에는 덮지 못한 기간이 없다. 평생 누적은 언제나 완전하다")
    func allTimeIsAlwaysComplete() {
        let made = receipt([memo("가", uses: 3)])
        #expect(made.period == .allTime)
        #expect(made.coverageStartedAt == nil)
    }

    @Test("기간 이름이 종이에 실린다. '이번 달'이라고만 찍으면 나중에 언제 것인지 모른다")
    func periodLabelIsCarried() {
        let made = monthReceipt(earned: [:], uses: [:], memos: [])
        #expect(made.periodLabel == "2026년 8월")
    }

    @Test("기간 영수증도 줄 수 상한을 지킨다")
    func periodReceiptRespectsLimit() {
        var earned: [UUID: Double] = [:]
        var uses: [UUID: Int] = [:]
        var memos: [Memo] = []
        for i in 1...10 {
            let m = memo("문구\(i)", uses: 0)
            memos.append(m)
            earned[m.id] = Double(i) * 10
            uses[m.id] = i
        }
        let made = monthReceipt(earned: earned, uses: uses, memos: memos, limit: 4)
        #expect(made.lines.count == 4)
        #expect(made.remainderCount == 6)
    }

    // MARK: - 사생활

    @Test("보안 문구는 제목조차 영수증에 안 실린다. 이 종이는 공유 대상이다")
    func secureShortcutsAreMasked() {
        let secure = memo("계좌 비밀번호", uses: 5, secure: true)
        let labels = receipt([secure]).lines.map(\.label)
        #expect(!labels.contains("계좌 비밀번호"))
        #expect(labels == ["잠긴 문구"])
    }
}
