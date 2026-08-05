//
//  PixelSprite.swift
//  ClipKeyboard
//
//  8×8 픽셀 스프라이트 — **이미지 파일 없이** 배열만으로 그린다.
//
//  왜 코드로 그리나: 에셋을 쓰면 @1x/@2x/@3x 세 벌을 넣어야 하고, 다크 모드용을 또 만들어야
//  하고, 앱 용량이 늘고, 어느 배율에선 뭉갠다. 8×8 배열은 용량이 0이고 어떤 크기에서도
//  픽셀이 또렷하다(픽셀 아트는 뭉개지지 않는 게 전부다).
//
//  ⚠️ 좌표계는 왼쪽 위가 (0,0), 아래가 땅이다. 마지막 줄은 흙(k)으로 바닥을 잡아
//     스프라이트들이 같은 지면 위에 선 것처럼 보이게 한다.
//

import SwiftUI

// MARK: - 팔레트

/// 스프라이트 문자 → 색. 테마와 무관한 고정 팔레트다 —
/// 픽셀 아트는 색 수가 적고 서로의 대비로 형태를 만들어서, 테마색으로 바꾸면 형태가 무너진다.
enum PixelPalette {
    static func color(for symbol: Character) -> Color? {
        switch symbol {
        case "g": return Color(red: 0.31, green: 0.55, blue: 0.29)   // 진한 초록
        case "G": return Color(red: 0.49, green: 0.72, blue: 0.42)   // 밝은 초록
        case "y": return Color(red: 0.91, green: 0.76, blue: 0.24)   // 노랑
        case "r": return Color(red: 0.83, green: 0.34, blue: 0.29)   // 빨강(지붕·꽃)
        case "b": return Color(red: 0.55, green: 0.37, blue: 0.24)   // 나무 줄기
        case "k": return Color(red: 0.23, green: 0.18, blue: 0.14)   // 흙
        case "w": return Color(red: 0.94, green: 0.91, blue: 0.84)   // 벽
        case "s": return Color(red: 0.72, green: 0.78, blue: 0.85)   // 눈·서리
        default:  return nil                                          // "." = 투명
        }
    }
}

// MARK: - 스프라이트

struct PixelSprite: Equatable, Identifiable {
    /// 위에서 아래로 8줄, 각 줄 8글자.
    let rows: [String]
    let id: String

    static let size = 8

    /// 새싹 — 한 번이라도 쓰면 돋는다.
    static let sprout = PixelSprite(rows: [
        "........",
        "........",
        "........",
        "...g....",
        "..gGg...",
        "...g....",
        "...g....",
        "..kkk..."
    ], id: "sprout")

    /// 꽃 — 조금 익숙해진 문구.
    static let flower = PixelSprite(rows: [
        "........",
        "..yyy...",
        ".yrrry..",
        ".yrrry..",
        "..yyy...",
        "...g....",
        "..gGg...",
        "..kkk..."
    ], id: "flower")

    /// 나무 — 손에 붙은 문구.
    static let tree = PixelSprite(rows: [
        "..GGG...",
        ".GGGGG..",
        "GGGGGGG.",
        ".GGGGG..",
        "..GGG...",
        "...b....",
        "...b....",
        "..kkk..."
    ], id: "tree")

    /// 집 — 고비를 넘긴 문구.
    static let house = PixelSprite(rows: [
        "...r....",
        "..rrr...",
        ".rrrrr..",
        "rrrrrrr.",
        ".wbbbw..",
        ".wbybw..",
        ".wbbbw..",
        "..kkk..."
    ], id: "house")
}

// MARK: - 마을 계획 (순수 함수 — 테스트 가능)

enum PixelVillage {

    /// 한 카드에 세울 수 있는 스프라이트 수. 넘치면 카드가 그림밭이 된다.
    static let maxSprites = 9

    /// 몇 회부터 무엇이 되는가.
    /// 새싹 1회 · 꽃 4회 · 나무 10회 · 집 25회 — 큰 것부터 채우고 남는 만큼 작은 것을 세운다.
    /// 그래서 27회짜리 문구는 "집 한 채 + 새싹 둘"이 되어 **한눈에 규모가 읽힌다.**
    static func plan(useCount: Int) -> [PixelSprite] {
        guard useCount > 0 else { return [] }

        var remaining = useCount
        var out: [PixelSprite] = []

        func take(_ cost: Int, _ sprite: PixelSprite) {
            while remaining >= cost && out.count < maxSprites {
                out.append(sprite)
                remaining -= cost
            }
        }

        take(25, .house)
        take(10, .tree)
        take(4, .flower)
        take(1, .sprout)

        return out
    }
}

// MARK: - 렌더러

/// 스프라이트 한 줄을 그리는 뷰. Canvas 하나로 전부 그려 뷰 개수를 늘리지 않는다
/// (카드마다 사각형을 수십 개 만들면 리스트 스크롤이 무거워진다).
struct PixelSpriteStrip: View {
    let sprites: [PixelSprite]
    /// 픽셀 하나의 크기(pt). 2면 스프라이트 하나가 16pt.
    var pixel: CGFloat = 2
    /// 스프라이트 사이 간격(픽셀 단위).
    var gap: CGFloat = 1

    private var spriteWidth: CGFloat { CGFloat(PixelSprite.size) * pixel }
    private var totalWidth: CGFloat {
        guard !sprites.isEmpty else { return 0 }
        return CGFloat(sprites.count) * spriteWidth + CGFloat(sprites.count - 1) * gap * pixel
    }

    var body: some View {
        Canvas { context, _ in
            var originX: CGFloat = 0
            for sprite in sprites {
                draw(sprite, at: originX, in: &context)
                originX += spriteWidth + gap * pixel
            }
        }
        .frame(width: totalWidth, height: CGFloat(PixelSprite.size) * pixel)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ sprite: PixelSprite, at originX: CGFloat, in context: inout GraphicsContext) {
        for (y, row) in sprite.rows.enumerated() {
            for (x, symbol) in row.enumerated() {
                guard let color = PixelPalette.color(for: symbol) else { continue }
                let rect = CGRect(x: originX + CGFloat(x) * pixel,
                                  y: CGFloat(y) * pixel,
                                  width: pixel, height: pixel)
                context.fill(Path(rect), with: .color(color))
            }
        }
    }
}

/// 카드 위에 얹히는 마을. 사용 횟수가 0이면 아무것도 그리지 않는다.
struct VillageStrip: View {
    let useCount: Int
    var pixel: CGFloat = 2

    var body: some View {
        let sprites = PixelVillage.plan(useCount: useCount)
        if !sprites.isEmpty {
            PixelSpriteStrip(sprites: sprites, pixel: pixel)
        }
    }
}
