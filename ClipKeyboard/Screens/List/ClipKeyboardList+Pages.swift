//
//  ClipKeyboardList+Pages.swift
//  ClipKeyboard
//
//  단축어 목록 화면(`ClipKeyboardList`)의 한 갈래.
//  페이지: 카테고리 한 장 · 최근 · 전체와 걸러 본 스크롤 · 빈 자리와 임시 저장 칸 · 빈 화면.
//
//  상태(`@State` · `@AppStorage`)와 화면의 뼈대(`body` · 시트를 거는 단계들)는 `ClipKeyboardList.swift` 에 있다.
//  저장 속성은 확장에 둘 수 없어서 그쪽에 모여 있고, 여기는 그 상태로 그리는 것과 하는 일만 둔다.
//

import SwiftUI
import LocalAuthentication
import TipKit
import UniformTypeIdentifiers
import PhotosUI
import LeeoKit

extension ClipKeyboardList {

    // MARK: - Tab Background Color

    /// 사용자 카테고리 페이지의 바탕 물. 기본 · 즐겨찾기 · 기본 제공 갈래는 물들이지 않는다.
    ///
    /// ⚠️ **화면 바닥이 아니라 페이지에 칠한다.** 예전에는 화면 전체 바닥 하나를 카테고리 색으로
    ///    물들이고 0.38초에 걸쳐 바꿨는데, 페이지는 0.25초면 넘어가서 카드는 이미 새 카테고리인데
    ///    바닥색만 뒤늦게 쓸려 오는 번쩍임이 됐다(`screenBody` 주석, 8b04a4b). 페이지에 붙이면
    ///    색은 따로 바뀌는 순간이 없다. 넘기는 손가락을 따라 카드와 함께 들어오고 나간다.
    /// ⚠️ 배경 사진을 고른 사람에게는 칠하지 않는다 - 사진을 덮는다.
    func pageTint(for tab: CategoryTab) -> Color {
        guard case .custom(let name) = tab, resolvedBackgroundImage.isEmpty else { return .clear }
        return customCategoryColor(name).opacity(theme.isDark ? 0.14 : 0.09)
    }

    /// 커스텀 카테고리 색상. 사용자가 지정한 색(userCategoryColors_v1)이 있으면 우선,
    /// 없으면 카테고리 순서에 따라 결정적으로 팔레트 색 반환.
    func customCategoryColor(_ name: String) -> Color {
        categoryTint(for: name, in: viewModel.customCategories)
    }

    /// 검색어가 비어 있지 않은(공백 제외) 상태 - 검색 결과 없음 분기 판단에 사용.
    var isSearching: Bool {
        !viewModel.searchQueryString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    func tabPageView(for tab: CategoryTab) -> some View {
        if tab == .recent {
            recentClipsPage
        } else {
            memoPageView(for: tab)
        }
    }

    /// 맨 앞 '최근' 페이지. 격자 페이지와 같은 틀(스크롤 · 위 여백 · 제목 접기)에 담는다.
    /// 타입 메타데이터 깊이 때문에 AnyView 로 끊는다(`mainColumn` 주석).
    var recentClipsPage: AnyView {
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
    func memoPageView(for tab: CategoryTab) -> some View {
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
    func emptyPage<Content: View>(for tab: CategoryTab, @ViewBuilder content: () -> Content) -> some View {
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
    func tabPageContent(for tab: CategoryTab, filtered: [Memo]) -> some View {
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
    var searchNoResultsView: some View {
        SearchNoResultsView(
            query: viewModel.searchQueryString.trimmingCharacters(in: .whitespacesAndNewlines),
            columns: gridColumns,
            cardHeight: cardMinHeight
        ) { query in
            ghostAddPattern = QuickPattern(icon: AppSymbol.magnifyingglass, title: query, scaffold: "")
        }
    }

    func allTabScrollView(memos allMemos: [Memo], tab: CategoryTab) -> some View {
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

    func filteredTabScrollView(memos: [Memo], tab: CategoryTab) -> some View {
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
    func openAddMemoWithSlot() {
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
    func clearPendingSlot() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { pendingSlot = false }
    }

    /// 만들기가 닫혔다. 새 카드가 생겼으면 **자리를 연출 없이 걷고 그 자리에서 카드를 튀게 한다.**
    ///
    /// ⚠️ 예전에는 자리가 줄어들며 사라지는 동안 카드가 맨 앞에 그냥 끼워졌다. 즐겨찾기가 있으면
    ///    자리는 맨 앞, 카드는 즐겨찾기 뒤라 서로 다른 데서 지워지고 생겼다(2026-10 사용자: 부자연스럽다).
    ///    이제 자리는 새 카드가 앉을 칸에 서고(`slotAnchorID`), 그 칸에서 바로 카드가 된다.
    func settlePendingSlot() {
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
    func celebrateBirth(_ id: UUID) {
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
    func slotAnchorID(in memos: [Memo]) -> UUID? {
        memos.first { !$0.isFavorite }?.id
    }

    /// 새 카드가 앉을 칸에 서는 것들: 만들기 자리, 그리고 만들다 떠난 임시 저장.
    /// 임시 저장은 첫 화면(기본 · 전체)에만 세운다. 카테고리 페이지마다 같은 카드가 서면 남의 것처럼 보인다.
    @ViewBuilder
    func slotCells(showsDrafts: Bool) -> some View {
        if pendingSlot { pendingSlotCell }
        if showsDrafts {
            ForEach(draftStore.drafts.filter { $0.id != resumingDraft?.id }.sorted { $0.savedAt > $1.savedAt }) { draft in
                draftCell(draft)
            }
        }
    }

    /// 만들다 떠난 단축어. 진짜 카드와 같은 크기에 점선 테두리라 **아직 아닌 것**으로 읽힌다. 누르면 이어 쓴다.
    func draftCell(_ draft: SavedDraft) -> some View {
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
    func resumeDraft(_ draft: SavedDraft) {
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
    var pendingSlotCell: some View {
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
    func openAddFlow(_ intent: AddCardCopy.Intent) {
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

    func emptyStateWithAddCard(message: String, tab: CategoryTab) -> some View {
        EmptyStateWithAddCard(message: message,
                              tab: tab,
                              columns: gridColumns,
                              cardHeight: cardMinHeight,
                              hasListBackground: !resolvedBackgroundImage.isEmpty,
                              onAdd: openAddFlow)
    }

    var favoritesEmptyStateView: some View {
        emptyStateWithAddCard(
            message: NSLocalizedString("즐겨찾기한 단축어가 없습니다.\n단축어를 꾹 눌러 즐겨찾기에 추가해보세요", comment: "Favorites tab empty state with hint"),
            tab: .favorites
        )
    }
}
