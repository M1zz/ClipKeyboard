//
//  PersonaEditionTests.swift
//  ClipKeyboardTests
//
//  같은 앱, 네 가지 판(`PersonaEdition`). 판마다 무엇이 다르고, 무엇은 같은지 못박는다.
//

import Testing
import Foundation
@testable import ClipKeyboard

struct PersonaEditionTests {

    private func profile(_ persona: Persona, sure: Bool = true) -> FeatureFit.Profile {
        FeatureFit.Profile(persona: persona, isConfident: sure)
    }

    private func candidate(_ title: String, value: String? = "",
                           type: ClipboardItemType? = nil,
                           id: UUID = UUID()) -> PersonaEdition.Candidate {
        PersonaEdition.Candidate(id: id, title: title, value: value, type: type)
    }

    // MARK: - 판 고르기

    @Test("확신할 때만 쓰임새의 판, 아니면 모두의 판")
    func kindNeedsConfidence() {
        #expect(PersonaEdition.kind(for: .unknown) == .everyone)
        #expect(PersonaEdition.kind(for: profile(.student, sure: false)) == .everyone)
        #expect(PersonaEdition.kind(for: profile(.nomad)) == .nomad)
        #expect(PersonaEdition.kind(for: profile(.business)) == .business)
        #expect(PersonaEdition.kind(for: profile(.student)) == .student)
        #expect(PersonaEdition.kind(for: profile(.general)) == .general)
    }

    @Test("판마다 세 칸이고, 칸 이름은 판 안에서 겹치지 않는다")
    func threeDistinctEssentials() {
        for kind in PersonaEdition.Kind.allCases {
            let ids = PersonaEdition.essentials(for: kind).map(\.id)
            #expect(ids.count == 3)
            #expect(Set(ids).count == 3)
        }
    }

    @Test("네 쓰임새의 판은 서로 다른 순간을 먼저 챙긴다")
    func editionsDiffer() {
        let firsts = [PersonaEdition.Kind.nomad, .business, .student].map {
            PersonaEdition.essentials(for: $0).map(\.id)
        }
        #expect(Set(firsts.flatMap { $0 }).count == 9)
    }

    @Test("요청형 순간이 판마다 하나는 있다 - 키보드에 붙박을 것이 있어야 한다")
    func everyEditionAnchorsSomething() {
        for kind in PersonaEdition.Kind.allCases {
            let anchored = PersonaEdition.essentials(for: kind).filter(\.anchorsKeyboard)
            #expect(!anchored.isEmpty)
        }
    }

    @Test("빈칸은 자동 변수가 아닌 것만 채울 칸이 된다 (날짜·도시는 알아서 채워진다)")
    func blanksAreFillable() {
        let timezone = PersonaEdition.timezone
        let blanks = TemplateVariableProcessor.extractCustomTokens(in: timezone.example)
        #expect(!blanks.contains("{도시}"))
        #expect(!blanks.contains("{타임존}"))
        #expect(!blanks.isEmpty)
    }

    // MARK: - 이미 찬 칸

    @Test("분류된 종류로 칸이 찬다")
    func coverageByType() {
        let account = candidate("카뱅", value: "3333-01-2345678", type: .bankAccount)
        let result = PersonaEdition.coverage(of: PersonaEdition.essentials(for: .general),
                                             candidates: [account])
        #expect(result["account"] == account.id)
        #expect(result["address"] == nil)
    }

    @Test("제목·본문의 낱말로 칸이 찬다, 대소문자는 가리지 않는다")
    func coverageByKeyword() {
        let report = candidate("Weekly Report")
        let result = PersonaEdition.coverage(of: PersonaEdition.essentials(for: .business),
                                             candidates: [report])
        #expect(result["weeklyReport"] == report.id)
    }

    @Test("단축어 하나는 한 칸만 채운다")
    func oneSnippetOneSlot() {
        // 계좌·주소·연락처 낱말이 다 든 하나 - 한 칸만 채우고 나머지는 비어야 한다.
        let both = candidate("연락처 계좌 주소", value: "a@b.com")
        let result = PersonaEdition.coverage(of: PersonaEdition.essentials(for: .everyone),
                                             candidates: [both])
        #expect(result.count == 1)
    }

    @Test("판 안에서 만든 것은 제목을 고쳐도 그 칸이다")
    func coverageByLink() {
        let renamed = candidate("아무 제목")
        let result = PersonaEdition.coverage(of: PersonaEdition.essentials(for: .student),
                                             candidates: [renamed],
                                             links: ["professorMail": renamed.id])
        #expect(result["professorMail"] == renamed.id)
    }

    @Test("지워진 단축어의 연결은 무시한다")
    func deletedLinkIgnored() {
        let result = PersonaEdition.coverage(of: PersonaEdition.essentials(for: .student),
                                             candidates: [],
                                             links: ["studentID": UUID()])
        #expect(result.isEmpty)
    }

    @Test("보안 단축어는 본문을 보지 않는다")
    func secureBodyNotRead() {
        let secure = candidate("잠근 것", value: nil)
        let result = PersonaEdition.coverage(of: PersonaEdition.essentials(for: .nomad),
                                             candidates: [secure])
        #expect(result.isEmpty)
    }

