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
import PhotosUI
import LeeoKit

// ┌ 이 화면은 다섯 파일로 나뉘어 있다 ───────────────────────────────────────────────
// │ ClipKeyboardList.swift             상태 전부 · 머리줄 · `body` 와 시트를 거는 단계(screenL3~L8)
// │ ClipKeyboardList+Background.swift  목록 뒤 배경 사진
// │ ClipKeyboardList+Cards.swift       카드 한 장 · 금고 입구
// │ ClipKeyboardList+Pages.swift       페이지와 스크롤 · 빈 화면
// │ ClipKeyboardList+Chrome.swift      툴바 · 카드 메뉴 · 시트 · 토스트 · 떠 있는 층
// │ ListTopBanners.swift               맨 위 배너 묶음 (자기 상태를 가진 독립된 뷰)
// └ 파일을 넘나들어야 해서 멤버에 `private` 을 붙이지 않는다. 이 타입은 밖에서 만들기만 하고 안을 만지지 않는다.
struct ClipKeyboardList: View {

    @StateObject var viewModel = ClipKeyboardListViewModel()
    /// 지금 이 사람이 어디쯤인가(`docs/product/USER_STATE_MODEL.md`). 빈 화면이 이걸 보고 갈린다.
    @ObservedObject var userState = UserStateStore.shared
    /// 임시 저장이 있을 때만 + 메뉴에 '임시 저장' 을 세운다.
    @ObservedObject var draftStore = DraftStore.shared
    /// 백지로 시작한 사람(새 설치). 목록이 가장 단순해진다: 큰 제목 '기본', + 하나, 카드 격자.
    /// 안내 띠 · 카드 · 팁 · 고스트 제안 · 화면 전환 버튼이 없다. 분류 · 최근 · 템플릿 · 스택 · 보안은
    /// 그 기능을 켜면(설정 ▸ 기능 더하기 · 넛지) 그 자리만 생긴다. 기존 사용자는 그대로다.
    /// (`FeatureSet` · docs/design/blank-start-onboarding.html)
    @State var blank = FeatureSet.isBlankStartUser()
    /// 키보드 켜기 수업(첫 단축어를 V 로 저장한 직후 · 목록 위 한 줄에서).
    @State var showKeyboardLesson = false
    @State var pendingKeyboardLesson = false
    /// 키보드를 켜고 써 봤다. 그때부터 단순한 목록에도 키보드 미리보기 단추가 선다.
    @State var keyboardLearned = LessonLedger.hasLearned(.keyboard)
    /// 저장 직후 쓰는 모습을 보고 고른 넛지(`FeatureNudge`). 목록 위에 한 번 뜬다.
    @State var nudge: AppFeature?
    /// "켜고 해 보기" 로 여는 기능 수업.
    @State var featureLesson: AppFeature?
    /// 앞뒤로 오갈 때 클립보드를 본다. 복사해 들고 왔으면 '최근' 수업을 연다(`openRecentLessonIfBroughtCopy`).
    @Environment(\.scenePhase) var scenePhase

    // MARK: - View-only State

    @State var showDraftList = false
    // 붙여넣기 허용 안내 팁 - 앱을 열 때마다 "붙여넣기 허용" 팝업이 뜨는 사용자를 설정으로 안내.
    // 클립보드 화면 배너와 dismiss 키(pasteTipDismissed)를 공유해, 어느 쪽에서 닫든 함께 사라진다.
    // 설치 직후엔 iOS 설정에 '다른 앱에서 붙여넣기' 항목이 아직 없어 안내가 헛돌므로,
    // 3번째 실행부터 노출한다(PastePermissionGuidance).
    @State var showPasteTip: Bool = !UserDefaults.standard.bool(forKey: DefaultsKey.pasteTipDismissed)
        && PastePermissionGuidance.isReady
    @FocusState var isSearchFieldFocused: Bool
    @State var memoToDelete: Memo?
    @State var graceBannerVisible: Bool = ProFeatureManager.hasGraceMemoQuota && !ProFeatureManager.didDismissGraceBanner
    @State var showPaywallFromKeyboard: Bool = false
    /// 페이월을 무엇 때문에 띄웠는가. 파는 물건과 첫 문장이 여기서 갈린다.
    /// (`nil` 이면 일반 업그레이드)
    @State var paywallTrigger: ProFeatureManager.LimitType?
    @State var showBulkImport: Bool = false
    /// + 메뉴에서 "단축어 마트" → 차려 둔 것에서 골라 빈칸만 채워 담는 시트
    @State var showShortcutMart: Bool = false
    /// + 메뉴에서 "빠른 메모 담기" → 보관함(Inbox) 추가 시트
    @State var showQuickNoteAdd: Bool = false
    /// App Intent·Control Center·딥링크로 빠른 메모 보관함(Inbox)을 직접 열 때 사용.
    @State var showInboxFromIntent: Bool = false

    // 메모 구분 표시 마스터 토글 - 기본 OFF(제목만, 가장 심플).
    // 켜면 타입 아이콘·배지·테두리·우상단 심볼·카테고리/즐겨찾기 색을 모두 표시.
    // App Group에 저장해 키보드 익스텐션도 같은 설정을 읽는다.
    /// 맨 앞 '최근' 페이지를 세우는가 - 키보드 '최근' 탭과 같은 설정. 페이지 목록은 뷰모델이
    /// 같은 값을 읽어 만든다(`allCategoryTabs`). 여기 둔 것은 설정이 바뀌면 다시 그리게 하려는 것이다.
    @AppStorage(KeyboardPrefs.showRecentClipsTab.key, store: AppGroup.defaults)
    var showsRecentClipsTab: Bool = KeyboardPrefs.showRecentClipsTab.fallback

    @AppStorage(KeyboardPrefs.showVisualCues.key, store: AppGroup.defaults)
    var showVisualCues: Bool = KeyboardPrefs.showVisualCues.fallback
    @State var showCategoryBadgeNudge: Bool = false

