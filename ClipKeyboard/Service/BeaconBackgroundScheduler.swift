//
//  BeaconBackgroundScheduler.swift
//  ClipKeyboard
//
//  키보드 익스텐션이 App Group에 쌓은 사용 비콘을 메인 앱이 백그라운드에서
//  주기적으로 깨어나 Firebase로 flush. 메인 앱 launch에 의존하지 않아도
//  키보드만 사용하는 유저의 DAU/WAU 추적 가능.
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

    /// 앱 launch 시 한 번 호출 — task 핸들러 등록 + 첫 스케줄 예약.
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

    /// 다음 task 예약 — 핸들러 종료 시점 + 앱 launch 시점에 호출.
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
    /// 백그라운드 task 실행 — 비콘 flush + 다음 task 재예약.
    private static func handleBeaconFlush(task: BGAppRefreshTask) {
        // 작업 만료 핸들러 — iOS가 시간 부족하면 호출됨
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // 다음 task는 무조건 미리 예약 (이번 task가 실패하더라도 체인 유지)
        scheduleNext()

        // 비콘 flush — Firebase Analytics로 keyboard_used 이벤트 전송
        AnalyticsService.flushKeyboardBeacon()

        task.setTaskCompleted(success: true)
    }
    #endif
}
