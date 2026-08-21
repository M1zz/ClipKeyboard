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
//  스킨 스위치도 함께 붙잡아 둔다 - 감추는 것(설정)과 되돌리는 것(화면)은 **함께**
//  일어나야 한다. 고를 수 없는데 남의 화면만 달라져 있으면 "왜 내 것만 이렇지"가 된다.
//

import Testing
import Foundation
@testable import ClipKeyboard

@Suite("SnippetsTabStyle: 첫 화면", .serialized)
struct SnippetsTabStyleTests {

    @Test("저장된 값이 없으면 **목록**, 쓰던 사람 쪽에 맞춘다")
    func defaultsToList() {
        let d = UserDefaults.standard
        let saved = d.string(forKey: DefaultsKey.snippetsTabStyle)
        defer { saved.map { d.set($0, forKey: DefaultsKey.snippetsTabStyle) } }

        d.removeObject(forKey: DefaultsKey.snippetsTabStyle)
        #expect(SnippetsTabStyle.current == .list)
    }

    @Test("모르는 값이어도 목록으로 떨어진다. 첫 화면이 비면 안 된다")
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

    @Test("두 화면 다 이름과 설명이 있다. 이름만으로는 뭐가 다른지 모른다")
    func bothStylesAreExplained() {
        for style in SnippetsTabStyle.allCases {
            #expect(!style.localizedName.isEmpty)
            #expect(!style.localizedDescription.isEmpty)
            #expect(!style.symbolName.isEmpty)
        }
    }
}

@Suite("스킨 스위치, 지금은 꺼져 있다")
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

    @Test("되살릴 준비는 되어 있다. rawValue 왕복은 그대로 살아 있다")
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

@Suite("SnippetsOnboardingStep, 처음 쓰는 사람이 지나는 길")
struct SnippetsOnboardingStepTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func step(fresh: Bool = true,
                      welcome: Bool = false,
                      chapters: Bool = false,
                      makeOwn: Bool = false,
                      snoozedHoursAgo: Double? = nil,
                      usable: Bool = false) -> SnippetsOnboardingStep {
        .current(startedFresh: fresh,
                 welcomeDone: welcome,
                 chaptersDone: chapters,
                 makeOwnDone: makeOwn,
                 keyboardUsable: usable,
                 setupSnoozedAt: snoozedHoursAgo.map { now.addingTimeInterval(-$0 * 3600) },
                 now: now)
    }

    @Test("쓰던 사람은 이 길을 걷지 않는다. 업데이트했다고 튜토리얼이 뜨면 안 된다")
    func existingUserSkipsEverything() {
        #expect(step(fresh: false) == .done)
        #expect(step(fresh: false, welcome: true) == .done)
    }

    @Test("처음이면 무엇을 넣어 뒀는지 알리는 것부터")
    func startsWithWelcome() {
        #expect(step() == .welcome)
    }

    @Test("환영을 지나면 **넣어 둔 것을 눌러 보는** 차례. 만들게 하지 않는다")
    func goesToTryingAfterWelcome() {
        #expect(step(welcome: true) == .tryScenarios)
    }

    @Test("셋을 눌러 보고 나면 **직접 하나 만들어 보는** 차례로 이어진다")
    func goesToMakeOwnAfterChapters() {
        // 예전에는 여기서 끝이었다. 키보드를 이미 켜 둔 사람은 콤보를 눌러 본 순간
        // 튜토리얼이 사라지고, 자기 것은 하나도 없는 채로 남았다.
        #expect(step(welcome: true, chapters: true) == .makeOwn)
        #expect(step(welcome: true, chapters: true, usable: true) == .makeOwn)
    }

    @Test("직접 만들기는 **맨 앞이 아니라 셋을 눌러 본 다음**이다")
    func makeOwnNeverComesBeforeTrying() {
        // 처음 온 사람에게 빈 칸부터 내밀면 무엇을 적어야 할지 모른다.
        #expect(step(welcome: true, chapters: false, makeOwn: false) == .tryScenarios)
        #expect(step(welcome: true, chapters: false, makeOwn: true) == .tryScenarios)
    }

    @Test("**키보드 설정은 맨 뒤**, 다 써 본 다음이라야 설정 앱까지 다녀올 이유가 분명하다")
    func keyboardSetupComesLast() {
        #expect(step(welcome: true, chapters: true, makeOwn: true) == .keyboardSetup)
        // 써 볼 것이 남아 있으면 아직 설정으로 보내지 않는다.
        #expect(step(welcome: true, chapters: false) == .tryScenarios)
    }

    @Test("이미 켜 둔 사람에게 켜는 법을 가르치지 않는다")
    func skipsSetupWhenKeyboardAlreadyUsable() {
        #expect(step(welcome: true, chapters: true, makeOwn: true, usable: true) == .done)
        // 밀어 둔 적이 있어도, 켜져 있으면 그것으로 끝이다.
        #expect(step(welcome: true, chapters: true, makeOwn: true,
                     snoozedHoursAgo: 1, usable: true) == .done)
    }

    // MARK: - 켜기 전에는 놓아주지 않는다

    @Test("**닫았다고 끝난 것이 아니다.** 안 켰으면 하루 뒤에 다시 데려온다")
    func setupComesBackUntilActuallyOn() {
        let done = (welcome: true, chapters: true, makeOwn: true)
        // 방금 밀어 뒀으면 오늘은 놔둔다 - 열 때마다 막아서면 앱을 닫는다.
        #expect(step(welcome: done.welcome, chapters: done.chapters, makeOwn: done.makeOwn,
                     snoozedHoursAgo: 1) == .done)
        #expect(step(welcome: done.welcome, chapters: done.chapters, makeOwn: done.makeOwn,
                     snoozedHoursAgo: 23) == .done)
        // 하루가 지나면 다시. 키보드를 켜지 않으면 이 앱은 아무것도 아니라서,
        // 여기서 놓아주는 것은 조용히 잃는 것이다.
        #expect(step(welcome: done.welcome, chapters: done.chapters, makeOwn: done.makeOwn,
                     snoozedHoursAgo: 25) == .keyboardSetup)
        #expect(step(welcome: done.welcome, chapters: done.chapters, makeOwn: done.makeOwn,
                     snoozedHoursAgo: 24 * 30) == .keyboardSetup)
    }

    @Test("켜져 있는지가 **하나뿐인 진실**이다")
    func onlyRealityEndsTheNagging() {
        // 어떤 조합이든, 켜져 있으면 끝. 안 켜져 있으면 (밀어 둔 동안만 빼고) 계속 데려온다.
        for hours in [nil, 1.0, 25.0] as [Double?] {
            #expect(step(welcome: true, chapters: true, makeOwn: true,
                         snoozedHoursAgo: hours, usable: true) == .done)
        }
    }

    @Test("길 전체가 끊기지 않고 이어진다")
    func theWholePathIsConnected() {
        // 어느 걸음에서도 `.done` 으로 빠지지 않는다 - 중간에 끊기면 거기서 튜토리얼이
        // 사라진 것처럼 보인다. 이 시험이 그 구멍을 막는다.
        var seen: [SnippetsOnboardingStep] = []
        var welcome = false, chapters = false, makeOwn = false
        var snoozed: Double?
        for _ in 0..<10 {
            let s = step(welcome: welcome, chapters: chapters, makeOwn: makeOwn,
                         snoozedHoursAgo: snoozed)
            seen.append(s)
            if s == .done { break }
            switch s {
            case .welcome:       welcome = true
            case .tryScenarios:  chapters = true
            case .makeOwn:       makeOwn = true
            case .keyboardSetup: snoozed = 1   // 안내를 보고 오늘은 밀어 뒀다
            case .done:          break
            }
        }
        #expect(seen == [.welcome, .tryScenarios, .makeOwn, .keyboardSetup, .done])
    }

    // MARK: - 오가는 규칙

    /// 툴바의 전환 버튼과 탭바 다시 누르기가 **같은 곳**으로 가야 한다.
    /// 둘이 갈라지면 같은 자리에서 누를 때마다 결과가 달라진다.
    @Test("전환은 두 화면을 오간다. 두 번 누르면 제자리")
    func toggleGoesBothWays() {
        #expect(SnippetsTabStyle.list.toggled == .keyboard)
        #expect(SnippetsTabStyle.keyboard.toggled == .list)
        #expect(SnippetsTabStyle.list.toggled.toggled == .list)
    }
}

