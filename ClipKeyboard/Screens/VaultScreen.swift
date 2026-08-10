//
//  VaultScreen.swift
//  ClipKeyboard
//
//  **금고** - 지금까지 쌓인 것을 여는 자리.
//
//  들어오면 금고가 닫혀 있다가 열린다. 왜 굳이 닫힌 걸 먼저 보여주나:
//  열려 있는 그림을 바로 띄우면 그냥 삽화지만, 열리는 걸 보면 **내 것을 여는 일**이 된다.
//
//  ⚠️ 안에 든 것은 그림이 아니라 **실제로 번 만큼**이다(`VaultSprite.openEmpty` + 잔고).
//     금괴를 스프라이트에 박아 넣으면 한 푼도 안 번 사람의 금고에도 금괴가 들어 있고,
//     그러면 이 화면 전체가 거짓말이 된다.
//

import SwiftUI
#if canImport(UIKit)
import LeeoKit
#endif

struct VaultScreen: View {

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isOpen = false
    @State private var savedSeconds: Double = 0
    @State private var thisMonth: Double = 0
    @State private var lastMonth: Double = 0
    @State private var receiptRequest: ReceiptRequest?

    private struct ReceiptRequest: Identifiable {
        let id = UUID()
        let issuedAt: Date
        let memos: [Memo]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                vault
                balance
                periods
                receiptButton
                footnote
            }
            .padding(20)
        }
        .background(theme.bg.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("금고", comment: "Vault screen title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear(perform: load)
        .sheet(item: $receiptRequest) { request in
            RefundReceiptSheet(memos: request.memos, issuedAt: request.issuedAt)
        }
    }

    // MARK: - 금고

    private var vault: some View {
        VaultInterior(savedSeconds: savedSeconds, isOpen: isOpen)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(NSLocalizedString("금고", comment: "Vault screen title"))
            .accessibilityValue(UsagePassport.timeSavedText(seconds: savedSeconds)
                                ?? NSLocalizedString("아직 비어 있어요", comment: "Vault button empty value"))
    }

    // MARK: - 잔고

    private var balance: some View {
        VStack(spacing: 6) {
            Text(NSLocalizedString("지금까지 쌓인 시간", comment: "Vault: balance label"))
                .font(.caption.weight(.semibold))
                .kerning(0.8)
                .foregroundColor(theme.textMuted)

            Text(UsagePassport.timeSavedText(seconds: savedSeconds)
                 ?? NSLocalizedString("아직 비어 있어요", comment: "Vault button empty value"))
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundColor(theme.accent)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                .fill(theme.surface)
        )
    }

    // MARK: - 기간

    private var periods: some View {
        HStack(spacing: 10) {
            periodCard(RefundPeriod.thisMonth.localizedName, seconds: thisMonth)
            periodCard(RefundPeriod.lastMonth.localizedName, seconds: lastMonth)
        }
    }

    private func periodCard(_ title: String, seconds: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(theme.textMuted)
            Text(RefundReceipt.durationText(seconds: seconds))
                .font(.headline)
                .foregroundColor(theme.text)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                .fill(theme.surface)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - 영수증

    private var receiptButton: some View {
        Button {
            HapticManager.shared.light()
            receiptRequest = ReceiptRequest(issuedAt: Date(),
                                            memos: (try? MemoStore.shared.load(type: .memo)) ?? [])
        } label: {
            HStack(spacing: 12) {
                VaultSpriteStrip(sprites: [.receipt], pixel: 3)
                Text(NSLocalizedString("영수증 뽑기", comment: "Button: print refund receipt"))
                    .font(.body.weight(.semibold))
                    .foregroundColor(theme.text)
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

    private var footnote: some View {
        Text(NSLocalizedString("기기 안에서만 계산돼요. 어디에도 보내지 않아요.", comment: "Vault: privacy note"))
            .font(.footnote)
            .foregroundColor(theme.textFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 데이터

    private func load() {
        savedSeconds = KeyboardUsageTracker.totalTimeSavedSeconds()

        let now = Date()
        thisMonth = RefundLedger.total(forMonthOf: now)
        if let previous = RefundPeriod.lastMonth.month(from: now) {
            lastMonth = RefundLedger.total(forMonthOf: previous)
        }

        // 닫힌 채로 잠깐 두었다가 연다. 동작 줄이기에서는 그냥 열린 채로 시작한다.
        if reduceMotion || !Delight.isEnabled {
            isOpen = true
        } else {
            isOpen = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { isOpen = true }
            }
        }
    }
}

// MARK: - 금고 속

/// 열린 금고와 그 **안에 실제로 쌓인 것**.
///
/// 내부 좌표는 `VaultSprite.interior` 하나만 본다 - 스프라이트를 고치면 여기도 따라 움직인다.
/// 숫자를 여기에 또 적으면 언젠가 동전이 벽을 뚫고 나온다.
struct VaultInterior: View {
    let savedSeconds: Double
    var isOpen: Bool = true

    /// 금고 한 칸의 크기(pt).
    var pixel: CGFloat = 11
    /// 동전 한 칸의 크기(pt).
    var coinPixel: CGFloat = 3

    private var side: CGFloat { CGFloat(VaultSprite.closed.size) * pixel }
    private var coinSide: CGFloat { CGFloat(VaultSprite.empty.size) * coinPixel }

    private var interior: CGRect {
        CGRect(x: CGFloat(VaultSprite.interior.x) * pixel,
               y: CGFloat(VaultSprite.interior.y) * pixel,
               width: CGFloat(VaultSprite.interior.width) * pixel,
               height: CGFloat(VaultSprite.interior.height) * pixel)
    }

    private var columns: Int { max(1, Int(interior.width / coinSide)) }
    private var rows: Int { max(1, Int(interior.height / coinSide)) }

    /// 금고에 담기는 것. 바닥부터 채우려고 큰 것이 아래로 가게 뒤집는다.
    private var stacked: [[VaultSprite]] {
        let plan = VaultLedger.plan(savedSeconds: savedSeconds, cap: columns * rows)
        guard plan != [.empty] else { return [] }
        return stride(from: 0, to: plan.count, by: columns)
            .map { Array(plan[$0..<min($0 + columns, plan.count)]) }
            .reversed()                       // 큰 액면이 바닥에 깔린다
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VaultSpriteStrip(sprites: [isOpen ? .openEmpty : .closed], pixel: pixel, gap: 0)

            if isOpen {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(stacked.enumerated()), id: \.offset) { _, row in
                        VaultSpriteStrip(sprites: row, pixel: coinPixel, gap: 0)
                    }
                }
                // 바닥부터 쌓이되 가로로는 가운데. leading 으로 두면 오른쪽에 빈 칸이
                // 몰려서 금고가 한쪽으로 기울어 보인다.
                .frame(width: interior.width, height: interior.height, alignment: .bottom)
                .offset(x: interior.minX, y: interior.minY)
                .transition(.opacity)
            }
        }
        .frame(width: side, height: side)
    }
}
