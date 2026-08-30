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

    /// 익스텐션이 쓸 최종 높이. 잰 값이 있으면 그것, 없으면 어림값.
    static func height(for size: CGSize) -> CGFloat {
        measuredHeight(for: size) ?? fallbackHeight(for: size)
    }

    /// 잰 값이 없을 때의 어림. **정답이 아니라 첫 인상용 임시값**이다.
    ///
    /// 애플이 키보드 높이를 공개하지 않으므로 화면 높이에 대한 비율로 어림한다.
    /// 비율은 세로에서 0.36, 가로에서 0.5 쯤이 실제 값에 가깝게 떨어진다
    /// (세로 844pt 화면이면 304pt, 실제와 몇 pt 차이). 아이패드는 화면이 커서
    /// 같은 비율을 쓰면 지나치게 높아지므로 따로 잡는다.
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
            : clamp(height * 0.36, low: 230, high: 350)
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
