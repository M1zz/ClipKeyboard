//
//  InAppKeyboardHost.swift
//  ClipKeyboard
//
//  앱 안에서 키보드가 글을 넣을 **자리**. 익스텐션의 `KeyboardViewController`가 하는 일을
//  앱 프로세스에서 그대로 한다 - 다만 종착지가 호스트 앱의 텍스트 필드가 아니라
//  우리가 들고 있는 문자열이다.
//
//  ⚠️ 삽입 경로를 새로 만들지 않는다. `KeyboardView`는 예나 지금이나 `.addTextEntry`
//     알림만 쏘고, 그걸 누가 받느냐만 다르다(익스텐션=컨트롤러 / 앱=여기).
//     경로가 갈라지면 "키보드에선 되는데 앱에선 안 되는" 기능이 반드시 생긴다.
//
//  ⚠️ 키보드 사용 통계(`keyboardPasteCount`·비콘)는 **건드리지 않는다.** 앱 안에서 눌러 본 것은
//     키보드를 쓴 게 아니다. 섞으면 "키보드를 얼마나 쓰는가"라는 지표가 의미를 잃는다.
//     문구별 사용 횟수(clipCount)는 올린다 - 그건 실제로 그 문구를 쓴 것이 맞다.
//

import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

/// 무대 위에 쌓이는 말풍선 한 개.
struct StageMessage: Identifiable, Equatable {
    enum Side { case incoming, outgoing }
    let id = UUID()
    let side: Side
    let text: String
}

@MainActor
final class InAppKeyboardHost: ObservableObject, TypingInputProxy {

    // MARK: - 입력창 상태

    /// 지금 입력창에 들어 있는 글.
    @Published private(set) var text: String = ""
    /// 캐럿 위치(문자 인덱스). `text.count`면 맨 뒤.
    @Published private(set) var caret: Int = 0
    /// 무대에 쌓인 말풍선. 첫 두 개는 상대가 건네는 말(대화의 이유)이다.
    @Published private(set) var messages: [StageMessage] = [
        .init(side: .incoming,
              text: NSLocalizedString("계좌번호 좀 보내줄래?",
                                      comment: "In-app keyboard stage: sample incoming message")),
        // ⚠️ 길게 누르기는 **눈에 안 보이는 동작**이다. 화면에 버튼을 더 두지 않는 대신
        //    이 줄로 알린다 - 안 알리면 아무도 모르는 기능이 된다.
        .init(side: .incoming,
              text: NSLocalizedString("아래 키보드에서 단축어를 눌러 보세요. 길게 누르면 복사돼요.",
                                      comment: "In-app keyboard stage: sample incoming hint"))
    ]

    /// `KeyboardView`가 구독하는 상태 - X(전체 삭제) 버튼 노출 여부를 여기서 본다.
    let documentState = KeyboardDocumentState()

    private var tokens: [NSObjectProtocol] = []
    /// 콤보 순차 입력이 도는 중인지 - 무대를 떠나면 멈춘다.
    private var comboWorkItems: [DispatchWorkItem] = []

    // MARK: - 생애

    init() {
        // 앱에는 "전체 접근" 개념이 없다 - 클립보드는 언제나 열려 있다.
        // 이 값을 켜 두지 않으면 KeyboardView가 클립보드 동작을 막고
        // "설정 > 키보드에서 전체 접근을 켜세요" 라는 엉뚱한 안내를 띄운다.
        // 지구본은 앱 안에서 갈 곳이 없으므로 끈다.
        KeyboardCapability.update(hasFullAccess: true, needsInputModeSwitchKey: false)
        subscribe()
    }

    deinit {
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// 화면을 떠날 때 - 돌고 있던 콤보 순차 입력을 세운다.
    func stop() {
        comboWorkItems.forEach { $0.cancel() }
        comboWorkItems.removeAll()
    }

    private func subscribe() {
        let t1 = NotificationCenter.default.addObserver(
            forName: .addTextEntry, object: nil, queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated { self?.handleAddTextEntry(note) }
        }
        let t2 = NotificationCenter.default.addObserver(
            forName: .templateInputComplete, object: nil, queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated { self?.handleTemplateInputComplete(note) }
        }
        tokens = [t1, t2]
    }

    // MARK: - TypingInputProxy (자판이 두드리는 자리)

    nonisolated func insertText(_ text: String) {
        MainActor.assumeIsolated { insert(text) }
    }

    nonisolated func deleteBackward() {
        MainActor.assumeIsolated {
            guard caret > 0 else { return }
            let idx = self.text.index(self.text.startIndex, offsetBy: caret - 1)
            self.text.remove(at: idx)
            caret -= 1
            syncDocumentState()
        }
    }

    nonisolated func insertNewline() {
        MainActor.assumeIsolated { insert("\n") }
    }

    /// 앱 안에는 넘어갈 다음 키보드가 없다. (지구본 키 자체를 숨기므로 불릴 일이 없다)
    nonisolated func advanceToNextInputMode() {}

    nonisolated func cursorRight() {
        MainActor.assumeIsolated {
            guard caret < text.count else { return }
            caret += 1
        }
    }

    nonisolated func clearAll() {
        MainActor.assumeIsolated {
            text = ""
            caret = 0
            syncDocumentState()
        }
    }

    // MARK: - 무대 동작

    /// 쓴 글을 말풍선으로 올린다.
    func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(.init(side: .outgoing, text: text))
        clearAll()
    }

    // MARK: - 삽입 (내부)

    private func insert(_ chunk: String) {
        let idx = text.index(text.startIndex, offsetBy: min(caret, text.count))
        text.insert(contentsOf: chunk, at: idx)
        caret = min(caret + chunk.count, text.count)
        syncDocumentState()
    }

