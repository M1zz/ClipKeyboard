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
        "통관부호",
        "우편번호",
        "이름",
        "생년월일",
        "주민등록번호",
        "사업자등록번호",
        "차량번호",
        "IP주소"
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
}
