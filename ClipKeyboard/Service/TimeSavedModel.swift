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
//  그래서 한 번의 사용을 네 조각으로 나눈다.
//
//      ① 찾아오는 시간(retrieval)   - 다른 곳에서 가져와야 했던 값인가
//      ② 옮겨 담는 시간(handling)   - 찾은 다음, 그걸 여기까지 가져오는 손놀림
//      ③ 치는 시간(typing)          - 손으로 옮겨 적었다면 걸렸을 시간
//      ④ 확인하는 시간(verification) - 틀리면 큰일 나는 숫자를 되짚어 보는 시간
//      빼기: 이 앱을 쓰는 값(tap)    - 키보드를 열고 키를 찾아 누르는 값
//
//  ⚠️ **②가 오래 빠져 있었다.** 찾는 시간과 치는 시간만 세면, 정작 사람이 실제로 하던
//     일의 한가운데가 빠진다. 값을 찾은 뒤에도 일이 남아 있다
//     길게 눌러 선택하고 → 양쪽 손잡이를 끌어 범위를 맞추고 → 복사하고 →
//     쓰던 앱으로 돌아와서 → 다시 길게 눌러 붙여넣는다.
//     휴대폰에서 이 손놀림은 **찾는 것만큼 성가시다.** 한 번에 되는 일도 아니라서,
//     선택 범위가 어긋나 두 번 하는 일이 흔하다.
//
//     예전 식은 이메일 한 줄을 "5초 치기 - 1초 탭 = 4초"로 셌다. 그런데 실제로
//     사람이 하던 일은 4초짜리가 아니었다.
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
    /// 근거: 숫자는 자판을 한 번 바꿔야 하고, 외워서 이어 치지 못해 **한 자씩 눈으로
    /// 확인하며** 누른다. 하이픈·공백이 섞이면 자판을 또 오간다. 초당 2자로 잡는다.
    /// (열여섯 자리 카드 번호에 8초. 직접 해 보면 그보다 빠르기 어렵다.)
    static let digitCharsPerSecond: Double = 2.0

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
    /// ⚠️ 근거를 밝힌다. 아래 값은 전부 **머릿속으로 검산할 수 있는 크기**로 잡았다.
    ///    "은행 앱을 열고 Face ID 를 통과해 계좌 화면까지 가는 데 28초"를 스스로
    ///    세어 보면 맞는지 틀리는지 바로 안다. 검산이 안 되는 숫자는 못 믿는다.
    ///
    /// ⚠️ 예전에는 여기 실측 범위의 **가장 짧은 쪽**을 넣어 두었다. 보수적으로 잡자는
    ///    뜻이었는데, 지나쳤다. "앱을 열어 찾아 온다"가 8초에 끝나는 일은 거의 없다.
    ///    화면이 열리기를 기다리고, 목록에서 눈으로 찾고, 맞는지 한 번 본다.
    ///    지금은 **가운데**를 잡는다. 여전히 긴 쪽 실측치보다는 훨씬 짧다.
    enum Retrieval {
        /// 찾아올 곳이 없다 - 인사말·자기 이름처럼 그냥 쳐 내려가는 것.
        static let fromMemory: Double = 0
        /// 외우고는 있지만 **정확히** 옮겨야 하는 것(이메일·전화번호).
        ///
        /// 0 이 아닌 이유: 아는 값이어도 사람은 한 번 확인하고 넣는다. 오타 하나면
        /// 답장이 안 오는 주소라서, 지난 메일이나 메모를 열어 눈으로 맞춰 보는 일이 잦다.
        static let fromRecall: Double = 4
        /// 이 기기 어딘가 - 다른 앱을 열어 눈으로 찾는다(주소록·메모·배송 앱).
        static let fromAnotherApp: Double = 12
        /// 잠긴 곳 - 은행·카드 앱을 열고 인증을 거쳐 해당 화면까지 간다.
        static let fromSecuredApp: Double = 28
        /// 기기 밖 - 지갑·서랍의 실물을 꺼내 온다(여권·보험증).
        static let fromPhysical: Double = 45
    }

    // MARK: - 옮겨 담는 시간

    /// 찾은 값을 **여기까지 가져오는** 손놀림에 드는 시간(초).
    ///
    /// 길게 눌러 선택 → 손잡이 두 개를 끌어 범위 맞추기 → 복사 → 쓰던 앱으로 복귀 →
    /// 다시 길게 눌러 붙여넣기. 이 중 대부분은 **선택**이 먹는다. 계좌번호처럼 하이픈이
    /// 섞인 문자열은 단어 단위 선택이 어긋나서 손잡이를 손보게 된다.
    ///
    /// 이 앱에서는 이 다섯 단계가 통째로 사라지고 탭 한 번이 된다.
    static let handlingSeconds: Double = 8

    /// 이 값에 **옮겨 담는 시간이 붙는가.**
    ///
    /// ⚠️ 붙지 않는 경우가 둘 있다.
    ///    · 찾아올 곳이 없는 것(`fromMemory`) - 복사할 원본 자체가 없다.
    ///    · 실물에서 오는 것(`fromPhysical`) - 여권은 복사가 안 된다. 눈으로 읽어
    ///      손으로 옮겨 적으므로, 그 값은 이미 `typing` 이 세고 있다.
    ///      여기서 또 세면 같은 시간을 두 번 세는 것이다.
    static func handlingSeconds(for type: ClipboardItemType?) -> Double {
        let retrieval = retrievalSeconds(for: type)
        guard retrieval > 0, retrieval != Retrieval.fromPhysical else { return 0 }
        return handlingSeconds
    }

    /// 값의 종류별로 "원래 어디서 가져와야 했나".
    ///
    /// ⚠️ 이 앱이 이미 하고 있는 분류(`ClipboardItemType`)를 그대로 쓴다.
    ///    새로 수집하는 것이 하나도 없다는 뜻이다 - 이 규칙은 사용 기록 화면 전체가
    ///    지키고 있는 것이라 여기서도 깬다면 그 화면이 통째로 거짓이 된다.
    static func retrievalSeconds(for type: ClipboardItemType?) -> Double {
        guard let type else { return Retrieval.fromMemory }
        switch type {
        // 찾아올 곳이 없다 - 그냥 쳐 내려간다.
        case .name, .text, .image:
            return Retrieval.fromMemory

        // 아는 값이지만 정확해야 해서 한 번 맞춰 본다.
        case .email, .phone, .birthDate:
            return Retrieval.fromRecall

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
            // 한 번 훑는 것으로 끝나지 않는다. 넣고 한 번, 보내기 전에 또 한 번 본다.
            return 8
        default:
            return 0
        }
    }

    // MARK: - 한 번의 사용

    /// 한 번 쓸 때 아낀 시간의 **내역**. 화면은 이걸 받아 그대로 펼쳐 보여준다.
    struct Breakdown: Equatable {
        /// 다른 곳에서 찾아오지 않아도 된 시간.
        let retrieval: Double
        /// 선택·복사·붙여넣기로 옮겨 담지 않아도 된 시간.
        let handling: Double
        /// 손으로 옮겨 적지 않아도 된 시간.
        let typing: Double
        /// 되짚어 읽지 않아도 된 시간.
        let verification: Double
        /// 이 앱을 쓰는 데 든 값(뺀다).
        let tapCost: Double

        /// 실제로 아낀 시간(초). 음수는 0으로 - 손해 본 것을 이득으로 적지 않는다.
        var total: Double { max(0, retrieval + handling + typing + verification - tapCost) }

        static let zero = Breakdown(retrieval: 0, handling: 0, typing: 0,
                                    verification: 0, tapCost: 0)

        static func + (lhs: Breakdown, rhs: Breakdown) -> Breakdown {
            Breakdown(retrieval: lhs.retrieval + rhs.retrieval,
                      handling: lhs.handling + rhs.handling,
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
                         handling: handlingSeconds(for: type),
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
                         handling: one.handling * n,
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
                return NSLocalizedString("원래는 다른 앱을 열어 찾고, 선택해서 복사하고, 돌아와서 붙여넣어야 했던 값이에요. 아낀 시간의 대부분이 여기서 나와요.",
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

    /// ⚠️ 문턱은 `fromAnotherApp` 이다. `fromRecall`(이메일·전화)까지 "찾아와야 했던 것"으로
    ///    부르면 그 갈래가 통째로 부풀어, 정작 은행 앱을 열던 값이 묻힌다.
    ///    시간은 후하게 세되, **이름표는 정확하게** 붙인다.
    static func kind(value: String, type: ClipboardItemType?) -> Kind {
        if retrievalSeconds(for: type) >= Retrieval.fromAnotherApp { return .lookup }
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
