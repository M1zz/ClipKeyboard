import TipKit
import SwiftUI

// MARK: - 팁을 건네는 얼굴
//
// 팁마다 얼굴 그림을 직접 고르지 않는다. `MascotTip` 을 채택하고 **포즈만** 고르면,
// 어떤 그림을 쓸지·없으면 무엇으로 대신할지는 `MascotPose` 가 정한다(Mascot.swift).
//
// ⚠️ 팁 그림은 전부 마스코트다. 예전에는 팁마다 다른 SF 기호였는데, 기호는 내용을
//    설명하지만 정작 **누가 말하고 있는지**는 매번 달라졌다.

// MARK: - WelcomeTip

struct WelcomeTip: MascotTip {
    var title: Text {
        Text(NSLocalizedString("탭하면 바로 복사돼요", comment: "Welcome tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("단축어를 탭해보세요. 클립보드에 바로 복사돼요.", comment: "Welcome tip message"))
    }
    var mascotPose: MascotPose { .greeting }
}

// MARK: - AddMemoTip

struct AddMemoTip: MascotTip {
    @Parameter
    static var welcomeTipInvalidated: Bool = false

    var title: Text {
        Text(NSLocalizedString("내 것을 저장해보세요", comment: "Add memo tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("+ 버튼으로 자주 쓰는 텍스트를 저장할 수 있어요.", comment: "Add memo tip message"))
    }
    var mascotPose: MascotPose { .pointing }

    var rules: [Rule] {
        #Rule(Self.$welcomeTipInvalidated) { $0 == true }
    }
}

// MARK: - KeyboardTip

struct KeyboardTip: MascotTip {
    @Parameter
    static var hasCopiedMemo: Bool = false

    var title: Text {
        Text(NSLocalizedString("키보드에서도 쓸 수 있어요", comment: "Keyboard tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("ClipKeyboard 키보드를 활성화하면 어디서든 바로 입력돼요.", comment: "Keyboard tip message"))
    }
    var mascotPose: MascotPose { .typing }

    var rules: [Rule] {
        #Rule(Self.$hasCopiedMemo) { $0 == true }
    }

    var actions: [Action] {
        [Action(id: "setup", title: NSLocalizedString("키보드 설정하기", comment: "Tip action: set up keyboard"))]
    }
}

// MARK: - CleanUpSamplesTip


// MARK: - ComboInfoTip
// 콤보 메모를 탭해서 ComboEditSheet를 처음 열었을 때 동작 방식을 설명.

struct ComboInfoTip: MascotTip {
    var title: Text {
        Text(NSLocalizedString("Combo는 이렇게 동작해요", comment: "Combo info tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("탭할 때마다 저장된 값이 순서대로 하나씩 입력돼요. 키보드에서 이어서 다음 값을 넣을 수 있어요.", comment: "Combo info tip message"))
    }
    var mascotPose: MascotPose { .explaining }
}

// MARK: - TemplateInfoTip
// 템플릿 메모를 탭해서 TemplateEditSheet를 처음 열었을 때 채우는 방법을 설명.

struct TemplateInfoTip: MascotTip {
    var title: Text {
        Text(NSLocalizedString("템플릿은 이렇게 채워요", comment: "Template info tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("강조된 칸만 채우면 나머지 문장은 그대로 완성돼요. 자주 쓰는 양식을 빠르게 입력하세요.", comment: "Template info tip message"))
    }
    var mascotPose: MascotPose { .explaining }
}

// MARK: - AttachedTemplateTip
// 메모+템플릿(attachedTemplate) 입력 시트 상단 설명.

struct AttachedTemplateTip: MascotTip {
    var title: Text {
        Text(NSLocalizedString("단축어 + 템플릿", comment: "Memo plus template header"))
    }
    var message: Text? {
        Text(NSLocalizedString("이 단축어에 템플릿이 연결돼 있어요. 빈칸을 채우면 단축어 내용과 합쳐서 복사돼요. 아래 '입력될 결과'에서 미리 볼 수 있어요.", comment: "Attached template explanation"))
    }
    var mascotPose: MascotPose { .explaining }
}

// MARK: - QuickNoteInboxTip
// 빠른 메모(Inbox) 캡처를 가르치는 팁. 앱을 어느 정도 써본(engaged) 사용자에게,
// "어디서든 담아 보관함에 모인다"는 외부 캡처 진입점을 자연스럽게 안내한다.
// 더보기(⋯) 메뉴 버튼에 popoverTip으로 부착된다.

struct QuickNoteInboxTip: MascotTip {
    @Parameter
    static var engaged: Bool = false

    var title: Text {
        Text(NSLocalizedString("어디서든 빠르게 담으세요", comment: "Quick note inbox tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("공유 시트·단축어·제어 센터로 담은 항목은 ⋯ 메뉴의 보관함에 모여요. 나중에 키보드 단축어로 저장하면 돼요.", comment: "Quick note inbox tip message"))
    }
    var mascotPose: MascotPose { .carrying }

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
