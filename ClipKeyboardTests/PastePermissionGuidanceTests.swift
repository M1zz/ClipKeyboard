//
//  PastePermissionGuidanceTests.swift
//  ClipKeyboardTests
//
//  **설치 첫날에는 클립보드를 건드리지 않는다**는 약속을 고정한다.
//
//  iOS는 앱이 클립보드를 읽는 순간 "붙여넣기 허용?" 팝업을 띄운다. 설치 당일 그게 뜨면
//  신규 사용자가 이 앱에서 보는 첫 다이얼로그가 권한 요청이 된다 - 무엇을 하는 앱인지
//  알기도 전에 거절할지를 묻는 셈이다. 며칠 써 본 뒤라야 허용할 이유가 생긴다.
//
//  ⚠️ 이 계약이 깨지는 방식은 조용하다. 팝업은 시뮬레이터·테스트에서 안 보이고
//     실기기 신규 설치에서만 튀어나온다. 그래서 날짜 경계를 여기서 붙잡아 둔다.
//

import Testing
import Foundation
@testable import ClipKeyboard

@Suite("PastePermissionGuidance, 붙여넣기 팝업 시점", .serialized)
struct PastePermissionGuidanceTests {

    private static let installKey = "app_install_date"

    /// 설치일을 원하는 시점으로 바꿔 두고 검사한 뒤 원래대로 돌려 둔다.
    private func withInstallDate(daysAgo: Double, _ body: () -> Void) {
        let d = UserDefaults.standard
        let saved = d.object(forKey: Self.installKey) as? Date
        defer {
            if let saved { d.set(saved, forKey: Self.installKey) }
            else { d.removeObject(forKey: Self.installKey) }
        }
        d.set(Date().addingTimeInterval(-daysAgo * 24 * 60 * 60), forKey: Self.installKey)
        body()
    }

    @Test("설치 당일에는 클립보드를 읽지 않는다. 팝업이 앱의 첫인상이 되면 안 된다")
    func doesNotReadOnInstallDay() {
        withInstallDate(daysAgo: 0) {
            #expect(PastePermissionGuidance.isWarmedUp == false)
            #expect(PastePermissionGuidance.mayAutoReadClipboard == false)
            #expect(PastePermissionGuidance.isReady == false)
        }
    }

    @Test("하루 지나도, 이틀 지나도 아직이다")
    func stillWaitsBeforeWarmUpDays() {
        for day in [1.0, 2.0, 2.9] {
            withInstallDate(daysAgo: day) {
                #expect(PastePermissionGuidance.mayAutoReadClipboard == false,
                        "설치 \(day)일 뒤에는 아직 읽으면 안 된다")
            }
        }
    }

    @Test("3일이 지나면 그때부터 모은다")
    func readsAfterWarmUp() {
        withInstallDate(daysAgo: Double(PastePermissionGuidance.warmUpDays)) {
            #expect(PastePermissionGuidance.isWarmedUp)
            #expect(PastePermissionGuidance.mayAutoReadClipboard)
        }
    }

    // ⚠️ `isReady`(며칠 + 몇 번 열어 봤는가)는 여기서 검사하지 않는다.
    //    실행 횟수(`appLaunchCount`)는 **다른 테스트도 쓰는 전역 키**라, 여기서 값을 바꾸면
    //    나란히 도는 리뷰 요청 테스트의 "초기화되면 0" 검사를 무너뜨린다(실제로 깨졌다).
    //    한쪽 테스트를 통과시키려고 다른 쪽을 흔드는 건 검사가 아니라 소음이다.
    //    날짜 경계(이 파일의 나머지)가 이 기능의 핵심이고, 실행 횟수 조건은
    //    `PastePermissionGuidance.isReady` 구현 한 줄로 읽어서 확인할 수 있다.

    // ⚠️ "설치일 기록이 없을 때" 는 여기서 검사하지 않는다.
    //    시뮬레이터의 cfprefsd 가 지운 키를 곧바로 되살려 놔서(외부에서 한 번 써 넣은 값이
    //    앱 프로세스의 removeObject 뒤에도 다시 나타난다) **삭제 상태를 만들 수가 없다.**
    //    억지로 통과시키려고 구현을 비틀면 테스트가 코드를 망가뜨리는 쪽이 된다.
    //    (그 경로의 규칙 자체는 `PastePermissionGuidance.installDate` 주석에 남겨 두었다
    //     모르면 지금을 설치일로 찍고, 즉 **기다리는 쪽**으로 붙는다)

}

@Suite("KeyboardInstallState, 키보드를 쓸 수 있는 상태인가")
struct KeyboardInstallStateTests {

    @Test("익스텐션 번들 ID는 앱 번들 아래에 있어야 한다. 틀리면 영영 '못 쓴다'가 된다")
    func extensionBundleIDIsCorrect() {
        #expect(KeyboardInstallState.extensionBundleID.hasPrefix("com.Ysoup.TokenMemo."))
        #expect(KeyboardInstallState.extensionBundleID == "com.Ysoup.TokenMemo.ClipKeyboardExtension")
    }

    @Test("설정에 우리 키보드가 있으면 켜진 것")
    func enabledWhenListed() {
        let ours = KeyboardInstallState.extensionBundleID
        #expect(KeyboardInstallState.usable(enabledKeyboards: ["com.example.Other.Keyboard", ours],
                                            didLoadOnce: false))
    }

    @Test("**설정에서 뺐으면 꺼진 것이다.** 예전에 띄워 본 적이 있어도 마찬가지")
    func removedFromSettingsWinsOverTheLatch() {
        // 예전 규칙은 `isEnabledInSettings || didLoadOnce` 였다. 그런데 `didLoadOnce` 는
        // 익스텐션이 뜰 때 켜지고 **지우는 코드가 없는 걸쇠**다. 키보드를 한 번이라도
        // 띄워 본 사람은 나중에 설정에서 빼도 앱이 계속 "켜져 있다"고 믿었고,
        // 그 사람은 무대에서 켜라는 안내를 다시는 못 받았다.
        #expect(KeyboardInstallState.usable(enabledKeyboards: ["com.example.Other.Keyboard"],
                                            didLoadOnce: true) == false)
        #expect(KeyboardInstallState.usable(enabledKeyboards: [], didLoadOnce: true) == false)
    }

    @Test("설정 목록을 **못 읽을 때만** 걸쇠로 대신한다")
    func fallsBackToTheLatchOnlyWhenUnreadable() {
        #expect(KeyboardInstallState.usable(enabledKeyboards: nil, didLoadOnce: true))
        // 못 읽고 걸쇠도 없으면 "아직 안 켠 것"으로 본다 - 켜 둔 사람을 한 번 귀찮게 하는
        // 것보다, 못 켠 사람을 영영 놓치는 쪽이 나쁘다.
        #expect(KeyboardInstallState.usable(enabledKeyboards: nil, didLoadOnce: false) == false)
    }

    @Test("실제 읽기 경로도 같은 규칙을 쓴다")
    func liveReadUsesTheSameRule() {
        #expect(KeyboardInstallState.isUsable
                == KeyboardInstallState.usable(
                    enabledKeyboards: UserDefaults.standard.array(forKey: "AppleKeyboards") as? [String],
                    didLoadOnce: KeyboardInstallState.didLoadOnce))
    }
}
