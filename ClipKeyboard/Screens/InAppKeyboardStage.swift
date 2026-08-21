//
//  InAppKeyboardStage.swift
//  ClipKeyboard
//
//  **무대** - 앱을 열면 키보드가 실제로 올라온 모습이 그대로 보인다.
//
//  왜 이렇게 하는가: 이 앱의 값어치는 목록이 아니라 **다른 앱에서 키보드로 꺼내 쓰는 순간**에
//  있다. 그런데 앱을 열면 카드 목록만 보여서, 키보드를 설치하고도 한 번도 안 써 본 사람이
//  자기가 뭘 갖고 있는지 모른 채 지나갔다. 그래서 앱의 첫 화면을 **키보드가 쓰이는 장면**으로 둔다.
//
//  ⚠️ 아래 키보드는 흉내가 아니라 **익스텐션과 같은 `KeyboardView`** 다. 두 벌로 만들면
//     하나만 고쳐지는 날이 반드시 온다. 다른 점은 글이 가는 곳뿐
//     익스텐션은 남의 앱 텍스트 필드로, 여기서는 위 입력창으로 간다(`InAppKeyboardHost`).
//
//  ⚠️ 위쪽 대화는 **우리 말풍선**이다. 메시지 앱을 그대로 베끼지 않는다
//     남의 앱 화면을 재현한 것처럼 보이면 심사에서 문제가 되고, 사용자도 진짜 대화로 오해한다.
//

import SwiftUI
import LeeoKit

struct InAppKeyboardStage: View {
    /// 튜토리얼이 가리키는 키 - 방금 만든 문구. 누르면 첫 걸음이 끝난다.
    var highlightedMemoId: UUID? = nil
    /// 가리키는 동안 대화 위에 얹을 안내 한 줄. 장마다 다르다(`TutorialChapter.coachLine`).
    var tutorialLine: String? = nil

    /// 지금 어느 화면을 보고 있는가 - 머리말의 전환 버튼이 이 값을 뒤집는다.
    /// 목록 쪽에도 **같은 버튼**이 얹혀 있어 어느 쪽에서든 왔다갔다 할 수 있다.
    @Binding var styleRaw: String

    /// 키보드에 실린 문구 id 목록 - 바뀌었을 때만 키보드를 다시 만든다.
    @State private var loadedIds: [UUID]

    /// ⚠️ 문구를 **여기서** 읽는다. 예전에는 `onAppear` 에서 읽고 곧바로 `feedToken` 을 올려
    ///    키보드를 다시 만들었는데, 그게 화면이 들어오는 도중에 일어나 **전환이 한 번 튀었다**
    ///    (목록 → 미리보기 방향만 이상했던 이유 - 반대 방향엔 다시 만들 일이 없다).
    ///    뷰가 만들어지는 시점에 미리 읽어 두면 등장할 때는 그릴 것이 이미 준비돼 있다.
    init(styleRaw: Binding<String>, highlightedMemoId: UUID? = nil, tutorialLine: String? = nil) {
        self._styleRaw = styleRaw
        self.highlightedMemoId = highlightedMemoId
        self.tutorialLine = tutorialLine
        // ⚠️ **비어 있을 때만** 읽는다. init 은 부모가 다시 그릴 때마다 도는데,
        //    매번 파일을 읽으면 글자 하나 칠 때마다 디스크를 두드리게 된다.
        //    그 뒤의 갱신은 onAppear·문구 변경 알림이 맡는다.
        if clipMemos.isEmpty { KeyboardMemoFeed.reload() }
        _loadedIds = State(initialValue: clipMemos.map(\.id))
    }

    @StateObject private var host = InAppKeyboardHost()
    @Environment(\.appTheme) private var theme

    /// 문구 목록이 바뀔 때마다 올린다 - `KeyboardView`는 등장할 때 한 번만 목록을 읽으므로
    /// (익스텐션에서는 키보드가 뜰 때마다 새 프로세스라 그걸로 충분했다),
    /// 앱에서는 이 값을 `.id`로 물려 다시 태어나게 해야 새 문구가 보인다.
    @State private var feedToken = 0

    /// 키보드 설치 안내(`KeyboardSetupOnboardingView`)를 띄우는 중인가.
    @State private var showsKeyboardSetup = false
    /// 새 단축어 만들기 시트.
    @State private var showsAddMemo = false
    /// 이 무대를 볼 때마다 다시 확인한다 - 설정에서 켜고 돌아오면 띠가 사라져야 한다.
    @State private var keyboardReady = true

