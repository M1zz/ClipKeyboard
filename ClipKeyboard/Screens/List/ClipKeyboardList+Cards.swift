//
//  ClipKeyboardList+Cards.swift
//  ClipKeyboard
//
//  단축어 목록 화면(`ClipKeyboardList`)의 한 갈래.
//  카드 한 장: 격자 칸 · 제안 칸(고스트) · 눌림과 동전 · 생활 레이어 · 금고 입구.
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

    // MARK: - View Sections


    // MARK: - Grid

    /// 한 줄에 놓을 카드 수. 아이폰 2열 / 아이패드·맥 4열.
    ///
    /// ⚠️ `.adaptive(minimum:)` 을 쓰면 **안 된다.** 이 그리드는 `TabView(.page)` 안의
    ///    `ScrollView` 에 들어 있는데, 그 조합에서는 LazyVGrid 에 폭이 제대로 제안되지 않아
    ///    `.adaptive` 가 열 수를 1로 계산해 카드가 화면 전체로 늘어난다(실제로 그렇게 깨졌다).
    ///    `.flexible()` 은 폭 측정 없이 "가용 공간을 n등분"이라 이 문제가 없다.
    ///    그래서 열 수는 **측정이 아니라 size class 로** 정한다.
    var gridColumnCount: Int {
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

    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: gridColumnCount)
    }

    /// 고스트(가상) 메모 셀 - 실제 메모 셀과 같은 치수·제목 스타일을 그대로 쓰되
    /// 반투명 + 점선 테두리로 "아직 실재하지 않는 제안"임을 표현. 탭하면 채워서
    /// 추가하는 편집기로 진입(사용자가 한 번 눌러보고 판단).
    func ghostMemoCell(pattern: QuickPattern) -> some View {
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

    func memoGridCell(memo: Memo) -> some View {
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
    func copyFromCard(_ memo: Memo) {
        viewModel.copyMemo(memo: memo)
        checkCategoryBadgeNudge()
        // VoiceOver 안내는 복사가 **확정될 때** 한다(`finalizeCopy`). 여기서 하면
        // 템플릿·스택처럼 시트만 뜨는 경로에서도 "복사됨" 이라고 말해 버린다.
    }

    /// 카드의 추가 옵션을 연다. 꾹 누르기와 VoiceOver 동작이 같은 길을 쓴다.
    func openMemoActions(_ memo: Memo) {
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
    var cardStyle: MemoCardStyle {
        MemoCardStyle(
            categories: viewModel.customCategories,
            cardHeight: cardMinHeight,
            showsVisualCues: visualCuesVisible,
            showsContentHint: contentPreview != .off,
            contentAlwaysVisible: contentPreview == .always,
            hasListBackground: !resolvedBackgroundImage.isEmpty
        )
    }

    func memoCardSurface(memo: Memo, lightweight: Bool = false) -> MemoCardSurface {
        cardStyle.surface(for: memo, showsCoin: showsCoin(memo), lightweight: lightweight)
    }

    // MARK: - 생활 레이어

    /// 카드 위에 사는 것 - 물성 스킨과 다른 층이라 겹쳐 쓸 수 있다.
    var livingSkin: LivingSkin {
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
    var vaultEntrance: some View {
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
    var anyModalUp: Bool {
        viewModel.selectedStackIdForSheet != nil
            || viewModel.selectedTemplateIdForSheet != nil
            || viewModel.showTemplateInputSheet
    }

    /// 카드에 동전을 잠깐 보여주는 시간(초). 이 동안 그 카드는 내용 대신 동전을 보여준다.
    static let coinBadgeDwell: Double = 0.9

    /// 문구를 실제로 썼다는 신호를 받았다.
    ///
    /// 탭 시점이 아니라 **사용 확정 시점**에 불린다. 탭에서 처리하면 콤보·템플릿처럼
    /// 시트가 뜨는 경로에서 아직 쓰지도 않았는데 동전이 날아간다.
    func handleMemoUsed(_ note: Notification) {
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
    func stampCopied(_ memoID: UUID) {
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
    static let copiedStampDwell: Double = 0.9

    /// 방금 쓴 카드의 테두리를 1초 뒤에 켰다가 서서히 끈다.
    ///
    /// 왜 바로가 아니라 1초 뒤인가: 누른 순간에는 이미 눌림·햅틱·동전이 한꺼번에 일어난다.
    /// 거기 테두리까지 겹치면 무엇 하나 안 읽힌다. 동전이 금고에 닿을 즈음 뒤늦게 켜져야
    /// **"방금 그 카드가 일했다"**가 따로 읽힌다.
    /// - Parameter delay: 새 카드가 생길 때는 기다리지 않는다(`celebrateBirth`). 그때는 겹칠 다른 연출이 없다.
    func lightUpCard(_ memoID: UUID, after delay: Double = 1.0) {
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
    func handleGeodeUse(memoID: UUID) {
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
    func showCoinThenFly(memoID: UUID, seconds: Double, from point: CGPoint) {
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
    func showsCoin(_ memo: Memo) -> Bool {
        livingSkin == .vault && coinBadgeMemoID == memo.id
    }
}
