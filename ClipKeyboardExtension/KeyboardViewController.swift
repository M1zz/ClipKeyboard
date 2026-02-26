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

        // 키보드 전체 높이 제약 (시스템 너비 관리를 유지하면서 높이만 제어)
        let keyboardHeight: CGFloat = 254  // SwiftUI 영역(200) + 하단 바(54)
        let heightConstraint = view.heightAnchor.constraint(equalToConstant: keyboardHeight)
        heightConstraint.priority = .defaultHigh
        heightConstraint.isActive = true

        configureNextKeyboardButton()

        loadMemos()

        // 필터 변경 알림 구독
        NotificationCenter.default.addObserver(forName: NSNotification.Name("filterChanged"), object: nil, queue: nil) { [weak self] _ in
            self?.loadMemos()
        }
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
        let bottomView = UIView(frame: CGRect.init(x: 0, y: 0, width: 320, height: 30))
        view.addSubview(bottomView)

        myKeyboardView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        myKeyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        myKeyboardView.bottomAnchor.constraint(equalTo: bottomView.topAnchor).isActive = true
        myKeyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "addTextEntry"), object: nil, queue: nil) { notification in
            print("🔔 addTextEntry 알림 수신")
            if let text = notification.object as? String,
               let userInfo = notification.userInfo,
               let memoId = userInfo["memoId"] as? UUID {
                print("📝 텍스트: \(text)")
                print("🆔 메모 ID: \(memoId)")

                // 해당 메모 찾기
                if let memoIndex = clipMemos.firstIndex(where: { $0.id == memoId }) {
                    var memo = clipMemos[memoIndex]

                    // Combo 메모인 경우
                    if memo.isCombo && !memo.comboValues.isEmpty {
                        print("🔄 Combo 메모 - 현재 인덱스: \(memo.currentComboIndex), 전체: \(memo.comboValues.count)개")

                        // 현재 인덱스의 값 가져오기
                        let currentValue = memo.comboValues[memo.currentComboIndex]
                        print("✅ Combo 값 입력: [\(memo.currentComboIndex + 1)/\(memo.comboValues.count)] \(currentValue)")

                        // 입력
                        self.textDocumentProxy.insertText(currentValue)
                        self.trackKeyboardPaste()

                        // 다음 인덱스로 이동 (순환)
                        memo.currentComboIndex = (memo.currentComboIndex + 1) % memo.comboValues.count
                        print("   다음 인덱스: \(memo.currentComboIndex)")

                        // 메모리에 업데이트
                        clipMemos[memoIndex] = memo

                        // 파일에도 저장
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

                        return
                    }
                }

                // 일반 메모 또는 템플릿 처리
                // 커스텀 플레이스홀더 확인
                let customPlaceholders = self.extractCustomPlaceholders(from: text)
                print("🔍 발견된 커스텀 플레이스홀더: \(customPlaceholders)")

                if !customPlaceholders.isEmpty {
                    print("✅ 템플릿 입력 오버레이 표시")
                    // 커스텀 오버레이 표시 (메모 ID 포함)
                    NotificationCenter.default.post(
                        name: NSNotification.Name("showTemplateInput"),
                        object: nil,
                        userInfo: [
                            "text": text,
                            "placeholders": customPlaceholders,
                            "memoId": memoId
                        ]
                    )
                } else {
                    print("⚡ 자동 변수만 치환해서 바로 입력")
                    // 플레이스홀더가 없으면 자동 변수만 치환해서 바로 입력
                    let processedText = self.processTemplateVariables(in: text)
                    print("💬 입력할 텍스트: \(processedText)")
                    self.textDocumentProxy.insertText(processedText)
                    self.trackKeyboardPaste()
                }
            } else {
                print("❌ 텍스트 또는 메모 ID가 없습니다")
            }
        }

        // 템플릿 입력 완료 알림 구독
        NotificationCenter.default.addObserver(forName: NSNotification.Name("templateInputComplete"), object: nil, queue: .main) { notification in
            print("✅ templateInputComplete 수신")
            if let userInfo = notification.userInfo,
               let text = userInfo["text"] as? String,
               let inputs = userInfo["inputs"] as? [String: String] {

                var processedText = text
                print("   원본 텍스트: \(processedText)")

                // 커스텀 플레이스홀더 치환
                for (placeholder, value) in inputs {
                    print("   [\(placeholder)] -> [\(value)]")
                    processedText = processedText.replacingOccurrences(of: placeholder, with: value)
                }

                // 자동 변수도 치환
                processedText = self.processTemplateVariables(in: processedText)
                print("   최종 텍스트: \(processedText)")

                print("📝 textDocumentProxy.insertText 호출")
                self.textDocumentProxy.insertText(processedText)
                self.trackKeyboardPaste()
                print("✅ 입력 완료!")
            }
        }
        
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        bottomView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        bottomView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        bottomView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        bottomView.heightAnchor.constraint(equalToConstant: 54).isActive = true

        // 투명한 배경
        bottomView.backgroundColor = .clear
        
        
