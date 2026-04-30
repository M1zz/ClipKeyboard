//
//  ShareViewController.swift
//  ClipKeyboardShareExtension
//
//  iOS Share Sheet에서 텍스트를 받아 ClipKeyboard 메모로 빠르게 저장.
//  메인 앱과 App Group을 공유해 MemoStore 파일에 직접 append.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers

@objc(ShareViewController)
class ShareViewController: UIViewController {

    private var sharedText: String = ""
    private var detectedTitle: String = ""
    private var detectedCategory: String = "기본"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        loadSharedItem()
    }

    private func loadSharedItem() {
        guard let item = (extensionContext?.inputItems as? [NSExtensionItem])?.first,
              let providers = item.attachments else {
            presentSheet()
            return
        }

        // text/plain or URL 처리
        let textType = UTType.plainText.identifier
        let urlType = UTType.url.identifier
        let group = DispatchGroup()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(textType) {
                group.enter()
                provider.loadItem(forTypeIdentifier: textType, options: nil) { [weak self] item, _ in
                    if let str = item as? String {
                        self?.sharedText = str
                    }
                    group.leave()
                }
            } else if provider.hasItemConformingToTypeIdentifier(urlType) {
                group.enter()
                provider.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] item, _ in
                    if let url = item as? URL {
                        self?.sharedText = url.absoluteString
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.computeDefaults()
            self?.presentSheet()
        }
    }

    private func computeDefaults() {
        // 자동 분류 (간단 — 풀 분류기는 메인 앱에 있음, 익스텐션에선 가벼운 휴리스틱만)
        let s = sharedText
        if s.contains("@") && s.contains(".") { detectedCategory = "이메일"; detectedTitle = "Email" }
        else if s.lowercased().hasPrefix("http") { detectedCategory = "URL"; detectedTitle = "URL" }
        else if s.range(of: #"^[A-Z]{2}\d{2}[A-Z0-9]{10,30}$"#, options: .regularExpression) != nil {
            detectedCategory = "IBAN"; detectedTitle = "IBAN"
        }
        else {
            detectedCategory = "기본"
            let firstLine = s.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? s
            detectedTitle = firstLine.count <= 30 ? firstLine : String(firstLine.prefix(27)) + "…"
        }
    }

    private func presentSheet() {
        let host = UIHostingController(
            rootView: ShareSaveView(
                text: sharedText,
                initialTitle: detectedTitle,
                category: detectedCategory,
                onSave: { [weak self] title, value in
                    self?.saveMemo(title: title, value: value)
                },
                onCancel: { [weak self] in
                    self?.cancel()
                }
            )
        )
        host.modalPresentationStyle = .formSheet
        present(host, animated: true)
    }

    private func saveMemo(title: String, value: String) {
        let appGroup = "group.com.Ysoup.TokenMemo"
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            cancel()
            return
        }
        let memoURL = containerURL.appendingPathComponent("memos.data")

        // 기존 메모 로드 (실패해도 빈 배열로 시작)
        var memos: [[String: Any]] = []
        if let data = try? Data(contentsOf: memoURL),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            memos = decoded
        }

        // 새 메모 추가 — Memo struct와 동일한 키 구조 사용
        let now = Date()
        let formatter = ISO8601DateFormatter()
        let iso = formatter.string(from: now)
        let newMemo: [String: Any] = [
            "id": UUID().uuidString,
            "title": title,
            "value": value,
            "isChecked": false,
            "lastEdited": iso,
            "isFavorite": false,
            "category": detectedCategory,
            "isSecure": false,
            "isTemplate": false,
            "templateVariables": [],
            "placeholderValues": [:] as [String: Any],
            "isCombo": false,
            "comboValues": [],
            "currentComboIndex": 0,
            "imageFileNames": [],
            "contentType": "text"
        ]
        memos.append(newMemo)

        // 저장 — JSONSerialization으로 직렬화. JSONEncoder는 Date를 다르게 처리해서 직접 JSON dict 사용.
        if let data = try? JSONSerialization.data(withJSONObject: memos, options: []) {
            try? data.write(to: memoURL)
        }

        // 메인 앱에게 데이터 변경 알림
        UserDefaults(suiteName: appGroup)?.set(Date().timeIntervalSince1970, forKey: "share.lastSavedAt")

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func cancel() {
        let cancelError = NSError(domain: "ClipKeyboardShareCancel", code: 0, userInfo: nil)
        extensionContext?.cancelRequest(withError: cancelError)
    }
}

// MARK: - SwiftUI sheet

private struct ShareSaveView: View {
    let text: String
    @State var title: String
    let category: String
    let onSave: (String, String) -> Void
    let onCancel: () -> Void

    init(text: String, initialTitle: String, category: String,
         onSave: @escaping (String, String) -> Void,
         onCancel: @escaping () -> Void) {
        self.text = text
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
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(8)
                }
                Section {
                    HStack {
                        Image(systemName: "tag")
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("Category", comment: "Category"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(category)
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Save to ClipKeyboard", comment: "Share extension title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "Cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Save", comment: "Save")) {
                        onSave(title.isEmpty ? String(text.prefix(20)) : title, text)
                    }
                    .fontWeight(.semibold)
                    .disabled(text.isEmpty)
                }
            }
        }
    }
}
