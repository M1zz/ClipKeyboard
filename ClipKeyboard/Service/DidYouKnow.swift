//
//  DidYouKnow.swift
//  ClipKeyboard
//
//  **그거 아세요?** - 이 앱이 자기 자랑을 하는 유일한 자리.
//
//  왜 필요한가: 이 앱의 좋은 점은 대부분 **안 보이는 곳**에 있다. 서버가 없다는 것,
//  설정 어딘가에 있는 기능들, 길게 누르면 되는 동작들. 화면에 안 나오는 것은
//  아무리 좋아도 없는 것과 같고, 설정을 뒤져 볼 사람은 백 명 중 몇 명이다.
//
//  ⚠️ **한 번에 하나만 말한다.** 기능 목록을 펼쳐 보이면 하나도 안 남는다.
//     한 번에 한 가지, 며칠에 한 번.
//
//  ⚠️ **본 것은 다시 안 나온다.** 같은 것을 되풀이하면 그때부터는 광고로 읽힌다.
//     다 봤으면 그냥 멈춘다 - 처음으로 돌아가지 않는다.
//
//  ⚠️ **자랑이 아니라 쓸모여야 한다.** 각 항목은 읽고 나서 **할 수 있는 일**이
//     하나 생겨야 한다(설정을 켜거나, 길게 눌러 보거나, 안심하거나).
//     "우리 앱은 빠릅니다" 같은 것은 여기 넣지 않는다.
//

import Foundation

/// 한 번에 하나씩 알려 주는 이야기.
struct DidYouKnow: Identifiable, Equatable {
    /// 본 것을 기억하는 열쇠. **문구가 바뀌어도 이 값은 그대로 둔다** -
    /// 바꾸면 이미 본 사람에게 다시 뜬다.
    let id: String
    /// 한 줄 제목.
    let title: String
    /// 두세 줄 설명.
    let body: String
    /// SF Symbol.
    let symbol: String
    /// 읽고 나서 갈 수 있는 곳(있으면). 없으면 알기만 하면 되는 이야기다.
    var action: Action?

    enum Action: Equatable {
        /// 설정 화면으로.
        case openSettings
        /// 키보드 미리보기(무대)로.
        case openStage
        /// 백업 화면으로.
        case openBackup

        var localizedLabel: String {
            switch self {
            case .openSettings:
                return NSLocalizedString("설정에서 보기", comment: "Did-you-know action: settings")
            case .openStage:
                return NSLocalizedString("키보드에서 해보기", comment: "Did-you-know action: stage")
            case .openBackup:
                return NSLocalizedString("백업 화면 열기", comment: "Did-you-know action: backup")
            }
        }
    }
}

// MARK: - 할 이야기들

extension DidYouKnow {

    /// 순서에 뜻이 있다. **가장 안심되는 것이 먼저다** - 이 앱에 개인정보를 적어도 되는지가
    /// 첫 며칠의 가장 큰 물음이고, 그 답을 못 들으면 나머지 기능은 쓸 일이 없다.
    static let all: [DidYouKnow] = [
        DidYouKnow(
            id: "no-server",
            title: NSLocalizedString("여기 적은 것은 어디로도 가지 않아요", comment: "DYK title: no server"),
            body: NSLocalizedString("이 앱에는 서버가 없어요. 계좌번호도 주민등록번호도 이 폰 안에만 있고, 저희조차 볼 수 없습니다. 털릴 서버가 없으니 털릴 방법도 없어요.", comment: "DYK body: no server"),
            symbol: "lock.iphone"
        ),
        DidYouKnow(
            id: "secure-memo",
            title: NSLocalizedString("남에게 보여주기 싫은 건 잠글 수 있어요", comment: "DYK title: secure memo"),
            body: NSLocalizedString("단축어를 보안으로 두면 Face ID 를 통과해야 열려요. 폰을 잠깐 빌려줘도 그것만은 안 보입니다.", comment: "DYK body: secure memo"),
            symbol: "faceid",
            action: .openSettings
        ),
        DidYouKnow(
            id: "long-press-copy",
            title: NSLocalizedString("길게 누르면 복사돼요", comment: "DYK title: long press"),
            body: NSLocalizedString("키보드에서 단축어를 길게 누르면 입력 대신 클립보드로 들어가요. 붙여넣을 곳이 따로 있을 때 쓰세요.", comment: "DYK body: long press"),
            symbol: "hand.tap",
            action: .openStage
        ),
        DidYouKnow(
            id: "auto-classify",
            title: NSLocalizedString("복사한 것이 알아서 갈래를 찾아가요", comment: "DYK title: auto classify"),
            body: NSLocalizedString("계좌번호를 복사하면 계좌로, 주소를 복사하면 주소로 스스로 분류돼요. 나중에 찾을 때 검색하지 않고 갈래만 고르면 됩니다.", comment: "DYK body: auto classify"),
            symbol: "square.grid.2x2"
        ),
        DidYouKnow(
            id: "checksum",
            title: NSLocalizedString("틀린 카드번호는 저장할 때 알려드려요", comment: "DYK title: checksum"),
            body: NSLocalizedString("카드번호·IBAN·사업자등록번호는 검사식이 있어요. 한 자리를 잘못 적었으면 저장하기 전에 짚어 드립니다.", comment: "DYK body: checksum"),
            symbol: "checkmark.seal"
        ),
        DidYouKnow(
            id: "cursor-token",
            title: NSLocalizedString("커서를 어디에 둘지 정할 수 있어요", comment: "DYK title: cursor token"),
            body: NSLocalizedString("단축어 안에 {커서} 를 적어 두면, 넣은 뒤 커서가 그 자리에 섭니다. 뒷말을 이어 쓸 때 손이 덜 갑니다.", comment: "DYK body: cursor token"),
            symbol: "text.cursor"
        ),
        DidYouKnow(
            id: "clipboard-token",
            title: NSLocalizedString("복사해 둔 것을 문장 안에 끼울 수 있어요", comment: "DYK title: clipboard token"),
            body: NSLocalizedString("{클립보드} 를 적어 두면 그 자리에 방금 복사한 것이 들어가요. \"운송장 번호는 {클립보드} 입니다\" 처럼요.", comment: "DYK body: clipboard token"),
            symbol: "doc.on.clipboard"
        ),
        DidYouKnow(
            id: "icloud-backup",
            title: NSLocalizedString("폰을 잃어버려도 단축어는 남아요", comment: "DYK title: backup"),
            body: NSLocalizedString("iCloud 백업이 켜져 있으면 새 폰에서 그대로 불러올 수 있어요. 백업은 본인 iCloud 계정에만 저장됩니다.", comment: "DYK body: backup"),
            symbol: "icloud",
            action: .openBackup
        ),
        DidYouKnow(
            id: "keyboard-look",
            title: NSLocalizedString("키보드 생김새를 바꿀 수 있어요", comment: "DYK title: keyboard look"),
            body: NSLocalizedString("키 개수·높이·글자 크기·색을 취향대로 바꿀 수 있어요. 한 화면에 여덟 개를 띄우는 사람도 있습니다.", comment: "DYK body: keyboard look"),
            symbol: "keyboard",
            action: .openSettings
        ),
        DidYouKnow(
            id: "share-sheet",
            title: NSLocalizedString("다른 앱에서 바로 저장할 수 있어요", comment: "DYK title: share sheet"),
            body: NSLocalizedString("어떤 앱에서든 글을 고르고 공유에서 ClipKeyboard 를 누르면 단축어가 됩니다. 앱을 열지 않아도 돼요.", comment: "DYK body: share sheet"),
            symbol: "square.and.arrow.up"
        )
    ]
}

