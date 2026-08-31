//
//  KeyboardHeightBook.swift
//  ClipKeyboard
//
//  시스템 키보드가 몇 pt 인지 적어 두는 장부. **앱과 키보드 익스텐션 양쪽 타겟**에 있다.
//
//  왜 필요한가: 익스텐션은 시스템 키보드 높이를 물어볼 방법이 없다. 그런 API 가 없다.
//  그래서 우리 키보드는 오래도록 254 라는 고정값을 썼고, 그 숫자가 기기마다 다른 진짜
//  높이와 어긋난 만큼 사용자에게 위화감으로 보였다. 게다가 iOS 는 입력 뷰를 자기 기본
//  높이로 한 번 세운 뒤 우리 값으로 끌어당기며 그 변화를 **애니메이션한다.** 키보드가
//  뜰 때 높이가 팍 튀는 것처럼 보이던 것이 이것이다.
//
//  방법은 하나뿐이다. **메인 앱은 시스템 키보드를 띄울 수 있다.** 앱에서 키보드가 올라올 때
//  그 높이를 재서 App Group 에 적어 두면, 익스텐션이 그대로 읽어 쓴다. 예측 입력 줄을 켰는지
//  껐는지 같은 그 사람의 설정까지 저절로 반영된다.
//
//  ⚠️ 앱을 한 번도 안 연 사람에게는 잰 값이 없다. 그때는 화면 비율로 어림한다
//     (`fallbackHeight`). 어림이라 몇 pt 어긋날 수 있고, 앱을 한 번 쓰면 정확해진다.
//
//  ⚠️ 익스텐션 타겟에도 컴파일된다. 메모리 상한(약 60MB) 안에서 도니 무거운 의존을 들이지 말 것.
//     여기 있는 건 UserDefaults 읽기·쓰기와 산수뿐이다.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum KeyboardHeightBook {

    // MARK: - 장부

    /// 잰 값들. `[화면키: 높이]` 형태로 App Group 에 있다.
    ///
    /// 화면마다 따로 적는 이유: 같은 사람이 아이폰과 아이패드를 함께 쓰고, 같은 기기라도
    /// 가로와 세로의 키보드 높이가 완전히 다르다. 하나로 뭉치면 방금 잰 값이 다른 상황의
    /// 값을 덮어써서, 돌아갈 때마다 어긋난다.
    private static var book: [String: Double] {
        get { (AppGroup.defaults?.dictionary(forKey: DefaultsKey.systemKeyboardHeights) as? [String: Double]) ?? [:] }
        set { AppGroup.defaults?.set(newValue, forKey: DefaultsKey.systemKeyboardHeights) }
    }

    /// 화면 하나를 가리키는 열쇠. 크기와 방향이 함께 들어간다.
    ///
    /// 짧은 변과 긴 변으로 적는 건 같은 기기를 한 이름으로 묶기 위해서다. 가로/세로는
    /// 뒤에 따로 붙인다. 그래야 "이 기기의 가로"와 "이 기기의 세로"가 각각 남는다.
    static func key(for size: CGSize) -> String {
        let short = Int(min(size.width, size.height).rounded())
        let long = Int(max(size.width, size.height).rounded())
        let orientation = size.width > size.height ? "L" : "P"
        return "\(short)x\(long)-\(orientation)"
    }

    // MARK: - 읽기

    /// 앱이 실제로 잰 값. 잰 적이 없으면 nil.
    static func measuredHeight(for size: CGSize) -> CGFloat? {
        guard let value = book[key(for: size)], value > 0 else { return nil }
        return CGFloat(value)
    }

    /// 시스템 키보드가 화면에서 차지하는 **전체** 높이. 잰 값이 있으면 그것, 없으면 어림값.
    static func totalHeight(for size: CGSize) -> CGFloat {
        measuredHeight(for: size) ?? fallbackHeight(for: size)
    }

    /// 익스텐션이 입력 뷰에 걸 높이. **우리가 그리는 판만큼**이다.
    ///
    /// ⚠️ 전체 높이가 아니다. iOS 26 부터 시스템이 우리 뷰 **바깥에** 지구본·받아쓰기 줄을
    ///    직접 그리기 때문에, 전체 높이를 그대로 요구하면 그 줄만큼 키보드가 더 높아진다
    ///    (`systemChrome` 머리말 참고).
    ///
    /// ## 왜 시스템 키보드와 "똑같이" 세우지 않는가
    ///
    /// 5.0.6 에서 한 번 그렇게 세웠다가 **판이 짜부라졌다.** 계산은 맞았는데 전제가 틀렸다.
    /// 시스템 키보드는 그 높이를 통째로 키에 쓴다. 우리 판은 같은 높이 안에 카테고리 줄을
    /// 먼저 얹고 남은 자리에 키를 깐다. 같은 값을 받으면 우리 격자만 한 줄 넘게 굶는다.
    ///
    /// 그래서 재는 값은 **격자가 받을 몫**으로 보고, 우리에게만 있는 머리 줄을 그 위에 얹는다.
    /// 총 높이는 시스템 키보드보다 머리 줄만큼 높아진다. 그게 맞다. 시스템 키보드에 없는
    /// 것을 우리가 그리고 있으니 그만큼 자리가 더 필요하다.
    ///
    /// - Parameter content: 우리 판이 그리는 것들의 치수. 사용자가 설정에서 키 높이와
    ///   칸 수를 바꾸므로 값이 고정이 아니다.
    static func height(for size: CGSize, content: ContentMetrics = ContentMetrics()) -> CGFloat {
        // ① 시스템 키보드가 키에 쓰는 만큼은 격자에 준다. 머리 줄은 그 위에 얹는다.
        let keyArea = totalHeight(for: size) - systemChrome(for: size)
        let matched = keyArea + content.headerHeight

        // ② 그래도 버튼 여섯은 보인다. 화면이 작아 ① 이 모자란 기기를 위한 바닥.
        let floor = max(content.floorHeight, minimumContentHeight)

        // ③ 그러나 화면을 통째로 먹지는 않는다. 가로에서 ② 를 그대로 쓰면 본문이 사라진다.
        let ceiling = maximumContentHeight(for: size)

        return min(max(matched, floor), ceiling)
    }

    /// 우리 판이 이보다 낮아지지는 않는다. 카테고리 줄 + 키 한 줄이 겨우 들어가는 높이.
    static let minimumContentHeight: CGFloat = 150

    /// 우리 판이 이보다 높아지지는 않는다.
    ///
    /// 키보드가 화면을 덮으면 무엇에 입력하고 있는지가 안 보인다. 세로에서는 화면의 55%,
    /// 가로에서는 62% 까지만 쓴다(가로는 화면이 낮아 같은 비율로는 키가 안 들어간다).
    static func maximumContentHeight(for size: CGSize) -> CGFloat {
        let isLandscape = size.width > size.height
        let share: CGFloat = isLandscape ? 0.62 : 0.55
        let room = size.height * share - systemChrome(for: size)
        return max(room, minimumContentHeight)
    }

    // MARK: - 우리 판이 그리는 것들의 치수

    /// 판 높이를 정하려면 **우리가 무엇을 그리는지** 알아야 한다.
    ///
    /// 키 높이와 칸 수는 설정에서 사용자가 바꾼다(App Group 공유). 값을 여기 박아 두면
    /// 키를 크게 쓰는 사람의 격자가 그만큼 잘린다. 그래서 인자로 받는다.
    ///
    /// ⚠️ 여기 숫자들은 `KeyboardView` 의 실제 레이아웃에서 온 것이다. 저쪽을 고치면
    ///    여기도 고쳐야 한다. 어긋나면 판이 다시 짜부라지거나 빈 자리가 남는다.
    struct ContentMetrics {
        /// 카테고리 줄. `categoryTabRow` 는 28pt 버튼에 위아래 5pt 여백이다.
        var headerHeight: CGFloat = 38
        /// 격자 위아래 여백. 키를 누를 때 번지는 물결이 잘리지 않을 자리다(`gridRippleReach` × 2).
        var gridPadding: CGFloat = 24
        /// 격자 줄 사이.
        var rowSpacing: CGFloat = 10
        /// 키 하나의 높이. 설정 > 키보드 모양에서 바꾼다.
        var buttonHeight: CGFloat = 44
        /// 한 줄에 서는 키 개수. 설정에서 1~5.
        var columns: Int = 2
        /// 적어도 이만큼은 보인다. 셋만 보이면 목록이 아니라 조각으로 읽힌다.
        var minimumVisibleButtons: Int = 6

        /// 버튼 `minimumVisibleButtons` 개가 실제로 보이려면 판이 얼마나 높아야 하는가.
        ///
        /// ⚠️ 줄 수에 울타리를 둔다. 한 칸씩 쓰는 사람에게 여섯 줄을 그대로 주면
        ///    키보드가 화면 절반을 넘는다. 넷까지만 센다(가로에서는 위 ③ 이 또 깎는다).
        var floorHeight: CGFloat {
            let perRow = max(1, min(5, columns))
            let needed = Int(ceil(Double(minimumVisibleButtons) / Double(perRow)))
            let rows = CGFloat(max(1, min(4, needed)))
            let grid = rows * buttonHeight + (rows - 1) * rowSpacing
            return headerHeight + gridPadding + grid
        }
    }

    // MARK: - 시스템이 우리 뷰 밖에 그리는 몫

    /// iOS 26 부터 시스템이 **우리 뷰 바깥에** 그리는 높이.
    ///
    /// 무엇인가: 키보드 판 위쪽 여백과, 아래쪽 지구본·받아쓰기 줄(그리고 그 아래 홈 인디케이터
    /// 자리)이다. 예전에는 지구본을 키보드가 직접 그렸는데, iOS 26 은 시스템이 그린다.
    /// `needsInputModeSwitchKey` 가 false 로 오는 것이 그 증거다.
    ///
    /// ⚠️ **이 몫은 우리 뷰에 포함되지 않는다.** `safeAreaInsets` 로도 안 온다(전부 0 이다).
    ///    그래서 전체 높이를 그대로 요구하면 딱 이만큼 키보드가 더 높아진다.
    ///
    /// 실측 (iPhone 17 Pro · iOS 26.0.1 · 세로, 사파리 주소창 위치로 잼):
    ///
    /// | 우리 뷰에 건 높이 | 키보드 전체 | 차이 |
    /// | --- | --- | --- |
    /// | 314.6 (예전 코드) | 399.7 | 85.1 |
    /// | 268 (제약 없이 iOS 기본) | 353.0 | 85.0 |
    /// | 시스템 키보드 | 311.0 | - |
    ///
    /// 85pt 의 내역은 위 여백 13 + 지구본·받아쓰기 줄 40 + 홈 인디케이터 34 이다.
    /// 재는 방법은 `docs/postmortem/KEYBOARD_SYSTEM_CHROME_5_0_6.md` 에 적어 두었다.
    ///
    /// ⚠️ 가로·아이패드 값은 같은 방법으로 재서 넣은 것이다. 새 값이 필요하면 그 문서를 따를 것.
    static func systemChrome(for size: CGSize) -> CGFloat {
        guard systemDrawsKeyboardChrome else { return 0 }
        let isLandscape = size.width > size.height
        let isPad = min(size.width, size.height) >= 600
        if isPad { return isLandscape ? padLandscapeChrome : padPortraitChrome }
        return isLandscape ? phoneLandscapeChrome : phonePortraitChrome
    }

    /// 시스템이 지구본·받아쓰기 줄을 직접 그리는 OS 인가.
    static var systemDrawsKeyboardChrome: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    static let phonePortraitChrome: CGFloat = 85
    /// 가로에서는 홈 인디케이터 자리가 21pt 로 줄어든다(세로 34pt).
    static let phoneLandscapeChrome: CGFloat = 72
    static let padPortraitChrome: CGFloat = 85
    static let padLandscapeChrome: CGFloat = 85

    /// 잰 값이 없을 때의 어림. **정답이 아니라 첫 인상용 임시값**이다.
    ///
    /// 애플이 키보드 높이를 공개하지 않으므로 화면 높이에 대한 비율로 어림한다.
    /// 비율은 실제로 올라오는 키보드(예측 입력 줄 포함)를 재서 맞췄다.
    ///
    /// | 기기 | 화면 | 키보드 | 비율 |
    /// | --- | --- | --- | --- |
    /// | iPhone SE 3 | 667 | 260 | 0.390 |
    /// | iPhone 13 mini | 812 | 335 | 0.413 |
    /// | iPhone 15 · 16 | 852 | 336 | 0.394 |
    /// | iPhone Pro Max | 932 | 346 | 0.371 |
    ///
    /// ⚠️ 예전에는 0.36 이었다. 위 표의 어느 기기보다도 낮아서, 앱을 아직 안 연 사람은
    ///    처음부터 짜부라진 키보드를 봤다. 0.39 로 올린다.
    /// 가로는 0.5, 아이패드는 화면이 커서 같은 비율을 쓰면 지나치게 높아지므로 따로 잡는다.
    ///
    /// 위아래 울타리를 두는 건 새 기기가 나와 비율이 어긋나도 말이 되는 범위에
    /// 머물게 하려는 것이다. 어림이 빗나가도 **쓸 수 없는 키보드**가 되지는 않는다.
    static func fallbackHeight(for size: CGSize) -> CGFloat {
        let height = max(size.width, size.height) > 0 ? size.height : 844
        let isLandscape = size.width > size.height
        // 짧은 변이 이보다 크면 아이패드로 본다(아이폰 최대가 440 언저리다).
        let isPad = min(size.width, size.height) >= 600

        if isPad {
            return clamp(height * 0.30, low: 260, high: 420)
        }
        return isLandscape
            ? clamp(height * 0.50, low: 150, high: 240)
            : clamp(height * 0.39, low: 250, high: 380)
    }

    private static func clamp(_ value: CGFloat, low: CGFloat, high: CGFloat) -> CGFloat {
        min(max(value, low), high)
    }

    // MARK: - 적기 (앱 전용)

    /// 잰 값을 장부에 적는다. 값이 그대로면 쓰지 않는다.
    ///
    /// 같은 값을 다시 쓰지 않는 이유: App Group UserDefaults 는 키보드도 읽는 파일이라,
    /// 의미 없는 쓰기가 잦으면 키보드가 뜨는 순간과 겹칠 수 있다.
    static func record(height: CGFloat, for size: CGSize) {
        let key = key(for: size)
        let value = Double(height.rounded())
        var current = book
        guard current[key] != value else { return }
        current[key] = value
        book = current
        print("📐 [KeyboardHeightBook] \(key) 시스템 키보드 높이 \(value) 기록")
    }

    #if canImport(UIKit) && !os(macOS)

    /// 시스템 키보드가 올라올 때마다 높이를 재서 적는다. **앱에서 1회 호출.**
    ///
    /// 익스텐션에서 부르면 안 된다. 익스텐션이 보는 키보드는 자기 자신이라
    /// 자기 높이를 정답으로 적어 버리고, 그 값이 다시 자기 입력이 되는 고리가 생긴다.
    static func startWatching() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            consider(frame: frame)
        }
    }

    private static var observer: NSObjectProtocol?

    /// 잰 값을 믿을지 가린다. **믿을 수 없는 값을 적는 것이 안 적는 것보다 나쁘다.**
    /// 어긋난 값이 장부에 한 번 들어가면 어림값으로도 못 돌아가고 그대로 굳는다.
    static func consider(frame: CGRect, screen: CGSize? = nil) {
        let screenSize = screen ?? UIScreen.main.bounds.size
        guard screenSize.height > 0 else { return }

        // ① 하드웨어 키보드가 붙어 있으면 화면에는 단축 바만 뜬다. 그 높이를 적으면
        //    키보드가 손가락 두 마디만 해진다.
        // ② 아이패드의 떠 있는 키보드(floating)는 화면 너비를 다 안 쓴다.
        //    폭이 화면과 크게 다르면 그 상황으로 본다.
        let coversWidth = abs(frame.width - screenSize.width) < 1
        let ratio = frame.height / screenSize.height
        guard coversWidth, ratio > 0.2, ratio < 0.6 else {
            print("📐 [KeyboardHeightBook] 믿을 수 없는 프레임 무시: \(frame) (화면 \(screenSize))")
            return
        }

        record(height: frame.height, for: screenSize)
    }

    #endif
}
