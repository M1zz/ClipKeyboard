//
//  UsagePassportView.swift
//  ClipKeyboard
//
//  비자 페이지 - 지금까지 다시 치지 않은 자국을 여권처럼 보여준다.
//
//  이 화면의 목적은 자랑이 아니라 **공유하고 싶어지는 지점**을 하나 만드는 것이다.
//  (자발적 추천이 0건이면 이 앱은 비타민으로 전락한다 - docs/KILL_CRITERIA.md)
//
//  ⚠️ 전부 기기 안의 값만 쓴다. 새로 수집하는 것은 없다.
//  ⚠️ 공유 이미지에는 **숫자와 문구 제목만** 들어간다. 내용은 절대 넣지 않고,
//     보안 문구는 제목도 가린다(UsagePassport.displayLabel).
//

import SwiftUI
#if canImport(UIKit)
import LeeoKit
#endif

struct UsagePassportView: View {

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 지금 보고 있는 기간. **처음 열면 이번 달이다.**
    ///
    /// ⚠️ 예전에는 평생 누적만 보여줬다. 몇 달 쓴 사람에게 그 숫자는 크기만 하고
    ///    **지금 잘 쓰고 있는지**를 말해 주지 않는다. 이번 달이 먼저 보여야
    ///    "요즘도 도움이 되고 있나"에 답이 된다. 평생 누적은 골라서 본다.
    ///
    /// ⚠️ 이번 주가 첫 칸이지만 **기본값은 아니다.** 일 원장이 나중에 들어와서, 예전부터
    ///    쓰던 사람은 이번 주가 한동안 비어 있다. 열자마자 빈 화면을 띄우면 안 된다.
    @State private var period: RefundPeriod = .thisMonth
    @State private var summary: UsagePassport.Summary?
    /// 아낀 시간의 내역 - "왜 이만큼인가"를 펼쳐 보이는 데 쓴다.
    @State private var breakdown: TimeSavedModel.Breakdown = .zero
    /// 방금 새로 닿은 이정표. 있으면 축하 카드가 맨 위에 뜬다.
    @State private var milestone: SavedTimeMilestone?
    /// 영수증을 뽑은 순간. 발행 시각을 고정해야 시트에서 기간을 바꿔도 시각이 안 흔들린다.
    @State private var receiptRequest: ReceiptRequest?
    /// 영상 미리보기 시트에 넘길 거리. 굽는 일은 그 시트 안에서 한다
    /// - 여기서 구워 놓고 시트를 열면 버튼이 1~2초 죽은 것처럼 보인다.
    @State private var videoRequest: VideoRequest?

    private struct VideoRequest: Identifiable {
        let id = UUID()
        let totalSeconds: Double
        let totalUses: Int
    }

