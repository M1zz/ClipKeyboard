//
//  ClipKeyboardList.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/05/14.
//

import SwiftUI
import LocalAuthentication
import TipKit
import UniformTypeIdentifiers
import LeeoKit

var fontSize: CGFloat = 20

extension Color {
    /// 즐겨찾기 지정색 — 시스템 핑크보다 더 선명한 분홍(#FF4A9E).
    static let clipFavorite = Color(red: 1.0, green: 0.29, blue: 0.62)
}

// UUID는 이 Swift 버전에서 Identifiable을 자동 제공하지 않으므로 명시적으로 추가
extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

/// List 스크롤 오프셋을 상위 View로 전달하는 PreferenceKey.
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// 순서 바꾸기 그리드의 드롭 델리게이트 — 드래그가 다른 카드 위로 들어오면 그 자리로 즉시 이동.
/// `.onDrag`가 손가락을 따라오는 네이티브 미리보기를 제공하고, dropEntered에서 라이브 재배치한다.
private struct MemoReorderDropDelegate: DropDelegate {
    let item: Memo
    @Binding var list: [Memo]
    @Binding var dragging: Memo?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging.id != item.id,
              let from = list.firstIndex(where: { $0.id == dragging.id }),
              let to = list.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            list.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
        HapticManager.shared.light()
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

/// 그리드 여백에 드롭됐을 때 드래그 상태만 정리하는 컨테이너용 델리게이트(재배치는 안 함).
private struct ReorderResetDropDelegate: DropDelegate {
    @Binding var dragging: Memo?
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

struct ClipKeyboardList: View {

    @StateObject private var viewModel = ClipKeyboardListViewModel()
    @ObservedObject private var suggestionManager = SuggestionManager.shared

    // MARK: - View-only State

    @State private var isSearchBarVisible = false
    @State private var showDraftList = false
    // 붙여넣기 허용 안내 팁 — 앱을 열 때마다 "붙여넣기 허용" 팝업이 뜨는 사용자를 설정으로 안내.
    // 클립보드 화면 배너와 dismiss 키(pasteTipDismissed)를 공유해, 어느 쪽에서 닫든 함께 사라진다.
    // 설치 직후엔 iOS 설정에 '다른 앱에서 붙여넣기' 항목이 아직 없어 안내가 헛돌므로,
    // 3번째 실행부터 노출한다(PastePermissionGuidance).
    @State private var showPasteTip: Bool = !UserDefaults.standard.bool(forKey: DefaultsKey.pasteTipDismissed)
        && PastePermissionGuidance.isReady
    @FocusState private var isSearchFieldFocused: Bool
    @State private var memoToDelete: Memo?
    @State private var graceBannerVisible: Bool = ProFeatureManager.hasGraceMemoQuota && !ProFeatureManager.didDismissGraceBanner
    // 가치 순간 Pro 넛지 — 1회·닫기 가능 (페이월 노출률 향상)
    @State private var proNudgeDismissed: Bool = UserDefaults.standard.bool(forKey: DefaultsKey.proValueNudgeDismissedV1)
    @State private var showPaywallFromKeyboard: Bool = false
    @State private var showBulkImport: Bool = false
    /// + 메뉴에서 "빠른 메모 담기" → 보관함(Inbox) 추가 시트
    @State private var showQuickNoteAdd: Bool = false
    /// App Intent·Control Center·딥링크로 빠른 메모 보관함(Inbox)을 직접 열 때 사용.
    @State private var showInboxFromIntent: Bool = false
    /// Inbox 배너를 닫은 시점의 항목 수. 이보다 더 쌓이면(=새 캡처) 배너가 다시 나타난다.
    @State private var inboxBannerDismissCount: Int = 0
    @State private var hasAppeared: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var occasionalSuggestion_: SuggestionTemplate?
    @State private var navigateToOccasionalAdd: Bool = false

    // 메모 구분 표시 마스터 토글 — 기본 OFF(제목만, 가장 심플).
    // 켜면 타입 아이콘·배지·테두리·우상단 심볼·카테고리/즐겨찾기 색을 모두 표시.
    // App Group에 저장해 키보드 익스텐션도 같은 설정을 읽는다.
    @AppStorage("showVisualCues", store: UserDefaults(suiteName: AppGroup.identifier))
    private var showVisualCues: Bool = false
    @State private var showCategoryBadgeNudge: Bool = false

    /// 메모 구분 장치(아이콘/배지/테두리/심볼/색) 노출 여부.
    /// 오직 설정 "메모 구분 표시" 토글만 따른다 — iOS "색상 없이 구별"(접근성)이 켜져 있어도
    /// 토글이 꺼져 있으면 표시하지 않는다(토글을 단일 스위치로).
    private var visualCuesVisible: Bool {
        showVisualCues
    }
    /// 디스플레이 설정 — 메모 셀 높이(작게 110 / 보통 140 / 크게 180).
    @AppStorage("memoCardHeight") private var memoCardHeight: Double = 140
    /// 단축어 스킨 프리셋 — 카드 위에 얹히는 것(없음/금고/마을/눈/새/고양이).
    @AppStorage(DefaultsKey.livingSkin, store: UserDefaults(suiteName: AppGroup.identifier))
    private var livingSkinRaw: String = LivingSkin.none.rawValue
    /// 동전이 어디서 날아 어디로 들어가는지를 쥐고 있는 것.
    @StateObject private var vaultDeposit = VaultDeposit()
    /// 금고에 쌓인 시간(초) — 입금할 때마다 갱신해 잔고 알약이 바로 늘어난다.
    @State private var vaultSeconds: Double = 0
    /// 금고 화면 열기.
    @State private var showVault = false
    /// 첫 단축어 만들기를 끝냈거나 건너뛰었는지.
    @AppStorage(DefaultsKey.firstShortcutDone)
    private var firstShortcutDone: Bool = false
    /// 단축어 탭이 무엇을 보여줄지(목록 / 키보드 미리보기). 툴바의 전환 버튼이 이 값을 뒤집는다.
    @AppStorage(DefaultsKey.snippetsTabStyle)
    private var snippetsTabStyleRaw: String = SnippetsTabStyle.list.rawValue
    /// 이 기기가 4.4.4 에서 처음 시작했는지 — 온보딩을 보여줄 사람인지 가른다.
    @AppStorage(DefaultsKey.startedFreshV444)
    private var startedFreshV444: Bool = false
    /// 방금 만든 단축어 — 한 번 써 볼 때까지 "눌러보세요"를 띄운다.
    @State private var coachMemoID: UUID?
    /// 그 카드가 화면 어디에 있는지(global). 안내를 카드 바로 아래에 붙이려고 본다.
    @State private var coachRect: CGRect = .zero
    /// 복사까지 해 본 직후 이어지는 붙여넣기 연습. 복사만 시키고 끝내면
    /// "복사됐다"로 끝나고, 값어치는 **그 다음에 안 친 것**에 있다.
    @State private var pastePractice: PastePracticeRequest?

    private struct PastePracticeRequest: Identifiable {
        let id = UUID()
        let value: String
    }

    /// 콤보/템플릿 튜토리얼을 끝냈는지. 한 번 한 사람에게 다시 권하지 않는다.
    @AppStorage(DefaultsKey.tutorialComboDone)
    private var tutorialComboDone: Bool = false
    @AppStorage(DefaultsKey.tutorialTemplateDone)
    private var tutorialTemplateDone: Bool = false
    @AppStorage(DefaultsKey.tutorialMakeTemplateDone)
    private var tutorialMakeTemplateDone: Bool = false
    /// 처음 배우는 차례가 끝났는가 — 안 끝났으면 챕터 초대는 무대가 이끈다.
    @AppStorage(DefaultsKey.tutorialChaptersDone)
    private var tutorialChaptersDone: Bool = false
    /// "템플릿으로 만들기" 시트가 튜토리얼로 열렸는지 — 닫힐 때 다음 장으로 이어주려고 본다.
    @State private var awaitingMakeTemplate = false
    /// "이어서 해볼까요?" 를 띄우는 중인 장.
    @State private var tutorialInvite: TutorialChapter?
    /// 만들기 화면을 띄우는 중인 장.
    @State private var tutorialMaking: TutorialChapter?
    /// 지금 코치가 가리키는 장 — 안내 문구가 장마다 다르다.
    @State private var coachChapter: TutorialChapter?
    /// 마지막으로 손가락이 닿은 자리(global). 동전이 여기서 튀어 오른다.
    @State private var lastTapPoint: CGPoint = .zero
    /// 지금 동전을 보여주고 있는 카드. 이 카드는 내용 대신 동전을 보여준다.
    @State private var coinBadgeMemoID: UUID?
    /// 방금 일한 카드 — 테두리가 잠깐 켜진다. 동전·보석이 날아간 **뒤에**
    /// "이 카드가 방금 일했다"를 뒤따라 말해 준다.
    @State private var glowMemoID: UUID?
    /// 지금 막 깨지고 있는 지오드. 부서진 모습을 잠깐 붙잡아 둔다 —
    /// 곧장 새 돌로 넘어가면 무엇이 나왔는지 못 보고 지나간다.
    @State private var burstingMemoID: UUID?
    /// 모달이 닫히기를 기다리는 입금. 콤보·템플릿은 시트가 떠 있는 동안 사용이 확정되는데,
    /// 그때 바로 날리면 동전이 시트 뒤에 가려 보이지도 않는다.
    @State private var pendingDeposit: (memoID: UUID, seconds: Double, point: CGPoint)?
    /// 키캡 물성 — 설정에서 바꾸면 이 화면도 바로 따라야 한다.
    @AppStorage(DefaultsKey.keyboardSkin, store: UserDefaults(suiteName: AppGroup.identifier))
    private var keyboardSkinRaw: String = KeyboardSkin.classic.rawValue
    /// 손님(새·고양이)이 지금 어느 카드에 와 있는지. 손님 스킨이 아니면 놀고 있는다.
    @StateObject private var guestScheduler = GuestScheduler()
    /// 카드 내용 힌트 — 설정(메모 표시)에서 켜기/끄기. 키보드도 함께 따르도록 App Group에 저장.
    @AppStorage("contentHintEnabled", store: UserDefaults(suiteName: AppGroup.identifier))
    private var contentHintEnabled: Bool = true

    // Category
    @State private var showCategoryManagement: Bool = false
    @State private var showAddCategoryAlert: Bool = false
    @State private var newCategoryName: String = ""
    @State private var categoryToDelete: String?
    // 롱프레스 컨텍스트에서 즉석 카테고리 생성+배정
    @State private var memoForCategoryAssign: Memo?
    @State private var newCategoryForMemo: String = ""
    @State private var showNewCategoryForMemoAlert: Bool = false

    // 롱프레스 테두리 애니메이션 + 액션 메뉴
    @State private var longPressActiveMemo: Memo?
    @State private var longPressProgress: CGFloat = 0
    @State private var memoForActions: Memo?
    @State private var showMemoActions: Bool = false

    // 탭 누름 바운스 — 카드별 트리거. 탭하면 해당 카드만 들어갔다(0.92)→1.05배로 튀었다→원래 크기.
    @State private var bounceTriggers: [UUID: Int] = [:]

    // 순서 바꾸기(흔들기/드래그 재정렬)
    @State private var draggingMemo: Memo?
    @State private var wiggle: Bool = false

    // 즐겨찾기 탭 전용
    @State private var showAddFavoriteMemoSheet: Bool = false
    @State private var showSwipeCategoryDialog: Bool = false

    // 스타터팩 — 추천 묶음 일괄 추가 시트
    @State private var showStarterPack: Bool = false

    // 고스트 메모 제안 — 메인 화면에 흐릿하게 "이런 메모는 어때요?" 제안
    @State private var ghostSuggestion: QuickPattern?
    @State private var ghostAddPattern: QuickPattern?
    private let dismissedGhostPatternsKey = "dismissedGhostPatterns_v1"
    // X로 한 번 닫으면 고스트 예시 제안을 영구히 끈다(앱 재실행해도 "또 다른 옵션"이 안 뜸).
    private let ghostSuggestionsOffKey = "ghostSuggestionsOff_v1"
    // X로 닫으면 이번 앱 실행(세션) 동안은 다음 제안을 띄우지 않는다.
    private static var ghostSuppressedThisSession = false

    // Sheet modals for MemoAdd
    @State private var showAddMemoSheet: Bool = false
    @State private var addMemoSheetCategory: String = ""
    @State private var showAddTemplateSheet: Bool = false
    @State private var showAddComboSheet: Bool = false
    @State private var memoToEdit: Memo?
    /// "템플릿으로 만들기" 원본 메모 — 이 메모 내용으로 채운 별도 새 메모를 만든다(원본은 그대로).
    @State private var makeTemplateSource: Memo?

    // TipKit
    private let welcomeTip = WelcomeTip()
    private let addMemoTip = AddMemoTip()
    private let quickNoteInboxTip = QuickNoteInboxTip()

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 카드 열 수 결정용 — 아이패드·맥에서 `.regular` 가 된다.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var shouldShowGraceBanner: Bool {
        graceBannerVisible && !ProFeatureManager.isPro
    }

    /// 가치 순간 Pro 넛지 표시 조건: 무료 유저 + 미닫힘 + 가치 입증
    /// (10분 이상 절약했거나 무료 한도에 근접). grace 배너와는 동시 노출 안 함.
    private var shouldShowProValueNudge: Bool {
        guard !proNudgeDismissed,
              !ProFeatureManager.hasFullAccess,
              !shouldShowGraceBanner else { return false }
        let savedEnough = KeyboardUsageTracker.totalTimeSavedSeconds() >= 600
        let nearLimit = viewModel.memos.count >= max(1, ProFeatureManager.freeMemoLimit - 3)
        return savedEnough || nearLimit
    }

    /// 넛지 메시지 종류 — Analytics source 슬라이싱용.
    private var proNudgeSource: String {
        KeyboardUsageTracker.totalTimeSavedSeconds() >= 600 ? "time_saved" : "slots_left"
    }

    /// 절약 시간이 충분하면 그 증거를, 아니면 남은 무료 칸(손실 회피)을 메시지로.
    private var proValueNudgeMessage: String {
        let saved = KeyboardUsageTracker.totalTimeSavedSeconds()
        if saved >= 600 {
            let minutes = Int(saved / 60)
            return String(format: NSLocalizedString("이미 %d분을 아꼈어요 — Pro로 무제한으로 계속", comment: "Pro nudge: time saved"), minutes)
        }
        let left = max(0, ProFeatureManager.freeMemoLimit - viewModel.memos.count)
        return String(format: NSLocalizedString("무료 단축어 %d칸 남았어요 — Pro로 무제한", comment: "Pro nudge: slots left"), left)
    }

    /// 카드 어항 미리보기 텍스트 — 제목 아래에서 물고기처럼 나타났다 사라질 내용 한 줄.
    /// 사용자가 메모에 힌트를 직접 적었으면 그것이 우선(보안 메모도 — 직접 쓴 한 줄이라 안전).
    /// ⚠️ 자동 요약은 보안 메모 내용 노출 금지(자물쇠 카드에서 값이 떠다니면 안 됨) → nil.
    private func fishbowlText(memo: Memo) -> String? {
        if let custom = memo.hint?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        guard !memo.isSecure else { return nil }
        let text = MemoPreviewFormatter.preview(for: memo, resolvedType: memo.autoDetectedType)
        return text.isEmpty ? nil : text
    }

    /// 페이지 상단 헤더 — 상단 배너 묶음(스크롤 콘텐츠 첫 요소라 스크롤과 함께 이동).
    /// 제목은 여기 두지 않는다 — 순정 네비게이션 바 인라인 타이틀이 담당(고정, glass).
    /// AnyView 타입 소거 — LazyVStack 자식 추가로 인한 타입 메타데이터 폭발 방지.
    /// 스크롤이 내려간 상태인지 — 타이틀 표시 모드 전환·상단 여백 측정 가드용.
    @State private var showsInlineNavTitle = false

    /// 타이틀 표시 모드. inlineLarge는 등장 시 접힌 채 시작하는 시스템 동작이 있어(실측)
    /// 항상 펼쳐지는 .large로 시작한 뒤 등장 직후 .inlineLarge로 전환한다.
    @State private var titleDisplayMode: ToolbarTitleDisplayMode = .large

    /// 등장 후 inlineLarge로 정착했는지 — 이때부터만 상단 시작점을 측정한다.
    /// (.large 시작 단계의 더 높은 바가 측정되면 여백이 커짐, 실측)
    @State private var titleBarSettled = false

    /// 등장 직후 .large → .inlineLarge 전환(펼침 상태 유지 확인용).
    private func expandTitleOnAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if !showsInlineNavTitle {
                titleDisplayMode = .inlineLarge
            }
            titleBarSettled = true
        }
    }

    /// 세이프에어리어 무시 전 페이저의 상단 y(=네비바 하단). categoryContent에서 실측.
    @State private var pageTopInset: CGFloat = 113

