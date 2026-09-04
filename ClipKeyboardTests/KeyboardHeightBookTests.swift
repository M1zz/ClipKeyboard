//
//  KeyboardHeightBookTests.swift
//  ClipKeyboardTests
//
//  우리 키보드가 시스템 키보드와 같은 높이로 서는지 지킨다.
//
//  이 화면은 눈으로만 확인되는 종류라 시험이 특히 중요하다. 잘못된 높이는 크래시가 아니라
//  **위화감**으로 나타나서, 빌드가 초록이어도 아무도 모른 채 배포된다. 실제로 254 라는
//  고정값이 그렇게 오래 남아 있었다.
//
//  여기서 지키는 약속.
//   ① 가로와 세로가 따로 기록된다 (한 칸을 나눠 쓰면 돌아갈 때마다 어긋난다)
//   ② 어림값이 말이 되는 범위에 있고, 가로가 세로보다 낮다
//   ③ 믿을 수 없는 측정은 **안 적는다** (틀린 값이 굳는 것이 어림값보다 나쁘다)
//

import XCTest
import UIKit
@testable import ClipKeyboard

final class KeyboardHeightBookTests: XCTestCase {

    /// 시험이 쓴 값을 남기지 않는다. App Group 은 키보드도 읽는 진짜 저장소다.
    override func tearDown() {
        AppGroup.defaults?.removeObject(forKey: DefaultsKey.systemKeyboardHeights)
        super.tearDown()
    }

    // MARK: - ① 화면키

    func test_가로와_세로는_다른_칸에_적힌다() {
        let portrait = CGSize(width: 390, height: 844)
        let landscape = CGSize(width: 844, height: 390)

        XCTAssertNotEqual(KeyboardHeightBook.key(for: portrait),
                          KeyboardHeightBook.key(for: landscape),
                          "한 칸을 나눠 쓰면 회전할 때마다 서로의 값을 덮어쓴다")
        XCTAssertTrue(KeyboardHeightBook.key(for: portrait).hasSuffix("-P"))
        XCTAssertTrue(KeyboardHeightBook.key(for: landscape).hasSuffix("-L"))
    }

    func test_같은_기기는_같은_이름으로_묶인다() {
        // 짧은 변·긴 변으로 적으므로 기기 부분은 방향과 무관하게 같다.
        let portrait = KeyboardHeightBook.key(for: CGSize(width: 390, height: 844))
        let landscape = KeyboardHeightBook.key(for: CGSize(width: 844, height: 390))
        XCTAssertEqual(portrait.dropLast(2), landscape.dropLast(2))
    }

    // MARK: - ② 어림값

    func test_어림값이_말이_되는_범위에_있다() {
        let devices: [(name: String, size: CGSize)] = [
            ("iPhone SE", CGSize(width: 375, height: 667)),
            ("iPhone 13 mini", CGSize(width: 375, height: 812)),
            ("iPhone 15", CGSize(width: 393, height: 852)),
            ("iPhone 17 Pro", CGSize(width: 402, height: 874)),
            ("iPhone Pro Max", CGSize(width: 430, height: 932))
        ]
        for device in devices {
            let height = KeyboardHeightBook.fallbackHeight(for: device.size)
            // 화면의 4분의 1보다 낮으면 못 쓰고, 절반을 넘으면 화면을 잡아먹는다.
            // 5.0.6 에서 0.36 을 쓰다 짜부라졌다. 어느 기기의 실측 비율(0.37~0.41)보다도 낮았다.
            XCTAssertGreaterThan(height, device.size.height * 0.34, "\(device.name) 너무 낮다")
            XCTAssertLessThan(height, device.size.height * 0.45, "\(device.name) 너무 높다")
        }
    }

    func test_가로가_세로보다_낮다() {
        let portrait = KeyboardHeightBook.fallbackHeight(for: CGSize(width: 393, height: 852))
        let landscape = KeyboardHeightBook.fallbackHeight(for: CGSize(width: 852, height: 393))
        XCTAssertLessThan(landscape, portrait,
                          "가로에서 시스템 키보드는 훨씬 낮다. 세로 높이를 그대로 쓰면 화면을 덮는다")
    }

    func test_아이패드는_따로_잡는다() {
        let pad = KeyboardHeightBook.fallbackHeight(for: CGSize(width: 834, height: 1194))
        // 아이폰 비율(0.39)을 그대로 쓰면 465pt 로 지나치게 높아진다.
        XCTAssertLessThan(pad, 1194 * 0.36)
        XCTAssertGreaterThan(pad, 260)
    }

    func test_큰_화면에서도_울타리를_넘지_않는다() {
        let huge = KeyboardHeightBook.fallbackHeight(for: CGSize(width: 1024, height: 1366))
        XCTAssertLessThanOrEqual(huge, 420, "새 기기가 나와도 말이 되는 범위에 머물러야 한다")
    }

    // MARK: - 잰 값이 어림값을 이긴다

