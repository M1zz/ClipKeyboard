//
//  PasteboardReader.swift
//  ClipKeyboard
//
//  클립보드를 **메인 스레드 밖에서** 읽는 유일한 통로.
//
//  왜 필요한가: `UIPasteboard.general.string` 은 속성 하나 읽는 것처럼 생겼지만
//  실제로는 다른 프로세스(pasteboardd)와 주고받는 일이고, 유니버설 클립보드가 켜져 있으면
//  **옆 기기에서 내용을 끌어오기까지 기다린다.** 기다리는 동안 부른 스레드는 그 자리에 선다.
//  그 스레드가 메인이면 화면이 굳는다. `.image` 는 여기에 큰 그림을 풀어내는 일까지 얹힌다.
//
//  4.4.6 의 `CKContainer(identifier:)` 와 같은 종류의 함정이다. 생김새는 값 읽기,
//  하는 일은 프로세스 사이 통신.
//  기록: docs/postmortem/HANG_PASTEBOARD_5_0_1.md · docs/postmortem/LAUNCH_WATCHDOG_4_4_6.md
//
//  ⚠️ **자동으로 읽는 자리는 반드시 이 길로 온다.** 화면이 뜰 때·앱이 앞으로 올 때처럼
//     사용자가 시키지 않은 읽기는 예외 없이 여기를 지난다.
//     (사용자가 붙여넣기를 직접 누른 자리는 기다림이 곧 대답이라 그대로 둔다)
//     검사: scripts/check_main_thread_pasteboard.sh
//
//  ⚠️ 큐는 **하나(직렬)** 다. 앱을 앞뒤로 여러 번 오가면 읽기 요청이 겹치는데,
//     동시에 여러 개를 띄우면 느린 클립보드를 여러 번 기다리게 된다.
//

import Foundation

#if os(iOS)
import UIKit

/// 클립보드에 담겨 있는 것.
enum PasteboardContent {
    case empty
    case text(String)
    case image(UIImage)
}

enum PasteboardReader {

    /// 클립보드를 읽는 자리. 메인이 아니다.
    private static let queue = DispatchQueue(label: "com.Ysoup.TokenMemo.pasteboard-read",
                                             qos: .userInitiated)

    // MARK: - Public

    /// 글자만 읽는다. 그림은 건드리지 않는다(푸는 값이 비싸다).
    /// - Parameter completion: **메인에서** 부른다. 글자가 없으면 nil.
    static func string(completion: @escaping (String?) -> Void) {
        content(transform: { content in
            if case .text(let text) = content { return text }
            return nil
        }, completion: completion)
    }

    /// 글자와 그림을 함께 본다. 둘 다 있으면 그림이 이긴다.
    /// - Parameter completion: **메인에서** 부른다.
    static func content(completion: @escaping (PasteboardContent) -> Void) {
        content(transform: { $0 }, completion: completion)
    }

    /// 읽은 것을 **그 자리에서** 주무른 뒤 결과만 메인으로 올린다.
    ///
    /// 그림을 줄이고 인코딩하는 것처럼 뒷일이 무거울 때 쓴다. 뒷일까지 백그라운드에서
    /// 끝내야 읽기만 옮긴 보람이 있다 - 읽기는 밖에서 하고 인코딩을 메인에서 하면
    /// 멈추는 자리만 옮겨 놓은 셈이다.
    ///
    /// - Parameters:
    ///   - transform: **백그라운드에서** 실행된다. UI 를 만지지 말 것.
    ///   - completion: **메인에서** 실행된다.
    static func content<T>(transform: @escaping (PasteboardContent) -> T,
                           completion: @escaping (T) -> Void) {
        queue.async {
            let result = transform(read())
            DispatchQueue.main.async { completion(result) }
        }
    }

    // MARK: - Private

    /// ⚠️ 이 함수만 `UIPasteboard` 값을 읽는다. 그리고 이 함수는 메인에서 불리지 않는다.
    private static func read() -> PasteboardContent {
        let board = UIPasteboard.general

        // 있는지부터 묻는다(`has…`). 없는 줄 모르고 읽으면 붙여넣기 허용 팝업이
        // 아무 이유 없이 뜬다.
        if board.hasImages, let image = board.image {
            return .image(image)
        }
        if board.hasStrings,
           let text = board.string,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(text)
        }
        return .empty
    }
}

#endif
