//
//  BasicScenarioTests.swift
//  ClipKeyboardTests
//
//  **기본 사용 시나리오가 처음부터 끝까지 도는지** 본다. 부품 하나가 아니라 이어진 길이다.
//
//    앱에서 단축어를 만든다 → 키보드 목록에 실린다 → 키보드에서 누르면 입력칸에 들어간다
//    → 앱 목록에 쓴 횟수가 오른다 → 고치면 키보드도 새 값을 넣는다 → 지우면 키보드에서도 사라진다
//    그리고 템플릿 · 스택 · 보안 · 복사한 것 저장이 같은 길을 끝까지 가는지.
//
//  ⚠️ 여기 있는 시험 이름은 docs/engineering/USER_JOURNEYS.md 의 표에 걸려 있다.
//     이름을 바꾸거나 지우면 scripts/check_journeys.sh 가 커밋을 막는다.
//
//  왜 필요한가: 부품 시험(저장소 · 분류 · 템플릿 치환 · 키보드 입력칸)은 각자 통과하는데,
//  그 사이의 이음매(같은 App Group 파일을 보는가, 같은 id 로 쓴 횟수를 올리는가, 알림 이름이
//  맞는가)가 끊기면 사용자는 "키보드에 아무것도 안 나와요"를 겪는다. 이 파일은 그 이음매만 본다.
//
//  무엇을 진짜로 쓰나:
//   - 만들기 · 고치기: `MemoAddViewModel.saveMemo` (저장 화면이 부르는 그대로)
//   - 키보드 목록: `KeyboardMemoFeed` (익스텐션과 앱 무대가 같이 쓰는 정렬)
//   - 키보드에서 누르기: `.addTextEntry` 알림 → `InAppKeyboardHost`
//     (`KeyboardView.insertMemo` 가 쏘는 알림을 `KeyboardViewController` 와 같은 순서로 받는 곳.
//      진짜 익스텐션은 키보드를 띄워야만 돌아서 시험이 닿지 않는다)
//   - 앱 목록: `ClipKeyboardListViewModel`
//   - 저장: 시뮬레이터의 실제 App Group 파일. 가짜 저장소를 쓰지 않는다
//

import XCTest
@testable import ClipKeyboard

@MainActor
final class BasicScenarioTests: XCTestCase {

    private var groupDefaults: UserDefaults? { AppGroup.defaults }

    override func setUp() {
        super.setUp()
        try? MemoStore.shared.save(memos: [], type: .memo, recordHistory: false)
        // 손으로 정한 순서가 남아 있으면 키보드 정렬 시험이 그 순서를 본다.
        groupDefaults?.removeObject(forKey: DefaultsKey.memoManualOrderActiveV1)
        groupDefaults?.removeObject(forKey: DefaultsKey.memoManualOrderV1)
    }

    override func tearDown() {
        try? MemoStore.shared.save(memos: [], type: .memo, recordHistory: false)
        clipMemos = []
        super.tearDown()
    }

    // MARK: - 시나리오 1: 만들고, 키보드에서 쓰고, 고치고, 지운다

