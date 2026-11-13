//
//  SnippetIcon.swift
//  ClipKeyboard
//
//  단축어 · 카테고리에 붙이는 아이콘 한 개. 심볼 · 이모지 · 내가 올린 그림 가운데 하나다.
//
//  왜: 사용자 요청(2026-11). 카테고리와 단축어를 이모지나 직접 올린 그림으로 알아보고 싶다.
//  예전에는 카테고리에만 SF 심볼을 고를 수 있었다(`CategoryIconSettings`).
//
//  ⚠️ 저장은 **글자 한 줄**이다. 카테고리 아이콘은 예전부터 `userCategoryIcons_v1` 에
//     심볼 이름 그대로 들어 있었으므로, 접두사가 없는 값은 심볼로 읽는다(하위 호환).
//     이모지는 `emoji:`, 그림은 `image:` 를 앞에 붙인다.
//  ⚠️ 그 사전은 키보드 · 동기화(`CategorySnapshot`)도 그대로 옮긴다. 심볼만 그릴 수 있는 곳은
//     `symbolName` 이 nil 이면 기본 심볼로 물러난다(`categorySymbol(for:in:)`).
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

enum SnippetIcon: Equatable, Hashable {
    case symbol(String)
    case emoji(String)
    /// `SnippetIconStore` 안의 파일 이름.
    case image(String)

    static let emojiPrefix = "emoji:"
    static let imagePrefix = "image:"

    /// 저장된 글자에서 읽는다. 비어 있으면 nil.
    init?(raw: String?) {
        guard let raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix(Self.emojiPrefix) {
            let value = String(raw.dropFirst(Self.emojiPrefix.count))
            guard !value.isEmpty else { return nil }
            self = .emoji(value)
        } else if raw.hasPrefix(Self.imagePrefix) {
            let value = String(raw.dropFirst(Self.imagePrefix.count))
            guard !value.isEmpty else { return nil }
            self = .image(value)
        } else {
            self = .symbol(raw)
        }
    }

    /// 저장할 글자.
    var raw: String {
        switch self {
        case .symbol(let name): return name
        case .emoji(let value): return Self.emojiPrefix + value
        case .image(let file):  return Self.imagePrefix + file
        }
    }

    /// 심볼만 그릴 수 있는 곳(메뉴 `Label`, 탭)이 쓸 이름. 심볼이 아니면 nil.
    var symbolName: String? {
        if case .symbol(let name) = self { return name }
        return nil
    }
}

// MARK: - Category Icon Lookup

/// 카테고리에 사용자가 고른 아이콘. 고른 적이 없으면 nil.
func customCategoryIcon(for category: String) -> SnippetIcon? {
    let dict = AppGroup.defaults?.dictionary(forKey: DefaultsKey.userCategoryIconsV1) as? [String: String]
    return SnippetIcon(raw: dict?[category])
}

// MARK: - Uploaded Images

/// 내가 올린 아이콘 그림들. App Group `Icons/` 에 정사각형 PNG 로 둔다.
///
/// ⚠️ 배경 사진(`BackgroundImageStore`)과 폴더를 나눈다. 쓰임새와 크기가 다르고,
///    한쪽을 정리하다 다른 쪽 그림을 지우면 안 된다.
/// ⚠️ 올린 그림은 **보관함**이다. 한 번 올리면 다른 단축어 · 카테고리에서도 다시 고를 수 있다.
///    그래서 단축어를 지워도 그림은 남는다. 지우는 것은 고르기 화면에서 사용자가 한다.
enum SnippetIconStore {

    /// 아이콘 한 장의 한 변(px). 카드에서 28pt 안팎으로 그리므로 3배 화면에도 넉넉하다.
    static let side: CGFloat = 256

    static var directory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent("Icons")
    }

    /// 갖고 있는 그림 파일 이름. 최근에 올린 것이 앞이다.
    static func saved() -> [String] {
        guard let directory,
              let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return [] }
        let dated: [(String, Date)] = names.map { name in
            let url = directory.appendingPathComponent(name)
            let date = (try? FileManager.default.attributesOfItem(atPath: url.path)[.creationDate]) as? Date
            return (name, date ?? .distantPast)
        }
        return dated.sorted { $0.1 > $1.1 }.map(\.0)
    }

    #if os(iOS)
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 64
        return c
    }()

    static func image(named file: String) -> UIImage? {
        if let hit = cache.object(forKey: file as NSString) { return hit }
        guard let directory,
              let loaded = UIImage(contentsOfFile: directory.appendingPathComponent(file).path) else { return nil }
        let ready = loaded.preparingForDisplay() ?? loaded
        cache.setObject(ready, forKey: file as NSString)
        return ready
    }

    /// 그림 한 장을 들인다. 가운데를 정사각형으로 잘라 `side` 로 줄인다. 파일 이름을 돌려준다.
    @discardableResult
    static func add(_ image: UIImage) -> String? {
        guard let directory else { return nil }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let square = squared(image)
            guard let data = square.pngData() else { return nil }
            let name = "\(UUID().uuidString).png"
            try data.write(to: directory.appendingPathComponent(name), options: .atomic)
            cache.setObject(square, forKey: name as NSString)
            print("✅ [SnippetIconStore.add] 아이콘 그림 추가: \(name) (\(data.count / 1024)KB)")
            return name
        } catch {
            print("❌ [SnippetIconStore.add] 저장 실패: \(error)")
            return nil
        }
    }

    static func remove(_ file: String) {
        guard let directory else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
        cache.removeObject(forKey: file as NSString)
    }

    private static func squared(_ image: UIImage) -> UIImage {
        let size = image.size
        let edge = min(size.width, size.height)
        let target = CGSize(width: side, height: side)
        let scale = side / max(edge, 1)
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(x: (side - drawSize.width) / 2, y: (side - drawSize.height) / 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
    #endif
}

// MARK: - Drawing

#if os(iOS)
/// 아이콘 하나를 `size` 크기 칸에 그린다. 심볼 · 이모지 · 그림을 부르는 쪽이 구분하지 않게.
struct SnippetIconView: View {
    let icon: SnippetIcon
    let size: CGFloat
    /// 심볼에 칠할 색. nil 이면 둘레 글자색을 따른다.
    var tint: Color? = nil

    var body: some View {
        content
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch icon {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: size * 0.78, weight: .semibold))
                .foregroundStyle(tint ?? .primary)
        case .emoji(let value):
            Text(value)
                .font(.system(size: size * 0.86))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        case .image(let file):
            if let ui = SnippetIconStore.image(named: file) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            } else {
                // 그림이 사라졌으면(다른 기기에서 온 카테고리 등) 아무것도 그리지 않는다.
                Color.clear
            }
        }
    }
}
#endif
