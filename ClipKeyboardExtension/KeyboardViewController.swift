//
// KeyboardViewController.swift
// TokenKeyboard
//
// Created by hyunho lee on 2023/05/24.
//

import UIKit
import SwiftUI

typealias KeyboardData = [String:String]
// var displayKeyboardData: KeyboardData = [:]
var clipKey: [String] = []
var clipValue: [String] = []
var clipMemoId: [UUID] = []  // 메모 ID 저장
var clipMemos: [Memo] = []  // 전체 메모 객체 저장
var tappedIndex = 2
var clipboardData: KeyboardData = [:]
var tokenMemoData: KeyboardData = [:]

class KeyboardViewController: UIInputViewController {
    @IBOutlet var nextKeyboardButton: UIButton!

    private var deleteTimer: Timer?
    private var deleteStartTime: Date?
    private var notificationTokens: [NSObjectProtocol] = []

    private let flowLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 0
        return layout
    }()
    
    private lazy var customCollectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        view.isScrollEnabled = true
        view.showsHorizontalScrollIndicator = true
        view.showsVerticalScrollIndicator = false
        view.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        view.contentInset = .zero
        view.backgroundColor = .systemGray5
        view.clipsToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let backButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        button.widthAnchor.constraint(equalToConstant: 45).isActive = true
        button.layer.cornerRadius = 8
        button.setImage(UIImage(systemName: "delete.backward"), for: .normal)
        button.tintColor = .black
        button.backgroundColor = .systemGray2
        button.setTitleColor(.black, for: .normal)
        return button
    }()
    
    private let globeKeyboardButton: UIButton = {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: 38).isActive = true
            button.widthAnchor.constraint(equalToConstant: 45).isActive = true
            button.layer.cornerRadius = 8
            button.setImage(UIImage(systemName: "globe"), for: .normal)
            button.tintColor = .black
            button.backgroundColor = .systemGray2
            return button
        }()
    
    let spaceButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        button.layer.cornerRadius = 8
        button.setTitle("Space", for: UIControl.State.normal)
        button.titleLabel!.font = .systemFont(ofSize: 14, weight: .medium)
        button.backgroundColor = UIColor.white
        button.setTitleColor(UIColor.black, for: UIControl.State.normal)
        return button
    }()
    
    let returnButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        button.widthAnchor.constraint(equalToConstant: 65).isActive = true
        button.layer.cornerRadius = 8
        button.setTitle(NSLocalizedString("Return", comment: "Return key"), for: UIControl.State.normal)
        button.titleLabel!.font = .systemFont(ofSize: 13, weight: .medium)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(UIColor.white, for: UIControl.State.normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        return button
    }()

    let textField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.borderStyle = .roundedRect
        textField.placeholder = "Enter text"
        return textField
    }()
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
    }
    
    private func configureNextKeyboardButton() {
        self.nextKeyboardButton = UIButton(type: .system)
        self.nextKeyboardButton.setTitle(NSLocalizedString("Next Keyboard", comment: "Title for 'Next Keyboard' button"), for: [])
        self.nextKeyboardButton.sizeToFit()
        self.nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        
        self.nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        
        self.view.addSubview(self.nextKeyboardButton)
        
        self.nextKeyboardButton.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        self.nextKeyboardButton.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
    }
    
    private let keyboardView = KeyboardView()
    private var hostingController: UIHostingController<KeyboardView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHeightConstraint()
        configureNextKeyboardButton()
        loadMemos()
        setupNotificationObservers()

        let bottomView = setupHostingController()
        setupBottomBarLayout(bottomView)

        print("✅ viewDidLoad 완료!")
        print("- bottomView가 추가되었습니다")
        print("- spaceButton, backButton, returnButton이 추가되었습니다")
    }

    /// 키보드 익스텐션 잠금 오버레이.
    /// - 메인 앱 열기 버튼은 tokenMemo://paywall URL scheme으로 paywall로 직행.
    private func presentKeyboardLockOverlay() {
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.98)

        let lockIcon = UIImageView(image: UIImage(systemName: "lock.fill"))
        lockIcon.tintColor = .systemBlue
        lockIcon.contentMode = .scaleAspectFit
        lockIcon.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = NSLocalizedString("Unlock keyboard in ClipKeyboard", comment: "Keyboard locked title")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textAlignment = .center
        title.numberOfLines = 0
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = NSLocalizedString("Open the main app to upgrade.", comment: "Keyboard locked subtitle")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabel
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let openButton = UIButton(type: .system)
        openButton.setTitle(NSLocalizedString("Open App", comment: "Open main app button"), for: .normal)
        openButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        openButton.backgroundColor = .systemBlue
        openButton.setTitleColor(.white, for: .normal)
        openButton.layer.cornerRadius = 10
        openButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
        openButton.addTarget(self, action: #selector(openMainAppPaywall), for: .touchUpInside)
        openButton.translatesAutoresizingMaskIntoConstraints = false

        overlay.addSubview(lockIcon)
        overlay.addSubview(title)
        overlay.addSubview(subtitle)
        overlay.addSubview(openButton)
        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            lockIcon.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            lockIcon.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 32),
            lockIcon.widthAnchor.constraint(equalToConstant: 32),
            lockIcon.heightAnchor.constraint(equalToConstant: 32),

            title.topAnchor.constraint(equalTo: lockIcon.bottomAnchor, constant: 10),
            title.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 24),
            title.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -24),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            subtitle.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 24),
            subtitle.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -24),

            openButton.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 16),
            openButton.centerXAnchor.constraint(equalTo: overlay.centerXAnchor)
        ])
    }

    @objc private func openMainAppPaywall() {
        guard let url = URL(string: "clipkeyboard://paywall") else { return }
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            // iOS 18+: use openURL(_:) via extensionContext selector chain fallback
            let selector = sel_registerName("openURL:")
            if current.responds(to: selector) {
                _ = current.perform(selector, with: url)
                return
            }
            responder = current.next
        }
        print("⚠️ [Keyboard] Paywall URL scheme 실행 실패")
    }

    // MARK: - viewDidLoad Helpers

    private func setupHeightConstraint() {
        let keyboardHeight: CGFloat = 254  // SwiftUI 영역(200) + 하단 바(54)
        let heightConstraint = view.heightAnchor.constraint(equalToConstant: keyboardHeight)
        heightConstraint.priority = .defaultHigh
        heightConstraint.isActive = true
    }

    /// SwiftUI KeyboardView를 호스팅하고, 하단 bottomView를 생성하여 반환
    private func setupHostingController() -> UIView {
        let hostingVC = UIHostingController(rootView: keyboardView)
        self.hostingController = hostingVC
        addChild(hostingVC)

        let myKeyboardView = hostingVC.view!
        myKeyboardView.translatesAutoresizingMaskIntoConstraints = false
        myKeyboardView.backgroundColor = .clear
        myKeyboardView.clipsToBounds = true
        view.addSubview(myKeyboardView)
        hostingVC.didMove(toParent: self)
        view.backgroundColor = .clear

        let bottomView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 30))
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        bottomView.backgroundColor = .clear
        view.addSubview(bottomView)

        NSLayoutConstraint.activate([
            myKeyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            myKeyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            myKeyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            myKeyboardView.bottomAnchor.constraint(equalTo: bottomView.topAnchor),
            bottomView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomView.leftAnchor.constraint(equalTo: view.leftAnchor),
            bottomView.rightAnchor.constraint(equalTo: view.rightAnchor),
            bottomView.heightAnchor.constraint(equalToConstant: 54)
        ])

        return bottomView
    }

    private func setupBottomBarLayout(_ bottomView: UIView) {
        bottomView.addSubview(globeKeyboardButton)
        globeKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        globeKeyboardButton.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor, constant: 8).isActive = true
        globeKeyboardButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor).isActive = true
        globeKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        bottomView.addSubview(spaceButton)
        spaceButton.translatesAutoresizingMaskIntoConstraints = false
        spaceButton.leadingAnchor.constraint(equalTo: globeKeyboardButton.trailingAnchor, constant: 8).isActive = true
        spaceButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor).isActive = true
        spaceButton.addTarget(self, action: #selector(spacePressed), for: .touchUpInside)

        bottomView.addSubview(backButton)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.leadingAnchor.constraint(equalTo: spaceButton.trailingAnchor, constant: 6).isActive = true
        backButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor).isActive = true
        backButton.addTarget(self, action: #selector(backSpacePressed), for: .touchUpInside)

        bottomView.addSubview(returnButton)
        returnButton.translatesAutoresizingMaskIntoConstraints = false
        returnButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 6).isActive = true
        returnButton.trailingAnchor.constraint(equalTo: bottomView.trailingAnchor, constant: -8).isActive = true
        returnButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor).isActive = true
        returnButton.addTarget(self, action: #selector(returnPressed), for: .touchUpInside)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(KeyboardViewController.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.3
        longPress.numberOfTouchesRequired = 1
        longPress.allowableMovement = 10
        backButton.addGestureRecognizer(longPress)
    }

    private func setupNotificationObservers() {
        let t1 = NotificationCenter.default.addObserver(forName: NSNotification.Name("filterChanged"), object: nil, queue: nil) { [weak self] _ in
            self?.loadMemos()
        }
        let t2 = NotificationCenter.default.addObserver(forName: NSNotification.Name("addTextEntry"), object: nil, queue: nil) { [weak self] notification in
            self?.handleAddTextEntry(notification)
        }
        let t3 = NotificationCenter.default.addObserver(forName: NSNotification.Name("templateInputComplete"), object: nil, queue: .main) { [weak self] notification in
            self?.handleTemplateInputComplete(notification)
        }
        let t4 = NotificationCenter.default.addObserver(forName: NSNotification.Name("openMainAppPaywall"), object: nil, queue: .main) { [weak self] _ in
            self?.openMainAppPaywall()
        }
        notificationTokens = [t1, t2, t3, t4]
    }

    private func handleAddTextEntry(_ notification: Notification) {
        print("🔔 addTextEntry 알림 수신")
        guard let text = notification.object as? String,
              let userInfo = notification.userInfo,
              let memoId = userInfo["memoId"] as? UUID else {
            print("❌ 텍스트 또는 메모 ID가 없습니다")
            return
        }

        print("📝 텍스트: \(text)")
        print("🆔 메모 ID: \(memoId)")

        if handleComboMemoIfNeeded(text: text, memoId: memoId) { return }

        let customPlaceholders = extractCustomPlaceholders(from: text)
        print("🔍 발견된 커스텀 플레이스홀더: \(customPlaceholders)")

        if !customPlaceholders.isEmpty {
            print("✅ 템플릿 입력 오버레이 표시")
            NotificationCenter.default.post(
                name: NSNotification.Name("showTemplateInput"),
                object: nil,
                userInfo: ["text": text, "placeholders": customPlaceholders, "memoId": memoId]
            )
        } else {
            print("⚡ 자동 변수만 치환해서 바로 입력")
            let processedText = processTemplateVariables(in: text)
            print("💬 입력할 텍스트: \(processedText)")
            textDocumentProxy.insertText(processedText)
            trackKeyboardPaste(memoId: memoId)
        }
    }

    /// Combo 메모인 경우 현재 인덱스 값을 입력하고 인덱스를 순환시킴
    /// - Returns: Combo 처리를 했으면 true
    private func handleComboMemoIfNeeded(text: String, memoId: UUID) -> Bool {
        guard let memoIndex = clipMemos.firstIndex(where: { $0.id == memoId }) else { return false }
        var memo = clipMemos[memoIndex]
        guard memo.isCombo && !memo.comboValues.isEmpty else { return false }

        let currentValue = memo.comboValues[memo.currentComboIndex]
        print("🔄 Combo 메모 - 현재 인덱스: \(memo.currentComboIndex), 전체: \(memo.comboValues.count)개")
        print("✅ Combo 값 입력: [\(memo.currentComboIndex + 1)/\(memo.comboValues.count)] \(currentValue)")

        textDocumentProxy.insertText(currentValue)
        trackKeyboardPaste(memoId: memoId)

        memo.currentComboIndex = (memo.currentComboIndex + 1) % memo.comboValues.count
        clipMemos[memoIndex] = memo
        print("   다음 인덱스: \(memo.currentComboIndex)")

        do {
            var allMemos = try MemoStore.shared.load(type: .tokenMemo)
            if let fileIndex = allMemos.firstIndex(where: { $0.id == memoId }) {
                allMemos[fileIndex].currentComboIndex = memo.currentComboIndex
                try MemoStore.shared.save(memos: allMemos, type: .tokenMemo)
                print("   💾 인덱스 저장 완료")
            }
        } catch {
            print("   ❌ 인덱스 저장 실패: \(error)")
        }

        return true
    }

    private func handleTemplateInputComplete(_ notification: Notification) {
        print("✅ templateInputComplete 수신")
        guard let userInfo = notification.userInfo,
              let text = userInfo["text"] as? String,
              let inputs = userInfo["inputs"] as? [String: String] else { return }

        let memoId = userInfo["memoId"] as? UUID

        var processedText = text
        print("   원본 텍스트: \(processedText)")

        for (placeholder, value) in inputs {
            print("   [\(placeholder)] -> [\(value)]")
            processedText = processedText.replacingOccurrences(of: placeholder, with: value)
        }

        processedText = processTemplateVariables(in: processedText)
        print("   최종 텍스트: \(processedText)")
        print("📝 textDocumentProxy.insertText 호출")
        textDocumentProxy.insertText(processedText)
        trackKeyboardPaste(memoId: memoId)
        print("✅ 입력 완료!")
    }

    @objc func spacePressed(button: UIButton) {
        print("⌨️ Space 버튼이 눌렸습니다!")
        (textDocumentProxy as UIKeyInput).insertText(" ")
    }

    @objc func returnPressed(button: UIButton) {
        print("↩️ Return 버튼이 눌렸습니다!")
        (textDocumentProxy as UIKeyInput).insertText("\n")
    }

    @objc private func handleLongPress(_ gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == .began {
            deleteStartTime = Date()
            // 즉시 첫 삭제 실행
            textDocumentProxy.deleteBackward()
            // 타이머 시작 (0.1초마다 삭제, 1초 이후에는 단어 단위로 삭제)
            deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                let elapsed = Date().timeIntervalSince(self.deleteStartTime ?? Date())
                if elapsed >= 1.0 {
                    self.deleteWordBackward()
                } else {
                    self.textDocumentProxy.deleteBackward()
                }
            }
        } else if gestureRecognizer.state == .ended || gestureRecognizer.state == .cancelled {
            // 손가락을 떼면 타이머 중지
            deleteTimer?.invalidate()
            deleteTimer = nil
            deleteStartTime = nil
        }
    }

    /// 커서 앞의 공백/줄바꿈과 단어 하나를 한 번에 삭제
    private func deleteWordBackward() {
        guard let context = textDocumentProxy.documentContextBeforeInput, !context.isEmpty else {
            textDocumentProxy.deleteBackward()
            return
        }

        var charsToDelete = 0
        var sawNonWhitespace = false
        for character in context.reversed() {
            let isBoundary = character.isWhitespace || character.isNewline
            if sawNonWhitespace && isBoundary {
                break
            }
            if !isBoundary {
                sawNonWhitespace = true
            }
            charsToDelete += 1
        }

        if charsToDelete == 0 {
            charsToDelete = 1
        }

        for _ in 0..<charsToDelete {
            textDocumentProxy.deleteBackward()
        }
    }

    @objc private func backSpacePressed(button: UIButton) {
        print("⬅️ Backspace 버튼이 눌렸습니다!")
        (textDocumentProxy as UIKeyInput).deleteBackward()
    }

    /// 키보드에서 메모 붙여넣기 시 App Group UserDefaults에 카운트 기록
    /// 메인 앱의 ReviewManager가 이 값을 동기화하여 리뷰 요청 트리거로 사용
    /// memoId가 주어지면 해당 메모의 clipCount + lastUsedAt도 업데이트한다.
    private func trackKeyboardPaste(memoId: UUID? = nil) {
        if let groupDefaults = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo") {
            let count = groupDefaults.integer(forKey: "keyboard_paste_count") + 1
            groupDefaults.set(count, forKey: "keyboard_paste_count")
            print("📊 [Keyboard] 붙여넣기 카운트: \(count)")
        }

        if let memoId {
            do {
                try MemoStore.shared.incrementClipCount(for: memoId)
            } catch {
                print("⚠️ [Keyboard] 사용량 업데이트 실패: \(error)")
            }
        }
    }

    deinit {
        deleteTimer?.invalidate()
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    override func viewWillLayoutSubviews() {
        self.nextKeyboardButton.isHidden = true //!self.needsInputModeSwitchKey
        super.viewWillLayoutSubviews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 레이아웃을 미리 계산하여 튀는 현상 방지
        view.layoutIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 뷰가 완전히 나타난 후 한 번 더 레이아웃 업데이트
        view.layoutIfNeeded()
    }
    
    override func textWillChange(_ textInput: UITextInput?) {
        
    }
    
    override func textDidChange(_ textInput: UITextInput?) {
        var textColor: UIColor
        let proxy = self.textDocumentProxy
        if proxy.keyboardAppearance == UIKeyboardAppearance.dark {
            textColor = UIColor.white
        } else {
            textColor = UIColor.black
        }
        self.nextKeyboardButton.setTitleColor(textColor, for: [])
    }
    
    private func loadMemos() {
        do {
            let allMemos = try MemoStore.shared.load(type: .tokenMemo)
            print("📱 [KeyboardViewController.loadMemos] 메모 로드 완료 - 총 \(allMemos.count)개")

            let filtered = filterExcludedMemos(allMemos)
            let userFiltered = applyUserFilter(filtered)
            let sorted = sortMemos(userFiltered)

            populateKeyboardData(sorted)
            buildTokenMemoData(sorted)
        } catch {
            print("❌ Error loading memos: \(error.localizedDescription)")
        }
    }

    /// 키보드에서 사용 불가한 메모(보안) 제외
    private func filterExcludedMemos(_ memos: [Memo]) -> [Memo] {
        var result = memos
        let secureCount = result.filter { $0.isSecure }.count
        result = result.filter { !$0.isSecure }
        if secureCount > 0 {
            print("   🔐 보안 메모 \(secureCount)개 제외됨 (키보드에서는 접근 불가)")
        }
        return result
    }

    /// 사용자 선택 필터(테마/템플릿/즐겨찾기) 적용
    private func applyUserFilter(_ memos: [Memo]) -> [Memo] {
        if let theme = selectedTheme {
            let result = memos.filter { $0.category == theme }
            print("   🏷️ 테마 필터 적용 (\(theme)) - \(result.count)개")
            return result
        } else if showOnlyTemplates {
            let result = memos.filter { $0.isTemplate }
            print("   🔍 템플릿 필터 적용 - \(result.count)개")
            return result
        } else if showOnlyFavorites {
            let result = memos.filter { $0.isFavorite }
            print("   ⭐ 즐겨찾기 필터 적용 - \(result.count)개")
            return result
        }
        return memos
    }

    /// clipKey/clipValue/clipMemoId/clipMemos 배열 채우기
    private func populateKeyboardData(_ memos: [Memo]) {
        clipKey = []
        clipValue = []
        clipMemoId = []
        clipMemos = []

        print("\n📋 [KeyboardViewController] 불러온 메모 상세 정보:")
        for (index, item) in memos.enumerated() {
            print("   [\(index)] =====================================")
            print("       ID: \(item.id)")
            print("       제목: \(item.title)")
            print("       값: \(item.value)")
            print("       카테고리: \(item.category)")
            print("       즐겨찾기: \(item.isFavorite)")
            print("       템플릿: \(item.isTemplate)")
            print("       보안: \(item.isSecure)")
            print("       수정일: \(item.lastEdited)")
            print("       사용횟수: \(item.clipCount)")
            print("       템플릿 변수: \(item.templateVariables)")
            print("       📦 플레이스홀더 값:")
            if item.placeholderValues.isEmpty {
                print("           (비어있음)")
            } else {
                for (placeholder, values) in item.placeholderValues {
                    print("           \(placeholder): \(values)")
                }
            }
            print("   ========================================\n")

            clipKey.append(item.title)
            clipValue.append(item.value)
            clipMemoId.append(item.id)
            clipMemos.append(item)
        }
        print("✅ [KeyboardViewController] clipMemos 배열에 \(clipMemos.count)개 저장 완료\n")
    }

    /// tokenMemoData 딕셔너리 채우기
    private func buildTokenMemoData(_ memos: [Memo]) {
        for item in memos {
            tokenMemoData[item.title] = item.value
        }
    }

    private func sortMemos(_ memos: [Memo]) -> [Memo] {
        return memos.sorted { (memo1, memo2) -> Bool in
            if memo1.isFavorite != memo2.isFavorite {
                return memo1.isFavorite && !memo2.isFavorite
            } else {
                return memo1.lastEdited > memo2.lastEdited
            }
        }
    }

    // 템플릿 관련 함수들
    private func extractCustomPlaceholders(from text: String) -> [String] {
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var placeholders: [String] = []

        for match in matches {
            if let range = Range(match.range, in: text) {
                let placeholder = String(text[range])
                if !TemplateVariableProcessor.autoVariableTokens.contains(placeholder) && !placeholders.contains(placeholder) {
                    placeholders.append(placeholder)
                }
            }
        }

        return placeholders
    }

    private func processTemplateVariables(in text: String) -> String {
        TemplateVariableProcessor.process(text)
    }

}

