//
//  Constants.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 10/10/23.
//

import Foundation

struct Constants {
    static var addNewToken: String {
        NSLocalizedString("새 토큰을 추가할까요?", comment: "Add new token prompt")
    }
    static var nothingToPaste: String {
        NSLocalizedString("생성된 키보드가 없어요", comment: "No keyboard created")
    }
    static var emptyDescription: String {
        NSLocalizedString("'+' 버튼을 탭하면 iMessage, Mail 또는 기타 앱에서 쉽게 접근할 수 있는 문구나 일반 텍스트를 추가할 수 있습니다.", comment: "Empty state description")
    }
    static var insertKeyword: String {
        NSLocalizedString("키보드 버튼 문구", comment: "Keyboard button text")
    }
    static var removeAll: String {
        NSLocalizedString("전체 삭제", comment: "Remove all")
    }
    static var save: String {
        NSLocalizedString("키보드 추가", comment: "Add keyboard")
    }
    static var insertContents: String {
        NSLocalizedString("키보드 입력 시 삽입되는 전체 문구를 작성해주세요", comment: "Insert content instruction")
    }
    // static let ok = ""
    // static let completed = ""

    // 통합 테마 시스템 - ClipboardItemType 기반 (rawValue 저장용)
    static let themes = [
        "텍스트",
        "이미지",
        "이메일",
        "전화번호",
        "주소",
        "URL",
        "카드번호",
        "계좌번호",
        "여권번호",
        "통관번호",
        "우편번호",
        "이름",
        "생년월일",
        "세금번호",
        "보험번호",
        "차량번호",
        "IP주소",
        "회원번호",
        "송장번호",
        "예약번호",
        "진료기록번호",
        "사번/학번"
    ]

    // 다국어 지원 테마명 (UI 표시용)
    static var localizedThemes: [String] {
        return ClipboardItemType.allCases.map { $0.localizedName }
    }

    // 하위 호환성을 위한 별칭
    static let categories = themes

    // ClipboardItemType에서 테마로 자동 매핑 (타입의 rawValue 사용)
    static func themeForClipboardType(_ type: ClipboardItemType) -> String {
        return type.rawValue
    }

    // 하위 호환성을 위한 별칭
    static func categoryForClipboardType(_ type: ClipboardItemType) -> String {
        return themeForClipboardType(type)
    }

    // MARK: - v4.0.8: Sample value provider
    // 빈 메모에서 시작하는 부담을 줄이기 위해 카테고리(테마)에 맞는 샘플을 미리 채워준다.
    // 사용자는 샘플을 수정해서 사용하면 됨. 사용자에게 "샘플" 뱃지로 명시 표시.

    /// 사용자에게 친화적인 샘플 placeholder 값들의 raw key로 매핑된 사전.
    private static let sampleValuesByRawType: [String: String] = [
        ClipboardItemType.email.rawValue: "example@email.com",
        ClipboardItemType.phone.rawValue: "010-0000-0000",
        ClipboardItemType.address.rawValue: "서울특별시 종로구 청와대로 1",
        ClipboardItemType.url.rawValue: "https://example.com",
        ClipboardItemType.creditCard.rawValue: "0000-0000-0000-0000",
        ClipboardItemType.bankAccount.rawValue: "000-0000-000000",
        ClipboardItemType.passportNumber.rawValue: "M12345678",
        ClipboardItemType.declarationNumber.rawValue: "P000000000000",
        ClipboardItemType.postalCode.rawValue: "06234",
        ClipboardItemType.name.rawValue: "홍길동",
        ClipboardItemType.birthDate.rawValue: "1990-01-01",
        ClipboardItemType.taxID.rawValue: "000-00-00000",
        ClipboardItemType.insuranceNumber.rawValue: "0000000000",
        ClipboardItemType.vehiclePlate.rawValue: "12가 3456",
        ClipboardItemType.ipAddress.rawValue: "192.168.0.1",
        ClipboardItemType.membershipNumber.rawValue: "M0000000",
        ClipboardItemType.trackingNumber.rawValue: "1Z000000000000000",
        ClipboardItemType.confirmationCode.rawValue: "ABC123XYZ",
        ClipboardItemType.medicalRecord.rawValue: "MR-000-0000",
        ClipboardItemType.employeeID.rawValue: "EMP-0000",
        ClipboardItemType.iban.rawValue: "GB82 WEST 1234 5698 7654 32",
        ClipboardItemType.swift.rawValue: "BOFAUS3NXXX",
        ClipboardItemType.vat.rawValue: "DE123456789",
        ClipboardItemType.cryptoWallet.rawValue: "0x0000000000000000000000000000000000000000",
        ClipboardItemType.paypalLink.rawValue: "paypal.me/yourname"
    ]

    /// 카테고리(테마)에 맞는 샘플 값을 반환. 매핑이 없거나 image/text면 nil.
    static func sampleValue(for category: String) -> String? {
        return sampleValuesByRawType[category]
    }

    /// 주어진 값이 카테고리의 샘플 값과 동일한지 (=아직 사용자가 수정 안 함) 판정.
    static func isSampleValue(_ value: String, forCategory category: String) -> Bool {
        guard let sample = sampleValue(for: category) else { return false }
        return value == sample
    }

    /// 카테고리에 맞는 기본 keyword(이름) 샘플. 카테고리 다국어명을 그대로 사용해
    /// 백지 부담을 줄이되, 사용자가 자기 맥락에 맞게 수정 가능.
    /// 예: ko 환경 "전화번호" / en 환경 "Phone" / id 환경 "Telepon".
    static func sampleTitle(for category: String) -> String? {
        // sampleValue 매핑이 있는 카테고리만 keyword 자동 채움
        guard sampleValuesByRawType[category] != nil else { return nil }
        if let type = ClipboardItemType(rawValue: category) {
            return type.localizedName
        }
        return category
    }

    /// 주어진 keyword가 카테고리의 샘플 keyword와 동일한지 — 자동 갱신 가능 여부 판정.
    static func isSampleTitle(_ title: String, forCategory category: String) -> Bool {
        guard let sample = sampleTitle(for: category) else { return false }
        return title == sample
    }

    // 테마명을 다국어 이름으로 변환 (UI 표시용)
    static func localizedThemeName(_ theme: String) -> String {
        if let type = ClipboardItemType.allCases.first(where: { $0.rawValue == theme }) {
            return type.localizedName
        }
        return NSLocalizedString(theme, comment: "Theme name")
    }

    // MARK: - App Version (중앙 버전 관리)
    // 주의: 실제 버전은 Xcode 프로젝트 설정의 MARKETING_VERSION에서 관리됩니다.
    // 이 값은 문서화 및 참조 목적으로만 사용하세요.

    /// 현재 앱 버전 (참고용)
    /// 실제 버전은 Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")에서 가져옵니다.
    static let appVersion = "4.0.0"

    /// App Store 앱 ID
    static let appStoreID = "1543660502"

    /// App Store 리뷰 URL
    static let appStoreReviewURL = "https://apps.apple.com/app/id\(appStoreID)?action=write-review"

    /// App Store 앱 페이지 URL
    static let appStoreURL = "https://apps.apple.com/app/id\(appStoreID)"

    /// 개발자 이메일
    static let developerEmail = "clipkeyboard@gmail.com"

    /// 튜토리얼 URL
    static let tutorialURL = "https://m1zz.github.io/ClipKeyboard/tutorial.html"
}
