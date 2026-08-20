//
//  TimeSavedModel.swift
//  ClipKeyboard
//
//  "얼마나 아꼈나"를 **설명할 수 있는 형태로** 계산한다.
//
//  ⚠️ 예전 식은 `글자수 / 4 - 1` 한 줄이었다. 치는 시간만 센 것이다.
//     그런데 이 앱이 실제로 아껴 주는 시간의 대부분은 **치는 시간이 아니다.**
//     계좌번호를 넣을 때 드는 비용은 스물몇 자를 치는 6초가 아니라,
//     은행 앱을 열고 → 계좌를 찾고 → 복사하고 → 원래 앱으로 돌아오는 그 사이다.
//     예전 식은 **이 앱이 가장 쓸모 있는 경우를 가장 적게 세고 있었다.**
//
//  그래서 한 번의 사용을 세 조각으로 나눈다.
//
//      ① 찾아오는 시간(retrieval)  - 다른 곳에서 가져와야 했던 값인가
//      ② 치는 시간(typing)         - 손으로 옮겨 적었다면 걸렸을 시간
//      ③ 확인하는 시간(verification) - 틀리면 큰일 나는 숫자를 되짚어 보는 시간
//      빼기: 이 앱을 쓰는 값(tap)   - 키보드를 열고 키를 찾아 누르는 값
//
//  ⚠️ **숫자는 전부 가정이고, 그 가정을 화면에 적는다.** 근거 없는 숫자를 크게
//     띄우는 것은 자랑이 아니라 거짓말이다. 각 상수 옆에 왜 그 값인지를 남기고,
//     사용 기록 화면은 `Breakdown` 을 받아 세 조각을 그대로 보여준다.
//     사용자가 "이건 좀 후하네" 라고 판단할 수 있어야 그 숫자를 믿는다.
//
//  ⚠️ 보수적으로 잡는다. 어느 쪽으로 틀릴지 골라야 한다면 **적게 세는 쪽**이다.
//     과장한 숫자는 한 번 들키면 나머지 화면까지 다 못 믿게 된다.
//

import Foundation

enum TimeSavedModel {

    // MARK: - 가정

    /// 사람이 화면 키보드로 **글**을 옮겨 적는 속도(자/초).
    ///
    /// 근거: 모바일 화면 자판의 일반적인 입력 속도는 분당 30~40단어 언저리이고,
    /// 한글은 자모 조합 때문에 이보다 느리다. 한·영 섞어 쓰는 것을 감안해
    /// **초당 4자**로 잡는다(예전 식과 같은 값 - 이 부분은 바꿀 이유가 없었다).
    static let proseCharsPerSecond: Double = 4.0

    /// 숫자·기호가 대부분인 값을 옮겨 적는 속도(자/초).
    ///
    /// 근거: 숫자는 자판을 한 번 바꿔야 하고, 외워서 이어 치지 못해 한 자씩 확인하며
    /// 누른다. 글보다 **확실히 느리다.** 초당 2.5자로 잡는다.
    static let digitCharsPerSecond: Double = 2.5

    /// 이 앱을 쓰는 데 드는 값(초). 절약분에서 **뺀다.**
    ///
    /// 근거: 키보드를 올리고 원하는 키를 눈으로 찾아 누르기까지. 공짜가 아니다.
    /// 이걸 빼지 않으면 한 글자짜리 문구도 시간을 벌어 주는 것이 되어 버린다.
    static let tapCostSeconds: Double = 1.0

    /// 이 길이 아래는 아예 세지 않는다(자).
    ///
    /// 근거: "네", "ok" 같은 것은 앱을 여는 편이 오히려 느리다.
    /// 아껴 준 것이 없으면 0이라고 말해야 한다.
    static let minimumCharacters = 4

    // MARK: - 찾아오는 시간

