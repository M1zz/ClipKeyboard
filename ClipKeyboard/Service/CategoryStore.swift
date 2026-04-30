//
//  CategoryStore.swift
//  ClipKeyboard
//
//  사용자 편집 가능한 메모 카테고리 목록.
//  - 첫 실행 시 Locale.current.regionCode 기반으로 기본 시드.
//  - 사용자 추가/삭제/순서변경 시 App Group UserDefaults에 영구 저장.
//  - 키보드 익스텐션도 같은 키를 읽어 일관된 카테고리 표시.
//
//  설계 원칙:
//  - ClipboardItemType (자동 분류 시스템) 과는 분리. ClipboardItemType은 시스템 내부에서
//    auto-detection 용도로만 쓰이고, UI에 노출되는 사용자-페이싱 카테고리는 이 store가 담당.
//  - rawValue가 "이메일", "URL" 등 ClipboardItemType과 겹치는 항목들은 그대로 유지하되
//    사용자는 자기 만든 항목 (예: "프리랜서 클라이언트", "여행 정보") 도 추가 가능.
//

import Foundation
import Combine

final class CategoryStore: ObservableObject {
    static let shared = CategoryStore()

    private let appGroup = "group.com.Ysoup.TokenMemo"
    private let storageKey = "user.categories.v1"
    private let seededFlagKey = "user.categories.seeded.v1"

    @Published private(set) var categories: [String] = []

    private init() {
        load()
    }

    // MARK: - Public API

    /// 사용자가 보는 전체 카테고리 목록 — 순서대로.
    var allCategories: [String] { categories }

    /// 새 카테고리 추가. 중복 시 무시.
    @discardableResult
    func add(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !categories.contains(trimmed) else { return false }
        categories.append(trimmed)
        persist()
        return true
    }

    /// 카테고리 이름 변경. 중복 시 무시.
    @discardableResult
    func rename(from oldName: String, to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, oldName != trimmed,
              let idx = categories.firstIndex(of: oldName),
              !categories.contains(trimmed) else { return false }
        categories[idx] = trimmed
        persist()
        return true
    }

    /// 카테고리 삭제. 보호 카테고리 (기본/텍스트/이미지) 제외.
    @discardableResult
    func remove(_ name: String) -> Bool {
        guard !Self.protectedCategories.contains(name) else { return false }
        guard let idx = categories.firstIndex(of: name) else { return false }
        categories.remove(at: idx)
        persist()
        return true
    }

    /// 순서 변경 (SwiftUI .onMove에서 호출).
    func move(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    /// 시스템 기본값으로 초기화 (사용자 데이터 삭제됨).
    func resetToDefaults() {
        categories = Self.localeDefaults()
        persist()
    }

    /// 보호 카테고리 — 삭제 불가.
    static let protectedCategories: Set<String> = ["기본", "텍스트", "이미지"]

    // MARK: - Storage

    private func load() {
        guard let defaults = UserDefaults(suiteName: appGroup) else {
            categories = Self.localeDefaults()
            return
        }
        if defaults.bool(forKey: seededFlagKey),
           let stored = defaults.stringArray(forKey: storageKey),
           !stored.isEmpty {
            categories = stored
        } else {
            // 첫 실행 — locale 기반 시드
            categories = Self.localeDefaults()
            defaults.set(true, forKey: seededFlagKey)
            persist()
        }
    }

    private func persist() {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        defaults.set(categories, forKey: storageKey)
    }

    // MARK: - Locale-aware defaults

    /// 현재 Locale에 맞는 기본 카테고리 목록.
    /// 글로벌 공통 (이메일/URL/전화번호 등) + 국가별 특화 항목.
    static func localeDefaults() -> [String] {
        let region = Locale.current.regionCode ?? ""
        return globalCommon + countrySpecific(for: region)
    }

    /// 모든 국가에서 공통적으로 유용한 카테고리.
    private static let globalCommon: [String] = [
        "기본",
        "이메일",
        "전화번호",
        "주소",
        "URL",
        "카드번호",
        "계좌번호",
        "이름",
        "생년월일",
        "우편번호"
    ]

    /// 국가 코드별 특화 카테고리.
    private static func countrySpecific(for region: String) -> [String] {
        switch region.uppercased() {
        case "KR":
            return ["주민등록번호", "사업자등록번호", "여권번호", "통관번호", "차량번호", "사번/학번"]
        case "ID":
            return ["NPWP", "KTP", "NIK", "BPJS", "Paspor", "Plat Nomor"]
        case "BR":
            return ["CPF", "CNPJ", "RG", "Passaporte", "Placa do veículo", "PIS"]
        case "US":
            return ["SSN", "EIN", "Driver's License", "Passport", "Insurance"]
        case "GB":
            return ["NI Number", "UTR", "Passport", "NHS Number", "Driving Licence"]
        case "DE":
            return ["Steuer-ID", "Personalausweis", "Reisepass", "Krankenversicherung", "IBAN"]
        case "FR":
            return ["Numéro fiscal", "Carte d'identité", "Passeport", "Sécurité sociale", "IBAN"]
        case "JP":
            return ["マイナンバー", "運転免許証", "パスポート", "健康保険"]
        case "VN":
            return ["CMND/CCCD", "Mã số thuế", "Hộ chiếu", "BHYT"]
        case "PH":
            return ["TIN", "SSS", "PhilHealth", "PhilSys", "Passport"]
        case "TH":
            return ["บัตรประชาชน", "เลขผู้เสียภาษี", "หนังสือเดินทาง"]
        case "MX":
            return ["RFC", "CURP", "INE", "Pasaporte"]
        case "ES":
            return ["DNI/NIE", "NIF", "Pasaporte", "IBAN", "Seguridad Social"]
        case "IN":
            return ["Aadhaar", "PAN", "GSTIN", "Passport", "Driving License"]
        default:
            // 글로벌 노마드 — 국가 코드 매칭 안 되면 노마드 친화 항목
            return ["IBAN", "VAT/Tax ID", "Passport", "Insurance"]
        }
    }
}
