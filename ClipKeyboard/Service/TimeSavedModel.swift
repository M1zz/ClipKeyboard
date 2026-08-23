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
//      ⑤ 밑값(baseline)             - 위를 다 더해도 못 미칠 때 채우는 몫
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
//  ⚠️ 보수적으로 잡되, **못 본 것을 0으로 적지는 않는다.** 이 둘은 다르다.
//     과장한 숫자는 한 번 들키면 나머지 화면까지 다 못 믿게 되지만, 반대로 지나치게
//     낮은 숫자는 이 앱이 하는 일을 **아예 안 보이게** 만든다. 그것도 틀린 것이다.
//
//     깃 토큰이 그 예였다. 40자짜리 무작위 문자열이라 이 앱은 "글"로 보고 치는 시간
//     10초만 셌다. 그런데 실제로 사람이 하던 일은 깃허브를 열고 → 설정으로 들어가 →
//     토큰을 찾거나 새로 만들고 → 복사해서 → 돌아오는 것이었다. 10초일 리가 없다.
//     못 본 것은 못 봤다고 인정하고 **밑값**(`minimumSavedSeconds`)으로 받친다.
//
//  ⚠️ **한 번의 수고를 여러 번으로 세지 않는다.** 위의 네 조각을 매번 그대로 얹으면
//     같은 값을 잇달아 붙여넣은 사람의 화면이 부푼다. 계좌번호를 한 서식에 세 번
//     넣었다고 은행 앱을 세 번 연 것은 아니다. 그래서 두 가지 상한을 둔다.
//
//      · 잇달아 쓰면(`repeatWindowSeconds`) 찾아오는 시간·옮겨 담는 시간을 안 물린다.
//        값은 이미 손에 있었다.
//      · 치는 시간에는 천장이 있다(`typingCeilingSeconds`). 그보다 긴 글은 애초에
//        손으로 옮겨 적을 글이 아니라, 어딘가에서 복사해 왔을 글이다.
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

    /// 한 번 쓸 때 **적어도 이만큼은** 아낀 것으로 본다(초).
    ///
    /// ⚠️ 조각을 다 더해도 이 아래로 나오는 경우가 있다. 그런데 그 숫자는 대체로
    ///    **모델이 못 본 것**이지 실제로 안 아낀 것이 아니다. 깃 토큰이 그 예다.
    ///    40자짜리 무작위 문자열이라 이 앱은 그냥 "글"로 보고 치는 시간 10초만 세는데,
    ///    실제로 사람이 하던 일은 깃허브를 열고 → 설정으로 들어가 → 토큰을 찾거나 새로
    ///    만들고 → 복사해서 → 돌아오는 것이었다. 10초일 리가 없다.
    ///
    /// ⚠️ 문구로 저장해 뒀다는 것 자체가 "이걸 매번 처리하기 싫다"는 뜻이다. 한 번 꺼내
    ///    쓸 때마다 하던 일을 멈추고 → 값을 어디서 가져올지 떠올리고 → 가져와서 → 넣고 →
    ///    맞는지 본다. 이 **멈췄다 다시 시작하는 값**이 30초 아래인 경우는 드물다.
    ///
    /// ⚠️ 밑값은 `minimumCharacters` 를 넘긴 것에만 붙는다. "네"·"ok" 는 여전히 0이다
    ///    - 밑값은 못 센 것을 채우는 것이지, 안 아낀 것을 아꼈다고 하는 게 아니다.
    static let minimumSavedSeconds: Double = 30

    /// 한 번 쓸 때 **치는 시간**으로 셀 수 있는 최대치(초).
    ///
    /// ⚠️ 상한이 없으면 5,000자짜리 문구 하나가 탭 한 번에 "20분을 아꼈다"고 찍힌다.
    ///    그건 아무도 안 믿는다. 실제로 사람이 그만한 글을 손으로 옮겨 적는 일은 없기
    ///    때문이다. 어딘가에서 복사해 왔을 것이고, **그 길은 이미 찾아오는 시간과
    ///    옮겨 담는 시간이 세고 있다.** 상한을 안 두면 같은 일을 두 번 세는 셈이다.
    ///
    /// 근거: 3분이면 초당 4자로 720자다. 문자 메시지 한 통이나 자기소개 한 문단은
    /// 넉넉히 들어가고, 그보다 긴 것은 "쳐서 넣는 글"이 아니라 "어딘가에 있던 글"이다.
    static let typingCeilingSeconds: Double = 180

    /// 앞서 쓴 뒤 이 시간 안에 **또 쓰면** 찾아오는 값을 다시 물리지 않는다(초).
    ///
    /// ⚠️ 계좌번호를 한 화면에서 세 번 붙여넣었다고 은행 앱을 세 번 연 것은 아니다.
    ///    한 번 꺼내 온 값은 손에(클립보드에) 남아 있어서, 두 번째부터 사람이 하던 일은
    ///    "붙여넣기" 하나뿐이다. 그런데도 매번 28초를 얹으면 한 번의 수고가 세 번이 된다.
    ///
    /// ⚠️ 되짚어 읽는 시간은 **깎지 않는다.** 붙여넣을 때마다 자릿수는 다시 확인한다.
    ///
    /// 근거: 10분. 이보다 길게 잡으면 오후에 다시 꺼낸 값까지 공짜로 세고, 짧게 잡으면
    /// 같은 서식을 채우는 몇 분 사이가 갈라진다. 어느 쪽으로 틀릴지 골라야 한다면
    /// **적게 세는 쪽**이라, 넉넉한 10분을 쓴다.
    static let repeatWindowSeconds: Double = 10 * 60

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
    /// ⚠️ 여기 값은 두 번 올렸다. 처음에는 실측 범위의 **가장 짧은 쪽**이었고, 그다음엔
    ///    가운데를 잡았는데 그것도 낮았다. 낮게 잡은 쪽이 안전하다고 여겼지만, 실제로는
    ///    **이 앱이 하는 일을 못 보이게 하는 쪽**이었다. 앱을 열어 값을 찾아오는 일을
    ///    직접 초를 재 보면, 화면이 뜨기를 기다리는 시간·목록에서 눈으로 훑는 시간·
    ///    맞는지 한 번 더 보는 시간이 전부 들어간다. 지금 값은 그걸 실제로 재 본 크기다.
    ///
    /// ⚠️ 그래도 **긴 쪽 실측치는 아니다.** 은행 앱이 콜드 스타트로 뜨고 인증이 한 번에
    ///    안 되면 1분을 넘기는 일도 흔한데, 그건 안 쓴다. 어느 쪽으로 틀릴지 골라야 한다면
    ///    여전히 적게 세는 쪽이다.
    enum Retrieval {
        /// 찾아올 곳이 없다 - 인사말·자기 이름처럼 그냥 쳐 내려가는 것.
        ///
        /// 0 이지만 실제로 0원이 되지는 않는다. 밑값(`minimumSavedSeconds`)이 받쳐 준다.
        static let fromMemory: Double = 0
        /// 외우고는 있지만 **정확히** 옮겨야 하는 것(이메일·전화번호).
        ///
        /// 0 이 아닌 이유: 아는 값이어도 사람은 한 번 확인하고 넣는다. 오타 하나면
        /// 답장이 안 오는 주소라서, 지난 메일이나 메모를 열어 눈으로 맞춰 보는 일이 잦다.
        /// (4초였다. 앱을 여는 시간도 안 되는 값이라 올렸다.)
        static let fromRecall: Double = 10
        /// 이 기기 어딘가 - 다른 앱을 열어 눈으로 찾는다(주소록·메모·배송 앱).
        ///
        /// 앱이 뜨고 → 목록을 훑고 → 맞는 항목인지 보는 데까지. 12초로는 앱이 뜨고 나면
        /// 남는 게 없다.
        static let fromAnotherApp: Double = 25
        /// 잠긴 곳 - 은행·카드 앱을 열고 인증을 거쳐 해당 화면까지 간다.
        ///
        /// 콜드 스타트 + 생체인증 + 계좌 화면까지 이동 + 네트워크 대기. 스스로 한 번
        /// 재 보면 안다. 28초에 끝나는 일이 아니다.
        static let fromSecuredApp: Double = 50
        /// 기기 밖 - 지갑·서랍의 실물을 꺼내 온다(여권·보험증).
        ///
        /// 자리에서 일어나는 순간 이미 45초는 지나 있다.
        static let fromPhysical: Double = 75
    }

    // MARK: - 옮겨 담는 시간

    /// 찾은 값을 **여기까지 가져오는** 손놀림에 드는 시간(초).
    ///
    /// 길게 눌러 선택 → 손잡이 두 개를 끌어 범위 맞추기 → 복사 → 쓰던 앱으로 복귀 →
    /// 다시 길게 눌러 붙여넣기. 이 중 대부분은 **선택**이 먹는다. 계좌번호처럼 하이픈이
    /// 섞인 문자열은 단어 단위 선택이 어긋나서 손잡이를 손보게 된다.
    ///
    /// 이 앱에서는 이 다섯 단계가 통째로 사라지고 탭 한 번이 된다.
    ///
    /// 8초였다. 다섯 단계를 8초에 끝내려면 한 번도 안 어긋나야 하는데, 손잡이 끌기는
    /// 원래 잘 어긋난다. 두 번째 시도가 흔한 것을 감안해 12초로 잡는다.
    static let handlingSeconds: Double = 12

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
            // 자릿수를 손가락으로 짚어 가며 읽는 일이라 8초보다 오래 걸린다.
            return 12
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
        /// 밑값을 채우는 몫 - 위의 조각이 `minimumSavedSeconds` 에 못 미칠 때 그 차이.
        ///
        /// ⚠️ 이걸 **따로 둔 이유**가 있다. 그냥 합계를 30으로 올려 버리면 화면이 펼쳐
        ///    보이는 네 줄의 합과 위의 큰 숫자가 안 맞는다. 셈을 펼쳐 보이려고 만든
        ///    자리가 셈이 안 맞는다고 말하게 되는 것이다. 밑값도 한 줄로 적으면
        ///    **더해 보면 그대로 맞는다.**
        let baseline: Double
        /// 이 앱을 쓰는 데 든 값(뺀다).
        let tapCost: Double

        /// 실제로 아낀 시간(초). 음수는 0으로 - 손해 본 것을 이득으로 적지 않는다.
        var total: Double {
            max(0, retrieval + handling + typing + verification + baseline - tapCost)
        }

        static let zero = Breakdown(retrieval: 0, handling: 0, typing: 0,
                                    verification: 0, baseline: 0, tapCost: 0)

        static func + (lhs: Breakdown, rhs: Breakdown) -> Breakdown {
            Breakdown(retrieval: lhs.retrieval + rhs.retrieval,
                      handling: lhs.handling + rhs.handling,
                      typing: lhs.typing + rhs.typing,
                      verification: lhs.verification + rhs.verification,
                      baseline: lhs.baseline + rhs.baseline,
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
    ///   - isRepeat: 바로 앞서 쓴 것을 `repeatWindowSeconds` 안에 **또** 쓴 것인가.
    ///     그렇다면 값은 이미 손에 있었으므로 찾아오는 시간과 옮겨 담는 시간을 물리지 않는다.
    static func breakdown(value: String, type: ClipboardItemType?, isRepeat: Bool = false) -> Breakdown {
        let length = value.count
        guard length >= minimumCharacters else { return .zero }

        // 숫자가 섞인 만큼 치는 속도를 낮춘다(글 4자/초 ↔ 숫자 2자/초 사이).
        let ratio = digitRatio(of: value)
        let cps = proseCharsPerSecond + (digitCharsPerSecond - proseCharsPerSecond) * ratio

        let retrieval = isRepeat ? 0 : retrievalSeconds(for: type)
        let handling = isRepeat ? 0 : handlingSeconds(for: type)
        // 손으로 옮겨 적었다고 볼 수 있는 데까지만 센다. 위쪽은 자르는 게 아니라
        // 애초에 손으로 옮겨 적을 글이 아니라서 셀 수 없는 것이다.
        let typing = min(Double(length) / cps, typingCeilingSeconds)
        let verification = verificationSeconds(for: type)

        // 조각을 다 더해도 밑값에 못 미치면 그 차이를 채운다.
        // ⚠️ 못 센 것을 채우는 것이지, 위에서 센 것에 얹는 게 아니다. 그래서 더하기가
        //    아니라 **모자란 만큼**이고, 이미 밑값을 넘긴 값에는 0이 붙는다.
        let counted = retrieval + handling + typing + verification - tapCostSeconds
        let baseline = max(0, minimumSavedSeconds - counted)

        return Breakdown(retrieval: retrieval,
                         handling: handling,
                         typing: typing,
                         verification: verification,
                         baseline: baseline,
                         tapCost: tapCostSeconds)
    }

    /// 여러 번 썼을 때의 내역 - 한 번 값을 그대로 곱한다.
    ///
    /// ⚠️ 여기서는 **잇달아 쓴 것을 가려낼 수 없다**(언제 썼는지가 아니라 몇 번 썼는지만
    ///    안다). 그래서 이 값은 실제로 원장에 쌓인 것보다 조금 클 수 있다. 원장이 있는
    ///    자리에서는 원장을 읽을 것 - 이건 횟수밖에 없는 자리(카드에 쌓인 동전 등)를 위한
    ///    어림이다.
    static func breakdown(value: String, type: ClipboardItemType?, useCount: Int) -> Breakdown {
        guard useCount > 0 else { return .zero }
        let one = breakdown(value: value, type: type)
        let n = Double(useCount)
        return Breakdown(retrieval: one.retrieval * n,
                         handling: one.handling * n,
                         typing: one.typing * n,
                         verification: one.verification * n,
                         baseline: one.baseline * n,
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
