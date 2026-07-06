//
//  QuickNoteControlIntent.swift
//  ClipKeyboard
//
//  제어센터 Quick Note 컨트롤의 인텐트 — 위젯 타겟(QuickNoteControl.swift)에 같은 타입이 있다.
//  포그라운드 모드 인텐트는 시스템이 메인 앱 프로세스에서 실행하므로, 앱 타겟에도 동일 타입이
//  등록돼 있어야 컨트롤 탭이 앱을 열 수 있다(인터랙티브 위젯 인텐트의 양쪽 타겟 포함 관행과 동일).
//

import AppIntents
import Foundation

struct AddQuickNoteControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Note"
    static var description = IntentDescription("Capture a quick note into ClipKeyboard.")

    // iOS 26: openAppWhenRun 은 deprecated — supportedModes 가 대체.
    // .foreground = 실행 시 앱을 포그라운드로 가져온다.
    static var supportedModes: IntentModes { .foreground }

    @MainActor
    func perform() async throws -> some IntentResult {
        print("🎛️ [AddQuickNoteControlIntent] 앱 프로세스에서 실행 — 빠른 메모 시트 요청")
        // 콜드 런치 대비 보류 플래그 + 이미 떠 있는 리스트 대비 알림, 양쪽 모두 건다.
        // (플래그는 ClipKeyboardList 가 onAppear/didBecomeActive 에서 소비하며 멱등)
        UserDefaults(suiteName: AppGroup.identifier)?.set(true, forKey: DefaultsKey.pendingQuickNoteAdd)
        NotificationCenter.default.post(name: .openQuickNoteAdd, object: nil)
        return .result()
    }
}
