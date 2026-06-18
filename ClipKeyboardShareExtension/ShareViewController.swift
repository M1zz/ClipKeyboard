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
                provider.loadItem(forTypeIdentifier: imageType, options: nil) { [weak self] item, _ in
                    defer { group.leave() }
                    if let image = item as? UIImage {
                        self?.sharedImages.append(image)
                    } else if let url = item as? URL,
                              let data = try? Data(contentsOf: url),
                              let image = UIImage(data: data) {
                        self?.sharedImages.append(image)
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
        if !sharedImages.isEmpty {
            detectedTitle = NSLocalizedString("Image", comment: "Default title for image memo")
            return
        }
        let s = sharedText
        if s.contains("@") && s.contains(".") {
            detectedCategory = "이메일"
            detectedTitle = "Email"
        } else if s.lowercased().hasPrefix("http") {
            detectedCategory = "URL"
            detectedTitle = "URL"
        } else if s.range(of: #"^[A-Z]{2}\d{2}[A-Z0-9]{10,30}$"#, options: .regularExpression) != nil {
            detectedCategory = "IBAN"
            detectedTitle = "IBAN"
        } else {
            detectedCategory = "기본"
            let firstLine = s.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? s
            detectedTitle = firstLine.count <= 30 ? firstLine : String(firstLine.prefix(27)) + "…"
        }
    }

    private func presentSheet() {
        let host = UIHostingController(
            rootView: ShareSaveView(
                text: sharedText,
                images: sharedImages,
                initialTitle: detectedTitle,
                category: detectedCategory,
                onSave: { [weak self] title, value in
                    self?.saveToInbox(title: title, value: value)
                },
                onCancel: { [weak self] in
                    self?.cancel()
                }
            )
        )
        host.modalPresentationStyle = .formSheet
        present(host, animated: true)
    }

    /// 공유받은 항목을 빠른 메모(Inbox) 보관함에 보류 저장한다.
    /// 정식 메모로 바로 만들지 않고, 사용자가 메인 앱에서 "메모로 저장"을 결정하게 한다.
    ///
    /// ⚠️ 스키마는 메인 앱의 `QuickNote` Codable 과 정확히 일치해야 한다(키/타입):
    ///    - `createdAt` 은 epoch 초(Double)
    ///    - `contentType` 은 ClipboardContentType rawValue("text"/"image"/"mixed")
    ///    하드코딩 문자열은 앱 코드를 공유하지 않는 익스텐션 타겟이라 불가피하다.
    private func saveToInbox(title: String, value: String) {
        let appGroup = "group.com.Ysoup.TokenMemo"
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            cancel()
            return
        }
        let inboxURL = containerURL.appendingPathComponent("quicknotes.data")

        var notes: [[String: Any]] = []
        if let data = try? Data(contentsOf: inboxURL),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            notes = decoded
        }

        let id = UUID().uuidString

        var imageFileNames: [String] = []
        if !sharedImages.isEmpty {
            let imagesDir = containerURL.appendingPathComponent("Images")
            try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

            for (index, image) in sharedImages.enumerated() {
                let fileName = index == 0 ? "\(id).jpg" : "\(id)_\(index).jpg"
                let fileURL = imagesDir.appendingPathComponent(fileName)
                let resized = resized(image, maxDimension: 1024)
                if let data = resized.jpegData(compressionQuality: 0.7) {
                    try? data.write(to: fileURL)
                    imageFileNames.append(fileName)
                }
            }
        }

        let hasImages = !imageFileNames.isEmpty
        let hasText = !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let contentType = hasImages ? (hasText ? "mixed" : "image") : "text"

        let newNote: [String: Any] = [
            "id": id,
            "text": value,
            "imageFileNames": imageFileNames,
            "contentType": contentType,
            "createdAt": Date().timeIntervalSince1970,
            "source": "share",
            "suggestedTitle": title,
            "suggestedCategory": detectedCategory
        ]
        notes.append(newNote)

        if let data = try? JSONSerialization.data(withJSONObject: notes, options: []) {
            try? data.write(to: inboxURL)
        }

        UserDefaults(suiteName: appGroup)?.set(Date().timeIntervalSince1970, forKey: "quicknote.lastSavedAt")

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "ClipKeyboardShareCancel", code: 0))
    }
}

// MARK: - SwiftUI sheet

private struct ShareSaveView: View {
    let text: String
    let images: [UIImage]
    @State var title: String
    let category: String
    let onSave: (String, String) -> Void
    let onCancel: () -> Void

    private var isImageShare: Bool { !images.isEmpty }
    private var canSave: Bool { isImageShare || !text.isEmpty }

    init(text: String, images: [UIImage], initialTitle: String, category: String,
         onSave: @escaping (String, String) -> Void,
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
                    HStack {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("Saved to Inbox", comment: "Destination label in share sheet"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(category)
                            .foregroundColor(.primary)
                    }
                } footer: {
                    Text(NSLocalizedString("It's kept in your inbox so you can decide later whether to save it as a keyboard memo.", comment: "Share sheet inbox explanation"))
                }
            }
            .navigationTitle(NSLocalizedString("Add to Inbox", comment: "Share extension title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "Cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Save", comment: "Save")) {
                        onSave(title, text)
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
