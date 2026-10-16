//
//  ClipboardCapture.swift
//  ClipKeyboard
//
//  "버튼 한 번으로 담기". 동작 버튼 · 제어 센터의 '클립보드 담기'(`CaptureClipboardIntent`)가
//  앱을 열면, 방금 복사한 글을 복사 기록(키보드 '최근' 탭)에 **임시 항목**으로 바로 넣는다.
//  저장할지 묻지 않는다. 임시 항목은 `SmartClipboardHistory.retentionDays` 뒤에 저절로 지워진다.
//
//  ⚠️ 이 읽기는 **사용자가 시킨 것**이다(버튼을 눌렀다). 그래서 설치 직후 며칠 클립보드를
//     건드리지 않는 관문(`PastePermissionGuidance.mayAutoReadClipboard`)을 지나지 않는다.
//     그래도 메인 밖에서 읽는 것은 같다(`PasteboardReader`).
//

import Foundation

enum ClipboardCapture {

    enum Outcome: Equatable {
        /// 담았다. 담은 글.
        case captured(String)
        /// 클립보드에 글이 없다.
        case empty
        /// 글은 있는데 '붙여넣기 허용?' 에서 거절했다.
        case refused
        /// 파일에 쓰지 못했다.
        case failed
    }

    /// 마지막으로 담은 때. 같은 순간에 목록의 "복사한 글 저장할까요?" 카드가 클립보드를 **또** 읽으면
    /// 붙여넣기 팝업이 두 번 뜬다. 그 카드는 이 시각 바로 뒤에는 읽지 않는다(`shouldSkipAutoRead`).
    @MainActor private(set) static var lastCaptureAt: Date?
    @MainActor private(set) static var isCapturing = false

    /// 버튼으로 담는 중이거나 막 담았으면, 저절로 도는 클립보드 읽기는 쉰다.
    @MainActor static func shouldSkipAutoRead(now: Date = Date()) -> Bool {
        if isCapturing { return true }
        if AppGroup.defaults?.bool(forKey: DefaultsKey.pendingClipboardCapture) == true { return true }
        guard let last = lastCaptureAt else { return false }
        return now.timeIntervalSince(last) < 5
    }

    /// 방금 복사한 글을 복사 기록 맨 위에 넣는다.
    /// - Parameter completion: **메인에서** 부른다.
    @MainActor static func capture(completion: @escaping @MainActor (Outcome) -> Void) {
        guard !isCapturing else { return }
        isCapturing = true
        PasteboardReader.textOrRefusal { text, refused in
            MainActor.assumeIsolated {
                isCapturing = false
                lastCaptureAt = Date()
                guard let text else {
                    completion(refused ? .refused : .empty)
                    return
                }
                do {
                    try MemoStore.shared.addToSmartClipboardHistory(content: text)
                    print("✅ [ClipboardCapture.capture] 버튼으로 담음: \(text.prefix(30))")
                    completion(.captured(text))
                } catch {
                    print("❌ [ClipboardCapture.capture] 담기 실패: \(error)")
                    completion(.failed)
                }
            }
        }
    }

    /// 담은 뒤 알리는 말.
    static func message(for outcome: Outcome) -> String {
        switch outcome {
        case .captured(let text):
            let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
            let preview = firstLine.count > 24 ? String(firstLine.prefix(24)) + "…" : firstLine
            return String(format: NSLocalizedString("키보드 '최근'에 담았어요: %@",
                                                    comment: "Toast after capturing the clipboard with the Action Button. %@ is the start of the copied text"),
                          preview)
        case .empty:
            return NSLocalizedString("담을 글이 없어요. 먼저 글을 복사해 주세요.",
                                     comment: "Toast when the Action Button capture finds no copied text")
        case .refused:
            return NSLocalizedString("붙여넣기를 허용해야 담을 수 있어요.",
                                     comment: "Toast when the user declined the paste permission during capture")
        case .failed:
            return NSLocalizedString("담지 못했어요. 잠시 뒤 다시 해 주세요.",
                                     comment: "Toast when saving the captured clipboard failed")
        }
    }
}
