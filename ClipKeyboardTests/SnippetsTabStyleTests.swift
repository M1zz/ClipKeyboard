//
//  SnippetsTabStyleTests.swift
//  ClipKeyboardTests
//
//  첫 화면(단축어 탭)이 무엇을 보여줄지의 계약을 고정한다.
//
//  가장 중요한 한 가지: **쓰던 사람의 첫 화면은 업데이트로 바뀌지 않는다.**
//  저장된 값이 없다는 것은 "아직 고른 적 없다"이지 "새 화면을 원한다"가 아니다.
//  새 설치에만 첫 실행에서 무대를 뿌리고, 기존 사용자에게는 1회 제안만 간다.
//
//  스킨 스위치도 함께 붙잡아 둔다 — 감추는 것(설정)과 되돌리는 것(화면)은 **함께**
//  일어나야 한다. 고를 수 없는데 남의 화면만 달라져 있으면 "왜 내 것만 이렇지"가 된다.
//

import Testing
import Foundation
@testable import ClipKeyboard

@Suite("SnippetsTabStyle — 첫 화면", .serialized)
struct SnippetsTabStyleTests {

    @Test("저장된 값이 없으면 **목록** — 쓰던 사람 쪽에 맞춘다")
    func defaultsToList() {
        let d = UserDefaults.standard
        let saved = d.string(forKey: DefaultsKey.snippetsTabStyle)
        defer { saved.map { d.set($0, forKey: DefaultsKey.snippetsTabStyle) } }

        d.removeObject(forKey: DefaultsKey.snippetsTabStyle)
        #expect(SnippetsTabStyle.current == .list)
    }

    @Test("모르는 값이어도 목록으로 떨어진다 — 첫 화면이 비면 안 된다")
    func unknownFallsBackToList() {
        let d = UserDefaults.standard
        let saved = d.string(forKey: DefaultsKey.snippetsTabStyle)
        defer {
            if let saved { d.set(saved, forKey: DefaultsKey.snippetsTabStyle) }
            else { d.removeObject(forKey: DefaultsKey.snippetsTabStyle) }
        }

        d.set("gundam", forKey: DefaultsKey.snippetsTabStyle)
        #expect(SnippetsTabStyle.current == .list)
    }

    @Test("고른 값은 그대로 살아난다")
    func roundTrips() {
        let d = UserDefaults.standard
        let saved = d.string(forKey: DefaultsKey.snippetsTabStyle)
        defer {
            if let saved { d.set(saved, forKey: DefaultsKey.snippetsTabStyle) }
            else { d.removeObject(forKey: DefaultsKey.snippetsTabStyle) }
        }

        for style in SnippetsTabStyle.allCases {
            d.set(style.rawValue, forKey: DefaultsKey.snippetsTabStyle)
            #expect(SnippetsTabStyle.current == style)
        }
    }

    @Test("두 화면 다 이름과 설명이 있다 — 이름만으로는 뭐가 다른지 모른다")
    func bothStylesAreExplained() {
        for style in SnippetsTabStyle.allCases {
            #expect(!style.localizedName.isEmpty)
            #expect(!style.localizedDescription.isEmpty)
            #expect(!style.symbolName.isEmpty)
        }
    }
}

@Suite("스킨 스위치 — 지금은 꺼져 있다")
struct SkinDisabledTests {

    @Test("키캡 스킨은 저장된 값이 무엇이든 예전 모습으로 보인다")
    func keyboardSkinResolvesToClassic() {
        #expect(KeyboardSkin.isEnabled == false)
        for skin in KeyboardSkin.allCases {
            #expect(KeyboardSkin.resolved(skin.rawValue) == .classic)
        }
        #expect(KeyboardSkin.current == .classic)
    }

    @Test("생활 레이어도 저장된 값이 무엇이든 없음으로 보인다")
    func livingSkinResolvesToNone() {
        #expect(LivingSkin.isEnabled == false)
        for skin in LivingSkin.allCases {
            #expect(LivingSkin.resolved(skin.rawValue) == LivingSkin.none)
        }
        #expect(LivingSkin.current == LivingSkin.none)
    }

    @Test("되살릴 준비는 되어 있다 — rawValue 왕복은 그대로 살아 있다")
    func rawValuesStillRoundTrip() {
        // 스위치를 켜는 순간 예전 선택이 그대로 살아나야 한다(값을 지우지 않았다).
        for skin in KeyboardSkin.allCases {
            #expect(KeyboardSkin(rawValue: skin.rawValue) == skin)
        }
        for skin in LivingSkin.allCases {
            #expect(LivingSkin(rawValue: skin.rawValue) == skin)
        }
    }
}
