//
//  VaultSprite.swift
//  ClipKeyboard
//
//  **금고** - "타수를 저축한다"는 컨셉의 픽셀 에셋.
//
//  이 앱이 아껴주는 시간은 원래 **증거가 안 남는** 이득이다. 그래서 해지된다.
//  금고는 사라진 노동을 눈에 보이는 물건(동전·금괴)으로 바꿔서, 아꼈다가 아니라
//  **불어났다**로 프레임을 옮긴다. 문구 하나를 만드는 데 든 20초가 원금이고,
//  200번 꺼내 쓴 시간이 수익이다.
//
//  PixelSprite.swift 와 같은 규약이다 - 이미지 파일 없이 문자열 배열만으로 그린다.
//  (에셋을 쓰면 @1x/@2x/@3x + 다크 모드용을 따로 넣어야 하고, 어느 배율에선 뭉갠다.)
//
//  ⚠️ PixelSprite 와 달리 **8×8 과 16×16 을 함께 쓴다.** 카드에 얹는 잔고는 8, 화면
//     머리에 세우는 금고는 16이다. 그래서 크기를 전역 상수로 두지 않고 rows 에서 뽑는다.
//
//  ⚠️ 문자열을 손으로 고칠 때는 반드시 폭을 세어라. 한 칸만 밀려도 테두리에 계단이
//     생기는데, 길이만 맞으면 눈으로 보기 전엔 모른다. `VaultSpriteTests` 가 잡아준다.
//

import SwiftUI

// MARK: - 팔레트

/// 금고 팔레트. PixelPalette 에 없는 금속·종이 색만 정의하고 나머지는 넘긴다
/// 앱의 픽셀 언어는 하나여야 해서 마을과 금고가 같은 노랑(y)을 쓴다.
///
/// 픽셀 아트는 색 수가 적고 서로의 대비로 형태를 만든다. 그래서 테마색을 쓰지 않는다.
/// 금속은 **밝은 면(대문자) + 어두운 면(소문자) + 외곽선(x)** 세 값이면 충분히 금속으로 읽힌다.
enum VaultPalette {
    static func color(for symbol: Character) -> Color? {
        switch symbol {
        case "x": return Color(red: 0.15, green: 0.13, blue: 0.16)   // 외곽선
        case "c": return Color(red: 0.72, green: 0.42, blue: 0.22)   // 동 - 어두운 면
        case "C": return Color(red: 0.89, green: 0.62, blue: 0.36)   // 동 - 밝은 면
        case "n": return Color(red: 0.55, green: 0.60, blue: 0.66)   // 은 - 어두운 면
        case "N": return Color(red: 0.87, green: 0.90, blue: 0.93)   // 은 - 밝은 면
        case "y": return Color(red: 0.91, green: 0.76, blue: 0.24)   // 금 - 어두운 면
        case "Y": return Color(red: 1.00, green: 0.93, blue: 0.60)   // 금 - 밝은 면
        case "m": return Color(red: 0.39, green: 0.42, blue: 0.47)   // 철 - 어두운 면
        case "M": return Color(red: 0.62, green: 0.66, blue: 0.72)   // 철 - 밝은 면
        case "v": return Color(red: 0.13, green: 0.36, blue: 0.27)   // 금고 명판 진녹(브랜드)
        case "t": return Color(red: 0.10, green: 0.09, blue: 0.11)   // 금고 내부 어둠
        case "w": return Color(red: 0.94, green: 0.91, blue: 0.85)   // 종이(영수증)
        // 황동 - **밝은 유리 카드 위에 놓이는 철물 전용.**
        // 카드가 흰색이라 회색 철(m/M)을 얹으면 물건이 아니라 때처럼 보인다.
        // 금속으로 읽히게 하는 건 광택이 아니라 **색**이다.
        case "a": return Color(red: 0.47, green: 0.35, blue: 0.08)   // 황동 어두운(외곽선)
        case "b": return Color(red: 0.69, green: 0.54, blue: 0.19)   // 황동 중간
        case "B": return Color(red: 0.89, green: 0.75, blue: 0.38)   // 황동 밝은
        default:  return nil                                          // "." = 투명
        }
    }
}

