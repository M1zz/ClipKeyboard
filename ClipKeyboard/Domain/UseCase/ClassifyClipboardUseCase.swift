//
//  ClassifyClipboardUseCase.swift
//  ClipKeyboard
//

import Foundation

/// 클립보드 내용을 분석해 타입과 신뢰도를 반환하는 UseCase
/// ClipboardClassificationService의 순수 함수 버전
struct ClassifyClipboardUseCase {
    static let shared = ClassifyClipboardUseCase()

    func execute(_ content: String) -> (type: ClipboardItemType, confidence: Double) {
        ClipboardClassificationService.shared.classify(content: content)
    }
}
