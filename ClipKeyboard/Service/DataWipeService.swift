//
//  DataWipeService.swift
//  ClipKeyboard
//
//  "모든 데이터 삭제" - 앱이 기기에 만든 것을 한 번에 지운다.
//
//  왜 필요한가
//   ① GDPR 삭제권 / CCPA 대응. 개인정보 처리방침이 "앱 내에서 데이터를 지우면 영구
//      삭제된다"고 약속하는데, 실제로는 클립보드 히스토리만 전체 삭제가 있었다.
//   ② 심사에서 리뷰어가 찾는 항목이다(사용자 생성 데이터를 지울 수 있는 경로).
//
//  ⚠️ 되돌릴 수 없다. 호출부에서 반드시 2단계 확인을 받을 것.
//  ⚠️ 지우지 **않는** 것: 구매(Pro) 권한 - StoreKit 영수증에 묶여 있어 앱이 지울 수도
//     없고 지워서도 안 된다(사용자가 돈을 낸 것). iCloud 백업도 건드리지 않는다
//     사용자가 명시적으로 만든 사본이므로 CloudBackupView 에서 따로 지운다.
//

import Foundation

enum DataWipeService {

    /// 삭제 결과 - 화면에 무엇이 지워졌는지 보여주기 위한 요약.
    struct Result {
        var deletedFiles: [String] = []
        var deletedImageCount: Int = 0
        var failures: [String] = []

        var isCompleteSuccess: Bool { failures.isEmpty }
    }

    /// App Group 컨테이너의 데이터 파일 전부.
    private static let storageFiles: [String] = [
        StorageFile.memos,
        StorageFile.clipboardHistory,
        StorageFile.smartClipboardHistory,
        StorageFile.combos,
        StorageFile.drafts,
        StorageFile.memoHistory,
        StorageFile.quickNotes
    ]

    /// 지워야 하는 App Group UserDefaults 키.
    /// 여기에 남으면 "다 지웠는데 카테고리 탭이 그대로"처럼 유령 상태가 된다.
    private static let groupKeys: [String] = [
        "userDefinedCategories_v1",
        "hiddenCategoryTabs_v1",
        "userCategoryIcons_v1",
        "category.feature.enabled.v1",
        "memoCategoryAssignments_v1"   // 카테고리 사이드카 - 남으면 삭제 후 되살아난다
    ]

    // MARK: - 실행

    /// 모든 사용자 데이터를 지운다. 실패한 항목이 있어도 나머지는 계속 진행한다
    /// (일부만 지워지고 멈추면 오히려 상태가 어긋난다).
    @discardableResult
    static func wipeAll() -> Result {
        var result = Result()
        let fm = FileManager.default

        guard let containerURL = fm.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) else {
            result.failures.append("App Group 컨테이너 접근 실패")
            AppLog.error(.wipe, "❌ [DataWipeService.wipeAll] App Group 컨테이너를 찾을 수 없음")
            return result
        }

        // ① 데이터 파일
        for name in storageFiles {
            let url = containerURL.appendingPathComponent(name)
            guard fm.fileExists(atPath: url.path) else { continue }
            do {
                try fm.removeItem(at: url)
                result.deletedFiles.append(name)
            } catch {
                result.failures.append(name)
                AppLog.error(.wipe, "❌ [DataWipeService.wipeAll] \(name) 삭제 실패: \(error.localizedDescription)")
            }
        }

        // ② 이미지 폴더 (통째로)
        let imagesURL = containerURL.appendingPathComponent("Images")
        if fm.fileExists(atPath: imagesURL.path) {
            let count = (try? fm.contentsOfDirectory(atPath: imagesURL.path).count) ?? 0
            do {
                try fm.removeItem(at: imagesURL)
                result.deletedImageCount = count
            } catch {
                result.failures.append("Images")
                AppLog.error(.wipe, "❌ [DataWipeService.wipeAll] 이미지 폴더 삭제 실패: \(error.localizedDescription)")
            }
        }

        // ③ App Group UserDefaults
        if let group = UserDefaults(suiteName: AppGroup.identifier) {
            for key in groupKeys { group.removeObject(forKey: key) }
        }

        // ④ 플레이스홀더 값 - 키가 `placeholder_values_{이름}` 이라 접두사로 훑는다
        let standard = UserDefaults.standard
        let placeholderKeys = standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("placeholder_values_") }
        for key in placeholderKeys { standard.removeObject(forKey: key) }

        // ⑤ 메모리 상태 비우기 - 화면이 지워진 데이터를 계속 들고 있지 않게
        let store = MemoStore.shared
        DispatchQueue.main.async {
            store.memos = []
            store.clipboardHistory = []
            store.smartClipboardHistory = []
            store.combos = []
        }

        AppLog.info(.wipe, "🗑 [DataWipeService.wipeAll] 파일 \(result.deletedFiles.count)개 · 이미지 \(result.deletedImageCount)개 삭제, 실패 \(result.failures.count)건")
        return result
    }
}
