//
//  TimeEquivalent.swift
//  ClipKeyboard
//
//  아낀 시간을 **다른 단위로 바꿔 말한다.** "1시간 24분" 대신 "5.2km", "커피 3잔".
//
//  왜 시간을 그대로 두지 않는가
//  ⚠️ 시간은 크기가 안 잡히는 단위다. "1시간 24분을 아꼈다"를 읽고 그게 큰지 작은지
//     판단하려면 머릿속에서 한 번 더 환산해야 한다. 남의 스토리에서 넘겨 보는 3초
//     안에는 그 환산이 안 일어난다. "5.2km 달릴 수 있는 시간"은 환산이 이미 끝나
//     있어서 그냥 읽힌다.
//
//  ⚠️ **매번 다른 것이 뽑힌다.** 같은 그림을 두 번 올릴 이유는 없다. 갈래가 여덟이라
//     쓸 때마다 다른 말이 나오고, 그것 자체가 다시 열어 볼 이유가 된다.
//
//  ⚠️ 여기 있는 숫자는 전부 **가정이고, 근거를 옆에 적는다.** `TimeSavedModel` 과 같은
//     규칙이다. 근거 없는 숫자를 크게 띄우는 것은 자랑이 아니라 거짓말이고, 이건
//     남의 스토리까지 가는 그림이라 거짓말이 가장 멀리 가는 자리다.
//

import Foundation

// MARK: - 한 갈래

/// 아낀 시간을 바꿔 말한 한 가지.
struct TimeEquivalent: Equatable {

    enum Kind: String, CaseIterable {
        case run, marathon, walk, show, song, book, bookVolume, transit, coffee, noodle

        /// 돈을 거쳐 셈하는 갈래인가. 이것만 나라별 값이 필요하다.
        var needsPrices: Bool {
            switch self {
            case .coffee, .noodle: return true
            default: return false
            }
        }
    }

    let kind: Kind
    /// 큰 자리에 설 최종값. 5.2(km) · 24(곡) · 3(잔).
    let value: Double
    let symbol: String
    /// 큰 숫자 **아래** 한 줄. 위의 "이걸 손으로 했다면" 과 이어져 한 문장이 된다.
    let caption: String

    /// 큰 글씨. 굴러 올라가는 중간값도 이걸로 그린다.
    func amountText(_ shown: Double) -> String {
        switch kind {
        case .run, .walk:
            return String(format: NSLocalizedString("%@km", comment: "Equivalent unit: kilometers"),
                          String(format: "%.1f", max(0, shown)))
        case .show:
            return String(format: NSLocalizedString("%d편", comment: "Equivalent unit: episodes"), count(shown))
        case .song:
            return String(format: NSLocalizedString("%d곡", comment: "Equivalent unit: songs"), count(shown))
        case .book:
            return String(format: NSLocalizedString("%d쪽", comment: "Equivalent unit: pages"), count(shown))
        case .transit:
            return String(format: NSLocalizedString("%d정거장", comment: "Equivalent unit: transit stops"), count(shown))
        case .coffee:
            return String(format: NSLocalizedString("%d잔", comment: "Equivalent unit: cups"), count(shown))
        case .noodle:
            // ⚠️ "%d개" 를 쓰지 않는다. 그 열쇠는 이미 있고 영어 번역이 단위 없는 "%d" 라
            //    영어 화면에 숫자만 덩그러니 남는다. 이 자리 전용 열쇠를 따로 둔다.
            return String(format: NSLocalizedString("%d봉지", comment: "Equivalent unit: packs"), count(shown))
        // ⚠️ 이 둘만 **큰 글씨에 이름까지** 넣는다. 나머지 단위(km·잔·곡·쪽)는 그 자체로
        //    무엇인지 말하지만 "번"과 "권"은 아니다. 굴러 올라가는 첫 순간에 "33번"만
        //    덩그러니 서 있으면 무엇이 33인지 알 길이 없다. 아래 줄이 곧 설명하더라도,
        //    큰 자리가 혼자 읽히지 않는 것은 그 자체로 틀린 것이다.
        case .marathon:
            return String(format: NSLocalizedString("마라톤 %d번", comment: "Equivalent unit: marathons"), count(shown))
        case .bookVolume:
            return String(format: NSLocalizedString("책 %d권", comment: "Equivalent unit: books"), count(shown))
        }
    }