    /// 이 값을 원래 **어디서 가져와야 했는가**에 따른 시간(초).
    ///
    /// 이것이 이 모델의 핵심이고, 예전 식에 통째로 빠져 있던 부분이다.
    /// 컨텍스트 스위칭 비용 - 쓰던 앱을 벗어났다가 돌아오는 값이다.
    ///
    /// ⚠️ 근거를 밝힌다. 앱을 전환해 무언가를 찾아 돌아오는 데 드는 시간을
    ///    실측한 공개 수치는 제각각이라(짧게는 몇 초, 길게는 수십 초) 여기서는
    ///    **가장 짧은 쪽**을 택했다. 아래 값은 "은행 앱을 열어 계좌를 찾는 데
    ///    20초"처럼 누구나 머릿속으로 검산할 수 있는 크기로만 잡았다.
    ///
    /// ⚠️ 외워서 바로 치는 것에는 0을 준다. 이름·인사말은 찾아올 곳이 없다.
    enum Retrieval {
        /// 머릿속에 있다 - 찾아올 곳이 없다.
        static let fromMemory: Double = 0
        /// 이 기기 어딘가 - 다른 앱을 열어 눈으로 찾는다(주소록·메모 등).
        static let fromAnotherApp: Double = 8
        /// 잠긴 곳 - 은행·카드 앱을 열고 인증을 거쳐 찾는다.
        static let fromSecuredApp: Double = 20
        /// 기기 밖 - 지갑·서랍의 실물을 꺼내 본다(여권·보험증).
        static let fromPhysical: Double = 30
    }

    /// 값의 종류별로 "원래 어디서 가져와야 했나".
    ///
    /// ⚠️ 이 앱이 이미 하고 있는 분류(`ClipboardItemType`)를 그대로 쓴다.
    ///    새로 수집하는 것이 하나도 없다는 뜻이다 - 이 규칙은 사용 기록 화면 전체가
    ///    지키고 있는 것이라 여기서도 깬다면 그 화면이 통째로 거짓이 된다.
    static func retrievalSeconds(for type: ClipboardItemType?) -> Double {
        guard let type else { return Retrieval.fromMemory }
        switch type {
        // 외워서 친다.
        case .email, .phone, .name, .birthDate, .text, .image:
            return Retrieval.fromMemory

        // 다른 앱을 열어 찾는다.
        case .address, .url, .postalCode, .ipAddress, .vehiclePlate,
             .membershipNumber, .trackingNumber, .confirmationCode,
             .employeeID, .paypalLink:
            return Retrieval.fromAnotherApp

        // 잠긴 앱을 열고 인증까지 거친다.
        case .creditCard, .bankAccount, .iban, .swift, .taxID, .vat,
             .cryptoWallet, .declarationNumber:
            return Retrieval.fromSecuredApp

        // 실물을 꺼내 본다.
        case .passportNumber, .insuranceNumber, .medicalRecord:
            return Retrieval.fromPhysical
        }
    }

    /// 틀리면 되짚어 봐야 하는 값인가 - 확인하는 시간(초).
    ///
    /// 근거: 계좌번호 한 자리가 틀리면 돈이 남에게 간다. 그런 값은 넣고 나서
    /// 반드시 한 번 다시 읽는다. 글에는 이 값이 붙지 않는다.
    static func verificationSeconds(for type: ClipboardItemType?) -> Double {
        guard let type else { return 0 }
        switch type {
        case .creditCard, .bankAccount, .iban, .swift, .cryptoWallet,
             .passportNumber, .taxID, .vat, .declarationNumber,
             .insuranceNumber, .medicalRecord:
            return 6
        default:
            return 0
        }
    }

    // MARK: - 한 번의 사용

    /// 한 번 쓸 때 아낀 시간의 **내역**. 화면은 이걸 받아 그대로 펼쳐 보여준다.
    struct Breakdown: Equatable {
        /// 다른 곳에서 찾아오지 않아도 된 시간.
        let retrieval: Double
        /// 손으로 옮겨 적지 않아도 된 시간.
        let typing: Double
        /// 되짚어 읽지 않아도 된 시간.
        let verification: Double
        /// 이 앱을 쓰는 데 든 값(뺀다).
        let tapCost: Double

        /// 실제로 아낀 시간(초). 음수는 0으로 - 손해 본 것을 이득으로 적지 않는다.
        var total: Double { max(0, retrieval + typing + verification - tapCost) }

        static let zero = Breakdown(retrieval: 0, typing: 0, verification: 0, tapCost: 0)

        static func + (lhs: Breakdown, rhs: Breakdown) -> Breakdown {
            Breakdown(retrieval: lhs.retrieval + rhs.retrieval,
                      typing: lhs.typing + rhs.typing,
                      verification: lhs.verification + rhs.verification,
                      tapCost: lhs.tapCost + rhs.tapCost)
        }
    }