    func test_만든_단축어를_키보드에서_쓰고_고치고_지운다() async throws {
        // 1. 앱에서 만든다 (화면은 "저장됨" 을 1초 보여 준 뒤 닫힌다)
        let closed = expectation(description: "저장하면 저장 화면이 닫혀야 한다")
        let add = makeAddViewModel()
        add.keyword = "회사 메일"
        add.value = "leeo@kakao.com"
        add.saveMemo { closed.fulfill() }

        await fulfillment(of: [closed], timeout: 3)
        let saved = try XCTUnwrap(stored(titled: "회사 메일"), "저장한 단축어가 파일에 있어야 한다")
        XCTAssertEqual(saved.value, "leeo@kakao.com")
        XCTAssertEqual(saved.clipCount, 0)

        // 2. 키보드 목록에 실린다
        XCTAssertEqual(KeyboardMemoFeed.reload(), 1)
        XCTAssertEqual(clipMemos.first?.id, saved.id, "키보드가 앱과 같은 파일을 봐야 한다")

        // 3. 키보드에서 누르면 입력칸에 들어간다
        let host = InAppKeyboardHost(typesOut: false)
        tapOnKeyboard(clipMemos[0])
        await settle()
        XCTAssertEqual(host.text, "leeo@kakao.com")

        // 4. 앱 목록에 쓴 횟수가 오른다
        let list = ClipKeyboardListViewModel()
        list.loadMemos()
        let used = try XCTUnwrap(list.memos.first { $0.id == saved.id })
        XCTAssertEqual(used.clipCount, 1, "키보드에서 쓴 것이 앱 목록에 보여야 한다")
        XCTAssertNotNil(used.lastUsedAt)

        // 5. 앱에서 고치면 키보드는 새 값을 넣는다 (새 단축어가 생기지 않는다)
        let edit = makeAddViewModel(editing: used)
        edit.value = "leeo@company.com"
        edit.saveMemo {}

        XCTAssertEqual(try MemoStore.shared.load(type: .memo).count, 1, "고치기가 새 단축어를 만들면 안 된다")
        KeyboardMemoFeed.reload()
        XCTAssertEqual(clipMemos.first?.id, saved.id, "고쳐도 같은 단축어여야 한다(쓴 횟수 · 순서가 이어진다)")

        host.clearAll()
        tapOnKeyboard(clipMemos[0])
        await settle()
        XCTAssertEqual(host.text, "leeo@company.com")
        XCTAssertEqual(stored(titled: "회사 메일")?.clipCount, 2, "고친 뒤에도 쓴 횟수가 이어져야 한다")

        // 6. 앱에서 지우면 키보드에서도 사라진다
        list.loadMemos()
        let index = try XCTUnwrap(list.memos.firstIndex { $0.id == saved.id })
        list.deleteMemo(at: IndexSet(integer: index))

        XCTAssertEqual(KeyboardMemoFeed.reload(), 0, "지운 단축어가 키보드에 남으면 안 된다")
        host.stop()
    }

    // MARK: - 시나리오 2: 즐겨찾기한 것이 키보드 맨 앞에 선다

    func test_즐겨찾기한_단축어가_키보드_맨_앞에_선다() throws {
        for (title, value) in [("집 주소", "서울시 강남구 테헤란로 1"), ("계좌", "카카오뱅크 3333-01-1234567"), ("인사", "안녕하세요")] {
            let add = makeAddViewModel()
            add.keyword = title
            add.value = value
            add.saveMemo {}
        }
        XCTAssertEqual(KeyboardMemoFeed.reload(), 3)

        let list = ClipKeyboardListViewModel()
        list.loadMemos()
        let home = try XCTUnwrap(list.memos.first { $0.title == "집 주소" })
        list.toggleFavorite(memoId: home.id)

        KeyboardMemoFeed.reload()
        XCTAssertEqual(clipMemos.first?.title, "집 주소", "앱에서 즐겨찾기하면 키보드 맨 앞에 와야 한다")
    }

    // MARK: - 시나리오 3: 템플릿은 빈칸을 물어보고, 채운 글을 넣는다

