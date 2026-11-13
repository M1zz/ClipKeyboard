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

struct ClipKeyboardList: View {

    @StateObject private var viewModel = ClipKeyboardListViewModel()
    /// 지금 이 사람이 어디쯤인가(`docs/product/USER_STATE_MODEL.md`). 빈 화면이 이걸 보고 갈린다.
    @ObservedObject private var userState = UserStateStore.shared
    /// 임시 저장이 있을 때만 + 메뉴에 '임시 저장' 을 세운다.
    @ObservedObject private var draftStore = DraftStore.shared
    /// 백지로 시작한 사람(새 설치). 목록이 가장 단순해진다: 큰 제목 '기본', + 하나, 카드 격자.
    /// 안내 띠 · 카드 · 팁 · 고스트 제안 · 화면 전환 버튼이 없다. 분류 · 최근 · 템플릿 · 스택 · 보안은
    /// 그 기능을 켜면(설정 ▸ 기능 더하기 · 넛지) 그 자리만 생긴다. 기존 사용자는 그대로다.
    /// (`FeatureSet` · docs/design/blank-start-onboarding.html)
    @State private var blank = FeatureSet.isBlankStartUser()
    /// 키보드 켜기 수업(첫 단축어를 V 로 저장한 직후 · 목록 위 한 줄에서).
    @State private var showKeyboardLesson = false
    @State private var pendingKeyboardLesson = false
    /// 키보드를 켜고 써 봤다. 그때부터 단순한 목록에도 키보드 미리보기 단추가 선다.
    @State private var keyboardLearned = LessonLedger.hasLearned(.keyboard)
    /// 저장 직후 쓰는 모습을 보고 고른 넛지(`FeatureNudge`). 목록 위에 한 번 뜬다.
    @State private var nudge: AppFeature?
    /// "켜고 해 보기" 로 여는 기능 수업.
    @State private var featureLesson: AppFeature?
    /// 앞뒤로 오갈 때 클립보드를 본다. 복사해 들고 왔으면 '최근' 수업을 연다(`openRecentLessonIfBroughtCopy`).
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - View-only State

    @State private var showDraftList = false
    // 붙여넣기 허용 안내 팁 - 앱을 열 때마다 "붙여넣기 허용" 팝업이 뜨는 사용자를 설정으로 안내.
    // 클립보드 화면 배너와 dismiss 키(pasteTipDismissed)를 공유해, 어느 쪽에서 닫든 함께 사라진다.
    // 설치 직후엔 iOS 설정에 '다른 앱에서 붙여넣기' 항목이 아직 없어 안내가 헛돌므로,
    // 3번째 실행부터 노출한다(PastePermissionGuidance).
    @State private var showPasteTip: Bool = !UserDefaults.standard.bool(forKey: DefaultsKey.pasteTipDismissed)
        && PastePermissionGuidance.isReady
    @FocusState private var isSearchFieldFocused: Bool
    @State private var memoToDelete: Memo?
    @State private var graceBannerVisible: Bool = ProFeatureManager.hasGraceMemoQuota && !ProFeatureManager.didDismissGraceBanner
    // 가치 순간 Pro 넛지 - 1회·닫기 가능 (페이월 노출률 향상)
    @State private var proNudgeDismissed: Bool = UserDefaults.standard.bool(forKey: DefaultsKey.proValueNudgeDismissedV1)
    @State private var showPaywallFromKeyboard: Bool = false
    /// 페이월을 무엇 때문에 띄웠는가. 파는 물건과 첫 문장이 여기서 갈린다.
    /// (`nil` 이면 일반 업그레이드)
    @State private var paywallTrigger: ProFeatureManager.LimitType?
    /// 잘못 열려 있던 기능이 닫힌다는 안내 - 떠 있는 동안 붙잡아 둔다(`ProFeatureManager.accessEndingNoticeNow`).
    @State private var accessNotice: ProFeatureManager.AccessEndingNotice? = ProFeatureManager.accessEndingNoticeNow
    /// 지금 화면에 서 있는 결제 순간.
    ///
    /// ⚠️ **왜 상태로 붙잡아 두나:** 띄우는 그 자리에서 "봤다"고 못박는데(평생 한 번),
    ///    그러면 `dueMoment` 는 곧바로 nil 이 된다. 화면이 그 값을 그대로 보고 있으면
    ///    배너가 나타나자마자 사라진다. 기록은 기록대로 남기고, 지금 보여 줄 것은 여기에 둔다.
    @State private var activeMoment: PurchaseMoment?
    @State private var showBulkImport: Bool = false
    /// + 메뉴에서 "단축어 마트" → 차려 둔 것에서 골라 빈칸만 채워 담는 시트
    @State private var showShortcutMart: Bool = false
    /// + 메뉴에서 "빠른 메모 담기" → 보관함(Inbox) 추가 시트
    @State private var showQuickNoteAdd: Bool = false
    /// App Intent·Control Center·딥링크로 빠른 메모 보관함(Inbox)을 직접 열 때 사용.
    @State private var showInboxFromIntent: Bool = false
    /// Inbox 배너를 닫은 시점의 항목 수. 이보다 더 쌓이면(=새 캡처) 배너가 다시 나타난다.
    @State private var inboxBannerDismissCount: Int = 0

    // 메모 구분 표시 마스터 토글 - 기본 OFF(제목만, 가장 심플).
    // 켜면 타입 아이콘·배지·테두리·우상단 심볼·카테고리/즐겨찾기 색을 모두 표시.
    // App Group에 저장해 키보드 익스텐션도 같은 설정을 읽는다.
    /// 맨 앞 '최근' 페이지를 세우는가 - 키보드 '최근' 탭과 같은 설정. 페이지 목록은 뷰모델이
    /// 같은 값을 읽어 만든다(`allCategoryTabs`). 여기 둔 것은 설정이 바뀌면 다시 그리게 하려는 것이다.
    @AppStorage(KeyboardPrefs.showRecentClipsTab.key, store: AppGroup.defaults)
    private var showsRecentClipsTab: Bool = KeyboardPrefs.showRecentClipsTab.fallback

    @AppStorage(KeyboardPrefs.showVisualCues.key, store: AppGroup.defaults)
    private var showVisualCues: Bool = KeyboardPrefs.showVisualCues.fallback
    @State private var showCategoryBadgeNudge: Bool = false

    /// 메모 구분 장치(아이콘/배지/테두리/심볼/색) 노출 여부. 설정 "단축어 구분 표시" 토글을 따른다.
    ///
    /// ⚠️ 예외 하나: iOS "색상 없이 구별"(접근성)이 켜져 있으면, 토글이 꺼져 있어도 **색에 뜻이 있는 카드**
    ///    (즐겨찾기 · 내가 만든 분류)에는 카드가 윗줄(하트 · 분류 심볼)을 세운다(`MemoCardSurface.showsCueRow`).
    ///    색을 구별하기 어려운 사람에게 분류를 색만으로 알릴 수 없어서다. 토글 설명이 이 예외를 말한다.
    private var visualCuesVisible: Bool {
        showVisualCues
    }
    /// 디스플레이 설정 - 메모 셀 높이(작게 110 / 보통 140 / 크게 180).
    @AppStorage(AppPrefs.memoCardHeight.key) private var memoCardHeight: Double = AppPrefs.memoCardHeight.fallback
    /// 카드를 누르면 복사 대신 메뉴가 열리게 뒤집는 설정(설정 ▸ 단축어). 기본은 꺼짐.
    @AppStorage(AppPrefs.cardTapOpensMenu.key) private var cardTapOpensMenu: Bool = AppPrefs.cardTapOpensMenu.fallback
    /// 단축어 스킨 프리셋 - 카드 위에 얹히는 것(없음/금고/마을/눈/새/고양이).
    @AppStorage(DefaultsKey.livingSkin, store: AppGroup.defaults)
    private var livingSkinRaw: String = LivingSkin.none.rawValue
    /// 동전이 어디서 날아 어디로 들어가는지를 쥐고 있는 것.
    @StateObject private var vaultDeposit = VaultDeposit()
    /// 금고에 쌓인 시간(초) - 입금할 때마다 갱신해 잔고 알약이 바로 늘어난다.
    @State private var vaultSeconds: Double = 0
    /// 금고 화면 열기.
    @State private var showVault = false
    /// 단축어 탭이 무엇을 보여줄지(목록 / 키보드 미리보기). 툴바의 전환 버튼이 이 값을 뒤집는다.
    @AppStorage(DefaultsKey.snippetsTabStyle)
    private var snippetsTabStyleRaw: String = SnippetsTabStyle.list.rawValue
    /// 지금 코치가 가리키는 카드. 무대와 **같은 표식**(`tutorialFirstUseMemoId`)에서 온다 -
    /// 튜토리얼 도중 목록으로 넘어와도 가리키는 것이 같아야 한다.
    @State private var coachMemoID: UUID?
    @AppStorage(DefaultsKey.tutorialFirstUseMemoId)
    private var tutorialTargetRaw: String = ""
    /// 그 카드가 화면 어디에 있는지(global). 안내를 카드 바로 아래에 붙이려고 본다.
    @State private var coachRect: CGRect = .zero
    /// 마지막으로 손가락이 닿은 자리(global). 동전이 여기서 튀어 오른다.
    @State private var lastTapPoint: CGPoint = .zero
    /// 지금 동전을 보여주고 있는 카드. 이 카드는 내용 대신 동전을 보여준다.
    @State private var coinBadgeMemoID: UUID?
    /// 방금 일한 카드 - 테두리가 잠깐 켜진다. 동전·보석이 날아간 **뒤에**
    /// "이 카드가 방금 일했다"를 뒤따라 말해 준다.
    @State private var glowMemoID: UUID?
    /// 지금 "복사됨" 도장을 얹고 있는 카드. 토스트 대신 **누른 그 자리**에서 알린다.
    @State private var copiedStampMemoID: UUID?
    /// 시트가 떠 있는 동안 쓴 카드. 시트가 닫힌 뒤 도장을 찍는다(동전과 같은 이유).
    @State private var pendingCopiedStamp: UUID?
    /// 지금 막 깨지고 있는 지오드. 부서진 모습을 잠깐 붙잡아 둔다
    /// 곧장 새 돌로 넘어가면 무엇이 나왔는지 못 보고 지나간다.
    @State private var burstingMemoID: UUID?
    /// 모달이 닫히기를 기다리는 입금. 콤보·템플릿은 시트가 떠 있는 동안 사용이 확정되는데,
    /// 그때 바로 날리면 동전이 시트 뒤에 가려 보이지도 않는다.
    @State private var pendingDeposit: (memoID: UUID, seconds: Double, point: CGPoint)?
    /// 카드 내용 힌트 - 설정(메모 표시)에서 켜기/끄기. 키보드도 함께 따르도록 App Group에 저장.
    @AppStorage(KeyboardPrefs.contentHintEnabled.key, store: AppGroup.defaults)
    private var contentHintEnabled: Bool = KeyboardPrefs.contentHintEnabled.fallback
    /// 칸 안에 내용 보이기(항상 · 보였다 사라지기 · 안 보이기). 비어 있으면 위 옛 값을 따른다.
    @AppStorage(KeyboardPrefs.contentPreviewMode.key, store: AppGroup.defaults)
    private var contentPreviewRaw: String = KeyboardPrefs.contentPreviewMode.fallback
    private var contentPreview: ContentPreviewMode {
        .resolve(raw: contentPreviewRaw, legacyHintEnabled: contentHintEnabled)
    }
    /// 목록 모양(격자 · 리스트).
    @AppStorage(AppPrefs.memoListLayout.key) private var listLayoutRaw: String = AppPrefs.memoListLayout.fallback
    private var isListLayout: Bool { listLayoutRaw == MemoListLayout.list.rawValue }
    /// 카드 한 장의 최소 높이. 리스트는 줄이 낮아야 리스트로 읽힌다.
    private var cardMinHeight: CGFloat {
        isListLayout ? MemoListLayout.listRowHeight : memoCardHeight
    }

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
    /// 손가락이 올라가 있는 카드. 말랑한 눌림에만 쓴다.
    /// ⚠️ `longPressActiveMemo` 를 쓰지 않는다. 저쪽은 테두리를 되감느라 뗀 뒤 0.2초 늦게 비워져서,
    ///    그걸 보면 떼는 순간이 아니라 한 박자 뒤에 튕긴다.
    @State private var pressedMemoID: UUID?
    /// 방금 탭한 카드와 탭 횟수. 짧게 톡 치면 `onPressingChanged` 가 오지 않아서
    /// (탭 제스처가 먼저 잡아간다) 눌림만 보고는 카드가 꿈쩍도 안 했다. 탭이 잡힌 자리에서 직접 튕긴다.
    @State private var tapBounceMemoID: UUID?
    @State private var tapBounceCount = 0
    @State private var longPressProgress: CGFloat = 0
    @State private var memoForActions: Memo?
    @State private var showMemoActions: Bool = false
    /// 끌어서 스택 만들기 화면(`MemoStackScreen`).
    @State private var showStackScreen: Bool = false