//        #if os(iOS)
//        bottomView.addSubview(addButton)
//        addButton.translatesAutoresizingMaskIntoConstraints = false
//        addButton.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor).isActive = true
//        addButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor).isActive = true
//        addButton.addTarget(self, action: #selector(openAppPressed), for: .touchUpInside)
//        #else
//        
//        #endif
//        if UIDevice.current.userInterfaceIdiom == .pad {
//            bottomView.addSubview(globeKeyboardButton)
//            globeKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
//            globeKeyboardButton.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor).isActive = true
//            globeKeyboardButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor).isActive = true
//            globeKeyboardButton.widthAnchor.constraint(equalToConstant: 70).isActive = true
//            globeKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
//            
//            bottomView.addSubview(addButton)
//            addButton.translatesAutoresizingMaskIntoConstraints = false
//            addButton.leadingAnchor.constraint(equalTo: globeKeyboardButton.trailingAnchor).isActive = true
//            addButton.centerYAnchor.constraint(equalTo: bottomView.centerYAnchor).isActive = true
//            addButton.addTarget(self, action: #selector(openAppPressed), for: .touchUpInside)
//        }
        
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

        print("✅ viewDidLoad 완료!")
        print("- bottomView가 추가되었습니다")
        print("- spaceButton, backButton, returnButton이 추가되었습니다")
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
            // 즉시 첫 삭제 실행
            textDocumentProxy.deleteBackward()
            // 타이머 시작 (0.1초마다 삭제)
            deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.textDocumentProxy.deleteBackward()
            }
        } else if gestureRecognizer.state == .ended || gestureRecognizer.state == .cancelled {
            // 손가락을 떼면 타이머 중지
            deleteTimer?.invalidate()
            deleteTimer = nil
        }
    }

    @objc private func backSpacePressed(button: UIButton) {
        print("⬅️ Backspace 버튼이 눌렸습니다!")
        (textDocumentProxy as UIKeyInput).deleteBackward()
    }

    /// 키보드에서 메모 붙여넣기 시 App Group UserDefaults에 카운트 기록
    /// 메인 앱의 ReviewManager가 이 값을 동기화하여 리뷰 요청 트리거로 사용
    private func trackKeyboardPaste() {
        guard let groupDefaults = UserDefaults(suiteName: "group.com.Ysoup.TokenMemo") else { return }
        let count = groupDefaults.integer(forKey: "keyboard_paste_count") + 1
        groupDefaults.set(count, forKey: "keyboard_paste_count")
        print("📊 [Keyboard] 붙여넣기 카운트: \(count)")
    }

    deinit {
        deleteTimer?.invalidate()
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
            var temp = try MemoStore.shared.load(type: .tokenMemo)

            print("📱 [KeyboardViewController.loadMemos] 메모 로드 완료 - 총 \(temp.count)개")

            // 🔒 보안 메모 제외 (키보드 익스텐션에서는 Face ID 사용 불가)
            let secureCount = temp.filter { $0.isSecure }.count
            temp = temp.filter { !$0.isSecure }
            if secureCount > 0 {
                print("   🔐 보안 메모 \(secureCount)개 제외됨 (키보드에서는 접근 불가)")
            }

            // 🖼️ 이미지 메모 제외 (키보드에서는 직접 입력 불가)
            let imageCount = temp.filter { $0.contentType == .image || $0.contentType == .mixed }.count
            temp = temp.filter { $0.contentType == .text }
            if imageCount > 0 {
                print("   🖼️ 이미지 메모 \(imageCount)개 제외됨 (키보드에서는 직접 입력 불가)")
            }

            // 필터 적용
            if let theme = selectedTheme {
                temp = temp.filter { $0.category == theme }
                print("   🏷️ 테마 필터 적용 (\(theme)) - \(temp.count)개")
            } else if showOnlyTemplates {
                temp = temp.filter { $0.isTemplate }
                print("   🔍 템플릿 필터 적용 - \(temp.count)개")
            } else if showOnlyFavorites {
                temp = temp.filter { $0.isFavorite }
                print("   ⭐ 즐겨찾기 필터 적용 - \(temp.count)개")
            }

            temp = sortMemos(temp)
            clipKey = []
            clipValue = []
            clipMemoId = []
            clipMemos = []

            print("\n📋 [KeyboardViewController] 불러온 메모 상세 정보:")
            for (index, item) in temp.enumerated() {
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

            var tempDic: [String:String] = [:]
            for item in temp {
                tempDic[item.title] = item.value
                tokenMemoData[item.title] = item.value
            }
        } catch {
            print("❌ Error loading memos: \(error.localizedDescription)")
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
        let autoVariables = ["{날짜}", "{시간}", "{연도}", "{월}", "{일}"]
        let pattern = "\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var placeholders: [String] = []

        for match in matches {
            if let range = Range(match.range, in: text) {
                let placeholder = String(text[range])
                if !autoVariables.contains(placeholder) && !placeholders.contains(placeholder) {
                    placeholders.append(placeholder)
                }
            }
        }

        return placeholders
    }

    private func processTemplateVariables(in text: String) -> String {
        var result = text
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "yyyy-MM-dd"
        result = result.replacingOccurrences(of: "{날짜}", with: dateFormatter.string(from: Date()))

        dateFormatter.dateFormat = "HH:mm:ss"
        result = result.replacingOccurrences(of: "{시간}", with: dateFormatter.string(from: Date()))

        result = result.replacingOccurrences(of: "{연도}", with: String(Calendar.current.component(.year, from: Date())))
        result = result.replacingOccurrences(of: "{월}", with: String(Calendar.current.component(.month, from: Date())))
        result = result.replacingOccurrences(of: "{일}", with: String(Calendar.current.component(.day, from: Date())))

        return result
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
        return self.size(withAttributes: [NSAttributedString.Key.font: UIFont(name: "Helvetica", size: 15)]).width
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