    func test_잰_값이_있으면_그것을_쓴다() {
        let size = CGSize(width: 393, height: 852)
        XCTAssertNil(KeyboardHeightBook.measuredHeight(for: size))

        KeyboardHeightBook.record(height: 301, for: size)

        XCTAssertEqual(KeyboardHeightBook.measuredHeight(for: size), 301)
        XCTAssertEqual(KeyboardHeightBook.totalHeight(for: size), 301,
                       "잰 값이 있는데 어림값을 쓰면 잰 의미가 없다")
    }

    func test_한_방향을_재도_다른_방향은_어림값을_쓴다() {
        let portrait = CGSize(width: 393, height: 852)
        let landscape = CGSize(width: 852, height: 393)
        KeyboardHeightBook.record(height: 301, for: portrait)

        XCTAssertEqual(KeyboardHeightBook.totalHeight(for: portrait), 301)
        XCTAssertNil(KeyboardHeightBook.measuredHeight(for: landscape),
                     "세로를 쟀다고 가로까지 안 것은 아니다")
    }

    // MARK: - ④ 시스템이 우리 뷰 밖에 그리는 몫은 빼고 요구한다

    /// iOS 26 은 지구본·받아쓰기 줄을 **우리 뷰 바깥에** 직접 그린다.
    /// 전체 높이를 그대로 요구하면 딱 그 줄만큼 키보드가 더 높아진다.
    /// 실제로 5.0.6 에서 키보드가 시스템 키보드보다 89pt 높게 섰다.
    func test_격자가_받는_몫은_시스템_키보드의_키_자리와_같다() {
        let size = CGSize(width: 393, height: 852)
        KeyboardHeightBook.record(height: 336, for: size)

        let chrome = KeyboardHeightBook.systemChrome(for: size)
        let metrics = KeyboardHeightBook.ContentMetrics()
        let panel = KeyboardHeightBook.height(for: size, content: metrics)

        XCTAssertEqual(panel - metrics.headerHeight, 336 - chrome, accuracy: 0.01,
                       "머리 줄을 뺀 나머지가 시스템 키보드의 키 자리와 같아야 한다")
    }

    /// 5.0.6 에서 판이 짜부라진 이유. 시스템 키보드와 **똑같이** 세우면, 시스템에는 없는
    /// 카테고리 줄을 우리가 그리는 만큼 격자가 굶는다. 머리 줄은 그 위에 얹어야 한다.
    func test_시스템_키보드보다_머리_줄만큼_높다() {
        let size = CGSize(width: 393, height: 852)
        KeyboardHeightBook.record(height: 336, for: size)

        let metrics = KeyboardHeightBook.ContentMetrics()
        let total = KeyboardHeightBook.height(for: size, content: metrics)
            + KeyboardHeightBook.systemChrome(for: size)

        XCTAssertEqual(total, 336 + metrics.headerHeight, accuracy: 0.01,
                       "시스템에 없는 줄을 그리는 만큼은 더 필요하다")
        XCTAssertGreaterThan(total, KeyboardHeightBook.totalHeight(for: size))
    }

    /// 시스템이 그려 주지 않는 OS 에서는 뺄 것이 없다. 머리 줄은 그래도 얹는다.
    func test_시스템이_안_그리면_전체_위에_머리_줄만_얹는다() {
        guard !KeyboardHeightBook.systemDrawsKeyboardChrome else { return }
        let size = CGSize(width: 393, height: 852)
        KeyboardHeightBook.record(height: 311, for: size)

        let metrics = KeyboardHeightBook.ContentMetrics()
        XCTAssertEqual(KeyboardHeightBook.height(for: size, content: metrics),
                       311 + metrics.headerHeight, accuracy: 0.01)
    }

    func test_세로가_가로보다_시스템_몫이_크다() {
        let portrait = CGSize(width: 393, height: 852)
        let landscape = CGSize(width: 852, height: 393)
        guard KeyboardHeightBook.systemDrawsKeyboardChrome else { return }

        XCTAssertGreaterThan(KeyboardHeightBook.systemChrome(for: portrait),
                             KeyboardHeightBook.systemChrome(for: landscape),
                             "가로에서는 홈 인디케이터 자리가 줄어든다")
    }

    // MARK: - 버튼 여섯은 보인다

    /// 사용자 신고: "키보드가 너무 낮아졌어, 짜부라졌네."
    /// 화면이 작아 시스템 키보드 자체가 낮은 기기에서도 격자가 조각으로 보이면 안 된다.
    func test_작은_화면에서도_버튼_여섯이_들어간다() {
        let small = CGSize(width: 320, height: 568)
        let metrics = KeyboardHeightBook.ContentMetrics()
        let panel = KeyboardHeightBook.height(for: small, content: metrics)

        let grid = panel - metrics.headerHeight - metrics.gridPadding
        let rows = (grid + metrics.rowSpacing) / (metrics.buttonHeight + metrics.rowSpacing)
        XCTAssertGreaterThanOrEqual(rows, 3,
                                    "두 칸씩 세 줄이면 여섯이다. 그보다 낮으면 목록이 아니라 조각이다")
    }