// MARK: - 스프라이트

struct VaultSprite: Equatable, Identifiable {
    /// 위에서 아래로 n줄, 각 줄 n글자. 정사각형이다.
    let rows: [String]
    let id: String

    /// 한 변의 픽셀 수. 8(잔고) 또는 16(히어로).
    var size: Int { rows.count }

    // MARK: 잔고 사다리 - 카드에 얹히는 것

    /// 빈 자리 - 아직 아무것도 벌어들이지 않은 문구. 동전이 놓일 홈만 파여 있다.
    ///
    /// ⚠️ 이게 없으면 안 쓴 카드에는 **아무것도 안 그려져서** 스킨을 켠 줄도 모른다.
    ///    빈 자리는 "여기에 쌓일 것"이라는 초대이기도 하다.
    static let empty = VaultSprite(rows: [
        "..m.m...",
        ".m....m.",
        "m......m",
        "........",
        "........",
        "m......m",
        ".m....m.",
        "...m.m.."
    ], id: "empty")

    /// 동전(동) - 10초.
    static let bronze = disc(dark: "c", light: "C", id: "bronze")
    /// 은화 - 1분.
    static let silver = disc(dark: "n", light: "N", id: "silver")
    /// 금화 - 10분.
    static let gold = disc(dark: "y", light: "Y", id: "gold")

    /// 금괴 - 1시간. 동전 3종과 **실루엣이 달라야** 한눈에 규모가 읽힌다.
    /// (색만 다르면 금화가 몇 개인지 세어야 알 수 있다.)
    static let ingot = VaultSprite(rows: [
        "........",
        "...xxx..",
        "..xYYYx.",
        ".xYYYYYx",
        "xYyyyyyx",
        "xyyyyyyx",
        "xxxxxxxx",
        "........"
    ], id: "ingot")

    /// 8×8 을 꽉 채운 원. 외곽선은 가장자리 1px 만 둔다
    /// 테두리를 두껍게 두면 안이 4×4밖에 안 남아서 원이 아니라 **사각형으로 보인다.**
    private static func disc(dark: Character, light: Character, id: String) -> VaultSprite {
        let d = String(dark), l = String(light)
        return VaultSprite(rows: [
            "..xxxx..",
            ".x\(l)\(l)\(l)\(l)x.",
            "x\(l)\(l)\(l)\(l)\(l)\(l)x",
            "x\(l)\(l)\(l)\(l)\(l)\(d)x",
            "x\(l)\(l)\(l)\(d)\(d)\(d)x",
            "x\(l)\(d)\(d)\(d)\(d)\(d)x",
            ".x\(d)\(d)\(d)\(d)x.",
            "..xxxx.."
        ], id: id)
    }

    // MARK: 상태 아이콘

    /// 무료 한도 초과 = 금고가 잠긴다. 손실 회피를 그림 하나로 말한다.
    static let lock = VaultSprite(rows: [
        "..MMMM..",
        "..M..M..",
        "xxxxxxxx",
        "xYYYYYYx",
        "xYYxxYYx",
        "xYYxxYYx",
        "xYYYYYYx",
        "xxxxxxxx"
    ], id: "lock")

    /// 환급 영수증. 줄 간격이 불규칙하면 종이가 아니라 계단처럼 보인다.
    static let receipt = VaultSprite(rows: [
        ".wwwwww.",
        ".wxxxxw.",
        ".wwwwww.",
        ".wxxxxw.",
        ".wwwwww.",
        ".wvvvvw.",
        ".wwwwww.",
        ".w.w.w.."
    ], id: "receipt")

    /// 이자가 붙는 순간의 반짝임.
    static let spark = VaultSprite(rows: [
        "...Y....",
        "...Y....",
        ".Y.Y.Y..",
        "..YYY...",
        "YYYYYYY.",
        "..YYY...",
        ".Y.Y.Y..",
        "...Y...."
    ], id: "spark")

    // MARK: 카드 철물

