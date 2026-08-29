//
//  LaunchGuard.swift
//  ClipKeyboard
//
//  런치가 끝까지 갔는지 지켜보고, 못 갔으면 다음 런치를 가볍게 만든다.
//
//  왜 필요한가: 런치 경로에는 **실기기에서만 도는 것들**이 줄지어 있다
//  (CloudKit 컨테이너, 백그라운드 작업 등록, MetricKit, iCloud 키값 저장소).
//  시뮬레이터는 그중 상당수를 조건부 컴파일로 건너뛰므로, 여기서 죽는 사고는
//  개발 중에 한 번도 안 보이다가 남의 기기에서만 터진다. 그리고 런치에서 죽는 앱은
//  같은 자리에서 계속 죽는다 - 사용자는 화면 한 장 못 본다.
//
//  Swift 트랩(강제 언래핑·인덱스 초과)이나 CloudKit 의 os_crash 는 do/catch 로 못 막는다.
//  그래서 **막는 대신 기억한다.**
//
//   ① 빵부스러기 - 지금 어느 단계인지 디스크에 남긴다. 죽으면 그 값이 그대로 남아,
//      다음 런치에 "직전에 어디서 죽었는지"를 알 수 있다(허브로도 한 번 보낸다).
//   ② 세이프 모드 - 직전 런치가 못 끝났으면 부가 기능을 통째로 쉰다. 데이터 무결성에
//      필요한 것만 돌리고 화면부터 띄운다.
//   ③ 격리 - 같은 단계가 되풀이해서 멈추면 그 단계는 **아예 시작하지 않는다.**
//      앱 버전이 바뀌면 격리를 풀고 다시 시도한다(새 빌드가 고쳤을 수 있으므로).
//
//  ⚠️ 격리 대상은 `optional` 단계뿐이다. 데이터 마이그레이션(`essential`)까지 건너뛰면
//     크래시는 멈춰도 사용자의 데이터가 변환되지 않은 채로 남는다. 그쪽은 계속 재시도하고
//     대신 로그를 크게 남긴다.
//

import Foundation

enum LaunchGuard {

    // MARK: - 단계

    /// 런치 단계 이름. 그대로 로그·통계에 실리므로 짧고 사람이 읽을 수 있게 둔다.
    /// (허브 이벤트는 `launch_incomplete:<stage>` 로 간다)
    enum Stage: String {
        /// 런치 시작 직후, 첫 단계에 들어가기 전.
        case begin = "begin"
        /// 새 설치 기본값 씨앗.
        case seed = "seed"
        /// 콤보/attached 모델 통합 마이그레이션.
        case comboMigration = "combo-migration"
        /// 백그라운드 새로고침 작업 등록(BGTaskScheduler).
        case backgroundTask = "background-task"
        /// TipKit 설정.
        case tips = "tips"
        /// 첫 화면(SwiftUI 가 `body` 를 처음 평가하는 구간).
        case firstFrame = "first-frame"
        /// 결제 권한·그랜드파더 판정.
        case entitlement = "entitlement"
        /// 익명 사용 통계 훅과 첫 전송.
        case analytics = "analytics"
        /// 원격 기능 플래그 조회.
        case remoteFlags = "remote-flags"
        /// MetricKit 진단 구독.
        case diagnostics = "diagnostics"
        /// 저장 파일 마이그레이션 묶음(심볼·한국어·보안메모·샘플).
        case dataMigrations = "data-migrations"
        /// iCloud 백업 서비스 기동.
        case cloudBackup = "cloud-backup"
        /// 메모 실시간 동기화 기동.
        case sync = "sync"
        /// 제어센터 컨트롤 갱신.
        case controls = "controls"
        /// 런치 직후 안내·제안 예약.
        case prompts = "prompts"
    }

    /// 단계의 성격. 세이프 모드에서 무엇을 쉬는지가 이 값으로 갈린다.
    private enum Tier: String {
        /// 데이터 무결성에 필요 - 세이프 모드에서도 돈다.
        case essential
        /// 없어도 앱이 동작한다 - 세이프 모드에서 쉬고, 되풀이해 멈추면 격리한다.
        case optional
    }

    // MARK: - 상태

    /// 직전 런치가 끝까지 못 갔다 - 이번 런치는 부가 기능을 전부 쉰다.
    private(set) static var isSafeMode = false

    /// 직전 런치가 멈춘 단계 이름(있다면). 이번 런치에서 한 번 보고하고 나면 볼 일이 없다.
    private(set) static var stalledStage: String?

    /// 연속으로 런치를 못 끝낸 횟수. 끝까지 가면 0으로 돌아간다.
    private(set) static var failStreak = 0

    /// 되풀이해서 멈춘 탓에 이번 빌드에서는 시작하지 않는 단계들.
    private(set) static var quarantined: Set<String> = []

    private static var defaults: UserDefaults { AppGroup.defaults ?? .standard }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    // MARK: - 런치 경계