//extension KeyboardViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
//    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        return clipKey.count
//    }
//    
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
//        return 10
//    }
//    
//    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//        guard let cell = customCollectionView.dequeueReusableCell(withReuseIdentifier: "cellIdentifier", for: indexPath) as? CollectionViewCell else {
//            return CollectionViewCell()
//        }
//        cell.setTitle(clipKey[indexPath.row])
//        cell.delegate = self
//        
//        return cell
//    }
//    
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
//        let label = UILabel(frame: .zero)
//        label.text = clipKey[indexPath.row]
//        label.sizeToFit()
//        
//        if label.frame.width > 150 {
//            return CGSize(width: 150, height: 40)
//        } else {
//            return CGSize(width: label.frame.width + 20, height: 40)
//        }
//    }
//}

extension KeyboardViewController: TextInput {
    func tapped(text: String, memoId: UUID) {
        print("📱 [KeyboardViewController] 메모 터치됨 - ID: \(memoId)")
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "addTextEntry"), object: text, userInfo: ["memoId": memoId])
    }
}

extension String {
    func textSize() -> CGFloat {
        let font: UIFont = UIFont(name: "Helvetica", size: 15) ?? .systemFont(ofSize: 15)
        return self.size(withAttributes: [NSAttributedString.Key.font: font]).width
    }
}


