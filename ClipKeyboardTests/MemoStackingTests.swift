//
//  MemoStackingTests.swift
//  ClipKeyboardTests
//
//  끌어서 스택 만들기. 사용자 요청: "스택을 드래그 앤 드롭으로 쌓게하기. 만들고보니 여러개를 묶을때"
//

import XCTest
@testable import ClipKeyboard

@MainActor
final class MemoStackingTests: XCTestCase {

    private var viewModel: ClipKeyboardListViewModel!

    override func setUp() {
        super.setUp()
        viewModel = ClipKeyboardListViewModel()
        try? MemoStore.shared.save(memos: [], type: .memo, recordHistory: false)
    }

    override func tearDown() {
        try? MemoStore.shared.save(memos: [], type: .memo, recordHistory: false)
        viewModel = nil
        super.tearDown()
    }

    func test_끌어온_카드가_스택의_다음_칸이_되고_목록에서_사라진다() throws {
        let target = Memo(title: "주소", value: "서울로 1")
        let dragged = Memo(title: "우편번호", value: "04524")
        try MemoStore.shared.save(memos: [target, dragged], type: .memo, recordHistory: false)
        viewModel.loadMemos()

        XCTAssertTrue(viewModel.stackMemo(dragged.id, onto: target.id))

        let saved = try MemoStore.shared.load(type: .memo)
        XCTAssertEqual(saved.count, 1, "끌어온 카드는 목록에서 사라진다")
        let stack = try XCTUnwrap(saved.first)
        XCTAssertEqual(stack.id, target.id)
        XCTAssertEqual(stack.title, "주소")
        XCTAssertEqual(stack.stackValues, ["서울로 1", "04524"], "놓인 카드 먼저, 끌어온 카드 다음")
        XCTAssertEqual(stack.stackItems.map(\.key), ["주소", "우편번호"], "무엇이었는지 칸 이름으로 남는다")
    }

    func test_이미_스택이면_뒤에_이어_붙고_스택끼리도_합쳐진다() throws {
        var a = Memo(title: "A", value: "1"); a.setStackValues(["1", "2"])
        var b = Memo(title: "B", value: "3"); b.setStackValues(["3", "4"])
        let merged = try XCTUnwrap(MemoStacking.stacked(a, adding: b))
        XCTAssertEqual(merged.stackValues, ["1", "2", "3", "4"])
    }

    func test_잠금_이미지_템플릿_자기_자신은_묶지_않는다() {
        let plain = Memo(title: "평범", value: "값")
        var secure = Memo(title: "잠금", value: "암호문"); secure.isSecure = true
        var image = Memo(title: "그림", value: ""); image.imageFileNames = ["a.jpg"]
        var template = Memo(title: "빈칸", value: "{이름}"); template.templateVariables = ["이름"]
        for bad in [secure, image, template] {
            XCTAssertNil(MemoStacking.stacked(plain, adding: bad), bad.title)
            XCTAssertNil(MemoStacking.stacked(bad, adding: plain), bad.title)
        }
        XCTAssertNil(MemoStacking.stacked(plain, adding: plain))
    }

    func test_묶을_수_없으면_아무것도_잃지_않는다() throws {
        let plain = Memo(title: "평범", value: "값")
        var secure = Memo(title: "잠금", value: "암호문"); secure.isSecure = true
        try MemoStore.shared.save(memos: [plain, secure], type: .memo, recordHistory: false)
        viewModel.loadMemos()

        XCTAssertFalse(viewModel.stackMemo(secure.id, onto: plain.id))
        XCTAssertEqual(try MemoStore.shared.load(type: .memo).count, 2)
    }
}