    /// 메모 구분 장치(아이콘/배지/테두리/심볼/색) 노출 여부. 설정 "단축어 구분 표시" 토글을 따른다.
    ///
    /// ⚠️ 예외 하나: iOS "색상 없이 구별"(접근성)이 켜져 있으면, 토글이 꺼져 있어도 **색에 뜻이 있는 카드**
    ///    (즐겨찾기 · 내가 만든 분류)에는 카드가 윗줄(하트 · 분류 심볼)을 세운다(`MemoCardSurface.showsCueRow`).
    ///    색을 구별하기 어려운 사람에게 분류를 색만으로 알릴 수 없어서다. 토글 설명이 이 예외를 말한다.
    var visualCuesVisible: Bool {
        showVisualCues
    }
    /// 디스플레이 설정 - 메모 셀 높이(작게 110 / 보통 140 / 크게 180).
    @AppStorage(AppPrefs.memoCardHeight.key) var memoCardHeight: Double = AppPrefs.memoCardHeight.fallback
    /// 카드를 누르면 복사 대신 메뉴가 열리게 뒤집는 설정(설정 ▸ 단축어). 기본은 꺼짐.
    @AppStorage(AppPrefs.cardTapOpensMenu.key) var cardTapOpensMenu: Bool = AppPrefs.cardTapOpensMenu.fallback
    /// 단축어 스킨 프리셋 - 카드 위에 얹히는 것(없음/금고/마을/눈/새/고양이).
    @AppStorage(DefaultsKey.livingSkin, store: AppGroup.defaults)
    var livingSkinRaw: String = LivingSkin.none.rawValue
    /// 동전이 어디서 날아 어디로 들어가는지를 쥐고 있는 것.
    @StateObject var vaultDeposit = VaultDeposit()
    /// 금고에 쌓인 시간(초) - 입금할 때마다 갱신해 잔고 알약이 바로 늘어난다.
    @State var vaultSeconds: Double = 0
    /// 금고 화면 열기.
    @State var showVault = false
    /// 단축어 탭이 무엇을 보여줄지(목록 / 키보드 미리보기). 툴바의 전환 버튼이 이 값을 뒤집는다.
    @AppStorage(DefaultsKey.snippetsTabStyle)
    var snippetsTabStyleRaw: String = SnippetsTabStyle.list.rawValue
    /// 지금 코치가 가리키는 카드. 무대와 **같은 표식**(`tutorialFirstUseMemoId`)에서 온다 -
    /// 튜토리얼 도중 목록으로 넘어와도 가리키는 것이 같아야 한다.
    @State var coachMemoID: UUID?
    @AppStorage(DefaultsKey.tutorialFirstUseMemoId)
    var tutorialTargetRaw: String = ""
    /// 그 카드가 화면 어디에 있는지(global). 안내를 카드 바로 아래에 붙이려고 본다.
    @State var coachRect: CGRect = .zero
    /// 마지막으로 손가락이 닿은 자리(global). 동전이 여기서 튀어 오른다.
    @State var lastTapPoint: CGPoint = .zero
    /// 지금 동전을 보여주고 있는 카드. 이 카드는 내용 대신 동전을 보여준다.
    @State var coinBadgeMemoID: UUID?
    /// 방금 일한 카드 - 테두리가 잠깐 켜진다. 동전·보석이 날아간 **뒤에**
    /// "이 카드가 방금 일했다"를 뒤따라 말해 준다.
    @State var glowMemoID: UUID?
    /// 지금 "복사됨" 도장을 얹고 있는 카드. 토스트 대신 **누른 그 자리**에서 알린다.
    @State var copiedStampMemoID: UUID?
    /// 시트가 떠 있는 동안 쓴 카드. 시트가 닫힌 뒤 도장을 찍는다(동전과 같은 이유).
    @State var pendingCopiedStamp: UUID?
    /// 지금 막 깨지고 있는 지오드. 부서진 모습을 잠깐 붙잡아 둔다
    /// 곧장 새 돌로 넘어가면 무엇이 나왔는지 못 보고 지나간다.
    @State var burstingMemoID: UUID?
    /// 모달이 닫히기를 기다리는 입금. 콤보·템플릿은 시트가 떠 있는 동안 사용이 확정되는데,
    /// 그때 바로 날리면 동전이 시트 뒤에 가려 보이지도 않는다.
    @State var pendingDeposit: (memoID: UUID, seconds: Double, point: CGPoint)?
    /// 카드 내용 힌트 - 설정(메모 표시)에서 켜기/끄기. 키보드도 함께 따르도록 App Group에 저장.
    @AppStorage(KeyboardPrefs.contentHintEnabled.key, store: AppGroup.defaults)
    var contentHintEnabled: Bool = KeyboardPrefs.contentHintEnabled.fallback
    /// 칸 안에 내용 보이기(항상 · 보였다 사라지기 · 안 보이기). 비어 있으면 위 옛 값을 따른다.
    @AppStorage(KeyboardPrefs.contentPreviewMode.key, store: AppGroup.defaults)
    var contentPreviewRaw: String = KeyboardPrefs.contentPreviewMode.fallback
    var contentPreview: ContentPreviewMode {
        .resolve(raw: contentPreviewRaw, legacyHintEnabled: contentHintEnabled)
    }
    /// 목록 모양(격자 · 리스트).
    @AppStorage(AppPrefs.memoListLayout.key) var listLayoutRaw: String = AppPrefs.memoListLayout.fallback
    var isListLayout: Bool { listLayoutRaw == MemoListLayout.list.rawValue }
    /// 카드 한 장의 최소 높이. 리스트는 줄이 낮아야 리스트로 읽힌다.
    var cardMinHeight: CGFloat {
        isListLayout ? MemoListLayout.listRowHeight : memoCardHeight
    }

    // Category
    @State var showCategoryManagement: Bool = false
    @State var showAddCategoryAlert: Bool = false
    @State var newCategoryName: String = ""
    @State var categoryToDelete: String?
    // 롱프레스 컨텍스트에서 즉석 카테고리 생성+배정
    @State var memoForCategoryAssign: Memo?
    @State var newCategoryForMemo: String = ""
    @State var showNewCategoryForMemoAlert: Bool = false

    // 롱프레스 테두리 애니메이션 + 액션 메뉴
    @State var longPressActiveMemo: Memo?
    /// 손가락이 올라가 있는 카드. 말랑한 눌림에만 쓴다.
    /// ⚠️ `longPressActiveMemo` 를 쓰지 않는다. 저쪽은 테두리를 되감느라 뗀 뒤 0.2초 늦게 비워져서,
    ///    그걸 보면 떼는 순간이 아니라 한 박자 뒤에 튕긴다.
    @State var pressedMemoID: UUID?
    /// 방금 탭한 카드와 탭 횟수. 짧게 톡 치면 `onPressingChanged` 가 오지 않아서
    /// (탭 제스처가 먼저 잡아간다) 눌림만 보고는 카드가 꿈쩍도 안 했다. 탭이 잡힌 자리에서 직접 튕긴다.
    @State var tapBounceMemoID: UUID?
    @State var tapBounceCount = 0
    @State var longPressProgress: CGFloat = 0
    @State var memoForActions: Memo?
    @State var showMemoActions: Bool = false
    /// 끌어서 스택 만들기 화면(`MemoStackScreen`).
    @State var showStackScreen: Bool = false


    // 탭 누름 바운스 - 카드별 트리거. 탭하면 해당 카드만 들어갔다(0.92)→1.05배로 튀었다→원래 크기.

    // 순서 바꾸기(흔들기/드래그 재정렬)

    // 즐겨찾기 탭 전용
    @State var showAddFavoriteMemoSheet: Bool = false

    // 스타터팩 - 추천 묶음 일괄 추가 시트

