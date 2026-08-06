//
//  PastePermissionGuidanceTests.swift
//  ClipKeyboardTests
//
//  **설치 첫날에는 클립보드를 건드리지 않는다**는 약속을 고정한다.
//
//  iOS는 앱이 클립보드를 읽는 순간 "붙여넣기 허용?" 팝업을 띄운다. 설치 당일 그게 뜨면
//  신규 사용자가 이 앱에서 보는 첫 다이얼로그가 권한 요청이 된다 — 무엇을 하는 앱인지
//  알기도 전에 거절할지를 묻는 셈이다. 며칠 써 본 뒤라야 허용할 이유가 생긴다.
//
//  ⚠️ 이 계약이 깨지는 방식은 조용하다. 팝업은 시뮬레이터·테스트에서 안 보이고
//     실기기 신규 설치에서만 튀어나온다. 그래서 날짜 경계를 여기서 붙잡아 둔다.
//

import Testing
import Foundation
@testable import ClipKeyboard

@Suite("PastePermissionGuidance — 붙여넣기 팝업 시점", .serialized)
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

    @Test("설치 당일에는 클립보드를 읽지 않는다 — 팝업이 앱의 첫인상이 되면 안 된다")
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

    @Test("우리 안내는 며칠 **그리고** 몇 번 열어 본 다음에만 — 둘 다 필요하다")
    func guidanceNeedsBothDaysAndLaunches() {
        let d = UserDefaults.standard
        let savedCount = d.integer(forKey: DefaultsKey.appLaunchCount)
        defer { d.set(savedCount, forKey: DefaultsKey.appLaunchCount) }

        // 날짜는 찼지만 아직 몇 번 안 열어 봤다 → 말 걸지 않는다.
        withInstallDate(daysAgo: 10) {
            d.set(1, forKey: DefaultsKey.appLaunchCount)
            #expect(PastePermissionGuidance.isReady == false)
            d.set(3, forKey: DefaultsKey.appLaunchCount)
            #expect(PastePermissionGuidance.isReady)
        }

        // 많이 열어 봤어도 날짜가 안 찼으면 말 걸지 않는다.
        withInstallDate(daysAgo: 0) {
            d.set(99, forKey: DefaultsKey.appLaunchCount)
            #expect(PastePermissionGuidance.isReady == false)
        }
    }

    // ⚠️ "설치일 기록이 없을 때" 는 여기서 검사하지 않는다.
    //    시뮬레이터의 cfprefsd 가 지운 키를 곧바로 되살려 놔서(외부에서 한 번 써 넣은 값이
    //    앱 프로세스의 removeObject 뒤에도 다시 나타난다) **삭제 상태를 만들 수가 없다.**
    //    억지로 통과시키려고 구현을 비틀면 테스트가 코드를 망가뜨리는 쪽이 된다.
    //    (그 경로의 규칙 자체는 `PastePermissionGuidance.installDate` 주석에 남겨 두었다 —
    //     모르면 지금을 설치일로 찍고, 즉 **기다리는 쪽**으로 붙는다)

}

@Suite("KeyboardInstallState — 키보드를 쓸 수 있는 상태인가")
struct KeyboardInstallStateTests {

    @Test("익스텐션 번들 ID는 앱 번들 아래에 있어야 한다 — 틀리면 영영 '못 쓴다'가 된다")
    func extensionBundleIDIsCorrect() {
        #expect(KeyboardInstallState.extensionBundleID.hasPrefix("com.Ysoup.TokenMemo."))
        #expect(KeyboardInstallState.extensionBundleID == "com.Ysoup.TokenMemo.ClipKeyboardExtension")
    }

    @Test("떠 본 적 있으면 설정 확인과 무관하게 쓸 수 있다")
    func didLoadOnceIsEnough() {
        guard let group = UserDefaults(suiteName: AppGroup.identifier) else { return }
        let saved = group.object(forKey: DefaultsKey.keyboardExtensionDidLoad) as? Bool
        defer {
            if let saved { group.set(saved, forKey: DefaultsKey.keyboardExtensionDidLoad) }
            else { group.removeObject(forKey: DefaultsKey.keyboardExtensionDidLoad) }
        }

        group.set(true, forKey: DefaultsKey.keyboardExtensionDidLoad)
        #expect(KeyboardInstallState.didLoadOnce)
        #expect(KeyboardInstallState.isUsable)

        // 표식이 없으면 이제는 **설정 목록**이 판단한다(예전엔 여기서 무조건 '못 쓴다'였다).
        group.set(false, forKey: DefaultsKey.keyboardExtensionDidLoad)
        #expect(KeyboardInstallState.isUsable == KeyboardInstallState.isEnabledInSettings)
    }
}
