//
//  UUIDExtension.swift
//  ClipKeyboard
//
//  UUID 하나를 그대로 SwiftUI에 넘길 수 있게 한다.
//
//  `.sheet(item:)` 같은 자리는 Identifiable 을 요구하는데 UUID 는 그것을 제공하지 않는다.
//  목록 화면 파일 맨 위에 얹혀 있던 것을 여기로 옮겼다. 특정 화면의 사정이 아니라
//  이 모듈 전체가 기대는 성질이라, 화면 파일에 있으면 찾을 수가 없다.
//

import Foundation

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
