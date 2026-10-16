//
//  CaptureClipboardControl.swift
//  widget
//
//  제어 센터 · 잠금 화면 · **동작 버튼**의 '클립보드 담기'. 누르면 클립키보드가 열리고,
//  방금 복사한 글이 키보드 '최근'에 바로 담긴다. 설정하는 법은 앱의 `ActionButtonGuideView`.
//
//  ⚠️ 앱 타겟(ClipKeyboard/App/CaptureClipboardIntent.swift)에 **같은 타입**이 있다. 타입명 · 동작을 맞춘다.
//     포그라운드 인텐트는 메인 앱 프로세스에서 실행되므로, 앱 쪽 정의가 없으면 탭이 조용히 무시된다.
//     기록: docs/engineering/CONTROL_CENTER_APP_LAUNCH.md
//  ⚠️ 인텐트 시그니처가 바뀌면 `kind` 의 버전을 올린다(시스템이 죽은 등록을 캐시한다).
//

import WidgetKit
import SwiftUI
import AppIntents
import os

private let captureLog = Logger(subsystem: "com.Ysoup.TokenMemo.widget", category: "control")

/// 위젯 타겟 쪽 정의. 실제 실행은 앱 쪽 정의로 이뤄진다.
struct CaptureClipboardIntent: AppIntent {
    static var title: LocalizedStringResource {
        LocalizedStringResource("클립보드 담기", comment: "Capture clipboard intent / control title")
    }
    static var description: IntentDescription {
        IntentDescription(LocalizedStringResource("방금 복사한 글을 키보드 '최근'에 바로 담습니다.",
                                                  comment: "Capture clipboard intent description"))
    }

    static var supportedModes: IntentModes { .foreground }

    @MainActor
    func perform() async throws -> some IntentResult {
        captureLog.info("🎛️ [CaptureClipboardControl] perform, 보류 플래그 기록 후 앱 오픈")
        AppGroup.defaults?.set(true, forKey: DefaultsKey.pendingClipboardCapture)
        return .result()
    }
}

struct CaptureClipboardControl: ControlWidget {
    static let kind = "com.Ysoup.TokenMemo.CaptureClipboardControl.v1"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: CaptureClipboardIntent()) {
                Label(LocalizedStringResource("클립보드 담기", comment: "Capture clipboard intent / control title"),
                      systemImage: "doc.on.clipboard")
            }
        }
        .displayName(LocalizedStringResource("클립보드 담기", comment: "Capture clipboard intent / control title"))
        .description(LocalizedStringResource("방금 복사한 글을 키보드 '최근'에 바로 담습니다.",
                                             comment: "Capture clipboard intent description"))
    }
}
