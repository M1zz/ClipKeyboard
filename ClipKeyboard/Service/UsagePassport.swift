//
//  UsagePassport.swift
//  ClipKeyboard
//
//  "비자 페이지" - 사용자가 지나온 자국을 여권처럼 보여주기 위한 집계.
//
//  ⚠️ 새로 수집하는 것이 하나도 없다. `Memo.clipCount` / `Memo.lastUsedAt` 과
//     `KeyboardUsageTracker.totalTimeSavedSeconds()` 는 이미 기기에 쌓여 있다.
//     "데이터 수집 0" 원칙을 깨지 않고 만들 수 있는 유일한 형태라서 이렇게 짰다.
//
//  ⚠️ 순수 함수다 - MemoStore·UserDefaults를 모른다. 화면이 값을 넣어주고,
//     테스트는 같은 입력을 직접 만들어 검증한다.
//
//  ⚠️ 보안 메모는 제목조차 내보내지 않는다(아래 stamps 참고).
//

import Foundation

enum UsagePassport {

    // MARK: - 도장 한 개

    /// 많이 쓴 문구 하나 = 도장 하나.
    struct Stamp: Identifiable, Equatable {
        let id: UUID
        /// 화면에 찍히는 이름. 보안 메모는 내용을 감춘 대체 문구가 들어온다.
        let label: String
        let useCount: Int
        /// 마지막으로 쓴 날. 없으면 기록 이전에 쓰인 것.
        let lastUsedAt: Date?
        /// 이 문구가 지금까지 돌려준 시간(초) - 영수증의 줄 금액.
        let earnedSeconds: Double
        /// 이 문구가 어떤 종류의 이득이었나 - 화면이 "왜 이만큼인가"를 한 줄로 말한다.
        let kind: TimeSavedModel.Kind
    }

    // MARK: - 한 기간의 기록

    struct Summary: Equatable {
        /// 기간 내 총 사용 횟수.
        let totalUses: Int
        /// 누적 절약 시간(초).
        let timeSavedSeconds: Double
        /// 한 번이라도 쓰인 문구 수.
        let usedShortcuts: Int
        /// 만들어만 두고 한 번도 안 쓴 문구 수 - 낮을수록 좋다.
        let unusedShortcuts: Int
        /// 상위 도장들 (많이 쓴 순).
        let stamps: [Stamp]

        /// 보여줄 만한 기록이 쌓였는지. 텅 빈 여권을 자랑처럼 띄우지 않기 위한 문턱.
        var isWorthShowing: Bool { totalUses >= 20 }

        var timeSavedMinutes: Int { Int(timeSavedSeconds) / 60 }
        var timeSavedHours: Int { Int(timeSavedSeconds) / 3600 }
    }

    // MARK: - 집계

    /// 상위 도장 개수 상한 - 여권 한 페이지에 들어갈 만큼만.
    static let stampLimit = 8

    /// 기기에 있는 메모들로 요약을 만든다.
    /// - Parameters:
    ///   - memos: 대상 메모 전체.
    ///   - timeSavedSeconds: `KeyboardUsageTracker.totalTimeSavedSeconds()` 값.
    ///   - limit: 상위 도장 개수.
    static func summary(memos: [Memo],
                        timeSavedSeconds: Double,
                        limit: Int = stampLimit) -> Summary {

        let used = memos.filter { $0.clipCount > 0 }

        // 많이 쓴 순 → 같으면 최근에 쓴 순 → 그래도 같으면 제목 순(정렬이 흔들리지 않게).
        let ranked = used.sorted { lhs, rhs in
            if lhs.clipCount != rhs.clipCount { return lhs.clipCount > rhs.clipCount }
            let l = lhs.lastUsedAt ?? .distantPast
            let r = rhs.lastUsedAt ?? .distantPast
            if l != r { return l > r }
            return lhs.title < rhs.title
        }

        return Summary(
            totalUses: memos.reduce(0) { $0 + $1.clipCount },
            timeSavedSeconds: max(0, timeSavedSeconds),
            usedShortcuts: used.count,
            unusedShortcuts: memos.count - used.count,
            stamps: ranked.prefix(max(0, limit)).map { memo in
                Stamp(id: memo.id,
                      label: displayLabel(for: memo),
                      useCount: memo.clipCount,
                      lastUsedAt: memo.lastUsedAt,
                      earnedSeconds: KeyboardUsageTracker.earnedSeconds(
                        value: memo.value,
                        type: memo.autoDetectedType,
                        useCount: memo.clipCount),
                      kind: TimeSavedModel.kind(value: memo.value, type: memo.autoDetectedType))
            }
        )
    }

    // MARK: - 기간별

