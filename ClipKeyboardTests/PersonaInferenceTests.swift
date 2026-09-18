//
//  PersonaInferenceTests.swift
//  ClipKeyboardTests
//
//  묻지 않고 저장한 것으로 쓰임새를 알아보는 판정.
//  **확신하지 말아야 할 때**(신호가 적거나 갈릴 때)를 알아보는 경우만큼 많이 적었다.
//  좁게 잡았다가 틀리면 엉뚱한 추천이 나간다.
//

import Testing
import Foundation
@testable import ClipKeyboard

struct PersonaInferenceTests {

    private typealias Item = PersonaFacts.Item

    @Test("아무것도 없으면 일반이고 확신하지 않는다")
    func emptyIsUnknown() {
        let result = PersonaInference.infer(PersonaFacts())
        #expect(result.persona == .general)
        #expect(!result.isConfident)
    }

    @Test("IBAN·SWIFT 와 시차 빈칸을 저장한 사람은 노마드다")
    func nomadFromTypesAndPlaceholders() {
        let facts = PersonaFacts(items: [
            Item(title: "송금 정보", value: "IBAN PT50 0002 0123 1234 5678 9015 4", type: .iban),
            Item(title: "SWIFT", value: "BCOMPTPL", type: .swift),
            Item(title: "시차 안내", value: "I'm in GMT+{시차} ({도시})", placeholders: ["시차", "도시"])
        ])
        let result = PersonaInference.infer(facts)
        #expect(result.persona == .nomad)
        #expect(result.isConfident)
        #expect(result.evidence.contains { $0.kind == .type(.iban) })
    }

    @Test("학번·교수님 메일·조별과제 공지를 저장한 사람은 학생이다")
    func studentFromWords() {
        let facts = PersonaFacts(items: [
            Item(title: "학번", value: "경영학과 2023123456 이서준"),
            Item(title: "교수님 메일", value: "안녕하세요 교수님, {학과} {학번} {이름}입니다.", placeholders: ["학과", "학번", "이름"]),
            Item(title: "조별과제 공지", value: "[{과제}] 회의 {날짜}", placeholders: ["과제"])
        ])
        let result = PersonaInference.infer(facts)
        #expect(result.persona == .student)
        #expect(result.isConfident)
    }

    @Test("세금계산서·고객사·미팅 팔로업은 직장인이다")
    func businessFromWords() {
        let facts = PersonaFacts(items: [
            Item(title: "사업자 정보", value: "사업자등록번호 123-45-67890 세금계산서 메일", type: .taxID),
            Item(title: "미팅 팔로업", value: "{담당자}님, 오늘 {고객사} 미팅 감사합니다", placeholders: ["담당자", "고객사"]),
            Item(title: "주간 보고", value: "금주 주간보고 드립니다")
        ])
        let result = PersonaInference.infer(facts)
        #expect(result.persona == .business)
        #expect(result.isConfident)
    }

    @Test("단서가 한두 개뿐이면 확신하지 않는다")
    func weakSignalIsNotConfident() {
        let facts = PersonaFacts(items: [
            Item(title: "여권", value: nil, type: .passportNumber)
        ])
        let result = PersonaInference.infer(facts)
        #expect(!result.isConfident)
        #expect(result.persona == .general)
        #expect(result.evidence.isEmpty)
    }

    @Test("두 쓰임새가 비슷하게 섞이면 확신하지 않는다")
    func mixedSignalsAreNotConfident() {
        let facts = PersonaFacts(items: [
            Item(title: "IBAN", value: "PT50...", type: .iban),
            Item(title: "SWIFT", value: "BCOMPTPL", type: .swift),
            Item(title: "교수님 메일", value: "교수님, 과제 제출합니다", placeholders: ["학번", "과목"]),
            Item(title: "조별 공지", value: "조별 회의 강의실")
        ])
        #expect(!PersonaInference.infer(facts).isConfident)
    }

    @Test("영어 낱말은 다른 낱말 속에서 잡지 않는다 (otherwise 의 wise, public 의 bic)")
    func englishWordBoundaries() {
        let facts = PersonaFacts(items: [
            Item(title: "note", value: "Otherwise the public library is closed. Likewise the swiftly moving line."),
            Item(title: "note 2", value: "otherwise public"),
            Item(title: "note 3", value: "likewise publication")
        ])
        #expect(PersonaInference.infer(facts).scores[.nomad] == nil)
    }

    @Test("한 글자 빈칸 이름은 통째로 같을 때만 본다 (분반은 반이 아니다)")
    func singleCharacterPlaceholder() {
        let facts = PersonaFacts(items: [Item(title: "출석", value: "{분반}", placeholders: ["분반"])])
        #expect(PersonaInference.infer(facts).scores[.general] == nil)
    }

    @Test("예전에 직접 고른 페르소나는 한 표일 뿐, 저장한 것이 더 크게 말한다")
    func earlierChoiceIsOneVote() {
        let facts = PersonaFacts(items: [
            Item(title: "학번", value: "2023123456 학과 교수"),
            Item(title: "과제", value: "과제 제출 강의", placeholders: ["과목", "분반"])
        ], earlierChoice: .nomad)
        #expect(PersonaInference.infer(facts).persona == .student)
    }

    @Test("공동현관·택배·회비만 있는 사람은 일반으로 확신한다")
    func generalCanBeConfident() {
        let facts = PersonaFacts(items: [
            Item(title: "집 주소", value: "103동 1204호 공동현관 #1204*", type: .address),
            Item(title: "택배 요청", value: "택배는 문 앞에"),
            Item(title: "모임 회비", value: "회비 계좌 카카오뱅크", type: .bankAccount),
            Item(title: "배달 요청", value: "배달은 벨 누르지 말아주세요")
        ])
        let result = PersonaInference.infer(facts)
        #expect(result.persona == .general)
        #expect(result.isConfident)
    }
}
