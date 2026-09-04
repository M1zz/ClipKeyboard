//
//  PersonaPrompt.swift
//  ClipKeyboard
//
//  페르소나를 **언제 물을 것인가.**
//
//  예전에는 처음 여는 자리에서 물었다. 그 자리에서는 아무도 답을 모른다. 앱을 아직
//  안 써 봤으니 "디지털 노마드"와 "학생" 중에 무엇을 고르면 자기 화면이 어떻게 되는지
//  알 길이 없고, 무엇보다 **아직 이 앱이 무엇인지도 모른다.** 그래서 아무거나 누르고
//  들어오거나, 그 화면에서 나가 버린다.
//
//  ⚠️ 그래서 **써 보고 나서** 묻는다. 단축어를 두 개 만들었거나 카테고리를 하나
//     만들었다면, 그때는 이 앱으로 무엇을 하려는지 자기가 안다. 그 사람에게
//     "혹시 이런 분이신가요?" 는 답할 수 있는 질문이다.
//
//  ⚠️ 그전까지는 **일반**으로 둔다(`Persona.default`). 모르는 채로 좁히지 않는다.
//     좁게 잡았다가 틀리면 엉뚱한 추천이 나가고, 그건 아무 추천도 안 하느니만 못하다.
//
//  ⚠️ **한 번만 묻는다.** 답을 했든 미뤘든 다시 묻지 않는다. 두 번째부터는 질문이
//     아니라 성가신 것이 된다. 나중에 마음이 바뀌면 설정 > 페르소나에 늘 있다.
//

import Foundation

enum PersonaPrompt {

    /// 물어본 적 있는가. 답을 했든 미뤘든 켜진다.
    private static let askedKey = "persona.prompt.asked.v1"

    /// 단축어를 이만큼 만들었으면 물어볼 때가 됐다.
    ///
    /// 근거: 하나는 우연일 수 있다(튜토리얼을 따라 만든 것일 수도 있다). 둘째를 만들었다는
    /// 것은 **첫 번째가 쓸모 있었다는 뜻**이고, 그때 비로소 이 앱을 자기 방식으로 쓰기
    /// 시작한다. 셋 넷까지 기다리면 그 사이의 추천이 전부 일반으로만 나간다.
    static let snippetThreshold = 2

    /// 카테고리는 **하나만 만들어도** 묻는다.
    ///
    /// 근거: 카테고리를 만드는 일은 단축어를 만드는 일보다 훨씬 드물고 의도적이다.
    /// 이름을 직접 지어 넣었다는 것은 자기가 무엇을 모아 두려는지 이미 안다는 뜻이다.
    static let categoryThreshold = 1

    static var wasAsked: Bool {
        AppGroup.defaults?.bool(forKey: askedKey) ?? false
    }

    /// 물어봤다고 적어 둔다. **답을 안 하고 미뤘을 때도 적는다.**
    static func markAsked() {
        AppGroup.defaults?.set(true, forKey: askedKey)
        print("👤 [PersonaPrompt] 물어봤음으로 표시")
    }

    /// 지금 물어도 되는가.
    ///
    /// - Parameters:
    ///   - snippetCount: 사용자가 가진 단축어 수.
    ///   - customCategoryCount: 사용자가 **직접 만든** 카테고리 수.
    ///   - tutorialDone: 처음 안내를 다 지났는가. **안 지났으면 절대 안 묻는다** - 안내
    ///     도중에 다른 판이 끼어들면 지금 무엇을 하던 중이었는지 놓친다.
    static func shouldAsk(snippetCount: Int,
                          customCategoryCount: Int,
                          tutorialDone: Bool) -> Bool {
        guard tutorialDone else { return false }
        guard !wasAsked else { return false }
        // 이미 고른 사람에게는 묻지 않는다(설정에서 먼저 골랐을 수 있다).
        guard CategoryStore.shared.selectedPersona == nil else { return false }
        return snippetCount >= snippetThreshold || customCategoryCount >= categoryThreshold
    }

    /// 처음부터 다시 - 튜토리얼 초기화처럼 기록을 되돌릴 때만.
    static func resetAsked() {
        AppGroup.defaults?.removeObject(forKey: askedKey)
    }
}