    // 고스트 메모 제안 - 메인 화면에 흐릿하게 "이런 메모는 어때요?" 제안
    @State var ghostSuggestion: QuickPattern?
    @State var ghostAddPattern: QuickPattern?
    let dismissedGhostPatternsKey = "dismissedGhostPatterns_v1"
    // X로 한 번 닫으면 고스트 예시 제안을 영구히 끈다(앱 재실행해도 "또 다른 옵션"이 안 뜸).
    let ghostSuggestionsOffKey = "ghostSuggestionsOff_v1"
    // X로 닫으면 이번 앱 실행(세션) 동안은 다음 제안을 띄우지 않는다.
    static var ghostSuppressedThisSession = false
    /// 이번 실행에서 목록이 한 번이라도 화면에 올라왔는가 - 배경 제안을 켠 순간에 띄우지 않으려고.
    static var listAppearedThisLaunch = false

    /// 만들기 시트를 여는 동안 격자에 먼저 서는 빈 자리.
    ///
    /// 왜 있나: + 를 누르면 시트만 덮여서, 이 단축어가 **어디에 생기는지** 알 수 없었다.
    /// 자리가 먼저 서고 그 위로 시트가 뜨면 "여기에 생기는구나" 가 남는다.
    ///
    /// ⚠️ 저장한 뒤가 아니라 **누른 그 순간** 선다. 예전에는 저장하고 1초 뒤에 내용을
    ///    채우는 연출이었는데, 기다리는 1초가 그냥 굼떠 보였다. 기다림이 아니라
    ///    자리를 보여 주는 것이 하려던 일이다.
    @State var pendingSlot: Bool = false
    /// 자리가 서고 시트가 뜨기까지의 사이. 이만큼은 있어야 자리가 서는 것이 보인다.
    static let pendingSlotBeat: TimeInterval = 0.3
    /// 만들기를 열 때 있던 단축어. 닫혔을 때 새로 생긴 카드를 이것으로 알아본다.
    @State var memoIDsBeforeAdd: Set<UUID> = []
    /// 방금 그 자리에 생긴 카드. 한 번 통 튄다(`celebrateBirth`).
    @State var poppingMemoID: UUID?
    /// 이어 쓰는 중인 임시 저장. 그동안은 그 임시 카드 대신 빈 자리가 같은 곳에 선다.
    @State var resumingDraft: SavedDraft?

    // Sheet modals for MemoAdd
    @State var showAddMemoSheet: Bool = false
    @State var addMemoSheetCategory: String = ""
    @State var showAddTemplateSheet: Bool = false
    @State var showAddStackSheet: Bool = false
    @State var memoToEdit: Memo?
    /// "템플릿으로 만들기" 원본 메모 - 이 메모 내용으로 채운 별도 새 메모를 만든다(원본은 그대로).
    @State var makeTemplateSource: Memo?

    // TipKit
    let welcomeTip = WelcomeTip()
    let addMemoTip = AddMemoTip()

    @Environment(\.appTheme) var theme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    /// 카드 열 수 결정용 - 아이패드·맥에서 `.regular` 가 된다.
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    /// 아이폰 듀오: 펴졌는가, 이 목록이 선 판의 위 끝은 어디인가(DesignSystem/FoldLayout.swift).
    @Environment(\.foldLayout) var foldLayout
    @Environment(\.foldPaneTop) var foldPaneTop

    var shouldShowGraceBanner: Bool {
        graceBannerVisible && !ProFeatureManager.isPro
    }

    /// 페이지 상단 헤더 - 상단 배너 묶음(스크롤 콘텐츠 첫 요소라 스크롤과 함께 이동).
    /// 제목은 여기 두지 않는다 - 순정 네비게이션 바 인라인 타이틀이 담당(고정, glass).
    /// AnyView 타입 소거 - 스택 자식 추가로 인한 타입 메타데이터 폭발 방지.
    /// 스크롤이 내려간 상태인지 - 타이틀 표시 모드 전환·상단 여백 측정 가드용.
    @State var showsInlineNavTitle = false

    /// 사람이 지금 페이지를 굴리고 있는가. 제목 접기·펼치기는 **이때만** 스크롤을 따라간다.
    @State var isPageScrolling = false

    /// 타이틀 표시 모드. **처음부터 inlineLarge 로 시작한다.**
    ///
    /// ⚠️ 예전에는 .large 로 시작해 등장 직후 .inlineLarge 로 바꿨다. inlineLarge 가 접힌 채
    ///    시작한다고 봤기 때문인데, 그건 첫 프레임에 스크롤뷰가 없어서(단축어를 늦게 읽어
    ///    빈 페이지가 먼저 그려졌다) 생긴 일이었다. 지금은 뷰모델이 먼저 읽어 첫 프레임부터
    ///    격자가 있다. 그 상태에서 모드를 바꾸면 **바꾸는 순간 제목이 접혔다 펼쳐지며 카드가
    ///    위로 튀었다 내려왔다**(실측). 바꿀 일을 만들지 않는다.
    @State var titleDisplayMode: ToolbarTitleDisplayMode = .inlineLarge