// MARK: - 처음 온 사람 · 쓰던 사람

/// ⚠️ 이 갈림길이 어긋나면 가장 나쁜 두 가지가 생긴다.
///    처음 온 사람이 "새로워졌어요"를 보거나, 쓰던 사람이 이름이 바뀐 걸 아무도 안 알려
///    줘서 "내가 뭘 지웠나" 하고 앱을 지운다.
@Suite("LaunchAudience, 앱을 연 사람이 어느 쪽인가")
struct LaunchAudienceTests {

    private let now = "5.0.0"

    @Test("오늘 처음 받은 사람은 온보딩이 맞이한다. 새 단장 안내는 안 뜬다")
    func firstLaunchIsNewcomer() {
        let a = LaunchAudience.resolve(launchCount: 0, startedFresh: true,
                                       lastSeenWhatsNewVersion: nil, currentWhatsNewVersion: now)
        #expect(a == .newcomer)
        #expect(a.showsWhatsNew == false)
        #expect(a.marksWhatsNewSeenSilently, "본 것으로 표시해 둬야 두 번째 실행에 뒤늦게 안 튀어나온다")
    }

    @Test("업데이트한 사람은 새 단장을 한 번 본다")
    func updatedUserSeesWhatsNew() {
        let a = LaunchAudience.resolve(launchCount: 42, startedFresh: false,
                                       lastSeenWhatsNewVersion: "4.4.5", currentWhatsNewVersion: now)
        #expect(a == .returningNeedsWhatsNew)
        #expect(a.showsWhatsNew)
    }

    @Test("한 번 본 사람에게 다시 띄우지 않는다")
    func alreadySeenStaysQuiet() {
        let a = LaunchAudience.resolve(launchCount: 43, startedFresh: false,
                                       lastSeenWhatsNewVersion: now, currentWhatsNewVersion: now)
        #expect(a == .returning)
        #expect(a.showsWhatsNew == false)
    }

    @Test("온보딩을 아직 안 끝낸 사람도 두 번째 실행부터는 처음 온 사람이 아니다")
    func freshButSecondLaunch() {
        // startedFresh 는 온보딩이 끝날 때까지 켜져 있다. 그것만 보면 매번 처음이 된다.
        let a = LaunchAudience.resolve(launchCount: 3, startedFresh: true,
                                       lastSeenWhatsNewVersion: now, currentWhatsNewVersion: now)
        #expect(a == .returning)
    }

    @Test("새 단장 안내의 버전이 앱 버전을 따라간다")
    func whatsNewVersionIsCurrent() {
        // ⚠️ 내용을 바꾸고 이 값을 안 올리면, 업데이트한 사람은 이미 본 것으로 기록돼 있어
        //    **새 안내를 한 번도 못 본다.**
        #expect(WhatsNewContent.version == "5.0.0")
    }
}