    /// 카드 오른쪽에 박히는 황동 다이얼. **카드에 놓는 철물은 이것 하나뿐이다.**
    ///
    /// 처음에는 경첩 둘 + 다이얼을 10pt 크기로 흩어 놨는데, 흰 유리 카드 위에서
    /// 작은 회색 덩어리들이 하드웨어가 아니라 **때처럼** 보였다.
    /// 작은 것 여럿보다 잘 그린 것 하나가 낫다 - 여럿은 노이즈고 하나는 의도다.
    static let dial = VaultSprite(rows: [
        "..aaaa..",
        ".aBBBBa.",
        "aBBaaBBa",
        "aBaaaaBa",
        "aBaaaaBa",
        "aBBaaBBa",
        ".abbbba.",
        "..aaaa.."
    ], id: "dial")

    // MARK: 동전 회전 3프레임 - 붙여넣을 때 *툭* 떨어지는 모션용

    static let spin: [VaultSprite] = [gold, spinTilted, spinEdge]

    private static let spinTilted = VaultSprite(rows: [
        "...xx...",
        "..xYYx..",
        "..xYYx..",
        "..xYYx..",
        "..xYyx..",
        "..xyyx..",
        "..xyyx..",
        "...xx..."
    ], id: "spin_tilted")

    private static let spinEdge = VaultSprite(rows: [
        "...xx...",
        "...Yx...",
        "...Yx...",
        "...Yx...",
        "...yx...",
        "...yx...",
        "...yx...",
        "...xx..."
    ], id: "spin_edge")

    // MARK: 히어로 금고 (16×16)

    /// 닫힌 금고. 금고로 읽히게 하는 건 대칭이 아니라 **비대칭**이다
    /// 왼쪽 경첩 / 가운데왼쪽 다이얼 / 오른쪽 손잡이 / 아래 명판.
    /// 동심 사각형만 그리면 금고가 아니라 창틀처럼 보인다.
    static let closed = VaultSprite(rows: [
        "................",
        ".xxxxxxxxxxxxxx.",
        ".xMMMMMMMMMMMMx.",
        ".xmmmmmmmmmmmmx.",
        ".xmMMMMMMMMMMmx.",
        ".xxMMyyyMMMyMmx.",
        ".xxMyYYYyMMYMmx.",
        ".xmMyYxYyMMYMmx.",
        ".xmMyYYYyMMYMmx.",
        ".xxMMyyyMMMyMmx.",
        ".xxMMMMMMMMMMmx.",
        ".xmMMMvvvvMMMmx.",
        ".xmmmmmmmmmmmmx.",
        ".xMMMMMMMMMMMMx.",
        ".xxxxxxxxxxxxxx.",
        "..x..........x.."
    ], id: "vault_closed")

    /// 속이 빈 열린 금고 - **내용물은 따로 얹는다.**
    ///
    /// 금괴를 스프라이트에 박아 넣으면 한 푼도 안 번 사람의 금고에도 금괴가 들어 있다.
    /// 그러면 이 화면 전체가 장식이 되고, 쌓였다는 말이 거짓이 된다.
    static let openEmpty = VaultSprite(rows: [
        "................",
        "...xxxxxxxxxxxx.",
        "...xMMMMMMMMMMx.",
        "xM.xMttttttttMx.",
        "xM.xMttttttttMx.",
        "xM.xMttttttttMx.",
        "xM.xMttttttttMx.",
        "xy.xMttttttttMx.",
        "xY.xMttttttttMx.",
        "xy.xMttttttttMx.",
        "xM.xMttttttttMx.",
        "xM.xMttttttttMx.",
        "xM.xMttttttttMx.",
        "...xMMMMMMMMMMx.",
        "...xxxxxxxxxxxx.",
        "....x......x...."
    ], id: "vault_open_empty")

    /// `openEmpty` 의 내부 공간(스프라이트 칸 단위). 여기에 잔고를 얹는다.
    /// 값이 스프라이트와 어긋나면 동전이 벽을 뚫고 나온다 - 테스트가 잡는다.
    static let interior = (x: 5, y: 3, width: 8, height: 10)