    private func count(_ shown: Double) -> Int { Int(max(0, shown).rounded()) }

    /// 글줄 안에 그대로 들어가는 **한 문장.** "12.5km 달릴 수 있는 시간이에요"
    ///
    /// ⚠️ `amountText` + `caption` 을 이어 붙이지 않는다. 그 둘은 영상에서 큰 글씨와
    ///    그 아래 줄로 **떨어져** 서 있을 때 읽히도록 쓴 것이라, 붙이면 말이 안 된다
    ///    ("12잔 최저임금으로 쳐도 커피 값이에요"). 붙여 쓸 자리에는 붙여 쓸 문장을 따로 둔다.
    var localizedSentence: String {
        // ⚠️ 마침표는 여기서 붙인다. 이 문장이 서는 자리의 윗줄이 "대략 3시간을 아꼈어요." 라
        //    마침표가 있고, 한 칸에서 돌아가는 문장들끼리 찍었다 안 찍었다 하면 눈에 걸린다.
        //    (지금 쓰는 세 말 모두 마침표로 문장을 닫는다. 그렇지 않은 말을 더할 때는
        //     이 줄을 카탈로그 쪽으로 옮길 것)
        sentenceBody + "."
    }

    private var sentenceBody: String {
        let amount = amountText(value)
        switch kind {
        case .run:
            return String(format: NSLocalizedString("%@ 달릴 수 있는 시간이에요",
                                                    comment: "Inline equivalent: running"), amount)
        case .marathon:
            return String(format: NSLocalizedString("%@ 완주할 수 있는 시간이에요",
                                                    comment: "Inline equivalent: marathons"), amount)
        case .walk:
            return String(format: NSLocalizedString("%@ 걸을 수 있는 시간이에요",
                                                    comment: "Inline equivalent: walking"), amount)
        case .show:
            return String(format: NSLocalizedString("드라마 %@ 볼 수 있는 시간이에요",
                                                    comment: "Inline equivalent: show"), amount)
        case .song:
            return String(format: NSLocalizedString("노래 %@ 들을 수 있는 시간이에요",
                                                    comment: "Inline equivalent: music"), amount)
        case .book:
            return String(format: NSLocalizedString("책 %@ 읽을 수 있는 시간이에요",
                                                    comment: "Inline equivalent: book pages"), amount)
        case .bookVolume:
            return String(format: NSLocalizedString("%@ 다 읽을 수 있는 시간이에요",
                                                    comment: "Inline equivalent: whole books"), amount)
        case .transit:
            return String(format: NSLocalizedString("지하철 %@ 갈 수 있는 시간이에요",
                                                    comment: "Inline equivalent: transit"), amount)
        case .coffee:
            return String(format: NSLocalizedString("최저임금으로 쳐도 커피 %@ 값이에요",
                                                    comment: "Inline equivalent: coffee"), amount)
        case .noodle:
            return String(format: NSLocalizedString("최저임금으로 쳐도 라면 %@ 값이에요",
                                                    comment: "Inline equivalent: instant noodles"), amount)
        }
    }
}

// MARK: - 뽑는 곳

enum TimeEquivalentCatalog {

    // MARK: 가정 (시간으로만 셈하는 것들)

    /// 조깅 1km 에 걸리는 시간(초).
    /// 근거: 일반인이 숨차지 않게 뛰는 속도가 6분/km 언저리다. 빠른 사람은 5분,
    /// 걷다 뛰다 하면 7분이 넘는다. 가운데를 잡는다.
    static let runSecondsPerKm: Double = 360

