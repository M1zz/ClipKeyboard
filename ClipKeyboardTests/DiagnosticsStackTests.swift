//
//  DiagnosticsStackTests.swift
//  ClipKeyboardTests
//
//  콜스택을 **읽을 수 있는 채로** 보내는지 지킨다.
//
//  왜 이 시험이 생겼나: 예전 `stackString` 은 `MXCallStackTree.jsonRepresentation()` 을
//  그대로 4000자에서 잘라 보냈다. 그 JSON 은 들여쓴 중첩 구조라 프레임 하나가 300자를
//  먹는다. 그래서 허브에 올라온 149건이 **전부** 뿌리 쪽 13프레임에서 끊겼고, 죽은 자리는
//  한 건도 담기지 않았으며, `binaryName` 은 `subFrames` 뒤에 오는 필드라 한 번도
//  도달하지 못했다. 어느 줄이 내 코드인지조차 알 수 없는 데이터였다.
//
//  여기서 지키는 약속은 세 가지다.
//   ① 죽은 자리가 0번으로 온다 (잘려도 살아남는 쪽이 거기여야 한다)
//   ② 바이너리 이름이 붙는다 (내 코드와 시스템 코드를 가를 수 있어야 한다)
//   ③ 깊은 스택도 상한 안에 들어간다 (13프레임에서 끊기지 않는다)
//

import XCTest
@testable import ClipKeyboard

#if canImport(MetricKit) && os(iOS) && !targetEnvironment(macCatalyst)

final class DiagnosticsStackTests: XCTestCase {

    // MARK: - 페이로드 흉내

    /// MetricKit 이 주는 모양 **그대로** 글자로 찍는다.
    ///
    /// ⚠️ `JSONSerialization` 에 Dictionary 를 넘겨 만들지 말 것. 그러면 키 순서가
    ///    뒤섞여서, 실제 페이로드에서 `binaryName` 이 `subFrames` **뒤에** 온다는
    ///    사실이 시험에서 사라진다. 옛 버그의 원인이 바로 그 순서였다.
    private func tree(frames: [(name: String, offset: Int)], attributed: Bool = true) -> Data {
        func frame(_ index: Int, indent: Int) -> String {
            let pad = String(repeating: " ", count: indent)
            let inner = String(repeating: " ", count: indent + 2)
            var body = """
            \(pad){
            \(inner)"binaryUUID" : "794FD256-8A8D-3C8D-91AA-AAC27EF3512C",
            \(inner)"offsetIntoBinaryTextSegment" : \(frames[index].offset),
            \(inner)"sampleCount" : 1,
            """
            if index + 1 < frames.count {
                body += "\n\(inner)\"subFrames\" : [\n" + frame(index + 1, indent: indent + 4) + "\n\(inner)],"
            }
            // 실제 페이로드와 같은 자리: subFrames 뒤.
            body += "\n\(inner)\"binaryName\" : \"\(frames[index].name)\","
            body += "\n\(inner)\"address\" : \(4_363_892 + frames[index].offset)"
            body += "\n\(pad)}"
            return body
        }

        let roots = frames.isEmpty ? "" : frame(0, indent: 6)
        let json = """
        {
          "callStacks" : [
            {
              "threadAttributed" : \(attributed),
              "callStackRootFrames" : [
        \(roots)
              ]
            }
          ]
        }
        """
        return Data(json.utf8)
    }

    // MARK: - ① 죽은 자리가 0번

    func test_가장_깊은_프레임이_0번으로_온다() {
        let data = tree(frames: [
            ("dyld", 20368),            // 뿌리
            ("ClipKeyboard", 172596),
            ("SwiftUI", 263284),
            ("ClipKeyboard", 820588)    // 잎 = 죽은 자리
        ])

        let text = DiagnosticsService.stackText(fromJSON: data)
        // 끝의 UUID 범례("--" 뒤)는 프레임이 아니다.
        let lines = text.components(separatedBy: "\n--\n")[0]
            .split(separator: "\n").map(String.init)

        XCTAssertEqual(lines.count, 4)
        XCTAssertTrue(lines[0].contains("ClipKeyboard +820588"),
                      "0번은 죽은 자리여야 한다. 실제: \(lines[0])")
        XCTAssertTrue(lines[3].contains("dyld +20368"),
                      "마지막은 뿌리여야 한다. 실제: \(lines[3])")
    }

    // MARK: - ② 바이너리 이름이 붙는다

    func test_바이너리_이름이_모든_줄에_붙는다() {
        let data = tree(frames: [("dyld", 1), ("ClipKeyboard", 2), ("UIKitCore", 3)])
        let text = DiagnosticsService.stackText(fromJSON: data)

        XCTAssertTrue(text.contains("ClipKeyboard"), "내 코드 프레임을 가릴 수 있어야 한다")
        XCTAssertTrue(text.contains("UIKitCore"))
        XCTAssertFalse(text.contains("?"), "이름 없는 프레임이 생기면 안 된다. 실제:\n\(text)")
    }

    // MARK: - ③ 깊은 스택도 담긴다

    func test_깊은_스택이_열세개에서_끊기지_않는다() {
        // 옛 형식이 정확히 13프레임에서 끊겼다. 그 자리를 훌쩍 넘는지 본다.
        let deep = (0..<150).map { (name: "Frame\($0)", offset: $0 * 1000) }
        let text = DiagnosticsService.stackText(fromJSON: tree(frames: deep))
        let lines = text.split(separator: "\n").count

        XCTAssertGreaterThan(lines, 100, "8000자면 100프레임은 넘게 들어가야 한다. 실제 \(lines)줄")
        XCTAssertLessThanOrEqual(text.count, 8000, "상한은 지켜야 한다")
    }