    // 탭 누름 바운스 - 카드별 트리거. 탭하면 해당 카드만 들어갔다(0.92)→1.05배로 튀었다→원래 크기.

    // 순서 바꾸기(흔들기/드래그 재정렬)

    // 즐겨찾기 탭 전용
    @State private var showAddFavoriteMemoSheet: Bool = false

    // 스타터팩 - 추천 묶음 일괄 추가 시트

    // 고스트 메모 제안 - 메인 화면에 흐릿하게 "이런 메모는 어때요?" 제안
    @State private var ghostSuggestion: QuickPattern?
    @State private var ghostAddPattern: QuickPattern?
    private let dismissedGhostPatternsKey = "dismissedGhostPatterns_v1"
    // X로 한 번 닫으면 고스트 예시 제안을 영구히 끈다(앱 재실행해도 "또 다른 옵션"이 안 뜸).
    private let ghostSuggestionsOffKey = "ghostSuggestionsOff_v1"
    // X로 닫으면 이번 앱 실행(세션) 동안은 다음 제안을 띄우지 않는다.
    private static var ghostSuppressedThisSession = false
    /// 이번 실행에서 목록이 한 번이라도 화면에 올라왔는가 - 배경 제안을 켠 순간에 띄우지 않으려고.
    private static var listAppearedThisLaunch = false

    /// 만들기 시트를 여는 동안 격자에 먼저 서는 빈 자리.
    ///
    /// 왜 있나: + 를 누르면 시트만 덮여서, 이 단축어가 **어디에 생기는지** 알 수 없었다.
    /// 자리가 먼저 서고 그 위로 시트가 뜨면 "여기에 생기는구나" 가 남는다.
    ///
    /// ⚠️ 저장한 뒤가 아니라 **누른 그 순간** 선다. 예전에는 저장하고 1초 뒤에 내용을
    ///    채우는 연출이었는데, 기다리는 1초가 그냥 굼떠 보였다. 기다림이 아니라
    ///    자리를 보여 주는 것이 하려던 일이다.
    @State private var pendingSlot: Bool = false
    /// 자리가 서고 시트가 뜨기까지의 사이. 이만큼은 있어야 자리가 서는 것이 보인다.
    private static let pendingSlotBeat: TimeInterval = 0.3
    /// 만들기를 열 때 있던 단축어. 닫혔을 때 새로 생긴 카드를 이것으로 알아본다.
    @State private var memoIDsBeforeAdd: Set<UUID> = []
    /// 방금 그 자리에 생긴 카드. 한 번 통 튄다(`celebrateBirth`).
    @State private var poppingMemoID: UUID?
    /// 이어 쓰는 중인 임시 저장. 그동안은 그 임시 카드 대신 빈 자리가 같은 곳에 선다.
    @State private var resumingDraft: SavedDraft?

    // Sheet modals for MemoAdd
    @State private var showAddMemoSheet: Bool = false
    @State private var addMemoSheetCategory: String = ""
    @State private var showAddTemplateSheet: Bool = false
    @State private var showAddStackSheet: Bool = false
    @State private var memoToEdit: Memo?
    /// "템플릿으로 만들기" 원본 메모 - 이 메모 내용으로 채운 별도 새 메모를 만든다(원본은 그대로).
    @State private var makeTemplateSource: Memo?

    // TipKit
    private let welcomeTip = WelcomeTip()
    private let addMemoTip = AddMemoTip()

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 카드 열 수 결정용 - 아이패드·맥에서 `.regular` 가 된다.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// 아이폰 듀오: 펴졌는가, 이 목록이 선 판의 위 끝은 어디인가(DesignSystem/FoldLayout.swift).
    @Environment(\.foldLayout) private var foldLayout
    @Environment(\.foldPaneTop) private var foldPaneTop

    private var shouldShowGraceBanner: Bool {
        graceBannerVisible && !ProFeatureManager.isPro
    }

    /// 지금 꺼낼 만한 **결제 순간**이 있는가 (`PurchaseMomentManager`).
    ///
    /// 개수 이야기(칸이 몇 칸 남았다)와는 다른 줄기다. 이쪽은 "잃을 게 생겼다" 와
    /// "쌓아 둔 것이 있다" 를 본다. 각각 평생 한 번만 온다.
    private var dueMoment: PurchaseMoment? {
        PurchaseMomentManager.dueMomentNow(ownMemoCount: ProFeatureManager.ownMemoCount(viewModel.memos))
    }

    /// 지금 배너가 말할 순간 - 이미 붙잡아 둔 것이 있으면 그것, 없으면 새로 판정한 것.
    private var momentToShow: PurchaseMoment? { activeMoment ?? dueMoment }

    /// 가치 순간 Pro 넛지 표시 조건: 무료 유저 + 미닫힘 + 가치 입증
    /// (10분 이상 절약했거나 무료 한도에 근접). grace 배너와는 동시 노출 안 함.
    ///
    /// ⚠️ **결제 순간은 닫기 기록을 넘어선다.** 개수 넛지를 한 번 물렸다고 해서
    ///    "백업이 없다" 는 말까지 영영 못 하게 되면, 정작 알려야 할 때 말을 못 한다.
    ///    대신 순간은 각각 평생 한 번뿐이라 되풀이되지 않는다.
    private var shouldShowProValueNudge: Bool {
        // 이 넛지가 꺼내는 말(백업 · 잠금 · 동기화)은 프로의 것이다. 플러스를 산 사람에게도 한다.
        guard !ProFeatureManager.hasProTier,
              !shouldShowGraceBanner else { return false }
        // 오랜만에 돌아온 사람에게 먼저 꺼낼 말이 돈일 수는 없다(순간도 마찬가지다).
        guard userState.state.activity == .active else { return false }
        if momentToShow != nil { return true }
        guard !proNudgeDismissed else { return false }
        let savedEnough = KeyboardUsageTracker.totalTimeSavedSeconds() >= 600
        // 한도와 같은 개수를 센다 - 심어 준 샘플로 넛지가 앞당겨 뜨면 안 된다.
        let nearLimit = ProFeatureManager.ownMemoCount(viewModel.memos) >= max(1, ProFeatureManager.memoLimit - 3)
        // ⚠️ **쌓아만 두는 사람에게 "칸이 얼마 안 남았다"는 틀린 말이다.** 만들어 둔 것의
        //    대부분을 안 쓰고 있으니 모자란 것은 칸이 아니라 찾는 길이고, 칸을 사면
        //    못 찾는 것이 하나 더 늘 뿐이다. 아낀 시간이라는 증거 쪽은 그대로 둔다.
        //    그건 개수 이야기가 아니라 이 앱이 해 준 일에 대한 이야기라 누구에게나 참이다.
        let mayTalkAboutRoom = userState.state.grain != .hoarder
        return savedEnough || (nearLimit && mayTalkAboutRoom)
    }

    /// 넛지 메시지 종류 - Analytics source 슬라이싱용.
    private var proNudgeSource: String {
        if let moment = momentToShow { return "moment_" + moment.rawValue }
        return KeyboardUsageTracker.totalTimeSavedSeconds() >= 600 ? "time_saved" : "slots_left"
    }

    /// 꺼낼 순간이 있으면 그 말을, 아니면 절약 시간이나 남은 칸을 메시지로.
    ///
    /// ⚠️ 순간의 말은 **사실만** 적는다. 겁을 주지 않는다. "지금 이 폰에만 있습니다" 는
    ///    사실이고, "잃어버리면 끝입니다" 는 겁주기다. 둘의 차이가 이 앱이 신뢰받는 이유다.
    private var proValueNudgeMessage: String {
        if let moment = momentToShow {
            switch moment {
            case .sensitiveSaved:
                return NSLocalizedString("방금 가려야 할 것을 저장하셨어요. Face ID로 잠글 수 있어요", comment: "Purchase moment: sensitive saved")
            case .secondDevice:
                return NSLocalizedString("기기가 둘이 되셨네요. 같은 단축어를 두 기기에서 쓸 수 있어요", comment: "Purchase moment: second device")
            case .noBackup:
                let count = ProFeatureManager.ownMemoCount(viewModel.memos)
                return String(format: NSLocalizedString("단축어 %d개를 만드셨어요. 지금 이 기기에만 있어요", comment: "Purchase moment: no backup"), count)
            }
        }
        let saved = KeyboardUsageTracker.totalTimeSavedSeconds()
        if saved >= 600 {
            let minutes = Int(saved / 60)
            return String(format: NSLocalizedString("이미 %d분을 아꼈어요. Pro로 무제한으로 계속", comment: "Pro nudge: time saved"), minutes)
        }
        let left = max(0, ProFeatureManager.memoLimit - ProFeatureManager.ownMemoCount(viewModel.memos))
        return String(format: NSLocalizedString("무료 단축어 %d칸 남았어요. Pro로 무제한", comment: "Pro nudge: slots left"), left)
    }

    /// 페이지 상단 헤더 - 상단 배너 묶음(스크롤 콘텐츠 첫 요소라 스크롤과 함께 이동).
    /// 제목은 여기 두지 않는다 - 순정 네비게이션 바 인라인 타이틀이 담당(고정, glass).
    /// AnyView 타입 소거 - 스택 자식 추가로 인한 타입 메타데이터 폭발 방지.
    /// 스크롤이 내려간 상태인지 - 타이틀 표시 모드 전환·상단 여백 측정 가드용.
    @State private var showsInlineNavTitle = false

    /// 사람이 지금 페이지를 굴리고 있는가. 제목 접기·펼치기는 **이때만** 스크롤을 따라간다.
    @State private var isPageScrolling = false

    /// 타이틀 표시 모드. **처음부터 inlineLarge 로 시작한다.**
    ///
    /// ⚠️ 예전에는 .large 로 시작해 등장 직후 .inlineLarge 로 바꿨다. inlineLarge 가 접힌 채
    ///    시작한다고 봤기 때문인데, 그건 첫 프레임에 스크롤뷰가 없어서(단축어를 늦게 읽어
    ///    빈 페이지가 먼저 그려졌다) 생긴 일이었다. 지금은 뷰모델이 먼저 읽어 첫 프레임부터
    ///    격자가 있다. 그 상태에서 모드를 바꾸면 **바꾸는 순간 제목이 접혔다 펼쳐지며 카드가
    ///    위로 튀었다 내려왔다**(실측). 바꿀 일을 만들지 않는다.
    @State private var titleDisplayMode: ToolbarTitleDisplayMode = .inlineLarge

