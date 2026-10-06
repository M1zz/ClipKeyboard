//
//  PersonaTests.swift
//  ClipKeyboardTests
//
//  Persona enum + CategoryStore.applyPersona 동작 검증.
//

import XCTest
@testable import ClipKeyboard

final class PersonaTests: XCTestCase {

    // MARK: - Persona enum

    /// 아무것도 안 고른 사람이 처음 보게 되는 갈래는 가장 넓은 것이어야 한다.
    ///
    /// 노마드였던 것은 이 앱이 국제 송금·비자에서 출발했다는 만든 사람의 사정이지
    /// 쓰는 사람의 사정이 아니었다. 좁히는 일은 묻지 않고 저장한 것을 보고 앱이 한다(`PersonaInference`).
    func testPersona_DefaultIsGeneral() {
        XCTAssertEqual(Persona.default, .general)
    }

    func testPersona_AllCases_HaveDistinctIcons() {
        let icons = Persona.allCases.map { $0.icon }
        XCTAssertEqual(Set(icons).count, icons.count, "각 페르소나는 고유 아이콘을 가져야 함")
    }

    func testPersona_AllCases_HaveNonEmptyTitles() {
        for p in Persona.allCases {
            XCTAssertFalse(p.localizedTitle.isEmpty, "\(p.rawValue) localizedTitle 누락")
        }
    }

    func testPersona_RawValuesAreStable() {
        // analytics + UserDefaults 영속에 사용되므로 raw value가 안정적이어야 함
        XCTAssertEqual(Persona.nomad.rawValue, "nomad")
        XCTAssertEqual(Persona.business.rawValue, "business")
        XCTAssertEqual(Persona.student.rawValue, "student")
        XCTAssertEqual(Persona.general.rawValue, "general")
    }

    func testPersona_Codable() throws {
        for p in Persona.allCases {
            let data = try JSONEncoder().encode(p)
            let decoded = try JSONDecoder().decode(Persona.self, from: data)
            XCTAssertEqual(decoded, p)
        }
    }

    // MARK: - Seed categories

    func testSeedCategories_NomadKO_HasKoreanLabels() {
        let seeds = Persona.nomad.seedCategories(language: "ko")
        XCTAssertFalse(seeds.isEmpty)
        XCTAssertTrue(seeds.contains("여권번호"))
        XCTAssertTrue(seeds.contains("IBAN"))
    }

    func testSeedCategories_NomadEN_HasEnglishLabels() {
        let seeds = Persona.nomad.seedCategories(language: "en")
        XCTAssertTrue(seeds.contains("Passport"))
        XCTAssertTrue(seeds.contains("IBAN"))
    }

    func testSeedCategories_NomadID_HasIndonesianLabels() {
        let seeds = Persona.nomad.seedCategories(language: "id")
        XCTAssertTrue(seeds.contains("Paspor"))
    }

    func testSeedCategories_UnknownLanguage_FallsBackToEnglish() {
        let seeds = Persona.nomad.seedCategories(language: "fr")
        XCTAssertTrue(seeds.contains("Passport"))
    }

    func testSeedCategories_AllPersonas_NonEmpty() {
        for p in Persona.allCases {
            for lang in ["ko", "en", "id"] {
                let seeds = p.seedCategories(language: lang)
                XCTAssertFalse(seeds.isEmpty, "\(p.rawValue)/\(lang) 시드가 비어있음")
                XCTAssertEqual(Set(seeds).count, seeds.count, "\(p.rawValue)/\(lang) 시드 내 중복 존재")
            }
        }
    }

    // MARK: - CategoryStore.applyPersona

