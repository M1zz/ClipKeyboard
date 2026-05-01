//
//  ClipKeyboardList.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/05/14.
//

import SwiftUI
import LocalAuthentication

var fontSize: CGFloat = 20

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

struct ClipKeyboardList: View {

    @StateObject private var viewModel = ClipKeyboardListViewModel()

    // MARK: - View-only State

    @State private var isSearchBarVisible = false
    @State private var memoToDelete: Memo? = nil
    @State private var graceBannerVisible: Bool = ProFeatureManager.hasGraceMemoQuota && !ProFeatureManager.didDismissGraceBanner
    @State private var showPaywallFromKeyboard: Bool = false
    @State private var showBulkImport: Bool = false
    @State private var hasAppeared: Bool = false
    @State private var scrollOffset: CGFloat = 0

    @Environment(\.appTheme) private var theme

    private var shouldShowGraceBanner: Bool {
        graceBannerVisible && !ProFeatureManager.isPro
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Design handoff: bg 토큰으로 전체 배경 통일.
                theme.bg.ignoresSafeArea()

                // 메모 리스트
                if !viewModel.memos.isEmpty {
                    List {
                        // 1. 검색 바 (조건부)
                        if isSearchBarVisible {
                            Section {
                                searchBarInlineSection
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // 2. Ambient Top Block — 인사말 + 통계 + 컨텍스트 액션 카드 (하나로 통합)
                        //    Notes 스타일: 스크롤 시 부드럽게 fade-out
                        if viewModel.selectedTypeFilter == nil {
                            Section {
                                ambientTopBlock
                                    .background(scrollOffsetReader)
                                    .opacity(greetingOpacity)
                            }
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        // 3. 타입 필터 바
                        if !viewModel.loadedData.isEmpty {
                            Section {
                                typeFilterBarInlineSection
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        // 4. Grace 배너 (조건부)
                        if shouldShowGraceBanner {
                            Section {
                                GraceQuotaBannerView {
                                    ProFeatureManager.markGraceBannerDismissed()
                                    graceBannerVisible = false
                                }
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        // 5. 리뷰 배너 (조건부)
                        if ReviewManager.shared.shouldShowBanner {
                            Section {
                                ReviewBannerView()
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        // 6. 메모 리스트 — 섹션 헤더 없이 단일 스트림.
                        //    · recency opacity로 시간감 전달
                        //    · 날짜 경계에서 초미니멀 divider 삽입
                        //    · 첫 로드 시 stagger enter 애니메이션
                        Section {
                            ForEach(Array(viewModel.memos.enumerated()), id: \.element.id) { index, memo in
                                let prevMemo = index > 0 ? viewModel.memos[index - 1] : nil
                                if let dayLabel = dayBoundaryLabel(for: memo, previousMemo: prevMemo) {
                                    timeDivider(label: dayLabel)
                                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                }
                                memoRow(memo: memo)
                                    .opacity(recencyOpacity(for: memo) * (hasAppeared ? 1.0 : 0.0))
                                    .offset(y: hasAppeared ? 0 : 16)
                                    .animation(
                                        .easeOut(duration: 0.35).delay(Double(min(index, 12)) * 0.035),
                                        value: hasAppeared
                                    )
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .coordinateSpace(name: "listScroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        scrollOffset = value
                    }
                    .animation(.easeInOut(duration: 0.28), value: viewModel.selectedTypeFilter)
                }

                // 빈 화면
                if viewModel.memos.isEmpty {
                    EmptyListView
                }
            }
            .task {
                viewModel.loadMemos()
            }
            .toolbar {
                toolbarContent
            }
            // Toast 메시지 오버레이
            .overlay(alignment: .bottom) {
                toastOverlay
            }
            .animation(.easeInOut(duration: 0.5), value: viewModel.showToast)

            // Navigation 설정 — 타이틀 제거. 그리팅이 상단 앵커 역할.
            // 접근성: VoiceOver용으로 숨은 라벨 유지.
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .accessibilityLabel(NSLocalizedString("Saved items", comment: "Screen: main memo list"))
            // 검색 및 필터 변경 감지
            .onChange(of: viewModel.searchQueryString) { _ in viewModel.applyFilters() }
            .onChange(of: viewModel.selectedTypeFilter) { _ in
                viewModel.applyFilters()
                viewModel.saveSelectedFilter()
            }
            // 인증 실패 Alert
            .alert(NSLocalizedString("인증 실패", comment: "Auth failed"), isPresented: $viewModel.showAuthAlert) {
                Button(NSLocalizedString("확인", comment: "Confirm"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("보안 메모에 접근하려면 생체 인증이 필요합니다", comment: "Biometric auth required"))
            }
            // 메모 삭제 확인 Alert
            .alert(
                NSLocalizedString("메모 삭제", comment: "Delete memo alert title"),
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
                Text(NSLocalizedString("이 작업은 취소할 수 없습니다.", comment: "Delete warning"))
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
            .onAppear {
                viewModel.onAppear()
                fontSize = UserDefaults.standard.object(forKey: "fontSize") as? CGFloat ?? 20.0
                // 첫 로드 시 stagger enter 트리거 (한 번만)
                if !hasAppeared {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        hasAppeared = true
                    }
                }
            }
            .paywall(isPresented: $showPaywallFromKeyboard, triggeredBy: nil)
            .onReceive(NotificationCenter.default.publisher(for: .showPaywall)) { _ in
                showPaywallFromKeyboard = true
            }
        }
    }

    // MARK: - View Sections

    /// 검색 바 섹션 (인라인)
    private var searchBarInlineSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme.textFaint)
                .font(.system(size: 16))

            TextField(NSLocalizedString("검색", comment: "Search"), text: $viewModel.searchQueryString)
                .textFieldStyle(PlainTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !viewModel.searchQueryString.isEmpty {
                Button(action: {
                    HapticManager.shared.soft()
                    viewModel.searchQueryString = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.textFaint)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.surfaceAlt)
        .cornerRadius(theme.radiusSm)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundColor(theme.text)
            Text(contextLine)
                .font(.system(size: 13))
                .foregroundColor(theme.textMuted)
            if let savedText = timeSavedBadgeText {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11))
                    Text(savedText)
                        .font(.system(size: 12, weight: .medium))
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
                onDismiss: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        viewModel.dismissClipboardCapture()
                    }
                },
                onSaveTap: {
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
            MemoRowView(memo: memo, fontSize: fontSize)
                .padding(14)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.blue.opacity(0.18), lineWidth: 1)
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
                    Text(memo.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.text)
                    if memo.isTemplate {
                        TagBadge(label: NSLocalizedString("Template", comment: "Tag: template"))
                    }
                    if memo.isCombo {
                        TagBadge(label: NSLocalizedString("Combo", comment: "Tag: combo"))
                    }
                    if memo.isSecure {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textFaint)
                    }
                    Spacer(minLength: 0)
                }

                #if os(iOS)
                if (memo.contentType == .image || memo.contentType == .mixed),
                   let firstImageFileName = memo.imageFileNames.first,
                   let image = MemoStore.shared.loadImage(fileName: firstImageFileName) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                #endif

                if !memo.value.isEmpty {
                    Text(memo.value)
                        .font(.system(size: 15))
                        .foregroundColor(theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                HStack(spacing: 8) {
                    if memo.clipCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 10))
                            Text(String(format: NSLocalizedString("Used %d×", comment: "Preview: total use count"), memo.clipCount))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(theme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.surfaceAlt)
                        .clipShape(Capsule())
                    }
                    if memo.isFavorite {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                            Text(NSLocalizedString("Favorite", comment: "Preview: favorite badge"))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.pink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.pink.opacity(0.12))
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

    /// 이전 메모와 날짜(캘린더 기준 일)가 바뀔 때만 divider 라벨 반환. 같은 날이면 nil.
    private func dayBoundaryLabel(for memo: Memo, previousMemo: Memo?) -> String? {
        let cal = Calendar.current
        let reference = memo.lastUsedAt ?? memo.lastEdited

        guard let prev = previousMemo else {
            return relativeDateLabel(reference)
        }
        let prevRef = prev.lastUsedAt ?? prev.lastEdited
        if cal.isDate(reference, inSameDayAs: prevRef) { return nil }
        return relativeDateLabel(reference)
    }

    /// 초미니멀 day divider — 얇은 수평선 + 작은 라벨.
    private func timeDivider(label: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(theme.divider)
                .frame(height: 0.5)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(theme.textFaint)
                .textCase(.uppercase)
                .tracking(0.5)
            Rectangle()
                .fill(theme.divider)
                .frame(height: 0.5)
        }
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
        MemoTypeFilterBar(selectedFilter: $viewModel.selectedTypeFilter, memos: viewModel.loadedData)
    }

    /// 메모 행
    private func memoRow(memo: Memo) -> some View {
        Button {
            HapticManager.shared.soft()
            viewModel.copyMemo(memo: memo)
        } label: {
            MemoRowView(
                memo: memo,
                fontSize: fontSize,
                showFavoriteNudge: viewModel.memos.first?.id == memo.id && viewModel.showFavoriteNudge
            )
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .cornerRadius(theme.radiusMd)
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            editButton(memo: memo)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                memoToDelete = memo
            } label: {
                Label(NSLocalizedString("삭제", comment: "Delete memo"), systemImage: "trash")
            }
            Button {
                viewModel.toggleFavorite(memoId: memo.id)
            } label: {
                Label(
                    memo.isFavorite
                        ? NSLocalizedString("즐겨찾기 해제", comment: "Remove favorite")
                        : NSLocalizedString("즐겨찾기", comment: "Add favorite"),
                    systemImage: memo.isFavorite ? "heart.slash" : "heart"
                )
            }
            .tint(.pink)
        }
        .contextMenu {
            memoContextMenu(memo: memo)
        } preview: {
            memoContextPreview(memo: memo)
        }
        .transition(.scale)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowSeparator(.hidden)
    }

    /// 우클릭(Mac) / 롱프레스(iOS) 컨텍스트 메뉴.
    /// swipe 액션은 iOS trackpad에서만 닿고 Mac에서는 불편하므로 같은 액션을 컨텍스트로도 제공.
    @ViewBuilder
    private func memoContextMenu(memo: Memo) -> some View {
        Button {
            viewModel.copyMemo(memo: memo)
        } label: {
            Label(NSLocalizedString("Copy", comment: "Context: copy"), systemImage: "doc.on.doc")
        }

        Button {
            viewModel.toggleFavorite(memoId: memo.id)
        } label: {
            Label(
                memo.isFavorite
                    ? NSLocalizedString("즐겨찾기 해제", comment: "Remove favorite")
                    : NSLocalizedString("즐겨찾기", comment: "Add favorite"),
                systemImage: memo.isFavorite ? "heart.slash" : "heart"
            )
        }

        Divider()

        NavigationLink {
            MemoAdd(
                memoId: memo.id,
                insertedKeyword: memo.title,
                insertedValue: memo.value,
                insertedCategory: memo.category,
                insertedIsTemplate: memo.isTemplate,
                insertedIsSecure: memo.isSecure,
                insertedIsCombo: memo.isCombo,
                insertedComboValues: memo.comboValues
            )
        } label: {
            Label(NSLocalizedString("수정", comment: "Edit"), systemImage: "pencil")
        }

        Divider()

        Button(role: .destructive) {
            memoToDelete = memo
        } label: {
            Label(NSLocalizedString("삭제", comment: "Delete memo"), systemImage: "trash")
        }
    }

    /// 수정 버튼
    private func editButton(memo: Memo) -> some View {
        NavigationLink {
            MemoAdd(
                memoId: memo.id,
                insertedKeyword: memo.title,
                insertedValue: memo.value,
                insertedCategory: memo.category,
                insertedIsTemplate: memo.isTemplate,
                insertedIsSecure: memo.isSecure,
                insertedIsCombo: memo.isCombo,
                insertedComboValues: memo.comboValues
            )
        } label: {
            Label(NSLocalizedString("수정", comment: "Edit"), systemImage: "pencil")
        }
        .tint(.green)
    }

    /// Toolbar 컨텐츠
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItemGroup(placement: .bottomBar) {
            toolbarButtons
        }
        #else
        ToolbarItemGroup(placement: .automatic) {
            toolbarButtons
        }
        #endif
    }

    /// Toolbar 버튼들 (iOS/macOS 공통)
    /// 구성: [검색 토글] [더보기 메뉴(히스토리·플레이스홀더·설정)]  ···  [+ 추가]
    /// "클립보드 앱의 주어는 '꺼내기'"라는 관점에서 검색/추가를 시각적으로 주연으로.
    @ViewBuilder
    private var toolbarButtons: some View {
        Button {
            HapticManager.shared.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isSearchBarVisible.toggle()
                if !isSearchBarVisible {
                    viewModel.searchQueryString = ""
                }
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isSearchBarVisible ? .blue : .secondary)
        }

        Menu {
            NavigationLink {
                ClipboardList()
            } label: {
                Label(
                    NSLocalizedString("클립보드 히스토리", comment: "Menu: clipboard history"),
                    systemImage: "clock.arrow.circlepath"
                )
            }

            Button {
                HapticManager.shared.light()
                viewModel.showPlaceholderManagementSheet = true
            } label: {
                Label(
                    NSLocalizedString("플레이스홀더 관리", comment: "Menu: placeholder management"),
                    systemImage: "list.bullet"
                )
            }

            NavigationLink {
                SettingView()
            } label: {
                Label(
                    NSLocalizedString("설정", comment: "Menu: settings"),
                    systemImage: "gearshape"
                )
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(theme.textMuted)
        }

        Spacer()

        Menu {
            NavigationLink {
                MemoAdd()
            } label: {
                Label(NSLocalizedString("New memo", comment: "Menu: new memo"), systemImage: "square.and.pencil")
            }
            Button {
                showBulkImport = true
            } label: {
                Label(NSLocalizedString("Bulk import from text", comment: "Menu: bulk import"), systemImage: "doc.on.clipboard")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.blue)
        }
        .sheet(isPresented: $showBulkImport) {
            BulkImportView()
        }
    }

    /// Toast 오버레이
    @ViewBuilder
    private var toastOverlay: some View {
        if viewModel.showToast {
            Text(viewModel.toastMessage)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.toastBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                .onTapGesture {
                    HapticManager.shared.soft()
                    viewModel.showToast = false
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeOut(duration: 0.2), value: viewModel.showToast)
                .padding(.bottom, 50)
        }
    }

    /// Empty list view
    private var EmptyListView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 24) {
                Text(NSLocalizedString("자주 치는 문장이 뭔가요?", comment: "Empty state question"))
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    Text("\"\(NSLocalizedString("회의가 10분 늦어질 것 같습니다", comment: "Empty state example 1"))\"")
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                    Text("\"\(NSLocalizedString("확인했습니다. 검토 후 답변드리겠습니다", comment: "Empty state example 2"))\"")
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
                .multilineTextAlignment(.center)

                NavigationLink {
                    MemoAdd()
                } label: {
                    Text(NSLocalizedString("첫 클립 추가", comment: "Add first clip button"))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(height: 44)
                        .padding(.horizontal, 24)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 30)
            .background(theme.bg)
            .cornerRadius(theme.radiusLg)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
}

struct ClipKeyboardList_Previews: PreviewProvider {
    static var previews: some View {
        ClipKeyboardList()
    }
}



// MARK: - Memo Type Filter Bar

struct MemoTypeFilterBar: View {
    @Binding var selectedFilter: ClipboardItemType?
    let memos: [Memo]

    // resolvedType 기준으로 개수 계산 — 이미지/자동분류 타입까지 반영
    var typeCounts: [ClipboardItemType: Int] {
        var counts: [ClipboardItemType: Int] = [:]
        for memo in memos {
            if let type = ClipboardClassificationService.shared.resolvedType(for: memo) {
                counts[type, default: 0] += 1
            }
        }
        return counts
    }

    // 개수가 많은 순서대로 타입 정렬
    var sortedTypes: [ClipboardItemType] {
        ClipboardItemType.allCases.sorted { type1, type2 in
            let count1 = typeCounts[type1, default: 0]
            let count2 = typeCounts[type2, default: 0]
            return count1 > count2
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // 전체 버튼 (항상 첫 번째)
                MemoFilterChip(
                    title: NSLocalizedString("전체", comment: "All"),
                    icon: "list.bullet",
                    count: memos.count,
                    isSelected: selectedFilter == nil
                ) {
                    selectedFilter = nil
                }

                // 타입별 필터 (개수가 많은 순서대로 정렬)
                ForEach(sortedTypes, id: \.self) { type in
                    MemoFilterChip(
                        title: type.localizedName,
                        icon: type.icon,
                        count: typeCounts[type, default: 0],
                        color: type.color,
                        isSelected: selectedFilter == type
                    ) {
                        selectedFilter = type
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MemoFilterChip: View {
    let title: String
    let icon: String
    let count: Int
    var color: String = "blue"
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .fontWeight(isSelected ? .semibold : .regular)
                Text(title)
                    .font(.system(size: 13))
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("\(count)")
                    .font(.system(size: 11))
                    .fontWeight(isSelected ? .bold : .medium)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        isSelected
                            ? Color.white.opacity(0.25)
                            : Color.black.opacity(0.1)
                    )
                    .cornerRadius(8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? Color.fromName(color) : theme.surfaceAlt)
                    .shadow(
                        color: isSelected ? Color.fromName(color).opacity(0.3) : Color.clear,
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            )
            .foregroundColor(isSelected ? .white : theme.textFaint)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        isSelected ? Color.white.opacity(0.2) : Color.clear,
                        lineWidth: 1
                    )
            )
            .scaleEffect(isSelected ? 1.0 : 0.96)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sheet Modifiers
/// 모든 Sheet 프레젠테이션을 관리하는 ViewModifier
struct SheetModifiers: ViewModifier {
    // Sheet 표시 상태
    @Binding var showTemplateInputSheet: Bool
    @Binding var showPlaceholderManagementSheet: Bool
    @Binding var selectedTemplateIdForSheet: UUID?
    @Binding var selectedComboIdForSheet: UUID?

    // 데이터
    let templatePlaceholders: [String]
    @Binding var templateInputs: [String: String]
    let memos: [Memo]
    let currentTemplateMemo: Memo?

    // 콜백
    let onTemplateComplete: () -> Void
    let onTemplateCancel: () -> Void
    let onTemplateCopy: (Memo, String) -> Void
    let onTemplateSheetCancel: () -> Void
    let onComboDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            // 템플릿 입력 시트
            .sheet(isPresented: $showTemplateInputSheet) {
                if currentTemplateMemo != nil {
                    TemplateInputSheet(
                        placeholders: templatePlaceholders,
                        inputs: $templateInputs,
                        onComplete: onTemplateComplete,
                        onCancel: onTemplateCancel
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
            // 플레이스홀더 관리 시트
            .sheet(isPresented: $showPlaceholderManagementSheet) {
                PlaceholderManagementSheet(allMemos: memos)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            // 템플릿 편집 시트
            .sheet(item: $selectedTemplateIdForSheet) { templateId in
                TemplateSheetResolver(
                    templateId: templateId,
                    allMemos: memos,
                    onCopy: onTemplateCopy,
                    onCancel: onTemplateSheetCancel
                )
            }
            // Combo 편집 시트
            .sheet(item: $selectedComboIdForSheet) { comboId in
                ComboSheetResolver(
                    comboId: comboId,
                    allMemos: memos,
                    onDismiss: onComboDismiss
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }
}