    /// 페이지 스크롤 오프셋으로 타이틀 모드 전환 - 페이저(UIKit 셀) 안 스크롤은
    /// 네비바가 자동 추적하지 못하고, preference도 셀 경계에서 업데이트가 끊겨(실측)
    /// onScrollGeometryChange(iOS 18+)를 쓴다. iOS 17은 전환 없이 inlineLarge 유지.
    @ViewBuilder
    private func trackPageScroll<V: View>(_ view: V) -> some View {
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

    private func pageHeader(for tab: CategoryTab) -> AnyView {
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

    private func defaultNamePrompt(_ name: String) -> some View {
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
    private func openRecentLessonIfBroughtCopy() {
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
    @State private var defaultNameDecisions = 0

    /// 네비게이션 바 타이틀 - 보고 있는 카테고리 이름. 찾는 중에는 모든 카테고리에서 찾으므로 '전체'.
    private var currentCategoryTitle: String {
        if blank && !usesCategoryHome { return CategoryTab.basic.displayName }
        return isInCategory ? viewModel.displayedCategoryTab.displayName : CategoryTab.all.displayName
    }

    /// 카테고리 고르기(제목 옆 아래 화살표 · 시트)를 세우는가.
    /// 카테고리 기능이 꺼져 있어도 '최근' 이 서면 '최근' · '전체' 두 칸이다.
    private var usesCategoryHome: Bool {
        CategoryStore.shared.isFeatureEnabled || showsRecentClipsTab
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
    private static let settleWindow: TimeInterval = 1.0

    @State private var settling: Bool = true

    private func beginSettling() {
        settling = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleWindow) {
            settling = false
        }
    }

    /// 상단 배너 모음. **자리마다 하나, 많아야 세 줄이다** (상태 띠 · 지금 카드 · 제안 카드).
    ///
    /// 띠마다 "말할 거리가 있다" 를 `PromptRow` 로 올리고, 누가 설지는 `PromptBoard` 가
    /// 고른다(`PromptArbiter`). 예전에는 띠 13개가 서로를 몰라 한꺼번에 설 수 있었다.
    /// 아래 순서는 그리는 순서일 뿐이고, 같은 종류 안의 차례는 `PromptCandidate.listOrder` 다.
    /// 설계: docs/design/PROGRESSIVE_DISCLOSURE.md 4절
    ///
    /// AnyView로 타입 소거 - mainColumn VStack의 제네릭 중첩 깊이를 줄이는 핵심.
    private var topBanners: some View {
        AnyView(
            VStack(spacing: 0) {
                // 키보드를 켜지 않았으면 선다. 닫는 단추가 없다 - 켜면 걷힌다.
                // 아직 자기 단축어가 없는 사람에게는 서지 않는다(꺼낼 것이 없다, `UserSurface.keyboardSetupBanner`).
                KeyboardSetupRequiredBanner()

                // 붙여넣기 허용 안내 - 앱 진입 시 클립보드를 읽어 팝업이 뜨는 바로 그 지점.
                // 한 번 설정을 바꾸면 팝업이 사라지므로, 최상단에서 설정으로 바로 안내한다.
                PromptRow(.pasteTip, wants: showPasteTip) {
                    PastePermissionTipBanner(
                        onOpenSettings: { openAppSettings() },
                        onDismiss: {
                            UserDefaults.standard.set(true, forKey: DefaultsKey.pasteTipDismissed)
                            showPasteTip = false
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }

                // 빠른 메모(Inbox) 배너 - 분류 대기 항목이 있으면 상단에 즉시 노출.
                // (컨테이너가 내부에서 QuickNoteStore를 관찰하고, 비었으면 아무것도 안 그린다.
                //  타입은 topBanners의 AnyView로 소거되어 mainColumn 타입 복잡도에 영향 없음.)
                QuickNoteInboxBannerContainer(dismissCount: $inboxBannerDismissCount) {
                    HapticManager.shared.light()
                    showInboxFromIntent = true
                }

                // 무료로 쓰는 기간의 이정표(50% · 80%). 자기 상태를 스스로 보고, 없으면 아무것도 안 그린다.
                FreeUseMilestoneBanner()

                // 열려 있던 기능이 닫힌다는 안내 - 파는 넛지보다 먼저 온다(알리는 말이 먼저다).
                PromptRow(.accessEnding, wants: accessNotice != nil) {
                    if let notice = accessNotice {
                        AccessEndingBanner(
                            notice: notice,
                            onUpgrade: {
                                HapticManager.shared.light()
                                ProFeatureManager.markAccessEndingNoticeSeen(notice)
                                accessNotice = nil
                                paywallTrigger = .memo
                                showPaywallFromKeyboard = true
                            },
                            onDismiss: {
                                ProFeatureManager.markAccessEndingNoticeSeen(notice)
                                accessNotice = nil
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    }
                }

                // 가치 순간 Pro 넛지 - 무료 유저가 가치를 느낀 시점에 1회 노출.
                PromptRow(.proValue, wants: shouldShowProValueNudge) {
                    ProValueNudgeBanner(
                        message: proValueNudgeMessage,
                        onTap: {
                            HapticManager.shared.light()
                            AnalyticsService.logProNudge(.proNudgeTapped, source: proNudgeSource)
                            // 무엇 때문에 띄운 페이월인지 넘긴다. 순간마다 파는 물건이 다르다.
                            paywallTrigger = momentToShow?.limitType
                            showPaywallFromKeyboard = true
                        },
                        onDismiss: {
                            // 순간을 물린 것이라면 개수 넛지까지 영영 덮지 않는다.
                            // (순간은 이미 노출 기록이 남아 다시 오지 않는다)
                            if activeMoment != nil {
                                activeMoment = nil
                            } else {
                                UserDefaults.standard.set(true, forKey: DefaultsKey.proValueNudgeDismissedV1)
                                proNudgeDismissed = true
                            }
                            PromptBoard.list.noteDeclined(.proValue)
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .onAppear {
                        AnalyticsService.logProNudge(.proNudgeShown, source: proNudgeSource)
                        // 띄운 그 자리에서 못박는다 - 닫는 방법과 무관하게 평생 한 번.
                        // 보여 줄 것은 `activeMoment` 가 계속 들고 있다(위 주석 참고).
                        if activeMoment == nil, let moment = dueMoment {
                            activeMoment = moment
                            PurchaseMomentManager.markShown(moment)
                        }
                    }
                }

                // 한 번에 정리하기 권유 - 보여줄지는 컨테이너가 스스로 정한다.
                // (mainColumn 타입 복잡도에 영향이 없도록 자식 하나로 유지)
                BulkImportNudgeBannerContainer(memoCount: viewModel.memos.count,
                                               hasLoaded: viewModel.hasLoadedMemos) {
                    HapticManager.shared.light()
                    showBulkImport = true
                }

                // 판마다 다른 필수 단축어 세 칸 (`PersonaEdition`). 보여 줄지는 컨테이너가 정한다.
                PersonaEssentialsCardContainer(memos: viewModel.memos,
                                               hasLoaded: viewModel.hasLoadedMemos,
                                               isAwayOrJustBack: userState.state.activity != .active) {
                    paywallTrigger = .memo
                    showPaywallFromKeyboard = true
                }

                PromptRow(.categoryActivation,
                          wants: CategoryStore.shared.shouldShowActivationBanner(currentMemoCount: viewModel.memos.count)) {
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
                }

                // 페르소나 기반 카테고리 이름 제안 (TipKit).
                // ⚠️ 팁이 스스로 물러났는지(`shouldDisplay`)까지 본다. 안 보면 닫힌 팁이 자리를 쥐고
                //    아래 말들이 영영 못 선다.
                PromptRow(.personaCategoryTip,
                          wants: shouldShowPersonaCategoryTip && personaCategoryTip.shouldDisplay) {
                    personaCategorySuggestionTip()
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }

                // 메모를 보고 카테고리 생성을 제안 (TipKit).
                PromptRow(.categorySuggestionTip, wants: categorySuggestionTipWants) {
                    if let suggestion = viewModel.suggestedCategory {
                        categorySuggestionTip(name: suggestion.name, count: suggestion.count)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                    }
                }
            }
            // 활동(휴면·복귀)이나 층이 바뀌면 다시 고른다. 손을 든 쪽은 그대로다.
            .onChange(of: userState.state) { _, _ in PromptBoard.list.recompute() }
        )
    }

    /// iOS 설정의 이 앱 페이지(‘다른 앱에서 붙여넣기’ 토글 포함)를 연다.
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    /// 카테고리 탭/단일 페이지 - 가장 깊은 단일 요소라 AnyView로 타입 소거.
    /// GeometryReader: 세이프에어리어를 무시하기 전의 상단 오프셋(=네비바 하단)을 재서
    /// 각 페이지 스크롤 콘텐츠의 시작 위치(contentMargins)로 쓴다.
    /// 카테고리 한 장을 보이는가. 고르기가 없는 화면(카테고리 기능 꺼짐)과 찾는 중에는 아니다.
    private var isInCategory: Bool { usesCategoryHome && !isSearching }

    /// 카테고리 한 장 · 찾은 결과 · 단일 페이지 가운데 하나. 옆으로 넘기는 페이저는 없다.
    /// 다른 카테고리로는 제목 옆 아래 화살표로 여는 시트(`CategoryPickerSheet`)에서 옮긴다.
    @ViewBuilder
    private var categoryContent: some View {
        if isInCategory {
            openedCategoryPage
        } else {
            // 찾는 중이면 모든 카테고리에서 찾은 결과를 한 장으로 보인다.
            tabPageView(for: .all)
        }
    }

    /// 보고 있는 카테고리 한 장. 사용자 카테고리는 그 색으로 옅게 물든다.
    private var openedCategoryPage: some View {
        let tab = viewModel.displayedCategoryTab
        return tabPageView(for: tab)
            .background { pageTint(for: tab).ignoresSafeArea() }
            .id(tab)
    }

    /// 제목과 그 오른쪽 아래 화살표. 누르면 카테고리 고르기 시트가 뜬다.
    /// 왼쪽 위, 오른쪽 단추들과 같은 줄에 선다.
    private func categoryTitleButton() -> some View {
        Button {
            HapticManager.shared.selection()
            viewModel.isCategoryPickerShown = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(currentCategoryTitle)
                    .font(.title2.bold())
                    .lineLimit(1)
                Image(systemName: AppSymbol.chevronDown)
                    .font(.body.weight(.bold))
                    .foregroundStyle(theme.textMuted)
            }
            .foregroundStyle(theme.text)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(currentCategoryTitle)
        .accessibilityHint(NSLocalizedString("카테고리 고르기", comment: "List title: opens the category picker sheet"))
    }

    /// 스크롤 페이지의 위 여백. 페이지가 이제 늘 바 아래에 서므로 시스템이 바 아래로 밀어 준다.
    /// (예전에는 페이저가 그 일을 안 해서 바 하단을 직접 재어 넣었다.)
    private let pageContentTopMargin: CGFloat = 8

    private var screenBody: some View {
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

    private var screenBody2: some View {
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
    private var screenL3: some View {
        AnyView(screenBody2)
            .onChange(of: viewModel.searchQueryString) { _, _ in viewModel.applyFilters() }
            .onChange(of: viewModel.selectedTypeFilter) { _, _ in
                viewModel.applyFilters()
                viewModel.saveSelectedFilter()
            }
            .onChange(of: viewModel.showFavoritesFilter) { _, _ in viewModel.applyFilters() }
            // 인증 실패 Alert
    }

    private var screenL4: some View {
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

    private var screenL5: some View {
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

    private var screenL6: some View {
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

    private var screenL7: some View {
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
            .onReceive(NotificationCenter.default.publisher(for: .accessRevoked)) { _ in
                accessNotice = ProFeatureManager.accessEndingNoticeNow
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // 체험 마지막 날은 앱을 켜 둔 채로도 온다.
                accessNotice = ProFeatureManager.accessEndingNoticeNow
                viewModel.onSceneResume()
                consumePendingInboxOpen()
            }
            // 콜드 런치에서 didBecomeActive가 위 구독 설치보다 먼저 지나간 경우의 폴백.
            // (Control Center 컨트롤이 켠 보류 플래그를 첫 표시 시점에 소비 - 멱등이라 중복 무해)
            .onAppear { consumePendingInboxOpen() }
    }

    private var screenL8: some View {
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
    private var listBackgroundImage: String = ""
    @AppStorage(DefaultsKey.backgroundOfferResolvedV1, store: AppGroup.defaults)
    private var backgroundOfferResolved: Bool = false
    @State private var showBackgroundOffer = false
    @State private var showBackgroundPicker = false

    /// 탭별 배경 덮어쓰기 [CategoryTab.storageKey: 에셋 이름]. ""는 "이 탭만 배경 없음".
    /// 항목이 없는 탭은 전체 기본값(listBackgroundImage)을 따른다.
    @State private var perTabBackgrounds: [String: String] = [:]
    /// 배경 선택 시트의 적용 범위 - 현재 탭만 / 모든 탭.
    @State private var backgroundScopeAllTabs = false
    /// 사진첩에서 고른 것. 고르는 즉시 저장하고 배경으로 적용한다.
    @State private var pickedBackgroundItem: PhotosPickerItem?
    /// 내가 넣어 둔 배경들.
    @State private var myBackgrounds: [String] = []

    /// 내 사진 하나를 들인다. **고르자마자 적용한다** - 넣고 또 골라야 하면 두 걸음이다.
    private func adoptPickedBackground(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task { @MainActor in
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let stored = BackgroundImageStore.add(image) else {
                viewModel.showPlainToast(NSLocalizedString("사진을 가져오지 못했어요",
                                                           comment: "Background import failed"))
                return
            }
            myBackgrounds = BackgroundImageStore.saved()
            applyBackground(stored)
            pickedBackgroundItem = nil
        }
    }

    /// 내가 넣은 배경 하나를 지운다.
    ///
    /// ⚠️ 지금 쓰고 있는 것을 지우면 **배경 없음으로 되돌린다.** 그러지 않으면 파일이
    ///    사라진 이름만 남아, 배경이 조용히 안 보이는 채로 설정만 켜져 있게 된다.
    private func removeUserBackground(_ name: String) {
        BackgroundImageStore.remove(name)
        myBackgrounds = BackgroundImageStore.saved()
        if listBackgroundImage == name { listBackgroundImage = "" }
        for (tab, value) in perTabBackgrounds where value == name {
            perTabBackgrounds[tab] = ""
        }
        persistPerTabBackgrounds()
        HapticManager.shared.selection()
    }

    /// 현재 탭에 실제로 보여줄 배경 - 탭 덮어쓰기 우선, 없으면 전체 기본값.
    private var resolvedBackgroundImage: String {
        // 홈은 어느 카테고리도 아니다 - 전체 배경만 깐다.
        guard isInCategory else { return listBackgroundImage }
        return perTabBackgrounds[viewModel.selectedCategoryTab.storageKey] ?? listBackgroundImage
    }

    private func loadPerTabBackgrounds() {
        perTabBackgrounds = (AppGroup.defaults?
            .dictionary(forKey: DefaultsKey.listBackgroundPerTabV1) as? [String: String]) ?? [:]
        preloadBackgrounds()
    }

    /// 이 화면이 쓸 배경들을 미리 풀어 둔다.
    ///
    /// ⚠️ **탭을 넘긴 뒤에 읽으면 늦다.** 그때 읽으면 디코드가 그 프레임에서 일어나
    ///    배경이 한 박자 늦게 들어오고, 그 사이가 바닥색으로 비친다.
    ///    옆 탭 것까지 미리 읽어 두면 넘기는 순간에는 그릴 일만 남는다.
    private func preloadBackgrounds() {
        BackgroundImageStore.preload(Array(perTabBackgrounds.values) + [listBackgroundImage])
    }

    private func persistPerTabBackgrounds() {
        AppGroup.defaults?
            .set(perTabBackgrounds, forKey: DefaultsKey.listBackgroundPerTabV1)
        preloadBackgrounds()
    }

    /// 배경 선택 적용 - 범위에 따라 현재 탭 덮어쓰기 또는 전체 기본값(+탭 덮어쓰기 초기화).
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
    ///    (한 번 닫으면 다시 안 뜬다 - 가장 좋은 기능을 첫날에 태워 없앤 것).
    ///
    /// 두 가지를 모두 만족해야 꺼낸다:
    ///  ① 설치 후 **최소 일주일** - 꾸미기는 도구가 손에 익은 다음의 즐거움이다.
    ///  ② 단축어가 어느 정도 쌓였을 것 - 카드가 몇 장 없는 화면에 배경을 깔면
    ///     살아나기는커녕 휑한 게 더 드러난다.
    private static let backgroundOfferMinDays: Double = 7
    private static let backgroundOfferMinMemos = 3

    private var isReadyForBackgroundOffer: Bool {
        guard viewModel.memos.count >= Self.backgroundOfferMinMemos else { return false }
        // 설치일이 없으면(아직 기록 전) 아직 이르다고 본다 - 일찍 묻느니 늦게 묻는다.
        guard let installed = UserDefaults.standard.object(forKey: "app_install_date") as? Date else {
            return false
        }
        return Date().timeIntervalSince(installed) >= Self.backgroundOfferMinDays * 86_400
    }

    /// 썸네일 선택 표시 기준 - 현재 범위에서 그 이미지가 적용돼 있는지.
    private func isBackgroundSelected(_ name: String) -> Bool {
        backgroundScopeAllTabs ? (listBackgroundImage == name) : (resolvedBackgroundImage == name)
    }

    var body: some View {
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
    private var draftMenuTitle: String {
        let count = DraftStore.shared.count
        return count > 0
            ? String(format: NSLocalizedString("임시 저장 (%d)", comment: "Menu: drafts with count"), count)
            : NSLocalizedString("임시 저장 보기", comment: "Menu: view drafts")
    }


    /// Control Center 컨트롤·딥링크가 켜둔 보류 플래그를 소비한다(앱 활성화 시).
    /// - 빠른 메모 컨트롤: 입력 시트 표시 / - 보관함 열기 컨트롤: Inbox 화면 이동.
    /// - 클립보드 담기(동작 버튼): 방금 복사한 글을 복사 기록에 담고 토스트로 알린다.
    private func consumePendingInboxOpen() {
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

    // MARK: - View Sections


    // MARK: - Grid

    /// 한 줄에 놓을 카드 수. 아이폰 2열 / 아이패드·맥 4열.
    ///
    /// ⚠️ `.adaptive(minimum:)` 을 쓰면 **안 된다.** 이 그리드는 `TabView(.page)` 안의
    ///    `ScrollView` 에 들어 있는데, 그 조합에서는 LazyVGrid 에 폭이 제대로 제안되지 않아
    ///    `.adaptive` 가 열 수를 1로 계산해 카드가 화면 전체로 늘어난다(실제로 그렇게 깨졌다).
    ///    `.flexible()` 은 폭 측정 없이 "가용 공간을 n등분"이라 이 문제가 없다.
    ///    그래서 열 수는 **측정이 아니라 size class 로** 정한다.
    private var gridColumnCount: Int {
        // 리스트로 고르면 한 줄에 하나.
        if isListLayout { return 1 }
        // 듀오를 폈을 때는 이 목록이 선 판의 **폭**으로 정한다(크기 등급은 판을 모른다).
        // 가로로 펴면 판 폭이 바깥 화면과 같아(약 463pt) 2열 그대로 - 펴도 카드 자리가 안 바뀐다.
        // 세로로 펴면 접힌 선 아래 판이 창 폭(669pt)이라, 카드 150pt 이상이 들어가는 만큼 세운다.
        if foldLayout.isUnfolded {
            let paneWidth = foldLayout.posture == .innerPortrait
                ? foldLayout.windowSize.width
                : foldLayout.leadEnd
            let fit = max(2, min(4, Int((paneWidth - 32 + 12) / 162)))
            return dynamicTypeSize.isAccessibilitySize ? max(1, fit / 2) : fit
        }
        // 손쉬운 사용의 큰 글씨에서는 열을 반으로 줄인다. 두 열 그대로면 제목이 한두 글자씩 끊긴다.
        if dynamicTypeSize.isAccessibilitySize {
            return horizontalSizeClass == .regular ? 2 : 1
        }
        return horizontalSizeClass == .regular ? 4 : 2
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: gridColumnCount)
    }

    /// 고스트(가상) 메모 셀 - 실제 메모 셀과 같은 치수·제목 스타일을 그대로 쓰되
    /// 반투명 + 점선 테두리로 "아직 실재하지 않는 제안"임을 표현. 탭하면 채워서
    /// 추가하는 편집기로 진입(사용자가 한 번 눌러보고 판단).
    private func ghostMemoCell(pattern: QuickPattern) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                // 아이콘을 그냥 띄워 두면 붕 뜬다 - 원형 배지에 담아야 만들다 만 게 아니라
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
                .buttonStyle(.squish)
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
        .frame(maxWidth: .infinity, minHeight: cardMinHeight, alignment: .topLeading)
        // ⚠️ 반투명 위에 또 반투명을 얹지 않는다. 예전에는 surface 0.5 에 opacity 0.85 까지
        //    겹쳐서 두 번 흐려졌고, 옅은 회색 점선까지 더해져 **만들다 만 카드**로 보였다.
        //    제안은 흐릿한 게 아니라 **아직 안 만든 것**이다 - 또렷하되 색으로 구분한다.
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
        // progress fill을 trigger보다 살짝 짧게 - 시뮬 환경에서 onLongPressGesture가
        // 미세하게 일찍 fire되는 경우가 있어 "원이 아직 안 찼는데 시트 뜸" 현상을
        // 방지하기 위함. 사용자는 0.5s에 원이 가득 차는 걸 보고 0.65s까지 누르면 시트.
        let progressFillDuration: Double = 0.5

        // Button + onLongPressGesture 조합이 iOS 17+에서 long press를 가로채는 경우가 있어
        // 일반 View + onTapGesture + onLongPressGesture 패턴으로 분리. 시각 affordance는
        // 그대로 유지 (button trait 명시 + tap 햅틱).
        return memoCardSurface(memo: memo)
        // 방금 생긴 카드가 그 자리에서 한 번 통 튄다(`celebrateBirth`). 투명도는 건드리지 않는다(유리가 잿빛이 된다)
        .scaleEffect(poppingMemoID == memo.id ? 1.07 : 1)
        // 방금 쓴 카드에 잠깐 켜지는 테두리.
        // ⚠️ 조건부로 뷰를 끼웠다 빼지 않고 **불투명도만** 바꾼다
        //    끼웠다 빼면 나타날 때 끊겨 보이고, 사라질 때 애니메이션이 안 걸린다.
        .overlay {
            RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
                .strokeBorder(theme.accent, lineWidth: 2.5)
                .opacity(glowMemoID == memo.id ? 1 : 0)
                .allowsHitTesting(false)
        }
        // 복사됨 도장. 테두리와 같은 이유로 끼웠다 빼지 않고 불투명도만 바꾼다.
        .overlay {
            CopiedStamp(cornerRadius: theme.radiusXl, green: blank)
                .opacity(copiedStampMemoID == memo.id ? 1 : 0)
                .scaleEffect(copiedStampMemoID == memo.id || reduceMotion ? 1 : 0.92)
                .allowsHitTesting(false)
        }
        // 코치가 가리킬 카드의 자리를 알려준다 - 안내를 화면 아래에 고정해 두면
        // 무엇을 누르라는 건지 이어지지 않는다.
        // ⚠️ 가리킬 카드에만 단다. 예전에는 모든 카드가 자리를 재어 선호값을 올렸고(대부분 .zero),
        //    레이아웃이 돌 때마다 카드 수만큼 모아 줄였다. 코치가 가리키는 카드는 하나뿐이다.
        .background {
            if coachMemoID == memo.id {
                GeometryReader { geo in
                    Color.clear.preference(key: CoachAnchorKey.self, value: geo.frame(in: .global))
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous))
        // 좌표를 받는 탭 - 동전이 **손가락이 닿은 자리**에서 튀어야 인과가 보인다.
        // 카드 중심에서 튀면 어느 카드를 눌렀는지는 알아도 내가 눌렀다는 느낌이 약하다.
        //
        // ⚠️ `.global` 이라야 한다. 이름 붙인 좌표계는 카드가 ScrollView 안쪽 깊이 있어
        //    닿지 않았고, 그 바람에 어느 카드를 눌러도 동전이 화면 왼쪽 위에서 날아갔다.
        .onTapGesture(coordinateSpace: .global) { location in
            HapticManager.shared.selection() // 탭: 선택 햅틱
            tapBounceMemoID = memo.id
            tapBounceCount += 1
            // 동전은 여기서 날리지 않는다. 콤보·템플릿은 아직 **쓴 게 아니라** 시트가 뜰 뿐이라,
            // 실제 사용이 확정될 때(.memoUsed) 날린다. 자리만 기억해 둔다.
            lastTapPoint = location
            // 누르면 복사가 기본이다. 설정에서 뒤집은 사람에게는 누르면 메뉴다(`MemoCardGesture`).
            switch MemoCardGesture.tap.action(tapOpensMenu: cardTapOpensMenu) {
            case .copy: copyFromCard(memo)
            case .menu: openMemoActions(memo)
            }
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
            // 완료 - 진행 완료 햅틱 후 액션 메뉴 표시(뒤집은 사람에게는 복사)
            HapticManager.shared.heavy()
            longPressActiveMemo = nil
            longPressProgress = 0
            switch MemoCardGesture.longPress.action(tapOpensMenu: cardTapOpensMenu) {
            case .copy: copyFromCard(memo)
            case .menu: openMemoActions(memo)
            }
        } onPressingChanged: { isPressing in
            pressedMemoID = isPressing ? memo.id : nil
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
                // 중간에 뗌 - 테두리 되감기
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
        // 누르면 말랑하게 줄었다가 떼면 튕긴다. 카드는 커서 조금만 줄인다.
        .squishPress(pressedMemoID == memo.id, scale: 0.94,
                     bounce: tapBounceMemoID == memo.id ? tapBounceCount : 0)
        .accessibilityLabel(MemoCardSurface.accessibilityLabel(for: memo, categories: viewModel.customCategories))
        .accessibilityHint(cardTapOpensMenu
            ? NSLocalizedString("탭하면 추가 옵션, 꾹 누르면 클립보드에 복사", comment: "Memo card hint when the tap and long-press actions are swapped in Settings: tap opens the menu, long press copies")
            : NSLocalizedString("탭하면 클립보드에 복사, 꾹 누르면 추가 옵션", comment: "Memo card hint"))
        // 꾹 누르기를 모르는 사람도, 손이 불편한 사람도 **꾹 눌러야 닿는 쪽**에 닿게.
        // 기본은 메뉴가, 뒤집은 사람에게는 복사가 꾹 누르기 뒤에 있다.
        .accessibilityAction(named: Text(cardTapOpensMenu
            ? NSLocalizedString("복사", comment: "Copy")
            : NSLocalizedString("더 보기", comment: "VoiceOver action: open memo actions"))) {
            switch MemoCardGesture.longPress.action(tapOpensMenu: cardTapOpensMenu) {
            case .copy: copyFromCard(memo)
            case .menu: openMemoActions(memo)
            }
        }
    }

    /// 카드에서 바로 복사한다. 누르기와 꾹 누르기 가운데 설정이 복사로 정해 둔 쪽이 부른다.
    private func copyFromCard(_ memo: Memo) {
        viewModel.copyMemo(memo: memo)
        checkCategoryBadgeNudge()
        // VoiceOver 안내는 복사가 **확정될 때** 한다(`finalizeCopy`). 여기서 하면
        // 템플릿·스택처럼 시트만 뜨는 경로에서도 "복사됨" 이라고 말해 버린다.
    }

    /// 카드의 추가 옵션을 연다. 꾹 누르기와 VoiceOver 동작이 같은 길을 쓴다.
    private func openMemoActions(_ memo: Memo) {
        memoForActions = memo
        // 펼친 듀오: 시트 대신 결과 쪽 판에(시트는 27.1 에서 접힌 선 한가운데에 선다)
        if foldLayout.isUnfolded {
            FoldComposeRouter.shared.open(pane: AnyView(memoActions(memo)))
        } else {
            showMemoActions = true
        }
    }

    /// 카드가 어떻게 보일지. 이 화면이 쥔 설정을 한 곳에서 모아 건넨다 - 화면의 상태가
    /// 카드 안으로 새어 들어가는 자리를 여기 하나로 좁힌다.
    private var cardStyle: MemoCardStyle {
        MemoCardStyle(
            categories: viewModel.customCategories,
            cardHeight: cardMinHeight,
            showsVisualCues: visualCuesVisible,
            showsContentHint: contentPreview != .off,
            contentAlwaysVisible: contentPreview == .always,
            hasListBackground: !resolvedBackgroundImage.isEmpty
        )
    }

    private func memoCardSurface(memo: Memo, lightweight: Bool = false) -> MemoCardSurface {
        cardStyle.surface(for: memo, showsCoin: showsCoin(memo), lightweight: lightweight)
    }

    // MARK: - 생활 레이어

    /// 카드 위에 사는 것 - 물성 스킨과 다른 층이라 겹쳐 쓸 수 있다.
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
            // 금고는 시간을, 지오드는 보석을 센다 - 모이는 자리는 같고 세는 것만 다르다.
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
        viewModel.selectedStackIdForSheet != nil
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
        // 금고 스킨은 카드가 내용 대신 **동전**을 보여 주는 것이 곧 "썼다" 는 대답이다.
        // 같은 자리에 도장까지 찍으면 둘 다 안 읽힌다.
        if livingSkin != .vault {
            if anyModalUp { pendingCopiedStamp = memoID } else { stampCopied(memoID) }
        }
        lightUpCard(memoID)

        // 가리키던 카드를 실제로 눌렀다 → 안내를 거둔다. 배운 것은 여기서 끝난다.
        //
        // ⚠️ 예전에는 여기서 **붙여넣기 연습 화면**(`PastePracticeView`)을 전체 화면으로
        //    띄웠다. 뺐다. 카드를 누른 순간 값은 이미 들어간 뒤라, 같은 값을 한 번 더
        //    "붙여넣어 보라"고 하는 것은 방금 한 일을 다시 시키는 일이었다.
        if coachMemoID == memoID {
            withAnimation(.easeOut(duration: 0.25)) { coachMemoID = nil }
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

    /// 카드 위에 "복사됨" 을 잠깐 얹는다. 목록에서 복사를 알리는 **유일한 시각 신호**다.
    ///
    /// ⚠️ 예전에는 화면 아래에 토스트("[값] 이 복사되었습니다")를 띄웠다. 눈은 누른 카드에
    ///    있는데 대답은 화면 바닥에서 왔고, 3초 동안 탭바를 가렸다. 대답은 누른 자리에서 한다.
    /// ⚠️ 동작 줄이기·연출 끄기에서도 **찍는다.** 이건 연출이 아니라 대답이다.
    ///    움직임(커지며 나타나기)만 뺀다.
    private func stampCopied(_ memoID: UUID) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7)) {
            copiedStampMemoID = memoID
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.copiedStampDwell) {
            // 그 사이 다른 카드를 눌렀으면 그쪽이 주인이다 - 뺏지 않는다.
            if copiedStampMemoID == memoID {
                withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2)) { copiedStampMemoID = nil }
            }
        }
    }

    /// 도장이 머무는 시간(초). 읽을 만큼만 - 길면 다음 카드를 누르는 손을 붙잡는다.
    private static let copiedStampDwell: Double = 0.9

    /// 방금 쓴 카드의 테두리를 1초 뒤에 켰다가 서서히 끈다.
    ///
    /// 왜 바로가 아니라 1초 뒤인가: 누른 순간에는 이미 눌림·햅틱·동전이 한꺼번에 일어난다.
    /// 거기 테두리까지 겹치면 무엇 하나 안 읽힌다. 동전이 금고에 닿을 즈음 뒤늦게 켜져야
    /// **"방금 그 카드가 일했다"**가 따로 읽힌다.
    /// - Parameter delay: 새 카드가 생길 때는 기다리지 않는다(`celebrateBirth`). 그때는 겹칠 다른 연출이 없다.
    private func lightUpCard(_ memoID: UUID, after delay: Double = 1.0) {
        guard Delight.isEnabled else { return }
        let fadeIn: Animation? = reduceMotion ? nil : .easeOut(duration: 0.25)
        let fadeOut: Animation? = reduceMotion ? nil : .easeIn(duration: 0.6)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(fadeIn) { glowMemoID = memoID }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 그 사이 다른 카드를 눌렀으면 그쪽이 주인이다 - 뺏지 않는다.
                if glowMemoID == memoID { withAnimation(fadeOut) { glowMemoID = nil } }
            }
        }
    }

    /// 지오드를 한 단계 깨뜨린다. 세 번째면 터뜨리고 보석을 날려 보낸다.
    ///
    /// 단계는 사용 횟수에서 계산하므로 여기서 따로 저장할 것이 없다
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
    /// 순서가 값어치다 - 동전과 내용이 **같은 자리를 동시에 쓰지 않는다.**
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
            // 그 사이 다른 카드를 눌렀으면 그쪽이 주인이다 - 뺏지 않는다.
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

    // MARK: - Tab Background Color

    /// 사용자 카테고리 페이지의 바탕 물. 기본 · 즐겨찾기 · 기본 제공 갈래는 물들이지 않는다.
    ///
    /// ⚠️ **화면 바닥이 아니라 페이지에 칠한다.** 예전에는 화면 전체 바닥 하나를 카테고리 색으로
    ///    물들이고 0.38초에 걸쳐 바꿨는데, 페이지는 0.25초면 넘어가서 카드는 이미 새 카테고리인데
    ///    바닥색만 뒤늦게 쓸려 오는 번쩍임이 됐다(`screenBody` 주석, 8b04a4b). 페이지에 붙이면
    ///    색은 따로 바뀌는 순간이 없다. 넘기는 손가락을 따라 카드와 함께 들어오고 나간다.
    /// ⚠️ 배경 사진을 고른 사람에게는 칠하지 않는다 - 사진을 덮는다.
    private func pageTint(for tab: CategoryTab) -> Color {
        guard case .custom(let name) = tab, resolvedBackgroundImage.isEmpty else { return .clear }
        return customCategoryColor(name).opacity(theme.isDark ? 0.14 : 0.09)
    }

    /// 커스텀 카테고리 색상. 사용자가 지정한 색(userCategoryColors_v1)이 있으면 우선,
    /// 없으면 카테고리 순서에 따라 결정적으로 팔레트 색 반환.
    private func customCategoryColor(_ name: String) -> Color {
        categoryTint(for: name, in: viewModel.customCategories)
    }

    // MARK: - Persona Category Suggestion (TipKit)

    /// 선택한 페르소나에 맞는, 아직 안 만든 카테고리 이름 후보.
    private var personaCategorySuggestions: [String] {
        guard let persona = PersonaResolver.confident else { return [] }
        let lang = AppLanguage.contentLanguageCode
        let existing = Set(viewModel.customCategories)
        return persona.seedCategories(language: lang).filter { !existing.contains($0) }
    }

    /// 페르소나 카테고리 제안 팁 표시 조건: 페르소나 있음 + 콘텐츠 기반 제안과 겹치지 않음 + 후보 있음.
    private var shouldShowPersonaCategoryTip: Bool {
        PersonaResolver.confident != nil
            && viewModel.suggestedCategory == nil
            && !personaCategorySuggestions.isEmpty
    }

    /// 카테고리 생성 제안 TipKit 카드. 수락 시 카테고리 추가 + 해당 탭으로 이동.
    /// id에 카테고리명을 포함해 카테고리별로 1회만 노출(무효화 추적)된다.
    private var personaCategoryTip: PersonaCategoryTip {
        PersonaCategoryTip(suggestions: Array(personaCategorySuggestions.prefix(3)))
    }

    private func personaCategorySuggestionTip() -> some View {
        let tip = personaCategoryTip
        return AnimatedTip(tip: tip) {
            TipView(tip) { action in
                // action.id == 카테고리 이름. 탭하면 그 카테고리를 만들고 기능을 켠다.
                viewModel.addCustomCategory(action.id)
                CategoryStore.shared.enableFeature()
                HapticManager.shared.success()
                viewModel.loadCustomCategories()
                viewModel.loadMemos()
                tip.invalidate(reason: .actionPerformed)
            }
        }
    }

    private func makeCategorySuggestionTip(name: String, count: Int) -> CategorySuggestionTip {
        CategorySuggestionTip(
            categoryRawName: name,
            displayName: Constants.localizedThemeName(name),
            count: count
        )
    }

    /// 카테고리 생성 제안을 올릴 때인가. 팁이 스스로 물러났으면 손을 들지 않는다.
    private var categorySuggestionTipWants: Bool {
        guard CategoryStore.shared.isFeatureEnabled,
              let suggestion = viewModel.suggestedCategory else { return false }
        return makeCategorySuggestionTip(name: suggestion.name, count: suggestion.count).shouldDisplay
    }

    private func categorySuggestionTip(name: String, count: Int) -> some View {
        let tip = makeCategorySuggestionTip(name: name, count: count)
        return AnimatedTip(tip: tip) {
            TipView(tip) { action in
                if action.id == "create" {
                    withAnimation { viewModel.acceptSuggestedCategory(name) }
                    HapticManager.shared.success()
                    tip.invalidate(reason: .actionPerformed)
                }
            }
        }
    }

    /// 검색어가 비어 있지 않은(공백 제외) 상태 - 검색 결과 없음 분기 판단에 사용.
    private var isSearching: Bool {
        !viewModel.searchQueryString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private func tabPageView(for tab: CategoryTab) -> some View {
        if tab == .recent {
            recentClipsPage
        } else {
            memoPageView(for: tab)
        }
    }

    /// 맨 앞 '최근' 페이지. 격자 페이지와 같은 틀(스크롤 · 위 여백 · 제목 접기)에 담는다.
    /// 타입 메타데이터 깊이 때문에 AnyView 로 끊는다(`mainColumn` 주석).
    private var recentClipsPage: AnyView {
        AnyView(trackPageScroll(ScrollView {
            RecentClipsPage(
                searchQuery: viewModel.searchQueryString,
                onToast: { viewModel.showPlainToast($0) },
                onSnippetSaved: { viewModel.loadMemos() }
            )
            .padding(.bottom, 110)
        })
        .scrollEdgeEffectHidden(true, for: .all)
        .contentMargins(.top, pageContentTopMargin, for: .scrollContent))
    }

    @ViewBuilder
    private func memoPageView(for tab: CategoryTab) -> some View {
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

    /// 빈 상태 화면 위에 페이지 헤더(배너)를 얹는다.
    ///
    /// ⚠️ **빈 페이지도 스크롤 안에 그린다.** 격자 페이지와 같은 틀이어야 같은 규칙을 따른다.
    ///
    ///    예전에는 스크롤 없이 `VStack` 에 위 여백만 줬다. 그러자 이 페이지만 페이저 칸이
    ///    주는 시스템 여백(바 높이 116)을 받았다 놓았다 해서, 넘길 때마다 "추가" 카드가
    ///    110pt 가까이 튀었다(실측: minY 116 → 0). 시스템 여백을 끊으면 이번에는 시스템 바가
    ///    따라갈 스크롤이 없어 도착 0.5초 뒤 큰 제목을 스스로 접었다(실측).
    ///    스크롤 안에 두면 두 가지가 한 번에 풀린다. 여백은 격자 페이지와 같은 값 하나로만 잡는다.
    ///
    /// ⚠️ 안내 문구를 화면 가운데에 두려면 내용이 보이는 높이를 채워야 한다
    ///    (`EmptyStateWithAddCard` 가 `maxHeight: .infinity` 로 가운데를 잡는다).
    ///    스크롤 안에서는 그 무한이 0 으로 접히므로 보이는 높이를 직접 준다.
    private func emptyPage<Content: View>(for tab: CategoryTab, @ViewBuilder content: () -> Content) -> some View {
        let topMargin = pageContentTopMargin
        // ⚠️ 격자 페이지처럼 **스크롤을 제목에 알린다**(`trackPageScroll`). 예전에는 빈 페이지만
        //    빠져 있었다. 빈 페이지는 대개 한 화면 안이라 드러나지 않았는데, 위에 이름 바꾸기 카드 ·
        //    세 가지 카드가 서면 화면을 넘어 스크롤되고, 그때 큰 제목이 접히지 않아 카드가
        //    "Work" 제목 밑으로 깔려 씹혀 보였다(신고 화면).
        return trackPageScroll(ScrollView {
            VStack(spacing: 0) {
                pageHeader(for: tab)
                // 빈 페이지에서는 이 타일이 첫 단축어를 만드는 길이다.
                if showsFreshClipboard(on: tab) {
                    LazyVGrid(columns: gridColumns, spacing: 12) { freshClipboardCell(on: tab) }
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                }
                content()
            }
            .containerRelativeFrame(.vertical, alignment: .top) { height, _ in
                max(height - topMargin, 0)
            }
        })
        // 내용이 한 화면을 안 넘으면 튕기지 않는다 - 빈 화면이 손에 끌려 다니면 고장으로 읽힌다.
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeEffectHidden(true, for: .all)
        .contentMargins(.top, topMargin, for: .scrollContent)
        // ⚠️ 여기서 배경을 칠하지 않는다. 바닥은 탭 껍데기(SnippetsTab)가 깔고, 그 위에
        //    카테고리 틴트가 얹힌다 - 여기서 한 겹 더 칠하면 **그 틴트를 덮어** 버린다
        //    (카테고리 색이 사라졌던 원인).
    }

    @ViewBuilder
    private func tabPageContent(for tab: CategoryTab, filtered: [Memo]) -> some View {
        switch tab {
        case .recent:
            // `tabPageView` 가 먼저 가른다 - 여기 오지 않는다.
            EmptyView()
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
                        message: String(format: NSLocalizedString("'%@'에 단축어가 없습니다", comment: "Custom category empty state"), name),
                        tab: tab
                    )
                }
            }
        }
    }

    // MARK: - Search Empty State

    /// 검색 결과가 없을 때의 화면 - 그림은 `SearchNoResultsView` 가 그린다.
    /// 여기서는 그 카드를 눌렀을 때 **어떤 편집기를 여는지**만 답한다.
    private var searchNoResultsView: some View {
        SearchNoResultsView(
            query: viewModel.searchQueryString.trimmingCharacters(in: .whitespacesAndNewlines),
            columns: gridColumns,
            cardHeight: cardMinHeight
        ) { query in
            ghostAddPattern = QuickPattern(icon: AppSymbol.magnifyingglass, title: query, scaffold: "")
        }
    }

    private func allTabScrollView(memos allMemos: [Memo], tab: CategoryTab) -> some View {
        trackPageScroll(ScrollView {
            // ⚠️ **바깥은 `LazyVStack` 이 아니다.** 게으름은 아래 `LazyVGrid` 가 맡는다.
            //    이 줄에 서는 것은 배너·팁·격자 몇 개뿐이라 게으를 이유가 없고, 게으르면 사고가 났다.
            //    배너와 팁이 모두 닫혀 **앞줄이 전부 높이 0** 이면, `LazyVStack` 이 그릴 것이 없다고
            //    보고 격자를 한 번도 배치하지 않았다. 단축어가 8개인데 페이지가 통째로 비었다
            //    (실측: 내용 높이 110 = 아래 여백뿐, 격자 배치 로그 0회). 배너가 떠 있을 때만 카드가 보였다.
            VStack(alignment: .leading, spacing: 0) {
                // 배너 - 스크롤 콘텐츠라 스크롤하면 함께 올라간다(타이틀은 바에 고정, inlineLarge).
                pageHeader(for: tab)

                // 상단 여백 - 제목과 팁/그리드 사이 숨 쉬는 공간
                //
                // ⚠️ 8 이었다. 제목 글자 아래끝에서 첫 카드 윗변까지 22pt 가 떠서 제목과
                //    목록이 한 덩어리로 안 읽혔다. 제목 글꼴의 디센더가 이미 쿠션 노릇을
                //    하므로 여기서 당겨도 붙지 않는다(iPhone 17 Pro Max 실측 22pt → 16pt).
                // ⚠️ **위 여백을 여기 말고 다른 데서 찾지 말 것.** `pageContentTopMargin` 은
                //    스크롤 내용이 바 아래에서 시작하는 자리일 뿐, 이 사이와는 따로 논다(실측).
                // ⚠️ 아래 `filteredTabScrollView` 의 같은 빈 칸과 **같은 값**이어야 한다.
                //    다르면 기본 탭과 카테고리 탭의 제목 아래가 달라 보인다.
                // ⚠️ 8 → 2 로 줄이고도 기기에서 보면 여전히 떠 있었다. 아래 그리드가 자기
                //    위에 8pt 를 더 두고 있어서, 둘을 합치면 10pt 가 늘 깔려 있었다.
                //    빈 칸은 0 으로 두고 남은 간격은 그리드 쪽 하나로만 잰다.
                Color.clear.frame(height: 0)

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
                    // ⚠️ tipBackground 를 걸지 않는다. 마스코트 스타일이 말풍선을
                    //    직접 그리므로, 바깥에 판을 하나 더 깔면 풍선 뒤에 빈 카드가 겹친다.
                    AnimatedTip(tip: welcomeTip) {
                        TipView(welcomeTip)
                            .onDisappear { AddMemoTip.welcomeTipInvalidated = true }
                    }
                }
                .padding(.horizontal, 16)

                // Grace 배너
                if shouldShowGraceBanner && !blank {
                    GraceQuotaBannerView {
                        ProFeatureManager.markGraceBannerDismissed()
                        graceBannerVisible = false
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                // 카테고리 배지 끄기 넛지
                if showCategoryBadgeNudge && !blank {
                    categoryBadgeNudgeBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 전체 메모를 하나의 그리드로.
                // 정렬: 즐겨찾기 먼저 + lastEdited 내림차순 (viewModel.memos = sortMemos 결과).
                // 사용량(lastUsedAt) 기반 재정렬은 의도적으로 적용하지 않음 - 사용자가 위치를
                // 외워서 찾기 때문에 사용할 때마다 카드가 점프하면 안 됨.
                if !allMemos.isEmpty {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        freshClipboardCell(on: tab)
                        // 고스트(가상) 메모 - 실제 메모 셀과 같은 모양, 흐릿하게.
                        // 한 번 눌러보고 채워서 추가할지 판단하게 한다.
                        if let ghost = ghostSuggestion, !blank {
                            ghostMemoCell(pattern: ghost)
                        }
                        let anchor = slotAnchorID(in: allMemos)
                        ForEach(allMemos) { memo in
                            // 만들기 자리 · 임시 저장은 **새 카드가 앉을 바로 그 칸**에 선다(`slotAnchorID`).
                            if memo.id == anchor { slotCells(showsDrafts: true) }
                            // ⚠️ 카드가 목록에 **끼워질 때 아무 연출도 하지 않는다.**
                            //    기본값은 페이드인데, 투명도가 걸린 뷰는 화면 밖에서 한 장으로
                            //    합쳐 그려지고 그 안의 유리(`glassEffect`)는 뒤를 못 봐서
                            //    잿빛으로 뜬다. 메모는 화면이 뜬 뒤에 읽혀 들어오므로
                            //    (`viewModel.loadMemos`) 목록을 열 때마다 그 순간을 지난다.
                            memoGridCell(memo: memo)
                                .transition(.identity)
                        }
                        if anchor == nil { slotCells(showsDrafts: true) }
                        // 그리드 끝 "추가" 카드는 두지 않는다 - 우상단 툴바 + 버튼이 있으므로
                        // 추가 카드는 빈 상태 화면(emptyStateWithAddCard 등)에서만 노출.
                    }
                    .padding(.horizontal, 16)
                    // ⚠️ 제목과 첫 카드 사이를 잡는 **마지막 값**이다. 위의 빈 칸은 0 이라,
                    //    여기만 보면 된다(팁이 떠 있을 때는 팁과 그리드 사이이기도 하다).
                    .padding(.top, 2)
                }
            }
            // 하단 여백 - 페이저가 화면 바닥까지 확장되므로(ignoresSafeArea)
            // 마지막 카드가 플로팅 탭바에 가리지 않도록 탭바 높이 이상 확보.
            .padding(.bottom, 110)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: viewModel.selectedTypeFilter)
            // 붙여넣기 안내 배너 닫힘 애니메이션 - 배너의 transition만으로는
            // LazyVStack 행 높이 변화가 스냅되므로 컨테이너에 값 기반 애니메이션 필요(실측).
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: showPasteTip)
            .onTwoFingerTap { enterSelectionFromTwoFingerTap() }
        }
        // [디자인 불변식] 스크롤 엣지 이펙트는 전부 숨김 - ScrollView 자체에 직접.
        // (.top만 숨기면 스크롤 시 상단에 흰 배경 밴드가 생기는 회귀를 실측으로 확인)
        // 아래 끝을 흐리게 지우는 베일은 두지 않는다. 카드는 탭바 뒤로 그대로 지나간다(사용자 요청).
        .scrollEdgeEffectHidden(true, for: .all)
        // 콘텐츠 시작점(고정 타이틀 아래).
        .contentMargins(.top, pageContentTopMargin, for: .scrollContent))
    }

    private func filteredTabScrollView(memos: [Memo], tab: CategoryTab) -> some View {
        trackPageScroll(ScrollView {
            // 바깥은 `VStack` - 이유는 위 `allTabScrollView` 의 주석 참고.
            VStack(alignment: .leading, spacing: 0) {
                // 배너 - 스크롤 콘텐츠라 스크롤하면 함께 올라간다(타이틀은 바에 고정, inlineLarge).
                pageHeader(for: tab)
                // 위 여백 - `allTabScrollView` 의 같은 빈 칸과 같은 값을 쓴다.
                Color.clear.frame(height: 0)
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    freshClipboardCell(on: tab)
                    let anchor = slotAnchorID(in: memos)
                    ForEach(memos) { memo in
                        if memo.id == anchor { slotCells(showsDrafts: false) }
                        // 끼워질 때 연출 없음 - 이유는 위 `allTabScrollView` 의 주석 참고.
                        memoGridCell(memo: memo)
                            .transition(.identity)
                    }
                    if anchor == nil { slotCells(showsDrafts: false) }
                    // 그리드 끝 "추가" 카드 없음 - 우상단 툴바 + 버튼으로 충분.
                    // 추가 카드는 빈 상태(favoritesEmptyStateView·emptyStateWithAddCard)에서만.
                }
                .padding(.horizontal, 16)
                // 위 `allTabScrollView` 의 그리드와 같은 값을 쓴다.
                .padding(.top, 2)
            }
            // 페이저 바닥 확장(ignoresSafeArea)에 맞춘 탭바 가림 방지 여백.
            .padding(.bottom, 110)
            // 붙여넣기 안내 배너 닫힘 애니메이션(위 allTabScrollView 참고).
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: showPasteTip)
            .onTwoFingerTap { enterSelectionFromTwoFingerTap() }
        }
        // [디자인 불변식] 엣지 이펙트 전부 숨김(위 allTabScrollView 참고).
        .scrollEdgeEffectHidden(true, for: .all)
        .contentMargins(.top, pageContentTopMargin, for: .scrollContent))
    }

    /// 빈 자리를 먼저 세우고, 한 박자 뒤에 만들기 시트를 연다.
    ///
    /// ⚠️ 자리와 시트를 같은 프레임에 내면 자리가 서는 것을 못 본다. 시트가 곧바로
    ///    올라와 격자를 덮기 때문이다. 그러면 + 를 누른 사람에게 남는 것은 예전과 같이
    ///    시트뿐이고, 이 자리는 시트를 닫은 뒤에야 처음 보인다.
    ///
    /// ⚠️ 움직임 줄이기를 켠 사람에게는 기다리게 하지 않는다. 그쪽에는 자리가 자라는
    ///    것을 안 보여 주므로 기다릴 이유도 없다.
    private func openAddMemoWithSlot() {
        memoIDsBeforeAdd = Set(viewModel.memos.map(\.id))
        resumingDraft = nil
        // 펼친 듀오: 시트 대신 결과 쪽 판에 연다. 시트는 27.1 에서 접힌 선 한가운데에 선다
        if foldLayout.isUnfolded {
            FoldComposeRouter.shared.open(category: addMemoSheetCategory)
            return
        }
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72)) {
            pendingSlot = true
        }
        guard !reduceMotion else { showAddMemoSheet = true; return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pendingSlotBeat) {
            showAddMemoSheet = true
        }
    }

    /// 시트가 닫히면 자리를 거둔다. 취소했으면 자리만 사라진다(만들던 것이 있으면 임시 카드가 그 자리에 남는다).
    private func clearPendingSlot() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { pendingSlot = false }
    }

    /// 만들기가 닫혔다. 새 카드가 생겼으면 **자리를 연출 없이 걷고 그 자리에서 카드를 튀게 한다.**
    ///
    /// ⚠️ 예전에는 자리가 줄어들며 사라지는 동안 카드가 맨 앞에 그냥 끼워졌다. 즐겨찾기가 있으면
    ///    자리는 맨 앞, 카드는 즐겨찾기 뒤라 서로 다른 데서 지워지고 생겼다(2026-10 사용자: 부자연스럽다).
    ///    이제 자리는 새 카드가 앉을 칸에 서고(`slotAnchorID`), 그 칸에서 바로 카드가 된다.
    private func settlePendingSlot() {
        viewModel.loadMemos()
        let born = viewModel.memos
            .filter { !memoIDsBeforeAdd.contains($0.id) }
            .max { $0.lastEdited < $1.lastEdited }
        memoIDsBeforeAdd = []
        resumingDraft = nil
        guard let born else { clearPendingSlot(); return }
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { pendingSlot = false }
        celebrateBirth(born.id)
    }

    /// 새 카드가 그 자리에서 한 번 통 튀고 테두리가 반짝인다. 움직임 줄이기면 반짝임만.
    private func celebrateBirth(_ id: UUID) {
        HapticManager.shared.success()
        lightUpCard(id, after: 0)
        guard !reduceMotion else { return }
        // 카드가 한 장 그려진 다음 튄다. 같은 순간에 걸면 끼워지는 것과 섞여 안 보인다
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.16, dampingFraction: 0.9)) { poppingMemoID = id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.45)) { poppingMemoID = nil }
            }
        }
    }