    /// 400프레임이면 `JSONSerialization` 의 중첩 한도를 넘어 파서가 실패한다.
    /// (프레임 하나가 사전+배열 두 겹이다) 그때도 건져 내는지가 이 시험의 핵심이다.
    func test_상한을_넘으면_뿌리쪽부터_버리고_생략을_알린다() {
        let deep = (0..<400).map { (name: "VeryLongBinaryName\($0)", offset: $0 * 100_000) }
        let text = DiagnosticsService.stackText(fromJSON: tree(frames: deep))

        // 뒤집힌 순서라 0번은 **잎**이다. 뿌리(0번 프레임)가 아니라 399번이 와야 한다.
        XCTAssertTrue(text.hasPrefix(" 0 VeryLongBinaryName399"),
                      "잘려도 죽은 자리는 남아야 한다. 실제 첫 줄: \(text.prefix(40))")
        XCTAssertFalse(text.contains("VeryLongBinaryName0 "),
                      "버릴 때는 뿌리 쪽부터 버려야 한다")
        XCTAssertTrue(text.contains("생략"), "무엇이 빠졌는지 알려야 한다")
        XCTAssertLessThanOrEqual(text.count, 8000)
    }

    // MARK: - ④ 심볼로 되돌릴 실마리

    func test_바이너리_UUID_범례가_끝에_붙는다() {
        let data = tree(frames: [("ClipKeyboard", 1), ("SwiftUI", 2)])
        let text = DiagnosticsService.stackText(fromJSON: data)

        XCTAssertTrue(text.contains("--"), "범례는 구분선 뒤에 온다")
        XCTAssertTrue(text.contains("@ ClipKeyboard 794FD256-8A8D-3C8D-91AA-AAC27EF3512C"),
                      "dSYM 을 찾으려면 UUID 가 필요하다. 실제:\n\(text)")
        // 프레임 줄은 그대로여야 한다.
        XCTAssertTrue(text.hasPrefix(" 0 SwiftUI +2"))
    }

    func test_범례를_붙여도_상한을_지킨다() {
        // 400겹을 넘으면 파서가 손을 들어 범례가 안 나온다. 그 아래에서 시험한다.
        let deep = (0..<200).map { (name: "QuiteLongBinaryNameNumber\($0)", offset: $0 * 100_000) }
        let text = DiagnosticsService.stackText(fromJSON: tree(frames: deep))

        XCTAssertLessThanOrEqual(text.count, 8000, "범례까지 더해도 상한 안이어야 한다")
        XCTAssertTrue(text.contains("생략"), "범례 자리를 뺀 만큼 프레임이 줄어도 안내는 남아야 한다")
        XCTAssertTrue(text.contains("\n--\n"), "범례가 함께 있어야 이 시험이 뜻을 가진다")
    }

    // MARK: - 고장난 입력

    func test_죽은_스레드가_표시되지_않으면_첫_스레드를_쓴다() {
        let data = tree(frames: [("ClipKeyboard", 42)], attributed: false)
        let text = DiagnosticsService.stackText(fromJSON: data)

        XCTAssertTrue(text.contains("ClipKeyboard +42"),
                      "멈춤 진단은 attributed 표식이 없다. 그래도 스택은 나와야 한다")
    }

    /// 무한 재귀로 죽은 스택이 이 모양으로 온다. 여기서 원문을 덤프하면
    /// 예전 버그(읽을 수 없는 JSON 덩어리)로 그대로 되돌아간다.
    func test_파서가_감당못할_깊이에서도_프레임을_건진다() {
        let deep = (0..<600).map { (name: "Deep\($0)", offset: $0) }
        let text = DiagnosticsService.stackText(fromJSON: tree(frames: deep))

        XCTAssertFalse(text.hasPrefix("{"), "JSON 원문을 그대로 흘리면 안 된다")
        XCTAssertTrue(text.hasPrefix(" 0 Deep599"),
                      "가장 깊은 프레임이 0번이어야 한다. 실제: \(text.prefix(40))")
        XCTAssertTrue(text.contains("생략"))
    }

    func test_모양이_다르면_원문이라도_남긴다() {
        let junk = Data(#"{"unexpected": true}"#.utf8)
        let text = DiagnosticsService.stackText(fromJSON: junk)

        XCTAssertFalse(text.isEmpty, "빈손으로 보내느니 원문이 낫다")
        XCTAssertTrue(text.contains("unexpected"))
    }

    func test_갈라진_트리도_한도_안에서_멈춘다() {
        // 표본 스택은 갈라질 수 있다. 재귀가 터지지 않는지 본다.
        func wide(_ depth: Int) -> [String: Any] {
            var frame: [String: Any] = ["offsetIntoBinaryTextSegment": depth, "sampleCount": 1]
            if depth < 12 {
                frame["subFrames"] = [wide(depth + 1), wide(depth + 1)]
            }
            frame["binaryName"] = "Wide"
            return frame
        }
        let root: [String: Any] = [
            "callStacks": [["threadAttributed": true, "callStackRootFrames": [wide(0)]]]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: root) else {
            return XCTFail("갈래 진 트리를 만들지 못했다")
        }

        let text = DiagnosticsService.stackText(fromJSON: data)
        XCTAssertLessThanOrEqual(text.count, 8000, "갈라진 트리에서도 상한을 지켜야 한다")
    }
}

#endif