    func testApplyPersona_PersistsSelectionWithoutMutatingCategories() {
        // 현재 동작: applyPersona는 페르소나 선택만 저장하고 카테고리는 시드하지 않는다
        // (사용자가 직접 카테고리를 만든다). 기존 카테고리는 그대로 보존돼야 한다.
        let store = CategoryStore.shared
        let before = store.allCategories

        store.applyPersona(.nomad, language: "en")

        XCTAssertEqual(store.selectedPersona, .nomad, "페르소나 선택이 저장돼야 함")
        XCTAssertEqual(store.allCategories, before, "applyPersona는 카테고리를 변경하지 않아야 함")
    }

    func testApplyPersona_PersistsSelection() {
        let store = CategoryStore.shared
        store.applyPersona(.business, language: "en")

        XCTAssertEqual(store.selectedPersona, .business)

        // cleanup
        AppGroup.defaults?
            .removeObject(forKey: "user.selected_persona.v1")
    }

    func testApplyPersona_Idempotent_NoDuplicates() {
        let store = CategoryStore.shared
        store.applyPersona(.student, language: "en")
        let firstCount = store.allCategories.count

        store.applyPersona(.student, language: "en")
        let secondCount = store.allCategories.count

        XCTAssertEqual(firstCount, secondCount, "같은 페르소나 재적용 시 중복 추가 금지")

        // cleanup
        let seeds = Persona.student.seedCategories(language: "en")
        for seed in seeds {
            _ = store.remove(seed)
        }
        AppGroup.defaults?
            .removeObject(forKey: "user.selected_persona.v1")
    }

    // MARK: - PersonaResolver 지문 (판정 건너뛰기)

    /// 넣을 값이 같으면 지문도 같아야 한다. 다르면 앱을 켤 때마다 판정이 다시 돈다.
    func testFingerprint_SameInput_SameStamp() {
        let memos = [Memo(title: "회사 주소", value: "서울시 강남구"),
                     Memo(title: "계좌", value: "123-456")]
        XCTAssertEqual(PersonaResolver.fingerprint(memos: memos, sampleIDs: []),
                       PersonaResolver.fingerprint(memos: memos, sampleIDs: []))
    }

    /// 판정이 읽는 값이 하나라도 바뀌면 지문이 바뀌어야 한다. 안 바뀌면 쓰임새가 낡은 채로 남는다.
    func testFingerprint_ChangesWhenInferenceInputChanges() {
        let base = Memo(title: "회사 주소", value: "서울시 강남구", templateVariables: [])
        let stamp = PersonaResolver.fingerprint(memos: [base], sampleIDs: [])

        var title = base; title.title = "학교 주소"
        var value = base; value.value = "부산시"
        var secure = base; secure.isSecure = true
        var type = base; type.autoDetectedType = .address
        var placeholder = base; placeholder.templateVariables = ["{이름}"]

        for changed in [title, value, secure, type, placeholder] {
            XCTAssertNotEqual(PersonaResolver.fingerprint(memos: [changed], sampleIDs: []), stamp)
        }
        XCTAssertNotEqual(PersonaResolver.fingerprint(memos: [base, base], sampleIDs: []), stamp,
                          "단축어가 늘면 지문이 바뀌어야 함")
    }

    /// 앱이 심어 준 샘플은 판정에 안 들어가므로 지문에도 안 들어간다.
    func testFingerprint_IgnoresSamples() {
        let own = Memo(title: "회사 주소", value: "서울시 강남구")
        let sample = Memo(title: "연습용", value: "hello")
        XCTAssertEqual(PersonaResolver.fingerprint(memos: [own, sample], sampleIDs: [sample.id]),
                       PersonaResolver.fingerprint(memos: [own], sampleIDs: []))
    }

    /// 칸 구분이 없으면 "ab"+"c" 와 "a"+"bc" 가 같은 지문이 된다.
    func testFingerprint_FieldBoundariesMatter() {
        let a = Memo(title: "ab", value: "c")
        let b = Memo(title: "a", value: "bc")
        XCTAssertNotEqual(PersonaResolver.fingerprint(memos: [a], sampleIDs: []),
                          PersonaResolver.fingerprint(memos: [b], sampleIDs: []))
    }
}
