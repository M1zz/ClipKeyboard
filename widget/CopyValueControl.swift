//
//  CopyValueControl.swift
//  widget
//
//  **앱을 열지 않고** 미리 정해 둔 값을 클립보드에 넣는다 - 제어센터 버튼과 위젯 탭이 함께 쓴다.
//
//  왜 필요한가: 지금까지 위젯은 `widgetURL` 로 앱을 띄운 다음에야 복사했다. 계좌번호 하나
//  붙여넣자고 하던 일(카톡·폼 작성)에서 튕겨 나갔다가 돌아와야 했으니, 앱을 여는 것보다
//  겨우 한 걸음 빠른 정도였다. 복사는 앱을 열 이유가 없는 일이다.
//
//  ⚠️ **포그라운드 모드로 만들지 말 것.** `supportedModes` 를 선언하지 않으면 백그라운드
//     전용으로 취급되는데, 이 인텐트에는 그게 맞다. `.foreground` 를 붙이는 순간 앱이 떠서
//     이 기능의 존재 이유가 사라진다. (제어센터 인텐트 일반론은
//     docs/engineering/CONTROL_CENTER_APP_LAUNCH.md - 저건 **앱을 여는** 인텐트 이야기다)
//
//  ⚠️ 앱 타겟에 같은 타입을 두지 않는다. 앱 프로세스에서 실행될 일이 없기 때문이다.
//     (`AddQuickNoteControlIntent` 는 포그라운드라 앱 타겟에도 있어야 했다 - 사정이 다르다)
//
//  ⚠️ 보안 단축어는 복사하지 않는다. 값이 암호문이라 붙여넣어 봐야 쓸 수 없고,
//     잠금화면 위젯에서 잠금 해제 없이 꺼내지는 일도 없어야 한다.
//
//  ⚠️ **잠금화면에서의 의미가 달라졌다.** 예전에는 위젯을 눌러도 앱이 뜨느라 잠금 해제를
//     거쳐야 값이 복사됐다. 이제는 잠긴 채로도 복사된다 - 잠금화면 위젯을 둔 사람에게는
//     그게 요청받은 편의지만, 남이 잠긴 폰을 집어 들면 즐겨찾기 값을 클립보드에 담을 수는
//     있다는 뜻이기도 하다. 그래서 대상은 **사용자가 직접 즐겨찾기한 비보안 값**으로만 한정한다.
//     민감한 것은 보안 단축어로 두면 이 경로에 아예 오르지 않는다.
//

import AppIntents
import WidgetKit
import SwiftUI
import UIKit
import os

private let copyLog = Logger(subsystem: "com.Ysoup.TokenMemo.widget", category: "copy")

// MARK: - 복사 인텐트

struct CopyMemoValueIntent: AppIntent {
    static var title: LocalizedStringResource {
        LocalizedStringResource("값 복사", comment: "Copy value intent title")
    }
    static var description: IntentDescription {
        IntentDescription(LocalizedStringResource("미리 정해 둔 단축어의 값을 클립보드에 복사합니다.",
                                                  comment: "Copy value intent description"))
    }

    /// 단축어 식별자(UUID 문자열). 값을 그대로 들고 다니지 않는 이유:
    /// 앱에서 내용을 고치면 위젯이 낡은 값을 복사하게 된다. 누를 때 다시 읽는다.
    @Parameter(title: LocalizedStringResource("단축어", comment: "Copy value intent: memo parameter"))
    var memoID: String

    init() { self.memoID = "" }
    init(memoID: String) { self.memoID = memoID }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: memoID),
              let memo = SharedMemoLoader.loadMemo(id: uuid),
              !memo.isSecure,
              !memo.value.isEmpty else {
            copyLog.info("📋 [CopyValue] 복사할 값을 찾지 못함 (id=\(memoID, privacy: .public))")
            return .result()
        }

        UIPasteboard.general.string = memo.value
        CopyFeedback.record(memoID: memoID)
        // 위젯이 "복사됨"을 잠깐 보여줄 수 있게 다시 그리게 한다.
        WidgetCenter.shared.reloadAllTimelines()
        copyLog.info("📋 [CopyValue] 복사 완료")
        return .result()
    }
}