    /// 글자 중 숫자·기호가 차지하는 비율. 치는 속도를 고르는 데 쓴다.
    static func digitRatio(of value: String) -> Double {
        let counted = value.filter { !$0.isWhitespace }
        guard !counted.isEmpty else { return 0 }
        let digits = counted.filter { $0.isNumber || $0.isPunctuation || $0.isSymbol }
        return Double(digits.count) / Double(counted.count)
    }

    /// 한 번 썼을 때의 내역.
    ///
    /// - Parameters:
    ///   - value: 실제로 들어간 글. 길이와 숫자 비율을 여기서 본다.
    ///   - type: 이 앱이 분류해 둔 값의 종류. 없으면 "외워서 치는 글"로 본다.
    static func breakdown(value: String, type: ClipboardItemType?) -> Breakdown {
        let length = value.count
        guard length >= minimumCharacters else { return .zero }

        // 숫자가 섞인 만큼 치는 속도를 낮춘다(글 4자/초 ↔ 숫자 2.5자/초 사이).
        let ratio = digitRatio(of: value)
        let cps = proseCharsPerSecond + (digitCharsPerSecond - proseCharsPerSecond) * ratio

        return Breakdown(retrieval: retrievalSeconds(for: type),
                         typing: Double(length) / cps,
                         verification: verificationSeconds(for: type),
                         tapCost: tapCostSeconds)
    }

    /// 여러 번 썼을 때의 내역 - 한 번 값을 그대로 곱한다.
    static func breakdown(value: String, type: ClipboardItemType?, useCount: Int) -> Breakdown {
        guard useCount > 0 else { return .zero }
        let one = breakdown(value: value, type: type)
        let n = Double(useCount)
        return Breakdown(retrieval: one.retrieval * n,
                         typing: one.typing * n,
                         verification: one.verification * n,
                         tapCost: one.tapCost * n)
    }

    // MARK: - 이 사용이 어떤 종류의 이득이었나

    /// 사용 기록에서 "왜 이만큼인가"를 한 줄로 말해 주기 위한 갈래.
    enum Kind: String, CaseIterable {
        /// 어딘가에서 찾아와야 했던 값.
        case lookup
        /// 그냥 길어서 치기 싫었던 글.
        case longText
        /// 짧고 외우고 있는 것 - 아껴 준 것이 크지 않다.
        case quick

        /// 긴 글로 치는 문턱(자). 이보다 길면 "치기만 해도 일"이다.
        static let longTextThreshold = 60

        var localizedName: String {
            switch self {
            case .lookup:
                return NSLocalizedString("찾아와야 했던 것", comment: "Saving kind: lookup")
            case .longText:
                return NSLocalizedString("길어서 치기 싫은 것", comment: "Saving kind: long text")
            case .quick:
                return NSLocalizedString("짧게 자주 쓰는 것", comment: "Saving kind: quick")
            }
        }

        var localizedExplanation: String {
            switch self {
            case .lookup:
                return NSLocalizedString("원래는 다른 앱을 열어 찾아와야 했던 값이에요. 아낀 시간의 대부분이 여기서 나와요.",
                                         comment: "Saving kind explanation: lookup")
            case .longText:
                return NSLocalizedString("찾을 필요는 없지만 손으로 옮겨 적기엔 긴 글이에요.",
                                         comment: "Saving kind explanation: long text")
            case .quick:
                return NSLocalizedString("짧아서 아끼는 시간은 작지만, 자주 쓰면 쌓여요.",
                                         comment: "Saving kind explanation: quick")
            }
        }
    }

    static func kind(value: String, type: ClipboardItemType?) -> Kind {
        if retrievalSeconds(for: type) > 0 { return .lookup }
        if value.count >= Kind.longTextThreshold { return .longText }
        return .quick
    }
}

// MARK: - 이정표

/// 아낀 시간이 어떤 크기에 닿았을 때 **한 번만** 축하한다.
///
/// ⚠️ 숫자만 커지는 화면은 아무 일도 일어나지 않는 화면과 같다. 3,600초와 3,540초는
///    사람에게 다르지 않은데, "한 시간"은 다르다. 사람이 아는 단위에 닿을 때만 말을 건다.
///
/// ⚠️ 축하는 **지나갈 때 한 번뿐**이다. 볼 때마다 축하하면 축하가 아니라 배너가 된다.
///    지나온 이정표는 App Group 에 적어 두고 다시 띄우지 않는다.
///
/// ⚠️ 비교 대상은 사람이 실제로 아는 것으로 고른다("커피 한 잔 마실 시간").
///    "2,700초 절약"은 크기가 안 잡히고, 크기가 안 잡히는 숫자는 자랑거리가 못 된다.
enum SavedTimeMilestone: String, CaseIterable, Identifiable {
    case oneMinute
    case fiveMinutes
    case fifteenMinutes
    case oneHour
    case threeHours
    case oneWorkday