    /// 걷기 1km 에 걸리는 시간(초).
    /// 근거: 성인 보행 속도 시속 4km. 신호와 사람을 피하는 몫까지 넣으면 이보다 느리다.
    static let walkSecondsPerKm: Double = 900

    /// 드라마 한 편(초).
    /// 근거: 광고 없는 스트리밍 한 편이 40~45분. 42분으로 잡는다.
    static let showSeconds: Double = 42 * 60

    /// 노래 한 곡(초).
    /// 근거: 대중가요 한 곡이 3분~4분. 3분 30초로 잡는다.
    static let songSeconds: Double = 210

    /// 책 한 쪽(초).
    /// 근거: 성인 묵독 속도가 분당 250단어 남짓이고 단행본 한 쪽이 300단어 안팎이다.
    /// 한 쪽에 1분 20초. 소설은 이보다 빠르고 기술서는 훨씬 느리다.
    static let bookSecondsPerPage: Double = 80

    /// 지하철 한 정거장(초).
    /// 근거: 정차와 가속을 포함해 도심 구간 한 정거장이 2분 안팎.
    static let transitSecondsPerStop: Double = 120

    /// 셀 수 있는 갈래는 **둘 이상일 때만** 내놓는다.
    ///
    /// ⚠️ 두 가지를 한꺼번에 막는다. 첫째, "커피 1잔"은 자랑이 안 된다.
    ///    둘째, 영어에서 단수·복수가 갈리는 것을 아예 피한다 - 늘 둘 이상이면
    ///    `%d episodes` 한 줄로 끝나고 복수형 규칙을 카탈로그에 넣지 않아도 된다.
    ///    (거리는 "1.0km" 가 자연스러워 이 규칙 밖이다)
    private static let minimumCount: Double = 2

    /// 마라톤 하나(초). 42.195km 를 위의 조깅 속도로 뛴 시간.
    static var marathonSeconds: Double { 42.195 * runSecondsPerKm }

    /// 책 한 권(쪽).
    /// 근거: 단행본 한 권이 250~350쪽. 300쪽으로 잡는다.
    static let pagesPerBook: Double = 300

    /// 거리는 이보다 짧으면 내놓지 않는다(km). "0.3km 달리기"는 아낀 것으로 안 읽힌다.
    private static let minimumKm: Double = 1.0

    /// 갈래마다 **말이 되는 위쪽 끝**. 이걸 넘으면 그 갈래는 내놓지 않는다.
    ///
    /// ⚠️ 아래쪽 문턱만 두었더니 오래 쓴 사람의 화면이 무너졌다. 141시간을 아낀 사람에게
    ///    "라면 1,218봉지"·"지하철 4,250정거장"·"책 6,375쪽"이 나왔다. 이건 자랑이 아니라
    ///    농담으로 읽힌다. **머릿속에 그려지지 않는 숫자는 크기를 전달하지 못하고,**
    ///    그 순간 아래 작은 줄의 진짜 횟수까지 같이 못 믿게 된다. 어림한 숫자를 크게
    ///    띄우는 일의 값이 이것이다.
    ///
    /// ⚠️ 천장만 두면 오래 쓴 사람에게 **아무것도 안 남는다.** 그래서 위쪽에 더 큰 단위를
    ///    둘 더 놓았다(마라톤·책 권). 6분부터 150시간까지 어디에 서 있든 적어도 두세
    ///    갈래는 말이 되도록 아래 값들이 서로 이어져 있다. 하나를 손보려거든
    ///    `docs/engineering/SHARE_VIDEO_EQUIVALENTS.md` 의 표를 다시 뽑아 볼 것.
    private static func ceiling(_ kind: TimeEquivalent.Kind) -> Double {
        switch kind {
        case .run:        return 42.195      // 이보다 멀면 마라톤으로 넘긴다
        case .marathon:   return 200
        case .walk:       return 30          // 하루에 걸을 만한 거리의 끝
        case .show:       return 100         // 시즌 열 개 남짓, 아직 그려진다
        case .song:       return 500
        case .book:       return 400         // 한 권을 넘으면 권으로 넘긴다
        case .bookVolume: return 200
        case .transit:    return 200
        case .coffee:     return 500
        case .noodle:     return 100
        }
    }