    /// 넣은 뒤 캐럿을 끝에서 `offsetFromEnd` 만큼 되돌린다(`{커서}` 토큰 처리).
    private func insertResolved(_ processed: String) {
        let placement = TemplateVariableProcessor.resolveCursor(in: processed)
        insert(placement.text)
        if placement.needsCursorMove {
            caret = max(0, caret - placement.offsetFromEnd)
        }
        KeyboardHaptics.stamp()
    }

    private func syncDocumentState() {
        documentState.hasText = !text.isEmpty
    }

    // MARK: - 알림 처리 (KeyboardViewController와 같은 순서)

    private func handleAddTextEntry(_ note: Notification) {
        guard let raw = note.object as? String,
              let memoId = note.userInfo?["memoId"] as? UUID else { return }

        // 콤보 분할 버튼에서 값 하나만 넣는 경우 순차 입력을 건너뛴다.
        let skipCombo = (note.userInfo?["skipCombo"] as? Bool) ?? false
        if !skipCombo, handleComboIfNeeded(text: raw, memoId: memoId) { return }

        let custom = customPlaceholders(in: raw)
        if custom.isEmpty {
            insertResolved(processVariables(in: raw))
            trackUse(memoId: memoId)
        } else {
            // 값을 물어봐야 한다 - 오버레이는 KeyboardView가 띄우고,
            // 다 채우면 `.templateInputComplete` 로 돌아온다.
            NotificationCenter.default.post(
                name: .showTemplateInput,
                object: nil,
                userInfo: ["text": raw, "placeholders": custom, "memoId": memoId]
            )
        }
    }

    private func handleTemplateInputComplete(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info["text"] as? String,
              let inputs = info["inputs"] as? [String: String] else { return }

        var processed = raw
        for (placeholder, value) in inputs {
            processed = processed.replacingOccurrences(of: placeholder, with: value)
        }
        processed = processVariables(in: processed)

        // 템플릿을 문구에 붙여 쓴 경우(base + 템플릿) - 본문 뒤에 이어 붙인다.
        if let baseId = info["baseMemoId"] as? UUID,
           let base = (try? MemoStore.shared.load(type: .memo))?.first(where: { $0.id == baseId }) {
            insertResolved(base.value.isEmpty ? processed : "\(base.value)\n\(processed)")
            trackUse(memoId: baseId)
        } else {
            insertResolved(processed)
            trackUse(memoId: info["memoId"] as? UUID)
        }
    }

    /// 여러 값(콤보) 문구면 값들을 간격을 두고 하나씩 넣는다.
    /// - Returns: 콤보로 처리했으면 true.
    private func handleComboIfNeeded(text raw: String, memoId: UUID) -> Bool {
        guard let memo = (try? MemoStore.shared.load(type: .memo))?.first(where: { $0.id == memoId }),
              !memo.comboValues.isEmpty else { return false }

        let values = SecureMemoCrypto.decryptSteps(memo.comboValues)
        guard !values.isEmpty else { return false }
        // 키가 아직 동기화되지 않아 암호문이 남았다면 그걸 그대로 타이핑하지 않는다.
        if values.contains(where: { SecureMemoCrypto.isEncrypted($0) }) { return true }

        insertCombo(values, interval: memo.comboInterval, index: 0)
        trackUse(memoId: memoId)
        return true
    }

    private func insertCombo(_ values: [String], interval: TimeInterval, index: Int) {
        guard index < values.count else { return }

        if index < values.count - 1 {
            // 중간 단계에서 캐럿을 옮기면 다음 값이 엉뚱한 자리에 들어간다
            // 커서 토큰은 마지막 단계에서만 살린다(익스텐션과 같은 규칙).
            insert(TemplateVariableProcessor.resolveCursor(in: processVariables(in: values[index])).text)
            KeyboardHaptics.mediumTap()
            let work = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated { self?.insertCombo(values, interval: interval, index: index + 1) }
            }
            comboWorkItems.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: work)
        } else {
            insertResolved(processVariables(in: values[index]))
        }
    }

    // MARK: - 치환

    /// 사용자가 값을 채워야 하는 변수만 골라낸다(자동 변수 `{날짜}` 등은 제외).
    private func customPlaceholders(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "\\{([^}]+)\\}") else { return [] }
        var found: [String] = []
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            let token = String(text[range])
            if !TemplateVariableProcessor.autoVariableTokens.contains(token), !found.contains(token) {
                found.append(token)
            }
        }
        return found
    }

    private func processVariables(in text: String) -> String {
        // 클립보드는 **토큰이 있을 때만** 읽는다. iOS는 읽을 때마다 붙여넣기 프롬프트를 띄울 수 있어
        // 미리 읽어 두면 아무 이유 없이 물어보게 된다.
        var clipboard: String?
        #if os(iOS)
        if TemplateVariableProcessor.containsClipboardToken(text) {
            clipboard = UIPasteboard.general.string
        }
        #endif
        // 커서 토큰은 남긴다 - insertResolved가 위치 계산에 쓴다.
        return TemplateVariableProcessor.process(text, clipboard: clipboard, keepCursorToken: true)
    }

    /// 문구를 실제로 썼다 - 사용 횟수만 올린다(`.memoUsed` 알림도 여기서 나간다).
    private func trackUse(memoId: UUID?) {
        guard let memoId else { return }
        do {
            try MemoStore.shared.incrementClipCount(for: memoId)
        } catch {
            print("⚠️ [InAppKeyboardHost.trackUse] 사용량 업데이트 실패: \(error)")
        }
    }
}
