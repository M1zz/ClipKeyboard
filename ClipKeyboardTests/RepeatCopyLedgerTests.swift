//
//  RepeatCopyLedgerTests.swift
//  ClipKeyboardTests
//
//  "같은 글을 일주일에 두 번 복사" 를 세는 장부. 앱을 두 번 연 것과 두 번 복사한 것을 가른다.
//

import Testing
import Foundation
@testable import ClipKeyboard

struct RepeatCopyLedgerTests {

    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let digest = RepeatCopyLedger.digest("KR12 3456 7890")

    @Test("같은 복사를 앱에서 여러 번 봐도 한 번이다")
    func sameChangeCountCountsOnce() {
        var entries: [RepeatCopyLedger.Entry] = []
        var copies = 0
        for _ in 0..<3 {
            let result = RepeatCopyLedger.noting(entries, digest: digest, changeCount: 40, now: now)
            entries = result.entries
            copies = result.copies
        }
        #expect(copies == 1)
    }

    @Test("다시 복사하면 두 번이고, 닫았던 카드를 한 번 더 꺼낼 수 있다")
    func secondCopyResurfacesOnce() {
        let first = RepeatCopyLedger.noting([], digest: digest, changeCount: 40, now: now)
        let second = RepeatCopyLedger.noting(first.entries, digest: digest, changeCount: 57, now: now.addingTimeInterval(3600))
        #expect(second.copies == 2)
        #expect(RepeatCopyLedger.shouldResurface(second.entry))

        var shown = second.entry
        shown.resurfaced = true
        #expect(!RepeatCopyLedger.shouldResurface(shown))
    }

    @Test("일주일이 지난 복사는 세지 않는다")
    func oldCopiesExpire() {
        let first = RepeatCopyLedger.noting([], digest: digest, changeCount: 1, now: now)
        let later = now.addingTimeInterval(8 * 86_400)
        let second = RepeatCopyLedger.noting(first.entries, digest: digest, changeCount: 2, now: later)
        #expect(second.copies == 1)
    }

    @Test("지문은 앞뒤 공백을 같은 글로 보고, 글 자체를 담지 않는다")
    func digestNormalizesAndHides() {
        #expect(RepeatCopyLedger.digest(" KR12 3456 7890\n") == digest)
        #expect(!digest.contains("3456"))
        #expect(digest.count == 16)
    }

    @Test("장부는 상한만큼만 기억한다")
    func ledgerIsCapped() {
        var entries: [RepeatCopyLedger.Entry] = []
        for i in 0..<(RepeatCopyLedger.Threshold.limit + 10) {
            entries = RepeatCopyLedger.noting(entries, digest: RepeatCopyLedger.digest("text \(i)"),
                                              changeCount: i, now: now).entries
        }
        #expect(entries.count == RepeatCopyLedger.Threshold.limit)
    }
}
