//
//  CardSurfaceEffects.swift
//  ClipKeyboard
//
//  카드 한 장의 표면 - 글자 뒤 할로, 사진 배경, 내용 힌트.
//  목록 화면 파일에 같이 살던 것을 꺼냈다. 이것들은 목록의 일부가 아니라
//  "카드는 어떻게 생겼는가" 라는 이 앱의 표면 언어라서,
//  다른 카드면에서도 그대로 쓸 수 있어야 한다.
//
//  ⚠️ `MemoCardSurface` 가 여기 있는 셋을 모두 쓴다. 예전에는 이 중 둘이 950줄짜리
//     보조 뷰 모음(`ClipKeyboardListComponents`)에 섞여 있어서, 카드 하나를 이해하려면
//     그 파일까지 열어야 했다. 카드의 표면은 카드 옆에 둔다.
//

import SwiftUI

/// 카드 글자 뒤에 까는 할로 - **필요할 때만 깐다.**
///
/// ⚠️ `color` 가 nil 이면 `compositingGroup` 째로 건너뛴다. 이게 이 뷰의 전부다.
///    할로는 유리 너머로 사진이나 카테고리 색이 비칠 때 글자를 붙잡아 주려고 있는데,
///    민 바탕(배경 사진 없음 + 무색 카드) 위에서는 테마 배경색과 **같은 색**이라
///    보이지도 않는다. 그런데 `compositingGroup` 은 카드마다 화면 밖 합성을 한 번씩
///    더 만든다 - 목록에 들어갈 때마다 카드 수만큼 공짜로 내는 값이었다.
struct CardTextHalo: ViewModifier {
    let color: Color?

    func body(content: Content) -> some View {
        if let color {
            content
                .compositingGroup()
                .shadow(color: color, radius: 4, x: 0, y: 0)
        } else {
            content
        }
    }
}

// MARK: - Memo Image Background Helper

/// 이미지 메모용 배경 뷰 - 로딩 중엔 회색 플레이스홀더, 완료 후 풀-블리드 표시
/// 이미지 단축어 카드의 배경 - 사진과, 그 위에 글자가 읽히게 하는 그늘까지 함께 그린다.
///
/// ⚠️ **사진이 오기 전에는 그늘을 얹지 않는다.** 예전에는 회색 판 위에 검은 그라디언트가
///    먼저 깔려서, 목록에 들어갈 때마다 카드가 **검게 칠해졌다가 사진으로 바뀌었다**
///    (다크 모드의 systemGray5 는 거의 검정이라 더 그렇게 보였다). 그늘은 사진을 위한
///    것이므로 사진과 운명을 같이해야 한다.
///
/// ⚠️ 한 번 읽은 사진은 캐시에 둔다. `loadImage` 는 매번 디스크에서 새로 읽어서,
///    탭을 오갈 때마다 같은 사진을 다시 읽고 그때마다 빈 자리가 한 번씩 보였다.
struct MemoImageBackground: View {
    let fileName: String

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: UIImage?

    /// 이미 읽어 둔 사진. 화면을 떠나도 남으므로 두 번째부터는 빈 자리가 없다.
    ///
    /// ⚠️ **상한을 반드시 준다.** 원본 사진은 3000x2000 이면 펼쳤을 때 24MB 쯤 되는데,
    ///    카드 하나는 140pt짜리다. 상한 없이 원본을 담아 두면 사진 스무 장에 수백 MB가
    ///    잡힌 채 시스템이 비명을 지를 때까지 안 빠진다(NSCache 는 비용을 안 알려주면
    ///    스스로 덜어내지 못한다). 그래서 **카드 크기로 줄여서** 담고, 총량도 못박는다.
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 60
        c.totalCostLimit = 32 * 1024 * 1024   // 32MB
        return c
    }()

    /// 카드에 그릴 만한 크기 - 이보다 큰 사진은 줄여서 담는다.
    /// (레티나 3배를 감안해도 카드 폭의 세 배면 넉넉하다)
    private static let thumbnailMaxPixel: CGFloat = 600

    var body: some View {
        ZStack {
            // 사진이 오기 전 자리 - 카드 표면색. 배경과 같은 계열이라 튀지 않는다.
            theme.surface
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                // 글자가 읽히도록 사진 위아래에 그늘 - **사진이 있을 때만.**
                LinearGradient(
                    colors: [.black.opacity(0.15), .clear, .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Image(systemName: AppSymbol.photo)
                    .font(.title3)
                    .foregroundColor(theme.textFaint)
            }
        }
        .clipped()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: image != nil)
        .onAppear(perform: load)
    }

    /// 카드에 필요한 만큼으로 줄인다. 이미 작으면 그대로 쓴다.
    private static func downsized(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > thumbnailMaxPixel else { return image }
        let scale = thumbnailMaxPixel / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return image.preparingThumbnail(of: target) ?? image
    }

    /// 캐시가 스스로 덜어낼 수 있도록 알려 주는 대략의 크기(바이트).
    private static func byteCost(_ image: UIImage) -> Int {
        let pixels = image.size.width * image.scale * image.size.height * image.scale
        return Int(pixels * 4)
    }

    private func load() {
        guard image == nil, !fileName.isEmpty else { return }
        // 캐시에 있으면 **그릴 때 바로** 얹는다 - 비동기로 미루면 빈 자리가 한 프레임 보인다.
        if let cached = Self.cache.object(forKey: fileName as NSString) {
            image = cached
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let loaded = MemoStore.shared.loadImage(fileName: fileName) else {
                DispatchQueue.main.async { image = nil }
                return
            }
            let shrunk = Self.downsized(loaded)
            Self.cache.setObject(shrunk, forKey: fileName as NSString, cost: Self.byteCost(shrunk))
            DispatchQueue.main.async { image = shrunk }
        }
    }
}

