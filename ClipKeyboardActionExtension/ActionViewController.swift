//
//  ActionViewController.swift
//  ClipKeyboardActionExtension
//
//  공유 시트 **아래쪽 목록**(동작)에 뜨는 한 줄 - 누르면 화면 없이 그 자리에서 단축어가 된다.
//
//  왜 따로 있는가: 공유 확장(`com.apple.share-services`)은 시트 **윗줄(앱)** 에만 나온다.
//  아래 목록에 나오려면 동작 확장(`com.apple.ui-services`)이 별도로 있어야 한다.
//  같은 시트인데 자리가 둘로 나뉘어 있고, 사용자는 자기가 자주 보는 자리에서 찾는다.
//
//  ⚠️ **화면을 띄우지 않는다.** 윗줄의 공유 확장은 제목을 고치고 보관함/단축어를 고르는
//     자리이고, 이쪽은 "그냥 넣어 둬"를 한 번에 끝내는 자리다. 둘 다 시트를 띄우면
//     굳이 둘일 이유가 없다.
//
//  ⚠️ 저장 로직을 여기 두지 않는다 - `Shared/QuickShortcutSave.swift` 하나만 스키마를 안다.
//     확장마다 한 벌씩 두면 한쪽만 고쳐지는 날이 반드시 온다.
//

import UIKit
import UniformTypeIdentifiers
import os

private let actionLog = Logger(subsystem: "com.Ysoup.TokenMemo.share", category: "action")

@objc(ActionViewController)
class ActionViewController: UIViewController {

    private var text: String = ""
    private var images: [UIImage] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        // 화면이 없다 - 시트가 그대로 닫히고 저장만 일어난다.
        view.backgroundColor = .clear
        loadInput()
    }

    private func loadInput() {
        guard let item = (extensionContext?.inputItems as? [NSExtensionItem])?.first,
              let providers = item.attachments else {
            finish()
            return
        }

        let imageType = UTType.image.identifier
        let textType = UTType.plainText.identifier
        let urlType = UTType.url.identifier
        let group = DispatchGroup()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(imageType) {
                group.enter()
                provider.loadItem(forTypeIdentifier: imageType, options: nil) { [weak self] item, _ in
                    defer { group.leave() }
                    if let image = item as? UIImage {
                        self?.images.append(image)
                    } else if let url = item as? URL,
                              let data = try? Data(contentsOf: url),
                              let image = UIImage(data: data) {
                        self?.images.append(image)
                    } else if let data = item as? Data, let image = UIImage(data: data) {
                        self?.images.append(image)
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(textType) {
                group.enter()
                provider.loadItem(forTypeIdentifier: textType, options: nil) { [weak self] item, _ in
                    defer { group.leave() }
                    if let str = item as? String { self?.text = str }
                }
            } else if provider.hasItemConformingToTypeIdentifier(urlType) {
                group.enter()
                provider.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] item, _ in
                    defer { group.leave() }
                    if let url = item as? URL { self?.text = url.absoluteString }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in self?.save() }
    }

    private func save() {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasText || !images.isEmpty else {
            actionLog.info("🎬 [Action] 담을 것이 없다")
            finish()
            return
        }

        // 제목·분류 판정은 공유 확장과 같은 규칙을 쓴다.
        let detected = QuickShortcutSave.detect(text: text, hasImages: !images.isEmpty)
        let outcome = QuickShortcutSave.saveAsShortcut(title: detected.title,
                                                       value: text,
                                                       category: detected.category,
                                                       images: images)
        actionLog.info("🎬 [Action] 저장 결과 \(String(describing: outcome), privacy: .public)")

        // 화면이 없으니 성공을 알릴 곳이 진동뿐이다.
        UINotificationFeedbackGenerator().notificationOccurred(outcome == .failed ? .error : .success)
        finish()
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
