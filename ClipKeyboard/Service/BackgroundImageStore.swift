//
//  BackgroundImageStore.swift
//  ClipKeyboard
//
//  목록 배경으로 **내 사진**을 쓰는 길.
//
//  왜 필요한가: 내장 배경 여덟 장 중에서만 고를 수 있었다. 배경은 취향이 가장 크게
//  갈리는 자리인데, 여덟 개 안에 자기 것이 없으면 그냥 안 쓰게 된다.
//
//  ⚠️ **App Group 에 둔다.** 앱 컨테이너에 두면 나중에 키보드나 위젯이 같은 그림을
//     쓰려 할 때 못 읽는다. 지금 쓰는 곳이 앱뿐이라도, 그림의 자리는 처음부터
//     둘 다 볼 수 있는 곳이어야 한다.
//
//  ⚠️ 저장된 값은 **에셋 이름과 한 칸에 섞여 산다**(`listBackgroundImage`).
//     그래서 내 사진에는 `user:` 를 앞에 붙여 구분한다. 접두사를 안 붙이면
//     에셋에 없는 이름이 들어왔을 때 조용히 배경이 사라진다.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

enum BackgroundImageStore {

    /// 내 사진임을 알리는 접두사.
    static let userPrefix = "user:"

    /// 배경 한 장의 긴 변 상한(px).
    ///
    /// ⚠️ 메모 이미지(1024)보다 크게 잡는다. 이건 화면을 가득 채우는 그림이라
    ///    1024 로 줄이면 최신 아이폰에서 눈에 띄게 뭉갠 티가 난다.
    ///    그렇다고 원본을 그대로 두면 App Group 이 사진첩만큼 커진다.
    static let maxDimension: CGFloat = 1600

    private static var directory: URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) else { return nil }
        return container.appendingPathComponent("Backgrounds")
    }

    /// 저장된 이름인가 - `user:` 로 시작하면 내 사진이다.
    static func isUserImage(_ name: String) -> Bool { name.hasPrefix(userPrefix) }

    private static func fileName(from stored: String) -> String {
        String(stored.dropFirst(userPrefix.count))
    }

    // MARK: - 읽기

    /// 지금 갖고 있는 내 배경들. 저장된 이름(`user:...`) 으로 돌려준다.
    ///
    /// 최근에 넣은 것이 앞에 온다 - 방금 넣은 사진을 찾으러 스크롤하지 않게.
    static func saved() -> [String] {
        guard let directory,
              let names = try? FileManager.default.contentsOfDirectory(
                atPath: directory.path) else { return [] }
        let withDates: [(String, Date)] = names.compactMap { name in
            let url = directory.appendingPathComponent(name)
            let date = (try? FileManager.default.attributesOfItem(atPath: url.path)[.creationDate]) as? Date
            return (name, date ?? .distantPast)
        }
        return withDates.sorted { $0.1 > $1.1 }.map { userPrefix + $0.0 }
    }

    #if os(iOS)
    /// 한 번 읽어 **디코드까지 마친** 그림을 들고 있는다.
    ///
    /// ⚠️ 캐시가 없으면 이 함수가 `body` 평가마다 불린다 - 탭을 넘길 때마다 1600px JPEG 를
    ///    디스크에서 다시 읽고 다시 푼다. 그 사이 첫 프레임을 놓쳐서 **배경이 한 번 사라졌다
    ///    돌아오는 것처럼** 보인다. 배경은 화면당 한 장이라 들고 있어도 값이 싸다.
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 8          // 탭마다 다른 배경을 깔아도 이 정도면 다 담긴다
        return c
    }()

    static func image(for stored: String) -> UIImage? {
        guard isUserImage(stored) else { return nil }
        if let hit = cache.object(forKey: stored as NSString) { return hit }
        guard let directory else { return nil }
        let url = directory.appendingPathComponent(fileName(from: stored))
        guard FileManager.default.fileExists(atPath: url.path),
              let loaded = UIImage(contentsOfFile: url.path) else { return nil }
        // ⚠️ `UIImage(contentsOfFile:)` 는 **그릴 때** 푼다. 여기서 미리 풀어 두지 않으면
        //    디코드가 첫 프레임의 메인 스레드에서 일어나 그 프레임을 놓친다.
        let ready = loaded.preparingForDisplay() ?? loaded
        cache.setObject(ready, forKey: stored as NSString)
        return ready
    }

    /// 곧 쓸 배경들을 미리 읽어 둔다 - 화면에 붙기 전에 캐시를 채우는 것이 목적이다.
    ///
    /// ⚠️ 배경 안 쓰는 사람에게는 아무 일도 하지 않는다(빈 이름은 그냥 건너뛴다).
    ///    에셋 배경은 `Image(name)` 이 알아서 캐시하므로 여기서 다루지 않는다.
    static func preload(_ names: [String]) {
        let targets = names.filter { isUserImage($0) && cache.object(forKey: $0 as NSString) == nil }
        guard !targets.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            for name in targets { _ = image(for: name) }
        }
    }

    /// 그림 하나를 캐시에서 뺀다 - 지운 배경을 계속 들고 있으면 안 된다.
    static func forget(_ stored: String) {
        cache.removeObject(forKey: stored as NSString)
    }

    // MARK: - 쓰기

    /// 사진 한 장을 배경으로 들인다. 저장된 이름을 돌려준다.
    ///
    /// ⚠️ 긴 변을 `maxDimension` 으로 줄이고 JPEG 로 굽는다. 배경은 뒤에 깔리는
    ///    그림이라 원본 화질이 필요하지 않고, 사진첩에서 온 원본은 한 장에 몇 MB 다.
    @discardableResult
    static func add(_ image: UIImage) -> String? {
        guard let directory else { return nil }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let resized = downscaled(image)
        guard let data = resized.jpegData(compressionQuality: 0.85) else { return nil }
        let name = "\(UUID().uuidString).jpg"
        do {
            try data.write(to: directory.appendingPathComponent(name), options: .atomic)
            print("🖼️ [BackgroundImageStore] 배경 추가: \(name) (\(data.count / 1024)KB)")
            let stored = userPrefix + name
            // 고르자마자 적용되는 자리다. 방금 손에 든 그림을 캐시에 넣어 두면
            // 화면이 다시 디스크로 갈 일이 없다.
            cache.setObject(resized.preparingForDisplay() ?? resized, forKey: stored as NSString)
            return stored
        } catch {
            print("❌ [BackgroundImageStore] 저장 실패: \(error)")
            return nil
        }
    }

    static func remove(_ stored: String) {
        guard isUserImage(stored), let directory else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName(from: stored)))
        forget(stored)
    }

    private static func downscaled(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    #endif
}

// MARK: - 그리기

#if os(iOS)
/// 배경 한 장 - **에셋이든 내 사진이든 같은 자리에서 그린다.**
///
/// ⚠️ 부르는 쪽이 둘을 구분하게 두지 않는다. 구분이 여러 곳으로 퍼지면 한 곳이
///    빠져서 "고르면 적용은 되는데 어떤 화면에서만 안 보이는" 배경이 생긴다.
struct BackgroundImageView: View {
    let name: String

    var body: some View {
        if BackgroundImageStore.isUserImage(name) {
            if let ui = BackgroundImageStore.image(for: name) {
                Image(uiImage: ui).resizable()
            } else {
                // 사진첩에서 지웠거나 파일이 사라진 경우 - 빈 화면 대신 아무것도 안 그린다.
                Color.clear
            }
        } else {
            Image(name).resizable()
        }
    }
}
#endif