    /// 열린 금고. 문이 몸통 **밖으로** 젖혀져야 열린 것으로 읽힌다
    /// 문을 몸통 안에 그리면 그냥 두꺼운 벽이 된다. 안에는 금괴 세 장.
    static let open = VaultSprite(rows: [
        "................",
        "...xxxxxxxxxxxx.",
        "...xMMMMMMMMMMx.",
        "xM.xMttttttttMx.",
        "xM.xMttttttttMx.",
        "xM.xMttYYYYttMx.",
        "xM.xMtyyyyyytMx.",
        "xy.xMttttttttMx.",
        "xY.xMttYYYYttMx.",
        "xy.xMtyyyyyytMx.",
        "xM.xMttttttttMx.",
        "xM.xMttYYYYttMx.",
        "xM.xMtyyyyyytMx.",
        "...xMMMMMMMMMMx.",
        "...xxxxxxxxxxxx.",
        "....x......x...."
    ], id: "vault_open")
}

// MARK: - 잔고 계획 (순수 함수 - 테스트 가능)

/// 절약한 시간을 **화폐 단위로** 환산한다.
///
/// 마을(PixelVillage)이 사용 횟수를 세는 것과 다르게 여기서는 **초**를 센다.
/// 금고의 값어치는 "몇 번 썼나"가 아니라 "얼마가 쌓였나"라서, 단위가 횟수면 컨셉이 죽는다.
enum VaultLedger {

    /// 한 카드에 올릴 수 있는 스프라이트 수. 넘치면 카드가 동전밭이 된다.
    static let maxSprites = 9

    /// 액면가(초). 실제 화폐처럼 배수가 고르지 않다 - 10초·1분·10분·1시간.
    static let bronzeSeconds: Double = 10
    static let silverSeconds: Double = 60
    static let goldSeconds: Double = 600
    static let ingotSeconds: Double = 3600

    /// 큰 단위부터 채우고 남는 만큼 작은 단위를 놓는다.
    /// 그래서 1시간 12분짜리 문구는 "금괴 하나 + 금화 하나 + 은화 둘"이 되어
    /// **한눈에 규모가 읽힌다.**
    /// - Parameter cap: 놓을 수 있는 최대 개수. 카드는 좁아서 9개지만
    ///   금고 화면은 넓어서 더 담을 수 있다.
    static func plan(savedSeconds: Double, cap: Int = maxSprites) -> [VaultSprite] {
        // 아직 못 번 문구도 빈 자리는 보여준다 - 아무것도 안 그리면 스킨이 켜졌는지조차 알 수 없다.
        guard savedSeconds >= bronzeSeconds else { return [.empty] }

        var remaining = savedSeconds
        var out: [VaultSprite] = []

        func take(_ worth: Double, _ sprite: VaultSprite) {
            while remaining >= worth && out.count < cap {
                out.append(sprite)
                remaining -= worth
            }
        }

        take(ingotSeconds, .ingot)
        take(goldSeconds, .gold)
        take(silverSeconds, .silver)
        take(bronzeSeconds, .bronze)

        return out
    }

    /// 가장 값나가는 액면 하나와 그 개수.
    ///
    /// 카드에는 이것만 보인다. 동전을 다 늘어놓으면 가로로 200pt가 넘는 **꽉 찬 띠**가 되어
    /// 제목과 내용 힌트를 덮는다(마을은 새싹처럼 성긴 그림이라 글이 비쳐 보였지만,
    /// 동전은 꽉 찬 원이라 글이 완전히 가려진다). 액면 하나 + 개수면 규모는 그대로 읽히고
    /// 자리는 1/5 로 줄어든다.
    static func headline(savedSeconds: Double) -> (sprite: VaultSprite, count: Int)? {
        let ladder: [(Double, VaultSprite)] = [
            (ingotSeconds, .ingot), (goldSeconds, .gold),
            (silverSeconds, .silver), (bronzeSeconds, .bronze)
        ]
        for (worth, sprite) in ladder {
            let count = Int(savedSeconds / worth)
            if count > 0 { return (sprite, count) }
        }
        return nil
    }

