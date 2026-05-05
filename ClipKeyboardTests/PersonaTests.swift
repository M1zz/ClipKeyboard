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

    func testApplyPersona_AddsSeedCategories() {
        let store = CategoryStore.shared
        let originalSnapshot = store.allCategories

        store.applyPersona(.nomad, language: "en")

        let after = store.allCategories
        XCTAssertTrue(after.contains("Passport"), "페르소나 시드가 추가되어야 함")
        XCTAssertTrue(after.contains("IBAN"))
        // 기존 카테고리도 유지되어야 함
        for original in originalSnapshot {
            XCTAssertTrue(after.contains(original), "기존 카테고리 \(original) 유실")
        }

        // cleanup — 추가한 시드만 제거
        let toRemove = Persona.nomad.seedCategories(language: "en")
            .filter { !originalSnapshot.contains($0) }
        for seed in toRemove {
            _ = store.remove(seed)
        }
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
