//
//  KeyboardAppLinkTests.swift
//  ClipKeyboardTests
//
//  진짜 키보드에서만 일어나야 하는 두 가지를 고정한다.
//  - 전체 접근이 꺼져 있다는 안내 줄 (`KeyboardHostKind.showsFullAccessNotice`)
//  - 빈칸 값 옆의 + 가 앱을 여는 것 (`KeyboardHostKind.opensAppToAddValue`)
//
//  왜 필요한가: 같은 `KeyboardView` 가 진짜 키보드 · 키보드 탭 · 설정 미리보기 세 곳에서 산다.
//  앱 안에서 "전체 접근을 켜세요" 가 뜨면 엉뚱한 말이고(앱에는 그 개념이 없다),
//  앱 안의 + 가 앱을 다시 열려 하면 아무 일도 안 일어난다.
//

import Testing
@testable import ClipKeyboard

// ⚠️ 전역 `KeyboardCapability` 를 만지지 않는다. 다른 묶음(앱 안 키보드 시험)이 같은 때에
//    그 값을 true 로 바꿔서, 여기서 false 를 가정하면 순서에 따라 깨졌다.
@Suite("키보드에서 앱으로 잇는 것들")
struct KeyboardAppLinkTests {

    @Test("전체 접근 안내는 진짜 키보드에서, 꺼져 있을 때만 선다")
    func fullAccessNoticeOnlyInExtensionWhenOff() {
        #expect(KeyboardHostKind.keyboardExtension.showsFullAccessNotice(hasFullAccess: false))
        #expect(!KeyboardHostKind.inApp.showsFullAccessNotice(hasFullAccess: false))
        #expect(!KeyboardHostKind.settingsPreview.showsFullAccessNotice(hasFullAccess: false))

        #expect(!KeyboardHostKind.keyboardExtension.showsFullAccessNotice(hasFullAccess: true))
    }

    @Test("빈칸 값의 + 는 진짜 키보드에서만 앱을 연다. 앱 안은 그 자리에서 적는다")
    func addValueOpensAppOnlyInExtension() {
        #expect(KeyboardHostKind.keyboardExtension.opensAppToAddValue)
        #expect(!KeyboardHostKind.keyboardExtension.showsOneOffValueHint)

        #expect(!KeyboardHostKind.inApp.opensAppToAddValue)
        #expect(KeyboardHostKind.inApp.showsOneOffValueHint)

        // 설정 미리보기도 앱 안이라 그 자리에서 적는다.
        #expect(!KeyboardHostKind.settingsPreview.opensAppToAddValue)
        #expect(KeyboardHostKind.settingsPreview.showsOneOffValueHint)
    }
}
