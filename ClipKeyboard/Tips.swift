import TipKit
import SwiftUI

// MARK: - WelcomeTip

struct WelcomeTip: Tip {
    var title: Text {
        Text(NSLocalizedString("탭하면 바로 복사돼요", comment: "Welcome tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("스니펫을 탭해보세요. 클립보드에 바로 복사돼요.", comment: "Welcome tip message"))
    }
    var image: Image? {
        Image(systemName: "doc.on.clipboard.fill")
    }
}

// MARK: - AddMemoTip

struct AddMemoTip: Tip {
    @Parameter
    static var welcomeTipInvalidated: Bool = false

    var title: Text {
        Text(NSLocalizedString("내 것을 저장해보세요", comment: "Add memo tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("+ 버튼으로 자주 쓰는 텍스트를 저장할 수 있어요.", comment: "Add memo tip message"))
    }
    var image: Image? {
        Image(systemName: "plus.circle.fill")
    }

    var rules: [Rule] {
        #Rule(Self.$welcomeTipInvalidated) { $0 == true }
    }
}

// MARK: - KeyboardTip

struct KeyboardTip: Tip {
    @Parameter
    static var hasCopiedMemo: Bool = false

    var title: Text {
        Text(NSLocalizedString("키보드에서도 쓸 수 있어요", comment: "Keyboard tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("ClipKeyboard 키보드를 활성화하면 어디서든 바로 입력돼요.", comment: "Keyboard tip message"))
    }
    var image: Image? {
        Image(systemName: "keyboard.fill")
    }

    var rules: [Rule] {
        #Rule(Self.$hasCopiedMemo) { $0 == true }
    }

    var actions: [Action] {
        [Action(id: "setup", title: "키보드 설정하기")]
    }
}

// MARK: - CleanUpSamplesTip

struct CleanUpSamplesTip: Tip {
    @Parameter
    static var userCreatedMemoCount: Int = 0

    var title: Text {
        Text(NSLocalizedString("예제를 지울까요?", comment: "Clean up samples tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("직접 만든 스니펫이 생겼어요. 처음에 넣어준 예제들을 정리할까요?", comment: "Clean up samples tip message"))
    }
    var image: Image? {
        Image(systemName: "trash.circle.fill")
    }

    var rules: [Rule] {
        #Rule(Self.$userCreatedMemoCount) { $0 >= 2 }
    }

    var actions: [Action] {
        [
            Action(id: "delete", title: "지우기"),
            Action(id: "keep", title: "유지하기")
        ]
    }
}

// MARK: - Sample UUID Storage

enum SampleMemoStorage {
    private static let key = "sampleMemoUUIDs_v1"

    static func save(ids: [UUID]) {
        UserDefaults.standard.set(ids.map { $0.uuidString }, forKey: key)
    }

    static func load() -> Set<UUID> {
        let strings = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
