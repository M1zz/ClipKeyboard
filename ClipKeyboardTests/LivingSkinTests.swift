//
//  LivingSkinTests.swift
//  ClipKeyboardTests
//
//  생활 레이어의 계약을 고정한다.
//
//  가장 중요한 세 지점:
//   ① **기본값은 `.none`** — 업데이트했다고 남의 화면에 갑자기 새가 날아다니면 안 된다.
//   ② **마을·발자국은 사용 횟수만으로 결정된다** — 난수를 쓰면 스크롤할 때마다 그림이
//      바뀌어서 "내가 쌓은 기록"이 아니라 그냥 장식으로 보인다.
//   ③ **한 카드에 올라가는 양에 상한이 있다** — 없으면 많이 쓴 카드가 그림밭이 된다.
//

import Testing
@testable import ClipKeyboard

@Suite("LivingSkin — 생활 레이어")
struct LivingSkinTests {

    // MARK: - 기본값·왕복

    @Test("알 수 없는 값은 '없음'으로 떨어진다")
    func unknownFallsBackToNone() {
        #expect(LivingSkin(rawValue: "dragon") == nil)
        #expect(LivingSkin(rawValue: "") == nil)
    }

    @Test("모든 스킨이 rawValue로 왕복한다")
    func roundTrips() {
        for skin in LivingSkin.allCases {
            #expect(LivingSkin(rawValue: skin.rawValue) == skin)
        }
    }

    @Test("목록 맨 위는 '없음' — 기본이 먼저 보여야 한다")
    func noneComesFirst() {
        #expect(LivingSkin.allCases.first == LivingSkin.none)
    }

    // MARK: - 성격 분류 (남는 것 / 흐르는 것)

    @Test("남는 것과 흐르는 것은 겹치지 않는다")
    func persistentAndVisitorAreDisjoint() {
        for skin in LivingSkin.allCases {
            #expect(!(skin.isPersistent && skin.isVisitor), "\(skin)이 두 성격을 동시에 가질 수 없다")
        }
        #expect(LivingSkin.village.isPersistent)
        #expect(LivingSkin.snow.isPersistent)
        #expect(LivingSkin.bird.isVisitor)
        #expect(LivingSkin.cat.isVisitor)
        #expect(!LivingSkin.none.isPersistent)
        #expect(!LivingSkin.none.isVisitor)
    }

    /// 손님이 자주 오면 반갑지 않다 — 최소 1분 간격은 지킨다.
    @Test("손님은 드물게 오고 짧게 머문다")
    func visitorsAreRare() {
        for skin in LivingSkin.allCases where skin.isVisitor {
            #expect(skin.visitInterval >= 60, "\(skin) 방문 간격이 너무 짧다")
            #expect(skin.visitDuration <= 10, "\(skin) 체류가 너무 길다")
            #expect(skin.visitDuration < skin.visitInterval)
        }
    }

    @Test("손님이 아닌 스킨은 방문 주기가 없다")
    func nonVisitorsHaveNoSchedule() {
        for skin in LivingSkin.allCases where !skin.isVisitor {
            #expect(skin.visitInterval == .infinity)
            #expect(skin.visitDuration == 0)
        }
    }

    // MARK: - 픽셀 마을

    @Test("한 번도 안 쓴 문구에는 아무것도 자라지 않는다")
    func nothingGrowsWithoutUse() {
        #expect(PixelVillage.plan(useCount: 0).isEmpty)
        #expect(PixelVillage.plan(useCount: -3).isEmpty)
    }

    @Test("한 번 쓰면 새싹이 돋는다")
    func firstUseSprouts() {
        #expect(PixelVillage.plan(useCount: 1) == [.sprout])
    }

    @Test("많이 쓸수록 큰 것이 선다 — 규모가 한눈에 읽혀야 한다")
    func biggerThingsAppearWithUse() {
        #expect(PixelVillage.plan(useCount: 4).contains(.flower))
        #expect(PixelVillage.plan(useCount: 10).contains(.tree))
        #expect(PixelVillage.plan(useCount: 25).contains(.house))
    }

