//
//  ListTopBanners.swift
//  ClipKeyboard
//
//  단축어 목록 맨 위의 배너 묶음. `ClipKeyboardList` 에서 떼어 냈다.
//
//  왜 따로 사는가: 목록 화면은 상태 수십 개를 한 뷰에 들고 있어서, 그중 하나만 바뀌어도 카드 격자까지
//  통째로 다시 그렸다. 배너는 스스로 나타나고 물러나며 상태를 자주 바꾸는 쪽이다(결제 순간을 붙잡고,
//  닫은 것을 적고, 이용 기간 안내를 다시 읽는다). 그 상태를 여기로 옮기면 배너가 바뀔 때 다시 그려지는
//  것이 이 묶음에서 끝난다.
//
//  밖으로 나가는 일(페이월 · 보관함 · 한 번에 정리하기 시트)은 목록 화면이 띄운다. 여기서는 알리기만 한다.
//

import SwiftUI
import TipKit
import LeeoKit

struct ListTopBanners: View {

    @ObservedObject var viewModel: ClipKeyboardListViewModel
    /// 지금 이 사람이 어디쯤인가. 돈 이야기를 꺼내도 되는 때인지 본다.
    @ObservedObject private var userState = UserStateStore.shared

    /// 붙여넣기 허용 안내. 목록 화면이 닫히는 움직임을 같이 걸어야 해서 그쪽이 쥔다.
    @Binding var showPasteTip: Bool
    /// 유예 배너가 서 있는가(격자 위, 목록 화면이 그린다). 서 있으면 Pro 넛지는 비킨다.
    let graceBannerShowing: Bool
    /// 페이월을 띄워 달라. 값은 무엇 때문에 띄우는가(`nil` 이면 일반 업그레이드).
    let onPaywall: (ProFeatureManager.LimitType?) -> Void
    let onOpenInbox: () -> Void
    let onBulkImport: () -> Void

    // 가치 순간 Pro 넛지 - 1회·닫기 가능 (페이월 노출률 향상)
    @State private var proNudgeDismissed: Bool = UserDefaults.standard.bool(forKey: DefaultsKey.proValueNudgeDismissedV1)
    /// 잘못 열려 있던 기능이 닫힌다는 안내 - 떠 있는 동안 붙잡아 둔다(`ProFeatureManager.accessEndingNoticeNow`).
    @State private var accessNotice: ProFeatureManager.AccessEndingNotice? = ProFeatureManager.accessEndingNoticeNow
    /// 지금 화면에 서 있는 결제 순간.
    ///
    /// ⚠️ **왜 상태로 붙잡아 두나:** 띄우는 그 자리에서 "봤다"고 못박는데(평생 한 번),
    ///    그러면 `dueMoment` 는 곧바로 nil 이 된다. 화면이 그 값을 그대로 보고 있으면
    ///    배너가 나타나자마자 사라진다. 기록은 기록대로 남기고, 지금 보여 줄 것은 여기에 둔다.
    @State private var activeMoment: PurchaseMoment?
    /// Inbox 배너를 닫은 시점의 항목 수. 이보다 더 쌓이면(=새 캡처) 배너가 다시 나타난다.
    @State private var inboxBannerDismissCount: Int = 0

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
              !graceBannerShowing else { return false }
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

    /// 상단 배너 모음. **자리마다 하나, 많아야 세 줄이다** (상태 띠 · 지금 카드 · 제안 카드).
    ///
    /// 띠마다 "말할 거리가 있다" 를 `PromptRow` 로 올리고, 누가 설지는 `PromptBoard` 가
    /// 고른다(`PromptArbiter`). 예전에는 띠 13개가 서로를 몰라 한꺼번에 설 수 있었다.
    /// 아래 순서는 그리는 순서일 뿐이고, 같은 종류 안의 차례는 `PromptCandidate.listOrder` 다.
    /// 설계: docs/design/PROGRESSIVE_DISCLOSURE.md 4절
    ///
    /// AnyView로 타입 소거 - mainColumn VStack의 제네릭 중첩 깊이를 줄이는 핵심.
    var body: some View {
        #if DEBUG
        let _ = HangProbe.noteRender("ListTopBanners")
        #endif
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
                    onOpenInbox()
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
                                onPaywall(.memo)
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
                            onPaywall(momentToShow?.limitType)
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
                    onBulkImport()
                }

                // 판마다 다른 필수 단축어 세 칸 (`PersonaEdition`). 보여 줄지는 컨테이너가 정한다.
                PersonaEssentialsCardContainer(memos: viewModel.memos,
                                               hasLoaded: viewModel.hasLoadedMemos,
                                               isAwayOrJustBack: userState.state.activity != .active) {
                    onPaywall(.memo)
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
            .onReceive(NotificationCenter.default.publisher(for: .accessRevoked)) { _ in
                accessNotice = ProFeatureManager.accessEndingNoticeNow
            }
            // 체험 마지막 날은 앱을 켜 둔 채로도 온다.
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                accessNotice = ProFeatureManager.accessEndingNoticeNow
            }
        )
    }

    /// iOS 설정의 이 앱 페이지(‘다른 앱에서 붙여넣기’ 토글 포함)를 연다.
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
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
}