// MARK: - 방금 복사했다는 표시

/// 위젯은 토스트를 띄울 수 없다. 대신 방금 복사한 사실을 App Group 에 남겨 두고,
/// 다음 타임라인에서 잠깐 "복사됨"으로 보여줬다가 되돌린다.
enum CopyFeedback {
    /// 이 시간 안에 복사한 것만 "방금"으로 친다.
    static let window: TimeInterval = 3

    private static let key = "widget.lastCopiedAt"
    private static let idKey = "widget.lastCopiedMemoID"

    static func record(memoID: String) {
        let defaults = AppGroup.defaults
        defaults?.set(Date().timeIntervalSince1970, forKey: key)
        defaults?.set(memoID, forKey: idKey)
    }

    /// 이 단축어를 방금 복사했는가.
    static func justCopied(memoID: String, now: Date = Date()) -> Bool {
        let defaults = AppGroup.defaults
        guard defaults?.string(forKey: idKey) == memoID else { return false }
        let at = defaults?.double(forKey: key) ?? 0
        guard at > 0 else { return false }
        return now.timeIntervalSince1970 - at < window
    }
}

// MARK: - 제어센터 컨트롤

/// 어느 값을 복사할지 고르는 설정 - 제어센터 버튼을 길게 눌러 바꾼다.
@available(iOS 18.0, *)
struct CopyValueControlConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource {
        LocalizedStringResource("복사할 값 고르기", comment: "Copy value control configuration title")
    }

    /// 즐겨찾기만 고를 수 있다(`MemoOptionsProvider`) - "미리 정해 둔 값"이 곧 즐겨찾기다.
    @Parameter(title: LocalizedStringResource("단축어", comment: "Copy value control: memo parameter"),
               optionsProvider: MemoOptionsProvider())
    var memo: MemoEntity?
}

@available(iOS 18.0, *)
struct CopyValueControl: ControlWidget {
    /// ⚠️ 인텐트 시그니처가 바뀌면 이 문자열을 올릴 것 - 시스템이 죽은 등록을 캐시해
    ///    눌러도 아무 일이 안 일어나는 사고가 이 앱에서 이미 한 번 있었다
    ///    (QuickNoteControl 의 kind 가 v4 까지 간 이유).
    static let kind = "com.Ysoup.TokenMemo.CopyValueControl.v1"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: Self.kind,
                                      provider: Provider()) { value in
            ControlWidgetButton(action: CopyMemoValueIntent(memoID: value.id)) {
                Label(value.title, systemImage: "doc.on.clipboard")
            }
        }
        .displayName(LocalizedStringResource("값 복사", comment: "Copy value control display name"))
        .description(LocalizedStringResource("정해 둔 단축어의 값을 앱을 열지 않고 복사합니다.",
                                             comment: "Copy value control description"))
    }

    struct Value {
        let id: String
        let title: String
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: CopyValueControlConfiguration) -> Value {
            Value(id: configuration.memo?.id ?? "",
                  title: configuration.memo?.title ?? String(localized: "값 복사",
                                                             comment: "Copy value control display name"))
        }

        func currentValue(configuration: CopyValueControlConfiguration) async throws -> Value {
            // 고른 것이 없으면 첫 즐겨찾기로 - 버튼을 추가하자마자 쓸 수 있어야 한다.
            if let picked = configuration.memo {
                return Value(id: picked.id, title: picked.title)
            }
            guard let first = SharedMemoLoader.loadFavoriteMemos().first else {
                return Value(id: "", title: String(localized: "즐겨찾기 없음",
                                                   comment: "No favorites widget"))
            }
            return Value(id: first.id.uuidString, title: first.title)
        }
    }
}