    func test_템플릿은_빈칸을_채워야_들어간다() async throws {
        // 1. 앱에서 템플릿을 만든다
        let add = makeAddViewModel()
        add.keyword = "발송 안내"
        add.value = "{이름}님, 주문하신 {상품} 오늘 보냈습니다"
        add.isTemplate = true
        add.saveMemo {}

        let template = try XCTUnwrap(stored(titled: "발송 안내"))
        XCTAssertTrue(template.isTemplate)
        KeyboardMemoFeed.reload()

        // 2. 키보드에서 누르면 바로 넣지 않고 빈칸을 물어본다
        let host = InAppKeyboardHost(typesOut: false)
        var asked: [String] = []
        let token = NotificationCenter.default.addObserver(forName: .showTemplateInput, object: nil, queue: .main) { note in
            asked = note.userInfo?["placeholders"] as? [String] ?? []
        }
        defer { NotificationCenter.default.removeObserver(token) }

        tapOnKeyboard(clipMemos[0])
        await settle()
        XCTAssertTrue(host.text.isEmpty, "빈칸이 있는 채로 넣으면 {이름} 이 그대로 붙여넣어진다")
        XCTAssertEqual(asked, ["{이름}", "{상품}"], "채울 칸을 순서대로 물어봐야 한다")

        // 3. 빈칸 창: 다 채워야 입력하기가 눌린다
        let state = TemplateInputState()
        state.originalText = template.value
        state.placeholders = asked
        state.inputs = Dictionary(uniqueKeysWithValues: asked.map { ($0, "") })
        state.inputs["{이름}"] = "이영훈"
        state.updateAllPlaceholdersFilled()
        XCTAssertFalse(state.allPlaceholdersFilled)
        XCTAssertEqual(TemplateInputState.nextUnfilled(in: asked, inputs: state.inputs, after: "{이름}"), "{상품}")

        state.inputs["{상품}"] = "키보드"
        state.updateAllPlaceholdersFilled()
        XCTAssertTrue(state.allPlaceholdersFilled)
        XCTAssertEqual(state.previewText, "이영훈님, 주문하신 키보드 오늘 보냈습니다")

        // 4. 입력하기 → 채운 글이 들어가고 쓴 횟수가 오른다
        NotificationCenter.default.post(
            name: .templateInputComplete,
            object: nil,
            userInfo: ["text": template.value, "inputs": state.inputs, "memoId": template.id]
        )
        await settle()
        XCTAssertEqual(host.text, "이영훈님, 주문하신 키보드 오늘 보냈습니다")
        XCTAssertEqual(stored(titled: "발송 안내")?.clipCount, 1)
        host.stop()
    }

    // MARK: - 시나리오 4: 이름이나 내용이 없으면 저장되지 않는다

    func test_이름이나_내용이_없으면_저장되지_않는다() async {
        // 공백·줄바꿈만 있는 것도 빈 것이다. 키보드에 누를 게 없는 키가 선다.
        let cases = [("빈 단축어", ""), ("", "제목 없는 내용"),
                     ("공백 단축어", "   "), ("줄바꿈 단축어", "\n\n"), ("  ", "제목이 공백")]
        for (title, value) in cases {
            var dismissed = false
            let add = makeAddViewModel()
            add.keyword = title
            add.value = value
            add.saveMemo { dismissed = true }
            try? await Task.sleep(for: .milliseconds(1_200))

            XCTAssertTrue(add.showAlert, "무엇이 빠졌는지 알려야 한다")
            XCTAssertFalse(dismissed, "저장되지 않았는데 화면이 닫히면 저장된 줄 안다")
        }
        XCTAssertEqual((try? MemoStore.shared.load(type: .memo))?.count, 0)
        XCTAssertEqual(KeyboardMemoFeed.reload(), 0)
    }

    // MARK: - 시나리오 5: 스택은 값들을 순서대로 넣는다

    func test_스택은_값을_순서대로_넣는다() async throws {
        let add = makeAddViewModel()
        add.keyword = "배송지"
        add.value = "홍길동"
        add.continuations = [ContinuationStep(text: "010-1234-5678"), ContinuationStep(text: "서울시 강남구")]
        add.saveMemo {}

        var stack = try XCTUnwrap(stored(titled: "배송지"))
        XCTAssertEqual(stack.stackValues, ["홍길동", "010-1234-5678", "서울시 강남구"])
        // 사이 간격(기본 2초)은 시험에서 기다릴 까닭이 없다.
        var memos = try MemoStore.shared.load(type: .memo)
        memos[0].stackInterval = 0.05
        try MemoStore.shared.save(memos: memos, type: .memo, recordHistory: false)
        stack = try XCTUnwrap(stored(titled: "배송지"))

        let host = InAppKeyboardHost(typesOut: false)
        tapOnKeyboard(stack)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(host.text, "홍길동010-1234-5678서울시 강남구", "값이 빠지거나 순서가 바뀌면 안 된다")
        XCTAssertEqual(stored(titled: "배송지")?.clipCount, 1, "스택은 한 번 쓴 것으로 센다")
        host.stop()
    }