    /// 런치 맨 앞에서 1회. 직전 런치가 어디까지 갔는지 여기서 판정한다.
    static func begin() {
        let d = defaults

        // 앱이 바뀌었으면 격리를 푼다 - 새 빌드가 고쳤을 수 있고,
        // 고쳤는지 확인할 방법은 한 번 더 돌려 보는 것뿐이다.
        if d.string(forKey: DefaultsKey.launchQuarantineVersion) != appVersion {
            d.removeObject(forKey: DefaultsKey.launchQuarantinedStages)
            d.set(appVersion, forKey: DefaultsKey.launchQuarantineVersion)
        }
        quarantined = Set(d.stringArray(forKey: DefaultsKey.launchQuarantinedStages) ?? [])

        if let marker = d.string(forKey: DefaultsKey.launchStageInFlight) {
            let (tier, stage) = parse(marker)
            stalledStage = stage
            isSafeMode = true
            failStreak = d.integer(forKey: DefaultsKey.launchFailStreak) + 1
            d.set(failStreak, forKey: DefaultsKey.launchFailStreak)

            let repeated = (d.string(forKey: DefaultsKey.launchLastStalledStage) == stage)
            d.set(stage, forKey: DefaultsKey.launchLastStalledStage)

            // 같은 자리에서 두 번 이상 멈췄다. 이번 빌드에서는 그 단계를 그만 부른다.
            // (한 번은 사고일 수 있지만 두 번은 그 단계 자체가 이 기기에서 못 도는 것이다)
            if repeated, tier == .optional, !quarantined.contains(stage) {
                quarantined.insert(stage)
                d.set(Array(quarantined), forKey: DefaultsKey.launchQuarantinedStages)
                AppLog.error(.launch, "🚧 [LaunchGuard] '\(stage)' 을(를) 격리한다. 이 버전에서는 시작하지 않는다")
            }

            AppLog.error(
                .launch,
                "❌ [LaunchGuard.begin] 직전 런치가 '\(stage)'(\(tier.rawValue)) 에서 멈췄다. "
                    + "세이프 모드로 연다 (연속 \(failStreak)회)"
            )
        } else {
            isSafeMode = false
            failStreak = 0
            AppLog.info(.launch, "🚀 [LaunchGuard.begin] 정상 런치")
        }

        mark(.begin, tier: .essential)
    }

    /// 런치 마지막에 1회. 여기까지 왔다는 것은 이번 런치가 온전했다는 뜻이다.
    static func finish() {
        let d = defaults
        d.removeObject(forKey: DefaultsKey.launchStageInFlight)
        d.set(0, forKey: DefaultsKey.launchFailStreak)
        d.synchronize()
        AppLog.info(.launch, "✅ [LaunchGuard.finish] 런치 완료\(isSafeMode ? " (세이프 모드로 끝냄)" : "")")
    }

    /// 첫 화면을 그리기 시작한다는 표식. `init()` 맨 끝에서 1회.
    ///
    /// 여기서부터 `runLaunchSequence()` 의 첫 단계까지가 SwiftUI 가 `body` 를 처음
    /// 평가하는 구간이고, **워치독의 `scene-create` 창이 정확히 이 구간이다.**
    /// 4.4.6 이 죽은 자리도 여기였다(`docs/postmortem/LAUNCH_WATCHDOG_4_4_6.md`).
    ///
    /// 표식이 없으면 그 죽음이 직전 단계(`tips`)의 것으로 기록된다. 그러면 두 번째
    /// 사고에서 TipKit 이 격리되고 - 죄 없는 단계가 꺼지고, 진짜 원인은 계속 숨는다.
    ///
    /// ⚠️ essential 이다. 건너뛸 수 있는 일이 아니라 **구간 이름**이므로 격리 대상이 아니다.
    static func markFirstFrame() {
        mark(.firstFrame, tier: .essential)
    }

    // MARK: - 단계 실행

    /// 데이터 무결성에 필요한 단계 - 세이프 모드에서도 반드시 돈다.
    static func essential(_ stage: Stage, _ body: () -> Void) {
        mark(stage, tier: .essential)
        body()
    }

    /// 없어도 앱이 동작하는 단계 - 세이프 모드에서는 쉬고, 격리됐으면 아예 안 부른다.
    static func optional(_ stage: Stage, _ body: () -> Void) {
        if isSafeMode {
            AppLog.warning(.launch, "⏭ [LaunchGuard] 세이프 모드, '\(stage.rawValue)' 건너뜀")
            return
        }
        if quarantined.contains(stage.rawValue) {
            AppLog.warning(.launch, "🚧 [LaunchGuard] 격리된 단계, '\(stage.rawValue)' 건너뜀")
            return
        }
        mark(stage, tier: .optional)
        body()
    }

    // MARK: - 보고

    /// 직전 런치가 멈췄다면 그 사실을 허브로 한 번 보낸다.
    /// ⚠️ 통계 훅이 꽂힌 **뒤에** 부를 것. 단계 이름만 가고 내용은 실리지 않는다.
    static func reportStallIfNeeded() {
        guard let stage = stalledStage else { return }
        AnalyticsService.log(.launchIncomplete, parameters: [.source: stage])
    }

    // MARK: - 내부

    private static func mark(_ stage: Stage, tier: Tier) {
        let d = defaults
        d.set("\(tier.rawValue):\(stage.rawValue)", forKey: DefaultsKey.launchStageInFlight)
        // ⚠️ 여기서 디스크까지 밀어 넣는다. 바로 다음 줄에서 죽을 수도 있는 값이라,
        //    시스템이 알아서 내보내 주기를 기다리면 정작 필요한 그 한 줄이 사라진다.
        //    단계 수가 열몇 개뿐이고 대부분 첫 화면 뒤에 도는 일이라 비용은 무시할 만하다.
        d.synchronize()
    }

    private static func parse(_ marker: String) -> (tier: Tier, stage: String) {
        let parts = marker.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let tier = Tier(rawValue: parts[0]) else {
            // 옛 형식이거나 알 수 없는 값 - 안전한 쪽(격리하지 않음)으로 읽는다.
            return (.essential, marker)
        }
        return (tier, parts[1])
    }
}
