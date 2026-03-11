//
//  ComboRepositoryProtocol.swift
//  Token memo
//

import Foundation

protocol ComboRepositoryProtocol {
    func fetchAll() throws -> [Combo]
    func save(_ combos: [Combo]) throws
    func add(_ combo: Combo) throws
    func update(_ combo: Combo) throws
    func delete(id: UUID) throws
    func incrementUseCount(id: UUID) throws
}