    /// 아래 키보드가 쓰는 것과 **같은** 배경 설정 - 무대 배경을 거기에 맞춘다.
    ///
    /// ⚠️ 무대와 키보드는 한 화면이다. 무대만 `theme.bg` 로 칠하면, 키보드 색을 직접 고른
    ///    사람의 화면에서 대화 영역과 키보드 사이에 **경계선이 생긴다.** 같은 값을 읽어
    ///    같은 색을 칠한다(키 색은 키보드 몫이라 여기서 보지 않는다).
    @AppStorage("keyboardUseCustomColors", store: AppGroup.defaults)
    private var keyboardUseCustomColors: Bool = false
    @AppStorage("keyboardCustomBgHex", store: AppGroup.defaults)
    private var keyboardCustomBgHex: String = ""

    /// 무대 전체가 깔고 앉는 색 - 아래 키보드의 배경색과 언제나 같다.
    private var stageBackground: Color {
        if keyboardUseCustomColors, !keyboardCustomBgHex.isEmpty,
           let custom = Color(hex: keyboardCustomBgHex) {
            return custom
        }
        return theme.bg
    }

    /// 클립보드에 붙일 이미지가 있는가 - 붙여넣기 버튼을 낼지 말지.
    /// ⚠️ **그릴 때마다 묻지 않는다.** 화면에 들어올 때·앱으로 돌아올 때·이미지 키를 누른 뒤에만
    ///    확인한다(`hasImages`는 팝업을 띄우지 않지만, 매 프레임 물어볼 이유도 없다).
    @State private var clipboardHasImage = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                stageHeader
                // 여기까지 배웠으면 마지막 한 걸음은 **진짜 키보드를 켜는 것**이다.
                // 무대에서 아무리 눌러 봐도 다른 앱에서 못 쓰면 아무 일도 일어나지 않는다.
                if !keyboardReady { keyboardSetupBanner }
                conversation
                composer
                // ⚠️ 안내는 **가리키는 것 바로 옆**에 둔다. 화면 맨 위에 두었더니 빛나는 키와
                //    멀어서 둘이 같은 이야기인 줄 몰랐다 - 눈이 글에서 키로 바로 건너가야 한다.
                tutorialCue
                // 진짜 키보드와 같은 뷰. 높이는 실제 키보드가 차지하는 만큼(화면의 절반쯤).
                KeyboardView(typingProxy: host,
                             documentState: host.documentState,
                             hostKind: .inApp,
                             highlightedMemoId: highlightedMemoId)
                    .frame(height: min(max(geo.size.height * 0.5, 260), 430))
                    .id(feedToken)
            }
        }
        .background(stageBackground.ignoresSafeArea())
        .onAppear {
            reloadFeed()
            refreshKeyboardReady()
            refreshClipboardImage()
        }
        .onDisappear { host.stop() }
        // 설정에서 키보드를 켜고 돌아오면 띠가 스스로 사라져야 한다.
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshKeyboardReady()
            refreshClipboardImage()
        }
        // 이미지 키를 누르면 클립보드에도 들어간다 - 뗐을 때 다시 붙일 수 있어야 하므로
        // 그 직후에 한 번 더 확인한다.
        .onReceive(NotificationCenter.default.publisher(for: .addImageEntry)) { _ in
            refreshClipboardImage()
        }
        .fullScreenCover(isPresented: $showsKeyboardSetup, onDismiss: refreshKeyboardReady) {
            KeyboardSetupOnboardingView { showsKeyboardSetup = false }
        }
        // 목록에서 문구를 만들거나 고치면 무대의 키보드도 따라와야 한다.
        .onReceive(NotificationCenter.default.publisher(for: .memoDataChanged)) { _ in
            reloadFeed()
        }
        // 만들고 나면 무대의 키보드에 바로 그 키가 있어야 한다 - 닫힐 때 다시 읽는다.
        .sheet(isPresented: $showsAddMemo, onDismiss: reloadFeed) {
            NavigationStack {
                MemoAdd(insertedCategory: "텍스트")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(NSLocalizedString("취소", comment: "Cancel")) { showsAddMemo = false }
                        }
                    }
            }
        }
    }

    /// 저장소 → `clipMemos` → 키보드 뷰 순으로 새로 읽는다.
    ///
    /// ⚠️ **바뀐 게 없으면 키보드를 다시 만들지 않는다.** 다시 만들면 그 순간 화면이 튀고,
    ///    검색어·콤보 위치 같은 그때그때의 상태도 함께 날아간다.
    ///
    /// ⚠️ 순서만 달라진 것은 **바뀐 것으로 치지 않는다.** 문구를 한 번 쓰면 `lastEdited` 가
    ///    갱신되어 목록 순서가 바뀌는데, 그걸 변화로 보면 **누를 때마다 키보드가 통째로
    ///    다시 만들어졌다.** 그 순간 방금 시작한 연출(껍데기 깨기)이 함께 사라졌고,
    ///    무엇보다 방금 누른 키가 손가락 밑에서 다른 자리로 튀었다.
    ///    있고 없고가 달라졌을 때만 다시 만든다.
    private func reloadFeed() {
        KeyboardMemoFeed.reload()
        let ids = clipMemos.map(\.id)
        guard Set(ids) != Set(loadedIds) else {
            loadedIds = ids     // 순서는 조용히 따라간다(다음 판단의 기준이 되게)
            return
        }
        loadedIds = ids
        feedToken += 1
    }

    /// 진짜 키보드를 쓸 수 있는 상태인가 - 판단은 `KeyboardInstallState` 한 곳에서만 한다.
    /// (설정에서 켰거나, 익스텐션이 한 번이라도 떴으면 쓸 수 있는 것으로 본다)
    private func refreshKeyboardReady() {
        keyboardReady = KeyboardInstallState.isUsable
    }

    /// 클립보드에 이미지가 있는지만 확인한다(내용은 읽지 않는다 - 읽으면 팝업이 뜬다).
    private func refreshClipboardImage() {
        clipboardHasImage = host.clipboardHasImage
    }

    /// 무대 아래 띠 - 마지막 한 걸음(진짜 키보드 켜기)으로 데려간다.
    ///
    /// ⚠️ 알림(모달)로 띄우지 않는다. 앱을 열자마자 창이 뜨면 무엇을 하라는 건지 보기도 전에
    ///    닫게 된다. 무대를 보여준 **다음에** 한 줄로 권하는 편이 이어진다.
    private var keyboardSetupBanner: some View {
        Button {
            HapticManager.shared.light()
            showsKeyboardSetup = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(NSLocalizedString("아직 다른 앱에서는 못 써요", comment: "Keyboard not set up banner title"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(theme.text)
                    Text(NSLocalizedString("키보드를 켜면 어디서든 이 화면이 올라와요", comment: "Keyboard not set up banner body"))
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                }
                Spacer(minLength: 0)
                Text(NSLocalizedString("켜기", comment: "Turn on the keyboard"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.accentForeground)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.accentColor))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.accentColor.opacity(0.10))
    }

    // MARK: - 머리말

    /// 제목 하나에 갈 곳 둘 - **목록**(있는 걸 고치러)과 **+**(새로 만들러).
    ///
    /// ⚠️ 설명 문구("다른 앱에서 보이는 그대로예요")는 뺐다. 아래에 진짜 키보드가
    ///    올라와 있는데 그걸 말로 또 설명하면, 매일 여는 화면에서 한 줄이 늘 자리만 차지한다.
    ///
    /// ⚠️ **+ 가 없으면 이 화면에서는 단축어를 만들 길이 없다.** 무대는 쓰는 자리이지
    ///    만드는 자리가 아니어서 목록으로만 보냈는데, 만들려면 두 번 건너가야 했다.
    private var stageHeader: some View {
        HStack(spacing: SnippetsStyleSwitchButton.clusterSpacing) {
            // ⚠️ 이건 **화면 제목**이다. 목록 쪽은 진짜 `navigationTitle` 이라 크게 나오는데
            //    여기만 `.headline`(본문과 같은 크기)이라, 같은 탭을 오갈 때 한쪽만
            //    제목이 사라진 것처럼 보였다. 무대는 네비게이션 바가 없어 머리말을 직접
            //    그리므로, 크기도 직접 제목만큼 준다.
            Text(NSLocalizedString("키보드 미리보기", comment: "In-app keyboard stage title"))
                .font(.title2.weight(.bold))
                .foregroundColor(theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            SnippetsStyleSwitchButton(styleRaw: $styleRaw)
            Button {
                HapticManager.shared.light()
                showsAddMemo = true
            } label: {
                // 목록 툴바의 + 와 같은 규격·같은 유리 서클.
                Image(systemName: AppSymbol.plus)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: SnippetsStyleSwitchButton.diameter,
                           height: SnippetsStyleSwitchButton.diameter)
                    .glassEffect(.clear.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("단축어 추가", comment: "Add a snippet"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.surface.opacity(0.6))
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.divider.opacity(0.5)).frame(height: 0.5)
        }
    }

    // MARK: - 대화

    /// 튜토리얼이 가리키는 중이면 대화 위에 한 줄 더 얹는다 - 무엇을 하라는 건지
    /// 빛만으로는 모를 수 있다. 빛은 **어디**를, 이 줄은 **무엇을** 알려 준다.
    @ViewBuilder
    private var tutorialCue: some View {
        if highlightedMemoId != nil {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Image(systemName: "hand.tap.fill")
                    .font(.subheadline.weight(.semibold))
                Text(tutorialLine
                     ?? NSLocalizedString("빛나는 단축어를 눌러 보세요", comment: "Tutorial cue on the stage"))
                    .font(.subheadline.weight(.bold))
                // 아래를 가리킨다 - 글과 빛나는 키 사이를 눈이 건너갈 길을 만든다.
                Image(systemName: "arrow.down")
                    .font(.caption.weight(.bold))
                Spacer(minLength: 0)
            }
            .foregroundColor(Color.accentForeground)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor)
        }
    }

    /// 대화 영역은 **무대와 같은 바탕**이다. 여기만 다른 색을 깔면 말풍선이 뜬 자리가
    /// 판때기처럼 보이고, 아래 키보드와도 배경이 어긋난다.
    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(host.messages) { message in
                        bubble(message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: host.messages.count) {
                guard let last = host.messages.last else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bubble(_ message: StageMessage) -> some View {
        let mine = message.side == .outgoing
        return HStack(alignment: .top, spacing: 8) {
            if mine { Spacer(minLength: 40) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 6) {
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
                        .accessibilityLabel(NSLocalizedString("보낸 이미지", comment: "Stage bubble: sent image"))
                }
                // 이미지만 보낸 말풍선에는 글칸을 그리지 않는다 - 빈 칸이 남으면 덜 만든 것처럼 보인다.
                if !message.text.isEmpty {
                    Text(message.text.templateAwareAttributed(theme: theme, font: .callout))
                        .font(.callout)
                        .foregroundColor(mine ? Color.accentForeground : theme.text)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        // 꼬리가 붙는 쪽에 그만큼 자리를 비워 준다 - 안 비우면 글자가 꼬리에 물린다.
                        .padding(mine ? .trailing : .leading, StageBubble.tailWidth)
                        // ⚠️ 받은 말풍선은 **바탕과 확실히 달라야** 한다. 풍선이 안 보이면
                        //    무대가 대화로 읽히지 않는다.
                        //    · surface(흰색)  : 밝은 바탕과 밝기가 붙어 흐리다
                        //    · surfaceAlt     : 바탕과 거의 같은 색이라 **풍선이 사라진다**
                        //    그래서 테마 토큰이 아니라 중립 회색을 쓴다. 밝고 어두운 화면
                        //    모두에서 스스로 뒤집힌다.
                        .background(
                            StageBubble(pointsLeft: !mine, radius: theme.radiusMd)
                                .fill(mine ? Color.accentColor : Color(uiColor: .systemGray5))
                        )
                        .textSelection(.enabled)
                }
            }
            if !mine { Spacer(minLength: 40) }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - 입력창

    /// 시스템 키보드는 뜨지 않는다 - 이 칸은 **아래 우리 키보드만** 채운다.
    /// (진짜 `TextField`를 두면 탭할 때 시스템 키보드가 올라와 무대가 가려진다)
    private var composer: some View {
        VStack(spacing: 6) {
            // 붙여 둔 이미지는 글 위에 - 이미지는 캐럿 자리에 끼울 수 없어 딸린 첨부로 둔다.
            if let image = host.attachedImage {
                attachmentChip(image)
            }
            HStack(alignment: .bottom, spacing: 8) {
                pasteImageButton
                composerField
                Button {
                    HapticManager.shared.light()
                    withAnimation(.easeOut(duration: 0.2)) { host.send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(host.canSend ? .accentColor : theme.textMuted.opacity(0.5))
                }
                .buttonStyle(.plain)
                .disabled(!host.canSend)
                .accessibilityLabel(NSLocalizedString("보내기", comment: "Send composed message"))
            }
        }
        .padding(.horizontal, 12)
        // 칸 자체를 낮췄으니 띠도 같이 얇게 - 한쪽만 줄이면 여백만 남아 더 어색하다.
        .padding(.vertical, 6)
        .background(theme.surface.opacity(0.6))
        .overlay(alignment: .top) {
            Rectangle().fill(theme.divider.opacity(0.5)).frame(height: 0.5)
        }
        .animation(.easeOut(duration: 0.2), value: host.attachedImage)
    }

    /// 클립보드에 이미지가 있을 때만 나오는 붙여넣기 버튼.
    ///
    /// ⚠️ 이미지 단축어를 누르면 이미 알아서 붙는다. 이 버튼은 **다른 데서 복사해 온** 이미지
    ///    (사진 앱·다른 앱)를 무대에서 붙여 볼 때를 위한 것이다. 늘 보이면 쓸 일 없는 버튼이
    ///    자리만 차지하므로 클립보드에 이미지가 있을 때만 나타난다.
    @ViewBuilder
    private var pasteImageButton: some View {
        if clipboardHasImage && host.attachedImage == nil {
            Button {
                HapticManager.shared.light()
                withAnimation(.easeOut(duration: 0.2)) { _ = host.pasteImageFromClipboard() }
            } label: {
                Image(systemName: AppSymbol.photoOnRectangleAngled)
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                    .frame(width: 30, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("복사한 이미지 붙여넣기", comment: "Paste copied image into the composer"))
        }
    }

    /// 입력창 위에 붙은 이미지 한 장 - x 로 뗀다.
    private func attachmentChip(_ image: UIImage) -> some View {
        HStack(spacing: 8) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(NSLocalizedString("이미지가 붙었어요. 보내면 올라가요", comment: "Composer attachment hint"))
                .font(.caption)
                .foregroundColor(theme.textMuted)
            Spacer(minLength: 0)
            Button {
                HapticManager.shared.light()
                withAnimation(.easeOut(duration: 0.2)) { host.detachImage() }
            } label: {
                Image(systemName: AppSymbol.xmarkCircleFill)
                    .font(.body)
                    .foregroundColor(theme.textMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("이미지 떼기", comment: "Remove the attached image"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    /// 입력창 한 줄의 속 높이. 여기와 위아래 여백을 더한 것이 칸의 실제 높이다(26 + 4·2 = 34).
    private static let composerLineHeight: CGFloat = 26
    private static let composerVerticalPadding: CGFloat = 4
    /// 반경은 칸 높이의 절반 - 높이를 바꿔도 알약 모양이 유지된다.
    private static var composerRadius: CGFloat { (composerLineHeight + composerVerticalPadding * 2) / 2 }

    private var composerField: some View {
        Group {
            if host.text.isEmpty {
                // 빈칸일 때도 캐럿은 서 있어야 "여기로 들어간다"가 읽힌다.
                placeholderText
            } else {
                composedText
            }
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        // ⚠️ 한 줄짜리 칸이다. 예전에는 46pt(높이 34 + 위아래 6)라 글 한 줄에 비해
        //    빈 위아래가 넓어, 아래 키보드와 나란히 놓으면 이 칸만 부풀어 보였다.
        //    반경은 높이의 절반이라 값이 바뀌어도 늘 알약 모양이 된다.
        .frame(minHeight: Self.composerLineHeight, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, Self.composerVerticalPadding)
        .background(theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: Self.composerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.composerRadius, style: .continuous)
                .strokeBorder(theme.divider.opacity(0.6), lineWidth: 0.5)
        )
        .accessibilityLabel(NSLocalizedString("입력창", comment: "Composer field accessibility label"))
        .accessibilityValue(host.text)
    }

    /// 캐럿을 사이에 낀 본문. 깜빡이지 않는다
    /// 하루에도 여러 번 여는 화면에서 상시 타이머는 소음이고 배터리다.
    ///
    /// ⚠️ `{변수}` 는 여기서도 **칩으로** 보여야 한다. 이 앱의 규칙은
    ///    "플레이스홀더는 어디서든 원문 중괄호가 아닌 하이라이트로 보인다" 인데,
    ///    이 입력창만 원문을 그대로 그려서 미리보기에 `{이름}` 이 노출됐다.
    private var composedText: Text {
        let chars = Array(host.text)
        let cut = min(max(host.caret, 0), chars.count)
        // 캐럿이 `{…}` **안쪽**에 들어가면 거기서 문자열이 잘려 중괄호가 도로 드러난다.
        // 보이기만 옮긴다 - host.caret 자체는 건드리지 않는다(입력 위치는 그대로여야 한다).
        let safe = caretCutOutsidePlaceholder(chars: chars, cut: cut)

        var out = String(chars[0..<safe]).templateAwareAttributed(theme: theme, font: .callout)
        out += caretGlyph
        out += String(chars[safe...]).templateAwareAttributed(theme: theme, font: .callout)
        return Text(out)
    }

    /// 캐럿이 `{…}` 안이면 그 칸의 끝으로 밀어 낸다(그리기용).
    private func caretCutOutsidePlaceholder(chars: [Character], cut: Int) -> Int {
        var openedAt: Int?
        for (i, c) in chars.enumerated() {
            if c == "{" { openedAt = i }
            else if c == "}" {
                if let open = openedAt, cut > open, cut <= i { return i + 1 }
                openedAt = nil
            }
        }
        return cut
    }

    /// 캐럿 한 획. 그리는 곳이 두 군데(빈칸일 때 · 글자가 있을 때)라 모양을 여기 한 곳에 둔다.
    private var caretGlyph: AttributedString {
        var caret = AttributedString("\u{258F}")
        caret.foregroundColor = .accentColor
        return caret
    }

    /// 빈칸 안내. 캐럿 뒤에 흐린 글씨로 붙는다.
    private var placeholderText: Text {
        var hint = AttributedString(NSLocalizedString("여기에 입력돼요",
                                                      comment: "In-app keyboard composer placeholder"))
        hint.foregroundColor = theme.textMuted
        return Text(caretGlyph + hint)
    }

}

// MARK: - 말풍선 모양

/// 꼬리가 달린 진짜 말풍선.
///
/// ⚠️ 예전에는 그냥 둥근 사각형이었다. 둥근 사각형은 카드로도, 버튼으로도, 입력칸으로도
///    읽힌다 - 무대에서 이것이 **누가 건넨 말**이라는 걸 알려 주는 것이 없었다.
///    꼬리 하나가 붙으면 그 순간 대화가 된다.
///
/// ⚠️ 꼬리는 **말한 쪽을 가리킨다.** 받은 말은 왼쪽(프로필 쪽), 보낸 말은 오른쪽.
struct StageBubble: Shape {
    /// 꼬리가 왼쪽을 향하는가(= 받은 말풍선).
    let pointsLeft: Bool
    let radius: CGFloat

    /// 꼬리가 차지하는 가로 폭. 글자 여백도 이만큼 밀어 준다.
    static let tailWidth: CGFloat = 11

    func path(in rect: CGRect) -> Path {
        let t = Self.tailWidth
        // 몸통은 꼬리만큼 안쪽으로 물러난다.
        let body = CGRect(x: pointsLeft ? rect.minX + t : rect.minX,
                          y: rect.minY,
                          width: rect.width - t,
                          height: rect.height)
        let r = min(radius, min(body.width, body.height) / 2)

        var path = Path(roundedRect: body, cornerRadius: r, style: .continuous)

        // 꼬리 - 위쪽에 붙는 부드러운 부리. 풍선이 짧아도 밖으로 나가지 않게 높이로 묶는다.
        let top = min(rect.minY + 8, rect.maxY - 4)
        let bottom = min(rect.minY + 26, rect.maxY - 2)
        let tipY = (top + bottom) / 2 - 3
        let edgeX = pointsLeft ? body.minX : body.maxX
        let tipX = pointsLeft ? rect.minX : rect.maxX
        let ctrl = pointsLeft ? edgeX - t * 0.35 : edgeX + t * 0.35

        var tail = Path()
        tail.move(to: CGPoint(x: edgeX, y: top))
        tail.addQuadCurve(to: CGPoint(x: tipX, y: tipY),
                          control: CGPoint(x: ctrl, y: top - 1))
        tail.addQuadCurve(to: CGPoint(x: edgeX, y: bottom),
                          control: CGPoint(x: ctrl, y: tipY + 7))
        tail.closeSubpath()

        path.addPath(tail)
        return path
    }
}
