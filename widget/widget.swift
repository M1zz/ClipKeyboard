//
//  widget.swift
//  widget
//
//  Created by hyunho lee on 2/1/26.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Provider

struct FavoriteMemoProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> FavoriteMemoEntry {
        FavoriteMemoEntry(
            date: Date(),
            memo: nil,
            configuration: SelectMemoIntent()
        )
    }

    func snapshot(for configuration: SelectMemoIntent, in context: Context) async -> FavoriteMemoEntry {
        let memo = loadSelectedMemo(configuration: configuration)
        return FavoriteMemoEntry(date: Date(), memo: memo, configuration: configuration)
    }

    func timeline(for configuration: SelectMemoIntent, in context: Context) async -> Timeline<FavoriteMemoEntry> {
        let now = Date()
        let memo = loadSelectedMemo(configuration: configuration)
        let copied = memo.map { CopyFeedback.justCopied(memoID: $0.id.uuidString, now: now) } ?? false

        // 방금 복사했으면 **두 칸**을 만든다 - 지금은 "복사됨", 잠시 뒤 원래 모습으로.
        // 한 칸만 두면 확인 문구가 다음 갱신(15분)까지 남아 거짓말이 된다.
        var entries = [FavoriteMemoEntry(date: now, memo: memo, configuration: configuration, justCopied: copied)]
        if copied {
            let revertAt = now.addingTimeInterval(CopyFeedback.window)
            entries.append(FavoriteMemoEntry(date: revertAt, memo: memo, configuration: configuration))
        }

        // 15분마다 갱신
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
        return Timeline(entries: entries, policy: .after(nextUpdate))
    }

    private func loadSelectedMemo(configuration: SelectMemoIntent) -> WidgetMemo? {
        if let selectedMemo = configuration.memo {
            return SharedMemoLoader.loadMemo(id: UUID(uuidString: selectedMemo.id) ?? UUID())
        }
        // 선택 없으면 첫 번째 즐겨찾기 메모 자동 선택
        return SharedMemoLoader.loadFavoriteMemos().first
    }
}

// MARK: - Timeline Entry

struct FavoriteMemoEntry: TimelineEntry {
    let date: Date
    let memo: WidgetMemo?
    let configuration: SelectMemoIntent
    /// 방금 복사했는가 - 위젯은 토스트를 띄울 수 없어 잠깐 문구를 바꿔 알린다.
    var justCopied: Bool = false
}

// MARK: - Widget Views

