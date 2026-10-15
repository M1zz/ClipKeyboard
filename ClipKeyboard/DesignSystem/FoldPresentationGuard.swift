//
//  FoldPresentationGuard.swift
//  ClipKeyboard
//
//  펼친 아이폰 듀오에서 **시트와 알림창이 접힌 선 위에 서지 않게** 한다.
//
//  화면 안의 판은 `FoldSplitView` 가 선을 비켜 세운다. 하지만 시트와 알림창은 화면이 아니라
//  시스템이 창 위에 띄운다. 시트는 창 바닥에서 창 끝까지 오르고, 알림창은 창 가운데,
//  곧 접힌 선 위에 선다. 그래서 띄우는 길 자체를 여기 한 곳에서 붙잡는다.
//
//  ⚠️ 접혀 있으면(바깥 화면 · 보통 아이폰 · 아이패드) 아무것도 바꾸지 않는다.
//  ⚠️ ObjC 런타임으로 UIKit 메서드를 바꿔 끼운다. 바꿔 끼운 이름(`fold_…`)은 **원래 구현**을 부른다.
//

import SwiftUI
import UIKit

// MARK: - 지금 접힘

/// 지금 창의 접힘. UIKit 쪽(`FoldSheetGuard`)이 읽는다. 루트의 `MeasuredWindow` 가 적는다.
@MainActor
enum FoldState {
    static var current = FoldLayout.single
}

// MARK: - 시트

/// 모든 시트를 **접힌 선의 한쪽**에 가둔다. 앱 어디서 띄운 시트든 이 한 곳을 지난다.
///
/// - 세로로 펴면 아래에서 오르는 시트는 아래 쪽 판 높이까지만 오른다. 높이 손잡이는 숨긴다.
/// - 가로로 펴면 시트를 오른쪽(결과 쪽)에 세운다(iOS 27 `preferredPlacement`).
///
/// ⚠️ 시트마다 수식어를 거는 길은 버렸다. 시트를 띄우는 자리가 79곳이고, 띄우는 쪽의
///    `presentationDetents` 가 시트 안쪽의 것을 이겨서(실측: 새 기능 안내가 창 끝까지 올라옴)
///    한 곳만 빠뜨려도 선을 덮는다. SwiftUI 도 결국 `UISheetPresentationController` 의
///    `detents` 를 쓰므로, 그 쓰기 자체를 여기서 바꿔 끼운다.
/// ⚠️ 접혀 있으면 받은 값을 그대로 넘긴다. 바깥 화면과 보통 아이폰은 아무것도 달라지지 않는다.
@MainActor
enum FoldSheetGuard {
    private static var installed = false

