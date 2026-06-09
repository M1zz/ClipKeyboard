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

    func testPersona_DefaultIsNomad() {
        XCTAssertEqual(Persona.default, .nomad)
    }

    func testPersona_AllCases_HaveDistinctIcons() {
        let icons = Persona.allCases.map { $0.icon }
        XCTAssertEqual(Set(icons).count, icons.count, "각 페르소나는 고유 아이콘을 가져야 함")
    }

    func testPersona_AllCases_HaveNonEmptyTitles() {
        for p in Persona.allCases {
            XCTAssertFalse(p.localizedTitle.isEmpty, "\(p.rawValue) localizedTitle 누락")
            XCTAssertFalse(p.localizedDescription.isEmpty, "\(p.rawValue) localizedDescription 누락")
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
        UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?
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
        UserDefaults(suiteName: "group.com.Ysoup.TokenMemo")?
            .removeObject(forKey: "user.selected_persona.v1")
    }
}