    /// 새 카드가 앉을 칸: 즐겨찾기 바로 뒤. 목록은 즐겨찾기 → 최근에 고친 순이라 새 카드는 늘 거기 온다.
    /// nil 이면 맨 끝(전부 즐겨찾기이거나 비어 있다).
    private func slotAnchorID(in memos: [Memo]) -> UUID? {
        memos.first { !$0.isFavorite }?.id
    }

    /// 새 카드가 앉을 칸에 서는 것들: 만들기 자리, 그리고 만들다 떠난 임시 저장.
    /// 임시 저장은 첫 화면(기본 · 전체)에만 세운다. 카테고리 페이지마다 같은 카드가 서면 남의 것처럼 보인다.
    @ViewBuilder
    private func slotCells(showsDrafts: Bool) -> some View {
        if pendingSlot { pendingSlotCell }
        if showsDrafts {
            ForEach(draftStore.drafts.filter { $0.id != resumingDraft?.id }.sorted { $0.savedAt > $1.savedAt }) { draft in
                draftCell(draft)
            }
        }
    }

    /// 만들다 떠난 단축어. 진짜 카드와 같은 크기에 점선 테두리라 **아직 아닌 것**으로 읽힌다. 누르면 이어 쓴다.
    private func draftCell(_ draft: SavedDraft) -> some View {
        Button { resumeDraft(draft) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("임시 저장", comment: "Drafts screen title"))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.accent)
                Text(draft.displayTitle)
                    .font(.body.weight(.semibold))
                    .foregroundColor(theme.text)
                    .lineLimit(1)
                // 잠근 단축어는 본문을 내보이지 않는다
                if !draft.isSecure, !draft.keyword.isEmpty, !draft.previewLine.isEmpty {
                    Text(draft.previewLine)
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: cardMinHeight, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
                    .fill(theme.accent.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
                    .strokeBorder(theme.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { DraftStore.shared.remove(draft.id) }
            } label: {
                Label(NSLocalizedString("삭제", comment: "Delete button"), systemImage: AppSymbol.trash)
            }
        }
        .transition(.scale(scale: 0.86).combined(with: .opacity))
        .accessibilityLabel(String(format: NSLocalizedString("임시 저장: %@", comment: "VoiceOver label of a draft card in the list: an unfinished snippet. %@ is its title"), draft.displayTitle))
        .accessibilityHint(NSLocalizedString("이어서 쓰려면 두 번 누르세요", comment: "VoiceOver hint of a draft card: double tap to continue writing"))
    }

