//
//  ClipboardCaptureCard.swift
//  ClipKeyboard
//

import SwiftUI
import LeeoKit

/// 감지 타입 → 메모 제목(키) 자동 제안.
/// 이 앱의 핵심 루프는 "키(제목) 저장 → 탭하면 값 복사"이므로,
/// 복사한 내용의 타입에서 키를 추론해 제목 입력 마찰을 없앤다.
extension ClipboardItemType {
    /// "내 이메일", "내 계좌번호" 처럼 재사용 맥락의 제목을 제안한다.
    /// 개인 데이터성 타입은 "내 %@", 그 외(링크·송장 등)는 타입명 그대로.
    var suggestedMemoTitle: String {
        switch self {
        case .text, .image, .url, .trackingNumber, .confirmationCode,
             .declarationNumber, .ipAddress, .vehiclePlate, .medicalRecord:
            return localizedName
        default:
            return String(format: NSLocalizedString("내 %@", comment: "Suggested memo title: My <type>"), localizedName)
        }
    }
}

/// 상단 인라인 캡처 카드: 방금 복사한 클립보드를 한 탭으로 메모로 저장.
/// 제목(키)은 감지 타입에서 자동 제안되어, 별도 입력 없이 바로 저장된다.
struct ClipboardCaptureCard: View {

    @Environment(\.appTheme) private var theme

    let value: String
    let detectedType: ClipboardItemType
    let confidence: Double
    /// 자동 제안된 제목(키) - 원탭 저장 시 그대로 사용.
    let suggestedTitle: String
    /// 최근 7일 안에 이 글을 복사한 횟수(`RepeatCopyLedger`). 2 이상이면 한 줄로 짚어 준다.
    var repeatCopies: Int = 0
    let onDismiss: () -> Void
    /// 한 탭 즉시 저장 (제안된 제목으로).
    let onSaveDirect: () -> Void
    /// "편집"으로 진입 - 카드만 닫고 MemoAdd로 이동.
    let onEditTap: () -> Void
    /// "편집" 을 세우는가. 화면 이동 틀 밖(키보드 탭의 무대)에서는 갈 곳이 없어 뺀다.
    var showsEdit: Bool = true
    /// 이 시간이 지나면 저절로 사라진다. 그동안 테두리를 따라 선이 줄어든다.
    var lifetime: TimeInterval = ClipboardCaptureCard.defaultLifetime
    /// 시간이 다 됐다. 부르는 쪽이 "닫기" 와 같게 처리한다.
    var onTimeout: () -> Void = {}

    /// 떠 있는 시간(사용자 요청 2026-10-18: 10초 지나면 그냥 사라지게).
    static let defaultLifetime: TimeInterval = 10

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn
    /// 세기 시작한 때. 테두리 선의 길이는 여기서 지난 시간으로 매 프레임 계산한다.
    ///
    /// ⚠️ `withAnimation` 으로 1 → 0 을 걸지 않는다. 카드가 화면에 그려지기 전에 걸린 애니메이션은
    ///    SwiftUI 가 건너뛰어 선이 처음부터 0 이었다(실측: 선이 아예 안 보였다).
    @State private var startedAt: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            typeIcon

