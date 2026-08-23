//
//  StoryShare.swift
//  ClipKeyboard
//
//  만든 그림·영상을 **인스타그램 스토리로 곧장** 올린다.
//
//  왜 공유 시트가 아니라 곧장인가
//  ⚠️ 공유 시트를 거치면 목록에서 인스타그램을 찾고 → 스토리인지 게시물인지 고르고 →
//     편집 화면까지 가야 한다. 그 사이에 대부분 그만둔다. 자랑은 **마음먹은 그 순간**에
//     끝나야 하는 일이라, 버튼 하나로 스토리 편집기까지 데려간다.
//
//  ⚠️ 그래도 공유 시트를 없애지는 않는다. 인스타그램을 안 깔았거나 다른 데로 보내려는
//     사람이 반드시 있다. 곧장 가는 길은 **하나 더 생긴 길**이지 대체가 아니다.
//
//  어떻게 동작하나 (Meta 가 정한 방식이다)
//   ① 붙임판(UIPasteboard)에 약속된 키로 그림이나 영상을 올려 둔다
//   ② `instagram-stories://share?source_application=...` 를 연다
//   ③ 인스타그램이 붙임판에서 그걸 꺼내 스토리 편집기에 얹는다
//
//  ⚠️ 붙임판에 **만료 시각을 반드시 건다.** 안 걸면 우리가 올린 그림이 사용자의 붙임판에
//     계속 남는다. 남의 붙임판에 우리 물건을 두고 오는 짓은 하지 않는다.
//
//  ⚠️ `LSApplicationQueriesSchemes` 에 `instagram-stories` 가 있어야 `canOpenURL` 이
//     참을 돌려준다. 없으면 인스타그램이 깔려 있어도 **없는 것으로 보인다.**
//     (ClipKeyboard-Info.plist 에 넣어 두었다)
//
//  ⚠️ `source_application` 은 Meta 문서상 **페이스북 앱 ID** 다. 아직 발급받은 것이
//     없어서 번들 ID 로 대신하고 있고, 그래서 인스타그램 버전에 따라 거절될 수 있다.
//     Info.plist 에 `FacebookAppID` 를 넣으면 그 값을 먼저 쓴다 - 발급받으면 코드를
//     고칠 것 없이 그 키만 채우면 된다.
//

import Foundation
#if canImport(UIKit)
import UIKit

enum StoryShare {

    /// 스토리 규격. 9:16 이 아니면 사용자가 올릴 때 잘라야 하고, 잘라야 하면 대개 안 올린다.
    static let canvasSize = CGSize(width: 1080, height: 1920)

    /// 붙임판에 올려 둔 것이 살아 있는 시간(초). 인스타그램이 건너가 읽을 만큼만.
    private static let pasteboardLifetime: TimeInterval = 5 * 60

    private static let storyScheme = "instagram-stories"

    // MARK: - 열 수 있는가

    /// 인스타그램으로 곧장 갈 수 있는가. 아니면 버튼을 아예 안 보여준다
    /// (눌러서 아무 일도 안 일어나는 버튼이 가장 나쁘다).
    static var isInstagramAvailable: Bool {
        guard let url = shareURL else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    private static var shareURL: URL? {
        var components = URLComponents()
        components.scheme = storyScheme
        components.host = "share"
        components.queryItems = [URLQueryItem(name: "source_application", value: sourceApplication)]
        return components.url
    }

    /// Meta 가 요구하는 보내는 앱 표시. 페이스북 앱 ID 가 있으면 그것을, 없으면 번들 ID 를 쓴다.
    private static var sourceApplication: String {
        let bundle = Bundle.main
        if let appID = bundle.object(forInfoDictionaryKey: "FacebookAppID") as? String,
           !appID.trimmingCharacters(in: .whitespaces).isEmpty {
            return appID
        }
        return bundle.bundleIdentifier ?? "com.Ysoup.TokenMemo"
    }

    // MARK: - 보내기

    /// 그림 한 장을 스토리 배경으로 올린다.
    ///
    /// - Returns: 인스타그램을 열었으면 true. false 면 **호출한 쪽이 공유 시트로 물러서야 한다.**
    @discardableResult
    static func shareToInstagram(image: UIImage) -> Bool {
        // PNG 다. 영수증은 글자와 가는 선이 전부라 JPEG 로 구우면 글자 둘레가 지저분해진다.
        guard let data = image.pngData() else { return false }
        return open(items: ["com.instagram.sharedSticker.backgroundImage": data])
    }

    /// 영상 한 편을 스토리 배경으로 올린다.
    @discardableResult
    static func shareToInstagram(videoURL: URL) -> Bool {
        guard let data = try? Data(contentsOf: videoURL) else { return false }
        return open(items: ["com.instagram.sharedSticker.backgroundVideo": data])
    }

    private static func open(items: [String: Any]) -> Bool {
        guard let url = shareURL, UIApplication.shared.canOpenURL(url) else { return false }

        // ⚠️ 만료 시각을 같이 건다. 안 걸면 우리가 올린 것이 사용자의 붙임판에 그대로 남는다.
        UIPasteboard.general.setItems(
            [items],
            options: [.expirationDate: Date().addingTimeInterval(pasteboardLifetime)]
        )
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return true
    }
}
#endif