    /// 페이지 스크롤 오프셋으로 타이틀 모드 전환 — 페이저(UIKit 셀) 안 스크롤은
    /// 네비바가 자동 추적하지 못하고, preference도 셀 경계에서 업데이트가 끊겨(실측)
    /// onScrollGeometryChange(iOS 18+)를 쓴다. iOS 17은 전환 없이 inlineLarge 유지.
    @ViewBuilder
    private func trackPageScroll<V: View>(_ view: V) -> some View {
        if #available(iOS 18.0, *) {
            view.onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top > 44
            } action: { _, scrolled in
                guard scrolled != showsInlineNavTitle else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    showsInlineNavTitle = scrolled
                    titleDisplayMode = scrolled ? .inline : .inlineLarge
                }
            }
        } else {
            view
        }
    }

    private func pageHeader(for tab: CategoryTab) -> AnyView {
        AnyView(topBanners)
    }

    /// 네비게이션 바 인라인 타이틀 — 현재 카테고리 이름(스와이프 시 갱신).
    private var currentCategoryTitle: String {
        let tab: CategoryTab = CategoryStore.shared.isFeatureEnabled ? viewModel.selectedCategoryTab : .all
        return tab.displayName
    }

    @ViewBuilder
    private var mainColumn: some View {
        // ⚠️ 런타임 타입 메타데이터 폭발 방지(중요):
        // VStack에 조건부 자식이 많아지면 거대한 중첩 제네릭 타입이 만들어지고,
        // 기기에서 런타임이 그 타입 메타데이터를 인스턴스화하다 스택을 넘겨 죽는다
        // (__swift_instantiateConcreteTypeFromMangledName 재귀 → mainColumn.getter 크래시).
        // 자식들을 AnyView로 타입 소거해 부모 타입을 평탄화하여 이를 막는다.
        VStack(spacing: 0) {
            // v4.3.9: 제목·배너는 pageHeader(for:)로 각 페이지 스크롤 안에 들어간다.
            // 상단에 고정 크롬이 없어 콘텐츠가 화면을 온전히 쓴다.
            categoryContent
        }
        // 순정 Liquid Glass: 상·하단 스크롤 엣지 효과는 시스템 기본에 맡긴다
        // (네비바·플로팅 탭바가 콘텐츠와 만날 때 soft glass 처리).
    }

    /// 상단 배너 모음(빠른 메모 Inbox · Pro 넛지 · 카테고리 활성/제안).
    /// AnyView로 타입 소거 — mainColumn VStack의 제네릭 중첩 깊이를 줄이는 핵심.
    private var topBanners: some View {
        AnyView(
            VStack(spacing: 0) {
                // 붙여넣기 허용 안내 — 앱 진입 시 클립보드를 읽어 팝업이 뜨는 바로 그 지점.
                // 한 번 설정을 바꾸면 팝업이 사라지므로, 최상단에서 설정으로 바로 안내한다.
                if showPasteTip {
                    PastePermissionTipBanner(
                        onOpenSettings: { openAppSettings() },
                        onDismiss: {
                            UserDefaults.standard.set(true, forKey: DefaultsKey.pasteTipDismissed)
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                                showPasteTip = false
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 빠른 메모(Inbox) 배너 — 분류 대기 항목이 있으면 상단에 즉시 노출.
                // (컨테이너가 내부에서 QuickNoteStore를 관찰하고, 비었으면 아무것도 안 그린다.
                //  타입은 topBanners의 AnyView로 소거되어 mainColumn 타입 복잡도에 영향 없음.)
                QuickNoteInboxBannerContainer(dismissCount: $inboxBannerDismissCount) {
                    HapticManager.shared.light()
                    showInboxFromIntent = true
                }

                // 가치 순간 Pro 넛지 — 무료 유저가 가치를 느낀 시점에 1회 노출.
                if shouldShowProValueNudge {
                    ProValueNudgeBanner(
                        message: proValueNudgeMessage,
                        onTap: {
                            HapticManager.shared.light()
                            AnalyticsService.logProNudge(.proNudgeTapped, source: proNudgeSource)
                            showPaywallFromKeyboard = true
                        },
                        onDismiss: {
                            UserDefaults.standard.set(true, forKey: DefaultsKey.proValueNudgeDismissedV1)
                            withAnimation { proNudgeDismissed = true }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear { AnalyticsService.logProNudge(.proNudgeShown, source: proNudgeSource) }
                }

                if CategoryStore.shared.shouldShowActivationBanner(currentMemoCount: viewModel.memos.count) {
                    CategoryActivationBanner(
                        onEnable: {
                            withAnimation { CategoryStore.shared.enableFeature() }
                            HapticManager.shared.success()
                        },
                        onDismiss: {
                            withAnimation { CategoryStore.shared.dismissActivationBanner() }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 페르소나 기반 카테고리 이름 제안 (TipKit).
                if shouldShowPersonaCategoryTip {
                    personaCategorySuggestionTip()
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 메모를 보고 카테고리 생성을 제안 (TipKit).
                if CategoryStore.shared.isFeatureEnabled,
                   let suggestion = viewModel.suggestedCategory {
                    categorySuggestionTip(name: suggestion.name, count: suggestion.count)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        )
    }

    /// iOS 설정의 이 앱 페이지(‘다른 앱에서 붙여넣기’ 토글 포함)를 연다.
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    /// 카테고리 탭/단일 페이지 — 가장 깊은 단일 요소라 AnyView로 타입 소거.
    /// GeometryReader: 세이프에어리어를 무시하기 전의 상단 오프셋(=네비바 하단)을 재서
    /// 각 페이지 스크롤 콘텐츠의 시작 위치(contentMargins)로 쓴다.
    private var categoryContent: some View {
        AnyView(
            GeometryReader { geo in
                let minY = geo.frame(in: .global).minY
                Group {
                    // 카테고리 기능이 활성일 때만 탭/swipe 뷰. 비활성이면 .all 페이지 하나.
                    if CategoryStore.shared.isFeatureEnabled {
                        categoryTabView
                    } else {
                        tabPageView(for: .all)
                    }
                }
                // 콘텐츠 시작점 = 확장(inlineLarge) 상태의 바 하단.
                // - 유효 범위(60~160) 가드: onAppear 직후 프레임 확정 전의 쓰레기 값 차단.
                //   상한을 200→160으로 좁힘 — .large→.inlineLarge 전환 중간의 과대값(~199)이
                //   latch되면 그리드가 화면 중앙부터 시작하는 버그가 됨(실측: inlineLarge 바
                //   하단은 100~130 언저리라 160이면 큰 글씨 설정까지 여유 있음).
                // - 접힘(.inline) 동안은 갱신 안 함: 스크롤 중 콘텐츠 점프 방지
                //
                // ⚠️ **커지는 쪽으로는 절대 안 움직인다.** 이 버그의 실패 방식은 언제나
                //    "너무 큼"이었다 — 큰 타이틀이 완전히 펼쳐진 순간의 값(150~160)이 latch되면
                //    그리드가 화면 한복판에서 시작한다. 반대로 작아서 생기는 사고는 없었다
                //    (바 하단에는 타이틀 쿠션이 넉넉해 몇 pt 붙어도 겹치지 않는다, 실측).
                //    범위 가드만으로는 못 막는다 — 유효 범위 안의 값 중에서도 **가장 작은 것**이
                //    우리가 원하는 상태(inlineLarge)의 바 하단이다.
                .onChange(of: minY, initial: true) { _, v in
                    if titleBarSettled, !showsInlineNavTitle, v > 60, v < 160 {
                        pageTopInset = min(pageTopInset, v)
                    }
                }
                // 정착 시점에 minY가 이미 최종값이면 위 onChange가 다시 안 불리므로 한 번 더 측정.
                .onChange(of: titleBarSettled) { _, settled in
                    if settled, !showsInlineNavTitle, minY > 60, minY < 160 {
                        pageTopInset = min(pageTopInset, minY)
                    }
                }
                // 타이틀이 다시 펼쳐질 때(스크롤 복귀) 재측정 — 어떤 경로로든 오염된 값을
                // 사용자가 맨 위로 돌아오는 순간 자가 치유한다.
                .onChange(of: showsInlineNavTitle) { _, inline in
                    if !inline, titleBarSettled, minY > 60, minY < 160 {
                        pageTopInset = min(pageTopInset, minY)
                    }
                }
            }
        )
    }

    /// 페이지 스크롤 콘텐츠의 상단 시작점 — 네비바 하단에서 10pt 끌어올려 타이틀과의
    /// 여백을 좁힌다(바 하단은 타이틀 아래 쿠션이 넉넉해 이 정도는 겹치지 않음, 실측).
    /// 상한 150 클램프: 측정값이 어떤 경로로든 오염돼도(전환 중간값 latch 등)
    /// 그리드가 화면 중앙부터 시작하는 최악의 표시는 막는다.
    /// **스크롤 페이지의 위 여백 — 경로에 따라 다르다.**
    ///
    /// ⚠️ 여기에 두 가지 화면이 섞여 있었고, 둘의 사정이 **정반대**라 값 하나로는 못 맞춘다.
    ///
    ///  ① **카테고리 페이저(TabView)** — 시스템이 바 아래로 안 밀어 준다.
    ///     우리가 잰 바 하단(100~130)을 그대로 줘야 한다. 안 주면 카드가 타이틀·툴바를 덮는다.
    ///  ② **단일 페이지**(카테고리 기능이 꺼진 '전체' 한 장) — ScrollView 를 시스템이
    ///     알아서 바 아래로 밀어 준다. 여기에 잰 값을 또 얹으면 여백이 **두 번** 들어가
    ///     그리드가 화면 중앙쯤에서 시작한다(오래된 "그리드가 안 올라간다" 버그의 정체).
    ///     실측: 0으로 두면 타이틀 아래 36pt 에 정확히 붙는다.
    ///
    /// 그래서 **어느 경로로 그려지는지**를 그대로 따라간다(categoryContent 의 분기와 같은 조건).
    private var pageContentTopMargin: CGFloat {
        CategoryStore.shared.isFeatureEnabled ? measuredBarBottomMargin : 8
    }

    /// 잰 네비바 하단에서 10pt 끌어올린 값. 페이저·빈 화면처럼 **시스템이 안 밀어 주는**
    /// 경로에서만 쓴다. 상한 130: 측정이 오염돼도 최악(화면 중앙 시작)은 막는다.
    private var measuredBarBottomMargin: CGFloat { min(max(pageTopInset - 10, 60), 130) }

    /// **스크롤이 없는 페이지(빈 화면)의 위 여백.**
    ///
    /// 이쪽도 시스템이 안 밀어 준다 — ScrollView 가 아니라 그냥 VStack 이다.
    /// 직접 재서 바 아래로 내려야 네비바에 글이 가려지지 않는다.
    private var emptyPageTopMargin: CGFloat { measuredBarBottomMargin }

    private var screenBody: some View {
            ZStack {
                // 현재 탭에 따라 배경색이 부드럽게 전환
                tabBackgroundColor
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.38), value: viewModel.selectedCategoryTab)

                // v4.1.0: 활성화 배너를 메모 위에 overlay하지 않고 VStack flow 안에
                // 두어 콘텐츠가 자연스럽게 아래로 밀려남. 다른 배너들(ReviewBanner,
                // GraceQuotaBanner 등)과 통일된 패턴.
                mainColumn
            }
            // 검색 키보드 내리기: 메모 영역 아무 데나 탭(simultaneous라 카드 탭 동작은 그대로 실행)
            // 하거나 스크롤하면 닫힌다. 검색바 자신은 safeAreaInset의 분리 영역이라
            // 탭해도 포커스가 풀리지 않음(깜빡임 없음).
            .simultaneousGesture(TapGesture().onEnded { isSearchFieldFocused = false })
            .scrollDismissesKeyboard(.immediately)
            // 검색은 순정 .searchable(검색 탭)로 이전 — 커스텀 하단 검색바 제거.
            .alert(
                NSLocalizedString("새 카테고리", comment: "Add category alert title"),
                isPresented: $showAddCategoryAlert
            ) {
                TextField(NSLocalizedString("카테고리 이름", comment: "Category name placeholder"), text: $newCategoryName)
                Button(NSLocalizedString("추가", comment: "Add")) {
                    viewModel.addCustomCategory(newCategoryName)
                    newCategoryName = ""
                }
                Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {
                    newCategoryName = ""
                }
            } message: {
                Text(NSLocalizedString("단축어를 분류할 카테고리 이름을 입력하세요.", comment: "Add category alert message"))
            }
            .alert(
                NSLocalizedString("카테고리 삭제", comment: "Delete category alert title"),
                isPresented: Binding(get: { categoryToDelete != nil }, set: { if !$0 { categoryToDelete = nil } })
            ) {
                Button(NSLocalizedString("삭제", comment: "Delete"), role: .destructive) {
                    if let name = categoryToDelete { viewModel.deleteCustomCategory(name) }
                    categoryToDelete = nil
                }
                Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { categoryToDelete = nil }
            } message: {
                if let name = categoryToDelete {
                    Text(String(format: NSLocalizedString("'%@' 카테고리를 삭제하시겠습니까? 단축어는 유지됩니다.", comment: "Delete category confirm message"), name))
                }
            }
            .alert(
                NSLocalizedString("새 카테고리 만들기", comment: "Create new category and assign alert title"),
                isPresented: $showNewCategoryForMemoAlert
            ) {
                TextField(NSLocalizedString("카테고리 이름", comment: "Category name placeholder"), text: $newCategoryForMemo)
                Button(NSLocalizedString("추가", comment: "Add")) {
                    let trimmed = newCategoryForMemo.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty, let memo = memoForCategoryAssign {
                        viewModel.addCustomCategory(trimmed)
                        viewModel.moveMemo(memo, toCategory: trimmed)
                    }
                    newCategoryForMemo = ""
                    memoForCategoryAssign = nil
                }
                Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {
                    newCategoryForMemo = ""
                    memoForCategoryAssign = nil
                }
            } message: {
                Text(NSLocalizedString("카테고리가 생성되고 이 단축어가 바로 이동됩니다.", comment: "Create category and assign message"))
            }
    }

    private var screenBody2: some View {
        screenBody
            .sheet(isPresented: $showStarterPack, onDismiss: { viewModel.loadMemos() }) {
                StarterPackView { count in
                    viewModel.showPlainToast(
                        String(format: NSLocalizedString("스타터팩 %d개를 추가했어요", comment: "Starter pack added toast"), count)
                    )
                }
            }
            .sheet(item: $ghostAddPattern, onDismiss: {
                viewModel.loadMemos()
                refreshGhostSuggestion()
            }) { pattern in
                NavigationStack {
                    MemoAdd(insertedKeyword: pattern.title, insertedValue: pattern.scaffold)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button(NSLocalizedString("취소", comment: "Cancel")) { ghostAddPattern = nil }
                            }
                        }
                }
            }
            .sheet(isPresented: $navigateToOccasionalAdd, onDismiss: { viewModel.loadMemos() }) {
                NavigationStack {
                    Group {
                        if let s = occasionalSuggestion_ { memoAdd(for: s) } else { MemoAdd() }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(NSLocalizedString("취소", comment: "Cancel")) { navigateToOccasionalAdd = false }
                        }
                    }
                }
            }
            .task {
                viewModel.loadMemos()
                refreshGhostSuggestion()
                AnalyticsService.setMemoBucket(viewModel.memos.count)
                expandTitleOnAppear()
                vaultSeconds = KeyboardUsageTracker.totalTimeSavedSeconds()
            }
            .toolbar {
                toolbarContent
            }
            // 동전 비행 + 코치를 한 겹으로 얹는다.
            // (오버레이를 여러 겹 쌓으면 이 화면의 뷰 체인이 길어져 타입 검사가 터진다.)
            .overlay { floatingLayer }
            .onPreferenceChange(CoachAnchorKey.self) { rect in
                coachRect = rect
            }
            .onReceive(NotificationCenter.default.publisher(for: .memoUsed)) { note in
                handleMemoUsed(note)
            }
            // 시트가 다 닫히면 기다리던 동전을 날린다. 닫히는 애니메이션이 끝나야
            // 동전이 시트 뒤에서 튀어나오는 것처럼 보이지 않는다.
            .onChange(of: anyModalUp) { _, isUp in
                guard !isUp, let pending = pendingDeposit else { return }
                pendingDeposit = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showCoinThenFly(memoID: pending.memoID,
                                    seconds: pending.seconds,
                                    from: pending.point)
                }
            }
            .navigationDestination(isPresented: $showVault) {
                VaultScreen()
            }
            // 온보딩의 마지막 걸음 — 전체 화면이라야 딴 데 안 보고 한 번 해 본다.
            .fullScreenCover(item: $pastePractice) { request in
                PastePracticeView(expected: request.value) {
                    pastePractice = nil
                    inviteNextChapter(after: 0.5)     // 붙여넣기까지 됐으면 다음 장을 권한다
                }
            }
            .fullScreenCover(item: $tutorialInvite) { chapter in
                TutorialInviteView(chapter: chapter) {
                    tutorialInvite = nil
                    // 시트가 겹치지 않게 한 박자 뒤에 다음 화면을 연다.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        if chapter == .makeTemplate {
                            // 새 화면을 만들지 않는다 — 이미 있는 "템플릿으로 만들기"를 그대로 태운다.
                            // 튜토리얼에서만 보는 특별한 화면을 배워봐야, 정작 평소에 쓰는
                            // 메뉴는 여전히 낯설다.
                            awaitingMakeTemplate = true
                            makeTemplateSource = convertibleShortcut
                        } else {
                            tutorialMaking = chapter
                        }
                    }
                } onDecline: {
                    tutorialInvite = nil
                    // 거절도 답이다 — 다시 묻지 않는다. 붙잡으면 다음에 안 온다.
                    markDone(chapter)
                }
            }
            .fullScreenCover(item: $tutorialMaking) { chapter in
                switch chapter {
                case .combo:
                    ComboTutorialView(onCreated: { tutorialCreated($0, chapter: .combo) },
                                      onSkip: { tutorialMaking = nil; tutorialComboDone = true })
                case .template:
                    TemplateTutorialView(onCreated: { tutorialCreated($0, chapter: .template) },
                                         onSkip: { tutorialMaking = nil; tutorialTemplateDone = true })
                case .makeTemplate:
                    // 여기로 오지 않는다(위에서 기존 화면으로 보낸다). 안전망.
                    Color.clear.onAppear { tutorialMaking = nil }
                }
            }
            // Toast 메시지 오버레이
            .overlay(alignment: .bottom) {
                toastOverlay
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: viewModel.showToast)

            // 순정 Inline Large 타이틀 — 맨 위에선 큰 제목이 바에 표시되고,
            // 스크롤이 내려가면 .inline(가운데 작은 제목)으로 전환(사용자 지정).
            // 페이저 안 스크롤은 시스템이 자동 추적하지 못해 trackPageScroll이
            // 오프셋을 보고 디스플레이 모드를 직접 전환한다.
            // 타이틀 뒤 배경 밴드는 각 ScrollView의 scrollEdgeEffectHidden이 막는다.
            .navigationTitle(currentCategoryTitle)
            #if os(iOS)
            .toolbarTitleDisplayMode(titleDisplayMode)
            // [디자인 불변식] 상·하단 배경 언제나 투명 — 정의는 alwaysTransparentBars() 참고.
            // TabView 전역 설정만으로는 이 화면의 스크롤뷰까지 확실히 닿지 않아
            // (하단 탭바 뒤 콘텐츠가 뿌옇게 바래는 회귀 발생) 로컬에도 명시한다.
            .alwaysTransparentBars()
            #endif
            .accessibilityLabel(NSLocalizedString("Saved items", comment: "Screen: main memo list"))
    }

    private var screenL3: some View {
        screenBody2
            .onChange(of: viewModel.searchQueryString) { _, _ in viewModel.applyFilters() }
            .onChange(of: viewModel.selectedTypeFilter) { _, _ in
                viewModel.applyFilters()
                viewModel.saveSelectedFilter()
            }
            .onChange(of: viewModel.showFavoritesFilter) { _, _ in viewModel.applyFilters() }
            // 인증 실패 Alert
    }

    private var screenL4: some View {
        screenL3
            .alert(NSLocalizedString("인증 실패", comment: "Auth failed"), isPresented: $viewModel.showAuthAlert) {
                Button(NSLocalizedString("확인", comment: "Confirm"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("보안 단축어에 접근하려면 생체 인증이 필요합니다", comment: "Biometric auth required"))
            }
            // 메모 삭제 확인 Alert
            .alert(
                NSLocalizedString("단축어 삭제", comment: "Delete memo alert title"),
                isPresented: Binding(
                    get: { memoToDelete != nil },
                    set: { if !$0 { memoToDelete = nil } }
                )
            ) {
                Button(NSLocalizedString("삭제", comment: "Confirm delete"), role: .destructive) {
                    if let memo = memoToDelete,
                       let idx = viewModel.memos.firstIndex(where: { $0.id == memo.id }) {
                        viewModel.deleteMemo(at: IndexSet(integer: idx))
                    }
                    memoToDelete = nil
                }
                Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {
                    memoToDelete = nil
                }
            } message: {
                if let memo = memoToDelete {
                    Text(String(format: NSLocalizedString("'%@'을(를) 삭제하시겠습니까? 이 작업은 취소할 수 없습니다.", comment: "Delete memo confirm message with title"), memo.title))
                } else {
                    Text(NSLocalizedString("이 작업은 취소할 수 없습니다.", comment: "Delete warning"))
                }
            }
            // 롱프레스 완료 후 액션 시트 (커스텀 bottom sheet)
            // iOS confirmationDialog/actionSheet는 시스템 디자인상 button systemImage를
            // 렌더링 안 함. 아이콘 표시를 위해 .sheet + MemoActionSheet 사용.
            // SwiftUI race 회피: sheet dismiss 후 0.35s 뒤에 memoToEdit/memoToDelete set.
            .sheet(isPresented: $showMemoActions) {
                if let memo = memoForActions {
                    MemoActionSheet(
                        memo: memo,
                        categories: viewModel.customCategories,
                        onCopy: {
                            HapticManager.shared.selection()
                            viewModel.copyMemo(memo: memo)
                        },
                        onToggleFavorite: {
                            HapticManager.shared.selection()
                            viewModel.toggleFavorite(memoId: memo.id)
                        },
                        onEdit: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                memoToEdit = memo
                            }
                        },
                        onDelete: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                memoToDelete = memo
                            }
                        },
                        onMoveToCategory: { category in
                            HapticManager.shared.selection()
                            viewModel.moveMemo(memo, toCategory: category)
                        },
                        onCreateNewCategory: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                memoForCategoryAssign = memo
                                newCategoryForMemo = ""
                                showNewCategoryForMemoAlert = true
                            }
                        },
                        onReorder: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                viewModel.enterReorderMode()
                            }
                        },
                        onMakeTemplate: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                makeTemplateSource = memo
                            }
                        },
                        onToggleSecure: {
                            HapticManager.shared.selection()
                            viewModel.toggleSecure(memoId: memo.id)
                        }
                    )
                }
            }
            // 순서 바꾸기 — 전체 메모 흔들기/드래그 재정렬 (전체화면)
    }

    private var screenL5: some View {
        screenL4
            .fullScreenCover(isPresented: $viewModel.isReorderMode) {
                reorderModeView
            }
            // 즐겨찾기 탭 + 버튼 — 즐겨찾기로 바로 저장
            .sheet(isPresented: $showAddFavoriteMemoSheet, onDismiss: { viewModel.loadMemos() }) {
                NavigationStack {
                    MemoAdd(insertedIsFavorite: true)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button(NSLocalizedString("취소", comment: "Cancel")) { showAddFavoriteMemoSheet = false }
                            }
                        }
                }
            }
            // 즐겨찾기 탭 오른쪽 스와이프 → 새 카테고리 생성 제안
            .confirmationDialog(
                NSLocalizedString("새로운 카테고리를 만들까요?", comment: "Swipe right favorites: create category dialog title"),
                isPresented: $showSwipeCategoryDialog,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("새 카테고리 만들기", comment: "Swipe right favorites: confirm create category")) {
                    newCategoryName = ""
                    showAddCategoryAlert = true
                }
                Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("즐겨찾기 단축어를 정리할 카테고리를 만들어볼까요?", comment: "Swipe right favorites: create category message"))
            }
    }

    private var screenL6: some View {
        screenL5
            .sheet(item: $memoToEdit, onDismiss: { viewModel.loadMemos() }) { memo in
                NavigationStack {
                    MemoAdd(
                        memoId: memo.id,
                        insertedKeyword: memo.title,
                        insertedValue: memo.value,
                        insertedCategory: memo.category,
                        insertedIsTemplate: memo.isTemplate,
                        insertedIsSecure: memo.isSecure
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(NSLocalizedString("취소", comment: "Cancel")) { memoToEdit = nil }
                        }
                    }
                }
            }
            // "템플릿으로 만들기" — 원본 내용으로 채운 별도 새 메모(memoId=nil). 본문 포커스로
            // 변수 삽입바를 바로 띄우고, 저장하면 원본은 그대로 둔 채 새 템플릿 메모가 생긴다.
            .sheet(item: $makeTemplateSource, onDismiss: {
                viewModel.loadMemos()
                // 튜토리얼로 열었던 거라면 여기서 그 장이 끝난다 — 저장했든 취소했든,
                // 이 화면을 한 번 본 것만으로 "있는 걸 바꿀 수 있다"는 건 전달됐다.
                if awaitingMakeTemplate {
                    awaitingMakeTemplate = false
                    tutorialMakeTemplateDone = true
                    inviteNextChapter(after: 0.5)
                }
            }) { src in
                NavigationStack {
                    MemoAdd(
                        insertedKeyword: src.title,
                        insertedValue: src.value,
                        insertedCategory: src.category,
                        startInTemplateMode: true,
                        templateSourceMemoId: src.id
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(NSLocalizedString("취소", comment: "Cancel")) { makeTemplateSource = nil }
                        }
                    }
                }
            }
            // 각종 Sheet Modifiers
            .modifier(SheetModifiers(
                showTemplateInputSheet: $viewModel.showTemplateInputSheet,
                showPlaceholderManagementSheet: $viewModel.showPlaceholderManagementSheet,
                selectedTemplateIdForSheet: $viewModel.selectedTemplateIdForSheet,
                selectedComboIdForSheet: $viewModel.selectedComboIdForSheet,
                templatePlaceholders: viewModel.templatePlaceholders,
                templateInputs: $viewModel.templateInputs,
                memos: viewModel.memos,
                currentTemplateMemo: viewModel.currentTemplateMemo,
                attachedTemplateBaseMemo: viewModel.attachedTemplateBaseMemo,
                onTemplateComplete: {
                    viewModel.confirmTemplateInput()
                },
                onTemplateCancel: { viewModel.showTemplateInputSheet = false },
                onTemplateCopy: { memo, processedValue in
                    viewModel.finalizeCopy(memo: memo, processedValue: processedValue)
                    viewModel.selectedTemplateIdForSheet = nil
                },
                onTemplateSheetCancel: { viewModel.selectedTemplateIdForSheet = nil },
                onComboDismiss: {
                    viewModel.selectedComboIdForSheet = nil
                    viewModel.loadMemos()
                }
            ))
            .onChange(of: livingSkinRaw) { _, _ in startGuestsIfNeeded() }
            .onAppear {
                startGuestsIfNeeded()
                viewModel.onAppear()
                fontSize = UserDefaults.standard.object(forKey: DefaultsKey.fontSize) as? CGFloat ?? 20.0
                // v4.1.0: 카테고리 기능 마이그레이션 — 기존 사용자 자동 활성
                CategoryStore.shared.migrateFeatureEnabledIfNeeded(
                    existingMemoCategories: viewModel.memos.map { $0.category }
                )
                // 첫 로드 시 stagger enter 트리거 (한 번만)
                if !hasAppeared {
                    SuggestionManager.shared.recordAppOpen()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        hasAppeared = true
                    }
                }
                // 앱을 두 번 이상 연 사용자에게만 빠른 메모 캡처 팁을 노출(첫날 도배 방지).
                if UserDefaults.standard.integer(forKey: DefaultsKey.appLaunchCount) >= 2 {
                    QuickNoteInboxTip.engaged = true
                }
            }
    }

    private var screenL7: some View {
        screenL6
            .paywall(isPresented: $showPaywallFromKeyboard, triggeredBy: nil)
            .onReceive(NotificationCenter.default.publisher(for: .showPaywall)) { _ in
                showPaywallFromKeyboard = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                viewModel.onSceneResume()
                consumePendingInboxOpen()
            }
            // 콜드 런치에서 didBecomeActive가 위 구독 설치보다 먼저 지나간 경우의 폴백.
            // (Control Center 컨트롤이 켠 보류 플래그를 첫 표시 시점에 소비 — 멱등이라 중복 무해)
            .onAppear { consumePendingInboxOpen() }
    }

    private var screenL8: some View {
        screenL7
            // '템플릿으로 만들기' 장만 목록에서 한다(고치는 일은 목록에서).
            // 무대가 이 알림을 쏘면 이미 있는 그 화면을 그대로 태운다.
            .onReceive(NotificationCenter.default.publisher(for: .startMakeTemplateTutorial)) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    awaitingMakeTemplate = true
                    makeTemplateSource = convertibleShortcut
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .demoSamplesInserted)) { _ in
                viewModel.loadCustomCategories()   // 시드된 카테고리 탭 반영
                viewModel.loadMemos()
            }
            .navigationDestination(isPresented: $showInboxFromIntent) {
                QuickNoteInboxView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openQuickNoteInbox)) { _ in
                // 알림 경로로 처리했으면 보류 플래그도 함께 소비(다음 활성화 때 중복 열림 방지).
                UserDefaults(suiteName: AppGroup.identifier)?.set(false, forKey: DefaultsKey.pendingOpenQuickNoteInbox)
                showInboxFromIntent = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .openQuickNoteAdd)) { _ in
                UserDefaults(suiteName: AppGroup.identifier)?.set(false, forKey: DefaultsKey.pendingQuickNoteAdd)
                showQuickNoteAdd = true
            }
    }

    // MARK: - 배경 이미지 (선택)

    /// 제공되는 배경 이미지 에셋 이름들. 빈 문자열 = 배경 없음(예전 모습 그대로).
    static let backgroundOptions: [String] = (1...8).map { String(format: "ListBackground%02d", $0) }

    @AppStorage(DefaultsKey.listBackgroundImageV1, store: UserDefaults(suiteName: AppGroup.identifier))
    private var listBackgroundImage: String = ""
    @AppStorage(DefaultsKey.backgroundOfferResolvedV1, store: UserDefaults(suiteName: AppGroup.identifier))
    private var backgroundOfferResolved: Bool = false
    @State private var showBackgroundOffer = false
    @State private var showBackgroundPicker = false

    /// 탭별 배경 덮어쓰기 [CategoryTab.storageKey: 에셋 이름]. ""는 "이 탭만 배경 없음".
    /// 항목이 없는 탭은 전체 기본값(listBackgroundImage)을 따른다.
    @State private var perTabBackgrounds: [String: String] = [:]
    /// 배경 선택 시트의 적용 범위 — 현재 탭만 / 모든 탭.
    @State private var backgroundScopeAllTabs = false

    /// 현재 탭에 실제로 보여줄 배경 — 탭 덮어쓰기 우선, 없으면 전체 기본값.
    private var resolvedBackgroundImage: String {
        perTabBackgrounds[viewModel.selectedCategoryTab.storageKey] ?? listBackgroundImage
    }

    private func loadPerTabBackgrounds() {
        perTabBackgrounds = (UserDefaults(suiteName: AppGroup.identifier)?
            .dictionary(forKey: DefaultsKey.listBackgroundPerTabV1) as? [String: String]) ?? [:]
    }

    private func persistPerTabBackgrounds() {
        UserDefaults(suiteName: AppGroup.identifier)?
            .set(perTabBackgrounds, forKey: DefaultsKey.listBackgroundPerTabV1)
    }

    /// 배경 선택 적용 — 범위에 따라 현재 탭 덮어쓰기 또는 전체 기본값(+탭 덮어쓰기 초기화).
    private func applyBackground(_ name: String) {
        HapticManager.shared.selection()
        withAnimation(.easeInOut(duration: 0.25)) {
            if backgroundScopeAllTabs {
                listBackgroundImage = name
                perTabBackgrounds = [:]
            } else {
                perTabBackgrounds[viewModel.selectedCategoryTab.storageKey] = name
            }
        }
        persistPerTabBackgrounds()
    }

    /// 배경 제안을 꺼낼 때가 됐는지.
    ///
    /// ⚠️ 예전에는 **설치 첫날 1초 만에** 물었다. 아직 뭐 하는 앱인지도 모르는 사람에게
    ///    "배경 사진 깔아볼래요?"를 들이미는 셈이라, 대부분 그냥 닫고 그걸로 끝이었다
    ///    (한 번 닫으면 다시 안 뜬다 — 가장 좋은 기능을 첫날에 태워 없앤 것).
    ///
    /// 두 가지를 모두 만족해야 꺼낸다:
    ///  ① 설치 후 **최소 일주일** — 꾸미기는 도구가 손에 익은 다음의 즐거움이다.
    ///  ② 단축어가 어느 정도 쌓였을 것 — 카드가 몇 장 없는 화면에 배경을 깔면
    ///     살아나기는커녕 휑한 게 더 드러난다.
    private static let backgroundOfferMinDays: Double = 7
    private static let backgroundOfferMinMemos = 3

    private var isReadyForBackgroundOffer: Bool {
        guard viewModel.memos.count >= Self.backgroundOfferMinMemos else { return false }
        // 설치일이 없으면(아직 기록 전) 아직 이르다고 본다 — 일찍 묻느니 늦게 묻는다.
        guard let installed = UserDefaults.standard.object(forKey: "app_install_date") as? Date else {
            return false
        }
        return Date().timeIntervalSince(installed) >= Self.backgroundOfferMinDays * 86_400
    }

    /// 썸네일 선택 표시 기준 — 현재 범위에서 그 이미지가 적용돼 있는지.
    private func isBackgroundSelected(_ name: String) -> Bool {
        backgroundScopeAllTabs ? (listBackgroundImage == name) : (resolvedBackgroundImage == name)
    }

    var body: some View {
        NavigationStack {
            screenL8
                // 배경 이미지(선택) — 유리 카드 뒤로 비치는 사진. 기본은 없음.
                // 탭별 덮어쓰기 지원: 탭을 넘기면 그 탭의 배경으로 부드럽게 교차.
                .background {
                    if !resolvedBackgroundImage.isEmpty {
                        Image(resolvedBackgroundImage)
                            .resizable()
                            .scaledToFill()
                            .ignoresSafeArea()
                            .transition(.opacity)
                            .id(resolvedBackgroundImage)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: resolvedBackgroundImage)
                // 새 배경 기능 1회 제안 — 아니요면 예전 모습 그대로, 써보면 기본 배경 적용.
                .alert(
                    NSLocalizedString("새로운 배경을 써보시겠어요?", comment: "Background offer alert title"),
                    isPresented: $showBackgroundOffer
                ) {
                    Button(NSLocalizedString("써볼게요", comment: "Accept category activation")) {
                        backgroundOfferResolved = true
                        withAnimation { listBackgroundImage = Self.backgroundOptions[0] }
                        showBackgroundPicker = true
                    }
                    Button(NSLocalizedString("괜찮아요", comment: "Decline category activation"), role: .cancel) {
                        backgroundOfferResolved = true
                        listBackgroundImage = ""
                    }
                } message: {
                    Text(NSLocalizedString("리스트 뒤에 사진을 깔면 유리 카드가 살아나요. 언제든 오른쪽 위 ⋯ 메뉴 > 배경 이미지에서 바꾸거나 끌 수 있어요.", comment: "Background offer alert message"))
                }
                .sheet(isPresented: $showBackgroundPicker) {
                    backgroundPickerSheet
                }
                .onAppear {
                    loadPerTabBackgrounds()
                    guard !backgroundOfferResolved, isReadyForBackgroundOffer else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showBackgroundOffer = true
                    }
                }
        }
    }

    /// 배경 이미지 선택 시트 — 없음 + 8종 썸네일 그리드, 탭 즉시 적용.
    /// 적용 범위: 현재 탭만(탭별 덮어쓰기) 또는 모든 탭(기본값 교체 + 덮어쓰기 초기화).
    private var backgroundPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("", selection: $backgroundScopeAllTabs) {
                        Text(String(format: NSLocalizedString("'%@' 탭만", comment: "Background scope: current tab only, with tab name"),
                                    viewModel.selectedCategoryTab.displayName))
                            .tag(false)
                        Text(NSLocalizedString("모든 탭", comment: "Background scope: all tabs"))
                            .tag(true)
                    }
                    .pickerStyle(.segmented)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                        // 없음(배경 끄기)
                        Button {
                            applyBackground("")
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                                    .fill(theme.surfaceAlt)
                                VStack(spacing: 6) {
                                    Image(systemName: "slash.circle")
                                        .font(.title2)
                                    Text(NSLocalizedString("없음", comment: "Background: none"))
                                        .font(.footnote.weight(.medium))
                                }
                                .foregroundColor(theme.textMuted)
                            }
                            .frame(height: 150)
                            .overlay(backgroundSelectionBadge(selected: isBackgroundSelected("")))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(NSLocalizedString("배경 없음", comment: "Background: none a11y"))

                        ForEach(Self.backgroundOptions, id: \.self) { name in
                            Button {
                                applyBackground(name)
                            } label: {
                                Image(name)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 150)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
                                    .overlay(backgroundSelectionBadge(selected: isBackgroundSelected(name)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(NSLocalizedString("배경 이미지", comment: "Menu: list background image"))
                        }
                    }
                }
                .padding(16)
            }
            .background(theme.bg)
            .navigationTitle(NSLocalizedString("배경 이미지", comment: "Menu: list background image"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("완료", comment: "Done")) { showBackgroundPicker = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// 선택된 썸네일 표시 — 파란 테두리 + 체크 뱃지.
    @ViewBuilder
    private func backgroundSelectionBadge(selected: Bool) -> some View {
        if selected {
            RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                .strokeBorder(Color.accentColor, lineWidth: 3)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: AppSymbol.checkmarkCircleFill)
                        .font(.title3)
                        .foregroundStyle(.white, Color.accentColor)
                        .padding(6)
                }
        }
    }

    /// + 메뉴의 "임시 저장" 항목 라벨(개수 배지).
    private var draftMenuTitle: String {
        let count = DraftStore.shared.count
        return count > 0
            ? String(format: NSLocalizedString("임시 저장 (%d)", comment: "Menu: drafts with count"), count)
            : NSLocalizedString("임시 저장 보기", comment: "Menu: view drafts")
    }

    /// 더보기 메뉴의 보관함 항목 라벨(개수 배지). 메뉴는 열릴 때 다시 만들어지므로 직접 읽어도 충분.
    private var inboxMenuTitle: String {
        let count = QuickNoteStore.shared.count
        return count > 0
            ? String(format: NSLocalizedString("메모 보관함 (%d)", comment: "Menu: quick note inbox with count"), count)
            : NSLocalizedString("메모 보관함", comment: "Menu: quick note inbox")
    }

    /// Control Center 컨트롤·딥링크가 켜둔 보류 플래그를 소비한다(앱 활성화 시).
    /// - 빠른 메모 컨트롤: 입력 시트 표시 / - 보관함 열기 컨트롤: Inbox 화면 이동.
    private func consumePendingInboxOpen() {
        let store = UserDefaults(suiteName: AppGroup.identifier)
        if store?.bool(forKey: DefaultsKey.pendingQuickNoteAdd) == true {
            store?.set(false, forKey: DefaultsKey.pendingQuickNoteAdd)
            print("🎛️ [ClipKeyboardList] 제어센터 보류 플래그 소비 → 빠른 메모 입력 시트")
            showQuickNoteAdd = true
        }
        if store?.bool(forKey: DefaultsKey.pendingOpenQuickNoteInbox) == true {
            store?.set(false, forKey: DefaultsKey.pendingOpenQuickNoteInbox)
            print("🎛️ [ClipKeyboardList] 제어센터 보류 플래그 소비 → 보관함 열기")
            showInboxFromIntent = true
        }
    }

    // MARK: - View Sections

    /// 검색 바 섹션 (인라인)
    private var searchBarInlineSection: some View {
        HStack(spacing: 8) {
            Image(systemName: AppSymbol.magnifyingglass)
                .foregroundColor(theme.textFaint)
                .font(.body)
                .accessibilityHidden(true)

            TextField(NSLocalizedString("검색", comment: "Search"), text: $viewModel.searchQueryString)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .accessibilityLabel(NSLocalizedString("단축어 검색", comment: "Search field accessibility label"))
                .accessibilityHint(NSLocalizedString("단축어 제목 또는 내용으로 검색합니다", comment: "Search field accessibility hint"))

            if !viewModel.searchQueryString.isEmpty {
                Button(action: {
                    HapticManager.shared.soft()
                    viewModel.searchQueryString = ""
                }) {
                    Image(systemName: AppSymbol.xmarkCircleFill)
                        .foregroundColor(theme.textFaint)
                        .font(.body)
                }
                .accessibilityLabel(NSLocalizedString("검색어 지우기", comment: "Clear search field"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.surfaceAlt)
        .cornerRadius(theme.radiusSm)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Grid

    /// 한 줄에 놓을 카드 수. 아이폰 2열 / 아이패드·맥 4열.
    ///
    /// ⚠️ `.adaptive(minimum:)` 을 쓰면 **안 된다.** 이 그리드는 `TabView(.page)` 안의
    ///    `ScrollView` 에 들어 있는데, 그 조합에서는 LazyVGrid 에 폭이 제대로 제안되지 않아
    ///    `.adaptive` 가 열 수를 1로 계산해 카드가 화면 전체로 늘어난다(실제로 그렇게 깨졌다).
    ///    `.flexible()` 은 폭 측정 없이 "가용 공간을 n등분"이라 이 문제가 없다.
    ///    그래서 열 수는 **측정이 아니라 size class 로** 정한다.
    private var gridColumnCount: Int { horizontalSizeClass == .regular ? 4 : 2 }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: gridColumnCount)
    }

    /// 고스트(가상) 메모 셀 — 실제 메모 셀과 같은 치수·제목 스타일을 그대로 쓰되
    /// 반투명 + 점선 테두리로 "아직 실재하지 않는 제안"임을 표현. 탭하면 채워서
    /// 추가하는 편집기로 진입(사용자가 한 번 눌러보고 판단).
    private func ghostMemoCell(pattern: QuickPattern) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                // 아이콘을 그냥 띄워 두면 붕 뜬다 — 원형 배지에 담아야 만들다 만 게 아니라
                // 만들어 둔 것으로 보인다.
                Image(systemName: AppSymbol.sparkles)
                    .font(.footnote.weight(.bold))
                    .foregroundColor(theme.accent)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(theme.accent.opacity(0.14)))
                    .accessibilityHidden(true)
                Spacer()
                Button {
                    HapticManager.shared.soft()
                    dismissGhostPattern(pattern)
                    // 닫으면 이번 세션 + 이후 영구히 제안하지 않는다 (다음 것/재실행 후에도 안 뜸).
                    Self.ghostSuppressedThisSession = true
                    UserDefaults.standard.set(true, forKey: ghostSuggestionsOffKey)
                    if reduceMotion {
                        ghostSuggestion = nil
                    } else {
                        // 현재 제안이 점차 작아지면서 사라진다. (다음 제안을 부르지 않음)
                        withAnimation(.easeIn(duration: 0.22)) { ghostSuggestion = nil }
                    }
                } label: {
                    Image(systemName: AppSymbol.xmark)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(theme.textFaint)
                        .padding(4)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(NSLocalizedString("닫기", comment: "Close / dismiss"))
            }
            Spacer(minLength: 16)
            Text(pattern.title)
                .font(.title2.weight(.semibold))
                .foregroundColor(theme.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            // 흐린 안내문 대신 **누를 것**처럼 생긴 알약. 이 카드의 일은 눌리는 것이다.
            HStack(spacing: 4) {
                Image(systemName: AppSymbol.plus)
                    .font(.caption2.weight(.bold))
                Text(NSLocalizedString("눌러서 추가해보기", comment: "Ghost memo: tap to try"))
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(theme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(theme.accent.opacity(0.12)))
            .padding(.top, 8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: memoCardHeight, alignment: .topLeading)
        // ⚠️ 반투명 위에 또 반투명을 얹지 않는다. 예전에는 surface 0.5 에 opacity 0.85 까지
        //    겹쳐서 두 번 흐려졌고, 옅은 회색 점선까지 더해져 **만들다 만 카드**로 보였다.
        //    제안은 흐릿한 게 아니라 **아직 안 만든 것**이다 — 또렷하되 색으로 구분한다.
        .background(
            RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
                .fill(theme.accent.opacity(0.07))
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
                .strokeBorder(theme.accent.opacity(0.28), lineWidth: 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous))
        .onTapGesture {
            HapticManager.shared.selection()
            ghostAddPattern = pattern
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(String(format: NSLocalizedString("추천 단축어 %@", comment: "VoiceOver: suggested memo"), pattern.title))
        .accessibilityHint(NSLocalizedString("눌러서 채워서 추가해보기", comment: "VoiceOver: ghost memo hint"))
        // 제안 교체 시 작은 네모에서 커지며 등장 / 닫으면 작아지며 사라지는 트랜지션.
        // 패턴이 바뀌면 id가 달라져 퇴장→등장이 분리되어 애니메이션된다.
        .id(pattern.title)
        .transition(.scale(scale: 0.2, anchor: .center).combined(with: .opacity))
    }

    private func memoGridCell(memo: Memo) -> some View {
        let isActive = longPressActiveMemo?.id == memo.id
        let holdDuration: Double = 0.65
        // progress fill을 trigger보다 살짝 짧게 — 시뮬 환경에서 onLongPressGesture가
        // 미세하게 일찍 fire되는 경우가 있어 "원이 아직 안 찼는데 시트 뜸" 현상을
        // 방지하기 위함. 사용자는 0.5s에 원이 가득 차는 걸 보고 0.65s까지 누르면 시트.
        let progressFillDuration: Double = 0.5

        // Button + onLongPressGesture 조합이 iOS 17+에서 long press를 가로채는 경우가 있어
        // 일반 View + onTapGesture + onLongPressGesture 패턴으로 분리. 시각 affordance는
        // 그대로 유지 (button trait 명시 + tap 햅틱).
        let skirtDepth = cardSkirtDepth(lightweight: false)

        return memoCardSurface(memo: memo)
        // 손님(새·고양이)은 카드 밖으로 넘쳐야 해서 clip 바깥에 얹는다.
        // 카드 한 장 위에서만 벌어진다 — 격자는 스크롤·재정렬되므로 전역 경로를 못 쓴다.
        .overlay(alignment: .topLeading) {
            if livingSkin.isVisitor, guestScheduler.hostId == memo.id {
                GeometryReader { geo in
                    GuestCreature(kind: livingSkin, cardWidth: geo.size.width)
                        .position(x: geo.size.width * 0.32, y: 0)
                }
                .allowsHitTesting(false)
            }
        }
        // 방금 쓴 카드에 잠깐 켜지는 테두리.
        // ⚠️ 조건부로 뷰를 끼웠다 빼지 않고 **불투명도만** 바꾼다 —
        //    끼웠다 빼면 나타날 때 끊겨 보이고, 사라질 때 애니메이션이 안 걸린다.
        .overlay {
            RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
                .strokeBorder(theme.accent, lineWidth: 2.5)
                .opacity(glowMemoID == memo.id ? 1 : 0)
                .allowsHitTesting(false)
        }
        // 코치가 가리킬 카드의 자리를 알려준다 — 안내를 화면 아래에 고정해 두면
        // 무엇을 누르라는 건지 이어지지 않는다.
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: CoachAnchorKey.self,
                    value: coachMemoID == memo.id ? geo.frame(in: .global) : .zero
                )
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous))
        // 누름 — 스킨에 따라 두 방식으로 갈린다.
        //
        // 두께가 있으면 **키캡처럼** 바닥까지 내려앉았다 돌아온다.
        // 두께가 없으면(납작·예전 방식) 내려앉을 바닥이 없으므로 **예전의 푹신한 바운스**로
        // 되돌린다 — 그러지 않으면 눌러도 아무 반응이 없는 죽은 카드가 된다.
        .modifier(CardPressEffect(
            trigger: bounceTriggers[memo.id] ?? 0,
            legacyBounce: keycapSkin.usesLegacyCardBounce,
            depth: skirtDepth,
            pressDuration: keycapSkin.pressDuration,
            skirt: { dy in cardSkirt(depth: skirtDepth, offsetY: dy) }
        ))
        // 좌표를 받는 탭 — 동전이 **손가락이 닿은 자리**에서 튀어야 인과가 보인다.
        // 카드 중심에서 튀면 어느 카드를 눌렀는지는 알아도 내가 눌렀다는 느낌이 약하다.
        //
        // ⚠️ `.global` 이라야 한다. 이름 붙인 좌표계는 카드가 ScrollView 안쪽 깊이 있어
        //    닿지 않았고, 그 바람에 어느 카드를 눌러도 동전이 화면 왼쪽 위에서 날아갔다.
        .onTapGesture(coordinateSpace: .global) { location in
            HapticManager.shared.selection() // 탭: 선택 햅틱
            if !reduceMotion { bounceTriggers[memo.id, default: 0] += 1 } // 푹신 바운스 재생
            // 동전은 여기서 날리지 않는다. 콤보·템플릿은 아직 **쓴 게 아니라** 시트가 뜰 뿐이라,
            // 실제 사용이 확정될 때(.memoUsed) 날린다. 자리만 기억해 둔다.
            lastTapPoint = location
            viewModel.copyMemo(memo: memo)
            checkCategoryBadgeNudge()
            #if os(iOS)
            if UIAccessibility.isVoiceOverRunning {
                let msg = String(format: NSLocalizedString("%@ 복사됨", comment: "VoiceOver: copied announcement"), memo.title)
                UIAccessibility.post(notification: .announcement, argument: msg)
            }
            #endif
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        // 롱프레스 감아지는 테두리 오버레이
        .overlay {
            RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
                .trim(from: 0, to: isActive ? longPressProgress : 0)
                .stroke(theme.accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .animation(
                    isActive
                        ? .linear(duration: progressFillDuration)
                        : .easeOut(duration: 0.18),
                    value: longPressProgress
                )
                .allowsHitTesting(false)
        }
        .onLongPressGesture(minimumDuration: holdDuration, maximumDistance: 20) {
            // 완료 — 진행 완료 햅틱 후 액션 메뉴 표시
            HapticManager.shared.heavy()
            longPressActiveMemo = nil
            longPressProgress = 0
            memoForActions = memo
            showMemoActions = true
        } onPressingChanged: { isPressing in
            if isPressing {
                longPressActiveMemo = memo
                longPressProgress = 0
                // 프로세스 진행 햅틱: 시작(light) → 중간(medium) → 완료 직전(medium)
                HapticManager.shared.light()
                DispatchQueue.main.asyncAfter(deadline: .now() + progressFillDuration * 0.45) {
                    guard self.longPressActiveMemo?.id == memo.id else { return }
                    HapticManager.shared.medium()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + progressFillDuration * 0.85) {
                    guard self.longPressActiveMemo?.id == memo.id else { return }
                    HapticManager.shared.medium()
                }
                withAnimation(.linear(duration: progressFillDuration)) {
                    longPressProgress = 1.0
                }
            } else {
                // 중간에 뗌 — 테두리 되감기
                withAnimation(.easeOut(duration: 0.18)) {
                    longPressProgress = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if self.longPressActiveMemo?.id == memo.id {
                        self.longPressActiveMemo = nil
                    }
                }
            }
        }
        .accessibilityLabel(memoGridAccessibilityLabel(memo))
        .accessibilityHint(NSLocalizedString("탭하면 클립보드에 복사, 꾹 누르면 추가 옵션", comment: "Memo card hint"))
    }

    /// 메모 카드의 순수 비주얼(제스처 없음). memoGridCell(탭/롱프레스)과 재정렬 모드 셀이 공유.
    /// - Parameter lightweight: 재정렬 그리드용 경량 렌더링 — 그림자와 내용 힌트 애니메이션을
    ///   생략한다. 흔들림(repeatForever 회전)과 매 프레임 경합하는 비용을 줄여 드래그를 매끄럽게.
    private func memoCardSurface(memo: Memo, lightweight: Bool = false) -> some View {
        let imageFileName = memo.imageFileNames.first ?? memo.imageFileName ?? ""
        let hasImage = !imageFileName.isEmpty
        let onColor = cardIsColored(memo: memo, hasImage: hasImage)

        return VStack(alignment: .leading, spacing: 0) {
            // 구분 표시 ON일 때만 상단 행(좌: 타입 아이콘 / 우: 즐겨찾기·카테고리 심볼). 기본은 제목만.
            if visualCuesVisible {
                HStack(alignment: .top, spacing: 4) {
                    // 보안 메모는 제목 왼쪽 자물쇠로 표시하므로 상단 타입 아이콘에서는 생략(중복 방지).
                    if !memo.isSecure {
                        memoTypeIcon(memo: memo, onColor: onColor)
                    }
                    Spacer()
                    if memo.isFavorite {
                        Image(systemName: AppSymbol.heartFill)
                            .font(.title2)
                            .foregroundColor(onColor ? .white.opacity(0.9) : .clipFavorite)
                            .accessibilityHidden(true)
                    } else if CategoryStore.shared.isFeatureEnabled,
                              viewModel.customCategories.contains(memo.category) {
                        Image(systemName: customCategoryIcon(memo.category))
                            .font(.title2)
                            .foregroundColor(onColor
                                ? .white.opacity(0.85)
                                : customCategoryColor(memo.category))
                            .accessibilityHidden(true)
                    }
                }
                Spacer(minLength: 16)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // 보안 메모 자물쇠 — 구분 표시 ON일 때만 (기본은 심볼 없이 제목만).
                if visualCuesVisible, memo.isSecure {
                    Image(systemName: AppSymbol.lockFill)
                        .font(.title3)
                        .foregroundColor(onColor ? .white.opacity(0.9) : theme.textMuted)
                        .accessibilityHidden(true)
                }
                // 템플릿 변수 {…}는 카드 제목에서도 원문이 아닌 칩(하이라이트)으로.
                Text(memo.title.templateAwareAttributed(theme: theme, font: .title2.weight(.semibold)))
                    .font(.title2.weight(.semibold))
                    .foregroundColor(onColor ? .white : theme.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 제목 아래 내용 힌트 — 카드가 화면에 2초쯤 머물면 한 번 살며시 맺혔다가
            // 흩어지듯 사라진다(이번 등장에서는 끝). 설정(메모 표시)에서 켜기/끄기.
            // 켜져 있으면 카드 높이 균일성을 위해 영역은 항상 확보(보안 메모 등은
            // 빈 공간), 꺼져 있으면 영역 자체가 없다.
            if contentHintEnabled {
                Spacer(minLength: 8)
                // 방금 쓴 카드는 이 자리에 **내용 대신 동전**을 보여준다.
                // 겹쳐 얹으면 내용이 안 읽히고, 옆에 두면 카드 높이가 흔들린다.
                // 같은 자리를 번갈아 쓰면 둘 다 해결된다.
                if !lightweight, showsCoin(memo) {
                    VaultCardBadge(savedSeconds: VaultLedger.earnedSeconds(
                        characterCount: memo.value.count, useCount: memo.clipCount),
                                   onColor: onColor)
                        .frame(height: ContentHintPreview.zoneHeight, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .scale(scale: 0.7, anchor: .leading)))
                } else if !lightweight, let hint = fishbowlText(memo: memo) {
                    ContentHintPreview(text: hint, seed: memo.id.hashValue, onColor: onColor)
                } else {
                    Color.clear.frame(height: ContentHintPreview.zoneHeight)
                }
            }
        }
        // 유리 카드 글자 가독성 — 맑은 유리는 뒤 배경(사진·색)에 따라 글자가 묻힐 수 있어,
        // 글 내용 뒤에 은은한 할로를 깐다. 흰 글자(색 유리)는 어두운 할로,
        // 테마색 글자(무색 유리)는 테마 배경색 할로 — 배경이 무엇이든 최소 대비 확보.
        // 이미지 카드는 자체 그라디언트가 가독성을 책임지므로 제외.
        .compositingGroup()
        .shadow(color: hasImage ? .clear : (onColor ? Color.black.opacity(0.55) : theme.bg),
                radius: 4, x: 0, y: 0)
        .padding(16)
        // 모든 메모 셀 동일 높이: 제목 2줄(최대 콘텐츠)보다 큰 값으로 floor를 잡아
        // 1줄·2줄 제목 모두 같은 높이로 정렬되게 한다. (제목은 2줄로 제한)
        .frame(maxWidth: .infinity, minHeight: memoCardHeight, alignment: .topLeading)
        // 배경: 이미지 카드는 사진 그대로. 텍스트 카드는 리퀴드 글래스(아래 CardGlass)가
        // 배경을 대신하되, 경량(재정렬) 모드에선 글래스가 프레임마다 비싸 단색으로 폴백.
        .background {
            if hasImage || lightweight {
                memoCardBackground(memo: memo, imageFileName: imageFileName, hasImage: hasImage)
            } else {
                // 맑은 유리 뒤에 깔리는 옅은 판 — 유리가 배경에 묻히지 않게 잡아 준다.
                // 투명도는 여기 한 곳(CardGlass.backingOpacity)에서만 조절한다.
                theme.surface.opacity(CardGlass.backingOpacity)
            }
        }
        // 생활 레이어(마을·눈+발자국) — **글자 뒤, 카드 표면 위.**
        // overlay로 얹으면 눈 베일과 발자국이 제목을 덮어 글이 묻힌다.
        .background {
            livingLayer(memo: memo, lightweight: lightweight)
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous))
        // 텍스트 카드 리퀴드 글래스(iOS 26 순정 glassEffect) — 카테고리 색은 tint로 유지.
        .modifier(CardGlass(
            active: !hasImage && !lightweight,
            tint: cardGlassTint(memo: memo),
            cornerRadius: theme.radiusXl
        ))
        // 타입 테두리 — 키보드 익스텐션과 동일(템플릿 보라/콤보 주황 dash/보안 회색 dot).
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
                .strokeBorder(memoTypeBorder(memo).color,
                              style: StrokeStyle(lineWidth: memoTypeBorder(memo).lineWidth,
                                                 dash: memoTypeBorder(memo).dash))
        )
        // 경량 모드(재정렬)에선 그림자 생략 — 회전하는 카드의 그림자는 매 프레임 오프스크린
        // 렌더링을 유발해 흔들림+드래그 시 버벅임의 주요 원인이 된다.
        .shadow(color: lightweight ? .clear : .black.opacity(0.10),
                radius: lightweight ? 0 : 8, x: 0, y: lightweight ? 0 : 4)
    }

    // MARK: - 생활 레이어

    /// 손님 스케줄러를 현재 스킨에 맞춰 켜거나 끈다.
    /// 스케줄러가 저전력 모드·동작 줄이기를 스스로 확인하므로 여기서는 재료만 넘긴다.
    private func startGuestsIfNeeded() {
        guestScheduler.start(
            skin: livingSkin,
            // 화면 위쪽 카드들만 후보 — 스크롤 밖에서 손님이 오가면 아무도 못 본다.
            candidates: { viewModel.memos.prefix(12).map(\.id) },
            reduceMotion: reduceMotion
        )
    }

    /// 카드 위에 사는 것 — 물성 스킨과 다른 층이라 겹쳐 쓸 수 있다.
    private var livingSkin: LivingSkin {
        LivingSkin.resolved(livingSkinRaw)
    }

    // MARK: - 금고

    /// 네비게이션 바 왼쪽에 서 있는 작은 금고. 동전의 목적지이자 금고 화면으로 가는 문.
    ///
    /// ⚠️ 처음에는 목록 위에 **띄워** 뒀는데 지저분했다. 스크롤되는 카드 위에 붙박이로
    ///    떠 있는 물건은 어디에 두든 무언가를 가린다. 바에 들어가면 자리를 다투지 않는다.
    ///    (본문 좌표계 밖이라 예전엔 못 넣었지만, 좌표를 전부 global 로 바꾼 뒤로는 된다.)
    ///
    /// ⚠️ 금고 스킨을 고른 사람에게만 보인다. 마을을 고른 사람의 바에 금고가 서 있으면
    ///    자기가 고른 것과 다른 것이 얹힌 셈이다.
    @ViewBuilder
    private var vaultEntrance: some View {
        if livingSkin == .vault || livingSkin == .geode {
            // 금고는 시간을, 지오드는 보석을 센다 — 모이는 자리는 같고 세는 것만 다르다.
            VaultButton(savedSeconds: vaultSeconds,
                        collects: livingSkin == .geode ? .gem : .coin,
                        deposit: vaultDeposit) {
                HapticManager.shared.light()
                showVault = true
            }
        }
    }

    /// 지금 무언가 시트가 떠 있는가. 떠 있으면 동전은 기다린다.
    private var anyModalUp: Bool {
        viewModel.selectedComboIdForSheet != nil
            || viewModel.selectedTemplateIdForSheet != nil
            || viewModel.showTemplateInputSheet
    }

    /// 카드에 동전을 잠깐 보여주는 시간(초). 이 동안 그 카드는 내용 대신 동전을 보여준다.
    private static let coinBadgeDwell: Double = 0.9

    /// 문구를 실제로 썼다는 신호를 받았다.
    ///
    /// 탭 시점이 아니라 **사용 확정 시점**에 불린다. 탭에서 처리하면 콤보·템플릿처럼
    /// 시트가 뜨는 경로에서 아직 쓰지도 않았는데 동전이 날아간다.
    private func handleMemoUsed(_ note: Notification) {
        guard let memoID = note.userInfo?[MemoUsedKey.memoID] as? UUID else { return }

        if livingSkin == .geode { handleGeodeUse(memoID: memoID) }
        lightUpCard(memoID)

        // 만든 걸 실제로 써 봤다 → 붙여넣기까지 이어서 데려간다.
        //
        // ⚠️ 클립보드를 읽어 값을 알아내지 않는다. iOS 16+ 는 읽을 때마다
        //    "붙여넣기 허용" 프롬프트를 띄워서, 가르치려던 동작을 시스템 팝업으로 가로챈다.
        //    이 연습은 온보딩에서 만든 평범한 문구에만 붙으므로 memo.value 가 곧 복사된 값이다.
        if coachMemoID == memoID {
            let chapter = coachChapter
            withAnimation(.easeOut(duration: 0.25)) { coachMemoID = nil; coachChapter = nil }

            // 복사했으면 **어느 장이든** 붙여넣기까지 데려간다.
            // 복사는 앱이 해 준 일이고, 값어치는 그다음에 안 친 것에 있다 — 그건 콤보도 같다.
            let copied = (note.userInfo?[MemoUsedKey.copiedText] as? String) ?? ""
            if let chapter { markDone(chapter) }
            if !copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    pastePractice = PastePracticeRequest(value: copied)
                }
            } else {
                inviteNextChapter(after: 0.6)
            }
        }

        guard livingSkin == .vault else { return }
        let seconds = note.userInfo?[MemoUsedKey.earnedSeconds] as? Double ?? 0

        vaultSeconds = KeyboardUsageTracker.totalTimeSavedSeconds()

        // 시트가 떠 있으면 동전은 그 뒤에 가려 보이지 않는다. 다 닫힌 뒤에 날린다.
        guard !anyModalUp else {
            pendingDeposit = (memoID, seconds, lastTapPoint)
            return
        }
        showCoinThenFly(memoID: memoID, seconds: seconds, from: lastTapPoint)
    }

    /// 방금 쓴 카드의 테두리를 1초 뒤에 켰다가 서서히 끈다.
    ///
    /// 왜 바로가 아니라 1초 뒤인가: 누른 순간에는 이미 눌림·햅틱·동전이 한꺼번에 일어난다.
    /// 거기 테두리까지 겹치면 무엇 하나 안 읽힌다. 동전이 금고에 닿을 즈음 뒤늦게 켜져야
    /// **"방금 그 카드가 일했다"**가 따로 읽힌다.
    private func lightUpCard(_ memoID: UUID) {
        guard Delight.isEnabled else { return }
        let fadeIn: Animation? = reduceMotion ? nil : .easeOut(duration: 0.25)
        let fadeOut: Animation? = reduceMotion ? nil : .easeIn(duration: 0.6)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(fadeIn) { glowMemoID = memoID }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 그 사이 다른 카드를 눌렀으면 그쪽이 주인이다 — 뺏지 않는다.
                if glowMemoID == memoID { withAnimation(fadeOut) { glowMemoID = nil } }
            }
        }
    }

    /// 지오드를 한 단계 깨뜨린다. 세 번째면 터뜨리고 보석을 날려 보낸다.
    ///
    /// 단계는 사용 횟수에서 계산하므로 여기서 따로 저장할 것이 없다 —
    /// 저장하면 언젠가 화면과 기록이 어긋난다.
    private func handleGeodeUse(memoID: UUID) {
        guard let memo = viewModel.memos.first(where: { $0.id == memoID }) else { return }
        // ⚠️ 알림은 저장 직후·목록 갱신 **전에** 온다(finalizeCopy 참고). 그래서 여기 있는
        //    clipCount 는 이번 사용을 아직 안 센 값이다. 하나를 더해야 맞다.
        guard GeodeStage.yieldsGem(afterUseCount: memo.clipCount + 1) else { return }

        guard Delight.isEnabled, !reduceMotion else {
            vaultDeposit.arriveSilently()
            return
        }

        let point = lastTapPoint
        withAnimation { burstingMemoID = memoID }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if burstingMemoID == memoID { withAnimation { burstingMemoID = nil } }
            vaultDeposit.launch(from: point, seconds: 0, payload: .gem)
        }
    }

    /// 카드에 동전을 먼저 보여주고, 사라지면서 금고로 날린다.
    ///
    /// 순서가 값어치다 — 동전과 내용이 **같은 자리를 동시에 쓰지 않는다.**
    /// 처음엔 둘을 겹쳐 놨는데 내용이 읽히질 않았다.
    private func showCoinThenFly(memoID: UUID, seconds: Double, from point: CGPoint) {
        // 동작 줄이기·저전력에서는 날리지 않는다. 그래도 입금은 알려야
        // "안 들어갔나" 싶지 않다.
        guard Delight.isEnabled, !reduceMotion else {
            vaultDeposit.arriveSilently()
            return
        }

        withAnimation(.easeOut(duration: 0.18)) { coinBadgeMemoID = memoID }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.coinBadgeDwell) {
            // 그 사이 다른 카드를 눌렀으면 그쪽이 주인이다 — 뺏지 않는다.
            if coinBadgeMemoID == memoID {
                withAnimation(.easeIn(duration: 0.16)) { coinBadgeMemoID = nil }
            }
            vaultDeposit.launch(from: point, seconds: seconds)
        }
    }

    /// 이 카드가 지금 내용 대신 동전을 보여줄 차례인가.
    private func showsCoin(_ memo: Memo) -> Bool {
        livingSkin == .vault && coinBadgeMemoID == memo.id
    }

    /// 카드에 얹히는 생활 레이어. 재정렬(경량) 모드에선 전부 생략한다 —
    /// 회전하는 카드마다 Canvas가 하나씩 더 붙으면 드래그가 눈에 띄게 무거워진다.
    @ViewBuilder
    private func livingLayer(memo: Memo, lightweight: Bool) -> some View {
        if !lightweight, Delight.isEnabled {
            switch livingSkin {
            case .vault:
                // 내용 힌트 자리를 번갈아 쓰는 게 기본이라(위 memoCardSurface 참고) 여기서는
                // **그 자리가 아예 없을 때만** 구석에 잠깐 띄운다.
                //
                // ⚠️ 동전을 상시로 늘어놓지 않는다. 처음엔 마을처럼 아래쪽에 쭉 깔았는데,
                //    마을은 새싹처럼 성긴 그림이라 글이 비쳐 보였지만 동전은 꽉 찬 원이라
                //    제목과 내용을 통째로 덮어버렸다.
                ZStack {
                    // 카드를 금고 문으로 — 경첩·다이얼·이음새는 전부 가장자리에 있어
                    // 글과 자리를 다투지 않는다.
                    VaultCardFrame(savedSeconds: VaultLedger.earnedSeconds(
                        characterCount: memo.value.count, useCount: memo.clipCount))

                    if !contentHintEnabled, showsCoin(memo) {
                        VaultCardBadge(savedSeconds: VaultLedger.earnedSeconds(
                            characterCount: memo.value.count, useCount: memo.clipCount))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(.trailing, 12)
                            .padding(.bottom, 10)
                            .transition(.opacity)
                    }
                }
            case .geode:
                // 세 번 쓸 때마다 깨진다. 금고 동전과 같은 이유로 **구석**에만 둔다 —
                // 가운데에 크게 놓으면 제목과 내용을 덮는다.
                // ⚠️ 금고 다이얼과 **같은 자리**(오른쪽 가운데)에 둔다.
                //    카드에서 눈이 가는 자리는 여기다. 아래 구석에 뒀더니 있는 줄도 몰랐다.
                //    제목은 왼쪽 정렬이라 이 자리는 비어 있다.
                GeodeBadge(useCount: memo.clipCount,
                           bursting: burstingMemoID == memo.id,
                           size: 38)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 6)
            case .village:
                // 사용 기록이 그대로 마을이 된다 — 움직이지 않으므로 스크린샷에 남는다.
                // 카드 **아래쪽**에 세운다. 위는 제목 자리라 겹치면 둘 다 안 읽힌다.
                VillageStrip(useCount: memo.clipCount)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 18)
                    .padding(.bottom, 12)
            case .snow:
                ZStack {
                    SnowTexture(seed: memo.id.hashValue)
                    FootprintLayer(useCount: memo.clipCount)
                }
            case .none, .bird, .cat:
                EmptyView()
            }
        }
    }

    // MARK: - 카드 키캡

    /// 사용자가 고른 키캡 물성. 앱 카드와 키보드 키가 **같은 스킨**을 따른다 —
    /// 따로 고르게 하면 설정만 늘고 두 화면이 안 맞는다.
    ///
    /// ⚠️ `KeyboardSkin.current`(UserDefaults 직접 읽기)가 아니라 @AppStorage를 쓴다.
    ///    직접 읽으면 설정에서 바꿔도 이 화면이 다시 그려지지 않아 "골라도 반응이 없다".
    private var keycapSkin: KeyboardSkin {
        KeyboardSkin.resolved(keyboardSkinRaw)
    }

    /// 카드가 얹혀 있는 두께. 0이면 스커트를 아예 그리지 않는다.
    /// 재정렬(경량) 모드에선 회전하는 카드마다 레이어가 하나 더 늘어 버벅임을 만들므로 뺀다.
    private func cardSkirtDepth(lightweight: Bool) -> CGFloat {
        guard !lightweight, Delight.isEnabled else { return 0 }
        return keycapSkin.cardSkirtDepth
    }

    /// 카드 아래 깔리는 옆면. 유리를 **버리지 않고** 그 밑에 두께만 더한다 —
    /// 유리는 표면이고 스커트는 두께라 서로 싸우지 않는다.
    ///
    /// ⚠️ 키보드의 `KeycapSurface`와 규칙은 같지만 구동 방식이 다르다.
    ///    키는 누르고 있는 동안(`isPressed`) 내려가 있고, 카드는 탭 한 번에
    ///    키프레임으로 내려갔다 올라온다(리스트는 롱프레스가 따로 있어 press 상태를 못 쓴다).
    @ViewBuilder
    private func cardSkirt(depth: CGFloat, offsetY: CGFloat) -> some View {
        if depth > 0 {
            RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
                .fill(Color.black.opacity(keycapSkin.skirtOpacity(isDark: theme.isDark)))
                // 캡이 dy만큼 내려가면 스커트는 그만큼 덜 내려가 **절대 위치가 고정**된다.
                // (합이 항상 depth → 바닥은 가만히 있고 캡만 눌린다)
                .offset(y: depth - offsetY)
        }
    }

    /// 텍스트 카드의 글래스 tint — 카테고리 색 정체성 유지(즐겨찾기 분홍/커스텀 팔레트색).
    /// 색이 없는 일반 카드는 nil(무색 프로스트 글래스).
    private func cardGlassTint(memo: Memo) -> Color? {
        if memo.isFavorite { return .clipFavorite }
        if CategoryStore.shared.isFeatureEnabled,
           viewModel.customCategories.contains(memo.category) {
            return customCategoryColor(memo.category)
        }
        return nil
    }

    /// 카드 배경이 짙은 색(컬러드)인지 여부 — 텍스트/아이콘 색상 결정에 사용.
    /// 색은 '카테고리'를 의미한다 — 타입(템플릿/콤보)은 색이 아니라 좌상단 아이콘으로 구분.
    private func cardIsColored(memo: Memo, hasImage: Bool) -> Bool {
        if hasImage { return true }
        // 카테고리/즐겨찾기 색은 '카테고리 정체성'이라 항상 표시(구분 표시 토글과 무관).
        // 보안은 색이 아니라 자물쇠 심볼로만 구분한다(카드 색은 카테고리를 따른다).
        if memo.isFavorite { return true }
        if CategoryStore.shared.isFeatureEnabled,
           viewModel.customCategories.contains(memo.category) { return true }
        return false
    }

    /// 그리드 셀 VoiceOver 합성 라벨 — 제목 + 상태(즐겨찾기/이미지/보안/템플릿/콤보/카테고리).
    private func memoGridAccessibilityLabel(_ memo: Memo) -> String {
        var parts: [String] = [memo.title]
        if memo.isFavorite { parts.append(NSLocalizedString("즐겨찾기", comment: "Category: favorites")) }
        if memo.contentType == .image || memo.contentType == .mixed {
            parts.append(NSLocalizedString("이미지 단축어", comment: "VoiceOver: image memo badge"))
        }
        if memo.isSecure { parts.append(NSLocalizedString("보안 단축어", comment: "VoiceOver: secure memo badge")) }
        if memo.isTemplate { parts.append(NSLocalizedString("템플릿", comment: "VoiceOver: template badge")) }
        if memo.isCombo { parts.append(NSLocalizedString("콤보", comment: "VoiceOver: combo badge")) }
        if CategoryStore.shared.isFeatureEnabled, viewModel.customCategories.contains(memo.category) {
            parts.append(NSLocalizedString(memo.category, comment: "Category name"))
        }
        return parts.joined(separator: ", ")
    }

    /// 키보드 키와 **같은 그림**을 쓴다 (DesignSystem/MemoTypeStyle.swift).
    private func memoTypeIconName(memo: Memo) -> String {
        MemoTypeStyle.symbolName(for: memo)
    }

    /// 메모 타입별 테두리 — 키보드 익스텐션과 같은 규칙을 공유한다.
    /// 템플릿: 보라 실선 / 콤보: 주황 dash[5,3] / 보안: 회색 dot[1,3] / 그 외: 없음.
    /// "메모 구분 표시" 토글이 켜진 경우에만 노출(기본은 깔끔한 카드).
    private func memoTypeBorder(_ memo: Memo) -> (color: Color, lineWidth: CGFloat, dash: [CGFloat]) {
        let style = MemoTypeStyle.border(for: memo, visualCuesVisible: visualCuesVisible)
        return (style.color, style.lineWidth, style.dash)
    }

    private func memoTypeIcon(memo: Memo, onColor: Bool) -> some View {
        let color = onColor ? Color.white.opacity(0.9) : theme.textFaint
        return HStack(spacing: 4) {
            Image(systemName: memoTypeIconName(memo: memo))
                .font(.title2)
                .foregroundStyle(color)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func memoCardBackground(memo: Memo, imageFileName: String, hasImage: Bool) -> some View {
        if hasImage {
            ZStack {
                MemoImageBackground(fileName: imageFileName)
                LinearGradient(
                    colors: [.black.opacity(0.15), .clear, .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        } else if memo.isFavorite {
            // 즐겨찾기 = 분홍 (카테고리 색이므로 항상 표시)
            Color.clipFavorite
        } else if CategoryStore.shared.isFeatureEnabled,
                  viewModel.customCategories.contains(memo.category) {
            // 색 = 카테고리 (항상 표시)
            customCategoryColor(memo.category)
        } else {
            // 보안 메모도 카테고리 색(없으면 기본 표면색)을 따른다 — 회색으로 칠하지 않는다.
            theme.surface
        }
    }

    // MARK: - Tab Background Color

    /// 하단 인디케이터 선택 dot 색상 — 탭 배경색과 시각적으로 매칭.
    /// 즐겨찾기는 분홍, 커스텀 카테고리는 그 카테고리 색, 전체는 무채색.
    private var tabIndicatorColor: Color {
        switch viewModel.selectedCategoryTab {
        case .basic:     return .gray
        case .all:       return .gray
        case .favorites: return .clipFavorite
        case .builtIn(let b): return b.tint
        case .custom(let name): return customCategoryColor(name)
        }
    }

    /// 현재 탭에 맞는 배경색 — 기본/전체=투명(회색 없이 시스템 배경), favorites=핑크, custom=팔레트색
    private var tabBackgroundColor: Color {
        switch viewModel.selectedCategoryTab {
        case .basic:     return .clear
        case .all:       return .clear
        case .favorites: return Color.clipFavorite.opacity(0.10)
        case .builtIn(let b): return b.tint.opacity(0.08)
        case .custom(let name): return customCategoryColor(name).opacity(0.08)
        }
    }

    /// 커스텀 카테고리 색상. 사용자가 지정한 색(userCategoryColors_v1)이 있으면 우선,
    /// 없으면 카테고리 순서에 따라 결정적으로 팔레트 색 반환.
    private func customCategoryColor(_ name: String) -> Color {
        categoryTint(for: name, in: viewModel.customCategories)
    }

    /// 커스텀 카테고리마다 고정 SF Symbol 반환 (색상 팔레트와 1:1 매핑)
    private func customCategoryIcon(_ name: String) -> String {
        // 색맹 사용자가 색 대신 심볼로 카테고리를 구분할 수 있게 한다(공유 헬퍼).
        categorySymbol(for: name, in: viewModel.customCategories)
    }

    // MARK: - Category Tab Bar

    private var categoryTabBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.allCategoryTabs, id: \.self) { tab in
                        categoryTabChip(tab: tab, proxy: proxy)
                    }
                    // "+" 추가 버튼
                    Button {
                        HapticManager.shared.light()
                        showAddCategoryAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: AppSymbol.plus)
                                .font(.caption.weight(.semibold))
                            Text(NSLocalizedString("추가", comment: "Add category button"))
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(theme.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().strokeBorder(theme.textFaint.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .accessibilityLabel(NSLocalizedString("카테고리 추가", comment: "Add category accessibility label"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background {
                // iOS 26+ : Liquid Glass / 이하 : ultraThinMaterial
                // ignoresSafeArea로 상태바 아래까지 확장해 카드처럼 떠있는 느낌 제거
                if #available(iOS 26, *) {
                    Rectangle()
                        .glassEffect()
                        .ignoresSafeArea(edges: .top)
                } else {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea(edges: .top)
                }
            }
            .onChange(of: viewModel.selectedCategoryTab) { _, newTab in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newTab, anchor: .center)
                }
            }
        }
        // 하단 경계 — 미세한 그림자로 자연스러운 분리
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }

    // MARK: - Persona Category Suggestion (TipKit)

    /// 선택한 페르소나에 맞는, 아직 안 만든 카테고리 이름 후보.
    private var personaCategorySuggestions: [String] {
        guard let persona = CategoryStore.shared.selectedPersona else { return [] }
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        let existing = Set(viewModel.customCategories)
        return persona.seedCategories(language: lang).filter { !existing.contains($0) }
    }

    /// 페르소나 카테고리 제안 팁 표시 조건: 페르소나 있음 + 콘텐츠 기반 제안과 겹치지 않음 + 후보 있음.
    private var shouldShowPersonaCategoryTip: Bool {
        CategoryStore.shared.selectedPersona != nil
            && viewModel.suggestedCategory == nil
            && !personaCategorySuggestions.isEmpty
    }

    /// 카테고리 생성 제안 TipKit 카드. 수락 시 카테고리 추가 + 해당 탭으로 이동.
    /// id에 카테고리명을 포함해 카테고리별로 1회만 노출(무효화 추적)된다.
    private func personaCategorySuggestionTip() -> some View {
        let tip = PersonaCategoryTip(suggestions: Array(personaCategorySuggestions.prefix(3)))
        return TipView(tip) { action in
            // action.id == 카테고리 이름. 탭하면 그 카테고리를 만들고 기능을 켠다.
            viewModel.addCustomCategory(action.id)
            CategoryStore.shared.enableFeature()
            HapticManager.shared.success()
            viewModel.loadCustomCategories()
            viewModel.loadMemos()
            tip.invalidate(reason: .actionPerformed)
        }
    }

    private func categorySuggestionTip(name: String, count: Int) -> some View {
        let tip = CategorySuggestionTip(
            categoryRawName: name,
            displayName: Constants.localizedThemeName(name),
            count: count
        )
        return TipView(tip) { action in
            if action.id == "create" {
                withAnimation { viewModel.acceptSuggestedCategory(name) }
                HapticManager.shared.success()
                tip.invalidate(reason: .actionPerformed)
            }
        }
    }

    private func categoryTabChip(tab: CategoryTab, proxy: ScrollViewProxy) -> some View {
        let isSelected = viewModel.selectedCategoryTab == tab
        return Button {
            HapticManager.shared.selection()
            viewModel.selectCategoryTab(tab)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.caption2.weight(.semibold))
                Text(tab.displayName)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                if !tab.isBuiltIn {
                    Button {
                        HapticManager.shared.light()
                        categoryToDelete = tab.displayName
                    } label: {
                        Image(systemName: AppSymbol.xmark)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(isSelected ? .white.opacity(0.7) : theme.textFaint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(format: NSLocalizedString("'%@' 카테고리 삭제", comment: "Delete category chip"), tab.displayName))
                }
            }
            .foregroundColor(isSelected ? .white : theme.textMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule().fill(Color.blue)
                } else {
                    // 비선택 칩: glass 환경에서 자연스럽게 녹아드는 반투명
                    if #available(iOS 26, *) {
                        Capsule().fill(.thinMaterial)
                    } else {
                        Capsule().fill(theme.surfaceAlt)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .id(tab)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Category Tab View (Page Swipe)

    /// TabView.page 방식 — ScrollView 내부 제스처 충돌 없이 수평 스와이프 완벽 처리.
    /// 마지막 탭에서 왼쪽으로 더 스와이프(없는 페이지 방향) → 새 카테고리 생성 제안.
    private var categoryTabView: some View {
        let binding = Binding<CategoryTab>(
            get: { viewModel.selectedCategoryTab },
            set: { newTab in
                viewModel.selectCategoryTab(newTab)
            }
        )
        return TabView(selection: binding) {
            ForEach(viewModel.allCategoryTabs, id: \.self) { tab in
                tabPageView(for: tab)
                    .tag(tab)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .id(viewModel.customCategories)
        // 경계 스와이프 감지: 없는 페이지 방향으로 스와이프할 때만 동작.
        // 첫 탭에서 오른쪽 → 마지막 탭으로 순환,
        // 마지막 탭에서 왼쪽(더 이상 없는 방향) → 카테고리 생성 제안.
        .simultaneousGesture(
            DragGesture(minimumDistance: 60)
                .onEnded { value in
                    let h = value.translation.width
                    let v = value.translation.height
                    guard abs(h) > abs(v) * 1.5, abs(h) > 80 else { return }
                    let tabs = viewModel.allCategoryTabs
                    let idx = viewModel.selectedCategoryIndex
                    if h > 0, idx == 0 {
                        // 첫 탭에서 오른쪽 스와이프 → 마지막 탭으로
                        HapticManager.shared.light()
                        viewModel.selectCategoryTab(tabs[tabs.count - 1])
                    } else if h < 0, idx == tabs.count - 1 {
                        // 마지막 탭에서 더 왼쪽(없는 페이지 방향) → 카테고리 생성 제안
                        HapticManager.shared.light()
                        showSwipeCategoryDialog = true
                    }
                }
        )
        // 하단 그라데이션 베일 — 콘텐츠가 탭바 뒤로 지나가되, 카드 흰 배경이
        // 탭바 주변에 어중간하게 걸쳐 보이지 않게 배경색으로 서서히 사라지게 한다.
        // ignoresSafeArea보다 먼저 걸어 확장된 바닥(홈 인디케이터)까지 덮는다.
        .overlay(alignment: .bottom) {
            LinearGradient(
                stops: [
                    .init(color: tabBackgroundColor.opacity(0), location: 0),
                    .init(color: tabBackgroundColor.opacity(0.9), location: 0.45),
                    .init(color: tabBackgroundColor, location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 130)
            .allowsHitTesting(false)
        }
        // 콘텐츠가 상단 툴바·하단 탭바 뒤로 지나다니게 — 페이저를 화면 위아래 끝까지 확장.
        // (기본값은 바 사이에 갇혀 콘텐츠가 바 밑으로 못 들어감)
        // 콘텐츠 시작 위치는 각 ScrollView의 contentMargins(.top, pageContentTopMargin)가 잡는다.
        .ignoresSafeArea(.container, edges: .vertical)
        .overlay(alignment: .bottom) {
            if viewModel.allCategoryTabs.count > 1 {
                SwipePageIndicator(
                    total: viewModel.allCategoryTabs.count,
                    selectedIndex: viewModel.selectedCategoryIndex,
                    accentColor: tabIndicatorColor
                )
                // 오버레이는 세이프에어리어(탭바 상단) 기준으로 정렬되므로 살짝만 띄운다.
                .padding(.bottom, 8)
            }
        }
    }

    /// 검색어가 비어 있지 않은(공백 제외) 상태 — 검색 결과 없음 분기 판단에 사용.
    private var isSearching: Bool {
        !viewModel.searchQueryString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private func tabPageView(for tab: CategoryTab) -> some View {
        let filtered = viewModel.memos(for: tab)
        // 검색 중인데 결과가 하나도 없으면, 메모가 아예 없을 때의 빈 화면(EmptyListView 등)
        // 대신 "검색 결과 없음" 피드백 + 실제 메모 모양의 제안 카드를 보여준다.
        if isSearching && filtered.isEmpty {
            VStack(spacing: 0) {
                pageHeader(for: tab)
                searchNoResultsView
            }
        } else {
            tabPageContent(for: tab, filtered: filtered)
        }
    }

    /// 빈 상태 화면 위에 페이지 헤더(제목+배너)를 얹는다 — 스크롤 콘텐츠가 없으니 고정이어도 무방.
    private func emptyPage<Content: View>(for tab: CategoryTab, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            pageHeader(for: tab)
            content()
        }
        // 페이저가 화면 끝까지 확장되고, 이 경로엔 ScrollView 가 없어 시스템이 밀어 주지도
        // 않는다 — 시작점을 직접 잡는다(pageContentTopMargin 과 다른 이유, 그쪽 주석 참고).
        .padding(.top, emptyPageTopMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // ⚠️ 배경을 여기서 깐다. 안 그러면 위 여백(pageContentTopMargin)과 네비바 자리는
        //    아무도 안 칠해 시스템 흰색이 그대로 나오고, 그 아래 내용물이 칠한 테마색과
        //    **가로줄로 갈린다**(비어 있을 때만 보이던 두 색 화면의 원인).
        .background(theme.bg.ignoresSafeArea())
    }

    @ViewBuilder
    private func tabPageContent(for tab: CategoryTab, filtered: [Memo]) -> some View {
        switch tab {
        case .basic:
            if !filtered.isEmpty {
                allTabScrollView(memos: filtered, tab: .basic)
            } else {
                emptyPage(for: tab) { EmptyListView }
            }
        case .all:
            if !viewModel.memos.isEmpty {
                allTabScrollView(memos: viewModel.memos, tab: .all)
            } else {
                emptyPage(for: tab) { EmptyListView }
            }
        case .favorites:
            if !filtered.isEmpty {
                filteredTabScrollView(memos: filtered, tab: tab)
            } else {
                emptyPage(for: tab) { favoritesEmptyStateView }
            }
        case .builtIn(let b):
            if !filtered.isEmpty {
                filteredTabScrollView(memos: filtered, tab: tab)
            } else {
                // 비어 있어도 "추가" 카드를 함께 보여 바로 만들 수 있게.
                emptyPage(for: tab) {
                    emptyStateWithAddCard(
                        icon: b.icon,
                        message: String(format: NSLocalizedString("'%@'에 해당하는 단축어가 없습니다", comment: "Built-in category empty state"), b.displayName),
                        tab: tab
                    )
                }
            }
        case .custom(let name):
            if !filtered.isEmpty {
                filteredTabScrollView(memos: filtered, tab: tab)
            } else {
                // 커스텀 탭은 메모 1개 이상일 때만 노출되지만, 안전망으로 추가 카드 포함.
                emptyPage(for: tab) {
                    emptyStateWithAddCard(
                        icon: "folder",
                        message: String(format: NSLocalizedString("'%@'에 단축어가 없습니다", comment: "Custom category empty state"), name),
                        tab: tab
                    )
                }
            }
        }
    }

    // MARK: - Search Empty State

    /// 검색 결과가 없을 때의 화면. 메모가 없을 때 쓰는 EmptyListView(완전히 다른 디자인)
    /// 대신, 결과가 없음을 분명히 알리고 "이런 메모를 만들어 보는 건 어떠세요?"라고 제안한다.
    /// 제안 카드는 우리가 실제로 쓰는 메모 카드와 같은 치수·제목 스타일을 그대로 쓴다.
    private var searchNoResultsView: some View {
        let query = viewModel.searchQueryString.trimmingCharacters(in: .whitespacesAndNewlines)
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(format: NSLocalizedString("'%@' 검색 결과가 없어요", comment: "Search empty state title with query"), query))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(NSLocalizedString("이런 단축어를 만들어 보는 건 어떠세요?", comment: "Search empty state: suggestion subhead"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                // 실제 메모 그리드와 동일한 2열 레이아웃 — 제안 카드도 진짜 메모 카드처럼 보인다.
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    searchSuggestionCard(query: query)
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 120)
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    /// 검색어를 제목으로 채운 "추가 제안" 카드. ghostMemoCell과 동일한 비주얼
    /// (실제 메모 카드 치수·제목 스타일 + 반투명·점선으로 "아직 없는 메모" 표현).
    /// 탭하면 검색어가 키워드로 채워진 편집기로 진입한다(기존 ghostAddPattern 시트 재사용).
    private func searchSuggestionCard(query: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                // 아이콘을 그냥 띄워 두면 붕 뜬다 — 원형 배지에 담아야 만들다 만 게 아니라
                // 만들어 둔 것으로 보인다.
                Image(systemName: AppSymbol.sparkles)
                    .font(.footnote.weight(.bold))
                    .foregroundColor(theme.accent)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(theme.accent.opacity(0.14)))
                    .accessibilityHidden(true)
                Spacer()
            }
            Spacer(minLength: 16)
            Text(query)
                .font(.title2.weight(.semibold))
                .foregroundColor(theme.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(NSLocalizedString("눌러서 이 이름으로 추가", comment: "Search suggestion card: tap to add with this name"))
                .font(.caption)
                .foregroundColor(theme.textFaint)
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: memoCardHeight, alignment: .topLeading)
        .background(theme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
                .strokeBorder(theme.divider, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        )
        .contentShape(RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous))
        .opacity(0.9)
        .onTapGesture {
            HapticManager.shared.selection()
            ghostAddPattern = QuickPattern(icon: AppSymbol.magnifyingglass, title: query, scaffold: "")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(String(format: NSLocalizedString("'%@' 단축어 만들기", comment: "VoiceOver: create memo from search query"), query))
        .accessibilityHint(NSLocalizedString("눌러서 이 이름으로 단축어를 추가합니다", comment: "VoiceOver: search suggestion hint"))
    }

    // MARK: - Reorder Mode (흔들기 + 드래그 재정렬)

    /// 2열 그리드 한 칸 너비 — onDrag 미리보기 크기에 사용. (좌우 패딩 16+16 + 칸 간격 12)
    /// iOS 26에서 `UIScreen.main`이 deprecated — 활성 씬의 **윈도우** 너비를 쓴다.
    /// 화면(screen)이 아니라 윈도우인 이유: 아이패드 분할뷰·스테이지 매니저·Mac Catalyst에서는
    /// 앱이 화면 전체를 쓰지 않아 screen 기준이면 미리보기가 실제 카드보다 커진다.
    @MainActor
    private var reorderPreviewWidth: CGFloat {
        #if os(iOS)
        let containerWidth = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows.first { $0.isKeyWindow }?
            .bounds.width
        // 실제 그리드와 같은 열 수로 나눠야 미리보기와 카드 크기가 일치한다.
        // (좌우 패딩 16+16 + 열 사이 간격 12×(n-1))
        let columns = CGFloat(gridColumnCount)
        let spacing = 12 * (columns - 1)
        let usable = (containerWidth ?? 320) - 32 - spacing
        return max(100, usable / columns)
        #else
        return 160
        #endif
    }

    /// 재정렬 안내 문구 — 카테고리 범위 재정렬이면 어느 카테고리인지 함께 보여준다.
    private var reorderHintText: String {
        if let scope = viewModel.reorderScopeName {
            return String(format: NSLocalizedString("'%@'의 카드를 끌어 순서를 바꾸세요", comment: "Reorder mode hint scoped to current category"), scope)
        }
        return NSLocalizedString("카드를 끌어 순서를 바꾸세요", comment: "Reorder mode hint")
    }

    /// 순서 바꾸기 전용 화면 — 현재 카테고리 탭의 메모(기능 꺼짐 시 전체)를
    /// 흔들리는 그리드로 보여주고 드래그로 재정렬.
    private var reorderModeView: some View {
        NavigationStack {
            ScrollView {
                Text(reorderHintText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)

                // 현재 탭에 재정렬할 메모가 없으면 빈 그리드 대신 이유를 설명한다.
                // (카테고리 범위 재정렬이라 다른 탭의 메모는 여기 나오지 않는 게 정상)
                if viewModel.reorderList.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: AppSymbol.trayFull)
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("이 카테고리에는 순서를 바꿀 단축어가 없어요", comment: "Reorder empty state title"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("다른 카테고리 탭에서 순서 바꾸기를 열어 보세요", comment: "Reorder empty state subtitle"))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                }

                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(Array(viewModel.reorderList.enumerated()), id: \.element.id) { index, memo in
                        reorderCardCell(memo: memo, index: index)
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
                // 재배치 애니메이션은 dropEntered의 withAnimation이 담당(이중 적용 방지).
                // 셀 바깥(여백)에 드롭돼도 드래그 상태를 풀어 카드가 사라진 채 남지 않게 한다.
                .onDrop(of: [.text], delegate: ReorderResetDropDelegate(dragging: $draggingMemo))
            }
            .background(theme.bg.ignoresSafeArea())
            // 그리드 밖(스크롤 영역 아무 곳)에 드롭돼도 드래그 상태를 정리하는 최후 안전망.
            .onDrop(of: [.text], delegate: ReorderResetDropDelegate(dragging: $draggingMemo))
            .navigationTitle(NSLocalizedString("순서 바꾸기", comment: "Reorder mode title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("완료", comment: "Done")) {
                        HapticManager.shared.success()
                        viewModel.exitReorderMode()
                    }
                    .fontWeight(.semibold)
                }
            }
            .solidNavBar(theme.bg)
        }
        .onAppear {
            draggingMemo = nil
            if !reduceMotion { withAnimation { wiggle = true } }
        }
        .onDisappear {
            wiggle = false
            draggingMemo = nil
        }
        // 드래그 세션이 끝나면(정상 드롭·취소 모두) 흔들림을 다시 켠다.
        // repeatForever는 value 변경 시에만 붙으므로 wiggle을 토글해 재시작한다.
        .onChange(of: draggingMemo?.id) { _, newValue in
            if newValue != nil {
                wiggle = false
            } else if !reduceMotion {
                withAnimation { wiggle = true }
            }
        }
    }

    /// 재정렬 그리드의 한 셀 — 흔들림 + onDrag/onDrop 라이브 재배치.
    private func reorderCardCell(memo: Memo, index: Int) -> some View {
        let isDragging = draggingMemo?.id == memo.id
        // 드래그 세션 동안엔 모든 카드의 흔들림을 멈춘다 — repeatForever 회전이 재배치
        // 스프링 애니메이션·스크롤과 매 프레임 경합해 버벅임의 주원인이었다.
        let dragActive = draggingMemo != nil
        // 흔들림 위상은 index가 아닌 id 기반 고정값 — 재배치로 index가 바뀔 때마다
        // 애니메이션이 리셋되어 깜빡이던 문제 방지.
        let phase = Double(abs(memo.id.hashValue) % 6) * 0.045
        return memoCardSurface(memo: memo, lightweight: true)
            // 드래그 중인 카드의 원위치는 완전히 숨기지 않고 흐릿하게만 — 드롭이 시스템에서
            // 취소돼 콜백이 안 와도 카드가 "사라진" 채 남지 않는다.
            .opacity(isDragging ? 0.3 : 1.0)
            .scaleEffect(isDragging ? 0.95 : 1.0)
            .overlay(alignment: .topLeading) {
                // 흔들기 모드 식별용 작은 그립 배지.
                Image(systemName: AppSymbol.arrowUpAndDownAndArrowLeftAndRight)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Circle().fill(Color.black.opacity(0.35)))
                    .padding(8)
                    .opacity(isDragging ? 0 : 1)
                    .accessibilityHidden(true)
            }
            .onDrag {
                draggingMemo = memo
                HapticManager.shared.medium()
                return NSItemProvider(object: memo.id.uuidString as NSString)
            } preview: {
                // 손가락을 따라오는 미리보기는 항상 또렷하게(원본 dim과 분리).
                memoCardSurface(memo: memo, lightweight: true)
                    .frame(width: reorderPreviewWidth, height: memoCardHeight)
            }
            .onDrop(of: [.text], delegate: MemoReorderDropDelegate(
                item: memo,
                list: $viewModel.reorderList,
                dragging: $draggingMemo
            ))
            // 흔들림 — 드래그 세션 중엔 전체 정지, reduceMotion이면 항상 정지.
            .rotationEffect(.degrees((reduceMotion || dragActive) ? 0 : (wiggle ? 1.4 : -1.4)))
            .animation(
                (reduceMotion || dragActive)
                    ? nil
                    : .easeInOut(duration: 0.22).repeatForever(autoreverses: true).delay(phase),
                value: wiggle
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(memo.title)
            .accessibilityHint(NSLocalizedString("드래그하여 순서를 바꿉니다", comment: "Reorder cell a11y hint"))
    }

    private func allTabScrollView(memos allMemos: [Memo], tab: CategoryTab) -> some View {
        trackPageScroll(ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // 배너 — 스크롤 콘텐츠라 스크롤하면 함께 올라간다(타이틀은 바에 고정, inlineLarge).
                pageHeader(for: tab)

                // 상단 여백 — 제목과 팁/그리드 사이 숨 쉬는 공간
                Color.clear.frame(height: 8)

                // TipKit 팁들
                // ⚠️ 세로 패딩(top/bottom)을 이 블록에 붙이지 않는다.
                // 팁이 모두 닫히면 TipView는 0 높이로 접히지만, 항상 존재하는 래퍼/뷰에 붙은
                // 세로 패딩은 빈 상태에서도 남아, 첫 페이지 그리드만 다른 페이지보다 아래에서
                // 시작하는 정렬 어긋남을 만든다. 가로 패딩만 두고, 팁이 보일 때의 위쪽 간격은
                // 상단 16pt 여백이, 그리드와의 간격은 그리드 자체의 .padding(.top, 8)이 담당한다.
                // ⚠️ "예제를 지울까요?" 팁은 뺐다. 4.4.4 부터 새로 시작하는 사람은
                //    샘플을 받지 않고 **자기 손으로 첫 단축어를 만든다**(온보딩).
                //    지울 예제가 없는 사람에게 예제를 지우라고 묻는 팁이었다.
                VStack(spacing: 12) {
                    TipView(welcomeTip)
                        .tipBackground(theme.surface)
                        .onDisappear { AddMemoTip.welcomeTipInvalidated = true }
                }
                .padding(.horizontal, 16)

                // Grace 배너
                if shouldShowGraceBanner {
                    GraceQuotaBannerView {
                        ProFeatureManager.markGraceBannerDismissed()
                        graceBannerVisible = false
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                // 카테고리 배지 끄기 넛지
                if showCategoryBadgeNudge {
                    categoryBadgeNudgeBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 전체 메모를 하나의 그리드로.
                // 정렬: 즐겨찾기 먼저 + lastEdited 내림차순 (viewModel.memos = sortMemos 결과).
                // 사용량(lastUsedAt) 기반 재정렬은 의도적으로 적용하지 않음 — 사용자가 위치를
                // 외워서 찾기 때문에 사용할 때마다 카드가 점프하면 안 됨.
                if !allMemos.isEmpty {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        // 고스트(가상) 메모 — 실제 메모 셀과 같은 모양, 흐릿하게.
                        // 한 번 눌러보고 채워서 추가할지 판단하게 한다.
                        if let ghost = ghostSuggestion {
                            ghostMemoCell(pattern: ghost)
                        }
                        ForEach(Array(allMemos.enumerated()), id: \.element.id) { index, memo in
                            memoGridCell(memo: memo)
                                .opacity(hasAppeared ? 1.0 : (reduceMotion ? 1.0 : 0.0))
                                .offset(y: (hasAppeared || reduceMotion) ? 0 : 12)
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(Double(min(index, 12)) * 0.03), value: hasAppeared)
                        }
                        // 그리드 끝 "추가" 카드는 두지 않는다 — 우상단 툴바 + 버튼이 있으므로
                        // 추가 카드는 빈 상태 화면(emptyStateWithAddCard 등)에서만 노출.
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            // 하단 여백 — 페이저가 화면 바닥까지 확장되므로(ignoresSafeArea)
            // 마지막 카드가 플로팅 탭바에 가리지 않도록 탭바 높이 이상 확보.
            .padding(.bottom, 110)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: viewModel.selectedTypeFilter)
            // 붙여넣기 안내 배너 닫힘 애니메이션 — 배너의 transition만으로는
            // LazyVStack 행 높이 변화가 스냅되므로 컨테이너에 값 기반 애니메이션 필요(실측).
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: showPasteTip)
        }
        // [디자인 불변식] 스크롤 엣지 이펙트는 전부 숨김 — ScrollView 자체에 직접.
        // (.top만 숨기면 스크롤 시 상단에 흰 배경 밴드가 생기는 회귀를 실측으로 확인)
        // 하단 카드 걸침 문제는 categoryTabView의 그라데이션 베일이 처리.
        .scrollEdgeEffectHidden(true, for: .all)
        // 페이저가 화면 끝까지 확장되므로 콘텐츠 시작점은 여기서 잡는다(고정 타이틀 아래).
        .contentMargins(.top, pageContentTopMargin, for: .scrollContent))
    }

    private func filteredTabScrollView(memos: [Memo], tab: CategoryTab) -> some View {
        trackPageScroll(ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // 배너 — 스크롤 콘텐츠라 스크롤하면 함께 올라간다(타이틀은 바에 고정, inlineLarge).
                pageHeader(for: tab)
                Color.clear.frame(height: 8)
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(Array(memos.enumerated()), id: \.element.id) { index, memo in
                        memoGridCell(memo: memo)
                            .opacity(hasAppeared ? 1.0 : (reduceMotion ? 1.0 : 0.0))
                            .offset(y: (hasAppeared || reduceMotion) ? 0 : 12)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(Double(min(index, 12)) * 0.03), value: hasAppeared)
                    }
                    // 그리드 끝 "추가" 카드 없음 — 우상단 툴바 + 버튼으로 충분.
                    // 추가 카드는 빈 상태(favoritesEmptyStateView·emptyStateWithAddCard)에서만.
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            // 페이저 바닥 확장(ignoresSafeArea)에 맞춘 탭바 가림 방지 여백.
            .padding(.bottom, 110)
            // 붙여넣기 안내 배너 닫힘 애니메이션(위 allTabScrollView 참고).
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: showPasteTip)
        }
        // [디자인 불변식] 엣지 이펙트 전부 숨김(위 allTabScrollView 참고).
        .scrollEdgeEffectHidden(true, for: .all)
        .contentMargins(.top, pageContentTopMargin, for: .scrollContent))
    }

    /// 즐겨찾기 탭 전용(하위 호환). 내부적으로 공통 addCard 사용.
    private var addFavoriteMemoCard: some View {
        addCard(for: .favorites)
    }

    /// 그리드 끝에 붙는 점선 "추가" 카드. 즐겨찾기·커스텀·기본 제공 카테고리가 공유.
    private func addMemoCard(label: String, accessibility: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: AppSymbol.plus)
                    .font(.title2.weight(.medium))
                    .foregroundColor(theme.textFaint)
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundColor(theme.textFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: memoCardHeight)  // 메모 셀과 동일 높이
            // 배경 사진 위에서는 반투명 표면이 씻겨 보여 프로스트 유리로 받친다.
            .background {
                if resolvedBackgroundImage.isEmpty {
                    theme.surface.opacity(0.5)
                } else {
                    Rectangle().fill(.ultraThinMaterial)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
                    .strokeBorder(
                        theme.textFaint.opacity(resolvedBackgroundImage.isEmpty ? 0.3 : 0.5),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }

    /// 현재 탭에 맞는 "추가" 카드 — 탭한 카테고리에 곧바로 들어가도록 생성 흐름을 연다.
    @ViewBuilder
    private func addCard(for tab: CategoryTab) -> some View {
        switch tab {
        case .basic, .all:
            // 기본/전체 탭에서도 다른 카테고리처럼 추가를 유도하는 카드.
            addMemoCard(
                label: NSLocalizedString("단축어 추가", comment: "Add memo card"),
                accessibility: NSLocalizedString("단축어 추가", comment: "Add memo card")
            ) { addMemoSheetCategory = ""; showAddMemoSheet = true }
        case .favorites:
            addMemoCard(
                label: NSLocalizedString("즐겨찾기 추가", comment: "Add memo to favorites card"),
                accessibility: NSLocalizedString("즐겨찾기 단축어 추가", comment: "Add favorite memo card a11y")
            ) { showAddFavoriteMemoSheet = true }
        case .builtIn(let b):
            switch b {
            case .templates:
                addMemoCard(
                    label: NSLocalizedString("템플릿 추가", comment: "Add template card"),
                    accessibility: NSLocalizedString("템플릿 추가", comment: "Add template card")
                ) { showAddTemplateSheet = true }
            case .combos:
                addMemoCard(
                    label: NSLocalizedString("콤보 추가", comment: "Add combo card"),
                    accessibility: NSLocalizedString("콤보 추가", comment: "Add combo card")
                ) { showAddComboSheet = true }
            case .images:
                addMemoCard(
                    label: NSLocalizedString("이미지 단축어 추가", comment: "Add image memo card"),
                    accessibility: NSLocalizedString("이미지 단축어 추가", comment: "Add image memo card")
                ) { addMemoSheetCategory = "이미지"; showAddMemoSheet = true }
            case .textMemos:
                addMemoCard(
                    label: NSLocalizedString("단축어 추가", comment: "Add memo card"),
                    accessibility: NSLocalizedString("단축어 추가", comment: "Add memo card")
                ) { addMemoSheetCategory = ""; showAddMemoSheet = true }
            }
        case .custom(let name):
            addMemoCard(
                label: String(format: NSLocalizedString("'%@' 추가", comment: "Add memo to this category card"), name),
                accessibility: String(format: NSLocalizedString("'%@' 카테고리에 단축어 추가", comment: "Add memo to category a11y"), name)
            ) { addMemoSheetCategory = name; showAddMemoSheet = true }
        }
    }

    /// 빈 상태 안내(아이콘+문구) — 배경 사진이 있으면 프로스트 유리 패널을 받쳐
    /// 밝은 설경 같은 사진 위에서도 회색 안내가 씻겨 보이지 않게 한다.
    private func emptyStateMessage(icon: String, message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(theme.textFaint)
            Text(message)
                .font(.body)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background {
            if !resolvedBackgroundImage.isEmpty {
                RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
        .padding(.horizontal, 32)
    }

    /// 빈 카테고리 안내 + 상단에 "추가" 카드. (즐겨찾기 빈 상태와 동일한 레이아웃을 일반화)
    private func emptyStateWithAddCard(icon: String, message: String, tab: CategoryTab) -> some View {
        ZStack(alignment: .center) {
            emptyStateMessage(icon: icon, message: message)
            VStack {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    addCard(for: tab)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var favoritesEmptyStateView: some View {
        ZStack(alignment: .center) {
            // 화면 정 중앙 — 빈 상태 안내
            emptyStateMessage(
                icon: AppSymbol.heartSlash,
                message: NSLocalizedString("즐겨찾기한 단축어가 없습니다.\n단축어를 꾹 눌러 즐겨찾기에 추가해보세요", comment: "Favorites tab empty state with hint")
            )

            // 상단 — 즐겨찾기 메모 추가 카드
            VStack {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    addFavoriteMemoCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Ambient Top Block

    /// 상단 통합 블록: 시간대 인사 + 스마트 컨텍스트 + 액션 카드 하나.
    /// 기존에 분산돼 있던 "방금 복사 캡처 / 컨텍스트 부제 / 히어로 카드"가
    /// 사용자 상태에 따라 자연스럽게 하나로 합쳐져 표시된다.
    private var ambientTopBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            greetingHeader
            contextActionCard
        }
    }

    /// 시간대 인사말 + 상태 한 줄 통계.
    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timeGreeting)
                .font(.system(.title, design: .serif, weight: .black))
                .foregroundColor(theme.text)
            Text(contextLine)
                .font(.body)
                .foregroundColor(theme.textMuted)
            if let savedText = timeSavedBadgeText {
                HStack(spacing: 4) {
                    Image(systemName: AppSymbol.clockArrowCirclepath)
                        .font(.caption2)
                        .accessibilityHidden(true)
                    Text(savedText)
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(.green)
                .padding(.top, 2)
            }
        }
    }

    /// 평생 누적 절약 시간 배지 — 10분 미만이면 숨김.
    private var timeSavedBadgeText: String? {
        let total = KeyboardUsageTracker.totalTimeSavedSeconds()
        guard total >= 600 else { return nil }
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        if hours > 0 {
            return String(format: NSLocalizedString("Saved %dh %dm so far", comment: "Time saved badge h+m"), hours, minutes)
        }
        return String(format: NSLocalizedString("Saved %dm so far", comment: "Time saved badge minutes"), minutes)
    }

    /// 상황에 맞는 단 하나의 액션 카드.
    /// 우선순위: 방금 복사한 클립보드 → 최근 1시간 내 쓴 메모 히어로 → 없음(숨김)
    @ViewBuilder
    private var contextActionCard: some View {
        if viewModel.hasFreshClipboard {
            ClipboardCaptureCard(
                value: viewModel.value,
                detectedType: viewModel.clipboardDetectedType,
                confidence: viewModel.clipboardConfidence,
                suggestedTitle: viewModel.suggestedClipboardTitle,
                onDismiss: {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                        viewModel.dismissClipboardCapture()
                    }
                },
                onSaveDirect: {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                        viewModel.saveClipboardAsMemo()
                    }
                },
                onEditTap: {
                    viewModel.markClipboardSaved()
                }
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        } else if let hero = heroMemo {
            heroCardView(memo: hero)
        }
    }

    /// 시간대 기반 인사말 + 이모지 — 아침/낮/저녁/밤.
    /// 이모지는 일출·낮·일몰·밤을 근사 (실제 일출/일몰 시간은 위치 권한 피하려 시간대로 근사).
    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let emoji: String
        let phrase: String
        switch hour {
        case 5..<8:
            emoji = "🌅"
            phrase = NSLocalizedString("Good morning", comment: "Greeting: morning")
        case 8..<12:
            emoji = "☀️"
            phrase = NSLocalizedString("Good morning", comment: "Greeting: morning")
        case 12..<17:
            emoji = "🌤"
            phrase = NSLocalizedString("Good afternoon", comment: "Greeting: afternoon")
        case 17..<20:
            emoji = "🌅"
            phrase = NSLocalizedString("Good evening", comment: "Greeting: evening")
        case 20..<24:
            emoji = "🌙"
            phrase = NSLocalizedString("Good evening", comment: "Greeting: evening")
        default:
            emoji = "🌙"
            phrase = NSLocalizedString("Still up?", comment: "Greeting: late night")
        }
        return "\(emoji)  \(phrase)"
    }

    // MARK: - Scroll Fade (Notes-style)

    /// 상단 그리팅 영역의 스크롤 오프셋을 기록하는 GeometryReader.
    private var scrollOffsetReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: ScrollOffsetPreferenceKey.self,
                value: -proxy.frame(in: .named("listScroll")).minY
            )
        }
    }

    /// 스크롤 오프셋 기반 fade — 80pt 넘게 스크롤하면 완전 투명.
    private var greetingOpacity: Double {
        1 - Double(min(max(scrollOffset / 80, 0), 1))
    }

    /// 그리팅 아래 한 줄 — 상황 기반 스마트 문구.
    /// 우선순위: 오늘 사용 횟수 표시 → 최근 1시간 사용한 메모 → 기본 개수 표시
    /// 일일 카운트는 KeyboardUsageTracker (사용자 로컬 자정 기준 자연 초기화).
    private var contextLine: String {
        let memos = viewModel.memos
        let todayTaps = KeyboardUsageTracker.dailyUsageCount()

        if todayTaps > 0 {
            let format = NSLocalizedString("%d saved · %d taps today", comment: "Stats with today usage")
            return String(format: format, memos.count, todayTaps)
        }

        let hourAgo = Date().addingTimeInterval(-60 * 60)
        if let recent = memos.first(where: { ($0.lastUsedAt ?? .distantPast) >= hourAgo }) {
            let format = NSLocalizedString("Just used %@", comment: "Context: recently used memo")
            return String(format: format, recent.title)
        }

        let format = NSLocalizedString("%d saved · find what you need", comment: "Stats default")
        return String(format: format, memos.count)
    }

    /// 히어로 카드에 띄울 메모. lastUsedAt이 최근 1시간 이내인 항목만 채택.
    private var heroMemo: Memo? {
        let hourAgo = Date().addingTimeInterval(-60 * 60)
        return viewModel.memos.first(where: { ($0.lastUsedAt ?? Date.distantPast) >= hourAgo })
    }

    /// "방금 쓴 것" 히어로 카드.
    private func heroCardView(memo: Memo) -> some View {
        Button {
            HapticManager.shared.soft()
            viewModel.copyMemo(memo: memo)
        } label: {
            MemoRowView(
                memo: memo,
                fontSize: fontSize,
                onFavoriteToggle: { viewModel.toggleFavorite(memoId: memo.id) },
                onDelete: { memoToDelete = memo }
            )
            .padding(14)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                    // 메모 구분 표시 토글을 따른다 (OFF면 테두리 숨김).
                    .stroke(visualCuesVisible ? Color.blue.opacity(0.12) : .clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Recency Fade

    /// 메모의 최근 사용 시점에 따라 행 opacity를 부드럽게 감쇠.
    /// 섹션 헤더 없이도 "최근 것은 생생하고 오래된 것은 조용히 뒤로 물러나는" 느낌.
    private func recencyOpacity(for memo: Memo) -> Double {
        let reference = memo.lastUsedAt ?? memo.lastEdited
        let interval = Date().timeIntervalSince(reference)
        if interval < 60 * 60 { return 1.0 }                 // 1시간 이내
        if interval < 60 * 60 * 24 { return 0.95 }           // 오늘
        if interval < 60 * 60 * 24 * 7 { return 0.88 }       // 이번 주
        return 0.78                                           // 그 이상
    }

    // MARK: - Context Menu Preview (Mail-style)

    /// 길게 눌렀을 때 떠오르는 플로팅 미리보기 — 실제 콘텐츠 전체 보기.
    private func memoContextPreview(memo: Memo) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Text(memo.title.templateAwareAttributed(theme: theme, font: .headline.weight(.semibold)))
                        .font(.headline.weight(.semibold))
                        .foregroundColor(theme.text)
                    if memo.isTemplate {
                        TagBadge(label: NSLocalizedString("Template", comment: "Tag: template"))
                    }
                    if memo.isCombo {
                        TagBadge(label: NSLocalizedString("Combo", comment: "Tag: combo"))
                    }
                    if memo.isSecure {
                        Image(systemName: AppSymbol.lockFill)
                            .font(.body)
                            .foregroundColor(theme.textFaint)
                    }
                    Spacer(minLength: 0)
                }

                #if os(iOS)
                if memo.contentType == .image || memo.contentType == .mixed,
                   let firstImageFileName = memo.imageFileNames.first,
                   let image = MemoStore.shared.loadImage(fileName: firstImageFileName) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
                }
                #endif

                if !memo.value.isEmpty {
                    Text(memo.value.templateAwareAttributed(theme: theme, font: .body.weight(.semibold)))
                        .font(.body)
                        .foregroundColor(theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                HStack(spacing: 8) {
                    if memo.clipCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: AppSymbol.docOnDocFill)
                                .font(.caption2)
                            Text(String(format: NSLocalizedString("Used %d×", comment: "Preview: total use count"), memo.clipCount))
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundColor(theme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.surfaceAlt)
                        .clipShape(Capsule())
                    }
                    if memo.isFavorite {
                        HStack(spacing: 4) {
                            Image(systemName: AppSymbol.heartFill)
                                .font(.caption2)
                            Text(NSLocalizedString("Favorite", comment: "Preview: favorite badge"))
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundColor(.clipFavorite)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.clipFavorite.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 420, minHeight: 120, idealHeight: 260, maxHeight: 520)
        .background(theme.surface)
    }

    // MARK: - Time Divider (day boundary)

    /// 이전 메모와 날짜 버킷(오늘/어제/이번주/이번달…)이 바뀔 때만 divider 라벨 반환.
    private func dayBoundaryLabel(for memo: Memo, previousMemo: Memo?) -> String? {
        let cal = Calendar.current
        let reference = memo.lastUsedAt ?? memo.lastEdited

        guard let prev = previousMemo else {
            return relativeDateLabel(reference)
        }
        let prevRef = prev.lastUsedAt ?? prev.lastEdited

        // 같은 날이거나 같은 버킷(예: 둘 다 "This week")이면 헤더 불필요
        if cal.isDate(reference, inSameDayAs: prevRef) { return nil }
        let currentLabel = relativeDateLabel(reference)
        let prevLabel = relativeDateLabel(prevRef)
        if currentLabel == prevLabel { return nil }
        return currentLabel
    }

    /// 초미니멀 day divider — 얇은 수평선 + 작은 라벨.
    private func timeDivider(label: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(theme.divider)
                .frame(height: 0.5)
                .accessibilityHidden(true)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(theme.textFaint)
                .textCase(.uppercase)
                .tracking(0.5)
            Rectangle()
                .fill(theme.divider)
                .frame(height: 0.5)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isHeader)
    }

    /// 캘린더 기준 상대적 날짜 라벨.
    private func relativeDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return NSLocalizedString("Today", comment: "Divider label: today")
        }
        if cal.isDateInYesterday(date) {
            return NSLocalizedString("Yesterday", comment: "Divider label: yesterday")
        }
        let daysDiff = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
        if daysDiff < 7 {
            return NSLocalizedString("This week", comment: "Divider label: earlier this week")
        }
        if daysDiff < 30 {
            return NSLocalizedString("This month", comment: "Divider label: earlier this month")
        }
        return NSLocalizedString("Earlier", comment: "Divider label: earlier than a month")
    }

    /// 타입 필터 바 섹션 (인라인)
    private var typeFilterBarInlineSection: some View {
        MemoTypeFilterBar(
            selectedFilter: $viewModel.selectedTypeFilter,
            showFavorites: $viewModel.showFavoritesFilter,
            memos: viewModel.loadedData
        )
    }

    /// 우클릭(Mac) / 롱프레스(iOS) 컨텍스트 메뉴.
    /// Toolbar 컨텐츠
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        // 순정 iOS 26: 네비게이션 바 트레일링.
        // sharedBackgroundVisibility(.hidden) — 버튼을 감싸던 공유 글래스 필(불투명해 보이는
        // 흰 알약 배경)을 제거해 아이콘이 배경 위에 그대로 뜨게 한다(헤더 투명 불변식).
        // 단일 ToolbarItem + HStack — 별도 아이템로 두면 시스템이 간격을 벌려
        // 버튼이 뚝 떨어져 보이므로, 하나로 묶어 간격을 직접 제어한다.
        // 음수 spacing: 시스템이 Menu 라벨 둘레에 넣는 내부 여백(~12pt)을 상쇄해
        // 두 유리 서클이 살짝 붙어 보이게 한다(44pt 탭 영역은 유지).
        // 금고는 **왼쪽**에 따로 둔다. 오른쪽은 이미 메뉴+추가가 붙어 있어
        // 거기 하나를 더 끼우면 셋이 뭉쳐 보인다.
        //
        // ⚠️ 스킨이 금고가 아닐 때는 ToolbarItem 자체를 만들지 않는다. 안이 빈 아이템도
        //    자리는 차지해서, 시스템이 바가 넘친다고 보고 오른쪽에 ⋯ 오버플로 버튼을
        //    하나 더 만들어 버린다(⋯ 가 두 개로 보였던 원인).
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: -8) {
                toolbarButtons
            }
        }
        .sharedBackgroundVisibility(.hidden)
        #else
        ToolbarItemGroup(placement: .automatic) {
            vaultEntrance
            toolbarButtons
        }
        #endif
    }

    /// Toolbar 버튼들 (iOS/macOS 공통)
    /// 구성: [더보기 메뉴(활용사례·보관함·카테고리·플레이스홀더)] [+ 추가]
    @ViewBuilder
    private var toolbarButtons: some View {
        // ⚠️ 예전 ⋯ 메뉴는 설정으로 옮겼다(활용 사례·보관함·스타터팩·플레이스홀더·배경).
        //    바에 ⋯ 와 + 와 금고를 다 두려니 시스템이 넘친다고 보고 오른쪽에 오버플로 ⋯ 를
        //    하나 더 만들어서, ⋯ 가 둘로 보이고 금고는 그 안에 접혀 사라졌다.
        //    바에는 **자주 쓰는 둘**만 남긴다 — 금고와 추가.
        vaultEntrance

        .accessibilityHint(NSLocalizedString("보관함, 카테고리 관리, 플레이스홀더 관리 메뉴를 엽니다", comment: "More options menu hint v2"))

        // 화면 전환 — **+ 바로 왼쪽**. 누르면 키보드 미리보기로 건너가고,
        // 그쪽 머리말의 같은 자리에서 격자 모양으로 바뀌어 되돌아올 수 있다.
        SnippetsStyleSwitchButton(styleRaw: $snippetsTabStyleRaw)

        Menu {
            // 통합 모델: 사용자는 "메모"만 만든다. 변수({…})를 넣으면 템플릿, 이어지는 메모를 더하면 콤보가 된다.
            Button {
                HapticManager.shared.light()
                if case .custom(let name) = viewModel.selectedCategoryTab { addMemoSheetCategory = name } else { addMemoSheetCategory = "" }
                showAddMemoSheet = true
            } label: {
                Label(NSLocalizedString("새 단축어 만들기", comment: "Menu: new memo"), systemImage: AppSymbol.squareAndPencil)
            }
            // 임시 저장 — 만들다 저장하지 않고 나간 미완성 메모를 이어서 작성.
            Button {
                HapticManager.shared.light()
                showDraftList = true
            } label: {
                Label(draftMenuTitle, systemImage: "clock.arrow.circlepath")
            }
            Divider()
            Button {
                showBulkImport = true
            } label: {
                Label(NSLocalizedString("한번에 많은 단축어 정리하기", comment: "Menu: bulk import"), systemImage: AppSymbol.docOnClipboard)
            }
        } label: {
            // 클리어 글래스 서클 — 하단 탭바와 같은 유리 언어(맑은 유리에 아이콘).
            Image(systemName: AppSymbol.plus)
                .font(.body.weight(.semibold))
                .foregroundColor(.blue)
                .frame(width: 44, height: 44)
                .glassEffect(.clear.interactive(), in: Circle())
        }
        .accessibilityLabel(NSLocalizedString("단축어 추가", comment: "Add memo menu label"))
        .accessibilityHint(NSLocalizedString("새 단축어를 작성하거나 텍스트를 가져옵니다", comment: "Add memo menu hint"))
        .popoverTip(addMemoTip)
        .sheet(isPresented: $showBulkImport) {
            BulkImportView()
        }
        .sheet(isPresented: $showDraftList) {
            NavigationStack {
                DraftListView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(NSLocalizedString("완료", comment: "Done")) { showDraftList = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showQuickNoteAdd) {
            QuickNoteEditSheet(note: QuickNote()) { newNote in
                guard !newNote.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                QuickNoteStore.shared.add(newNote)
                // 담긴 위치를 바로 알려준다 — 상단 Inbox 배너도 함께 나타나 뷰어로 안내.
                viewModel.showPlainToast(NSLocalizedString("메모를 보관함에 담았어요", comment: "Toast after quick note saved to inbox"))
            } onPromote: { newNote in
                guard !newNote.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                QuickNoteStore.shared.add(newNote)
                QuickNoteStore.shared.promoteToMemo(newNote)
                viewModel.loadMemos()
                viewModel.showPlainToast(NSLocalizedString("단축어로 저장했어요", comment: "Toast after quick note promoted to memo"))
            }
        }
        // 설정 > 카테고리 관리와 동일한 단일 화면(CategorySettings)을 시트로 재사용 —
        // 진입점만 두 곳, 편집 UI는 하나로 통일. 닫을 때 뷰모델을 리로드해 탭에 즉시 반영.
        .sheet(isPresented: $showCategoryManagement, onDismiss: {
            viewModel.loadCustomCategories()
            viewModel.applyFilters()
        }) {
            NavigationStack {
                CategorySettings()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(NSLocalizedString("닫기", comment: "Close sheet")) {
                                showCategoryManagement = false
                            }
                        }
                    }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showAddMemoSheet, onDismiss: { viewModel.loadMemos() }) {
            NavigationStack {
                MemoAdd(insertedCategory: addMemoSheetCategory.isEmpty ? "텍스트" : addMemoSheetCategory)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(NSLocalizedString("취소", comment: "Cancel")) { showAddMemoSheet = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showAddTemplateSheet, onDismiss: { viewModel.loadMemos() }) {
            NavigationStack {
                MemoAdd(insertedIsTemplate: true)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(NSLocalizedString("취소", comment: "Cancel")) { showAddTemplateSheet = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showAddComboSheet, onDismiss: { viewModel.loadMemos() }) {
            NavigationStack {
                MemoAdd(insertedIsCombo: true)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(NSLocalizedString("취소", comment: "Cancel")) { showAddComboSheet = false }
                        }
                    }
            }
        }
    }

    /// Toast 오버레이
    @ViewBuilder
    private var toastOverlay: some View {
        if viewModel.showToast {
            Text(viewModel.toastMessage)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                // Liquid Glass 토스트 — 어둡게 틴트한 glass라 흰 글자 가독성 유지,
                // 뒤 콘텐츠가 은은히 비쳐 떠 있는 컨트롤 레이어로 읽힌다. (iOS 26)
                .glassEffect(
                    .regular.tint(Color.toastBackground.opacity(0.75)),
                    in: RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                )
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                .onTapGesture {
                    HapticManager.shared.soft()
                    viewModel.showToast = false
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeOut(duration: 0.2), value: viewModel.showToast)
                .padding(.bottom, 50)
                .accessibilityHidden(true)  // VoiceOver는 아래 onChange announcement로 전달
                .onChange(of: viewModel.showToast) { _, isShowing in
                    #if os(iOS)
                    if isShowing {
                        UIAccessibility.post(notification: .announcement, argument: viewModel.toastMessage)
                    }
                    #endif
                }
        }
    }

    /// 빈 목록 — **광부와 함께 첫 단축어를 하나 만든다.**
    ///
    /// ⚠️ 예전에는 여기에 "이런 방법으로 쓸 수 있어요" 카드 격자 + 스타터팩 배너가 있었다.
    ///    걷어낸 이유: 그 화면은 **읽을 거리만 주고 아무것도 시키지 않았다.**
    ///    활용 사례를 아무리 잘 써 놔도 한 번도 안 만들어 본 사람에게는 남의 이야기고,
    ///    만들어서 써 본 사람만 다음 날 다시 온다.
    ///    (스타터팩 자체는 남아 있다 — 더보기 메뉴에서 여전히 쓸 수 있다.)
    private var EmptyListView: some View {
        Group {
            // ⚠️ 온보딩은 **4.4.4 에서 처음 시작한 사람에게만** 보인다.
            //    이 조건이 없으면 몇 년 쓴 사람이 단축어를 정리해 목록을 비우는 순간
            //    "매번 똑같은 걸 치고 있지는 않나요?"가 뜬다 — 그 사람에겐 헛소리다.
            if firstShortcutDone || !startedFreshV444 {
                minimalEmptyState
            } else {
                FirstShortcutOnboardingView(
                    onCreated: { memo in
                        firstShortcutDone = true
                        viewModel.loadMemos()
                        // 만들기만 하고 끝내면 "저장했다"로 끝난다. 한 번 **써 봐야** 값어치를 안다.
                        coachMemoID = memo.id
                    },
                    onSkip: { firstShortcutDone = true }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 아직 안 해 본 다음 장을 권한다. 없으면 아무 일도 안 일어난다.
    ///
    /// ⚠️ 한 번에 셋을 다 가르치지 않는다. 첫 화면에서 "단축어·콤보·템플릿이 있어요"를
    ///    다 설명하면 하나도 안 남는다. 하나 만들고 → 써 보고 → 그다음 것을 권한다.
    private func inviteNextChapter(after delay: Double) {
        // ⚠️ 처음 배우는 중이라면 **여기서 권하지 않는다.** 그 흐름은 무대(SnippetsTab)가
        //    이끌고 있고, 양쪽이 같이 권하면 같은 장이 두 번 뜬다.
        guard !(startedFreshV444 && !tutorialChaptersDone) else { return }
        // 순서가 곧 배우는 차례다 — 템플릿을 만들어 본 다음이라야
        // "있는 걸 템플릿으로 바꾼다"는 말이 통한다.
        let next = TutorialChapter.allCases.first { chapter in
            switch chapter {
            case .template:     return !tutorialTemplateDone
            // 바꿀 단축어가 없으면 이 장은 건너뛴다 — 없는 걸 바꾸라고 할 수는 없다.
            case .makeTemplate: return !tutorialMakeTemplateDone && convertibleShortcut != nil
            case .combo:        return !tutorialComboDone
            }
        }
        // 더 권할 것이 없다 = 배우는 차례가 끝났다.
        // ⚠️ 이 사실을 알려야 한다. 어떤 장은 조건이 안 되면(바꿀 단축어가 없는 등) 조용히
        //    건너뛰므로, 완료 표식만 보고 판단하면 **영영 안 끝난 것으로 남는다** —
        //    그러면 마지막 걸음(키보드 설정)이 오지 않는다.
        guard let next else {
            NotificationCenter.default.post(name: .tutorialChaptersFinished, object: nil)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            tutorialInvite = next
        }
    }

    /// 템플릿으로 바꿀 만한 단축어 — 아직 템플릿도 콤보도 아닌 평범한 글.
    private var convertibleShortcut: Memo? {
        viewModel.memos.first {
            !$0.isTemplate && !$0.isCombo && $0.contentType == .text
                && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// 장을 끝난 것으로 표시한다.
    private func markDone(_ chapter: TutorialChapter) {
        switch chapter {
        case .template:     tutorialTemplateDone = true
        case .makeTemplate: tutorialMakeTemplateDone = true
        case .combo:        tutorialComboDone = true
        }
    }

    /// 튜토리얼에서 만든 것을 목록에 반영하고 "눌러보세요"로 이어준다.
    private func tutorialCreated(_ memo: Memo, chapter: TutorialChapter) {
        tutorialMaking = nil
        viewModel.loadMemos()
        coachMemoID = memo.id
        coachChapter = chapter
    }

    /// "만든 걸 눌러보세요" — 연습의 마지막 한 걸음.
    ///
    /// 만들기만 하고 끝내면 "저장했다"로 끝난다. 한 번 눌러 봐야 **왜 저장했는지**를 안다.
    /// 그래서 이 안내는 닫기 버튼이 없다 — 대신 한 번 쓰면 스스로 사라진다.
    /// 카드 위에 떠 있는 것들 — 날아가는 동전과 코치.
    private var floatingLayer: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                CoinFlightLayer(deposit: vaultDeposit)

                if coachMemoID != nil, coachRect != .zero {
                    // ⚠️ 화면 맨 아래에 고정하지 않는다. 가리키는 카드는 위에 있는데 안내가
                    //    아래에 있으면 무엇을 누르라는 건지 이어지지 않는다.
                    //    카드 **바로 아래**에 꼭지를 위로 달고 붙인다.
                    let top = coachRect.maxY - geo.frame(in: .global).minY + 10
                    FirstUseCoachChip(
                        line: coachChapter?.coachLine
                            ?? NSLocalizedString("만든 걸 눌러보세요. 바로 복사돼요.",
                                                 comment: "First-use coach: tap the shortcut you made"),
                        pointsUp: true
                    )
                    .frame(maxWidth: geo.size.width - 32)
                    .offset(y: min(top, geo.size.height - 120))
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// 다 지워서 비었을 때. 첫 온보딩을 이미 지난 사람에게 안내를 다시 깔지 않는다.
    private var minimalEmptyState: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("아직 단축어가 없어요. 위 + 를 눌러 하나 만들어요.", comment: "Empty list: no shortcuts yet"))
                .font(.body)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }


    // MARK: - Ghost Memo Suggestion

    /// 닫지 않았고 아직 같은 제목의 메모가 없는 패턴 하나를 골라 제안한다.
    /// 이번 세션에 사용자가 X로 닫았다면(ghostSuppressedThisSession) 제안하지 않는다.
    private func refreshGhostSuggestion() {
        guard !Self.ghostSuppressedThisSession,
              !UserDefaults.standard.bool(forKey: ghostSuggestionsOffKey) else {
            ghostSuggestion = nil
            return
        }
        let dismissed = Set(UserDefaults.standard.stringArray(forKey: dismissedGhostPatternsKey) ?? [])
        let existingTitles = Set(viewModel.memos.map { $0.title })
        ghostSuggestion = QuickPattern.defaults.first {
            !dismissed.contains($0.title) && !existingTitles.contains($0.title)
        }
    }

    /// 제안을 닫으면 다시 뜨지 않도록 제목을 기록한다.
    private func dismissGhostPattern(_ pattern: QuickPattern) {
        var dismissed = UserDefaults.standard.stringArray(forKey: dismissedGhostPatternsKey) ?? []
        if !dismissed.contains(pattern.title) {
            dismissed.append(pattern.title)
            UserDefaults.standard.set(dismissed, forKey: dismissedGhostPatternsKey)
        }
    }

    /// feature 태그에 맞게 MemoAdd를 구성한다.
    /// .template → 템플릿 토글 ON, .combo → 콤보 토글 ON, 나머지 → 일반 메모.
    private func deleteSampleMemos() {
        let sampleIds = SampleMemoStorage.load()
        guard !sampleIds.isEmpty else { return }
        do {
            let allMemos = try MemoStore.shared.load(type: .memo)
            let remaining = allMemos.filter { !sampleIds.contains($0.id) }
            try MemoStore.shared.save(memos: remaining, type: .memo)
            SampleMemoStorage.clear()
            viewModel.loadMemos()
            print("🗑️ [ClipKeyboardList] 샘플 메모 \(sampleIds.count)개 삭제 완료")
        } catch {
            print("❌ [ClipKeyboardList.deleteSampleMemos] 샘플 메모 삭제 실패: \(error)")
            viewModel.showPlainToast(NSLocalizedString("샘플 단축어를 삭제하지 못했습니다", comment: "Sample memo delete failed toast"))
        }
    }

    /// 메모 복사 시 호출 — 3회 이상이면 카테고리 배지 끄기 넛지 표시 (1회)
    private func checkCategoryBadgeNudge() {
        guard showVisualCues else { return }
        guard !UserDefaults.standard.bool(forKey: DefaultsKey.categoryBadgeNudgeDismissed) else { return }
        let count = UserDefaults.standard.integer(forKey: DefaultsKey.memoCopyCount) + 1
        UserDefaults.standard.set(count, forKey: DefaultsKey.memoCopyCount)
        if count >= 3 {
            withAnimation(.easeInOut(duration: 0.3)) { showCategoryBadgeNudge = true }
        }
    }

    /// 카테고리 색상 배지 끄기 넛지 배너
    private var categoryBadgeNudgeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: AppSymbol.circleFill)
                .font(.title3)
                .foregroundColor(.blue)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("카테고리 심볼", comment: "Nudge: category symbol title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.text)
                Text(NSLocalizedString("카드 오른쪽 점이 카테고리를 표시해요. 끄시겠어요?", comment: "Nudge: category badge message"))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
            }
            Spacer()
            VStack(spacing: 6) {
                Button {
                    UserDefaults.standard.set(true, forKey: DefaultsKey.categoryBadgeNudgeDismissed)
                    withAnimation { showVisualCues = false; showCategoryBadgeNudge = false }
                } label: {
                    Text(NSLocalizedString("끄기", comment: "Nudge: turn off"))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue, in: Capsule())
                }
                Button {
                    UserDefaults.standard.set(true, forKey: DefaultsKey.categoryBadgeNudgeDismissed)
                    withAnimation { showCategoryBadgeNudge = false }
                } label: {
                    Text(NSLocalizedString("유지", comment: "Nudge: keep on"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
            }
        }
        .padding(12)
        .background(theme.surface)
        .cornerRadius(theme.radiusMd)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private func memoAdd(for suggestion: SuggestionTemplate) -> MemoAdd {
        var add = MemoAdd()
        add.insertedValue = suggestion.content
        switch suggestion.feature {
        case .template:      add.insertedIsTemplate = true
        case .combo:         add.insertedIsCombo    = true
        case .snippet, .smartClipboard: break
        }
        return add
    }

    private func suggestionCard(_ suggestion: SuggestionTemplate) -> some View {
        Button {
            occasionalSuggestion_ = suggestion
            navigateToOccasionalAdd = true
        } label: {
            // 실제 메모 카드(memoCardSurface)와 같은 규격 — 유리 배경·radiusXl·동일 최소
            // 높이·제목 서체까지 맞춰, 예시 카드가 "추가되면 이렇게 보인다"를 그대로 보여준다.
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 6) {
                    Text(suggestion.emoji)
                        .font(.title2)
                    Spacer()
                    Text(suggestion.feature.label)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(suggestion.feature.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(suggestion.feature.color.opacity(0.12))
                        .cornerRadius(theme.radiusXs)
                }
                Spacer(minLength: 16)

                Text(suggestion.title)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(theme.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Text((suggestion.content.components(separatedBy: "\n").first ?? suggestion.content)
                    .templateAwareAttributed(theme: theme, font: .body))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
                    .lineLimit(2)
            }
            // 유리 위 글자 가독성 할로 — memoCardSurface와 동일.
            .compositingGroup()
            .shadow(color: theme.bg, radius: 4, x: 0, y: 0)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: memoCardHeight, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous))
            .modifier(CardGlass(active: true, tint: nil, cornerRadius: theme.radiusXl))
            .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: NSLocalizedString("%@ 예시 단축어 추가", comment: "Suggestion card a11y label"), suggestion.title))
        .accessibilityHint(NSLocalizedString("탭하면 이 예시로 단축어를 만들 수 있어요", comment: "Suggestion card a11y hint"))
    }
}

/// 텍스트 메모 카드의 리퀴드 글래스 배경(iOS 26 순정 glassEffect).
/// active=false(이미지 카드·경량 재정렬 모드)면 아무것도 하지 않는다.
/// tint가 있으면 카테고리 색을 글래스에 입힌다 — 색=카테고리 정체성 유지.
/// tint가 없는 기본(무색) 카드는 프로스트 대신 **맑은 유리(.clear)** — 뒤 배경이
/// 그대로 비쳐 보여 상단 투명 배경·유리 탭바와 같은 유리 언어를 쓴다.
/// 메모 카드의 리퀴드 글래스(iOS 26 `glassEffect`).
///
/// ⚠️ **투명도를 바꾸려면 `backingOpacity` 하나만 만지면 된다.**
///
/// `Glass` 에는 `.regular` / `.clear` / `.identity` 세 변형뿐이고 그 사이를 나타낼
/// 불투명도 인자가 없다. 그래서 두 가지를 조합해 원하는 지점을 만든다:
///   - 유리는 `.clear` (가장 맑은 변형)
///   - 그 **뒤에** 카드 표면색을 아주 옅게 깐다 → 이 판의 불투명도가 곧 다이얼
///
/// `backingOpacity` 0.0 이면 순정 `.clear`(배경에 묻힐 만큼 투명),
/// 0.5 를 넘어가면 체감상 `.regular` 와 비슷해진다. 그 사이를 취한다.
private struct CardGlass: ViewModifier {
    /// 유리 뒤에 깔리는 판의 불투명도 — **투명도 조절 다이얼**.
    /// 올리면 더 불투명(뚜렷)해지고, 내리면 더 맑아진다.
    static let backingOpacity: Double = 0.22

    let active: Bool
    let tint: Color?
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if active {
            if let tint {
                // 색 정체성(즐겨찾기 분홍/커스텀 팔레트색)은 틴트로 유지된다.
                content.glassEffect(
                    .clear.tint(tint).interactive(),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
            } else {
                content.glassEffect(
                    .clear.interactive(),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
            }
        } else {
            content
        }
    }
}

struct ClipKeyboardList_Previews: PreviewProvider {
    static var previews: some View {
        ClipKeyboardList()
    }
}

// MARK: - 카드 누름 효과

/// 카드가 탭에 반응하는 방식. 스킨에 따라 **두 갈래**로 갈린다.
///
/// - 두께가 있는 스킨: 키캡처럼 바닥까지 내려앉았다 돌아온다(스커트가 제자리에 남는다).
/// - 두께가 없는 스킨(납작·예전 방식): 키캡 이전에 쓰던 **푹신한 스케일 바운스**.
///   0.92로 쑥 들어갔다가 1.05까지 부풀고 제자리로 — 키프레임으로 1.05 peak를 보장해
///   빠르게 연타해도 항상 보인다.
///
/// ⚠️ 두 방식을 한 뷰에서 분기하는 이유: 예전 동작을 **버리지 않고 남겨 두기 위해서**다.
///    키캡은 취향이 갈리는 변화라, 설정 하나로 원래대로 돌아갈 수 있어야 한다.
private struct CardPressEffect<Skirt: View>: ViewModifier {
    let trigger: Int
    let legacyBounce: Bool
    let depth: CGFloat
    let pressDuration: Double
    @ViewBuilder let skirt: (CGFloat) -> Skirt

    func body(content: Content) -> some View {
        if legacyBounce {
            content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    CubicKeyframe(0.92, duration: 0.12)   // 부드럽게 쑥 들어감
                    CubicKeyframe(1.05, duration: 0.17)   // 원래보다 크게 튀어나옴
                    CubicKeyframe(1.0, duration: 0.22)    // 원래 크기로 안착
                }
            }
        } else {
            content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, dy in
                view
                    .background(skirt(dy))
                    .offset(y: dy)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    CubicKeyframe(depth, duration: pressDuration)  // 바닥까지
                    CubicKeyframe(0, duration: 0.22)               // 제자리로
                }
            }
        }
    }
}
