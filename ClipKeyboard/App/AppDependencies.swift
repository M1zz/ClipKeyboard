//
//  AppDependencies.swift
//  Token memo
//

import Foundation

/// 앱 전체 의존성 조립 컨테이너
/// View에서: @Environment(AppDependencies.self) var deps
final class AppDependencies: ObservableObject {
    static let shared = AppDependencies()

    // MARK: - Storage
    let storage = AppGroupStorage.shared

    // MARK: - Repositories
    lazy var memoRepository: MemoRepositoryProtocol = MemoRepository(storage: storage)
    lazy var clipboardRepository: ClipboardRepositoryProtocol = ClipboardRepository(storage: storage)
    lazy var comboRepository: ComboRepositoryProtocol = ComboRepository(storage: storage)

    // MARK: - Use Cases
    lazy var classifyClipboard = ClassifyClipboardUseCase()
    lazy var saveMemo: SaveMemoUseCase = SaveMemoUseCase(memoRepository: memoRepository)

    // MARK: - ViewModel Factories
    @MainActor
    func makeMemoAddViewModel(editingMemo: Memo? = nil) -> MemoAddViewModel {
        MemoAddViewModel(
            saveMemoUseCase: saveMemo,
            memoRepository: memoRepository,
            editingMemo: editingMemo
        )
    }
}