    /// 다음 동전 한 닢까지 얼마나 왔나(0~1).
    ///
    /// 지금 액면 기준으로 잰다 - 동전만 모으는 문구는 10초마다, 금괴를 모으는 문구는
    /// 1시간마다 차오른다. 항상 같은 단위로 재면 큰 문구는 눈금이 안 움직이고
    /// 작은 문구는 늘 가득 차 있어서, 둘 다 아무 말도 안 하게 된다.
    static func nextCoinProgress(savedSeconds: Double) -> Double {
        guard savedSeconds > 0 else { return 0 }
        let worth = ladderWorth(for: savedSeconds)
        return min(1, max(0, savedSeconds.truncatingRemainder(dividingBy: worth) / worth))
    }

    private static func ladderWorth(for seconds: Double) -> Double {
        if seconds >= ingotSeconds { return ingotSeconds }
        if seconds >= goldSeconds { return goldSeconds }
        if seconds >= silverSeconds { return silverSeconds }
        return bronzeSeconds
    }

    /// 문구 하나가 지금까지 벌어들인 시간(초).
    ///
    /// 식은 `KeyboardUsageTracker` 에 있는 하나를 그대로 쓴다 - 여기서 따로 세면
    /// 카드에 쌓인 동전과 잔고 화면 숫자가 어긋나서, 둘 중 하나는 거짓말이 된다.
    static func earnedSeconds(characterCount: Int, useCount: Int) -> Double {
        KeyboardUsageTracker.earnedSeconds(characterCount: characterCount, useCount: useCount)
    }

    /// 메모를 들고 있는 자리에서 쓰는 창구.
    ///
    /// ⚠️ 위의 글자수 창구는 **찾아오는 시간을 셀 수 없다**(값의 종류를 모르니까).
    ///    메모가 있으면 반드시 이쪽을 쓸 것 - 안 그러면 계좌번호 카드에 쌓인 동전이
    ///    사용 기록의 숫자보다 한참 적게 나온다.
    static func earnedSeconds(for memo: Memo) -> Double {
        KeyboardUsageTracker.earnedSeconds(value: memo.value,
                                           type: memo.autoDetectedType,
                                           useCount: memo.clipCount)
    }
}

// MARK: - 렌더러

/// 스프라이트 한 줄을 그리는 뷰. Canvas 하나로 전부 그려 뷰 개수를 늘리지 않는다
/// (카드마다 사각형을 수십 개 만들면 리스트 스크롤이 무거워진다).
struct VaultSpriteStrip: View {
    let sprites: [VaultSprite]
    /// 픽셀 하나의 크기(pt).
    var pixel: CGFloat = 3
    /// 스프라이트 사이 간격(픽셀 단위).
    var gap: CGFloat = 1

    private var unit: Int { sprites.first?.size ?? 8 }
    private var spriteWidth: CGFloat { CGFloat(unit) * pixel }
    private var totalWidth: CGFloat {
        guard !sprites.isEmpty else { return 0 }
        return CGFloat(sprites.count) * spriteWidth + CGFloat(sprites.count - 1) * gap * pixel
    }

    var body: some View {
        Canvas { context, _ in
            var originX: CGFloat = 0
            for sprite in sprites {
                draw(sprite, at: originX, in: &context)
                originX += CGFloat(sprite.size) * pixel + gap * pixel
            }
        }
        .frame(width: totalWidth, height: CGFloat(unit) * pixel)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ sprite: VaultSprite, at originX: CGFloat, in context: inout GraphicsContext) {
        for (y, row) in sprite.rows.enumerated() {
            for (x, symbol) in row.enumerated() {
                guard let color = VaultPalette.color(for: symbol) else { continue }
                let rect = CGRect(x: originX + CGFloat(x) * pixel,
                                  y: CGFloat(y) * pixel,
                                  width: pixel, height: pixel)
                context.fill(Path(rect), with: .color(color))
            }
        }
    }
}

/// 카드 위에 얹히는 잔고. 아직 못 번 문구에는 빈 자리만 놓인다.
struct VaultBalanceStrip: View {
    let savedSeconds: Double
    var pixel: CGFloat = 3

