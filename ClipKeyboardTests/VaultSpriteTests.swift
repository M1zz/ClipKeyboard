//
//  VaultSpriteTests.swift
//  ClipKeyboardTests
//
//  금고 에셋의 계약을 고정한다.
//
//  가장 중요한 세 지점:
//   ① **스프라이트는 정사각이고 모든 줄의 폭이 같다** — 한 칸만 밀려도 테두리에 계단이
//      생기는데, 길이만 맞으면 눈으로 보기 전엔 아무도 모른다. 실제로 두 번 밀렸다.
//   ② **잔고는 절약한 시간(초)만으로 결정된다** — 난수를 쓰면 스크롤할 때마다 액수가
//      바뀌어서 "내가 쌓은 돈"이 아니라 그냥 장식이 된다.
//   ③ **카드에 올라가는 양에 상한이 있다** — 없으면 오래 쓴 문구가 동전밭이 된다.
//

import Testing
import SwiftUI
@testable import ClipKeyboard

@Suite("VaultSprite — 금고 에셋")
struct VaultSpriteTests {

    /// 앱에 실제로 들어가는 모든 스프라이트.
    private static let all: [VaultSprite] = [
        .empty, .bronze, .silver, .gold, .ingot,
        .lock, .receipt, .spark,
        .closed, .open, .openEmpty
    ] + VaultSprite.spin

    // MARK: - 격자 무결성