// MARK: - 언제 말을 거는가

/// **아직 안 한 이야기 중 다음 것**을 고르고, 말을 걸어도 되는 때인지 판단한다.
///
/// ⚠️ 이 파일에서 가장 조심스러운 부분이다. 좋은 이야기라도 아무 때나 튀어나오면
///    그건 알림이 아니라 방해다. 세 가지를 지킨다.
///
///    ① **첫날에는 말하지 않는다.** 처음 온 사람은 온보딩을 지나는 중이고, 그 위에
///       또 하나가 얹히면 둘 다 안 읽힌다.
///    ② **며칠에 한 번.** 열 때마다 새 이야기를 하면 정보가 아니라 소음이 된다.
///    ③ **다 하면 멈춘다.** 처음으로 돌아가지 않는다. 되풀이되는 순간 광고가 된다.
enum DidYouKnowScheduler {

    /// 이야기와 이야기 사이(초). 사흘.
    static let interval: TimeInterval = 3 * 24 * 60 * 60
    /// 설치하고 이만큼은 아무 말도 하지 않는다. 하루.
    static let quietAfterInstall: TimeInterval = 24 * 60 * 60

    private static var defaults: UserDefaults { .standard }
    private static let seenKey = "didYouKnow.seen.v1"
    private static let lastShownKey = "didYouKnow.lastShownAt.v1"
    private static let optOutKey = "didYouKnow.optOut.v1"

    /// 이미 본 이야기들.
    static var seen: Set<String> {
        Set(defaults.stringArray(forKey: seenKey) ?? [])
    }

    /// "이제 그만 볼게요" 를 고른 사람.
    static var isOptedOut: Bool {
        get { defaults.bool(forKey: optOutKey) }
        set { defaults.set(newValue, forKey: optOutKey) }
    }

    static var lastShownAt: Date? {
        let t = defaults.double(forKey: lastShownKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    /// 아직 안 한 이야기 중 첫 번째. 다 했으면 nil.
    static var next: DidYouKnow? {
        let done = seen
        return DidYouKnow.all.first { !done.contains($0.id) }
    }

    /// 지금 말을 걸어도 되는가 - 되면 그 이야기를, 아니면 nil.
    ///
    /// - Parameters:
    ///   - onboardingFinished: 처음 오는 길을 다 지났는가. 지나기 전에는 말하지 않는다.
    ///   - installedAt: 설치 시각. 모르면 말하지 않는다(모르는 채로 첫날에 말을 걸 수 있다).
    static func candidate(onboardingFinished: Bool,
                          installedAt: Date?,
                          now: Date = Date()) -> DidYouKnow? {
        guard !isOptedOut, onboardingFinished else { return nil }
        guard let installedAt, now.timeIntervalSince(installedAt) >= quietAfterInstall else { return nil }
        if let last = lastShownAt, now.timeIntervalSince(last) < interval { return nil }
        return next
    }

    /// 보여 줬다고 적는다.
    static func markShown(_ item: DidYouKnow, at date: Date = Date()) {
        var done = seen
        done.insert(item.id)
        defaults.set(Array(done), forKey: seenKey)
        defaults.set(date.timeIntervalSince1970, forKey: lastShownKey)
    }

    /// 처음부터 다시 - 설정의 "다시 보기" 용.
    static func resetAll() {
        defaults.removeObject(forKey: seenKey)
        defaults.removeObject(forKey: lastShownKey)
        defaults.removeObject(forKey: optOutKey)
    }
}
