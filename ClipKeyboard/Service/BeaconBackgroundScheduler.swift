//
//  BeaconBackgroundScheduler.swift
//  ClipKeyboard
//
//  키보드 익스텐션이 App Group에 쌓은 사용 비콘을 메인 앱이 백그라운드에서
//  주기적으로 깨어나 flush (AnalyticsService, 현재 no-op). 메인 앱 launch에
//  의존하지 않아도 키보드만 사용하는 유저의 DAU/WAU 추적 가능.
//
//  iOS는 사용자 행동 패턴 + 배터리 상태 등을 고려해 task 실행 빈도를
//  자체 결정 (보통 하루 1~2회). 항상 즉시 실행되지 않으니 메인 앱 launch
//  flush와 함께 양쪽으로 보장.
//

import Foundation
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

enum BeaconBackgroundScheduler {

    /// Info.plist BGTaskSchedulerPermittedIdentifiers와 동일해야 함.
    static let taskIdentifier = "com.Ysoup.TokenMemo.beacon-flush"

    /// 앱 launch 시 한 번 호출 - task 핸들러 등록 + 첫 스케줄 예약.
    /// 등록은 앱 launch 사이클 초기 (UIScene/willConnect 또는 App init)에 해야 한다.
    static func registerAndScheduleIfNeeded() {
        #if canImport(BackgroundTasks)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            handleBeaconFlush(task: task as! BGAppRefreshTask)
        }
        scheduleNext()
        #endif
    }

    /// 예약을 전부 걷어낸다 - 세이프 모드처럼 **핸들러를 등록하지 않은 런치**에서 부른다.
    /// 등록 없이 예약만 남아 있으면 iOS가 그 작업으로 앱을 깨웠을 때 받을 곳이 없다.
    static func cancelAll() {
        #if canImport(BackgroundTasks)
        BGTaskScheduler.shared.cancelAllTaskRequests()
        print("🧹 [BeaconBackgroundScheduler] 핸들러 미등록 런치, 예약을 걷어냈다")
        #endif
    }

    /// 다음 task 예약 - 핸들러 종료 시점 + 앱 launch 시점에 호출.
    /// earliestBeginDate를 4시간 뒤로 설정해 적당한 빈도 유도 (iOS는 더 늦출 수 있음).
    static func scheduleNext() {
        #if canImport(BackgroundTasks)
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)  // 4 hours
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 [BeaconBackgroundScheduler] 다음 flush 예약됨 (4h 이후)")
        } catch {
            print("⚠️ [BeaconBackgroundScheduler] submit 실패: \(error)")
        }
        #endif
    }

    #if canImport(BackgroundTasks)
    /// 백그라운드 task 실행 - 비콘 flush + 활동일 소급 전송 + 다음 task 재예약.
    private static func handleBeaconFlush(task: BGAppRefreshTask) {
        // 다음 task는 무조건 미리 예약 (이번 task가 실패하더라도 체인 유지)
        scheduleNext()

        // ⚠️ 소급 전송이 끝난 **뒤에** 완료를 알린다. 예전엔 여기서 바로 setTaskCompleted를
        //    불러, 허브로 나가던 CloudKit 쓰기가 시작하자마자 잘렸다 - 앱을 안 여는
        //    사용자를 세려고 만든 경로가 정작 아무것도 못 보내고 있었다.
        //    (flushKeyboardBeacon 의 keyboard_used 는 여전히 fire-and-forget 이라 잘릴 수
        //     있지만, 횟수 자체는 totalCount 로 남아 다음 스냅샷에 실려 유실되지 않는다)
        let work = Task { @MainActor in
            defer { task.setTaskCompleted(success: !Task.isCancelled) }

            AnalyticsService.flushKeyboardBeacon()
            await UsageReportingService.reportKeyboardActiveDays()
        }

        // 만료되면 취소만 한다 - 완료 통보는 위 defer가 한 번만 부른다(이중 호출 방지).
        // 소급 전송 루프가 날짜 사이마다 취소를 확인하므로 곧바로 빠져나온다.
        task.expirationHandler = { work.cancel() }
    }
    #endif
}
