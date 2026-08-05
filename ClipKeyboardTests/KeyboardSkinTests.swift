//
//  KeyboardSkinTests.swift
//  ClipKeyboardTests
//
//  키캡 스킨의 계약을 고정한다.
//
//  가장 중요한 두 지점:
//   ① **기본값은 항상 `.standard`** — 업데이트했다고 남의 키보드 모양이 멋대로 바뀌면 안 된다.
//      저장된 값이 없거나, 깨졌거나, 예전 버전이 쓰던 모르는 값이어도 기본으로 떨어져야 한다.
//   ② **스킨은 색을 정하지 않는다** — 색은 테마와 커스텀 키 색이 담당한다.
//      스킨이 색까지 건드리기 시작하면 셋이 서로 덮어쓰며 싸운다.
//

import Testing
import SwiftUI
@testable import ClipKeyboard

@Suite("KeyboardSkin — 키캡 물성")
struct KeyboardSkinTests {

    // MARK: - 기본값

    @Test("알 수 없는 값은 기본 스킨으로 떨어진다")
    func unknownRawValueFallsBack() {
        #expect(KeyboardSkin(rawValue: "gundam") == nil)
        #expect(KeyboardSkin(rawValue: "") == nil)
    }

    @Test("모든 스킨은 rawValue로 왕복한다 — 저장·복원이 안전해야 한다")
    func roundTrips() {
        for skin in KeyboardSkin.allCases {
            #expect(KeyboardSkin(rawValue: skin.rawValue) == skin)
        }
    }

    @Test("기본 스킨은 지금까지의 값을 그대로 유지한다")
    func standardKeepsExistingLook() {
        let standard = KeyboardSkin.standard
        // 이 값들이 바뀌면 기존 사용자의 키보드 생김새가 말없이 달라진다.
        #expect(standard.skirtDepth == 3)
        #expect(standard.shadowOpacity == 0.08)
        #expect(standard.cornerRadius(base: 14) == 14)   // 테마 값 그대로
    }

    // MARK: - 물성 일관성

    /// 두께가 0이면 눌릴 바닥이 없다 — 스커트 그늘도 0이어야 앞뒤가 맞는다.
    @Test("납작 스킨은 두께·그늘·그림자가 모두 없다")
    func flatHasNoDepth() {
        let flat = KeyboardSkin.flat
        #expect(flat.skirtDepth == 0)
        #expect(flat.skirtOpacity(isDark: false) == 0)
        #expect(flat.skirtOpacity(isDark: true) == 0)
        #expect(flat.shadowOpacity == 0)
        #expect(flat.sheenOpacity(isDark: false) == 0)
    }

    @Test("기계식은 가장 두껍고 가장 빠르게 내려간다")
    func mechanicalIsDeepestAndSnappiest() {
        let mech = KeyboardSkin.mechanical
        for other in KeyboardSkin.allCases where other != mech {
            #expect(mech.skirtDepth >= other.skirtDepth)
            #expect(mech.pressDuration <= other.pressDuration)
        }
    }

    @Test("말랑은 가장 둥글고 가장 느긋하게 돌아온다")
    func softIsRoundestAndSlowest() {
        let soft = KeyboardSkin.soft
        for other in KeyboardSkin.allCases where other != soft {
            #expect(soft.cornerRadius(base: 14) >= other.cornerRadius(base: 14))
            #expect(soft.releaseResponse >= other.releaseResponse)
        }
    }

    @Test("모든 스킨의 값이 실제로 그릴 수 있는 범위 안에 있다")
    func valuesStayInRange() {
        for skin in KeyboardSkin.allCases {
            #expect(skin.skirtDepth >= 0 && skin.skirtDepth <= 8)
            #expect(skin.cornerRadius(base: 14) > 0)
            #expect(skin.pressDuration > 0 && skin.pressDuration < 0.3)
            #expect(skin.releaseResponse > 0)
            #expect(skin.releaseDamping > 0 && skin.releaseDamping <= 1)
            for isDark in [true, false] {
                #expect(skin.skirtOpacity(isDark: isDark) >= 0 && skin.skirtOpacity(isDark: isDark) <= 1)
                #expect(skin.sheenOpacity(isDark: isDark) >= 0 && skin.sheenOpacity(isDark: isDark) <= 1)
            }
            #expect(skin.shadowOpacity >= 0 && skin.shadowOpacity <= 1)
        }
    }

    /// 모서리는 테마가 정한 스케일을 **비율로만** 조정한다.
    /// 절대값을 박아두면 테마를 바꿨을 때 키만 어긋난다.
    @Test("모서리는 테마 값에 비례한다")
    func cornerRadiusScalesWithTheme() {
        for skin in KeyboardSkin.allCases {
            let small = skin.cornerRadius(base: 10)
            let large = skin.cornerRadius(base: 20)
            #expect(large > small)
            #expect(abs(large - small * 2) < 0.001)
        }
    }

    // MARK: - 표시

    @Test("이름과 설명이 모두 채워져 있고 서로 다르다")
    func labelsAreDistinct() {
        var names = Set<String>()
        for skin in KeyboardSkin.allCases {
            #expect(!skin.localizedName.isEmpty)
            #expect(!skin.localizedDescription.isEmpty)
            #expect(names.insert(skin.localizedName).inserted, "스킨 이름이 겹치면 고를 수 없다")
        }
    }

    @Test("선택지가 하나뿐이면 설정 화면을 만들 이유가 없다")
    func hasMultipleChoices() {
        #expect(KeyboardSkin.allCases.count >= 3)
        #expect(KeyboardSkin.allCases.first == .standard, "기본이 목록 맨 위에 있어야 한다")
    }
}