    private struct ReceiptRequest: Identifiable {
        let id = UUID()
        let issuedAt: Date
        let memos: [Memo]
        /// 화면에서 보던 기간 그대로 뽑는다 - 다른 기간의 종이가 나오면 딴 물건이 된다.
        let period: RefundPeriod
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let summary, summary.totalUses > 0 {
                    // 축하는 **맨 위**다. 아래에 두면 숫자를 보고 스크롤을 멈춘 사람이 못 본다.
                    if let milestone { celebration(milestone) }
                    periodPicker
                    header(summary)
                    groundsSection(summary)
                    shareVideoButton(summary)
                    receiptButton(summary)
                    stampsSection(summary)
                    footnote(summary)
                } else if period != .allTime {
                    // ⚠️ 이 기간에만 없는 것이지 **아무것도 없는 것이 아니다.**
                    //    빈 화면을 그대로 띄우면 몇 달 치 기록이 있는 사람도
                    //    "아무것도 안 했다"는 화면을 보게 된다.
                    periodPicker
                    emptyPeriodState
                } else {
                    emptyState
                }
            }
            .padding(20)
        }
        .background(theme.bg.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("사용 기록", comment: "Usage passport screen title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .sheet(item: $receiptRequest) { request in
            RefundReceiptSheet(memos: request.memos, issuedAt: request.issuedAt, period: request.period)
        }
        .sheet(item: $videoRequest) { request in
            ShareVideoSheet(totalSeconds: request.totalSeconds, totalUses: request.totalUses)
        }
    }

    // MARK: - 영수증 뽑기

    /// 영수증은 **버튼을 눌러야** 나온다. 화면에 항상 펼쳐두면 종이가 아니라 배경이 되고,
    /// 뽑는 동작이 없으면 "가지고 있다"는 감각도 생기지 않는다.
    private func receiptButton(_ summary: UsagePassport.Summary) -> some View {
        Button {
            HapticManager.shared.light()
            receiptRequest = ReceiptRequest(issuedAt: Date(),
                                            memos: (try? MemoStore.shared.load(type: .memo)) ?? [],
                                            period: period)
        } label: {
            HStack(spacing: 12) {
                VaultSpriteStrip(sprites: [.receipt], pixel: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("영수증 뽑기", comment: "Button: print refund receipt"))
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.text)
                    Text(NSLocalizedString("지금 보고 있는 기간을 한 장으로 뽑아요.", comment: "Button subtitle: refund receipt"))
                        .font(.caption)
                        .foregroundColor(theme.textMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: AppSymbol.chevronRight)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.textFaint)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                    .fill(theme.surface)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 친구들에게 알리기

    /// 아낀 시간을 세로 영상으로 만들어 **미리 보여준 뒤** 내보낸다.
    ///
    /// ⚠️ 이미지가 아니라 영상인 이유는 **자랑이 숫자가 아니라 숫자가 올라가는 장면에서**
    ///    생기기 때문이다. 멈춘 그림은 스크롤에 묻히고, 3초간 굴러 올라가는 숫자는 눈이 따라간다.
    ///
    /// ⚠️ 이름이 "자랑할 영상 만들기"였다. 그건 **우리가 주는 물건**의 이름이지 사람이
    ///    하려는 일의 이름이 아니다. 하려는 일은 친구들에게 알리는 것이고 영상은 그 수단이라,
    ///    버튼에는 하려는 일을 적는다.
    ///
    /// ⚠️ 여기서 굽지 않는다. 굽는 데 1~2초 걸리는데 그동안 버튼이 죽은 것처럼 보이면
    ///    사람은 한 번 더 누른다. 시트를 즉시 열고 **그 안에서** 굽는다.
    @ViewBuilder
    private func shareVideoButton(_ summary: UsagePassport.Summary) -> some View {
        if summary.timeSavedSeconds > 0 {
            Button {
                HapticManager.shared.light()
                videoRequest = VideoRequest(totalSeconds: summary.timeSavedSeconds,
                                            totalUses: summary.totalUses)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: AppSymbol.squareAndArrowUp)
                        .font(.title3.weight(.semibold))
                        .frame(width: 26, height: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("친구들에게 알리기", comment: "Button: tell friends"))
                            .font(.body.weight(.semibold))
                            .foregroundColor(theme.accentFg)
                        Text(NSLocalizedString("3초짜리 세로 영상으로 만들어 인스타 스토리에 바로 올려요.",
                                               comment: "Button subtitle: tell friends"))
                            .font(.caption)
                            .foregroundColor(theme.accentFg.opacity(0.8))
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                        .fill(theme.accent)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 머리말

    private func header(_ summary: UsagePassport.Summary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("다시 치지 않은 횟수", comment: "Usage passport: headline label"))
                .font(.caption.weight(.semibold))
                .kerning(0.8)
                .foregroundColor(theme.textMuted)

            Text(countText(summary.totalUses))
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundColor(theme.accent)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(Delight.motion(.once, reduceMotion: reduceMotion), value: summary.totalUses)

            if let saved = UsagePassport.timeSavedText(seconds: summary.timeSavedSeconds) {
                Text(String(format: NSLocalizedString("대략 %@을 아꼈어요.", comment: "Usage passport: time saved sentence"), saved))
                    .font(.body)
                    .foregroundColor(theme.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                .fill(theme.surface)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - 도장들

    @ViewBuilder
    private func stampsSection(_ summary: UsagePassport.Summary) -> some View {
        if !summary.stamps.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(NSLocalizedString("많이 쓴 문구", comment: "Usage passport: top shortcuts section"))
                    .font(.headline)
                    .foregroundColor(theme.text)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 10)], spacing: 10) {
                    ForEach(Array(summary.stamps.enumerated()), id: \.element.id) { index, stamp in
                        stampCard(stamp, index: index)
                    }
                }
            }
        }
    }

    private func stampCard(_ stamp: UsagePassport.Stamp, index: Int) -> some View {
        HStack(spacing: 10) {
            // 손으로 찍은 것처럼 카드마다 각도를 조금씩 흔든다(순서 기반이라 렌더마다 안 바뀐다).
            StampMark(useCount: stamp.useCount, size: 30, angle: [-9.0, 5.0, -3.0, 8.0][index % 4])

            VStack(alignment: .leading, spacing: 2) {
                Text(stamp.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.text)
                    .lineLimit(1)
                Text(String(format: NSLocalizedString("%d회", comment: "Usage count suffix"), stamp.useCount))
                    .font(.caption)
                    .foregroundColor(theme.textMuted)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                .fill(theme.surface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("%1$@, %2$d회 사용", comment: "Stamp card accessibility label"),
                                   stamp.label, stamp.useCount))
    }

    // MARK: - 꼬리말

    private func footnote(_ summary: UsagePassport.Summary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // ⚠️ 이 기간을 다 못 덮었으면 **먼저** 밝힌다. 아래 숫자가 작은 이유가
            //    안 써서가 아니라 아직 안 세서일 수 있다.
            if let started = summary.coverageStartedAt {
                Text(String(format: NSLocalizedString("%@부터 센 값이에요.", comment: "Usage passport: coverage note"),
                            coverageDateText(started)))
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
            }
            if summary.unusedShortcuts > 0 {
                Text(String(format: NSLocalizedString("아직 한 번도 안 쓴 문구가 %d개 있어요.", comment: "Usage passport: unused shortcuts hint"),
                            summary.unusedShortcuts))
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
            }
            Text(NSLocalizedString("이 숫자는 기기 안에서만 계산돼요. 어디에도 보내지 않아요.", comment: "Usage passport: privacy note"))
                .font(.footnote)
                .foregroundColor(theme.textFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 기간 고르기

    private var periodPicker: some View {
        Picker(NSLocalizedString("기간", comment: "Usage passport: period"), selection: $period) {
            // ⚠️ `allCases` 가 아니라 고르게 할 것만 둔다 - 지난달은 금고와 영수증에 있다.
            ForEach(RefundPeriod.selectable) { p in
                Text(p.localizedName).tag(p)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: period) { _, _ in reload() }
    }

    /// 고른 기간에만 기록이 없을 때. **전체로 가는 길을 함께 둔다.**
    private var emptyPeriodState: some View {
        VStack(spacing: 10) {
            Image(systemName: AppSymbol.calendar)
                .font(.largeTitle)
                .foregroundColor(theme.textFaint)
                .accessibilityHidden(true)
            Text(String(format: NSLocalizedString("%@에는 아직 쓴 기록이 없어요",
                                                  comment: "Usage passport: empty for this period"),
                        period.localizedName))
                .font(.body.weight(.semibold))
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)
            // ⚠️ 안 쓴 것과 아직 안 센 것은 다르다. 후자면 그렇다고 말한다.
            if let started = summary?.coverageStartedAt {
                Text(String(format: NSLocalizedString("%@부터 센 값이에요.", comment: "Usage passport: coverage note"),
                            coverageDateText(started)))
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
                    .multilineTextAlignment(.center)
            }
            Button {
                period = .allTime
            } label: {
                Text(NSLocalizedString("전체 기간 보기", comment: "Usage passport: see all time"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - 빈 상태

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: AppSymbol.tray)
                .font(.system(size: 44, weight: .light))
                .foregroundColor(theme.textFaint)
                .accessibilityHidden(true)
            Text(NSLocalizedString("아직 백지예요", comment: "Usage passport empty state title"))
                .font(.title3.weight(.bold))
                .foregroundColor(theme.text)
            Text(NSLocalizedString("키보드에서 문구를 한 번 쓰면 여기에 자국이 남기 시작해요.", comment: "Usage passport empty state body"))
                .font(.body)
                .foregroundColor(theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                .fill(theme.surface)
        )
    }

    // MARK: - 데이터

    /// "8월 17일" - 언제부터 센 값인지 밝힐 때 쓴다.
    private func coverageDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }

    private func countText(_ count: Int) -> String {
        String(format: NSLocalizedString("%d번", comment: "Usage passport: times count"), count)
    }

    private func reload() {
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        let saved = KeyboardUsageTracker.totalTimeSavedSeconds()
        summary = UsagePassport.summary(memos: memos, period: period, timeSavedSeconds: saved)
        // ⚠️ 셈의 내역은 **평생 것만** 남아 있다(합계만 쌓고 달별로 안 나눠 뒀다).
        //    그래서 기간을 좁혔을 때는 펼치지 않는다 - 위 숫자와 아래 내역이
        //    다른 기간을 말하면 그 화면은 거짓말이 된다.
        breakdown = period == .allTime ? KeyboardUsageTracker.savedBreakdown() : .zero

        // ⚠️ 화면을 열 때 확인하고, **본 즉시 지나간 것으로 적는다.** 다음에 또 띄우면
        //    축하가 아니라 배너가 된다.
        if let reached = SavedTimeMilestone.newlyReached(totalSeconds: saved) {
            milestone = reached
            SavedTimeMilestone.markReached(upTo: reached)
            // 어느 칸까지 갔는지만 남긴다 - 초는 보내지 않는다.
            AnalyticsService.log(.timeSavedMilestone, parameters: [.source: reached.rawValue])
        }
    }

    // MARK: - 축하

    /// 새 이정표에 닿았을 때 한 번 뜨는 카드.
    ///
    /// ⚠️ 닫기 버튼을 두지 않는다. 이 카드는 다음에 열면 이미 없다 - 없앨 것을
    ///    없애는 버튼은 할 일만 하나 늘린다.
    private func celebration(_ milestone: SavedTimeMilestone) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: AppSymbol.checkmarkSealFill)
                .font(.system(size: 40))
                .foregroundColor(theme.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.localizedTitle)
                    .font(.headline)
                    .foregroundColor(theme.text)
                Text(milestone.localizedComparison)
                    .font(.subheadline)
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                .fill(theme.accentSoft)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
        .accessibilityElement(children: .combine)
    }

    // MARK: - 근거

    /// "왜 이만큼인가" - 아낀 시간을 세 조각으로 펼쳐 보인다.
    ///
    /// ⚠️ 이 자리가 이 화면에서 **가장 중요하다.** 큰 숫자 하나만 있으면 사람은 그 숫자를
    ///    안 믿는다(믿을 근거가 없으니까). 무엇을 어떻게 셌는지 보여야 "이건 좀 후하네"
    ///    라고 판단할 수 있고, 판단할 수 있어야 비로소 그 숫자를 자기 것으로 받아들인다.
    ///
    /// ⚠️ 내역이 합계보다 작을 수 있다. 이 모델이 들어오기 전에 쌓인 시간에는 내역이
    ///    없기 때문이다. 그래서 **비율이 아니라 각 조각의 크기**를 그대로 적는다.
    ///
    /// ⚠️ 뺀 줄(이 앱을 쓰느라 든 시간)도 함께 적는다. 더한 줄만 보이던 때는 줄의 합이
    ///    위의 큰 숫자보다 늘 커서, 세어 보는 사람에게 셈이 틀린 것처럼 보였다.
    @ViewBuilder
    private func groundsSection(_ summary: UsagePassport.Summary) -> some View {
        let parts = breakdown
        let sum = parts.retrieval + parts.handling + parts.typing + parts.verification + parts.baseline
        if sum > 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("이 시간은 이렇게 셌어요", comment: "Usage passport: grounds header"))
                    .font(.caption.weight(.semibold))
                    .kerning(0.8)
                    .foregroundColor(theme.textMuted)

                groundRow(symbol: "magnifyingglass",
                          title: NSLocalizedString("찾아오지 않아도 된 시간", comment: "Grounds row: retrieval"),
                          note: NSLocalizedString("계좌·주소처럼 다른 앱을 열어 가져와야 했던 값이에요.",
                                                  comment: "Grounds note: retrieval"),
                          seconds: parts.retrieval)
                if parts.handling > 0 {
                    groundRow(symbol: "doc.on.clipboard",
                              title: NSLocalizedString("복사·붙여넣기 하지 않아도 된 시간", comment: "Grounds row: handling"),
                              note: NSLocalizedString("길게 눌러 선택하고, 복사하고, 돌아와서 붙여넣던 손놀림이에요.",
                                                      comment: "Grounds note: handling"),
                              seconds: parts.handling)
                }
                groundRow(symbol: "keyboard",
                          title: NSLocalizedString("치지 않아도 된 시간", comment: "Grounds row: typing"),
                          note: NSLocalizedString("손으로 옮겨 적었다면 걸렸을 시간이에요.",
                                                  comment: "Grounds note: typing"),
                          seconds: parts.typing)
                if parts.verification > 0 {
                    groundRow(symbol: "checkmark.circle",
                              title: NSLocalizedString("다시 읽지 않아도 된 시간", comment: "Grounds row: verification"),
                              note: NSLocalizedString("한 자만 틀려도 곤란한 숫자를 되짚어 보는 시간이에요.",
                                                      comment: "Grounds note: verification"),
                              seconds: parts.verification)
                }
                if parts.baseline > 0 {
                    groundRow(symbol: "arrow.up.to.line",
                              title: NSLocalizedString("꺼내 쓸 때마다 드는 기본값", comment: "Grounds row: baseline"),
                              note: NSLocalizedString("하던 일을 멈추고, 값을 어디서 가져올지 떠올리고, 넣고, 맞는지 보는 시간이에요. 아무리 짧아도 한 번에 30초는 잡았어요.",
                                                      comment: "Grounds note: baseline"),
                              seconds: parts.baseline)
                }
                // ⚠️ 뺀 것도 적는다. 더한 줄만 보이면 위의 큰 숫자와 아래 줄들의 합이 안 맞고,
                //    셈을 펼쳐 보이려고 만든 자리가 셈이 안 맞는다고 말하게 된다.
                if parts.tapCost > 0 {
                    groundRow(symbol: "minus.circle",
                              title: NSLocalizedString("이 앱을 쓰느라 든 시간", comment: "Grounds row: tap cost"),
                              note: NSLocalizedString("키보드를 올리고 키를 찾아 누르기까지, 한 번에 1초로 봤어요.",
                                                      comment: "Grounds note: tap cost"),
                              seconds: parts.tapCost,
                              isSubtracted: true)
                }

                kindCounts

                Text(NSLocalizedString("어림한 값이에요. 같은 문구를 잇달아 쓰면 찾아오는 시간은 한 번만 셉니다.",
                                       comment: "Usage passport: grounds disclaimer"))
                    .font(.caption)
                    .foregroundColor(theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                    .fill(theme.surface)
            )
        }
    }

    /// - Parameter isSubtracted: 더한 줄이 아니라 **뺀** 줄인가. 금액 앞에 빼기를 붙이고
    ///   색을 죽여, 훑어만 봐도 방향이 보이게 한다.
    private func groundRow(symbol: String,
                           title: String,
                           note: String,
                           seconds: Double,
                           isSubtracted: Bool = false) -> some View {
        let amount = UsagePassport.breakdownText(seconds: seconds)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundColor(isSubtracted ? theme.textFaint : theme.accent)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(isSubtracted ? theme.textMuted : theme.text)
                Text(note)
                    .font(.caption)
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(isSubtracted
                 ? String(format: NSLocalizedString("-%@", comment: "Grounds row: subtracted amount"), amount)
                 : amount)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundColor(isSubtracted ? theme.textMuted : theme.text)
        }
        .accessibilityElement(children: .combine)
    }

    /// 어떤 종류의 문구가 얼마나 일했나 - 횟수로 보여 준다.
    @ViewBuilder
    private var kindCounts: some View {
        let rows = TimeSavedModel.Kind.allCases
            .map { ($0, KeyboardUsageTracker.useCount(of: $0)) }
            .filter { $0.1 > 0 }
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Divider().padding(.vertical, 2)
                ForEach(rows, id: \.0) { kind, count in
                    HStack(spacing: 8) {
                        Text(kind.localizedName)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(theme.text)
                        Spacer(minLength: 8)
                        Text(String(format: NSLocalizedString("%d번", comment: "Use count suffix"), count))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(theme.textMuted)
                    }
                }
            }
        }
    }
}

// MARK: - 공유 시트

/// 파일 하나를 시스템 공유 시트에 넘긴다.
///
/// ⚠️ `ShareLink` 를 쓰지 않는다. 그건 누를 때 이미 물건이 있어야 하는데, 영상은
///    누른 뒤에 만들어진다. 다 만든 다음 이 시트를 띄우는 편이 순서가 맞다.
///
/// ⚠️ 영상 파일을 넘기면 스토리에 올릴 수 있는 앱들이 시트에 나타난다. 우리가 특정
///    앱을 직접 열지 않는다 - 어디에 올릴지는 사용자가 고를 일이다.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
