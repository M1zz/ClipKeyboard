//
//  FeedbackServiceTests.swift
//  ClipKeyboardTests
//
//  피드백 CloudKit 연동의 리그레션 테스트 (네트워크 없이 로컬 CKRecord로 검증).
//
//  잠그는 계약:
//  1. 스키마 상수 — 컨테이너 ID / 레코드 타입 / 구독 ID가 Dashboard 설정과 어긋나면
//     대시보드에는 보이는데 앱 인박스에는 안 보이는 장애가 재발한다.
//  2. 쓰기(makeRecord)와 읽기(FeedbackRecord) 필드 키가 항상 1:1로 유지된다.
//  3. FeedbackType rawValue는 서버에 저장된 값이므로 절대 변경 불가.
//

import XCTest
import CloudKit
@testable import ClipKeyboard

final class FeedbackServiceTests: XCTestCase {

    // MARK: - 스키마 상수 (Dashboard 설정과의 계약)

    func testContainerIdentifierMatchesBackupContainer() {
        // CloudKitBackupService와 같은 컨테이너를 써야 Dashboard 한 곳에서 관리된다
        XCTAssertEqual(FeedbackService.containerIdentifier, "iCloud.com.Ysoup.TokenMemo")
    }

    func testRecordTypeIsStable() {
        // Dashboard의 Record Type 이름 — 바꾸면 기존 피드백이 전부 조회에서 빠진다
        XCTAssertEqual(FeedbackService.recordType, "Feedback")
    }

    func testNewFeedbackSubscriptionIDIsStable() {
        // 서버에 저장된 구독 ID — 바꾸면 기존 기기의 구독을 해제할 수 없게 된다
        XCTAssertEqual(FeedbackService.newFeedbackSubscriptionID, "feedback-new-v1")
    }

    // MARK: - 인박스 조회 쿼리

    func testFetchQueryTargetsFeedbackWithTruePredicate() {
        let query = FeedbackService.makeFetchQuery()

        XCTAssertEqual(query.recordType, "Feedback")
        // TRUEPREDICATE — Production에 recordName Queryable 인덱스가 필요한 형태
        XCTAssertEqual(query.predicate, NSPredicate(value: true))
    }

    func testFetchQuerySortsByCreationDateDescending() {
        let query = FeedbackService.makeFetchQuery()

        XCTAssertEqual(query.sortDescriptors?.count, 1)
        XCTAssertEqual(query.sortDescriptors?.first?.key, "creationDate")
        XCTAssertEqual(query.sortDescriptors?.first?.ascending, false)
    }

    // MARK: - 제출 레코드 구성 (쓰기 모델)

    func testMakeRecordPopulatesAllSchemaFields() {
        let record = FeedbackService.makeRecord(
            type: "bug",
            message: "새 메모 생성이 안돼요",
            deviceInfo: "App 4.3.7 | iPhone | iOS 26.5.2"
        )

        XCTAssertEqual(record.recordType, "Feedback")
        XCTAssertEqual(record["type"] as? String, "bug")
        XCTAssertEqual(record["message"] as? String, "새 메모 생성이 안돼요")
        XCTAssertEqual(record["deviceInfo"] as? String, "App 4.3.7 | iPhone | iOS 26.5.2")
        XCTAssertEqual(record["locale"] as? String, Locale.current.identifier)

        // appVersion은 번들에 따라 값이 다르므로 존재만 보장
        XCTAssertNotNil(record["appVersion"] as? String)

        #if targetEnvironment(macCatalyst)
        XCTAssertEqual(record["platform"] as? String, "macCatalyst")
        #else
        XCTAssertEqual(record["platform"] as? String, "iOS")
        #endif

        // status는 제출 시점에는 없어야 한다 (개발자가 인박스에서 완료 표시할 때만 기록)
        XCTAssertNil(record["status"])
    }

    // MARK: - 인박스 읽기 모델 (FeedbackRecord)