    /// 한 기간만 잘라 본 요약.
    ///
    /// ⚠️ **월 원장에서 뽑는다**(`RefundLedger`). 문구별 초와 횟수가 달 단위로 남아 있어
    ///    그 달만 정확히 셀 수 있다. 전체는 원장 이전에 쌓인 것까지 있는 평생 누적을 쓴다.
    ///
    /// ⚠️ **주 단위는 만들지 않았다.** 원장이 달 단위라 거기서 한 주를 오려 내면 그 달
    ///    전체가 딸려와 틀린 수가 찍힌다. `RefundPeriod` 머리말에 같은 이유가 적혀 있고,
    ///    그 원칙을 여기서도 지킨다. 주 단위가 필요하면 **먼저 주 단위로 기록**해야 한다.
    ///
    /// ⚠️ 원장이 생기기 전부터 쓰던 사람은 그 달 값이 비어 있을 수 있다. 그때는 화면이
    ///    "이 달에는 아직"이라고 말해야지, 0을 자랑처럼 띄우면 안 된다.
    static func summary(memos: [Memo],
                        period: RefundPeriod,
                        timeSavedSeconds: Double,
                        now: Date = Date(),
                        limit: Int = stampLimit) -> Summary {
        guard let month = period.month(from: now) else {
            return summary(memos: memos, timeSavedSeconds: timeSavedSeconds, limit: limit)
        }

        let seconds = RefundLedger.entries(forMonthOf: month)
        let uses = RefundLedger.uses(forMonthOf: month)
        let byID = Dictionary(uniqueKeysWithValues: memos.map { ($0.id, $0) })

        // 그 달에 실제로 쓰인 것만. 지운 문구는 원장에 남아 있어도 셀 수 없다
        // (이름을 모르니 도장을 찍을 수 없다). 시간 합계에는 그대로 들어간다.
        let ranked = uses
            .compactMap { id, count -> (Memo, Int, Double)? in
                guard let memo = byID[id], count > 0 else { return nil }
                return (memo, count, seconds[id] ?? 0)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.title < rhs.0.title
            }

        return Summary(
            totalUses: uses.values.reduce(0, +),
            timeSavedSeconds: max(0, seconds.values.reduce(0, +)),
            usedShortcuts: ranked.count,
            // 이 기간에 안 쓴 것 - 만들어만 두고 이번 달에 한 번도 안 꺼낸 문구.
            unusedShortcuts: max(0, memos.count - ranked.count),
            stamps: ranked.prefix(max(0, limit)).map { memo, count, earned in
                Stamp(id: memo.id,
                      label: displayLabel(for: memo),
                      useCount: count,
                      lastUsedAt: memo.lastUsedAt,
                      earnedSeconds: earned,
                      kind: TimeSavedModel.kind(value: memo.value, type: memo.autoDetectedType))
            }
        )
    }

    /// 도장에 찍을 이름.
    /// 보안 메모는 **제목도 내보내지 않는다** - 이 화면은 공유 대상이라 제목이 새어나가면 안 된다.
    /// 제목이 비었으면 이름 없는 문구로 표시한다(값을 대신 쓰지 않는다).
    static func displayLabel(for memo: Memo) -> String {
        if memo.isSecure {
            return NSLocalizedString("잠긴 문구", comment: "Passport stamp label for a locked (secure) shortcut")
        }
        let trimmed = memo.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return NSLocalizedString("이름 없는 문구", comment: "Passport stamp label for an untitled shortcut")
        }
        return trimmed
    }

    // MARK: - 표시 문구

    /// "3시간 47분" 처럼 사람이 읽는 절약 시간. 1분 미만이면 nil.
    static func timeSavedText(seconds: Double) -> String? {
        let total = Int(max(0, seconds))
        guard total >= 60 else { return nil }

        let hours = total / 3600
        let minutes = (total % 3600) / 60

        if hours > 0 {
            return String(format: NSLocalizedString("%d시간 %d분", comment: "Duration: hours and minutes"), hours, minutes)
        }
        return String(format: NSLocalizedString("%d분", comment: "Duration: minutes only"), minutes)
    }

    /// 내역 줄에 쓰는 표기 - **1분 아래도 숫자로 적는다.**
    ///
    /// ⚠️ 큰 숫자(`timeSavedText`)는 1분 아래를 nil 로 돌려준다. 40초를 자랑거리로
    ///    내밀지 않으려는 뜻이고, 그건 그대로 둔다.
    ///
    /// ⚠️ 그런데 **내역 줄에까지 그 규칙을 쓰면** 몇 번 안 써 본 사람의 화면이
    ///    "0분 / 0분" 이 된다. 셈을 펼쳐 보이려고 만든 자리가 "아껴 준 게 없다"는
    ///    말을 하게 되는 것이다. 내역은 자랑이 아니라 **근거**라서, 작아도 있는
    ///    그대로 적어야 한다.
    static func breakdownText(seconds: Double) -> String {
        let total = Int(max(0, seconds.rounded()))
        guard total >= 60 else {
            return String(format: NSLocalizedString("%d초", comment: "Duration: seconds only"), total)
        }
        return timeSavedText(seconds: Double(total)) ?? ""
    }
}