    /// 임시 카드를 눌렀다. 그 자리는 빈 자리로 바뀌고, 저장하면 그 자리에서 카드가 된다.
    private func resumeDraft(_ draft: SavedDraft) {
        HapticManager.shared.light()
        memoIDsBeforeAdd = Set(viewModel.memos.map(\.id))
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) {
            resumingDraft = draft
            pendingSlot = true
        }
        showAddMemoSheet = true
    }

    /// 만들기 시트가 열려 있는 동안 격자 맨 앞에 서는 빈 자리.
    /// 카드와 같은 크기·같은 모서리라, 시트를 닫으면 그 자리에 그대로 카드가 앉는다.
    private var pendingSlotCell: some View {
        RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
            .fill(theme.accent.opacity(0.07))
            .frame(maxWidth: .infinity, minHeight: cardMinHeight)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
                    .strokeBorder(theme.accent.opacity(0.28), lineWidth: 1.5)
            )
            .overlay(
                Image(systemName: AppSymbol.squareAndPencil)
                    .font(.title3)
                    .foregroundColor(theme.accent.opacity(0.5))
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .transition(.scale(scale: 0.86).combined(with: .opacity))
    }

    /// 빈 칸에 서는 것들은 `MemoListEmptyStates` 가 그린다. 여기서는 **눌렸을 때 무엇을
    /// 열지**만 답한다 - 어느 시트를 어떻게 여는지는 이 화면의 사정이다.
    private func openAddFlow(_ intent: AddCardCopy.Intent) {
        switch intent {
        case .addMemo(let category):
            addMemoSheetCategory = category
            showAddMemoSheet = true
        case .addFavorite:
            showAddFavoriteMemoSheet = true
        case .addTemplate:
            showAddTemplateSheet = true
        case .addStack:
            showAddStackSheet = true
        }
    }

    private func emptyStateWithAddCard(message: String, tab: CategoryTab) -> some View {
        EmptyStateWithAddCard(message: message,
                              tab: tab,
                              columns: gridColumns,
                              cardHeight: cardMinHeight,
                              hasListBackground: !resolvedBackgroundImage.isEmpty,
                              onAdd: openAddFlow)
    }

    private var favoritesEmptyStateView: some View {
        emptyStateWithAddCard(
            message: NSLocalizedString("즐겨찾기한 단축어가 없습니다.\n단축어를 꾹 눌러 즐겨찾기에 추가해보세요", comment: "Favorites tab empty state with hint"),
            tab: .favorites
        )
    }

    // MARK: - Selection Mode (여러 개 고르기)

    /// 두 손가락으로 톡 치면 여기로 온다.
    ///
    /// ⚠️ 이 몸짓은 **눈에 보이지 않는다.** 아는 사람만 쓰는 지름길이고, 같은 문이
    ///    꾹 누르기 판에도 있다(`onSelectMultiple`).
    ///
    /// ⛔️ 보이스오버가 켜져 있으면 오지 않는다. 인식기가 아예 꺼져 있고
    ///    (`TwoFingerTapAvailability`), 여기서 한 번 더 확인한다.
    private func enterSelectionFromTwoFingerTap() {
        #if os(iOS)
        guard TwoFingerTapAvailability.isAllowedNow else { return }
        #endif
        guard !viewModel.isSelectionMode, !viewModel.isReorderMode else { return }
        HapticManager.shared.medium()
        viewModel.enterSelectionMode()
    }

    /// 보고 있는 페이지에만 선다. 옆 페이지도 미리 지어지므로, 조건이 없으면 안 보이는 곳에서도 초를 센다.
    private func showsFreshClipboard(on tab: CategoryTab) -> Bool {
        viewModel.hasFreshClipboard && tab == viewModel.selectedCategoryTab
    }

    /// 방금 복사한 글이 격자 첫 칸에 만들어질 타일로 선다.
    ///
    /// ⚠️ 2026-05 목록을 갈래 격자로 바꿀 때(`8d4347f5`) 이 카드를 담던 묶음이 옮겨지지 않아
    ///    다섯 달 동안 안 보였다. 클립보드는 그동안에도 읽고 있었다(사용자 신고 2026-10-18).
    ///    격자가 없는 빈 페이지도 `emptyPage` 가 이 칸을 세운다.
    @ViewBuilder
    private func freshClipboardCell(on tab: CategoryTab) -> some View {
        if showsFreshClipboard(on: tab) {
            PromptRow(.freshClipboard, wants: true) {
                freshClipboardCard
            }
        }
    }

    /// 방금 복사한 글을 단축어로 저장하자는 타일.
    private var freshClipboardCard: some View {
        ClipboardCaptureCard(
            value: viewModel.value,
            detectedType: viewModel.clipboardDetectedType,
            suggestedTitle: viewModel.suggestedClipboardTitle,
            repeatCopies: viewModel.clipboardRepeatCopies,
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
            },
            onTimeout: {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                    viewModel.dismissClipboardCapture()
                }
            },
            cardHeight: cardMinHeight
        )
    }

    /// 우클릭(Mac) / 롱프레스(iOS) 컨텍스트 메뉴.
    /// Toolbar 컨텐츠
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        // 순정 iOS 26: 네비게이션 바 트레일링.
        // sharedBackgroundVisibility(.hidden) - 버튼을 감싸던 공유 글래스 필(불투명해 보이는
        // 흰 알약 배경)을 제거해 아이콘이 배경 위에 그대로 뜨게 한다(헤더 투명 불변식).
        // 단일 ToolbarItem + HStack - 별도 아이템로 두면 시스템이 간격을 벌려
        // 버튼이 뚝 떨어져 보이므로, 하나로 묶어 간격을 직접 제어한다.
        // 음수 spacing: 시스템이 Menu 라벨 둘레에 넣는 내부 여백(~12pt)을 상쇄해
        // 두 유리 서클이 살짝 붙어 보이게 한다(44pt 탭 영역은 유지).
        // 금고는 **왼쪽**에 따로 둔다. 오른쪽은 이미 메뉴+추가가 붙어 있어
        // 거기 하나를 더 끼우면 셋이 뭉쳐 보인다.
        //
        // ⚠️ 스킨이 금고가 아닐 때는 ToolbarItem 자체를 만들지 않는다. 안이 빈 아이템도
        //    자리는 차지해서, 시스템이 바가 넘친다고 보고 오른쪽에 ⋯ 오버플로 버튼을
        //    하나 더 만들어 버린다(⋯ 가 두 개로 보였던 원인).
        // 카테고리를 보고 있으면 제목 오른쪽에 아래 화살표. 누르면 카테고리 고르기 시트.
        // ⚠️ 제목 단추는 왼쪽 위 한 자리에만 세우고, 시스템 제목은 걷어 낸다(`hidesSystemTitle`).
        //    `.largeTitle` · `.title` 자리에 세웠더니 iOS 버전마다 두 자리가 함께 보이거나
        //    시스템 큰 제목과 겹쳐, 같은 제목이 두 번 섰다.
        if isInCategory {
            ToolbarItem(placement: .largeTitle) {
                // 큰 제목 자리는 가운데로 모아 세운다. 시스템 큰 제목처럼 왼쪽에 붙인다.
                categoryTitleButton().frame(maxWidth: .infinity, alignment: .leading)
            }
                .sharedBackgroundVisibility(.hidden)
        }
        ToolbarItem(placement: .topBarTrailing) {
            // ⚠️ 간격은 무대 머리말과 **같은 값**을 쓴다. 예전엔 여기만 -8이라
            //    44pt 유리 서클끼리 겹쳐 두 버튼이 한 덩어리로 보였다.
            GlassCircleCluster {
                if blank && !FeatureSet.hasGraduated(level: userState.state.level) {
                    // 키보드를 켜고 써 본 뒤에야 미리보기로 건너가는 단추가 선다
                    if keyboardLearned { SnippetsStyleSwitchButton(styleRaw: $snippetsTabStyleRaw) }
                    plainAddButton
                } else {
                    toolbarButtons
                }
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

    /// 카드를 길게 눌렀을 때의 할 일. 접혀 있으면 시트, 펼친 듀오에서는 결과 쪽 판에 선다.
    private func memoActions(_ memo: Memo) -> MemoActionSheet {
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
            // 펼친 듀오: 고치는 화면도 결과 쪽 판에(메뉴가 서 있던 그 자리)
            if foldLayout.isUnfolded {
                FoldComposeRouter.shared.open(edit: memo)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                memoToEdit = memo
            }
        },
        onDelete: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                memoToDelete = memo
            }
        },
        onMoveToCategory: blank && !FeatureSet.isOn(.category) ? nil : { category in
            HapticManager.shared.selection()
            viewModel.moveMemo(memo, toCategory: category)
        },
        onCreateNewCategory: blank && !FeatureSet.isOn(.category) ? nil : {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                memoForCategoryAssign = memo
                newCategoryForMemo = ""
                showNewCategoryForMemoAlert = true
            }
        },
        onReorder: blank ? nil : {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                viewModel.enterReorderMode()
            }
        },
        // 꾹 눌러 들어온 카드는 미리 골라 둔다 - 누른 것이 안 골라진 채
        // 열리면 왜 눌렀는지가 사라진다.
        onSelectMultiple: blank ? nil : {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                viewModel.enterSelectionMode(preselect: memo.id)
            }
        },
        // 이 카드를 묶을 수 없으면 줄을 내지 않는다(잠금 · 이미지 · 템플릿).
        onStack: (blank && !FeatureSet.isOn(.stack)) || !MemoStacking.canStack(memo) ? nil : {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showStackScreen = true
            }
        },
        onMakeTemplate: blank && !FeatureSet.isOn(.template) ? nil : {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                makeTemplateSource = memo
            }
        },
        onToggleSecure: blank && !FeatureSet.isOn(.secure) ? nil : {
            HapticManager.shared.selection()
            viewModel.toggleSecure(memoId: memo.id)
        }
    )
    }

    /// 툴바에서 여는 만들기 · 정리 시트들.
    ///
    /// ⚠️ 툴바 안에 달지 않고 **화면 본체에** 단다. 툴바 항목은 시스템이 다시 만들 수 있고, 그러면
    ///    시트가 뜨지 못하거나 닫혔다는 소식(onDismiss)이 오지 않는다. 그러면 파란 빈 자리가 격자에
    ///    남고 + 도 먹지 않는다(`ea863880` · 2026-10 사용자 보고).
    private func toolbarSheets<Content: View>(_ content: Content) -> some View {
        content
            .sheet(isPresented: $viewModel.isCategoryPickerShown) {
                CategoryPickerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showBulkImport) {
                BulkImportView()
            }
            .sheet(isPresented: $showShortcutMart) {
                // 담을 때마다 목록이 갱신되도록 - 마트는 여러 개를 이어서 담을 수 있다.
                ShortcutMartView { _ in viewModel.loadMemos() }
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
                    guard QuickNoteStore.shared.add(newNote) else {
                        viewModel.showPlainToast(NSLocalizedString("변경 사항을 저장하지 못했습니다", comment: "Save failed toast"))
                        return
                    }
                    // 담긴 위치를 바로 알려준다 - 상단 Inbox 배너도 함께 나타나 뷰어로 안내.
                    viewModel.showPlainToast(NSLocalizedString("메모를 보관함에 담았어요", comment: "Toast after quick note saved to inbox"))
                } onPromote: { newNote in
                    guard !newNote.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    QuickNoteStore.shared.add(newNote)
                    QuickNoteStore.shared.promoteToMemo(newNote)
                    viewModel.loadMemos()
                    viewModel.showPlainToast(NSLocalizedString("단축어로 저장했어요", comment: "Toast after quick note promoted to memo"))
                }
            }
            // 설정 > 카테고리 관리와 동일한 단일 화면(CategorySettings)을 시트로 재사용
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
            .sheet(isPresented: $showAddMemoSheet, onDismiss: {
                settlePendingSlot()
                // 첫 단축어를 담은 바로 그때 키보드를 켜자고 한다. 가장 의욕이 있을 때다
                if pendingKeyboardLesson {
                    pendingKeyboardLesson = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showKeyboardLesson = true }
                }
            }) {
                NavigationStack {
                    addMemoSheetContent
                        .toolbar {
                            // 단순한 새 단축어에는 V 하나만. 내리려면 시트를 끌어 내린다
                            if !blank {
                            ToolbarItem(placement: .topBarLeading) {
                                Button(NSLocalizedString("취소", comment: "Cancel")) { showAddMemoSheet = false }
                            }
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
            .sheet(isPresented: $showAddStackSheet, onDismiss: { viewModel.loadMemos() }) {
                NavigationStack {
                    MemoAdd(insertedIsStack: true)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button(NSLocalizedString("취소", comment: "Cancel")) { showAddStackSheet = false }
                            }
                        }
                }
            }
    }

    /// 만들기 시트의 내용. 임시 카드에서 왔으면 그 글로 이어 쓴다.
    @ViewBuilder
    private var addMemoSheetContent: some View {
        if let draft = resumingDraft {
            MemoAdd(
                insertedKeyword: draft.keyword,
                insertedValue: draft.value,
                insertedCategory: draft.category,
                insertedIsSecure: draft.isSecure,
                insertedHint: draft.hint,
                insertedIsFavorite: draft.isFavorite,
                resumeDraftId: draft.id
            )
        } else {
            MemoAdd(insertedCategory: addMemoSheetCategory.isEmpty ? "텍스트" : addMemoSheetCategory)
        }
    }

    /// 단순한 목록의 + . 메뉴 없이 바로 새 단축어를 연다.
    private var plainAddButton: some View {
        GlassCircleButton(AppSymbol.plus, role: .primary,
                          label: NSLocalizedString("단축어 추가", comment: "Add memo menu label")) {
            HapticManager.shared.light()
            addMemoSheetCategory = viewModel.newSnippetCategory
            openAddMemoWithSlot()
        }
    }

    /// Toolbar 버튼들 (iOS/macOS 공통)
    /// 구성: [더보기 메뉴(활용사례·보관함·카테고리·플레이스홀더)] [+ 추가]
    @ViewBuilder
    private var toolbarButtons: some View {
        // ⚠️ 예전 ⋯ 메뉴는 설정으로 옮겼다(활용 사례·보관함·스타터팩·플레이스홀더·배경).
        //    바에 ⋯ 와 + 와 금고를 다 두려니 시스템이 넘친다고 보고 오른쪽에 오버플로 ⋯ 를
        //    하나 더 만들어서, ⋯ 가 둘로 보이고 금고는 그 안에 접혀 사라졌다.
        //    바에는 **자주 쓰는 둘**만 남긴다 - 금고와 추가.
        vaultEntrance

        .accessibilityHint(NSLocalizedString("보관함, 카테고리 관리, 빈칸 관리 메뉴를 엽니다", comment: "More options menu hint v2"))

        // 화면 전환 - **+ 바로 왼쪽**. 누르면 키보드 미리보기로 건너가고,
        // 그쪽 머리말의 같은 자리에서 격자 모양으로 바뀌어 되돌아올 수 있다.
        SnippetsStyleSwitchButton(styleRaw: $snippetsTabStyleRaw)

        Menu {
            // 통합 모델: 사용자는 "메모"만 만든다. 변수({…})를 넣으면 템플릿, 이어지는 메모를 더하면 콤보가 된다.
            Button {
                HapticManager.shared.light()
                addMemoSheetCategory = viewModel.newSnippetCategory
                openAddMemoWithSlot()
            } label: {
                Label(NSLocalizedString("새 단축어 만들기", comment: "Menu: new memo"), systemImage: AppSymbol.squareAndPencil)
            }
            // 임시 저장 - 만들다 저장하지 않고 나간 미완성 메모를 이어서 작성.
            // ⚠️ 이어 쓸 것이 없으면 세우지 않는다. 빈 목록을 여는 줄은 쓸모없이 메뉴만 길게 한다(2026-10 사용자)
            if !draftStore.drafts.isEmpty {
                Button {
                    HapticManager.shared.light()
                    showDraftList = true
                } label: {
                    Label(draftMenuTitle, systemImage: "clock.arrow.circlepath")
                }
            }
            Divider()
            // 빈 화면 앞에서 "뭘 만들지"부터 떠올리지 않아도 되게 - 차려 둔 것에서 골라 온다.
            Button {
                HapticManager.shared.light()
                showShortcutMart = true
            } label: {
                Label(NSLocalizedString("단축어 마트에서 고르기", comment: "Menu: shortcut mart"),
                      systemImage: AppSymbol.bagFill)
            }
            Button {
                showBulkImport = true
            } label: {
                Label(NSLocalizedString("한번에 많은 단축어 정리하기", comment: "Menu: bulk import"), systemImage: AppSymbol.docOnClipboard)
            }
            // ⚠️ 이 시트는 배선만 돼 있고 **여는 길이 어디에도 없었다.**
            //    ⋯ 메뉴를 설정으로 옮길 때 항목만 빠지고 바인딩은 남아, 목록에서는
            //    죽은 화면이 되어 있었다. 설정 깊숙이 들어가야만 닿았다.
            // 빈칸은 3층이다. 설정 ▸ 단축어에는 늘 있다.
            if userState.isVisible(.template) {
            Button {
                HapticManager.shared.light()
                viewModel.showPlaceholderManagementSheet = true
            } label: {
                Label(NSLocalizedString("빈칸 관리", comment: "Placeholder management title (by name)"),
                      systemImage: AppSymbol.listBulletRectangle)
            }
            }
        } label: {
            // 시그니처 유리 서클(`GlassCircle`) - 하단 탭바와 같은 유리 언어.
            GlassCircleLabel(systemImage: AppSymbol.plus)
        }
        .accessibilityLabel(NSLocalizedString("단축어 추가", comment: "Add memo menu label"))
        .accessibilityHint(NSLocalizedString("새 단축어를 작성하거나 텍스트를 가져옵니다", comment: "Add memo menu hint"))
        .popoverTip(addMemoTip)
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
                // Liquid Glass 토스트 - 어둡게 틴트한 glass라 흰 글자 가독성 유지,
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

    /// 빈 목록.
    ///
    /// ⚠️ 여기에 온보딩을 세우지 않는다. 처음 쓰는 사람의 목록은 **비어 있지 않다** -
    ///    설치 첫 실행에 단축어·템플릿·콤보가 한 벌씩 들어가고(`performSampleInsertion`),
    ///    튜토리얼은 그걸 가리키며 눌러 보게 한다(`SnippetsTab`).
    ///    이 자리가 보이는 건 **다 지운 사람**뿐이고, 그 사람에게 필요한 건 안내가 아니라
    ///    다시 만들 자리를 알려 주는 한 줄이다.
    private var EmptyListView: some View {
        minimalEmptyState
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 무대가 가리키는 것을 목록도 그대로 가리킨다.
    ///
    /// ⚠️ 튜토리얼은 무대에서 도는데, 사용자는 도중에 목록으로 넘어올 수 있다. 그때
    ///    가리키는 것이 사라지면 하던 일이 끊긴 것처럼 보인다. 표식 하나를 두 화면이
    ///    함께 읽어 **어느 쪽에 있든 같은 것**을 가리킨다.
    private func syncCoachTarget() {
        let target = tutorialTargetRaw.isEmpty ? nil : UUID(uuidString: tutorialTargetRaw)
        withAnimation(.easeOut(duration: 0.25)) { coachMemoID = target }
    }

    /// "이걸 눌러보세요" - 안내는 닫기 버튼이 없다. 한 번 쓰면 스스로 사라진다.
    /// 카드 위에 떠 있는 것들 - 날아가는 동전과 코치.
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
                        line: NSLocalizedString("이걸 눌러보세요. 바로 복사돼요.",
                                                comment: "First-use coach: tap this card"),
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
            // 빈 화면은 **아무 말도 안 하는 화면**이다. 글 한 줄만 있으면 "고장인가"로도
            // 읽힌다. 빈 서랍 그림이 그 자체로 "아직 없다"를 말한다.
            Image(systemName: AppSymbol.tray)
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundColor(theme.textFaint)
                .accessibilityHidden(true)

            Text(NSLocalizedString("아직 단축어가 없어요. 위 + 를 눌러 하나 만들어요.", comment: "Empty list: no shortcuts yet"))
                .font(.body)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)

            // ⚠️ 아직 **자기 것을 하나도 안 만든 사람**에게만 준다.
            //    빈 칸에서 무엇부터 적을지 떠올리는 것이 첫 단축어를 막는 가장 큰 벽이라,
            //    그 사람에게는 빈 종이가 아니라 **고를 것**이 있어야 한다.
            //    한 번이라도 만든 사람에게는 이 말이 참견이 된다(`UserSurface.exampleMart`).
            if userState.isVisible(.exampleMart) && !blank {
                Button {
                    showShortcutMart = true
                } label: {
                    Text(NSLocalizedString("예시에서 골라 담기", comment: "Empty list: pick from examples"))
                        .font(.body.weight(.semibold))
                        .foregroundColor(Color.accentForeground)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(Color.accentColor, in: Capsule())
                }
                .padding(.top, 4)
            }
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

    /// 메모 복사 시 호출 - 3회 이상이면 카테고리 배지 끄기 넛지 표시 (1회)
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
                .foregroundColor(.accentColor)
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
                        .foregroundColor(Color.accentForeground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor, in: Capsule())
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