    // MARK: - 시나리오 6: 보안 단축어는 파일에 평문으로 남지 않는다

    func test_보안_단축어는_파일에_평문이_없고_키보드는_원래_값을_넣는다() async throws {
        try XCTSkipUnless(SecureMemoCrypto.isKeyAvailable || SecureMemoCrypto.encrypt("probe") != nil,
                          "이 시뮬레이터에서 키체인 키를 만들 수 없다")
        let secret = "M12345678"
        let add = makeAddViewModel()
        add.keyword = "여권번호"
        add.value = secret
        add.isSecure = true
        add.saveMemo {}

        let saved = try XCTUnwrap(stored(titled: "여권번호"))
        XCTAssertTrue(saved.isSecure)
        XCTAssertTrue(SecureMemoCrypto.isEncrypted(saved.value), "보안 단축어가 평문으로 적혀 있다")
        XCTAssertFalse(rawMemoFile().contains(secret), "파일 어디에도 평문이 있으면 안 된다")

        // 키보드는 인증 뒤 풀어서 넣는다(`KeyboardView.insertMemo` 가 푼 값을 쏜다).
        let host = InAppKeyboardHost(typesOut: false)
        let opened = try XCTUnwrap(SecureMemoCrypto.decrypt(saved.value))
        NotificationCenter.default.post(name: .addTextEntry, object: opened, userInfo: ["memoId": saved.id])
        await settle()
        XCTAssertEqual(host.text, secret, "암호문(smenc1:...)이 붙여넣어지면 안 된다")
        host.stop()
    }

    // MARK: - 시나리오 7: 복사한 것 → 분류 → 단축어로 저장 → 키보드

    func test_복사한_것을_단축어로_저장하면_키보드에_실린다() async throws {
        try? MemoStore.shared.saveSmartClipboardHistory(history: [])
        defer { try? MemoStore.shared.saveSmartClipboardHistory(history: []) }

        try MemoStore.shared.addToSmartClipboardHistory(content: "leeo@kakao.com")
        let copied = try XCTUnwrap(MemoStore.shared.loadSmartClipboardHistory().first)
        XCTAssertEqual(copied.detectedType, .email, "복사한 이메일은 이메일로 분류돼야 한다")

        var memos = try MemoStore.shared.load(type: .memo)
        memos.append(SaveToMemoSheet.makeSnippet(from: copied, title: "메일", category: "기본", isSecure: false))
        try MemoStore.shared.save(memos: memos, type: .memo)

        KeyboardMemoFeed.reload()
        let snippet = try XCTUnwrap(clipMemos.first { $0.title == "메일" })
        let host = InAppKeyboardHost(typesOut: false)
        tapOnKeyboard(snippet)
        await settle()
        XCTAssertEqual(host.text, "leeo@kakao.com")
        host.stop()
    }

    /// 카드번호를 복사해 저장하면 창이 보안을 스스로 켠다. 그때 값이 평문으로 적히던 버그가 있었다.
    func test_복사한_카드번호를_보안으로_저장하면_암호화된다() throws {
        try XCTSkipUnless(SecureMemoCrypto.encrypt("probe") != nil, "이 시뮬레이터에서 키체인 키를 만들 수 없다")
        let card = SmartClipboardHistory(content: "4111 1111 1111 1111", detectedType: .creditCard, confidence: 0.95)

        let memo = SaveToMemoSheet.makeSnippet(from: card, title: "카드", category: "카드", isSecure: true)

        XCTAssertTrue(memo.isSecure)
        XCTAssertTrue(SecureMemoCrypto.isEncrypted(memo.value), "보안으로 저장했는데 평문이다")
        XCTAssertEqual(SecureMemoCrypto.decrypt(memo.value), "4111 1111 1111 1111")
    }