// MARK: - Content Hint (카드 속 은은한 내용 힌트)

/// 메모 카드 제목 아래의 내용 힌트 - 카드가 화면에 나타나고 2초쯤 머물면 그제야
/// 블러가 걷히며 살며시 맺혔다가(materialize), 잠시 머문 뒤 흩어지듯 사라진다(dissolve).
/// 사라진 뒤에도 4~10초 쉬었다가 다시 맺힌다 - 앱을 켜둔 동안 주기적으로 반복.
/// 카드(seed)마다 등장 시점·머무는 시간·휴식이 조금씩 달라 화면 전체가 동시에
/// 깜빡이지 않고, 하나둘 차례로 맺혔다 제각각 흩어진다.
struct ContentHintPreview: View {
    let text: String
    /// 카드별 위상 시드(메모 id 해시) - 등장 지연·머묾 시간에 결정적 편차를 준다.
    let seed: Int
    /// 컬러 카드(이미지·카테고리색) 위인지 - 텍스트 색 결정.
    let onColor: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 카드 높이 균일성을 위해 항상 이 높이를 차지한다(힌트가 없는 동안은 빈 공간).
    /// .body 한 줄이 들어가는 높이.
    static let zoneHeight: CGFloat = 22

    /// 최소 2초는 머문 뒤에야 맺히기 시작한다(바닥값) - 여기에 카드별 편차가 더해진다.
    static let baseRevealDelay: Double = 2.0
    /// 맺힘/흩어짐 전환 시간.
    static let fadeDuration: Double = 0.9

    /// 등장 지연 2.0~3.6s - 카드들이 하나둘 차례로 맺힌다.
    private var revealDelay: Double { Self.baseRevealDelay + unit(0) * 1.6 }
    /// 머묾 3.6~5.4s - 먼저 맺힌 힌트가 꼭 먼저 사라지진 않도록 제각각.
    private var holdDuration: Double { 3.6 + unit(1) * 1.8 }
    /// 흩어진 뒤 휴식 4~10s - 쉬었다가 다시 맺힌다(주기 반복).
    private var restDuration: Double { 4.0 + unit(2) * 6.0 }

    /// seed에서 뽑은 결정적 0..<1 (salt로 서로 독립적인 값) - 같은 카드는 항상 같은 리듬.
    private func unit(_ salt: UInt64) -> Double {
        var h = UInt64(bitPattern: Int64(seed)) &+ (salt &+ 1) &* 0x9E3779B97F4A7C15
        h ^= h >> 33
        h = h &* 0xFF51AFD7ED558CCD
        h ^= h >> 33
        return Double(h % 1024) / 1024.0
    }

    /// 빈 공간 → 맺힘 → (머묾) → 흩어짐 → 휴식 → 다시 맺힘… 의 반복.
    private enum Stage {
        case waiting    // 빈 공간 (첫 대기·휴식 구간 - 다음 맺힘은 3pt 아래에서 시작)
        case shown      // 또렷하게 읽히는 구간
        case gone       // 흩어지는 중 (살짝 떠오르며 블러 속으로)
    }

    @State private var stage: Stage = .waiting
    @Environment(\.appTheme) private var theme

    var body: some View {
        // ⚠️ 원문을 그대로 그리면 `{이름}` 이 중괄호째 나온다.
        //    미리보기 문자열은 `isTemplate` 일 때만 중괄호를 벗기는데, 값에 `{}` 가 있어도
        //    templateVariables 가 비면 isTemplate 이 false 라 그 손질을 못 받는다.
        //    "플레이스홀더는 어디서든 하이라이트로 보인다"는 규칙을 여기서도 지킨다.
        Text(text.templateAwareAttributed(theme: theme, font: .body))
            .font(.body)
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundColor(onColor ? .white.opacity(0.85) : .secondary)
            .opacity(stage == .shown ? 1 : 0)
            .blur(radius: reduceMotion || stage == .shown ? 0 : 4)
            .offset(y: reduceMotion ? 0 : rise)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Self.zoneHeight)
            .allowsHitTesting(false)        // 탭은 카드로 통과
            .accessibilityHidden(true)      // VoiceOver는 카드 라벨이 안내 (일시 표시 요소 제외)
            .task {
                // 카드가 화면을 벗어나면 task가 취소되고, 다시 나타나면 처음부터 시작된다.
                stage = .waiting
                do {
                    try await Task.sleep(for: .seconds(revealDelay))
                    while !Task.isCancelled {
                        withAnimation(.easeInOut(duration: Self.fadeDuration)) { stage = .shown }
                        try await Task.sleep(for: .seconds(Self.fadeDuration + holdDuration))
                        withAnimation(.easeInOut(duration: Self.fadeDuration)) { stage = .gone }
                        try await Task.sleep(for: .seconds(Self.fadeDuration))
                        stage = .waiting   // 보이지 않는 동안 시작 위치로 (애니메이션 없음)
                        try await Task.sleep(for: .seconds(restDuration))
                    }
                } catch { /* 화면 이탈로 취소 - 다음 등장 때 다시 */ }
            }
    }

    /// 맺힘은 3pt 아래에서 자리로 떠오르고, 흩어짐은 2pt 위로 떠오르며 사라진다.
    private var rise: CGFloat {
        switch stage {
        case .waiting: return 3
        case .shown:   return 0
        case .gone:    return -2
        }
    }
}
