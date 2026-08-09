//
//  ShareViewController.swift
//  ClipKeyboardShareExtension
//
//  iOS Share Sheet에서 이미지/텍스트/URL 받아 ClipKeyboard 메모로 빠르게 저장.
//  메인 앱과 App Group을 공유해 MemoStore 파일에 직접 append.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers
import os

/// 익스텐션은 print가 Console에 안 잡힘 — Console.app에서
/// subsystem:com.Ysoup.TokenMemo.share 필터로 확인.
private let shareLog = Logger(subsystem: "com.Ysoup.TokenMemo.share", category: "share")

@objc(ShareViewController)
class ShareViewController: UIViewController {

    private var sharedText: String = ""
    private var sharedImages: [UIImage] = []
    private var detectedTitle: String = ""
    private var detectedCategory: String = "기본"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        loadSharedItems()
    }

    private func loadSharedItems() {
        guard let item = (extensionContext?.inputItems as? [NSExtensionItem])?.first,
              let providers = item.attachments else {
            presentSheet()
            return
        }

        let imageType = UTType.image.identifier
        let textType = UTType.plainText.identifier
        let urlType = UTType.url.identifier
        let group = DispatchGroup()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(imageType) {
                group.enter()
                provider.loadItem(forTypeIdentifier: imageType, options: nil) { [weak self] item, error in
                    defer { group.leave() }
                    if let image = item as? UIImage {
                        self?.sharedImages.append(image)
                    } else if let url = item as? URL,
                              let data = try? Data(contentsOf: url),
                              let image = UIImage(data: data) {
                        self?.sharedImages.append(image)
                    } else if let data = item as? Data,
                              let image = UIImage(data: data) {
                        // 일부 앱(스크린샷 공유 등)은 이미지를 Data로 넘긴다.
                        self?.sharedImages.append(image)
                    } else {
                        shareLog.error("📤 [Share] 이미지 로드 실패: item=\(String(describing: type(of: item))), error=\(String(describing: error))")
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(textType) {
                group.enter()
                provider.loadItem(forTypeIdentifier: textType, options: nil) { [weak self] item, _ in
                    defer { group.leave() }
                    if let str = item as? String {
                        self?.sharedText = str
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(urlType) {
                group.enter()
                provider.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] item, _ in
                    defer { group.leave() }
                    if let url = item as? URL {
                        self?.sharedText = url.absoluteString
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.computeDefaults()
            self?.presentSheet()
        }
    }

    private func computeDefaults() {
        // 판정 규칙은 동작 확장과 **같은 곳**에 있다 — 두 곳이 다르게 이름 지으면 안 된다.
        let detected = QuickShortcutSave.detect(text: sharedText, hasImages: !sharedImages.isEmpty)
        detectedTitle = detected.title
        detectedCategory = detected.category
    }

    private func presentSheet() {
        let host = UIHostingController(
            rootView: ShareSaveView(
                text: sharedText,
                images: sharedImages,
                initialTitle: detectedTitle,
                category: detectedCategory,
                onSave: { [weak self] title, value, destination in
                    switch destination {
                    case .shortcut: self?.saveAsShortcut(title: title, value: value)
                    case .inbox:    self?.saveToInbox(title: title, value: value)
                    }
                },
                onCancel: { [weak self] in
                    self?.cancel()
                }
            )
        )
        host.modalPresentationStyle = .formSheet
        present(host, animated: true)
    }

    /// 바로 쓸 수 있는 단축어로 저장 — 실제 쓰기는 `QuickShortcutSave` 가 한다.
    private func saveAsShortcut(title: String, value: String) {
        let outcome = QuickShortcutSave.saveAsShortcut(title: title, value: value,
                                                       category: detectedCategory, images: sharedImages)
        finish(outcome)
    }

    /// 나중에 정하도록 보관함에 담는다.
    private func saveToInbox(title: String, value: String) {
        let outcome = QuickShortcutSave.saveToInbox(title: title, value: value,
                                                    category: detectedCategory, images: sharedImages)
        finish(outcome)
    }

    private func finish(_ outcome: QuickShortcutSave.Outcome) {
        guard outcome != .failed else {
            shareLog.error("📤 [Share] 저장 실패 — 시트를 닫지 않는다")
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "ClipKeyboardShareCancel", code: 0))
    }
}

// MARK: - SwiftUI sheet

/// 공유받은 것을 어디에 둘까.
enum ShareDestination: String, CaseIterable, Identifiable {
    /// **기본값.** 바로 쓸 수 있는 단축어 — 키보드에 곧장 올라온다.
    case shortcut
    /// 나중에 정하기 — 보관함에 두고 앱에서 추린다.
    case inbox

    var id: String { rawValue }

    var label: String {
        switch self {
        case .shortcut: return NSLocalizedString("단축어", comment: "Share destination: save as a shortcut right away")
        case .inbox:    return NSLocalizedString("보관함", comment: "Share destination: keep in the inbox for later")
        }
    }

    var explanation: String {
        switch self {
        case .shortcut:
            return NSLocalizedString("바로 키보드에 올라와요. 다른 앱에서 곧장 꺼내 쓸 수 있어요.",
                                     comment: "Share destination explanation: shortcut")
        case .inbox:
            return NSLocalizedString("보관함에 담아 둬요. 나중에 앱에서 단축어로 만들지 정하면 돼요.",
                                     comment: "Share destination explanation: inbox")
        }
    }
}

private struct ShareSaveView: View {
    let text: String
    let images: [UIImage]
    @State var title: String
    let category: String
    let onSave: (String, String, ShareDestination) -> Void
    let onCancel: () -> Void

    /// ⚠️ 기본은 **단축어**다. 사파리에서 계좌번호를 잡아 공유한 사람은 그걸 쓰려고 온 것이지
    ///    나중에 추리려고 온 것이 아니다. 예전에는 무조건 보관함이라, 앱에 들어가
    ///    "메모로 저장"을 한 번 더 눌러야 했다.
    @State private var destination: ShareDestination = .shortcut

    private var isImageShare: Bool { !images.isEmpty }
    private var canSave: Bool { isImageShare || !text.isEmpty }

    init(text: String, images: [UIImage], initialTitle: String, category: String,
         onSave: @escaping (String, String, ShareDestination) -> Void,
         onCancel: @escaping () -> Void) {
        self.text = text
        self.images = images
        self._title = State(initialValue: initialTitle)
        self.category = category
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("Title", comment: "Title field")) {
                    TextField(NSLocalizedString("Title", comment: "Title field"), text: $title)
                }

                Section(NSLocalizedString("Content", comment: "Content section")) {
                    if isImageShare {
                        imagePreview
                    } else {
                        Text(text)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(8)
                    }
                }

                Section {
                    Picker(NSLocalizedString("어디에 담을까요?", comment: "Share sheet: destination picker"),
                           selection: $destination) {
                        ForEach(ShareDestination.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Image(systemName: destination == .shortcut ? "keyboard" : "tray.and.arrow.down.fill")
                            .foregroundColor(.secondary)
                        Text(destination.explanation)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer(minLength: 0)
                    }

                    HStack {
                        Text(NSLocalizedString("분류", comment: "Share sheet: detected category label"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(category)
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("ClipKeyboard에 담기", comment: "Share extension title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "Cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Save", comment: "Save")) {
                        onSave(title, text, destination)
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if images.count == 1 {
            Image(uiImage: images[0])
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .cornerRadius(8)
                .padding(.vertical, 4)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(images.indices, id: \.self) { i in
                        Image(uiImage: images[i])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipped()
                            .cornerRadius(8)
                    }
                }
                .padding(.vertical, 4)
            }
            Text(String(format: NSLocalizedString("%d images", comment: "Image count label"), images.count))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
