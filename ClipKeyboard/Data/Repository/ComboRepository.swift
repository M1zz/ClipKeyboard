//
//  ComboRepository.swift
//  Token memo
//

import Foundation

final class ComboRepository: ComboRepositoryProtocol {
    private let storage: AppGroupStorage

    init(storage: AppGroupStorage = .shared) {
        self.storage = storage
    }

    func fetchAll() throws -> [Combo] {
        try MemoStore.shared.loadCombos()
    }

    func save(_ combos: [Combo]) throws {
        try MemoStore.shared.saveCombos(combos)
    }

    func add(_ combo: Combo) throws {
        try MemoStore.shared.addCombo(combo)
    }

    func update(_ combo: Combo) throws {
        try MemoStore.shared.updateCombo(combo)
    }

    func delete(id: UUID) throws {
        try MemoStore.shared.deleteCombo(id: id)
    }

    func incrementUseCount(id: UUID) throws {
        try MemoStore.shared.incrementComboUseCount(id: id)
    }
}
