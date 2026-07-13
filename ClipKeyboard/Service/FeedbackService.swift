//
//  FeedbackService.swift
//  ClipKeyboard
//
//  앱 내 피드백/기능 요청을 CloudKit Public Database로 직접 제출한다.
//  메일 앱 없이도 동작하며, 개발자는 CloudKit Dashboard에서 접수 내역을 확인한다.
//
//  ⚠️ CloudKit Dashboard 설정 필요 (docs/FEEDBACK_CLOUDKIT.md 참고):
//  - Public DB에 "Feedback" 레코드 타입 (개발 환경에서 첫 저장 시 자동 생성)
//  - Security Roles: World에 create만 허용, read 권한 제거
//  - 스키마를 Production으로 배포
//

import Foundation
import CloudKit

final class FeedbackService {
    static let shared = FeedbackService()
    private init() {}

    /// CloudKitBackupService와 동일한 컨테이너 사용
    private static let containerIdentifier = "iCloud.com.Ysoup.TokenMemo"
    static let recordType = "Feedback"

    enum FeedbackError: LocalizedError {
        case iCloudUnavailable
        case saveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .iCloudUnavailable:
                return NSLocalizedString("iCloud에 로그인되어 있지 않아요", comment: "Feedback error: iCloud unavailable")
            case .saveFailed:
                return NSLocalizedString("전송에 실패했어요", comment: "Feedback error: save failed")
            }
        }
    }

    /// 피드백을 Public DB에 제출한다. 실패 시 throw — 호출부에서 이메일 폴백 처리.
    func submit(type: String, message: String, deviceInfo: String) async throws {
        let container = CKContainer(identifier: Self.containerIdentifier)

        // Public DB 쓰기도 iCloud 로그인이 필요하다.
        let status = try await container.accountStatus()
        guard status == .available else {
            print("⚠️ [FeedbackService.submit] iCloud 계정 없음: \(status)")
            throw FeedbackError.iCloudUnavailable
        }

        let record = CKRecord(recordType: Self.recordType)
        record["type"] = type
        record["message"] = message
        record["deviceInfo"] = deviceInfo
        record["appVersion"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        record["locale"] = Locale.current.identifier
        record["platform"] = {
            #if targetEnvironment(macCatalyst)
            return "macCatalyst"
            #else
            return "iOS"
            #endif
        }()

        do {
            _ = try await container.publicCloudDatabase.save(record)
            print("✅ [FeedbackService.submit] 피드백 제출 완료 (type=\(type))")
        } catch {
            print("❌ [FeedbackService.submit] 제출 실패: \(error)")
            throw FeedbackError.saveFailed(error)
        }
    }
}
