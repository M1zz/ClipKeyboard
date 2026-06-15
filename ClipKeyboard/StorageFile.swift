//
//  StorageFile.swift
//  ClipKeyboard
//
//  자동 생성 가능 — 정적 App Group 저장 파일명 단일 출처(Single Source of Truth).
//  메인앱·키보드(ClipKeyboardExtension)·macOS(.tap) 3개 타겟이 공유한다.
//  하드코딩 리터럴 대신 항상 이 상수를 사용할 것.
//

import Foundation

enum StorageFile {
    static let clipboardHistory = "clipboard.history.data"
    static let combos = "combos.data"
    static let memoHistory = "memo.history.data"
    static let memos = "memos.data"
    static let smartClipboardHistory = "smart.clipboard.history.data"
}