final class EmptyListView: UIView {
    
    init() {
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // Create the image view
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "eyes")
        imageView.contentMode = .scaleAspectFit
        
        // Create the title label
        let titleLabel = UILabel()
        titleLabel.text = "Nothing to Paste"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.textAlignment = .center
        
        // Create the body label
        let bodyLabel = UILabel()
        bodyLabel.text = Constants.emptyDescription
        bodyLabel.font = UIFont.systemFont(ofSize: 16)
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0
        bodyLabel.textColor = UIColor.black.withAlphaComponent(0.7)
        
        // Create a vertical stack view
        let stackView = UIStackView(arrangedSubviews: [imageView, titleLabel, bodyLabel])
        stackView.axis = .vertical
        stackView.spacing = 5
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        // Constraints for the stack view
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 30),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30)
        ])
        
        // Constraints for the image view
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: 45),
            imageView.widthAnchor.constraint(equalToConstant: 45)
        ])
    }
}


extension UIView {
    func addKeyboardSubview(_ subview: UIView) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subview)
        NSLayoutConstraint.activate([
            subview.leftAnchor.constraint(equalTo: leftAnchor),
            subview.rightAnchor.constraint(equalTo: rightAnchor),
            subview.topAnchor.constraint(equalTo: topAnchor),
            subview.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
