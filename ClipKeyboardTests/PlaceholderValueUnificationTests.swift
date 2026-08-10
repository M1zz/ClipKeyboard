//
//  PlaceholderValueUnificationTests.swift
//  ClipKeyboardTests
//
//  플레이스홀더 값이 **한 곳에서만 보이는 일**이 없도록 붙잡아 둔다.
//
//  값이 사는 곳이 둘이다
//   ① 메모 안(`Memo.placeholderValues`) - 그 문구가 들고 다니는 기억
//   ② 앱 전체가 함께 보는 저장소(`placeholder_values_{이름}`) - 실제 입력 화면이 읽는 곳
//
//  ⚠️ 튜토리얼이 ①에만 넣는 바람에, 목록에서 그 템플릿을 써 보면 제안이 하나도 안 떴다.
//     "분명히 넣었는데 없다"는 데이터가 갈라져 보이는 지점이라 조용히 신뢰를 깎는다.
//     새 문구를 만드는 길이 늘어날 때마다 이 테스트가 같은 실수를 막는다.
//

import Testing
import Foundation
@testable import ClipKeyboard

@Suite("플레이스홀더 값 일원화", .serialized)
struct PlaceholderValueUnificationTests {

    /// 테스트가 남긴 값이 다음 실행에 섞이지 않게 지우고 시작·끝낸다.
    private func withCleanStore(_ token: String, _ body: () -> Void) {
        UserDefaults.standard.removeObject(forKey: "placeholder_values_\(token)")
        defer { UserDefaults.standard.removeObject(forKey: "placeholder_values_\(token)") }
        body()
    }

    @Test("공용 저장소에 넣은 값은 그 이름으로 다시 읽힌다")
    func addedValueIsReadableByPlaceholderName() {
        let token = "{테스트자리}"
        withCleanStore(token) {
            let memoId = UUID()
            MemoStore.shared.addPlaceholderValue("이영훈",
                                                 for: token,
                                                 sourceMemoId: memoId,
                                                 sourceMemoTitle: "자기소개")
            let values = MemoStore.shared.loadPlaceholderValues(for: token)
            #expect(values.contains { $0.value == "이영훈" })
            #expect(values.first?.sourceMemoTitle == "자기소개")
        }
    }

    @Test("같은 값을 다시 넣어도 목록에 두 번 쌓이지 않는다")
    func doesNotDuplicateSameValue() {
        let token = "{테스트자리2}"
        withCleanStore(token) {
            let id = UUID()
            MemoStore.shared.addPlaceholderValue("같은값", for: token, sourceMemoId: id, sourceMemoTitle: "A")
            MemoStore.shared.addPlaceholderValue("같은값", for: token, sourceMemoId: id, sourceMemoTitle: "A")
            let values = MemoStore.shared.loadPlaceholderValues(for: token)
            #expect(values.filter { $0.value == "같은값" }.count == 1)
        }
    }

    @Test("키에는 중괄호가 그대로 들어간다. 입력 화면이 그 형태로 찾는다")
    func keyKeepsBraces() {
        // 앱의 다른 화면들(MemoAddViewModel·KeyboardView)은 `{이름}` 형태를 그대로 키로 쓴다.
        // 튜토리얼만 중괄호를 뗀 이름으로 쓰면 같은 자리인데 서로 못 찾는다.
        let braced = "{소개하는 이름}"
        withCleanStore(braced) {
            MemoStore.shared.addPlaceholderValue("값", for: braced, sourceMemoId: UUID(), sourceMemoTitle: "t")
            #expect(MemoStore.shared.loadPlaceholderValues(for: braced).isEmpty == false)
            // 중괄호 없는 이름으로는 찾히지 않는다(= 형태가 다르면 남남이다)
            #expect(MemoStore.shared.loadPlaceholderValues(for: "소개하는 이름").isEmpty)
        }
    }
}
