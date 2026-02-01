//
//  Constants.swift
//  Token memo
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
    static let appVersion = "3.0.4"

    /// App Store 앱 ID
    static let appStoreID = "1543660502"

    /// App Store 리뷰 URL
    static let appStoreReviewURL = "https://apps.apple.com/app/id\(appStoreID)?action=write-review"

    /// App Store 앱 페이지 URL
    static let appStoreURL = "https://apps.apple.com/app/id\(appStoreID)"

    /// 개발자 이메일
    static let developerEmail = "clipkeyboard@gmail.com"

    /// 튜토리얼 URL
    static let tutorialURL = "https://leeo75.notion.site/ClipKeyboard-tutorial-70624fccc524465f99289c89bd0261a4"
}