    /// 페이지 스크롤 오프셋으로 타이틀 모드 전환 - 페이저(UIKit 셀) 안 스크롤은
    /// 네비바가 자동 추적하지 못하고, preference도 셀 경계에서 업데이트가 끊겨(실측)
    /// onScrollGeometryChange(iOS 18+)를 쓴다. iOS 17은 전환 없이 inlineLarge 유지.
    @ViewBuilder
    func trackPageScroll<V: View>(_ view: V) -> some View {
        if #available(iOS 18.0, *) {
            view
                .onScrollPhaseChange { _, phase in
                    isPageScrolling = phase != .idle
                }
                .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top > 44
            } action: { _, scrolled in
                guard scrolled != showsInlineNavTitle else { return }
                // ⚠️ **손이 굴린 것만 스크롤로 친다.** 단축어가 채워질 때, 팁·배너가 늦게 끼어들 때
                //    페이지가 다시 만들어지며 오프셋이 한 번 출렁이는데, 그걸 스크롤로 읽으면
                //    제목이 접혔다가 도로 펼쳐지면서 카드가 통째로 위에서 아래로 미끄러져
                //    내려왔다(실측, 0.2초쯤 140pt, 앱을 켤 때마다). 바는 UIKit 이 그려서
                //    `settling` 의 transaction 으로도 안 막힌다 - 여기서 아예 안 받는다.
                guard isPageScrolling else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    showsInlineNavTitle = scrolled
                    titleDisplayMode = scrolled ? .inline : .inlineLarge
                }
            }
                .modifier(StaleScrollOffsetReset(isScrolling: isPageScrolling) {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        showsInlineNavTitle = false
                        titleDisplayMode = .inlineLarge
                    }
                })
        } else {
            view
        }
    }

    func pageHeader(for tab: CategoryTab) -> AnyView {
        // 앱이 깔아 준 카테고리에 처음 오면 이름을 정하게 한다. 고르기 전에는 늘 선다.
        // ⚠️ 백지 사용자에게도 선다. 업무 · 개인을 받았으면 그 이름을 정하는 일은 미니멀과 상관없다
        //    (예전에는 아래 백지 갈래가 먼저 돌아가 카드가 아예 안 섰다. 2026-10 사용자 신고).
        // (`defaultNameDecisions` 를 읽어 두어야 고른 순간 카드가 걷힌다)
        _ = defaultNameDecisions
        var namePrompt: AnyView?
        if case .custom(let name) = tab, CategoryStore.needsNameDecision(name) {
            namePrompt = AnyView(defaultNamePrompt(name))
        }

        // 처음은 미니멀하게. 이 자리의 안내 띠 · 카드(가장 자주 다시 치는 세 가지 등)를 통째로 비운다
        if blank {
            var rest = AnyView(EmptyView())
            // 하나만 예외: "나중에 다시" 를 고른 사람에게 키보드를 켜자는 한 줄. 켤 때까지만
            if let nudge {
                rest = AnyView(FeatureNudgeCard(feature: nudge, onYes: {
                    FeatureNudge.record(nudge, .yes)
                    FeatureSet.set(nudge, on: true)
                    self.nudge = nil
                    featureLesson = nudge
                }, onNo: {
                    FeatureNudge.record(nudge, .no)
                    self.nudge = nil
                }))
            } else if KeyboardLessonBanner.isDue {
                rest = AnyView(KeyboardLessonBanner { showKeyboardLesson = true })
            }
            guard let namePrompt else { return rest }
            return AnyView(VStack(spacing: 0) { namePrompt; rest })
        }
        guard let namePrompt else { return AnyView(topBanners) }
        return AnyView(VStack(spacing: 0) { namePrompt; topBanners })
    }

    func defaultNamePrompt(_ name: String) -> some View {
        DefaultCategoryNamePrompt(
            name: name,
            onKept: {
                CategoryStore.markNameDecided(name)
                defaultNameDecisions += 1
            },
            onRenamed: { newName in
                defaultNameDecisions += 1
                viewModel.loadCustomCategories()
                viewModel.loadMemos()
                viewModel.selectCategoryTab(.custom(newName), animated: false)
            }
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    /// 복사해 들고 들어온 백지 사용자에게 '최근' 을 처음 한 번 소개한다(묻지 않고 수업을 연다).
    ///
    /// ⚠️ 첫 실행이 끝나지 않았거나 다른 수업이 떠 있으면 비킨다. 실행 창 자리(`LaunchSheetGate`)도
    ///    같이 쥔다. 맨 위 화면이 창을 띄우면 이 덮개가 밀려 내려가기 때문이다.
    func openRecentLessonIfBroughtCopy() {
        let board = UIPasteboard.general
        guard FeatureNudge.broughtCopy(pasteboardChangeCount: board.changeCount, hasStrings: board.hasStrings) else { return }
        guard !ClipKeyboardApp.isBlankStartInProgress,
              featureLesson == nil, !showKeyboardLesson,
              FeatureNudge.mayAsk(.recent) else { return }
        guard LaunchSheetGate.claim("recentLesson") else { return }
        // 같은 복사로 다시 열리지 않게 지금 번호를 적어 둔다
        FeatureNudge.noteLeaving(pasteboardChangeCount: board.changeCount)
        FeatureNudge.record(.recent, .yes)
        FeatureSet.set(.recent, on: true)
        print("📋 [ClipKeyboardList] 복사해 들고 왔다, '최근' 수업을 연다")
        featureLesson = .recent
    }

    /// 기본 카테고리 이름을 정할 때마다 오른다 - 카드를 다시 그리게 하는 값.
    @State var defaultNameDecisions = 0

    /// 네비게이션 바 타이틀 - 보고 있는 카테고리 이름. 찾는 중에는 모든 카테고리에서 찾으므로 '전체'.
    var currentCategoryTitle: String {
        if blank && !usesCategoryHome { return CategoryTab.basic.displayName }
        return isInCategory ? viewModel.displayedCategoryTab.displayName : CategoryTab.all.displayName
    }

    /// 카테고리 고르기(제목 옆 아래 화살표 · 시트)를 세우는가.
    /// 카테고리 기능이 꺼져 있어도 '최근' 이 서면 '최근' · '전체' 두 칸이다.
    var usesCategoryHome: Bool {
        CategoryStore.shared.isFeatureEnabled || showsRecentClipsTab
    }

    @ViewBuilder
    var mainColumn: some View {
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
        // ⚠️ **목록이 자리를 잡는 동안에는 아무것도 움직이지 않는다.**
        //
        //    화면이 뜨고 1초 사이에 늦게 도착하는 것들이 있다: TipKit 팁(보여줄지를 스스로
        //    늦게 판단한다), 상단 배너들, 읽어 들인 메모. 저마다 자기 애니메이션으로
        //    들어오면서 아래 카드를 통째로 밀어 내려서, 목록에 들어갈 때마다 화면이
        //    한 번 출렁이는 것으로 보였다("하늘에서 뚝 떨어진다").
        //
        //    끄는 것은 **그 창 동안의 암묵 애니메이션뿐**이다. 손을 대서 생기는 것들
        //    (카드 누름·동전·글로우·내용 힌트)은 그 뒤에 일어나므로 그대로 산다.
        .transaction { if settling { $0.animation = nil } }
        // 순정 Liquid Glass: 상·하단 스크롤 엣지 효과는 시스템 기본에 맡긴다
        // (네비바·플로팅 탭바가 콘텐츠와 만날 때 soft glass 처리).
    }

    /// 목록이 자리를 잡는 중인가. 위 `mainColumn` 의 주석이 이 값의 전부다.
    ///
    /// ⚠️ 화면에 나타날 때마다 다시 켠다. 탭을 오가면 이 화면이 새로 만들어질 때도,
    ///    그대로 살아 있을 때도 있어서 `@State` 초기값만 믿으면 한쪽이 빠진다.
    static let settleWindow: TimeInterval = 1.0

    @State var settling: Bool = true

    func beginSettling() {
        settling = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleWindow) {
            settling = false
        }
    }

    /// 상단 배너 모음. 배너의 상태와 판단은 `ListTopBanners` 가 쥔다. 여기서는 배너가 화면 밖으로
    /// 내보내는 일(페이월 · 보관함 · 한 번에 정리하기)만 받는다.
    var topBanners: some View {
        ListTopBanners(
            viewModel: viewModel,
            showPasteTip: $showPasteTip,
            graceBannerShowing: shouldShowGraceBanner,
            onPaywall: { trigger in
                paywallTrigger = trigger
                showPaywallFromKeyboard = true
            },
            onOpenInbox: { showInboxFromIntent = true },
            onBulkImport: { showBulkImport = true }
        )
    }

    /// 카테고리 탭/단일 페이지 - 가장 깊은 단일 요소라 AnyView로 타입 소거.
    /// GeometryReader: 세이프에어리어를 무시하기 전의 상단 오프셋(=네비바 하단)을 재서
    /// 각 페이지 스크롤 콘텐츠의 시작 위치(contentMargins)로 쓴다.
    /// 카테고리 한 장을 보이는가. 고르기가 없는 화면(카테고리 기능 꺼짐)과 찾는 중에는 아니다.
    var isInCategory: Bool { usesCategoryHome && !isSearching }

    /// 카테고리 한 장 · 찾은 결과 · 단일 페이지 가운데 하나. 옆으로 넘기는 페이저는 없다.
    /// 다른 카테고리로는 제목 옆 아래 화살표로 여는 시트(`CategoryPickerSheet`)에서 옮긴다.
    @ViewBuilder
    var categoryContent: some View {
        if isInCategory {
            openedCategoryPage
        } else {
            // 찾는 중이면 모든 카테고리에서 찾은 결과를 한 장으로 보인다.
            tabPageView(for: .all)
        }
    }

    /// 보고 있는 카테고리 한 장. 사용자 카테고리는 그 색으로 옅게 물든다.
    var openedCategoryPage: some View {
        let tab = viewModel.displayedCategoryTab
        return tabPageView(for: tab)
            .background { pageTint(for: tab).ignoresSafeArea() }
            .id(tab)
    }

    /// 제목과 그 오른쪽 아래 화살표. 누르면 카테고리 고르기 시트가 뜬다.
    /// 왼쪽 위, 오른쪽 + 단추와 같은 줄에 선다.
    func categoryTitleButton() -> some View {
        Button {
            HapticManager.shared.selection()
            viewModel.isCategoryPickerShown = true
        } label: {
            // 화살표는 글자 높이의 가운데에 작게 붙인다. 바닥선에 맞추면 한글 옆에서 아래로 처져 보인다.
            HStack(alignment: .center, spacing: 4) {
                Text(currentCategoryTitle)
                    .font(.largeTitle.bold())
                    .lineLimit(1)
                Image(systemName: AppSymbol.chevronDown)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.textMuted)
            }
            .foregroundStyle(theme.text)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(currentCategoryTitle)
        .accessibilityHint(NSLocalizedString("카테고리 고르기", comment: "List title: opens the category picker sheet"))
        // VoiceOver 에서만 보이는 동작. 앱에 처음 들어왔을 때 들려준 안내를 다시 듣는다(`VoiceOverWelcome`).
        .accessibilityAction(named: Text(VoiceOverWelcome.replayActionName)) {
            VoiceOverWelcome.speak(cardTapOpensMenu: cardTapOpensMenu)
        }
    }

    /// 스크롤 페이지의 위 여백. 페이지가 이제 늘 바 아래에 서므로 시스템이 바 아래로 밀어 준다.
    /// (예전에는 페이저가 그 일을 안 해서 바 하단을 직접 재어 넣었다.)
    let pageContentTopMargin: CGFloat = 8

    var screenBody: some View {
            ZStack {
                // ⚠️ **바닥은 언제나 있어야 한다.**
                //
                //    투명하게 두고 `ignoresSafeArea` 를 걸면 뒤에 아무것도 없어서
                //    **창의 검정이 그대로 비친다.** 탭을 옮길 때마다 화면이 한 번 까매지는
                //    것으로 보였고, 그건 연출이 아니라 고장으로 읽힌다.
                theme.bg
                    .ignoresSafeArea()

                // 배경 사진(선택) - 유리 카드 뒤로 비치는 사진. 기본은 없음.
                // 탭별 덮어쓰기 지원: 탭을 넘기면 그 탭의 배경으로 부드럽게 교차.
                //
                // ⚠️ **바닥색 위**에 있어야 한다. 예전에는 이 화면 전체의 `.background` 로
                //    달아 뒀는데, 그 자리는 위 `theme.bg` 보다 **뒤**다. 불투명한 바닥이
                //    사진을 통째로 덮어서, 골라도 아무 일도 일어나지 않았다(실측).
                //
                // ⚠️ 그렇다고 바닥을 걷어내면 안 된다. 사진이 아직 안 그려진 첫 프레임에
                //    창의 검정이 그대로 비친다 - 위 주석의 그 사고다. 바닥은 두고 덮는다.
                // 사진이 화면보다 커지지 않는 것은 `BackgroundImageView` 가 지킨다(그 주석).
                if !resolvedBackgroundImage.isEmpty {
                    BackgroundImageView(name: resolvedBackgroundImage)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .id(resolvedBackgroundImage)
                }

                // ⚠️ **화면 전체를 갈래 색으로 물들이지 않는다.** (갈래 색은 페이지마다 붙인다: `pageTint`)
                //
                //    예전에는 여기에 카테고리 색을 옅게(0.11) 깔고 0.38초에 걸쳐 바꿨다.
                //    그런데 페이지는 0.25초쯤에 다 넘어간다. 그래서 카드는 이미 새 카테고리
                //    것인데 화면 색만 뒤늦게 따라오는 구간이 생겼고, 카테고리를 오갈 때마다
                //    **화면 전체가 색을 쓸어 바꾸는 것**이 번쩍임으로 보였다.
                //
                //    녹화 프레임으로 잰 값: 초록(217,233,221) -> 파랑(210,226,243) 이
                //    프레임 77~97 사이, 0.33초에 걸쳐 진행. 그 사이 제목과 카드는 이미
                //    새 카테고리였다.
                //
                //    갈래가 무엇인지는 **카드 색**이 이미 말한다. 바닥까지 같이 물들일
                //    이유가 없다. 바닥은 테마색 하나로 가만히 있는다.

                // v4.1.0: 활성화 배너를 메모 위에 overlay하지 않고 VStack flow 안에
                // 두어 콘텐츠가 자연스럽게 아래로 밀려남. 다른 배너들(ReviewBanner,
                // GraceQuotaBanner 등)과 통일된 패턴.
                mainColumn
            }
            // 탭을 넘길 때 배경 사진이 부드럽게 교차한다(위 transition 과 짝).
            .animation(.easeInOut(duration: 0.25), value: resolvedBackgroundImage)
            // 검색 키보드 내리기: 메모 영역 아무 데나 탭(simultaneous라 카드 탭 동작은 그대로 실행)
            // 하거나 스크롤하면 닫힌다. 검색바 자신은 safeAreaInset의 분리 영역이라
            // 탭해도 포커스가 풀리지 않음(깜빡임 없음).
            .simultaneousGesture(TapGesture().onEnded { isSearchFieldFocused = false })
            .scrollDismissesKeyboard(.immediately)
            // 검색은 순정 .searchable(검색 탭)로 이전 - 커스텀 하단 검색바 제거.
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

    var screenBody2: some View {
        toolbarSheets(AnyView(screenBody))
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
            .task {
                viewModel.loadMemos()
                refreshGhostSuggestion()
                AnalyticsService.setMemoBucket(viewModel.memos.count)
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
                guard !isUp else { return }
                if let stamp = pendingCopiedStamp {
                    pendingCopiedStamp = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { stampCopied(stamp) }
                }
                guard let pending = pendingDeposit else { return }
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
            // Toast 메시지 오버레이
            .overlay(alignment: .bottom) {
                toastOverlay
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: viewModel.showToast)

            // 순정 Inline Large 타이틀 - 맨 위에선 큰 제목이 바에 표시되고,
            // 스크롤이 내려가면 .inline(가운데 작은 제목)으로 전환(사용자 지정).
            // 페이저 안 스크롤은 시스템이 자동 추적하지 못해 trackPageScroll이
            // 오프셋을 보고 디스플레이 모드를 직접 전환한다.
            // 타이틀 뒤 배경 밴드는 각 ScrollView의 scrollEdgeEffectHidden이 막는다.
            .navigationTitle(currentCategoryTitle)
            #if os(iOS)
            .toolbarTitleDisplayMode(titleDisplayMode)
            // [디자인 불변식] 상·하단 배경 언제나 투명 - 정의는 alwaysTransparentBars() 참고.
            // TabView 전역 설정만으로는 이 화면의 스크롤뷰까지 확실히 닿지 않아
            // (하단 탭바 뒤 콘텐츠가 뿌옇게 바래는 회귀 발생) 로컬에도 명시한다.
            .alwaysTransparentBars()
            #endif
            .accessibilityLabel(NSLocalizedString("Saved items", comment: "Screen: main memo list"))
    }

    // ⚠️ 아래 단계들은 안쪽 화면을 **AnyView 로 감싸서** 받는다. 떼지 말 것.
    //
    //    수식어를 붙일 때마다 화면 값이 통째로 한 번 더 복사되는데, 그 값이 단계를 지날수록 커져서
    //    (맨 바깥이 13KB) Debug 빌드에서 이 체인만 스택을 850KB 썼다. 기기의 메인 스레드 스택은 1MB 라
    //    `screenL3` 의 `screenBody2` 줄에서 EXC_BAD_ACCESS (code=2) 로 죽었다. 시뮬레이터는 스택이 8MB 라 멀쩡하다.
    //    AnyView 는 값을 힙에 두고 참조만 넘기므로 단계마다 크기가 다시 작아진다 (850KB → 190KB).
    //    docs/postmortem/LIST_VIEW_STACK_OVERFLOW.md
    var screenL3: some View {
        AnyView(screenBody2)
            .onChange(of: viewModel.searchQueryString) { _, _ in viewModel.applyFilters() }
            .onChange(of: viewModel.selectedTypeFilter) { _, _ in
                viewModel.applyFilters()
                viewModel.saveSelectedFilter()
            }
            .onChange(of: viewModel.showFavoritesFilter) { _, _ in viewModel.applyFilters() }
            // 인증 실패 Alert
    }

    var screenL4: some View {
        AnyView(screenL3)
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
                    memoActions(memo)
                }
            }
            // 순서 바꾸기 - 전체 메모 흔들기/드래그 재정렬 (전체화면)
    }

    var screenL5: some View {
        AnyView(screenL4)
            .fullScreenCover(isPresented: $viewModel.isReorderMode) {
                MemoReorderScreen(viewModel: viewModel,
                                  style: cardStyle,
                                  columnCount: gridColumnCount)
                    .appFoldConfined()
            }
            .fullScreenCover(isPresented: $showStackScreen) {
                MemoStackScreen(viewModel: viewModel,
                                style: cardStyle,
                                columnCount: gridColumnCount)
                    .appFoldConfined()
            }
            // 여러 개 고르기 - 지금 탭의 카드를 체크로 골라 한꺼번에 옮기거나 지운다.
            .fullScreenCover(isPresented: $viewModel.isSelectionMode) {
                MemoSelectionScreen(viewModel: viewModel,
                                    style: cardStyle,
                                    columnCount: gridColumnCount)
                    .appFoldConfined()
            }
            // 즐겨찾기 탭 + 버튼 - 즐겨찾기로 바로 저장
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
    }

    var screenL6: some View {
        AnyView(screenL5)
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
            // "템플릿으로 만들기" - 원본 내용으로 채운 별도 새 메모(memoId=nil). 본문 포커스로
            // 변수 삽입바를 바로 띄우고, 저장하면 원본은 그대로 둔 채 새 템플릿 메모가 생긴다.
            .sheet(item: $makeTemplateSource, onDismiss: {
                viewModel.loadMemos()
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
                selectedStackIdForSheet: $viewModel.selectedStackIdForSheet,
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
                onStackDismiss: {
                    viewModel.selectedStackIdForSheet = nil
                    viewModel.loadMemos()
                }
            ))
            .onAppear {
                beginSettling()
                viewModel.onAppear()
                // 빈 화면이 사람에 따라 갈리므로 들어올 때마다 다시 잰다.
                userState.refresh()
                // ⚠️ 제안 카드("눌러서 추가해보기")의 자리를 **첫 프레임 전에** 정한다. `.task` 에서만
                //    정하면 격자가 한 번 그려진 뒤 맨 앞에 카드가 끼어들어, 모든 카드가 한 칸씩
                //    밀리며 앱을 켤 때마다 덜컹했다(실측). 단축어는 뷰모델이 이미 읽어 두었다.
                refreshGhostSuggestion()
                // v4.1.0: 카테고리 기능 마이그레이션 - 기존 사용자 자동 활성
                CategoryStore.shared.migrateFeatureEnabledIfNeeded(
                    existingMemoCategories: viewModel.memos.map { $0.category }
                )
            }
    }

    var screenL7: some View {
        AnyView(screenL6)
            .paywall(isPresented: $showPaywallFromKeyboard, triggeredBy: paywallTrigger)
            // 문턱에 닿았으면 앱을 열 때 영수증 화면을 한 번 띄운다(FreeUseScreens.swift).
            .freeUseMoments()
            .onReceive(NotificationCenter.default.publisher(for: .showPaywall)) { _ in
                showPaywallFromKeyboard = true
            }
            #if DEBUG
            // 스토어 스크린샷: `-ScreenshotScene stack` 이면 스택을 누른 것과 같은 길로 시트를 연다.
            .onAppear {
                guard UserDefaults.standard.string(forKey: "ScreenshotScene") == "stack" else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if let memo = viewModel.memos.first(where: { $0.isStack }) {
                        viewModel.selectedStackIdForSheet = memo.id
                    }
                }
            }
            #endif
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                viewModel.onSceneResume()
                consumePendingInboxOpen()
            }
            // 콜드 런치에서 didBecomeActive가 위 구독 설치보다 먼저 지나간 경우의 폴백.
            // (Control Center 컨트롤이 켠 보류 플래그를 첫 표시 시점에 소비 - 멱등이라 중복 무해)
            .onAppear { consumePendingInboxOpen() }
    }

    var screenL8: some View {
        AnyView(screenL7)
            .onAppear { syncCoachTarget() }
            .onChange(of: tutorialTargetRaw) { _, _ in syncCoachTarget() }
            // ⚠️ 목록은 무대 뒤에 **깔린 채로 살아 있다**(`SnippetsTab.content`).
            //    무대에서 단축어를 만들어도 이 화면은 다시 만들어지지 않으므로,
            //    바뀌었다는 소식을 직접 듣고 다시 읽어야 한다.
            .onReceive(NotificationCenter.default.publisher(for: .memoDataChanged)) { _ in
                viewModel.loadMemos()
            }
            .onReceive(NotificationCenter.default.publisher(for: .demoSamplesInserted)) { _ in
                viewModel.loadCustomCategories()   // 시드된 카테고리 탭 반영
                viewModel.loadMemos()
            }
            // 방금 만든 단축어가 지금 탭에서 안 보이면 보이는 탭으로 옮겨 간다.
            // (저장은 됐는데 화면은 그대로라 "어디 갔지?" 가 되던 자리)
            .onReceive(NotificationCenter.default.publisher(for: .memoSaved)) { note in
                guard let id = note.object as? UUID else { return }
                viewModel.loadCustomCategories()   // 저장 화면에서 새로 만든 카테고리 반영
                viewModel.loadMemos()
                viewModel.revealSavedMemo(id: id)
            }
            // 복원·가져오기는 카테고리 목록을 App Group 에 직접 갈아끼운다.
            // `.memoDataChanged` 는 단축어만 다시 읽으므로 탭은 그대로 비어 있었다.
            .onReceive(NotificationCenter.default.publisher(for: .dataRestored)) { _ in
                viewModel.loadCustomCategories()
                viewModel.loadMemos()
            }
            .navigationDestination(isPresented: $showInboxFromIntent) {
                QuickNoteInboxView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openShortcutMart)) { _ in
                showShortcutMart = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .openBulkImport)) { _ in
                showBulkImport = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .openQuickNoteInbox)) { _ in
                // 알림 경로로 처리했으면 보류 플래그도 함께 소비(다음 활성화 때 중복 열림 방지).
                AppGroup.defaults?.set(false, forKey: DefaultsKey.pendingOpenQuickNoteInbox)
                showInboxFromIntent = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .openQuickNoteAdd)) { _ in
                AppGroup.defaults?.set(false, forKey: DefaultsKey.pendingQuickNoteAdd)
                showQuickNoteAdd = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .captureClipboard)) { _ in
                // 앱이 앞에 선 뒤에 읽어야 한다. 알림은 앱이 아직 넘어오는 중에 올 수 있어
                // 여기서는 보류 플래그만 두고, 실제 읽기는 활성화 때 한 곳(`consumePendingInboxOpen`)에서 한다.
                if UIApplication.shared.applicationState == .active {
                    consumePendingInboxOpen()
                }
            }
    }

    // MARK: - 배경 이미지 (선택)

    @AppStorage(DefaultsKey.listBackgroundImageV1, store: AppGroup.defaults)
    var listBackgroundImage: String = ""
    @AppStorage(DefaultsKey.backgroundOfferResolvedV1, store: AppGroup.defaults)
    var backgroundOfferResolved: Bool = false
    @State var showBackgroundOffer = false
    @State var showBackgroundPicker = false

    /// 탭별 배경 덮어쓰기 [CategoryTab.storageKey: 에셋 이름]. ""는 "이 탭만 배경 없음".
    /// 항목이 없는 탭은 전체 기본값(listBackgroundImage)을 따른다.
    @State var perTabBackgrounds: [String: String] = [:]
    /// 배경 선택 시트의 적용 범위 - 현재 탭만 / 모든 탭.
    @State var backgroundScopeAllTabs = false
    /// 사진첩에서 고른 것. 고르는 즉시 저장하고 배경으로 적용한다.
    @State var pickedBackgroundItem: PhotosPickerItem?
    /// 내가 넣어 둔 배경들.
    @State var myBackgrounds: [String] = []

    var body: some View {
        #if DEBUG
        let _ = HangProbe.noteRender("ClipKeyboardList")
        #endif
        NavigationStack {
            screenL8
                // 다 가진 사람에게 드물게 "혼자 만드는 앱이에요" 창(`TipAskSheetAnchor`). 화면 맨 바깥 한 곳에만.
                .background(TipAskSheetAnchor())
                // 펼친 듀오: 접힌 선 띠의 고르는 쪽 절반을 지금 페이지의 갈래 색으로(`FoldSplitView.hinge`)
                .preference(key: FoldBandLeadFillKey.self, value: pageTint(for: viewModel.displayedCategoryTab))
                // 기능을 켜면 그 자리가 바로 생긴다(설정 ▸ 기능 더하기 · 넛지)
                .onReceive(NotificationCenter.default.publisher(for: .featureSetChanged)) { _ in
                    blank = FeatureSet.isBlankStartUser()
                }
                // 결과 쪽 판의 새 단축어가 닫혔다 = 시트가 닫힌 것과 같다(목록 다시 읽기 · 키보드 수업)
                .onReceive(FoldComposeRouter.shared.$request.dropFirst()) { request in
                    guard request == nil else { return }
                    viewModel.loadMemos()
                    if pendingKeyboardLesson {
                        pendingKeyboardLesson = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showKeyboardLesson = true }
                    }
                }
                // 백지 사용자가 자기 단축어를 처음 담았다 → 장부에 적고, 키보드가 아직이면 수업을 잡아 둔다
                .onReceive(NotificationCenter.default.publisher(for: .memoSaved)) { _ in
                    guard FeatureSet.isBlankStartUser() else { return }
                    // 처음이 아니면 방금 저장한 것을 보고 넛지를 하나 고른다(하루 하나 · 기능마다 한 번)
                    if LessonLedger.hasLearned(.makeOwn) {
                        let memos = ((try? MemoStore.shared.load(type: .memo)) ?? []).sorted { $0.lastEdited > $1.lastEdited }
                        guard let saved = memos.first else { return }
                        let others = memos.dropFirst().map { (title: $0.title, value: $0.value) }
                        if let f = FeatureNudge.suggestion(saved: (saved.title, saved.value), others: others,
                                                           recentPastes: FeatureNudge.pastedSaves()),
                           FeatureNudge.mayAsk(f) {
                            FeatureNudge.record(f, .shown)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                withAnimation(.spring(duration: 0.45)) { nudge = f }
                            }
                        }
                        return
                    }
                    LessonLedger.learn(.makeOwn)
                    if !LessonLedger.hasLearned(.keyboard) && !KeyboardInstallState.isUsable {
                        pendingKeyboardLesson = true
                    }
                }
                #if DEBUG
                // 개발 빌드에서 수업 화면을 곧장 연다(명령줄 시뮬레이터는 누를 수 없어서): -PreviewKeyboardLesson YES
                .onAppear { if UserDefaults.standard.bool(forKey: "PreviewKeyboardLesson") { showKeyboardLesson = true } }
                .onAppear {
                    if UserDefaults.standard.bool(forKey: "PreviewAddSheet") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { openAddMemoWithSlot() }
                    }
                    if UserDefaults.standard.bool(forKey: "PreviewMemoActions") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            guard let memo = viewModel.memos.first else { return }
                            memoForActions = memo
                            if foldLayout.isUnfolded { FoldComposeRouter.shared.open(pane: AnyView(memoActions(memo))) }
                            else { showMemoActions = true }
                        }
                    }
                }
                #endif
                // 무언가를 복사한 채로 들어왔다 → 처음 한 번 '최근' 을 소개한다
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { openRecentLessonIfBroughtCopy() }
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { openRecentLessonIfBroughtCopy() }
                    case .background:
                        FeatureNudge.noteLeaving(pasteboardChangeCount: UIPasteboard.general.changeCount)
                    default:
                        break
                    }
                }
                .fullScreenCover(item: $featureLesson) { f in
                    FeatureLessonView(feature: f) { featureLesson = nil }
                }
                .fullScreenCover(isPresented: $showKeyboardLesson) {
                    KeyboardLessonView {
                        showKeyboardLesson = false
                        keyboardLearned = LessonLedger.hasLearned(.keyboard)
                    }
                }
                // 새 배경 기능 1회 제안 - 아니요면 예전 모습 그대로, 써보면 기본 배경 적용.
                .alert(
                    NSLocalizedString("새로운 배경을 써보시겠어요?", comment: "Background offer alert title"),
                    isPresented: $showBackgroundOffer
                ) {
                    Button(NSLocalizedString("써볼게요", comment: "Accept category activation")) {
                        backgroundOfferResolved = true
                        withAnimation { listBackgroundImage = ListBackgroundPickerSheet.options[0] }
                        showBackgroundPicker = true
                    }
                    Button(NSLocalizedString("괜찮아요", comment: "Decline category activation"), role: .cancel) {
                        backgroundOfferResolved = true
                        listBackgroundImage = ""
                    }
                } message: {
                    Text(NSLocalizedString("리스트 뒤에 사진을 깔면 유리 카드가 살아나요. 언제든 오른쪽 위 ⋯ 메뉴 > 배경 이미지에서 바꾸거나 끌 수 있어요.", comment: "Background offer alert message"))
                }
                .sheet(isPresented: $showBackgroundPicker, onDismiss: { pickedBackgroundItem = nil }) {
                    ListBackgroundPickerSheet(
                        scopeAllTabs: $backgroundScopeAllTabs,
                        pickedItem: $pickedBackgroundItem,
                        currentTabName: viewModel.selectedCategoryTab.displayName,
                        myBackgrounds: myBackgrounds,
                        isSelected: isBackgroundSelected,
                        onApply: applyBackground,
                        onRemoveMine: removeUserBackground,
                        onDone: { showBackgroundPicker = false }
                    )
                        .onAppear { myBackgrounds = BackgroundImageStore.saved() }
                        .onChange(of: pickedBackgroundItem) { _, item in
                            adoptPickedBackground(item)
                        }
                }
                .onAppear {
                    loadPerTabBackgrounds()
                    // ⚠️ **앱을 켠 그 화면에서는 묻지 않는다.** 켜고 1초 만에 판이 덮이면 화면이
                    //    자리를 잡는 움직임과 겹쳐 앱이 켜지면서 덜컹이는 것으로 읽혔다.
                    //    다른 탭에 한 번 다녀와 목록으로 돌아온 때 묻는다.
                    let isLaunchAppearance = !Self.listAppearedThisLaunch
                    Self.listAppearedThisLaunch = true
                    guard !isLaunchAppearance else { return }
                    guard !backgroundOfferResolved, isReadyForBackgroundOffer else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        // 이번 실행에 이미 다른 창이 떴으면 다음에 묻는다(`LaunchSheetGate`).
                        guard LaunchSheetGate.claim("backgroundOffer") else { return }
                        showBackgroundOffer = true
                    }
                }
        }
    }

    /// + 메뉴의 "임시 저장" 항목 라벨(개수 배지).
    var draftMenuTitle: String {
        let count = DraftStore.shared.count
        return count > 0
            ? String(format: NSLocalizedString("임시 저장 (%d)", comment: "Menu: drafts with count"), count)
            : NSLocalizedString("임시 저장 보기", comment: "Menu: view drafts")
    }


    /// Control Center 컨트롤·딥링크가 켜둔 보류 플래그를 소비한다(앱 활성화 시).
    /// - 빠른 메모 컨트롤: 입력 시트 표시 / - 보관함 열기 컨트롤: Inbox 화면 이동.
    /// - 클립보드 담기(동작 버튼): 방금 복사한 글을 복사 기록에 담고 토스트로 알린다.
    func consumePendingInboxOpen() {
        let store = AppGroup.defaults
        if store?.bool(forKey: DefaultsKey.pendingQuickNoteAdd) == true {
            store?.set(false, forKey: DefaultsKey.pendingQuickNoteAdd)
            print("🎛️ [ClipKeyboardList] 제어센터 보류 플래그 소비 → 빠른 메모 입력 시트")
            showQuickNoteAdd = true
        }
        if store?.bool(forKey: DefaultsKey.pendingClipboardCapture) == true {
            store?.set(false, forKey: DefaultsKey.pendingClipboardCapture)
            print("🎛️ [ClipKeyboardList] 보류 플래그 소비 → 클립보드 담기")
            viewModel.captureClipboardFromButton()
        }
        if store?.bool(forKey: DefaultsKey.pendingOpenQuickNoteInbox) == true {
            store?.set(false, forKey: DefaultsKey.pendingOpenQuickNoteInbox)
            print("🎛️ [ClipKeyboardList] 제어센터 보류 플래그 소비 → 보관함 열기")
            showInboxFromIntent = true
        }
    }

}

