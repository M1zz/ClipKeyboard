//
//  PasteboardReaderTests.swift
//  ClipKeyboardTests
//
//  클립보드 읽기가 **메인 스레드를 붙잡지 않는지** 지킨다.
//
//  ⚠️ 여기서 지키는 것은 "값을 잘 읽는가"가 아니라 **어디서 기다리는가**다.
//     유니버설 클립보드가 켜져 있으면 값 하나 읽는 데 옆 기기를 기다리고, 그 기다림이
//     메인에서 일어나면 화면이 굳는다. 5.0.1 에서 1.28초 멈춤으로 올라왔다.
//     기록: docs/postmortem/HANG_PASTEBOARD_5_0_1.md
//

import XCTest
import UIKit
@testable import ClipKeyboard

final class PasteboardReaderTests: XCTestCase {

    private var saved: String?

    override func setUp() {
        super.setUp()
        // 시험이 남의 클립보드를 망가뜨리지 않게 넣어 두고 되돌린다.
        saved = UIPasteboard.general.hasStrings ? UIPasteboard.general.string : nil
    }

    override func tearDown() {
        if let saved {
            UIPasteboard.general.string = saved
        } else {
            UIPasteboard.general.items = []
        }
        super.tearDown()
    }

    /// 부르자마자 돌아와야 한다. 그 자리에서 답이 나오면 그건 메인에서 기다렸다는 뜻이다.
    func test_읽기는_부른_자리를_붙잡지_않는다() {
        UIPasteboard.general.string = "계좌번호 1002-345-678901"

        var returned = false
        var answeredBeforeReturn = false
        let done = expectation(description: "클립보드를 읽었다")

        PasteboardReader.string { _ in
            // 부른 자리가 아직 돌아오지도 않았는데 답이 왔다면 그 자리에서 기다린 것이다.
            if !returned { answeredBeforeReturn = true }
            done.fulfill()
        }
        returned = true

        wait(for: [done], timeout: 5)
        XCTAssertFalse(answeredBeforeReturn, "완료가 부른 자리에서 곧바로 실행됐다 - 메인에서 기다렸다는 뜻")
    }

    /// 답은 메인에서 와야 한다. 화면(@Published)을 바로 만질 수 있어야 하니까.
    func test_답은_메인에서_온다() {
        UIPasteboard.general.string = "leeo@kakao.com"

        let done = expectation(description: "메인에서 답이 왔다")
        PasteboardReader.string { text in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(text, "leeo@kakao.com")
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
    }

    /// 빈 클립보드는 nil. `hasStrings` 로 먼저 물어보므로 값을 읽으러 가지도 않는다.
    func test_빈_클립보드는_없다고_답한다() {
        UIPasteboard.general.items = []

        let done = expectation(description: "빈 클립보드")
        PasteboardReader.string { text in
            XCTAssertNil(text)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
    }

    /// 공백만 든 것은 담긴 것으로 치지 않는다. 제안 배너가 빈 카드로 뜨면 안 된다.
    func test_공백만_있으면_없는_것으로_친다() {
        UIPasteboard.general.string = "   \n  "

        let done = expectation(description: "공백")
        PasteboardReader.content { content in
            if case .empty = content {
                done.fulfill()
            } else {
                XCTFail("공백만 든 클립보드를 내용으로 쳤다")
            }
        }
        wait(for: [done], timeout: 5)
    }

    /// 뒷일(그림 줄이기·인코딩)은 백그라운드에서 끝내고 결과만 메인으로 올린다.
    /// 이게 깨지면 읽기만 옮기고 무거운 일은 메인에 남긴 셈이 된다.
    func test_뒷일은_백그라운드에서_한다() {
        UIPasteboard.general.string = "뒷일"

        let done = expectation(description: "transform 은 메인이 아니다")
        PasteboardReader.content(transform: { _ -> Bool in
            Thread.isMainThread
        }, completion: { ranOnMain in
            XCTAssertFalse(ranOnMain, "뒷일이 메인에서 돌았다")
            XCTAssertTrue(Thread.isMainThread, "완료는 메인이어야 한다")
            done.fulfill()
        })
        wait(for: [done], timeout: 5)
    }
}