    /// 앱이 뜰 때 한 번. 두 번 불러도 한 번만 바꿔 끼운다.
    static func install() {
        guard !installed else { return }
        installed = true
        swap(UISheetPresentationController.self,
             #selector(setter: UISheetPresentationController.detents),
             #selector(UISheetPresentationController.fold_setDetents(_:)))
        swap(UISheetPresentationController.self,
             #selector(UISheetPresentationController.presentationTransitionWillBegin),
             #selector(UISheetPresentationController.fold_presentationTransitionWillBegin))
        swap(UIViewController.self,
             #selector(UIViewController.present(_:animated:completion:)),
             #selector(UIViewController.fold_present(_:animated:completion:)))
    }

    /// 이 클래스가 직접 갖지 않은 메서드면 먼저 더해서, 부모 클래스(모든 표시 방식)는 건드리지 않는다.
    fileprivate static func swap(_ cls: AnyClass, _ original: Selector, _ replacement: Selector) {
        guard let o = class_getInstanceMethod(cls, original),
              let r = class_getInstanceMethod(cls, replacement) else {
            print("❌ [FoldSheetGuard.swap] 메서드를 못 찾음: \(original)")
            return
        }
        if class_addMethod(cls, original, method_getImplementation(r), method_getTypeEncoding(r)) {
            class_replaceMethod(cls, replacement, method_getImplementation(o), method_getTypeEncoding(o))
        } else {
            method_exchangeImplementations(o, r)
        }
    }

    static let lowerPaneDetentID = UISheetPresentationController.Detent.Identifier("fold.lowerPane")

    /// 세로로 폈을 때 쓸 높이. 시트 맨 위가 접힌 선 띠 아래 끝(`trailStart`)에 닿는다.
    /// 시트 높이는 바닥 안전 영역을 뺀 값이라 그만큼 덜어 낸다.
    static func detents(for sheet: UISheetPresentationController,
                        requested: [UISheetPresentationController.Detent]) -> [UISheetPresentationController.Detent] {
        guard FoldState.current.posture == .innerPortrait else { return requested }
        return [.custom(identifier: lowerPaneDetentID) { [weak sheet] context in
            let fold = FoldState.current
            let bottomInset = sheet?.containerView?.window?.safeAreaInsets.bottom ?? 0
            let height = fold.windowSize.height - bottomInset - fold.trailStart
            return max(0, min(context.maximumDetentValue, height))
        }]
    }

    /// 띄우기 직전에 한 번 더 맞춘다. 높이를 따로 주지 않은 시트는 `detents` 를 쓰지 않고 뜨기 때문이다.
    static func prepare(_ sheet: UISheetPresentationController) {
        switch FoldState.current.posture {
        case .innerPortrait:
            sheet.detents = sheet.detents   // 위의 바꿔 끼운 쓰기를 지난다
            sheet.selectedDetentIdentifier = lowerPaneDetentID
            sheet.prefersGrabberVisible = false
        case .innerLandscape:
            if #available(iOS 27.0, *) {
                sheet.preferredPlacement = .trailing
            }
        case .single:
            break
        }
    }
}

extension UISheetPresentationController {
    // 바꿔 끼운 뒤에는 이 이름이 **원래 구현**을 부른다.
    @objc fileprivate func fold_setDetents(_ detents: [UISheetPresentationController.Detent]) {
        let filtered = MainActor.assumeIsolated { FoldSheetGuard.detents(for: self, requested: detents) }
        fold_setDetents(filtered)
    }

    @objc fileprivate func fold_presentationTransitionWillBegin() {
        MainActor.assumeIsolated { FoldSheetGuard.prepare(self) }
        fold_presentationTransitionWillBegin()
    }
}

// MARK: - 알림창

/// 알림창(`UIAlertController`)을 **고르는 쪽 판 크기의 창**에 띄운다.
///
/// 알림창은 자기가 뜬 창의 가운데에 선다. 앱 창은 펼친 화면 전체라 그 가운데가 접힌 선이다.
/// 알림창이 서는 자리를 고를 길이 UIKit 에 없어서(27.0 SDK), 창을 하나 더 만들어
/// 고르는 쪽 판 자리에 맞춰 두고 거기서 띄운다. 그러면 판 가운데에 선다.
/// 아래에서 오르는 선택 목록(`confirmationDialog`)도 같은 길로 판 바닥에 선다.
///
/// ⚠️ 띄운 쪽(SwiftUI)이 보기에는 자기가 띄운 것이 아니다. 단추를 누르면 알림창이 스스로
///    내려가고 SwiftUI 는 그 단추의 동작으로 상태를 되돌리므로 흐름은 그대로다.
@MainActor
enum FoldAlertRouter {
    private static var paneWindow: UIWindow?

    /// 이 표시를 판 창으로 돌릴 것인가.
    static func shouldRoute(_ presented: UIViewController, from presenter: UIViewController) -> Bool {
        guard FoldState.current.isUnfolded, presented is UIAlertController else { return false }
        return !(presenter is FoldPaneRootController)
    }

    static func route(_ alert: UIViewController, from presenter: UIViewController,
                      animated: Bool, completion: (() -> Void)?) {
        guard let host = presenter.view.window, let scene = host.windowScene else {
            presenter.fold_present(alert, animated: animated, completion: completion)
            return
        }
        let window = paneWindow ?? FoldPaneWindow(windowScene: scene)
        let root = (window.rootViewController as? FoldPaneRootController) ?? FoldPaneRootController()
        window.rootViewController = root
        window.windowLevel = .alert
        window.backgroundColor = .clear
        window.frame = paneFrame(in: host)
        window.isHidden = false
        paneWindow = window
        print("🔀 [FoldAlertRouter.route] 알림창을 고르는 쪽 판(\(window.frame))에 띄움")
        root.fold_present(alert, animated: animated, completion: completion)
    }

    /// 알림창이 내려가면 판 창도 거둔다.
    static func close() {
        paneWindow?.isHidden = true
        paneWindow = nil
    }

    /// 고르는 쪽 판. 가로면 왼쪽, 세로면 아래. 화면 좌표.
    private static func paneFrame(in host: UIWindow) -> CGRect {
        let fold = FoldState.current
        // 앱 창 크기. 실기기는 창 그대로, 미리보기 틀이면 틀의 크기다.
        let bounds = CGRect(origin: .zero,
                            size: FoldState.current.windowSize == .zero ? host.bounds.size : FoldState.current.windowSize)
        let local: CGRect
        switch fold.posture {
        case .innerLandscape:
            local = CGRect(x: 0, y: 0, width: fold.leadEnd, height: bounds.height)
        case .innerPortrait:
            let top = fold.trailStart
            local = CGRect(x: 0, y: top, width: bounds.width, height: bounds.height - top)
        case .single:
            local = bounds
        }
        // 미리보기 틀(`-FoldPreview`)이면 창 안에서 틀이 놓인 자리만큼 옮긴다. 실기기는 0 이다.
        return host.convert(local.offsetBy(dx: fold.windowOrigin.x, dy: fold.windowOrigin.y), to: nil)
    }
}

/// 판 창. 띄운 것이 없으면 **터치를 받지 않는다.**
///
/// ⚠️ 알림창이 내려갈 때 창을 거두는 길(`FoldPaneRootController.dismiss`)을 놓치면,
///    보이지 않는 창이 고르는 쪽 판을 덮어 앱이 눌리지 않는 것처럼 된다. 그 경우에도
///    터치가 아래 앱 창으로 빠지게 둔다.
final class FoldPaneWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard rootViewController?.presentedViewController != nil else { return nil }
        return super.hitTest(point, with: event)
    }
}