    var id: String { rawValue }

    /// 이 이정표에 닿는 시간(초).
    var seconds: Double {
        switch self {
        case .oneMinute:      return 60
        case .fiveMinutes:    return 5 * 60
        case .fifteenMinutes: return 15 * 60
        case .oneHour:        return 60 * 60
        case .threeHours:     return 3 * 60 * 60
        case .oneWorkday:     return 8 * 60 * 60
        }
    }

    var localizedTitle: String {
        switch self {
        case .oneMinute:
            return NSLocalizedString("1분을 벌었어요", comment: "Milestone title: one minute")
        case .fiveMinutes:
            return NSLocalizedString("5분을 벌었어요", comment: "Milestone title: five minutes")
        case .fifteenMinutes:
            return NSLocalizedString("15분을 벌었어요", comment: "Milestone title: fifteen minutes")
        case .oneHour:
            return NSLocalizedString("한 시간을 벌었어요", comment: "Milestone title: one hour")
        case .threeHours:
            return NSLocalizedString("세 시간을 벌었어요", comment: "Milestone title: three hours")
        case .oneWorkday:
            return NSLocalizedString("하루치 일과를 벌었어요", comment: "Milestone title: one workday")
        }
    }

    /// 크기를 잡아 주는 한 줄. 사람이 아는 것에 견준다.
    var localizedComparison: String {
        switch self {
        case .oneMinute:
            return NSLocalizedString("아직 작지만, 여기서부터 쌓여요.", comment: "Milestone note: one minute")
        case .fiveMinutes:
            return NSLocalizedString("커피 한 잔 주문할 시간이에요.", comment: "Milestone note: five minutes")
        case .fifteenMinutes:
            return NSLocalizedString("정류장 하나만큼 걸어갈 시간이에요.", comment: "Milestone note: fifteen minutes")
        case .oneHour:
            return NSLocalizedString("점심 한 끼를 통째로 벌었어요.", comment: "Milestone note: one hour")
        case .threeHours:
            return NSLocalizedString("영화 한 편 보고도 남아요.", comment: "Milestone note: three hours")
        case .oneWorkday:
            return NSLocalizedString("하루 일과를 통째로 벌었어요. 이건 자랑해도 돼요.", comment: "Milestone note: one workday")
        }
    }

    // MARK: 지나온 자리

    private static let reachedKey = "kb.milestone.reached.v1"

    /// 이미 축하한 이정표들.
    static var reached: Set<String> {
        Set(AppGroup.defaults?.stringArray(forKey: reachedKey) ?? [])
    }

    /// 지금 누적 시간으로 **새로 닿은** 이정표. 없으면 nil.
    ///
    /// 여러 개를 한꺼번에 넘어섰다면 **가장 큰 것 하나만** 축하한다.
    /// 축하를 줄줄이 띄우면 그건 축하가 아니라 밀린 알림이다.
    static func newlyReached(totalSeconds: Double) -> SavedTimeMilestone? {
        let done = reached
        return allCases
            .filter { $0.seconds <= totalSeconds && !done.contains($0.rawValue) }
            .max(by: { $0.seconds < $1.seconds })
    }

    /// 축하했다고 적어 둔다. 넘어선 것 **전부**를 적는다 - 큰 것 하나만 적으면
    /// 다음에 열 때 건너뛴 작은 것들이 뒤늦게 튀어나온다.
    static func markReached(upTo milestone: SavedTimeMilestone) {
        guard let d = AppGroup.defaults else { return }
        var done = reached
        for m in allCases where m.seconds <= milestone.seconds {
            done.insert(m.rawValue)
        }
        d.set(Array(done), forKey: reachedKey)
    }

    /// 처음부터 다시 - 튜토리얼 초기화처럼 기록을 되돌릴 때만.
    static func resetAll() {
        AppGroup.defaults?.removeObject(forKey: reachedKey)
    }
}