    func testFeedbackRecordMapsAllFieldsFromCKRecord() {
        let ckRecord = CKRecord(recordType: FeedbackService.recordType)
        ckRecord["type"] = "feature"
        ckRecord["message"] = "카테고리 페이지가 바로 생기면 좋겠어요"
        ckRecord["deviceInfo"] = "App 4.3.7 | iPhone | iOS 26.5.2"
        ckRecord["appVersion"] = "4.3.7"
        ckRecord["locale"] = "ko_KR"
        ckRecord["platform"] = "iOS"
        ckRecord["status"] = "done"

        let record = FeedbackService.FeedbackRecord(ckRecord)

        XCTAssertEqual(record.id, ckRecord.recordID.recordName)
        XCTAssertEqual(record.type, "feature")
        XCTAssertEqual(record.message, "카테고리 페이지가 바로 생기면 좋겠어요")
        XCTAssertEqual(record.deviceInfo, "App 4.3.7 | iPhone | iOS 26.5.2")
        XCTAssertEqual(record.appVersion, "4.3.7")
        XCTAssertEqual(record.locale, "ko_KR")
        XCTAssertEqual(record.platform, "iOS")
        XCTAssertEqual(record.status, "done")
    }

    func testFeedbackRecordDefaultsWhenFieldsMissing() {
        // Dashboard에서 수동 생성했거나 구버전이 만든 레코드 — 필드가 비어도 크래시 없이 표시
        let record = FeedbackService.FeedbackRecord(CKRecord(recordType: FeedbackService.recordType))

        XCTAssertEqual(record.type, "-")
        XCTAssertEqual(record.message, "")
        XCTAssertEqual(record.deviceInfo, "")
        XCTAssertEqual(record.appVersion, "")
        XCTAssertEqual(record.locale, "")
        XCTAssertEqual(record.platform, "")
        XCTAssertNil(record.status)
        XCTAssertFalse(record.isDone)
    }

    func testIsDoneOnlyWhenStatusIsExactlyDone() {
        let ckRecord = CKRecord(recordType: FeedbackService.recordType)
        var record = FeedbackService.FeedbackRecord(ckRecord)

        record.status = "done"
        XCTAssertTrue(record.isDone)

        for notDone in [nil, "", "DONE", "open", "in-progress"] {
            record.status = notDone
            XCTAssertFalse(record.isDone, "status=\(notDone ?? "nil")은 완료로 표시되면 안 된다")
        }
    }

    func testSubmitAndInboxFieldKeysStayInSync() {
        // 핵심 회귀 가드: 쓰기(makeRecord)와 읽기(FeedbackRecord)의 필드 키가 어긋나면
        // 제출은 성공하는데 인박스에는 기본값("-", "")만 보이는 조용한 장애가 된다
        let submitted = FeedbackService.makeRecord(
            type: "question",
            message: "템플릿은 어떻게 쓰나요?",
            deviceInfo: "App 4.3.9 | iPhone | iOS 26.5.2"
        )

        let read = FeedbackService.FeedbackRecord(submitted)

        XCTAssertEqual(read.type, "question")
        XCTAssertEqual(read.message, "템플릿은 어떻게 쓰나요?")
        XCTAssertEqual(read.deviceInfo, "App 4.3.9 | iPhone | iOS 26.5.2")
        XCTAssertEqual(read.locale, Locale.current.identifier)
        XCTAssertFalse(read.appVersion.isEmpty)
        XCTAssertFalse(read.platform.isEmpty)
    }

    // MARK: - FeedbackType (서버에 저장되는 rawValue)

    func testFeedbackTypeRawValuesAreStable() {
        // rawValue는 CloudKit 레코드의 type 필드에 그대로 저장된다 — 변경 금지
        XCTAssertEqual(FeedbackType.bug.rawValue, "bug")
        XCTAssertEqual(FeedbackType.feature.rawValue, "feature")
        XCTAssertEqual(FeedbackType.question.rawValue, "question")
        XCTAssertEqual(FeedbackType.other.rawValue, "other")
        XCTAssertEqual(FeedbackType.allCases.count, 4)
    }

    func testFeedbackTypeRoundTripsThroughStoredRawValue() {
        // 인박스는 FeedbackType(rawValue: record.type)으로 아이콘/이름을 복원한다
        for type in FeedbackType.allCases {
            let record = FeedbackService.makeRecord(type: type.rawValue, message: "m", deviceInfo: "d")
            let restored = FeedbackType(rawValue: FeedbackService.FeedbackRecord(record).type)
            XCTAssertEqual(restored, type)
        }
    }

    func testUnknownFeedbackTypeFallsBackToNil() {
        // 미래 버전이 새 타입을 추가해도 구버전 인박스는 raw 문자열로 표시 (크래시 없음)
        XCTAssertNil(FeedbackType(rawValue: "praise"))
    }

    func testFeedbackTypeHasIconAndLocalizedName() {
        for type in FeedbackType.allCases {
            XCTAssertFalse(type.icon.isEmpty)
            XCTAssertFalse(type.localizedName.isEmpty)
        }
    }
}