    // MARK: 뽑기

    /// 이 시간으로 **말이 되는** 갈래를 전부 만든다. 하나도 없으면 빈 배열.
    ///
    /// - Parameter region: 돈을 거치는 갈래에만 쓴다. nil 이면 그 갈래는 빠진다.
    static func all(seconds: Double,
                    region: String? = Locale.current.region?.identifier,
                    now: Date = Date()) -> [TimeEquivalent] {
        guard seconds > 0 else { return [] }
        let prices = LocalPrices.table(for: region, now: now)

        return TimeEquivalent.Kind.allCases.compactMap { kind in
            if kind.needsPrices, prices == nil { return nil }
            guard let value = value(for: kind, seconds: seconds, prices: prices) else { return nil }
            return TimeEquivalent(kind: kind, value: value, symbol: symbol(kind), caption: caption(kind))
        }
    }

    /// 그중 하나를 고른다. `avoiding` 은 방금 보여 준 것 - 연달아 같은 게 나오지 않게 한다.
    static func pick(seconds: Double,
                     avoiding previous: TimeEquivalent.Kind? = nil,
                     region: String? = Locale.current.region?.identifier,
                     now: Date = Date()) -> TimeEquivalent? {
        let pool = all(seconds: seconds, region: region, now: now)
        guard !pool.isEmpty else { return nil }
        // 뺄 것을 빼고도 남는 게 있을 때만 뺀다. 갈래가 하나뿐이면 그거라도 내놓는다.
        let narrowed = pool.filter { $0.kind != previous }
        return (narrowed.isEmpty ? pool : narrowed).randomElement()
    }

    // MARK: - 값

    private static func value(for kind: TimeEquivalent.Kind,
                              seconds: Double,
                              prices: LocalPrices?) -> Double? {
        let raw: Double
        let floor: Double
        switch kind {
        case .run:
            raw = seconds / runSecondsPerKm;             floor = minimumKm
        case .marathon:
            raw = seconds / marathonSeconds;             floor = minimumCount
        case .walk:
            raw = seconds / walkSecondsPerKm;            floor = minimumKm
        case .show:
            raw = seconds / showSeconds;                 floor = minimumCount
        case .song:
            raw = seconds / songSeconds;                 floor = minimumCount
        case .book:
            raw = seconds / bookSecondsPerPage;          floor = minimumCount
        case .bookVolume:
            raw = seconds / bookSecondsPerPage / pagesPerBook; floor = minimumCount
        case .transit:
            raw = seconds / transitSecondsPerStop;       floor = minimumCount
        case .coffee:
            guard let prices else { return nil }
            raw = prices.earned(seconds: seconds) / prices.coffee; floor = minimumCount
        case .noodle:
            guard let prices else { return nil }
            raw = prices.earned(seconds: seconds) / prices.noodle; floor = minimumCount
        }
        return within(raw, floor: floor, ceiling: ceiling(kind))
    }

    /// 양 끝 안에 들어야 내놓는다.
    ///
    /// ⚠️ 아래쪽은 **반올림한 뒤** 잰다. 1.6잔은 화면에 "2잔"으로 서기 때문이다.
    ///    위쪽은 반올림 전 값으로 잰다. 천장은 "여기까지가 그려진다"는 선이라
    ///    한 끗 차이로 넘나드는 것을 굳이 살려 줄 이유가 없다.
    private static func within(_ value: Double, floor: Double, ceiling: Double) -> Double? {
        guard value.rounded() >= floor, value <= ceiling else { return nil }
        return value
    }