/// 판 창의 뿌리. 아무것도 그리지 않고, 띄운 것이 내려가면 창을 거둔다.
final class FoldPaneRootController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag) {
            completion?()
            FoldAlertRouter.close()
        }
    }
}

extension UIViewController {
    @objc fileprivate func fold_present(_ presented: UIViewController, animated: Bool, completion: (() -> Void)?) {
        let routes = MainActor.assumeIsolated { FoldAlertRouter.shouldRoute(presented, from: self) }
        if routes {
            MainActor.assumeIsolated {
                FoldAlertRouter.route(presented, from: self, animated: animated, completion: completion)
            }
        } else {
            fold_present(presented, animated: animated, completion: completion)
        }
    }
}

// MARK: - 시트의 짝: 비어 있는 다른 판

/// 시트가 떠 있는 동안 **시트가 없는 쪽 판**에 그 시트의 결과를 크게 세운다(재료 | 결과).
///
/// 펼친 화면에서 시트는 한 판에 갇힌다(세로면 아래, 가로면 오른쪽). 템플릿을 채우는 동안
/// 완성 문장을 보는 일처럼, 만지는 것과 그 결과를 동시에 보고 싶은 시트가 있다.
/// 그 결과를 다른 판(세로면 위, 가로면 왼쪽)에 판 크기의 창 하나로 띄운다.
///
/// ⚠️ 창은 앱 창보다 한 층 위에 뜬다. 시트가 없는 쪽만 덮으므로 시트를 가리지 않는다.
/// ⚠️ 접혀 있으면 아무것도 띄우지 않는다. 시트 안의 작은 미리보기가 그대로 그 일을 한다.
@MainActor
final class FoldSheetCompanionStore: ObservableObject {
    static let shared = FoldSheetCompanionStore()

    @Published private(set) var title = ""
    @Published private(set) var content: AnyView?
    private var owner: UUID?
    private var window: UIWindow?

    private init() {}

    func show(owner: UUID, title: String, content: AnyView) {
        guard FoldState.current.isUnfolded else { return hide(owner: owner) }
        self.owner = owner
        self.title = title
        self.content = content
        placeWindow()
    }

