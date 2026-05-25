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
    private let personaKey = "user.selected_persona.v1"
    /// v4.1.0: 카테고리 기능 활성화 플래그. 기본 OFF, 사용자가 명시적으로 활성화.
    private let featureEnabledKey = "category.feature.enabled.v1"
    /// 활성화 배너를 사용자가 "안 쓸래요"로 닫은 적이 있는지 — 다시 표시 안 함.
    private let activationDismissedKey = "category.activation.banner.dismissed.v1"
    /// 마이그레이션 완료 flag — 기존 사용자(category != "기본"인 메모 보유)는 자동 활성.
    private let featureMigratedKey = "category.feature.migrated.v1"

    @Published private(set) var categories: [String] = []
    @Published private(set) var isFeatureEnabled: Bool = false

    private init() {
        load()
        loadFeatureEnabledState()
    }

    // MARK: - Feature toggle (v4.1.0)

    /// 카테고리 기능 켜기. 메인 화면 탭/메모 추가 picker 노출.
    func enableFeature() {
        UserDefaults(suiteName: appGroup)?.set(true, forKey: featureEnabledKey)
        isFeatureEnabled = true
        print("✅ [CategoryStore] 카테고리 기능 활성화")
    }

    /// 사용자가 "안 쓸래요" 선택 — 배너 영구 닫기. 추후 카테고리 관리 페이지에서
    /// 수동으로 다시 켤 수 있음.
    func dismissActivationBanner() {
        UserDefaults(suiteName: appGroup)?.set(true, forKey: activationDismissedKey)
        print("🙈 [CategoryStore] 활성화 배너 영구 닫힘")
    }

    /// 활성화 배너를 보여줄지 — 미활성 + 미dismiss + 메모 5개 이상일 때 true.
    func shouldShowActivationBanner(currentMemoCount: Int) -> Bool {
        guard !isFeatureEnabled else { return false }
        let defaults = UserDefaults(suiteName: appGroup)
        if defaults?.bool(forKey: activationDismissedKey) == true { return false }
        return currentMemoCount >= 5
    }

    /// 첫 실행 시 마이그레이션 — 기존 사용자(메모 중 category가 "기본"이 아닌 것이
    /// 1개라도 있으면 카테고리를 이미 쓰고 있던 것)는 자동 활성. 신규 설치는 OFF.
    func migrateFeatureEnabledIfNeeded(existingMemoCategories: [String]) {
        let defaults = UserDefaults(suiteName: appGroup)
        guard defaults?.bool(forKey: featureMigratedKey) != true else { return }
        let hasNonDefault = existingMemoCategories.contains { $0 != "기본" && !$0.isEmpty }
        if hasNonDefault {
            defaults?.set(true, forKey: featureEnabledKey)
            isFeatureEnabled = true
            print("🔄 [CategoryStore] 기존 사용자 자동 활성 (category != 기본인 메모 보유)")
        }
        defaults?.set(true, forKey: featureMigratedKey)
    }

    private func loadFeatureEnabledState() {
        isFeatureEnabled = UserDefaults(suiteName: appGroup)?.bool(forKey: featureEnabledKey) ?? false
    }

    // MARK: - Persona

    /// 사용자가 온보딩에서 선택한 페르소나. nil이면 미선택.
    var selectedPersona: Persona? {
        get {
            guard let raw = UserDefaults(suiteName: appGroup)?.string(forKey: personaKey) else {
                return nil
            }
            return Persona(rawValue: raw)
        }
    }

    /// 페르소나 선택 + 시드 카테고리를 기존 목록에 머지(중복 제거).
    /// 사용자가 추가했던 카테고리는 보존되며, 페르소나 시드만 위에 얹힌다.
    func applyPersona(_ persona: Persona, language: String? = nil) {
        let lang = language ?? Locale.current.language.languageCode?.identifier ?? "en"
        let seeds = persona.seedCategories(language: lang)

        var merged = categories
        for seed in seeds where !merged.contains(seed) {
            merged.append(seed)
        }
        categories = merged
        persist()
        UserDefaults(suiteName: appGroup)?.set(persona.rawValue, forKey: personaKey)
        print("👤 [CategoryStore] 페르소나 적용: \(persona.rawValue) (lang=\(lang), 신규=\(seeds.count))")
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
        let region = Locale.current.region?.identifier ?? ""
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
