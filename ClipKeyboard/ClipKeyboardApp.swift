//
//  ClipKeyboardApp.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/05/14.
//

import SwiftUI
import TipKit
// 키보드 ext에서는 Firebase 미사용 (KEYBOARD_EXTENSION 플래그로 제외)
#if !KEYBOARD_EXTENSION && canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct ClipKeyboardApp: App {
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showReviewRequest = false
    @State private var showAccessibilityGuide = false
    /// 기존 사용자에게 데모 샘플 체험을 1회 물어보는 알림
    @State private var showDemoSampleOffer = false
    /// 새 기기 첫 실행에서 "기존 메모를 불러올 수 있어요"를 1회 안내
    @State private var showRestoreHint = false
    /// 안내에서 "불러오기"를 누르면 백업/복원 화면을 시트로 띄운다
    @State private var showCloudBackupSheet = false
    private let restoreHintShownKey = "restoreHintShown_v1"

    /// 유닛 테스트 실행 중인지 — `XCTestConfigurationFilePath`는 xcodebuild test로
    /// (XCTest/Swift Testing 모두) 번들을 주입할 때만 설정되고, 프로덕션/TestFlight/
    /// 일반 실행에는 없다. 테스트 중에는 Firebase·스케줄러·마이그레이션 등 무거운
    /// 런치 작업을 건너뛰어 테스트 러너가 곧바로 연결되게 한다.
    static let isRunningUnitTests: Bool =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    init() {
        if ClipKeyboardApp.isRunningUnitTests {
            print("🧪 [APP INIT] 유닛 테스트 모드 — 무거운 초기화 스킵")
            return
        }

        print("🚀 [APP INIT] ClipKeyboardApp 초기화 시작")
        print("📱 [APP INIT] DataManager 생성됨")

        // 콤보/attached 데이터 모델 통합 마이그레이션 — 다른 어떤 load/save보다 먼저 실행해
        // 레거시 키(isCombo/comboValues/attachedTemplateId)가 신 모델 재저장으로 사라지기 전에 변환.
        migrateComboModelIfNeeded()

        // Firebase 초기화 — GoogleService-Info.plist 자동 로드
        // Analytics 데이터 수집 여부는 Firebase Console 설정에 따름
        #if !KEYBOARD_EXTENSION && canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("🔥 [APP INIT] FirebaseApp 초기화 완료")
        }
        #endif

        // 키보드 익스텐션이 App Group에 기록한 사용 비콘을 Firebase로 보냄
        AnalyticsService.flushKeyboardBeacon()

        // 세그먼트 유저 속성 — 모든 퍼널을 Pro 여부·페르소나·키보드 활성으로 쪼갤 수 있게.
        let keyboardActive = (UserDefaults(suiteName: AppGroup.identifier)?
            .double(forKey: DefaultsKey.kbBeaconLastUse) ?? 0) > 0
        AnalyticsService.applyLaunchUserProperties(
            isPro: ProFeatureManager.hasFullAccess,
            persona: CategoryStore.shared.selectedPersona?.rawValue,
            keyboardActive: keyboardActive
        )

        // 백그라운드 새로고침 task 등록 — 메인 앱이 안 열려도 주기적으로 비콘 flush
        // (키보드만 쓰는 유저의 DAU 추적용)
        BeaconBackgroundScheduler.registerAndScheduleIfNeeded()

        // TestFlight 여부 비동기 감지 — isPro 체크 전에 완료되도록 최우선 실행
        Task { await ProFeatureManager.bootstrapIsTestFlight() }

        // v4.0 이전 유료 앱 구매자 그랜드파더 (AppTransaction 영수증 기반).
        // bootstrap_done 1회 가드와 무관하게 매 실행 검증 → 이미 업데이트 후 Pro를 잃은
        // 기존 구매자도 다음 실행에서 자동 복구된다. (이미 부여됐으면 즉시 no-op)
        Task { await ProFeatureManager.grandfatherPaidUserIfNeeded() }

        // DEBUG 빌드에서만 계정/구매 상태 진단 덤프 (Xcode 콘솔에서 "🩺 [Diag]"로 검색)
        #if DEBUG
        Task {
            // TestFlight 감지·그랜드파더 검증이 먼저 끝나도록 잠깐 양보
            await ProFeatureManager.bootstrapIsTestFlight()
            await ProFeatureManager.grandfatherPaidUserIfNeeded()
            await StoreManager.shared.logAccountDiagnostics()
        }
        #endif

        // 앱 실행 횟수 증가
        ReviewManager.shared.incrementAppLaunchCount()

        // v4.0 그랜드파더 플래그 초기화 (최초 1회만 효과 있음, 이후는 no-op)
        bootstrapV4GrandfatherFlags()

        // TipKit 설정 — 온보딩 대신 상황에 맞는 팁으로 안내
        try? Tips.configure([
            .datastoreLocation(.applicationDefault)
        ])

        #if targetEnvironment(macCatalyst)
        setupMacCatalystCommands()
        #endif
    }

    /// v3.x → v4.0 업그레이드 유저에게 그랜드파더 상태를 부여한다.
    /// - Pro 구매 이력 있으면 영구 unlock
    /// - 메모를 하나라도 보유했다면 기존 무료 유저로 기록 (키보드 익스텐션 접근 유지)
    /// - 메모가 새 freeMemoLimit 초과면 grace 플래그
    private func bootstrapV4GrandfatherFlags() {
        // 이미 한 번 초기화됐으면 skip
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        let initKey = DefaultsKey.v4GrandfatherBootstrapDone
        if defaults?.bool(forKey: initKey) == true { return }

        let currentMemoCount: Int
        if let memos = try? MemoStore.shared.load(type: .memo) {
            currentMemoCount = memos.count
        } else {
            currentMemoCount = 0
        }

        ProStatusManager.shared.bootstrapV4GrandfatherFlags(
            existingMemoCount: currentMemoCount,
            isProNow: ProFeatureManager.isPro
        )

        defaults?.set(true, forKey: initKey)
        print("✅ [APP INIT] v4.0 그랜드파더 부트스트랩 완료 (memos=\(currentMemoCount), isPro=\(ProFeatureManager.isPro))")
    }

    // MARK: - Default Sample Data

    /// 최초 설치 후 온보딩 완료 시 4종(일반 메모·템플릿·콤보·일반메모+템플릿)을 1개씩 삽입한다.
    /// "이런 것도 되는구나"를 첫 화면에서 바로 보여주기 위한 시드 데이터.
    /// UserDefaults 플래그로 중복 삽입을 방지한다(기존 설치 유저에겐 재삽입 안 함).
    private let samplesInsertedKey = "defaultSamplesInserted_v1"
    /// 기존 사용자에게 "체험해 볼래요?"를 이미 물어봤는지(신규 설치는 자동 처리되어 묻지 않음).
    private let demoOfferResolvedKey = "demoSampleOfferResolved_v1"

    /// 현재 페르소나·로케일에 맞는 샘플 4종 + 카테고리 2개를 만들어 저장한다. 성공 여부 반환.
    /// 샘플이 속한 카테고리를 실제로 생성·활성화해 "색 = 카테고리 = 스와이프 페이지"가
    /// 첫 화면에서 일관되게 동작하도록 한다.
    @discardableResult
    private func performSampleInsertion() -> Bool {
        let isKorean = (Locale.current.language.languageCode?.identifier ?? "en") == "ko"
        let persona = CategoryStore.shared.selectedPersona ?? .general
        let result = persona == .nomad ? nomadSamples(isKorean: isKorean) : generalSamples(isKorean: isKorean)
        do {
            var memos = (try? MemoStore.shared.load(type: .memo)) ?? []
            memos.append(contentsOf: result.memos)
            try MemoStore.shared.save(memos: memos, type: .memo)
            SampleMemoStorage.save(ids: result.memos.map { $0.id })
            // 샘플이 속한 카테고리를 실제로 만들고 기능을 켜 → 스와이프 페이지(탭)가 생긴다.
            result.categories.forEach { CategoryStore.shared.add($0) }
            CategoryStore.shared.enableFeature()
            print("✅ [APP INIT] 샘플 \(result.memos.count)개 + 카테고리 \(result.categories.count)개 시드 (persona=\(persona.rawValue))")
            // 시딩 후 리스트가 카테고리/메모를 다시 읽도록 알림 (신규 설치·체험 수락 공통)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .demoSamplesInserted, object: nil)
            }
            return true
        } catch {
            print("❌ [APP INIT] 기본 샘플 삽입 실패: \(error)")
            return false
        }
    }

    /// 신규 설치에서만 자동 삽입. 신규 설치는 데모 질문 대상이 아니므로 resolved로 표시.
    /// 한국어 입력 토글 기본값은 OFF지만, 기존에 키보드 기본 언어를 한국어로 쓰던 사용자는
    /// 토글이 갑자기 사라지지 않도록 1회 자동 활성화한다. (영어 기본 사용자는 OFF 유지 → 한 안 보임)
    private func migrateKoreanEnabledIfNeeded() {
        let g = UserDefaults(suiteName: AppGroup.identifier)
        guard g?.bool(forKey: DefaultsKey.koreanEnabledMigratedV1) != true else { return }
        if g?.string(forKey: DefaultsKey.keyboardTypingLang) == "korean" {
            g?.set(true, forKey: DefaultsKey.keyboardKoreanEnabled)
            print("🔄 [APP INIT] 기존 한국어 사용자 — 한국어 입력 자동 활성화")
        }
        g?.set(true, forKey: DefaultsKey.koreanEnabledMigratedV1)
    }

    /// 기존 평문 보안 메모를 암호화한다(1회). 암호화 키가 아직 없으면 생성된다.
    /// 키 확보 실패(키체인 불가) 시 플래그를 세우지 않아 다음 실행에서 재시도.
    private func migrateSecureMemoEncryptionIfNeeded() {
        let g = UserDefaults(suiteName: AppGroup.identifier)
        guard g?.bool(forKey: DefaultsKey.secureMemoEncryptionMigratedV1) != true else { return }
        do {
            var memos = try MemoStore.shared.load(type: .memo)
            var changed = false
            var allEncrypted = true
            for i in memos.indices where memos[i].isSecure && !SecureMemoCrypto.isEncrypted(memos[i].value) {
                if let enc = SecureMemoCrypto.encrypt(memos[i].value) {
                    memos[i].value = enc
                    changed = true
                } else {
                    allEncrypted = false
                }
            }
            if changed { try MemoStore.shared.save(memos: memos, type: .memo) }
            if allEncrypted {
                g?.set(true, forKey: DefaultsKey.secureMemoEncryptionMigratedV1)
                print("🔐 [APP INIT] 보안 메모 암호화 마이그레이션 완료 (변경: \(changed))")
            } else {
                print("⏳ [APP INIT] 보안 키 미확보 — 다음 실행에서 보안 메모 암호화 재시도")
            }
        } catch {
            print("❌ [APP INIT] 보안 메모 암호화 마이그레이션 실패: \(error)")
        }
    }

    /// 시드 샘플 중 본문에 {변수}가 있는데도 templateVariables가 비어 isTemplate=false가 된
    /// 메모(예: "인사말 + 회신", "송금 안내 + 양식")를 1회 보정한다. 탭 시 하프모달이 뜨도록.
    /// 사용자가 직접 만든 메모(코드/JSON 안의 리터럴 중괄호 등)는 건드리지 않기 위해
    /// SampleMemoStorage가 추적하는 샘플 메모로만 범위를 한정한다.
    private func migrateSampleTemplateFlagsIfNeeded() {
        let g = UserDefaults(suiteName: AppGroup.identifier)
        guard g?.bool(forKey: DefaultsKey.sampleTemplateFlagsMigratedV1) != true else { return }
        do {
            var memos = try MemoStore.shared.load(type: .memo)
            let sampleIds = SampleMemoStorage.load()
            var changed = false
            for i in memos.indices
            where sampleIds.contains(memos[i].id) && memos[i].templateVariables.isEmpty {
                let custom = memos[i].value.extractTemplatePlaceholders()
                if !custom.isEmpty {
                    memos[i].templateVariables = custom
                    changed = true
                    print("🔄 [APP MIGRATION] 샘플 템플릿 플래그 보정: \(memos[i].title) → \(custom)")
                }
            }
            if changed { try MemoStore.shared.save(memos: memos, type: .memo) }
            g?.set(true, forKey: DefaultsKey.sampleTemplateFlagsMigratedV1)
            print("🔄 [APP MIGRATION] 샘플 템플릿 플래그 마이그레이션 완료 (변경=\(changed))")
        } catch {
            print("❌ [APP MIGRATION] 샘플 템플릿 플래그 마이그레이션 실패: \(error)")
        }
    }

    /// 레거시 메모의 콤보/attached 필드만 원본 JSON에서 읽기 위한 경량 디코더.
    /// (신 Memo 모델은 이 키들을 더 이상 디코드하지 않으므로 별도로 읽어야 한다.)
    private struct LegacyMemoFields: Decodable {
        let id: UUID
        var isCombo: Bool = false
        var comboValues: [String] = []
        var attachedTemplateId: UUID?
        enum CodingKeys: String, CodingKey { case id, isCombo, comboValues, attachedTemplateId }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id)
            isCombo = try c.decodeIfPresent(Bool.self, forKey: .isCombo) ?? false
            comboValues = try c.decodeIfPresent([String].self, forKey: .comboValues) ?? []
            attachedTemplateId = try c.decodeIfPresent(UUID.self, forKey: .attachedTemplateId)
        }
    }

    private var appGroupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
    }

    /// 변환되지 않은 레거시 콤보/attached 데이터가 디스크에 남아있는지 빠르게 감지.
    /// (combos.data 존재, 또는 memos.data 원본에 레거시 키가 살아있으면 true.)
    /// CloudKit으로 옛 백업을 복원한 경우처럼 플래그가 이미 set돼 있어도 재변환이 필요한 상황을 잡아낸다.
    private func hasLegacyComboData() -> Bool {
        // 1) 플랫 콤보 파일이 비어있지 않게 존재
        if let url = appGroupContainerURL?.appendingPathComponent(StorageFile.combos),
           let d = try? Data(contentsOf: url), d.count > 2 {
            return true
        }
        // 2) 메모 원본에 레거시 콤보/attached 키가 살아있음 (신 모델 save 후엔 사라짐)
        if let url = appGroupContainerURL?.appendingPathComponent(StorageFile.memos),
           let d = try? Data(contentsOf: url),
           let s = String(data: d, encoding: .utf8) {
            if s.contains("\"isCombo\":true") { return true }
            if s.contains("\"attachedTemplateId\":\"") { return true }
        }
        return false
    }

    /// 콤보/메모+템플릿 데이터 모델 통합 마이그레이션.
    /// - 레거시 메모 내장 콤보(isCombo+comboValues) → 자식 메모 생성 + childMemoIds
    /// - attachedTemplateId → 본문을 합쳐 일반 메모로 (compose)
    /// - 플랫 Combo(combos.data) → childMemoIds를 가진 콤보 Memo
    ///
    /// 하위호환 강화 포인트:
    /// - init 맨 앞 + onAppear + CloudKit 복원 후 모두에서 호출(멱등). 다른 load/save가 레거시 키를
    ///   지우기 전에 원본 JSON에서 먼저 읽는다.
    /// - 플래그가 set돼 있어도 `hasLegacyComboData()`가 참이면 재실행(옛 백업 복원 대비).
    /// - 단일 save로 원자적 적용. 실패 시 플래그 미set → 다음 기회에 재시도.
    private func migrateComboModelIfNeeded() {
        let g = UserDefaults(suiteName: AppGroup.identifier)
        let alreadyMigrated = (g?.bool(forKey: DefaultsKey.comboModelUnifyMigratedV1) == true)
        // 이미 변환됐고 남은 레거시 데이터도 없으면 빠르게 종료.
        guard !alreadyMigrated || hasLegacyComboData() else { return }
        do {
            // 1) 원본 JSON에서 레거시 필드 먼저 읽기 (이후 save로 사라지기 전에).
            //    OldMemo 등 과거 포맷도 id만 있으면 디코드됨(콤보 필드는 기본값).
            var legacyById: [UUID: LegacyMemoFields] = [:]
            if let url = appGroupContainerURL?.appendingPathComponent(StorageFile.memos),
               let data = try? Data(contentsOf: url),
               let legacy = try? JSONDecoder().decode([LegacyMemoFields].self, from: data) {
                for l in legacy { legacyById[l.id] = l }
            }

            var memos = try MemoStore.shared.load(type: .memo)   // 신 모델 (comboValues 보유 메모는 그대로 디코드)
            var converted = false

            // 2) attachedTemplate → 본문 합치기 + dev childMemoIds 콤보 → comboValues.
            //    (레거시 메모 내장 콤보의 comboValues는 모델에 그대로 디코드되어 별도 변환 불필요.)
            let valueById = Dictionary(memos.map { ($0.id, $0.value) }, uniquingKeysWith: { a, _ in a })
            for i in memos.indices {
                if let L = legacyById[memos[i].id],
                   let tId = L.attachedTemplateId,
                   let tmpl = memos.first(where: { $0.id == tId }) {
                    memos[i].value = TemplateVariableProcessor.compose(
                        memoValue: memos[i].value, templateBody: tmpl.value, templateInputs: [:])
                    converted = true
                }
                // dev(미출시)에서 만든 childMemoIds 콤보 → 참조 메모 value를 comboValues 단계로 펼침.
                if memos[i].comboValues.isEmpty, !memos[i].childMemoIds.isEmpty {
                    let steps = memos[i].childMemoIds.compactMap { valueById[$0] }.filter { !$0.isEmpty }
                    if !steps.isEmpty {
                        memos[i].comboValues = steps
                        memos[i].childMemoIds = []
                        converted = true
                    }
                }
            }

            // 3) 플랫 Combo(combos.data) → comboValues를 가진 콤보 Memo (기존 Combo 타입으로 디코드)
            let combos = (try? MemoStore.shared.loadCombos()) ?? []
            for c in combos where !memos.contains(where: { $0.id == c.id }) {
                var steps: [String] = []
                for item in c.items.sorted(by: { $0.order < $1.order }) {
                    if item.type == .memo || item.type == .template,
                       let v = valueById[item.referenceId], !v.isEmpty {
                        steps.append(v)
                    } else {
                        let v = item.displayValue ?? ""
                        let t = (item.displayTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !v.isEmpty { steps.append(v) } else if !t.isEmpty { steps.append(t) }
                    }
                }
                guard !steps.isEmpty else { continue }   // 빈 콤보는 만들지 않음
                var comboMemo = Memo(
                    id: c.id, title: c.title, value: "",
                    isFavorite: c.isFavorite, category: c.category,
                    comboValues: steps, comboInterval: c.interval, lastUsedAt: c.lastUsed)
                comboMemo.clipCount = c.useCount
                memos.append(comboMemo)
                converted = true
            }
            // 변경이 있을 때만 저장(불필요한 디스크 쓰기 방지).
            if converted {
                try MemoStore.shared.save(memos: memos, type: .memo)
            }

            // 4) combos.data 삭제(없으면 무시) + 플래그
            if let url = appGroupContainerURL?.appendingPathComponent(StorageFile.combos) {
                try? FileManager.default.removeItem(at: url)
            }
            g?.set(true, forKey: DefaultsKey.comboModelUnifyMigratedV1)
            print("🔄 [APP MIGRATION] 콤보 모델 통합 완료 (변경=\(converted))")
        } catch {
            print("❌ [APP MIGRATION] 콤보 모델 마이그레이션 실패: \(error)")
        }
    }

    /// 구 "카테고리 심볼" 토글(categoryBadgeVisible, standard UD)을 신 마스터 토글
    /// showVisualCues(App Group)로 1회 승계. 켜둔 사용자는 계속 구분 표시가 보이도록.
    private func migrateVisualCuesIfNeeded() {
        let std = UserDefaults.standard
        guard !std.bool(forKey: DefaultsKey.visualCuesMigratedV1) else { return }
        if std.object(forKey: DefaultsKey.categoryBadgeVisible) as? Bool == true {
            UserDefaults(suiteName: AppGroup.identifier)?.set(true, forKey: DefaultsKey.showVisualCues)
        }
        std.set(true, forKey: DefaultsKey.visualCuesMigratedV1)
    }

    private func insertDefaultSamplesIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: samplesInsertedKey) else { return }
        if performSampleInsertion() {
            UserDefaults.standard.set(true, forKey: samplesInsertedKey)
            UserDefaults.standard.set(true, forKey: demoOfferResolvedKey)
        }
    }

    /// 이미 설치돼 자동 삽입을 못 받은 기존 사용자에게만 1회 체험을 묻는다.
    private func offerDemoSamplesToExistingUserIfNeeded() {
        guard UserDefaults.standard.bool(forKey: samplesInsertedKey),
              !UserDefaults.standard.bool(forKey: demoOfferResolvedKey) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showDemoSampleOffer = true
        }
    }

    /// 새 기기(또는 재설치) 첫 실행에서 "기존에 쓰던 메모를 불러올 수 있어요"를 1회 안내한다.
    /// 조건: ① 아직 안내 안 함, ② 시작 시 로컬에 내 메모가 없었음(새 기기 신호),
    ///       ③ iCloud에 실제 백업이 존재함(복원할 게 있을 때만 안내 — 신규 유저에겐 안 뜸).
    /// 안내는 한 번만(표시 시 플래그 기록). 백업이 아직 확인 안 되면 다음 실행에서 재시도.
    private func offerRestoreHintIfNeeded(localWasEmpty: Bool) {
        guard !UserDefaults.standard.bool(forKey: restoreHintShownKey) else { return }
        guard localWasEmpty else { return }   // 이미 내 메모가 있는 기기면 안내 불필요
        Task {
            let hasBackup = await CloudKitBackupService.shared.hasBackup()
            guard hasBackup else { return }   // 복원할 백업이 없으면 안내하지 않음(플래그도 유지)
            await MainActor.run {
                guard !showDemoSampleOffer else { return }   // 다른 모달과 중첩 방지
                UserDefaults.standard.set(true, forKey: restoreHintShownKey)
                showRestoreHint = true
            }
        }
    }

    private func generalSamples(isKorean: Bool) -> (memos: [Memo], categories: [String]) {
        let work = isKorean ? "업무" : "Work"
        let personal = isKorean ? "개인" : "Personal"
        // 1) 일반 메모 (즐겨찾기) — 기본 제공되는 즐겨찾기 탭에 바로 들어가 분홍으로 표시
        let memo = Memo(
            title: isKorean ? "내 이메일" : "My Email",
            value: "example@email.com",
            isFavorite: true
        )
        // 2) 템플릿 — 본문에 {변수}가 있으면 자동으로 템플릿(templateVariables로 판정)
        let template = Memo(
            title: isKorean ? "회신 템플릿" : "Reply Template",
            value: isKorean
                ? "{이름}님, 문의 주셔서 감사합니다.\n{날짜}까지 답변드릴게요."
                : "Hi {name}, thanks for reaching out.\nI'll reply by {date}.",
            category: work,
            templateVariables: isKorean ? ["{이름}"] : ["{name}"]
        )
        // 3) 콤보 — 메모 안에 순서 있는 단계들(comboValues)
        let combo = Memo(
            title: isKorean ? "이름 + 연락처" : "Name + Contact",
            value: "",
            category: personal,
            comboValues: isKorean ? ["홍길동", "010-0000-0000"] : ["John Doe", "555-0000"]
        )
        // 4) 인사말 + 회신 양식을 한 메모로 합침 — 본문에 {변수}가 있으므로 템플릿이어야 한다.
        //    templateVariables를 넘기지 않으면 isTemplate=false가 되어 탭 시 {변수}가
        //    그대로 복사되는 버그가 생긴다. 합쳐진 본문의 커스텀 토큰을 그대로 사용.
        let memoWithTemplate = Memo(
            title: isKorean ? "인사말 + 회신" : "Greeting + Reply",
            value: (isKorean ? "안녕하세요, 연락 주셔서 반갑습니다!" : "Hi, great to hear from you!") + "\n" + template.value,
            category: work,
            templateVariables: template.templateVariables
        )
        return ([memo, template, combo, memoWithTemplate], [work, personal])
    }

    private func nomadSamples(isKorean: Bool) -> (memos: [Memo], categories: [String]) {
        let finance = isKorean ? "금융" : "Finance"
        let travel = isKorean ? "여행" : "Travel"
        let template = Memo(
            title: isKorean ? "국제 송금 양식" : "Bank Transfer",
            value: isKorean
                ? "{금액}을 {수신인}에게 보냅니다\nIBAN: {iban}\nSWIFT: {swift}\n참조: {참조번호}"
                : "Pay {amount} to {recipient}\nIBAN: {iban}\nSWIFT: {swift}\nRef: {reference}",
            category: finance,
            templateVariables: isKorean
                ? ["{금액}", "{수신인}", "{iban}", "{swift}", "{참조번호}"]
                : ["{amount}", "{recipient}", "{iban}", "{swift}", "{reference}"]
        )
        let combo = Memo(
            title: isKorean ? "내 연락처" : "My Contact",
            value: "",
            category: travel,
            comboValues: isKorean ? ["이름", "이메일", "전화번호"] : ["Full Name", "Email", "Phone"]
        )
        // 즐겨찾기 — 기본 제공되는 즐겨찾기 탭에 바로 들어가 분홍으로 표시
        let checklist = Memo(
            title: isKorean ? "여행 체크리스트" : "Travel Checklist",
            value: isKorean
                ? "여권 ✓\n비자 ✓\n여행자보험 ✓\n긴급 연락처: "
                : "Passport ✓\nVisa ✓\nTravel Insurance ✓\nEmergency Contact: ",
            isFavorite: true
        )
        // 고정 안내문 + 송금 양식을 한 메모로 합침 — 본문에 {변수}가 있으므로 템플릿이어야 한다.
        let noteWithTemplate = Memo(
            title: isKorean ? "송금 안내 + 양식" : "Payment note + form",
            value: (isKorean ? "아래 계좌로 송금 부탁드립니다." : "Please send payment to the account below.") + "\n" + template.value,
            category: finance,
            templateVariables: template.templateVariables
        )
        return ([template, combo, checklist, noteWithTemplate], [finance, travel])
    }

    var body: some Scene {
        WindowGroup {
            // 테스트 호스트: 무거운 화면/onAppear 마이그레이션 없이 빈 뷰만 띄워
            // 테스트 러너가 즉시 연결되게 한다. (ViewBuilder 조건 분기)
            if ClipKeyboardApp.isRunningUnitTests {
                Color.clear
            } else {
            AppThemedContainer {
            ClipKeyboardList()
                .environmentObject(storeManager)
                #if targetEnvironment(macCatalyst)
                .frame(minWidth: 520, minHeight: 640)
                #endif
                .onOpenURL { url in
                    handleOpenURL(url)
                }
                .onAppear {
                    // 샘플 삽입 전에 "이 기기에 원래 내 메모가 있었는지"를 먼저 본다.
                    // (없으면 새 기기일 가능성 → 백업 복원 안내 대상)
                    let localWasEmpty = ((try? MemoStore.shared.load(type: .memo)) ?? []).isEmpty

                    migrateComboModelIfNeeded()
                    migrateVisualCuesIfNeeded()
                    migrateKoreanEnabledIfNeeded()
                    migrateSecureMemoEncryptionIfNeeded()
                    insertDefaultSamplesIfNeeded()
                    migrateSampleTemplateFlagsIfNeeded()
                    offerDemoSamplesToExistingUserIfNeeded()
                    offerRestoreHintIfNeeded(localWasEmpty: localWasEmpty)

                    // 메모 실시간 동기화 시작(Pro + 플래그 ON일 때만). 시작 시 원격을 당겨온다.
                    MemoSyncEngine.shared.startIfEnabled()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        // 데모 체험 질문이 떠 있으면 리뷰 요청은 양보 (모달 중첩 방지)
                        if !showDemoSampleOffer, ReviewManager.shared.shouldShowReview() {
                            showReviewRequest = true
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        checkVoiceOverAndNudge()
                    }
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIAccessibility.voiceOverStatusDidChangeNotification
                    )
                ) { _ in
                    checkVoiceOverAndNudge()
                }
                .onChange(of: scenePhase) { _, phase in
                    // 앱이 다시 앞으로 오면 즉시 동기화 — 다른 기기의 최신 메모를 바로 반영.
                    // (start는 멱등 — 토글이 KV로 전파돼 막 켜진 경우 여기서 시작될 수 있음.)
                    if phase == .active {
                        MemoSyncEngine.shared.startIfEnabled()
                        MemoSyncEngine.shared.syncNow()
                    }
                }
                .sheet(isPresented: $showReviewRequest) {
                    ReviewRequestView()
                        .presentationDetents([.medium])
                }
                .sheet(isPresented: $showAccessibilityGuide) {
                    AccessibilityGuideView()
                }
                .alert(
                    NSLocalizedString("이런 기능도 있어요", comment: "Demo samples offer title"),
                    isPresented: $showDemoSampleOffer
                ) {
                    Button(NSLocalizedString("체험해 보기", comment: "Demo samples offer accept")) {
                        // performSampleInsertion 내부에서 .demoSamplesInserted 알림을 발행해 리스트가 갱신됨
                        performSampleInsertion()
                        UserDefaults.standard.set(true, forKey: demoOfferResolvedKey)
                    }
                    Button(NSLocalizedString("괜찮아요", comment: "Demo samples offer decline"), role: .cancel) {
                        UserDefaults.standard.set(true, forKey: demoOfferResolvedKey)
                    }
                } message: {
                    Text(NSLocalizedString("템플릿·콤보·메모+템플릿 예시 4개를 추가해 직접 써볼 수 있어요. 기존 메모는 그대로 유지돼요.", comment: "Demo samples offer message"))
                }
                .alert(
                    NSLocalizedString("기존 메모를 불러올 수 있어요", comment: "Restore hint title"),
                    isPresented: $showRestoreHint
                ) {
                    Button(NSLocalizedString("불러오기", comment: "Restore hint: open restore")) {
                        showCloudBackupSheet = true
                    }
                    Button(NSLocalizedString("나중에", comment: "Restore hint: dismiss"), role: .cancel) { }
                } message: {
                    Text(NSLocalizedString("기존에 쓰던 메모를 불러오는 방법이 있습니다. iCloud 백업에서 복원할 수 있어요.", comment: "Restore hint message"))
                }
                .sheet(isPresented: $showCloudBackupSheet) {
                    NavigationStack { CloudBackupView() }
                }
        } // AppThemedContainer
            } // else (비테스트 실행)

        }
        #if targetEnvironment(macCatalyst)
        .defaultSize(width: 620, height: 780)
        #endif
        #if targetEnvironment(macCatalyst)
        .commands {
            // 클립키보드 전용 메뉴
            // v4.2: ⌃⇧ (Control+Shift) + 영문자 3-key 조합으로 통일.
            // Mac에서 Control+Shift 계열 단축키는 거의 표준 바인딩이 없어
            // 타 유틸(Raycast/Maccy/Alfred 등)과 충돌 가능성이 낮음.
            CommandMenu(NSLocalizedString("ClipKeyboard", comment: "App menu name")) {
                Button(NSLocalizedString("Memo List", comment: "Menu: memo list")) {
                    NotificationCenter.default.post(name: .showMemoList, object: nil)
                }
                .keyboardShortcut("m", modifiers: [.control, .shift])

                Button(NSLocalizedString("New Memo", comment: "Menu: new memo")) {
                    NotificationCenter.default.post(name: .showNewMemo, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.control, .shift])

                Divider()

                Button(NSLocalizedString("Clipboard History", comment: "Menu: clipboard history")) {
                    NotificationCenter.default.post(name: .showClipboardHistory, object: nil)
                }
                .keyboardShortcut("h", modifiers: [.control, .shift])

                Button(NSLocalizedString("Paywall", comment: "Menu: paywall")) {
                    NotificationCenter.default.post(name: .showPaywall, object: nil)
                }

                Divider()

                Button(NSLocalizedString("Preferences…", comment: "Menu: preferences")) {
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandGroup(replacing: .help) {
                Button(NSLocalizedString("ClipKeyboard Help", comment: "Menu: help")) {
                    if let url = URL(string: "https://m1zz.github.io/ClipKeyboard/tutorial.html") {
                        #if targetEnvironment(macCatalyst)
                        UIApplication.shared.open(url)
                        #endif
                    }
                }
            }
        }
        #endif
    }

    // MARK: - Accessibility Nudge

    /// VoiceOver가 켜진 상태로 앱에 진입하면 최초 1회 접근성 안내 시트를 띄운다.
    private func checkVoiceOverAndNudge() {
        #if os(iOS)
        let nudgeKey = "a11y_guide_nudge_shown_v1"
        guard UIAccessibility.isVoiceOverRunning,
              !(UserDefaults.standard.bool(forKey: nudgeKey)) else { return }
        UserDefaults.standard.set(true, forKey: nudgeKey)
        // 리뷰 시트와 겹치지 않도록 약간 지연
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showAccessibilityGuide = true
        }
        #endif
    }

    // MARK: - URL Scheme Handler

    private func handleOpenURL(_ url: URL) {
        guard url.scheme == "clipkeyboard" else { return }
        print("🔗 [URL] App opened with URL: \(url)")

        if url.host == "copy", let idString = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "id" })?.value,
           let memoId = UUID(uuidString: idString) {
            // 위젯에서 메모 복사 요청
            copyMemoToClipboard(memoId: memoId)
        } else if url.host == "paywall" {
            // 키보드 익스텐션에서 paywall 직행 요청 (v4.0)
            NotificationCenter.default.post(name: .showPaywall, object: nil)
        }
    }

    private func copyMemoToClipboard(memoId: UUID) {
        let store = MemoStore.shared
        if store.memos.isEmpty {
            try? store.memos = store.load(type: .memo)
        }

        guard let memo = store.memos.first(where: { $0.id == memoId }) else {
            print("⚠️ [Widget Copy] 메모를 찾을 수 없음: \(memoId)")
            return
        }

        #if os(iOS)
        // 위젯은 보안 메모를 노출하지 않지만, 방어적으로 암호문이면 복호화(키 없으면 중단).
        let widgetValue: String
        if SecureMemoCrypto.isEncrypted(memo.value) {
            guard let dec = SecureMemoCrypto.decrypt(memo.value) else {
                print("🔒 [Widget Copy] 보안 키 미동기화 - 복사 중단")
                return
            }
            widgetValue = dec
        } else {
            widgetValue = memo.value
        }
        UIPasteboard.general.string = widgetValue
        print("✅ [Widget Copy] 클립보드에 복사됨: \(memo.title)")

        // 복사 완료 햅틱 피드백
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    #if targetEnvironment(macCatalyst)
    private func setupMacCatalystCommands() {
        print("⌨️ [MAC CATALYST] 단축키 설정 완료")

        // 메뉴바 아이콘 설정
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            MenuBarManager.shared.setupMenuBar()
        }

        // 전역 핫키 등록
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            GlobalHotkeyManager.shared.registerGlobalHotkey()
        }
    }
    #endif
}
