//
//  ExperimentService.swift
//  ClipKeyboard
//
//  A/B 테스트 최소 기반 — 새 인프라 없이 **이미 있는 것 두 개만** 조합한다.
//   ① 설치 UUID(`leeo.usage.installID`) → 안정적인 그룹 배정
//   ② 사용 통계 이벤트 슬라이스 → 그룹별 결과 비교
//
//  설계 원칙
//   ⚠️ **로컬에서 결정한다.** 서버에 물어보지 않으므로 네트워크가 없어도, 첫 실행에도
//      즉시 그룹이 정해진다. 원격 조회를 기다리면 그 사이 화면이 깜빡이거나 배정이
//      실행마다 달라진다.
//   ⚠️ **같은 설치는 항상 같은 그룹.** 설치 ID 해시로 정하므로 재실행해도 안 바뀐다.
//      실행마다 그룹이 바뀌면 데이터가 통째로 무의미해진다.
//   ⚠️ 실험은 `RemoteFlagsService` 로 끌 수 있다 — 실험이 사고를 내면 즉시 대조군으로.
//
//  결과 보는 법
//   이벤트 이름에 그룹이 슬라이스로 붙는다: `paywall_view:exp_paywall_copy_b`
//   → 사용 통계 화면의 이벤트 목록에서 그룹별 설치 수를 그대로 비교하면 된다.
//
//  ⚠️ 한계: 표본이 작으면(설치 수십 곳) 차이는 대부분 잡음이다.
//     최소 각 그룹 100설치 이상에서만 결론을 내릴 것.
//

import Foundation
import CryptoKit

enum ExperimentService {

    /// 진행 중인 실험. 끝난 실험은 **지우지 말고 주석으로 결과를 남긴 뒤** 제거한다.
    enum Experiment: String, CaseIterable {
        /// 페이월 문구 A/B — 첫 실험.
        case paywallCopy = "paywall_copy"

        /// 이 실험이 나뉘는 그룹 수 (현재는 전부 2개: a/b).
        var variantCount: Int { 2 }
    }

    enum Variant: String {
        case a, b
        /// 이벤트 슬라이스에 붙는 라벨.
        var slice: String { rawValue }
    }

    /// 설치 ID를 못 읽는 경우(이론상 첫 실행 직전)에 쓰는 기본 그룹 — 항상 대조군.
    private static let fallback: Variant = .a

    /// 이 설치의 그룹. **결정적**이다 — 같은 설치 ID면 언제 호출해도 같은 값.
    static func variant(for experiment: Experiment) -> Variant {
        guard RemoteFlagsService.cachedValue(.paywallEnabled) else { return fallback }
        guard let installID = installID else { return fallback }

        // 실험 이름을 섞어 해시한다 — 안 섞으면 모든 실험에서 같은 설치가 항상
        // 같은 쪽에 배정돼(A만 계속 당첨) 실험끼리 상관이 생긴다.
        let digest = SHA256.hash(data: Data("\(experiment.rawValue):\(installID)".utf8))
        let bucket = digest.withUnsafeBytes { $0.load(as: UInt8.self) }
        return Int(bucket) % experiment.variantCount == 0 ? .a : .b
    }

    /// 이벤트에 붙일 슬라이스 문자열. 예: `exp_paywall_copy_b`
    /// `AnalyticsService.log(_:parameters:)` 의 `source` 파라미터로 넘기면
    /// 이벤트 이름이 `paywall_view:exp_paywall_copy_b` 가 된다.
    static func slice(for experiment: Experiment) -> String {
        "exp_\(experiment.rawValue)_\(variant(for: experiment).slice)"
    }

    // MARK: - 내부

    /// LeeoKit 이 만들어 둔 설치 UUID. 실험 배정에만 쓰고 어디에도 저장하지 않는다.
    /// ⚠️ 저장 위치는 `UserDefaults.standard` 다(LeeoUsageReporter 기준) — App Group 이 아니다.
    ///    키가 바뀌면 전 사용자가 그룹을 새로 배정받아 진행 중인 실험이 무효가 된다.
    static let installIDKey = "leeo.usage.installID"

    private static var installID: String? {
        UserDefaults.standard.string(forKey: installIDKey)
    }
}
