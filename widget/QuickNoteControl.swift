//
//  QuickNoteControl.swift
//  widget
//
//  Control Center / 잠금화면 컨트롤 - 탭하면 ClipKeyboard 를 열어 빠른 메모 입력 시트를 띄운다.
//  애플 "빠른 메모"처럼 앱을 일일이 찾지 않고 어디서든 바로 캡처를 시작하게 한다.
//
//  ⚠️ 동작 원리 (iOS 26 - 자세한 트러블슈팅 기록은 docs/engineering/CONTROL_CENTER_APP_LAUNCH.md):
//  1. 포그라운드 모드 인텐트는 위젯 프로세스가 아니라 "메인 앱 프로세스"에서 실행된다.
//     따라서 이 인텐트와 동일한 타입이 앱 타겟(ClipKeyboard/App/QuickNoteControlIntent.swift)에도
//     반드시 존재해야 한다. 없으면 시스템이 실행 대상을 못 찾아 탭이 조용히 무시된다.
//  2. iOS 26 SDK 부터 openAppWhenRun 은 deprecated - supportedModes(.foreground)가 대체.
//  3. 화면 라우팅은 App Group 보류 플래그 + NotificationCenter 로 한다
//     (ClipKeyboardList 가 onAppear/didBecomeActive 에서 소비, 멱등).
//

import WidgetKit
import SwiftUI
import AppIntents
import os

/// 위젯 익스텐션은 print가 Console에 안 잡힘 - Console.app에서
/// subsystem:com.Ysoup.TokenMemo.widget 필터로 확인.
private let controlLog = Logger(subsystem: "com.Ysoup.TokenMemo.widget", category: "control")

/// 제어센터 컨트롤용 인텐트 (위젯 타겟 측 정의).
/// ⚠️ 앱 타겟의 ClipKeyboard/App/QuickNoteControlIntent.swift 와 타입명·동작을 항상 일치시킬 것.
/// 실제 포그라운드 실행은 앱 쪽 정의로 이뤄진다.
@available(iOS 18.0, *)
struct AddQuickNoteControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Note"
    static var description = IntentDescription("Capture a quick note into ClipKeyboard.")

    // iOS 26: openAppWhenRun 은 deprecated - supportedModes 가 대체.
    // supportedModes 미선언 인텐트는 백그라운드 전용 취급돼 앱 열기가 조용히 무시된다.
    static var supportedModes: IntentModes { .foreground }

    @MainActor
    func perform() async throws -> some IntentResult {
        controlLog.info("🎛️ [QuickNoteControl] perform, 보류 플래그 기록 후 앱 오픈")
        AppGroup.defaults?.set(true, forKey: DefaultsKey.pendingQuickNoteAdd)
        return .result()
    }
}

@available(iOS 18.0, *)
struct QuickNoteControl: ControlWidget {
    // 예전 kind(QuickNoteInboxControl)는 인텐트 타입 변경 이력 때문에 시스템이
    // 죽은 등록 정보를 캐시하고 있어 탭해도 인텐트가 실행되지 않았다.
    // 인텐트 시그니처가 바뀔 때마다 kind 를 올려 완전히 새로 등록한다
    // (기존에 추가된 버튼은 제거 후 재추가 필요).
    static let kind = "com.Ysoup.TokenMemo.QuickNoteControl.v4"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: AddQuickNoteControlIntent()) {
                Label("Quick Note", systemImage: "note.text.badge.plus")
            }
        }
        .displayName("Quick Note")
        .description("Capture a quick note into ClipKeyboard.")
    }
}

// MARK: - 빠른 메모 잠금화면/홈 위젯 - widgetURL 경로로 앱을 연다
// (컨트롤과 별개의 안정 진입점. 위젯 탭 → 앱 열기는 어떤 iOS 버전에서도 동작.)
struct QuickNoteWidgetEntry: TimelineEntry {
    let date: Date
}

struct QuickNoteWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickNoteWidgetEntry { .init(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (QuickNoteWidgetEntry) -> Void) {
        completion(.init(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickNoteWidgetEntry>) -> Void) {
        completion(Timeline(entries: [.init(date: .now)], policy: .never))
    }
}

struct QuickNoteWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .systemSmall {
                VStack(spacing: 6) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.title)
                    Text(NSLocalizedString("메모", comment: "Quick note widget title"))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            } else {
                // 잠금 화면(circular): 아이콘만
                Image(systemName: "note.text.badge.plus")
                    .font(.title2)
            }
        }
        .widgetURL(URL(string: "clipkeyboard://quicknote"))
    }
}

struct QuickNoteLockWidget: Widget {
    let kind: String = "QuickNoteLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickNoteWidgetProvider()) { _ in
            QuickNoteWidgetView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(NSLocalizedString("메모", comment: "Quick note widget title"))
        .description(NSLocalizedString("메모 담기", comment: "Menu: add quick note to inbox"))
        .supportedFamilies([.accessoryCircular, .systemSmall])
    }
}
