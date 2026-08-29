//
//  ShareVideoMainThreadTests.swift
//  ClipKeyboardTests
//
//  **영상을 굽는 동안 메인 스레드가 숨을 쉬는가.**
//
//  5.0.4 에서 워치독 종료(0x8BADF00D)가 여덟 건 올라왔다. 전부 같은 자리였다.
//  `ShareVideoRenderer` 가 `@MainActor` 라, 1080x1920 짜리 102장을 굽는 동안
//  메인 스레드가 한 번도 풀리지 않았다. 시스템이 보기에 그건 "장면 갱신을 10초 안에
//  못 끝낸 앱" 이고, 그래서 껐다.
//
//  그래서 여기서 붙잡는 것은 **결과물이 아니라 어디서 도는지**다. 영상이 잘 나오는지는
//  눈으로 본다. 눈으로 볼 수 없는 것은 굽는 동안 메인이 남에게 자리를 내주는가이고,
//  그게 되돌아가면 앱이 다시 죽는다.
//
//  ⚠️ 이 시험은 영상을 끝까지 굽지 않는다. 잠깐 굽다가 취소한다. 끝까지 구우면
//     시험이 몇 초씩 늘어지는데, 알고 싶은 것은 **처음 몇백 밀리초 동안 메인이
//     살아 있었는가** 하나뿐이다.
//

import XCTest
@testable import ClipKeyboard

final class ShareVideoMainThreadTests: XCTestCase {

    /// 굽는 동안 메인 액터가 다른 일을 할 수 있어야 한다.
    ///
    /// `ShareVideoRenderer` 가 다시 `@MainActor` 가 되면 심장 박동이 0에 가깝게 떨어진다.
    /// 그 상태가 곧 5.0.4 에서 앱이 꺼지던 상태다.
    @MainActor
    func test_영상을_굽는_동안_메인이_숨을_쉰다() async throws {
        var heartbeats = 0

        // 굽기를 시작한다. 끝까지 기다리지 않는다.
        let render = Task {
            try await ShareVideoRenderer.render(totalSeconds: 5_000,
                                                totalUses: 120,
                                                equivalent: nil)
        }

        // 메인에서 규칙적으로 뛰어 본다. 메인이 잡혀 있으면 여기까지 차례가 안 온다.
        let deadline = Date().addingTimeInterval(0.4)
        while Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
            heartbeats += 1
        }

        render.cancel()
        _ = try? await render.value

        // 0.4초 동안 20ms 간격이면 넉넉히 열 번은 뛴다. 절반만 넘겨도 메인은 살아 있는 것이다.
        XCTAssertGreaterThan(heartbeats, 5,
                             "굽는 동안 메인이 잡혀 있다. ShareVideoRenderer 가 다시 메인 액터로 돌아갔는지 확인할 것")
    }

    /// 시트를 닫으면 굽기도 멈춰야 한다.
    ///
    /// 취소를 안 들으면 아무도 안 볼 영상을 끝까지 굽는다. 그 시간에도 앱은
    /// CPU 를 태우고 있고, 시스템이 앱을 끄려 할 때 제때 못 나간다
    /// (`Failed to terminate gracefully after 5.0s`).
    func test_취소하면_굽기를_그만둔다() async throws {
        let render = Task {
            try await ShareVideoRenderer.render(totalSeconds: 5_000,
                                                totalUses: 120,
                                                equivalent: nil)
        }

        try await Task.sleep(nanoseconds: 80_000_000)
        render.cancel()

        let started = Date()
        do {
            _ = try await render.value
            // 이미 다 구웠다면 취소를 확인할 수 없다. 그건 이 시험의 실패가 아니다.
        } catch is CancellationError {
            // 원하던 것.
        } catch {
            // 시뮬레이터에 인코더가 없는 등 다른 이유로 실패하는 것은 여기서 볼 일이 아니다.
        }

        XCTAssertLessThan(Date().timeIntervalSince(started), 2.0,
                          "취소한 뒤에도 계속 굽고 있다")
    }
}