            VStack(alignment: .leading, spacing: 6) {
                headerRow
                if repeatCopies >= RepeatCopyLedger.Threshold.repeatCopies {
                    repeatRow
                }
                preview
                suggestedTitleRow
                actionRow
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMd)
                .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
        )
        // 남은 시간. 테두리를 따라 은은한 선이 줄어든다. 시계처럼 읽히지 않게 숫자는 두지 않는다.
        .overlay {
            if counts && !reduceMotion, let startedAt {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(startedAt)
                    RoundedRectangle(cornerRadius: theme.radiusMd)
                        .trim(from: 0, to: max(0, 1 - elapsed / lifetime))
                        .stroke(Color.accentColor.opacity(0.55),
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        // 글이 바뀌면(새로 복사하고 왔으면) 처음부터 다시 센다.
        .task(id: value) { await countDown() }
    }

    /// 저절로 사라지는가. VoiceOver 를 켠 사람에게는 카드가 읽는 도중에 없어지면 안 된다.
    private var counts: Bool { lifetime > 0 && !voiceOverOn }

    private func countDown() async {
        guard counts else { return }
        startedAt = Date()
        try? await Task.sleep(for: .seconds(lifetime))
        guard !Task.isCancelled else { return }
        onTimeout()
    }

    // MARK: - Subviews

    private var typeIcon: some View {
        Image(systemName: detectedType.icon)
            .font(.system(.body, weight: .semibold))
            .foregroundColor(Color.fromName(detectedType.color))
            .frame(width: 40, height: 40)
            .background(Color.fromName(detectedType.color).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm))
            .accessibilityHidden(true)
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Text(NSLocalizedString("Just copied", comment: "Inline capture card: just copied hint"))
                .font(.body.weight(.semibold))
                .foregroundColor(theme.textMuted)

            Text(detectedType.localizedName)
                .font(.body.weight(.semibold))
                .foregroundColor(Color.fromName(detectedType.color))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.fromName(detectedType.color).opacity(0.15))
                .clipShape(Capsule())

            if confidence > 0.8 {
                Image(systemName: AppSymbol.sparkles)
                    .font(.system(.caption2))
                    .foregroundColor(.yellow)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 0)
        }
    }

    /// "이번 주에 n번째 복사한 글이에요" - 한 번 보고 말 글과 저장할 글을 가른다.
    private var repeatRow: some View {
        Label(String(format: NSLocalizedString("이번 주에 %d번째 복사한 글이에요",
                                               comment: "Clipboard capture card: the same text was copied N times within 7 days"),
                     repeatCopies),
              systemImage: AppSymbol.clockArrowCirclepath)
            .font(.footnote.weight(.semibold))
            .foregroundColor(theme.accent)
    }

    private var preview: some View {
        Text(value)
            .font(.body)
            .foregroundColor(theme.text)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 자동 제안된 제목(키)을 칩으로 노출 - 무엇으로 저장될지 미리 보여준다.
    private var suggestedTitleRow: some View {
        HStack(spacing: 6) {
            Text(NSLocalizedString("제목", comment: "Label: memo title (key)"))
                .font(.caption.weight(.medium))
                .foregroundColor(theme.textFaint)

            HStack(spacing: 4) {
                Image(systemName: AppSymbol.keyFill)
                    .font(.system(.caption2))
                    .accessibilityHidden(true)
                Text(suggestedTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.10))
            .clipShape(Capsule())

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(format: NSLocalizedString("제안된 제목 %@", comment: "VoiceOver: suggested title"), suggestedTitle)
        )
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            // 한 탭 즉시 저장 - 제안된 제목으로 바로 메모 생성.
            Button(action: onSaveDirect) {
                HStack(spacing: 4) {
                    Image(systemName: AppSymbol.plusCircleFill)
                        .font(.body)
                        .accessibilityHidden(true)
                    Text(NSLocalizedString("단축어로 저장", comment: "Inline capture card: save as memo (one tap)"))
                        .font(.body.weight(.semibold))
                }
                .foregroundColor(Color.accentForeground)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.accentColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.squish)
            .accessibilityHint(
                String(format: NSLocalizedString("%@ 제목으로 바로 저장", comment: "VoiceOver hint: save with suggested title"), suggestedTitle)
            )

            // 제목을 바꾸고 싶을 때만 - 편집 화면으로.
            if showsEdit {
            FoldLink {
                MemoAdd(insertedKeyword: suggestedTitle, insertedValue: value)
            } label: {
                Text(NSLocalizedString("편집", comment: "Inline capture card: edit before saving"))
                    .font(.body)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.squish)
            .simultaneousGesture(TapGesture().onEnded { onEditTap() })
            }

            Button(action: onDismiss) {
                Text(NSLocalizedString("Dismiss", comment: "Inline capture card: dismiss button"))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.squish)

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }
}

// MARK: - 목록 밖에서 같은 카드를 보이기

/// "방금 복사함" 카드를 **목록 밖(키보드 탭의 무대)** 에서도 보이게 하는 통로.
///
/// 클립보드를 읽고 저장하는 일은 목록의 뷰모델이 한다(`ClipKeyboardListViewModel.checkFreshClipboard`).
/// 목록은 무대 밑에 늘 깔려 있어 앱에 들어올 때마다 그 확인이 돈다. 무대는 여기서 결과만 본다.
///
/// ⚠️ 무대가 클립보드를 따로 읽지 않는다. 두 곳이 읽으면 iOS 의 "붙여넣기 허용?" 이 두 번 뜬다.
@MainActor
final class FreshClipboardOffer: ObservableObject {
    static let shared = FreshClipboardOffer()
    private init() {}

    struct Snapshot: Equatable {
        let value: String
        let detectedType: ClipboardItemType
        let confidence: Double
        let suggestedTitle: String
        let repeatCopies: Int
    }

    @Published private(set) var snapshot: Snapshot?
    private weak var owner: ClipKeyboardListViewModel?

    func update(from viewModel: ClipKeyboardListViewModel) {
        owner = viewModel
        let next: Snapshot? = viewModel.hasFreshClipboard ? Snapshot(
            value: viewModel.value,
            detectedType: viewModel.clipboardDetectedType,
            confidence: viewModel.clipboardConfidence,
            suggestedTitle: viewModel.suggestedClipboardTitle,
            repeatCopies: viewModel.clipboardRepeatCopies) : nil
        if next != snapshot { snapshot = next }
    }

    func save() { owner?.saveClipboardAsMemo() }
    func dismiss() { owner?.dismissClipboardCapture() }
}

#if DEBUG
struct ClipboardCaptureCard_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ClipboardCaptureCard(
                value: "example@test.com",
                detectedType: .email,
                confidence: 0.95,
                suggestedTitle: "내 이메일",
                onDismiss: {},
                onSaveDirect: {},
                onEditTap: {}
            )
            .padding()
        }
    }
}
#endif