    private static func symbol(_ kind: TimeEquivalent.Kind) -> String {
        switch kind {
        case .run:        return AppSymbol.figureRun
        case .marathon:   return AppSymbol.flagCheckered
        case .bookVolume: return AppSymbol.booksVerticalFill
        case .walk:    return AppSymbol.figureWalk
        case .show:    return AppSymbol.playTvFill
        case .song:    return AppSymbol.musicNote
        case .book:    return AppSymbol.bookPages
        case .transit: return AppSymbol.tramFill
        case .coffee:  return AppSymbol.cupAndSaucerFill
        case .noodle:  return AppSymbol.forkKnife
        }
    }

    /// ⚠️ 위의 "이걸 손으로 했다면" 과 **이어 읽히는 한 문장**이다. 따로 읽히면 안 된다.
    private static func caption(_ kind: TimeEquivalent.Kind) -> String {
        switch kind {
        case .run:
            return NSLocalizedString("달릴 수 있는 시간이에요", comment: "Share video: running equivalent")
        case .marathon:
            return NSLocalizedString("완주할 수 있는 시간이에요", comment: "Share video: marathon equivalent")
        case .bookVolume:
            return NSLocalizedString("다 읽을 수 있는 시간이에요", comment: "Share video: whole book equivalent")
        case .walk:
            return NSLocalizedString("걸을 수 있는 시간이에요", comment: "Share video: walking equivalent")
        case .show:
            return NSLocalizedString("드라마를 볼 수 있는 시간이에요", comment: "Share video: show equivalent")
        case .song:
            return NSLocalizedString("노래를 들을 수 있는 시간이에요", comment: "Share video: music equivalent")
        case .book:
            return NSLocalizedString("책을 읽을 수 있는 시간이에요", comment: "Share video: reading equivalent")
        case .transit:
            return NSLocalizedString("지하철로 갈 수 있는 시간이에요", comment: "Share video: transit equivalent")
        case .coffee:
            return NSLocalizedString("최저임금으로 쳐도 커피 값이에요", comment: "Share video: coffee equivalent")
        case .noodle:
            return NSLocalizedString("최저임금으로 쳐도 라면 값이에요", comment: "Share video: instant noodle equivalent")
        }
    }
}

// MARK: - 나라마다 다른 값

/// 최저임금과 물건값. **둘 다 매년 바뀌므로 기준 연도를 함께 들고 다닌다.**
///
/// 왜 금액을 그대로 안 쓰고 물건으로 바꾸는가
/// ⚠️ "최저임금으로 쳐도 13,240원"은 표를 손보지 않으면 해마다 조금씩 틀려진다.
///    그런데 "커피 3잔"은 훨씬 오래 버틴다. **최저임금과 커피값이 대체로 같이 오르기
///    때문이다.** 우리가 쓰는 것은 두 값의 **비율**이고, 비율은 물가를 타지 않는다.
///    표가 몇 해 낡아도 잔 수는 웬만해선 그대로다. 금액을 크게 띄우는 쪽이
///    더 정확해 보이지만 실제로는 그 반대다.
///
/// ⚠️ 그래도 영원하지는 않다. `staleAfterYears` 가 지나면 **돈을 거치는 갈래는 통째로
///    빠진다.** 시간·거리로 셈하는 갈래는 남으므로 화면이 비지 않는다. 낡은 값을 계속
///    내보내느니 그 갈래를 접는 편이 낫다.
///
/// ⚠️ 표에 없는 지역은 **채워 넣지 않는다.** 한국 최저임금으로 브라질 사용자의
///    커피 잔 수를 세면 그건 그냥 틀린 숫자다. 없으면 없는 대로 다른 갈래가 나간다.
struct LocalPrices {
    /// 시간당 최저임금(현지 통화).
    let hourlyWage: Double
    /// 카페에서 마시는 커피 한 잔(현지 통화).
    let coffee: Double
    /// 봉지 라면·즉석면 한 개, 마트 기준(현지 통화).
    let noodle: Double
    /// 이 값들을 적어 넣은 해. 낡았는지 재는 기준이다.
    let asOf: Int