struct FavoriteMemoWidgetView: View {
    var entry: FavoriteMemoEntry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryRectangular:
            accessoryRectangularView
        case .accessoryInline:
            accessoryInlineView
        case .systemSmall:
            systemSmallView
        default:
            systemSmallView
        }
    }

    // MARK: - 잠금화면: 원형
    private var accessoryCircularView: some View {
        copyTap {
            ZStack {
                AccessoryWidgetBackground()
                if entry.justCopied {
                    Image(systemName: "checkmark")
                        .font(.title2)
                } else if entry.memo != nil {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title2)
                } else {
                    Image(systemName: "heart.slash")
                        .font(.title3)
                }
            }
        }
    }

    // MARK: - 잠금화면: 직사각형
    private var accessoryRectangularView: some View {
        copyTap { rectangularContent }
    }

    private var rectangularContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let memo = entry.memo {
                HStack(spacing: 4) {
                    Image(systemName: entry.justCopied ? "checkmark.circle.fill" : "heart.fill")
                        .font(.caption2)
                    Text(memo.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                Text(entry.justCopied
                     ? NSLocalizedString("복사됨", comment: "Widget: copied confirmation")
                     : memo.value)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "heart.slash")
                        .font(.caption2)
                    Text(NSLocalizedString("즐겨찾기 없음", comment: "No favorites widget"))
                        .font(.headline)
                }
                Text(NSLocalizedString("단축어를 즐겨찾기에 추가하세요", comment: "Add memo to favorites"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 잠금화면: 인라인
    // ⚠️ 인라인은 글자 한 줄만 허용해 버튼을 얹을 수 없다 - 여기만 앱을 여는 방식으로 남는다.
    private var accessoryInlineView: some View {
        Group {
            if let memo = entry.memo {
                Label(memo.title, systemImage: "heart.fill")
            } else {
                Label(
                    NSLocalizedString("즐겨찾기 없음", comment: "No favorites widget"),
                    systemImage: "heart.slash"
                )
            }
        }
        .widgetURL(copyURL)
    }

    // MARK: - 홈화면: Small (탭하면 그 자리에서 복사)
    private var systemSmallView: some View {
        copyTap { smallContent }
    }

    private var smallContent: some View {
        Group {
            if let memo = entry.memo {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.pink)
                        Text(memo.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }

                    Text(memo.value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    Spacer()

                    HStack {
                        Spacer()
                        Label(
                            entry.justCopied
                                ? NSLocalizedString("복사됨", comment: "Widget: copied confirmation")
                                : NSLocalizedString("탭하여 복사", comment: "Tap to copy widget"),
                            systemImage: entry.justCopied ? "checkmark.circle.fill" : "doc.on.doc"
                        )
                        .font(.caption2)
                        .foregroundStyle(entry.justCopied ? .green : .blue)
                    }
                }
            } else {
                // 즐겨찾기 없는 상태
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "heart.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(NSLocalizedString("즐겨찾기 없음", comment: "No favorites widget"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(NSLocalizedString("단축어를 즐겨찾기에 추가하세요", comment: "Add memo to favorites"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .widgetURL(copyURL)
    }

    // MARK: - 탭 동작

    /// 값이 있으면 **앱을 열지 않고 그 자리에서** 복사한다.
    ///
    /// ⚠️ 예전에는 `widgetURL` 로 앱을 띄운 뒤 복사했다. 계좌번호 하나 붙여넣자고
    ///    하던 일에서 튕겨 나갔다 돌아와야 했으니, 앱을 직접 여는 것과 별 차이가 없었다.
    ///
    /// 즐겨찾기가 없을 때만 앱을 연다 - 그때는 만들러 가야 하니 앱이 맞다.
    @ViewBuilder
    private func copyTap<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if let memo = entry.memo, !memo.isSecure {
            Button(intent: CopyMemoValueIntent(memoID: memo.id.uuidString)) {
                content()
            }
            .buttonStyle(.plain)
        } else {
            content().widgetURL(copyURL)
        }
    }

    // MARK: - URL (버튼을 못 얹는 인라인 위젯·즐겨찾기 없음 상태에서만)

    private var copyURL: URL? {
        if let memo = entry.memo {
            return URL(string: "clipkeyboard://copy?id=\(memo.id.uuidString)")
        }
        return URL(string: "clipkeyboard://")
    }
}

// MARK: - Widget Definition

struct FavoriteMemoWidget: Widget {
    let kind: String = "FavoriteMemoWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectMemoIntent.self,
            provider: FavoriteMemoProvider()
        ) { entry in
            FavoriteMemoWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(
            NSLocalizedString("즐겨찾기 단축어", comment: "Favorite memo widget name")
        )
        .description(
            NSLocalizedString("즐겨찾기 단축어를 탭하여 바로 복사합니다. 단축어를 왼쪽으로 밀어 즐겨찾기를 설정하세요.", comment: "Favorite memo widget description")
        )
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .systemSmall
        ])
    }
}

// MARK: - Preview

#Preview(as: .accessoryRectangular) {
    FavoriteMemoWidget()
} timeline: {
    FavoriteMemoEntry(
        date: .now,
        memo: WidgetMemo.preview,
        configuration: SelectMemoIntent()
    )
    FavoriteMemoEntry(
        date: .now,
        memo: nil,
        configuration: SelectMemoIntent()
    )
}

// MARK: - Preview Helper

extension WidgetMemo {
    static var preview: WidgetMemo? {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","title":"계좌번호","value":"110-123-456789","isFavorite":true,"lastEdited":"2026-01-01T00:00:00Z","category":"계좌번호","isSecure":false}
        """
        return try? JSONDecoder().decode(WidgetMemo.self, from: json.data(using: .utf8)!)
    }
}