    /// 키를 크게 쓰는 사람의 격자가 그만큼 잘리면 안 된다. 바닥은 **설정을 따라** 움직인다.
    func test_키를_크게_쓰면_바닥도_함께_올라간다() {
        var small = KeyboardHeightBook.ContentMetrics()
        small.buttonHeight = 44
        var large = KeyboardHeightBook.ContentMetrics()
        large.buttonHeight = 72

        XCTAssertGreaterThan(large.floorHeight, small.floorHeight)
    }

    /// 한 칸씩 쓰면 여섯을 세로로 쌓아야 하지만, 여섯 줄을 그대로 주면 화면 절반을 넘는다.
    func test_한_칸_배치에서도_줄_수에_울타리가_있다() {
        var single = KeyboardHeightBook.ContentMetrics()
        single.columns = 1
        // 네 줄까지만 센다: 38 + 24 + (4 × 44 + 3 × 10) = 268
        XCTAssertEqual(single.floorHeight, 268, accuracy: 0.01)
    }

    /// 세 칸이면 두 줄에 여섯이 다 선다. 굳이 더 높일 이유가 없다.
    func test_칸이_많으면_바닥이_낮아진다() {
        var wide = KeyboardHeightBook.ContentMetrics()
        wide.columns = 3
        XCTAssertLessThan(wide.floorHeight, KeyboardHeightBook.ContentMetrics().floorHeight)
    }

    // MARK: - 울타리

    /// 울타리: 상수가 빗나가도 **쓸 수 없는 키보드**가 되지는 않는다.
    func test_아주_낮은_화면에서도_판이_최소치_아래로_내려가지_않는다() {
        let tiny = CGSize(width: 320, height: 480)
        XCTAssertGreaterThanOrEqual(KeyboardHeightBook.height(for: tiny),
                                    KeyboardHeightBook.minimumContentHeight)
    }

    /// 키보드가 화면을 덮으면 무엇에 입력하고 있는지가 안 보인다.
    /// 특히 가로에서는 바닥(버튼 여섯)을 그대로 쓰면 본문이 사라진다.
    func test_가로에서_바닥이_화면을_덮지_않는다() {
        let landscape = CGSize(width: 852, height: 393)
        let panel = KeyboardHeightBook.height(for: landscape)
        let total = panel + KeyboardHeightBook.systemChrome(for: landscape)

        XCTAssertLessThan(total, 393 * 0.65, "가로에서 키보드가 화면의 3분의 2를 넘으면 못 쓴다")
    }

    func test_어떤_설정으로도_울타리를_넘지_않는다() {
        let size = CGSize(width: 393, height: 852)
        var greedy = KeyboardHeightBook.ContentMetrics()
        greedy.columns = 1
        greedy.buttonHeight = 100
        greedy.minimumVisibleButtons = 12

        XCTAssertLessThanOrEqual(KeyboardHeightBook.height(for: size, content: greedy),
                                 KeyboardHeightBook.maximumContentHeight(for: size))
    }

    // MARK: - ③ 믿을 수 없는 측정은 안 적는다

    func test_하드웨어_키보드의_단축바는_무시한다() {
        let screen = CGSize(width: 393, height: 852)
        // 하드웨어 키보드가 붙으면 화면에는 단축 바만 뜬다(55pt 안팎).
        KeyboardHeightBook.consider(frame: CGRect(x: 0, y: 797, width: 393, height: 55),
                                    screen: screen)

        XCTAssertNil(KeyboardHeightBook.measuredHeight(for: screen),
                     "이 값을 적으면 키보드가 손가락 두 마디만 해진다")
    }

    func test_아이패드의_떠있는_키보드는_무시한다() {
        let screen = CGSize(width: 834, height: 1194)
        // floating 키보드는 화면 너비를 다 쓰지 않는다.
        KeyboardHeightBook.consider(frame: CGRect(x: 40, y: 800, width: 320, height: 280),
                                    screen: screen)

        XCTAssertNil(KeyboardHeightBook.measuredHeight(for: screen))
    }

    func test_화면을_거의_덮는_값도_무시한다() {
        let screen = CGSize(width: 393, height: 852)
        KeyboardHeightBook.consider(frame: CGRect(x: 0, y: 0, width: 393, height: 700),
                                    screen: screen)

        XCTAssertNil(KeyboardHeightBook.measuredHeight(for: screen),
                     "화면 대부분을 덮는 값은 키보드 높이가 아니다")
    }

    func test_그럴듯한_측정은_적는다() {
        let screen = CGSize(width: 393, height: 852)
        KeyboardHeightBook.consider(frame: CGRect(x: 0, y: 551, width: 393, height: 301),
                                    screen: screen)

        XCTAssertEqual(KeyboardHeightBook.measuredHeight(for: screen), 301)
    }
}
