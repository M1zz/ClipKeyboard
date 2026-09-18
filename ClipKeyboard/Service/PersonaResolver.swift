//
//  PersonaResolver.swift
//  ClipKeyboard
//
//  지금 이 사람을 **어떤 쓰임새로 보고 있는지** 답하는 유일한 곳.
//
//  `PersonaInference` 가 순수한 판정이라면, 여기는 기기에서 값을 긁어 판정을 돌리고
//  결과를 App Group 에 적어 두는 곳이다. 화면은 판정을 직접 돌리지 않고 이 값만 읽는다.
//
//  답이 나오는 순서
//
//  1. 사람이 설정에서 **직접 정해 둔 것**(`override`). 드문 경우다 - 앱이 틀렸을 때의 탈출구.
//  2. 앱이 알아본 것(`inferred`).
//  3. 모르면 일반.
//
//  ⚠️ 화면이 물어야 할 것은 대개 `confident` 다. "확신이 없으면 좁히지 않는다" 가 규칙이라,
//     `current` 로 좁혀 보여 주면 저장한 것이 두세 개뿐인 사람에게 엉뚱한 추천이 나간다.
//
//  ⚠️ 예전에 사람이 직접 고른 페르소나(`CategoryStore.selectedPersona`)는 **한 표**로만 들어간다.
//     그 사람이 고른 뒤로 쓰임새가 바뀌었을 수 있고, 무엇보다 대부분은 첫 화면에서 아무거나
//     눌렀다(`PersonaPrompt` 가 생긴 이유였다).
//

import Foundation

enum PersonaResolver {

    private static var defaults: UserDefaults? { AppGroup.defaults }

    // MARK: - 읽기

    /// 사람이 설정에서 직접 정해 둔 쓰임새. nil 이면 앱이 알아서 본다(기본).
    static var override: Persona? {
        get { defaults?.string(forKey: DefaultsKey.personaOverride).flatMap(Persona.init(rawValue:)) }
        set {
            if let newValue {
                defaults?.set(newValue.rawValue, forKey: DefaultsKey.personaOverride)
            } else {
                defaults?.removeObject(forKey: DefaultsKey.personaOverride)
            }
            print("👤 [PersonaResolver] 직접 정한 쓰임새: \(newValue?.rawValue ?? "자동")")
        }
    }

    /// 앱이 마지막으로 알아본 쓰임새.
    static var inferred: Persona {
        defaults?.string(forKey: DefaultsKey.personaInferred).flatMap(Persona.init(rawValue:)) ?? .general
    }

    /// 앱이 알아본 것에 확신이 있는가.
    static var inferredIsConfident: Bool {
        defaults?.bool(forKey: DefaultsKey.personaInferredConfident) ?? false
    }

    /// 지금 쓸 쓰임새. 모르면 일반.
    static var current: Persona { override ?? inferred }

    /// **확신할 때만** 쓰임새, 아니면 nil. 좁혀 보여 줄지 정하는 화면은 이걸 본다.
    static var confident: Persona? {
        if let override { return override }
        return inferredIsConfident ? inferred : nil
    }

    /// 기능 맞춤(`FeatureFit`)에 넘길 한 덩어리.
    static var profile: FeatureFit.Profile {
        if let override { return FeatureFit.Profile(persona: override, isConfident: true) }
        return FeatureFit.Profile(persona: inferred, isConfident: inferredIsConfident)
    }

    // MARK: - 다시 알아보기

    /// 판정을 다시 돌려 적어 둔다. 결과를 돌려주는 것은 설정 화면이 근거를 보여 주기 위해서다.
    ///
    /// ⚠️ 부르는 자리는 `UserStateStore.refresh` 다. 이미 목록을 읽은 자리라 한 번 더 읽지 않는다.
    @discardableResult
    static func refresh(memos: [Memo], sampleIDs: Set<UUID>) -> PersonaInference.Result {
        let result = PersonaInference.infer(facts(memos: memos, sampleIDs: sampleIDs))
        let changed = result.persona != inferred || result.isConfident != inferredIsConfident
        defaults?.set(result.persona.rawValue, forKey: DefaultsKey.personaInferred)
        defaults?.set(result.isConfident, forKey: DefaultsKey.personaInferredConfident)
        if changed {
            print("👤 [PersonaResolver.refresh] 알아본 쓰임새: \(result.persona.rawValue) (확신 \(result.isConfident))")
        }
        return result
    }

    /// 지금 기기의 값으로 판정만 돌린다(적지 않는다). 설정 화면이 근거를 그릴 때 쓴다.
    static func evaluateNow() -> PersonaInference.Result {
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        return PersonaInference.infer(facts(memos: memos, sampleIDs: SampleMemoStorage.load()))
    }

    /// 판정에 넣을 값을 모은다.
    static func facts(memos: [Memo], sampleIDs: Set<UUID>) -> PersonaFacts {
        let items = memos
            .filter { !sampleIDs.contains($0.id) }
            .map { memo in
                PersonaFacts.Item(
                    title: memo.title,
                    value: memo.isSecure ? nil : memo.value,
                    type: detectedType(of: memo),
                    placeholders: memo.templateVariables.map(\.strippingTemplateBraces)
                )
            }
        return PersonaFacts(items: items,
                            customCategories: CategoryStore.shared.allCategories,
                            earlierChoice: CategoryStore.shared.selectedPersona)
    }

    /// 저장할 때 분류해 둔 종류. 없으면(예전 단축어) 짧은 글만 그 자리에서 분류한다.
    /// 긴 글은 계좌·IBAN 같은 한 줄짜리 값이 아니라 분류해도 `.text` 이고, 정규식만 오래 돈다.
    private static func detectedType(of memo: Memo) -> ClipboardItemType? {
        if let type = memo.autoDetectedType { return type }
        guard !memo.isSecure, memo.value.count <= 120 else { return nil }
        let guess = ClipboardClassificationService.shared.classify(content: memo.value)
        return guess.confidence >= 0.7 ? guess.type : nil
    }
}