    // MARK: - 키보드 붙박이

    @Test("요청형 칸만 붙박고, 두 개를 넘지 않는다")
    func anchors() {
        let account = UUID(), address = UUID(), meetup = UUID()
        let anchors = PersonaEdition.anchors(for: .general,
                                             coverage: ["account": account, "address": address, "meetup": meetup])
        #expect(anchors == [account, address])
        #expect(anchors.count <= PersonaEdition.anchorLimit)
    }

    @Test("비어 있는 칸은 붙박지 않는다")
    func noAnchorWithoutSnippet() {
        #expect(PersonaEdition.anchors(for: .student, coverage: [:]).isEmpty)
    }

    @Test("빠른 줄: 지금 쓸 차례 다음이 붙박이, 그다음이 최근")
    func quickRowOrder() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var recent = Memo(title: "최근", value: "r")
        recent.lastUsedAt = now.addingTimeInterval(-3600)
        let invoice = Memo(title: "인보이스", value: "i")
        let account = Memo(title: "계좌", value: "a")
        let plan = QuickRowPlanner.plan(memos: [recent, invoice, account],
                                        dueIDs: [invoice.id],
                                        anchorIDs: [account.id],
                                        struggling: false, now: now)
        #expect(plan.map(\.memoID) == [invoice.id, account.id, recent.id])
        #expect(plan.map(\.reason) == [.due, .anchor, .recent])
    }

    @Test("무료 한도로 가려진 단축어는 붙박이여도 세우지 않는다")
    func anchorMustBeVisible() {
        let hidden = UUID()
        let plan = QuickRowPlanner.plan(memos: [], dueIDs: [], anchorIDs: [hidden],
                                        struggling: false, now: Date())
        #expect(plan.isEmpty)
    }

    // MARK: - 카드를 세울까

    private func shelf(covered: Int = 1, dismissed: Set<PersonaEdition.Kind> = [],
                       own: Int = 2, away: Bool = false, loaded: Bool = true,
                       kind: PersonaEdition.Kind = .nomad) -> Bool {
        PersonaEdition.showsShelf(.init(kind: kind, covered: covered, total: 3, dismissed: dismissed,
                                        ownMemoCount: own, isAwayOrJustBack: away, hasLoaded: loaded))
    }

    @Test("빈 칸이 남았으면 세운다")
    func shelfShows() {
        #expect(shelf())
    }

    @Test("다 찼거나, 닫았거나, 아직 하나도 안 만들었거나, 막 돌아왔거나, 읽기 전이면 세우지 않는다")
    func shelfGuards() {
        #expect(!shelf(covered: 3))
        #expect(!shelf(dismissed: [.nomad]))
        #expect(!shelf(own: 0))
        #expect(!shelf(away: true))
        #expect(!shelf(loaded: false))
    }

    @Test("판이 바뀌면 닫았던 카드와 상관없이 새 판의 카드가 선다")
    func newEditionShowsAgain() {
        #expect(shelf(dismissed: [.everyone], kind: .nomad))
    }

    // MARK: - 결제 순간의 차례

    @Test("쓰임새마다 결제 순간의 차례가 다르다")
    func purchaseOrder() {
        #expect(FeatureFit.purchaseMomentOrder(.unknown) == PurchaseMoment.defaultOrder)
        #expect(FeatureFit.purchaseMomentOrder(profile(.general)) == PurchaseMoment.defaultOrder)
        #expect(FeatureFit.purchaseMomentOrder(profile(.nomad)).first == .secondDevice)
        #expect(FeatureFit.purchaseMomentOrder(profile(.business)) == [.secondDevice, .noBackup, .sensitiveSaved])
        #expect(FeatureFit.purchaseMomentOrder(profile(.student)).isEmpty)
        #expect(FeatureFit.purchaseMomentOrder(profile(.student, sure: false)) == PurchaseMoment.defaultOrder)
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func due(order: [PurchaseMoment]) -> PurchaseMoment? {
        // 보안(2시간 전)과 두 대째가 **같이** 온 날.
        PurchaseMomentManager.dueMoment(now: now, context: .init(
            hasPro: false, hasSync: false, shownMoments: [],
            sensitiveSavedAt: now.addingTimeInterval(-2 * 3600),
            knownDeviceCount: 2, ownMemoCount: 3,
            lastBackupAt: nil, installedAt: now.addingTimeInterval(-60 * 86_400),
            order: order))
    }

    @Test("둘이 같이 오면 차례가 앞선 것이 먼저다")
    func orderDecidesWhenBothDue() {
        #expect(due(order: PurchaseMoment.defaultOrder) == .sensitiveSaved)
        #expect(due(order: FeatureFit.purchaseMomentOrder(profile(.nomad))) == .secondDevice)
    }

    @Test("차례에 없는 순간은 오지 않는다 (학생)")
    func emptyOrderIsSilent() {
        #expect(due(order: []) == nil)
    }
}