    /// 이 시간을 최저임금으로 환산한 돈(현지 통화).
    func earned(seconds: Double) -> Double { hourlyWage * seconds / 3600 }

    /// 기준 연도가 이만큼 지나면 더는 쓰지 않는다.
    ///
    /// 근거: 최저임금은 해마다 오르지만 물건값도 같이 오르므로 비율은 잘 안 움직인다.
    /// 3년이면 비율이 눈에 띄게 어긋날 만한 폭이고, 그 사이에 앱이 몇 번은 업데이트된다.
    static let staleAfterYears = 3

    /// 지역 코드로 찾는다. 없거나 낡았으면 nil - 부르는 쪽이 그 갈래를 뺀다.
    static func table(for region: String?, now: Date = Date()) -> LocalPrices? {
        guard let region, let prices = byRegion[region.uppercased()] else { return nil }
        let year = Calendar(identifier: .gregorian).component(.year, from: now)
        guard year - prices.asOf <= staleAfterYears else { return nil }
        return prices
    }

    /// ⚠️ **값을 손볼 때 `asOf` 를 같이 올릴 것.** 안 올리면 낡은 값이 3년 더 나간다.
    ///    올리기만 하고 값을 안 고치면 그게 더 나쁘다 - 만료 장치를 껐을 뿐이다.
    ///
    /// ⚠️ 물건값은 **한 잔·한 개의 흔한 소매가**지 평균이 아니다. 우리가 쓰는 것은
    ///    최저임금과의 비율뿐이라 소수점까지 맞을 필요가 없다. 다만 자릿수가 틀리면
    ///    바로 티가 나므로 그것만 지킨다.
    ///
    /// ⚠️ 인도네시아는 시간당 최저임금이라는 제도가 없다. 주별 월 최저임금(UMP)을
    ///    월 173시간으로 나눈 값이다. 자카르타 기준이라 지방은 이보다 낮다.
    private static let byRegion: [String: LocalPrices] = [
        "KR": LocalPrices(hourlyWage: 10_320, coffee: 4_500, noodle: 1_200, asOf: 2026),
        "US": LocalPrices(hourlyWage: 7.25, coffee: 4.00, noodle: 1.20, asOf: 2025),
        "JP": LocalPrices(hourlyWage: 1_121, coffee: 400, noodle: 180, asOf: 2025),
        "GB": LocalPrices(hourlyWage: 12.21, coffee: 3.50, noodle: 1.00, asOf: 2025),
        "DE": LocalPrices(hourlyWage: 12.82, coffee: 3.30, noodle: 1.00, asOf: 2025),
        "FR": LocalPrices(hourlyWage: 11.88, coffee: 3.00, noodle: 1.00, asOf: 2025),
        "NL": LocalPrices(hourlyWage: 14.06, coffee: 3.50, noodle: 1.10, asOf: 2025),
        "AU": LocalPrices(hourlyWage: 24.95, coffee: 5.00, noodle: 1.50, asOf: 2025),
        "NZ": LocalPrices(hourlyWage: 23.50, coffee: 5.50, noodle: 1.50, asOf: 2025),
        "CA": LocalPrices(hourlyWage: 17.75, coffee: 3.50, noodle: 1.50, asOf: 2025),
        "TW": LocalPrices(hourlyWage: 190, coffee: 60, noodle: 35, asOf: 2025),
        "HK": LocalPrices(hourlyWage: 42.10, coffee: 35, noodle: 10, asOf: 2025),
        "ID": LocalPrices(hourlyWage: 31_195, coffee: 25_000, noodle: 3_500, asOf: 2025),
    ]
}