struct ClipKeyboardList_Previews: PreviewProvider {
    static var previews: some View {
        ClipKeyboardList()
    }
}

// MARK: - 내용이 줄었는데 넘어간 자리에 멈춘 스크롤

/// 페이지 내용이 줄어 **이미 끝을 넘어선 자리에 멈춘** 스크롤을 맨 위로 되돌린다.
///
/// 왜 필요한가: 기본 페이지 위에는 이름 정하기 카드 · 세 가지 카드가 붙는다. 그 카드로 길어진
/// 페이지를 내려 보다가 카드가 걷히면 내용이 짧아지는데, UIKit 스크롤뷰는 그때 자리를 끌어오지
/// 않는다. 남은 카드가 제목줄 밑에 반쯤 깔리고 아래는 텅 빈 채 멈췄다. 제목도 접힌 채로 남는다
/// (신고 화면: 작은 "General" 아래 잘린 카드 두 장, 그 밑은 빈 화면. 손으로 끌면 그제야 튕겨 돌아온다).
///
/// ⚠️ 손이 굴리는 동안에는 안 건드린다. 끝에서 고무줄처럼 늘어나는 것도 '넘어선 자리' 로 읽힌다.
@available(iOS 18.0, *)
private struct StaleScrollOffsetReset: ViewModifier {
    let isScrolling: Bool
    let onReset: () -> Void

    @State private var position = ScrollPosition(edge: .top)

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onScrollGeometryChange(for: Bool.self) { geo in
                let maxOffset = max(-geo.contentInsets.top,
                                    geo.contentSize.height + geo.contentInsets.bottom - geo.containerSize.height)
                return geo.contentOffset.y > maxOffset + 1
            } action: { _, stale in
                guard stale, !isScrolling else { return }
                position.scrollTo(edge: .top)
                onReset()
            }
    }
}