    @Test("모든 스프라이트가 정사각이고 줄 폭이 일정하다")
    func gridIsSquare() {
        for sprite in Self.all {
            let width = sprite.rows.first?.count ?? 0
            #expect(width == sprite.rows.count,
                    "\(sprite.id): \(sprite.rows.count)행 × \(width)칸 — 정사각이 아니다")
            for (i, row) in sprite.rows.enumerated() {
                #expect(row.count == width,
                        "\(sprite.id) \(i)번째 줄: \(row.count)칸 (기대 \(width)) — '\(row)'")
            }
        }
    }

    @Test("크기는 8(잔고) 또는 16(히어로) 뿐이다")
    func onlyTwoSizes() {
        for sprite in Self.all {
            #expect(sprite.size == 8 || sprite.size == 16, "\(sprite.id): \(sprite.size)")
        }
    }

    @Test("모든 문자가 팔레트에 있다 — 오타는 조용히 투명해진다")
    func everySymbolIsKnown() {
        for sprite in Self.all {
            for row in sprite.rows {
                for symbol in row where symbol != "." {
                    #expect(VaultPalette.color(for: symbol) != nil,
                            "\(sprite.id): '\(symbol)' 는 팔레트에 없다")
                }
            }
        }
    }

    @Test("빈 스프라이트는 없다 — 아무것도 안 그리면 스킨이 켜진 줄도 모른다")
    func nothingIsBlank() {
        for sprite in Self.all {
            let painted = sprite.rows.joined().filter { $0 != "." }.count
            #expect(painted > 0, "\(sprite.id) 가 전부 투명하다")
        }
    }

    // MARK: - 금고 속

    @Test("금고 내부 좌표가 실제로 비어 있다 — 어긋나면 동전이 벽을 뚫는다")
    func interiorIsActuallyHollow() {
        let rows = VaultSprite.openEmpty.rows
        let box = VaultSprite.interior

        for y in box.y..<(box.y + box.height) {
            let row = Array(rows[y])
            for x in box.x..<(box.x + box.width) {
                #expect(row[x] == "t", "내부 (\(x),\(y)) 가 어둠이 아니다: '\(row[x])'")
            }
        }
    }

    @Test("내부 상자가 금고 밖으로 나가지 않는다")
    func interiorFitsInsideTheVault() {
        let box = VaultSprite.interior
        #expect(box.x >= 0 && box.x + box.width <= VaultSprite.openEmpty.size)
        #expect(box.y >= 0 && box.y + box.height <= VaultSprite.openEmpty.size)
    }

    @Test("속 빈 금고에는 금이 한 조각도 없다 — 안 번 사람 금고에 금괴가 있으면 거짓말이다")
    func emptyVaultHoldsNoGold() {
        let box = VaultSprite.interior
        for y in box.y..<(box.y + box.height) {
            let row = Array(VaultSprite.openEmpty.rows[y])
            for x in box.x..<(box.x + box.width) {
                #expect(row[x] != "y" && row[x] != "Y")
            }
        }
    }

    // MARK: - 잔고 계획

    @Test("10초를 못 넘기면 빈 자리만 놓인다")
    func belowOneCoinShowsEmptyPlot() {
        #expect(VaultLedger.plan(savedSeconds: 0) == [.empty])
        #expect(VaultLedger.plan(savedSeconds: 9.9) == [.empty])
    }

    @Test("음수가 들어와도 빈 자리로 떨어진다")
    func negativeIsSafe() {
        #expect(VaultLedger.plan(savedSeconds: -100) == [.empty])
    }

    @Test("큰 단위부터 채운다 — 1시간 12분은 금괴 하나 + 금화 하나 + 은화 둘")
    func fillsLargestFirst() {
        let plan = VaultLedger.plan(savedSeconds: 3600 + 600 + 120)
        #expect(plan == [.ingot, .gold, .silver, .silver])
    }

    @Test("정확히 한 액면가면 그것 하나만 놓인다")
    func exactDenominations() {
        #expect(VaultLedger.plan(savedSeconds: 10) == [.bronze])
        #expect(VaultLedger.plan(savedSeconds: 60) == [.silver])
        #expect(VaultLedger.plan(savedSeconds: 600) == [.gold])
        #expect(VaultLedger.plan(savedSeconds: 3600) == [.ingot])
    }

    @Test("아무리 많이 벌어도 카드에 9개를 넘지 않는다")
    func capped() {
        let plan = VaultLedger.plan(savedSeconds: 3600 * 500)
        #expect(plan.count <= VaultLedger.maxSprites)
    }

    @Test("같은 초를 넣으면 항상 같은 그림 — 난수가 섞이면 안 된다")
    func deterministic() {
        for seconds in stride(from: 0.0, through: 8000.0, by: 137.0) {
            #expect(VaultLedger.plan(savedSeconds: seconds) == VaultLedger.plan(savedSeconds: seconds))
        }
    }

    @Test("더 오래 아낀 문구가 더 값나가는 액면을 갖는다")
    func moreTimeIsNeverWorthLess() {
        func topValue(_ seconds: Double) -> Int {
            let plan = VaultLedger.plan(savedSeconds: seconds)
            let order: [VaultSprite] = [.empty, .bronze, .silver, .gold, .ingot]
            return plan.compactMap { order.firstIndex(of: $0) }.max() ?? 0
        }
        var previous = 0
        for seconds in stride(from: 0.0, through: 7200.0, by: 50.0) {
            let current = topValue(seconds)
            #expect(current >= previous, "\(seconds)초에서 액면이 낮아졌다")
            previous = current
        }
    }

    // MARK: - 카드 배지 (액면 하나 + 개수)

    @Test("가장 값나가는 액면 하나만 고른다")
    func headlinePicksTopDenomination() {
        #expect(VaultLedger.headline(savedSeconds: 3600 * 3 + 700)?.sprite == .ingot)
        #expect(VaultLedger.headline(savedSeconds: 1_200)?.sprite == .gold)
        #expect(VaultLedger.headline(savedSeconds: 180)?.sprite == .silver)
        #expect(VaultLedger.headline(savedSeconds: 30)?.sprite == .bronze)
    }

    @Test("개수는 그 액면이 몇 개인지다 — 배지가 규모를 대신 말한다")
    func headlineCountsThatDenomination() {
        #expect(VaultLedger.headline(savedSeconds: 3600 * 3 + 700)?.count == 3)
        #expect(VaultLedger.headline(savedSeconds: 1_200)?.count == 2)
    }

    @Test("한 푼도 못 벌었으면 배지가 아예 없다 — 빈 배지는 카드만 어지럽힌다")
    func headlineIsNilWhenNothingEarned() {
        #expect(VaultLedger.headline(savedSeconds: 0) == nil)
        #expect(VaultLedger.headline(savedSeconds: 9.9) == nil)
        #expect(VaultLedger.headline(savedSeconds: -50) == nil)
    }

    @Test("배지 액면은 잔고가 늘수록 낮아지지 않는다")
    func headlineNeverDowngrades() {
        let order: [VaultSprite] = [.bronze, .silver, .gold, .ingot]
        var previous = -1
        for seconds in stride(from: 10.0, through: 7200.0, by: 25.0) {
            guard let sprite = VaultLedger.headline(savedSeconds: seconds)?.sprite,
                  let rank = order.firstIndex(of: sprite) else {
                Issue.record("\(seconds)초에서 배지가 사라졌다")
                continue
            }
            #expect(rank >= previous, "\(seconds)초에서 액면이 낮아졌다")
            previous = rank
        }
    }

    // MARK: - 이음새 (다음 동전까지)

    @Test("이음새는 지금 액면 기준으로 찬다 — 늘 같은 단위로 재면 아무 말도 못 한다")
    func seamMeasuresAgainstCurrentDenomination() {
        // 동전(10초)을 모으는 문구: 15초 → 반쯤
        #expect(abs(VaultLedger.nextCoinProgress(savedSeconds: 15) - 0.5) < 0.001)
        // 금괴(3600초)를 모으는 문구: 3600 + 1800 → 반쯤
        #expect(abs(VaultLedger.nextCoinProgress(savedSeconds: 5400) - 0.5) < 0.001)
    }

    @Test("이음새는 0과 1 사이를 벗어나지 않는다")
    func seamStaysInRange() {
        for seconds in stride(from: -100.0, through: 20_000.0, by: 37.0) {
            let p = VaultLedger.nextCoinProgress(savedSeconds: seconds)
            #expect(p >= 0 && p <= 1, "\(seconds)초에서 \(p)")
        }
    }

    @Test("한 푼도 못 벌었으면 이음새가 비어 있다")
    func seamEmptyWhenNothingEarned() {
        #expect(VaultLedger.nextCoinProgress(savedSeconds: 0) == 0)
        #expect(VaultLedger.nextCoinProgress(savedSeconds: -5) == 0)
    }

    // MARK: - 계산식 일치

    @Test("문구가 번 시간은 KeyboardUsageTracker 와 같은 식으로 센다")
    func earnedMatchesTracker() {
        // recordMemoUse: max(0, 글자수/4 - 1) 을 사용할 때마다 누적.
        let value = String(repeating: "가", count: 40)   // 40/4 - 1 = 9초
        #expect(VaultLedger.earnedSeconds(characterCount: value.count, useCount: 1) == 9)
        #expect(VaultLedger.earnedSeconds(characterCount: value.count, useCount: 10) == 90)
    }

    @Test("한 번도 안 쓴 문구는 0원 — 만들기만 해서는 벌리지 않는다")
    func unusedEarnsNothing() {
        #expect(VaultLedger.earnedSeconds(characterCount: 500, useCount: 0) == 0)
    }

    @Test("탭 오버헤드보다 짧은 문구는 벌이가 0 — 음수로 새지 않는다")
    func shortMemoNeverGoesNegative() {
        #expect(VaultLedger.earnedSeconds(characterCount: 2, useCount: 100) == 0)
    }
}
