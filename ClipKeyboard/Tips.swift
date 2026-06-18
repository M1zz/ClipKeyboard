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
        Image(systemName: AppSymbol.docOnClipboardFill)
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
        Image(systemName: AppSymbol.plusCircleFill)
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
        Image(systemName: AppSymbol.keyboardFill)
    }

    var rules: [Rule] {
        #Rule(Self.$hasCopiedMemo) { $0 == true }
    }

    var actions: [Action] {
        [Action(id: "setup", title: NSLocalizedString("키보드 설정하기", comment: "Tip action: set up keyboard"))]
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
        Image(systemName: AppSymbol.trashCircleFill)
    }

    var rules: [Rule] {
        #Rule(Self.$userCreatedMemoCount) { $0 >= 2 }
    }

    var actions: [Action] {
        [
            Action(id: "delete", title: NSLocalizedString("지우기", comment: "Tip action: delete")),
            Action(id: "keep", title: NSLocalizedString("유지하기", comment: "Tip action: keep"))
        ]
    }
}

// MARK: - ComboInfoTip
// 콤보 메모를 탭해서 ComboEditSheet를 처음 열었을 때 동작 방식을 설명.

struct ComboInfoTip: Tip {
    var title: Text {
        Text(NSLocalizedString("Combo는 이렇게 동작해요", comment: "Combo info tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("탭할 때마다 저장된 값이 순서대로 하나씩 입력돼요. 키보드에서 이어서 다음 값을 넣을 수 있어요.", comment: "Combo info tip message"))
    }
    var image: Image? {
        Image(systemName: AppSymbol.`repeat`)
    }
}

// MARK: - TemplateInfoTip
// 템플릿 메모를 탭해서 TemplateEditSheet를 처음 열었을 때 채우는 방법을 설명.

struct TemplateInfoTip: Tip {
    var title: Text {
        Text(NSLocalizedString("템플릿은 이렇게 채워요", comment: "Template info tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("강조된 칸만 채우면 나머지 문장은 그대로 완성돼요. 자주 쓰는 양식을 빠르게 입력하세요.", comment: "Template info tip message"))
    }
    var image: Image? {
        Image(systemName: AppSymbol.curlybraces)
    }
}

// MARK: - AttachedTemplateTip
// 메모+템플릿(attachedTemplate) 입력 시트 상단 설명.

struct AttachedTemplateTip: Tip {
    var title: Text {
        Text(NSLocalizedString("메모 + 템플릿", comment: "Memo plus template header"))
    }
    var message: Text? {
        Text(NSLocalizedString("이 메모에 템플릿이 연결돼 있어요. 빈칸을 채우면 메모 내용과 합쳐서 복사돼요. 아래 '입력될 결과'에서 미리 볼 수 있어요.", comment: "Attached template explanation"))
    }
    var image: Image? {
        Image(systemName: AppSymbol.docBadgePlus)
    }
}

// MARK: - QuickNoteInboxTip
// 빠른 메모(Inbox) 캡처를 가르치는 팁. 앱을 어느 정도 써본(engaged) 사용자에게,
// "어디서든 담아 보관함에 모인다"는 외부 캡처 진입점을 자연스럽게 안내한다.
// 더보기(⋯) 메뉴 버튼에 popoverTip으로 부착된다.

struct QuickNoteInboxTip: Tip {
    @Parameter
    static var engaged: Bool = false

    var title: Text {
        Text(NSLocalizedString("어디서든 빠르게 담으세요", comment: "Quick note inbox tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("공유 시트·단축어·제어 센터로 담은 항목은 ⋯ 메뉴의 보관함에 모여요. 나중에 키보드 메모로 저장하면 돼요.", comment: "Quick note inbox tip message"))
    }
    var image: Image? {
        Image(systemName: AppSymbol.trayAndArrowDownFill)
    }

    var rules: [Rule] {
        #Rule(Self.$engaged) { $0 == true }
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
