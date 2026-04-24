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
        let memo = loadSelectedMemo(configuration: configuration)
        let entry = FavoriteMemoEntry(date: Date(), memo: memo, configuration: configuration)

        // 15분마다 갱신
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
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
        ZStack {
            AccessoryWidgetBackground()
            if entry.memo != nil {
                Image(systemName: "doc.on.clipboard")
                    .font(.title2)
            } else {
                Image(systemName: "heart.slash")
                    .font(.title3)
            }
        }
        .widgetURL(copyURL)
    }

    // MARK: - 잠금화면: 직사각형
    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let memo = entry.memo {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                    Text(memo.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                Text(memo.value)
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
                Text(NSLocalizedString("메모를 즐겨찾기에 추가하세요", comment: "Add memo to favorites"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(copyURL)
    }

    // MARK: - 잠금화면: 인라인
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

    // MARK: - 홈화면: Small (widgetURL로 앱 실행 후 복사)
    private var systemSmallView: some View {
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
                            NSLocalizedString("탭하여 복사", comment: "Tap to copy widget"),
                            systemImage: "doc.on.doc"
                        )
                        .font(.caption2)
                        .foregroundStyle(.blue)
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
                    Text(NSLocalizedString("메모를 즐겨찾기에 추가하세요", comment: "Add memo to favorites"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .widgetURL(copyURL)
    }

    // MARK: - URL (잠금화면 위젯 탭 시 사용)

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
            NSLocalizedString("즐겨찾기 메모", comment: "Favorite memo widget name")
        )
        .description(
            NSLocalizedString("즐겨찾기 메모를 탭하여 바로 복사합니다. 메모를 왼쪽으로 밀어 즐겨찾기를 설정하세요.", comment: "Favorite memo widget description")
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