    var body: some View {
        VaultSpriteStrip(sprites: VaultLedger.plan(savedSeconds: savedSeconds), pixel: pixel)
    }
}

/// 단축어 카드를 **금고 문**으로 읽히게 하는 철물 - 왼쪽 경첩 둘, 오른쪽 다이얼,
/// 아래 가장자리에 다음 동전까지의 이음새.
///
/// ⚠️ 전부 **가장자리에만** 둔다. 카드 한가운데는 제목과 내용의 자리다.
///    동전을 가운데 늘어놨다가 글이 안 읽혔던 일을 반복하지 않는다.
///
/// ⚠️ Canvas **하나**로 전부 그린다. 부품마다 뷰를 만들면 카드 한 장에 일곱 개가 붙어
///    스크롤이 무거워진다(카드가 수십 장이다).
struct VaultCardFrame: View {
    let savedSeconds: Double
    /// 철물 픽셀 크기. 2.5면 다이얼이 20pt.
    ///
    /// ⚠️ 작게 만들지 마라. 10pt 로 줄였더니 흰 카드 위에서 형태가 뭉개져 얼룩이 됐다.
    ///    픽셀 아트는 작아지면 정보가 아니라 노이즈가 된다.
    var pixel: CGFloat = 2.5

    private var unit: CGFloat { CGFloat(VaultSprite.dial.size) * pixel }

    var body: some View {
        Canvas { context, size in
            // 다이얼 하나 - 오른쪽 가장자리, 세로 가운데. 제목은 왼쪽 정렬이라 여기가 비어 있다.
            draw(.dial,
                 at: CGPoint(x: size.width - 4 - unit, y: size.height / 2 - unit / 2),
                 in: &context)

            // 아래 이음새 - 다음 동전까지 차오른다.
            let track = CGRect(x: 20, y: size.height - 5, width: size.width - 40, height: 2.5)
            context.fill(Path(track), with: .color(Color(red: 0.69, green: 0.54, blue: 0.19).opacity(0.16)))
            let filled = CGRect(x: track.minX, y: track.minY,
                                width: track.width * VaultLedger.nextCoinProgress(savedSeconds: savedSeconds),
                                height: track.height)
            context.fill(Path(filled), with: .color(Color(red: 0.84, green: 0.66, blue: 0.16)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ sprite: VaultSprite, at origin: CGPoint, in context: inout GraphicsContext) {
        for (y, row) in sprite.rows.enumerated() {
            for (x, symbol) in row.enumerated() {
                guard let color = VaultPalette.color(for: symbol) else { continue }
                context.fill(Path(CGRect(x: origin.x + CGFloat(x) * pixel,
                                         y: origin.y + CGFloat(y) * pixel,
                                         width: pixel, height: pixel)),
                             with: .color(color))
            }
        }
    }
}

/// 단축어 카드 구석에 붙는 잔고 표시 - **액면 하나 + 개수**.
///
/// 동전을 늘어놓지 않는 이유는 `VaultLedger.headline` 에 적어 두었다.
/// 한 줄로 요약하면: 글을 덮지 않으려고.
struct VaultCardBadge: View {
    let savedSeconds: Double
    /// 카드 배경이 진할 때 숫자가 묻히지 않게.
    var onColor: Bool = false

    var body: some View {
        if let headline = VaultLedger.headline(savedSeconds: savedSeconds) {
            HStack(spacing: 3) {
                VaultSpriteStrip(sprites: [headline.sprite], pixel: 2, gap: 0)
                if headline.count > 1 {
                    Text("\(headline.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(onColor ? .white.opacity(0.9)
                                                 : Color(red: 0.55, green: 0.44, blue: 0.10))
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(.ultraThinMaterial)
            )
            .accessibilityHidden(true)
        }
    }
}

/// 화면 머리에 세우는 금고 한 채.
struct VaultHero: View {
    var isOpen: Bool = false
    var pixel: CGFloat = 6

    var body: some View {
        VaultSpriteStrip(sprites: [isOpen ? .open : .closed], pixel: pixel, gap: 0)
    }
}
