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

    @State private var summary: UsagePassport.Summary?
    /// 영수증을 뽑은 순간. 발행 시각을 고정해야 시트에서 기간을 바꿔도 시각이 안 흔들린다.
    @State private var receiptRequest: ReceiptRequest?

    private struct ReceiptRequest: Identifiable {
        let id = UUID()
        let issuedAt: Date
        let memos: [Memo]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let summary, summary.totalUses > 0 {
                    header(summary)
                    receiptButton(summary)
                    stampsSection(summary)
                    footnote(summary)
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
            RefundReceiptSheet(memos: request.memos, issuedAt: request.issuedAt)
        }
    }

    // MARK: - 영수증 뽑기

    /// 영수증은 **버튼을 눌러야** 나온다. 화면에 항상 펼쳐두면 종이가 아니라 배경이 되고,
    /// 뽑는 동작이 없으면 "가지고 있다"는 감각도 생기지 않는다.
    private func receiptButton(_ summary: UsagePassport.Summary) -> some View {
        Button {
            HapticManager.shared.light()
            receiptRequest = ReceiptRequest(issuedAt: Date(),
                                            memos: (try? MemoStore.shared.load(type: .memo)) ?? [])
        } label: {
            HStack(spacing: 12) {
                VaultSpriteStrip(sprites: [.receipt], pixel: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("영수증 뽑기", comment: "Button: print refund receipt"))
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.text)
                    Text(NSLocalizedString("돌려받은 시간을 한 장으로 저장해 두세요.", comment: "Button subtitle: refund receipt"))
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

    // MARK: - 빈 상태

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            MascotView(pose: .sleeping, size: 64)
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

    private func countText(_ count: Int) -> String {
        String(format: NSLocalizedString("%d번", comment: "Usage passport: times count"), count)
    }

    private func reload() {
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        summary = UsagePassport.summary(
            memos: memos,
            timeSavedSeconds: KeyboardUsageTracker.totalTimeSavedSeconds()
        )
    }
}
