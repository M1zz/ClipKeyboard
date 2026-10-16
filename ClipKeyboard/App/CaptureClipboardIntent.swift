//
//  CaptureClipboardIntent.swift
//  ClipKeyboard
//
//  '클립보드 담기'. 동작 버튼 · 제어 센터 · 단축어 앱에서 누르면 앱이 열리고, 방금 복사한 글이
//  복사 기록(키보드 '최근' 탭)에 바로 담긴다(`ClipboardCapture`).
//
//  ⚠️ 위젯 타겟(widget/CaptureClipboardControl.swift)에 **같은 타입**이 있다. 타입명 · 동작을 맞춘다.
//     포그라운드 인텐트는 메인 앱 프로세스에서 실행되므로 앱 쪽에도 있어야 버튼이 앱을 연다.
//     기록: docs/engineering/CONTROL_CENTER_APP_LAUNCH.md
//
//  ⚠️ 클립보드는 여기서 읽지 않는다. 인텐트가 도는 순간 앱은 아직 앞에 없을 수 있고,
//     앞에 없는 앱이 클립보드를 읽으면 iOS 가 빈 값을 준다. 앱이 앞에 선 뒤 목록이 읽는다.
//

import AppIntents
import Foundation

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
        print("🎛️ [CaptureClipboardIntent] 앱 프로세스에서 실행, 클립보드 담기 요청")
        // 콜드 런치 대비 보류 플래그 + 이미 떠 있는 목록 대비 알림. 목록이 소비하며 멱등.
        AppGroup.defaults?.set(true, forKey: DefaultsKey.pendingClipboardCapture)
        NotificationCenter.postOnMain(name: .captureClipboard, object: nil)
        return .result()
    }
}