    /// 27회 = 집 한 채(25) + 남은 2회만큼 새싹 둘.
    @Test("큰 것부터 채우고 남는 만큼 작은 것을 세운다")
    func fillsLargestFirst() {
        let plan = PixelVillage.plan(useCount: 27)
        #expect(plan.first == .house)
        #expect(plan.filter { $0 == .sprout }.count == 2)
    }

    @Test("아무리 많이 써도 카드가 그림밭이 되지 않는다")
    func planIsCapped() {
        for count in [50, 500, 10_000] {
            #expect(PixelVillage.plan(useCount: count).count <= PixelVillage.maxSprites)
        }
    }

    @Test("같은 횟수는 항상 같은 마을을 만든다 — 스크롤해도 안 바뀐다")
    func planIsDeterministic() {
        for count in [1, 7, 33, 120] {
            #expect(PixelVillage.plan(useCount: count) == PixelVillage.plan(useCount: count))
        }
    }

    @Test("모든 스프라이트는 8×8 이다")
    func spritesAreWellFormed() {
        for sprite in [PixelSprite.sprout, .flower, .tree, .house] {
            #expect(sprite.rows.count == PixelSprite.size)
            for row in sprite.rows {
                #expect(row.count == PixelSprite.size, "\(sprite.id) 줄 길이가 안 맞는다")
            }
        }
    }

    // MARK: - 발자국

    @Test("안 쓴 카드에는 발자국이 없다")
    func noFootprintsWithoutUse() {
        #expect(FootprintTrail.marks(useCount: 0).isEmpty)
    }

    @Test("쓴 횟수만큼 하나씩, 상한까지만 찍힌다")
    func footprintsAccumulateUpToCap() {
        #expect(FootprintTrail.marks(useCount: 1).count == 1)
        #expect(FootprintTrail.marks(useCount: 5).count == 5)
        #expect(FootprintTrail.marks(useCount: 999).count == FootprintTrail.maxMarks)
    }

    /// 난수를 쓰면 스크롤할 때마다 발자국이 옮겨 다녀 "지나간 자취"로 안 읽힌다.
    @Test("발자국 위치는 결정적이다")
    func footprintsAreDeterministic() {
        #expect(FootprintTrail.marks(useCount: 6) == FootprintTrail.marks(useCount: 6))
    }

    @Test("발자국은 대각선으로 — 오른쪽 위로 걸어간다")
    func footprintsWalkDiagonally() {
        let marks = FootprintTrail.marks(useCount: FootprintTrail.maxMarks)
        for (a, b) in zip(marks, marks.dropFirst()) {
            #expect(b.x > a.x, "가로로 전진해야 한다")
            #expect(b.y < a.y, "세로로 올라가야 한다")
        }
    }

    @Test("발자국이 카드 밖으로 나가지 않는다")
    func footprintsStayInsideCard() {
        for mark in FootprintTrail.marks(useCount: FootprintTrail.maxMarks) {
            #expect(mark.x > 0 && mark.x < 1)
            #expect(mark.y > 0 && mark.y < 1)
        }
    }

    // MARK: - 표시

    @Test("이름·설명이 채워져 있고 이름이 겹치지 않는다")
    func labelsAreDistinct() {
        var names = Set<String>()
        for skin in LivingSkin.allCases {
            #expect(!skin.localizedName.isEmpty)
            #expect(!skin.localizedDescription.isEmpty)
            #expect(names.insert(skin.localizedName).inserted)
        }
    }

    @Test("'없음'만 성격 꼬리표가 없다")
    func onlyNoneHasNoTrait() {
        #expect(LivingSkin.none.localizedTrait == nil)
        for skin in LivingSkin.allCases where skin != .none {
            #expect(skin.localizedTrait != nil)
        }
    }
}
