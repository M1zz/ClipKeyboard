//
//  ClipKeyboardList+Chrome.swift
//  ClipKeyboard
//
//  단축어 목록 화면(`ClipKeyboardList`)의 한 갈래.
//  페이지 바깥을 두르는 것: 여러 개 고르기 · 방금 복사한 글 카드 · 툴바 · 카드 메뉴 · 시트 · 토스트 · 떠 있는 층.
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

    // MARK: - Selection Mode (여러 개 고르기)

    /// 두 손가락으로 톡 치면 여기로 온다.
    ///
    /// ⚠️ 이 몸짓은 **눈에 보이지 않는다.** 아는 사람만 쓰는 지름길이고, 같은 문이
    ///    꾹 누르기 판에도 있다(`onSelectMultiple`).
    ///
    /// ⛔️ 보이스오버가 켜져 있으면 오지 않는다. 인식기가 아예 꺼져 있고
    ///    (`TwoFingerTapAvailability`), 여기서 한 번 더 확인한다.
    func enterSelectionFromTwoFingerTap() {
        #if os(iOS)
        guard TwoFingerTapAvailability.isAllowedNow else { return }
        #endif
        guard !viewModel.isSelectionMode, !viewModel.isReorderMode else { return }
        HapticManager.shared.medium()
        viewModel.enterSelectionMode()
    }

    /// 보고 있는 페이지에만 선다. 옆 페이지도 미리 지어지므로, 조건이 없으면 안 보이는 곳에서도 초를 센다.
    func showsFreshClipboard(on tab: CategoryTab) -> Bool {
        viewModel.hasFreshClipboard && tab == viewModel.selectedCategoryTab
    }

    /// 방금 복사한 글이 격자 첫 칸에 만들어질 타일로 선다.
    ///
    /// ⚠️ 2026-05 목록을 갈래 격자로 바꿀 때(`8d4347f5`) 이 카드를 담던 묶음이 옮겨지지 않아
    ///    다섯 달 동안 안 보였다. 클립보드는 그동안에도 읽고 있었다(사용자 신고 2026-10-18).
    ///    격자가 없는 빈 페이지도 `emptyPage` 가 이 칸을 세운다.
    @ViewBuilder
    func freshClipboardCell(on tab: CategoryTab) -> some View {
        if showsFreshClipboard(on: tab) {
            PromptRow(.freshClipboard, wants: true) {
                freshClipboardCard
            }
        }
    }

    /// 방금 복사한 글을 단축어로 저장하자는 타일.
    var freshClipboardCard: some View {
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
    var toolbarContent: some ToolbarContent {
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
        // ⚠️ 제목 단추는 `.largeTitle` 한 자리에만 세운다. `.title` 자리에도 세웠더니
        //    기기에서 두 자리가 함께 보여 같은 제목이 두 번 섰다.
        if isInCategory {
            ToolbarItem(placement: .largeTitle) {
                // 이 자리는 그냥 두면 가운데에 선다. 시스템 큰 제목처럼 왼쪽에 붙인다.
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
    func memoActions(_ memo: Memo) -> MemoActionSheet {
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
    func toolbarSheets<Content: View>(_ content: Content) -> some View {
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
    var addMemoSheetContent: some View {
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
    var plainAddButton: some View {
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
    var toolbarButtons: some View {
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
    var toastOverlay: some View {
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
    var EmptyListView: some View {
        minimalEmptyState
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 무대가 가리키는 것을 목록도 그대로 가리킨다.
    ///
    /// ⚠️ 튜토리얼은 무대에서 도는데, 사용자는 도중에 목록으로 넘어올 수 있다. 그때
    ///    가리키는 것이 사라지면 하던 일이 끊긴 것처럼 보인다. 표식 하나를 두 화면이
    ///    함께 읽어 **어느 쪽에 있든 같은 것**을 가리킨다.
    func syncCoachTarget() {
        let target = tutorialTargetRaw.isEmpty ? nil : UUID(uuidString: tutorialTargetRaw)
        withAnimation(.easeOut(duration: 0.25)) { coachMemoID = target }
    }

    /// "이걸 눌러보세요" - 안내는 닫기 버튼이 없다. 한 번 쓰면 스스로 사라진다.
    /// 카드 위에 떠 있는 것들 - 날아가는 동전과 코치.
    var floatingLayer: some View {
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
    var minimalEmptyState: some View {
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
    func refreshGhostSuggestion() {
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
    func dismissGhostPattern(_ pattern: QuickPattern) {
        var dismissed = UserDefaults.standard.stringArray(forKey: dismissedGhostPatternsKey) ?? []
        if !dismissed.contains(pattern.title) {
            dismissed.append(pattern.title)
            UserDefaults.standard.set(dismissed, forKey: dismissedGhostPatternsKey)
        }
    }

    /// 메모 복사 시 호출 - 3회 이상이면 카테고리 배지 끄기 넛지 표시 (1회)
    func checkCategoryBadgeNudge() {
        guard showVisualCues else { return }
        guard !UserDefaults.standard.bool(forKey: DefaultsKey.categoryBadgeNudgeDismissed) else { return }
        let count = UserDefaults.standard.integer(forKey: DefaultsKey.memoCopyCount) + 1
        UserDefaults.standard.set(count, forKey: DefaultsKey.memoCopyCount)
        if count >= 3 {
            withAnimation(.easeInOut(duration: 0.3)) { showCategoryBadgeNudge = true }
        }
    }

    /// 카테고리 색상 배지 끄기 넛지 배너
    var categoryBadgeNudgeBanner: some View {
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