    // MARK: - 시나리오 9: 무료로 다 쓰다가, 문턱을 넘으면 만든 것은 그대로 · 새로 만들기만 한도

    func test_문턱을_넘어도_만든_것은_그대로고_새로_만들기에서만_결제를_묻는다() async throws {
        try XCTSkipIf(ProFeatureManager.isPro || ProFeatureManager.isGrandfathered || ProFeatureManager.isInTrial,
                      "이 기기가 이미 Pro 라 문턱 뒤를 볼 수 없다")
        let group = AppGroup.defaults
        let savedCount = group?.object(forKey: DefaultsKey.freeUseCount)
        defer {
            if let savedCount { group?.set(savedCount, forKey: DefaultsKey.freeUseCount) }
            else { group?.removeObject(forKey: DefaultsKey.freeUseCount) }
        }
        group?.set(0, forKey: DefaultsKey.freeUseCount)

        // 1. 무료 기간: 무료 한도(10개)를 훌쩍 넘겨 만들 수 있다
        for index in 0..<(ProFeatureManager.freeMemoLimit + 2) {
            let add = makeAddViewModel()
            add.keyword = "문구 \(index)"
            add.value = "값 \(index)"
            add.saveMemo {}
            XCTAssertFalse(add.showPaywall, "무료 기간에 결제 화면이 뜨면 안 된다(\(index + 1)번째)")
        }
        let made = ProFeatureManager.freeMemoLimit + 2
        XCTAssertEqual(try MemoStore.shared.load(type: .memo).count, made)

        // 2. 문턱을 넘는다 (키보드에서 넣은 횟수가 쌓인 것과 같다)
        group?.set(FreeUse.threshold, forKey: DefaultsKey.freeUseCount)
        XCTAssertFalse(FreeUse.isActive)

        // 3. 만든 것은 키보드에 전부 실리고, 누르면 들어간다
        KeyboardMemoFeed.reload()
        XCTAssertEqual(ProFeatureManager.memosWithinLimit(clipMemos).count, made,
                       "무료 기간에 만든 것을 문턱 뒤에 가리면 고장처럼 보인다")
        let host = InAppKeyboardHost(typesOut: false)
        tapOnKeyboard(clipMemos[0])
        await settle()
        XCTAssertFalse(host.text.isEmpty, "문턱 뒤에도 넣기는 된다")
        host.stop()

        // 4. 새로 만들기에서만 결제를 묻는다
        let add = makeAddViewModel()
        add.keyword = "새 문구"
        add.value = "새 값"
        add.saveMemo {}
        XCTAssertTrue(add.showPaywall, "한도를 넘은 새로 만들기에서 결제 화면이 떠야 한다")
        XCTAssertNil(stored(titled: "새 문구"), "결제 전에는 저장되지 않는다")
    }

    // MARK: - Helpers

    private func makeAddViewModel(editing memo: Memo? = nil) -> MemoAddViewModel {
        let vm = MemoAddViewModel(saveMemoUseCase: SaveMemoUseCase(),
                                  memoRepository: MemoRepository(),
                                  editingMemo: memo)
        vm.onAppear(memoId: memo?.id,
                    insertedKeyword: memo?.title ?? "",
                    insertedValue: memo?.value ?? "",
                    insertedIsTemplate: memo?.isTemplate ?? false)
        return vm
    }

    /// 저장 파일의 원문. 평문이 새어 있는지 글자로 확인한다.
    private func rawMemoFile() -> String {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent(StorageFile.memos),
              let data = try? Data(contentsOf: url) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    private func stored(titled title: String) -> Memo? {
        (try? MemoStore.shared.load(type: .memo))?.first { $0.title == title }
    }

    /// 키보드의 단축어 키를 누른 것과 같다(`KeyboardView.insertMemo` 가 쏘는 알림 그대로).
    private func tapOnKeyboard(_ memo: Memo) {
        NotificationCenter.default.post(name: .addTextEntry,
                                        object: memo.value,
                                        userInfo: ["memoId": memo.id])
    }

    private func settle() async {
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(80))
    }
}