    /// 띄운 그 시트만 거둘 수 있다. 다른 시트가 이어서 떴으면 그대로 둔다.
    func hide(owner: UUID) {
        guard self.owner == owner else { return }
        self.owner = nil
        content = nil
        window?.isHidden = true
        window = nil
    }

    private func placeWindow() {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let host = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else { return }
        // ⚠️ 시트로 떠 있을 때만 세운다. 같은 화면이 목록 | 자세히 줄(`FoldNavigation`)에 밀려 들어와
        //    있을 때 세우면, 비어 있다고 본 판이 실은 목록과 뒤로 단추라서 그것을 덮는다.
        guard host.rootViewController?.presentedViewController != nil else {
            content = nil
            window?.isHidden = true
            return
        }
        let fold = FoldState.current
        // 앱 창 크기. 실기기는 창 그대로, 미리보기 틀이면 틀의 크기다.
        let bounds = CGRect(origin: .zero,
                            size: FoldState.current.windowSize == .zero ? host.bounds.size : FoldState.current.windowSize)
        let local: CGRect
        switch fold.posture {
        case .innerPortrait:
            local = CGRect(x: 0, y: 0, width: bounds.width, height: fold.leadEnd)
        case .innerLandscape:
            local = CGRect(x: 0, y: 0, width: fold.leadEnd, height: bounds.height)
        case .single:
            return
        }
        let window = self.window ?? UIWindow(windowScene: scene)
        if window.rootViewController == nil {
            let hosting = UIHostingController(rootView: AppThemedContainer { FoldSheetCompanionHost() })
            hosting.view.backgroundColor = .clear
            window.rootViewController = hosting
        }
        window.windowLevel = .normal + 1
        window.frame = host.convert(local.offsetBy(dx: fold.windowOrigin.x, dy: fold.windowOrigin.y), to: nil)
        window.isHidden = false
        self.window = window
        print("🪟 [FoldSheetCompanionStore.placeWindow] 시트의 짝을 비어 있는 판(\(window.frame))에 띄움")
    }
}

private struct FoldSheetCompanionHost: View {
    @ObservedObject private var store = FoldSheetCompanionStore.shared
    @Environment(\.appTheme) private var theme

    var body: some View {
        if let content = store.content {
            // ⚠️ 바탕을 불투명하게 깐다. 짝 판은 앱 창 위에 뜨는 따로 된 창이라, 비치면
            //    뒤의 앱 화면과 글자가 겹친다(실측).
            Group {
                // 제목이 없으면 짝이 스스로 판 전체를 그린다(배경 사진처럼 가장자리까지 까는 것).
                if store.title.isEmpty {
                    content
                } else {
                    FoldCompanionPane(title: store.title) { content }
                }
            }
            .background(theme.bg.ignoresSafeArea())
        }
    }
}

extension View {
    /// 시트 본문에 건다. 펼친 화면이면 `value` 가 바뀔 때마다 비어 있는 판의 결과를 다시 그린다.
    func foldSheetCompanion<Value: Equatable, Companion: View>(
        title: String,
        value: Value,
        @ViewBuilder content: @escaping (Value) -> Companion
    ) -> some View {
        modifier(FoldSheetCompanionModifier(title: title, value: value, content: content))
    }
}

private struct FoldSheetCompanionModifier<Value: Equatable, Companion: View>: ViewModifier {
    @Environment(\.foldLayout) private var fold
    @State private var owner = UUID()
    let title: String
    let value: Value
    let content: (Value) -> Companion

    func body(content view: Content) -> some View {
        view
            .onChange(of: value, initial: true) { _, now in publish(now) }
            .onChange(of: fold) { _, _ in publish(value) }
            .onDisappear { FoldSheetCompanionStore.shared.hide(owner: owner) }
    }

    private func publish(_ now: Value) {
        if fold.isUnfolded {
            FoldSheetCompanionStore.shared.show(owner: owner, title: title, content: AnyView(content(now)))
        } else {
            FoldSheetCompanionStore.shared.hide(owner: owner)
        }
    }
}
