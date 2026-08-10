//
//  DelightMotion.swift
//  ClipKeyboard
//
//  DOSSIER 컨셉의 delight 레이어 - **모션 예산 단일 출처**.
//
//  핵심 규칙: delight는 빈도의 역수로 배분한다.
//  이 앱의 핵심 동작(문구 입력)은 하루 20~50번 반복되므로,
//  자주 일어나는 일일수록 짧고 조용해야 하고 드문 일에만 연출을 허락한다.
//  등급을 안 지키면 "시간을 아껴주는 앱이 시간을 쓰는" 상태가 된다.
//
//  ⚠️ 색은 여기서 정하지 않는다. 인앱은 Native Neutral을 유지하며
//     AppTheme 토큰(accent/success/danger)만 쓴다. DOSSIER의 버건디·금박은
//     마케팅 표면(스토어·랜딩) 전용이다.
//

import SwiftUI
import LeeoKit

enum Delight {

    // MARK: - 모션 예산

    /// 연출 등급. 값은 지속 시간(초).
    enum Tier {
        /// 매일 20~50회 - 문구 입력, 자동 편철. 눈이 아니라 손끝에만 남는다.
        case daily
        /// 주 1~2회 - 검증 통과, 봉인/개봉. 시선을 끌어도 되지만 작업을 멈추면 안 된다.
        case occasional
        /// 평생 1~2회 - 발급 완료, 기간 요약. 여기서만 화면을 크게 써도 된다.
        case once

        var duration: Double {
            switch self {
            case .daily:      return 0.18
            case .occasional: return 0.42
            case .once:       return 0.90
            }
        }
    }

    /// 등급에 맞는 애니메이션. reduce-motion이면 항상 nil(=즉시 반영).
    static func motion(_ tier: Tier, reduceMotion: Bool) -> Animation? {
        guard !reduceMotion, isEnabled else { return nil }
        switch tier {
        case .daily:
            return .easeOut(duration: tier.duration)
        case .occasional:
            return .spring(response: tier.duration, dampingFraction: 0.72)
        case .once:
            return .spring(response: tier.duration, dampingFraction: 0.82)
        }
    }

    // MARK: - 사용자 토글

    /// 연출·햅틱 마스터 스위치. 기본 켜짐, 설정에서 끌 수 있다.
    /// App Group에 저장해 키보드 익스텐션도 같은 값을 읽는다.
    static var isEnabled: Bool {
        let store = UserDefaults(suiteName: AppGroup.identifier)
        // 값이 없으면(설치 직후) 켜짐이 기본이다.
        guard let value = store?.object(forKey: DefaultsKey.delightEffectsEnabled) as? Bool else {
            return true
        }
        return value
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults(suiteName: AppGroup.identifier)?
            .set(enabled, forKey: DefaultsKey.delightEffectsEnabled)
        AppLog.info(.usage, "🔖 [Delight.setEnabled] 연출 \(enabled ? "켬" : "끔")")
    }

    // MARK: - 햅틱 (동작별 명명 - 세기를 부르지 않는다)

    /// 날인 - 문구가 입력된 순간. 도장은 가벼운 물건이 아니므로 medium 한 번.
    static func stamp() {
        guard isEnabled else { return }
        HapticManager.shared.medium()
    }

    /// 편철 - 복사한 것이 제 칸에 꽂힌 순간.
    static func filed() {
        guard isEnabled else { return }
        HapticManager.shared.selection()
    }

    /// 검증 통과 - 체크섬이 맞았다.
    static func verified() {
        guard isEnabled else { return }
        HapticManager.shared.success()
    }

    /// 검증 실패 - 나무라지 않는다. error가 아니라 soft로 알린다.
    static func rejected() {
        guard isEnabled else { return }
        HapticManager.shared.soft()
    }

    /// 봉함 - 보안 메모를 잠갔다.
    static func sealed() {
        guard isEnabled else { return }
        HapticManager.shared.rigid()
    }

    /// 개봉 - 생체인증으로 열었다.
    static func unsealed() {
        guard isEnabled else { return }
        HapticManager.shared.soft()
    }
}

// MARK: - 잉크 농도

extension Delight {
    /// 사용 횟수를 잉크 농도로 바꾼다 - 많이 쓴 문구일수록 자국이 진하다.
    ///
    /// 숫자를 세어 보여주는 대신 농도로 보여주는 이유: 사용 흔적은 성과가 아니라 애착이다.
    /// 0회는 아예 자국이 없고(0.0), 100회 이상에서 상한(0.5)에 도달해 더는 진해지지 않는다.
    /// 상한을 둔 이유는 리스트가 특정 행만 시커멓게 보이는 것을 막기 위해서다.
    static func inkOpacity(forUseCount count: Int) -> Double {
        guard count > 0 else { return 0 }
        let value = 0.12 + Double(count) * 0.0038
        return min(value, 0.50)
    }
}
