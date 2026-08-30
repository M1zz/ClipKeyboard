//
//  DiagnosticsService.swift
//  ClipKeyboard
//
//  크래시·행(hang)·성능 가시성 - MetricKit으로 받아 FeedbackHub에 쌓는다.
//
//  왜 Sentry/Crashlytics가 아닌가
//   · 외부 SDK 0개 원칙을 유지한다(개인정보 신고 항목이 늘지 않고, SDK 자체의 수집도 없다).
//   · 피드백·통계가 쓰는 CloudKit 공개 DB가 이미 있어 새 인프라 비용이 사실상 0이다.
//   · **키보드 익스텐션의 메모리 종료(jetsam)까지 잡힌다** - 이 앱에서 가장 위험한 실패
//     모드이고, 서드파티 SDK를 익스텐션에 넣는 건 메모리 예산상 부담이 크다.
//
//  한계 (알고 쓰는 것)
//   · MetricKit 페이로드는 하루 한 번꼴로 **묶여서** 온다 → 실시간 알림용이 아니다.
//     "어제 이 버전에서 크래시가 늘었나"를 보는 용도다.
//   · 시뮬레이터에서는 거의 오지 않는다. 실기기 + 사용자 규모가 있어야 데이터가 쌓인다.
//   · iOS 전용. Mac Catalyst 에서는 MetricKit 진단 페이로드를 주지 않아 비활성이다.
//
//  ⚠️ 개인정보: 콜스택·앱 버전·OS 버전만 보낸다. 사용자 데이터나 식별자는 넣지 않는다.
//     (설치 UUID조차 붙이지 않는다 - 크래시 집계에 필요 없다.)
//     App Privacy 신고는 `NSPrivacyCollectedDataTypeCrashData`(미연결·비추적)로 다룬다.
//

import Foundation
#if canImport(MetricKit) && os(iOS) && !targetEnvironment(macCatalyst)
import MetricKit
import CloudKit

final class DiagnosticsService: NSObject, MXMetricManagerSubscriber {

    static let shared = DiagnosticsService()

    private static let recordType = "CrashReport"
    /// 한 페이로드에서 올리는 최대 진단 건수 - 공개 DB 쓰기 폭주 방지.
    private static let maxReportsPerPayload = 5
    /// 콜스택 문자열 상한 (CloudKit 레코드 비대화 방지).
    ///
    /// 프레임 한 줄이 30자 안팎이라 8000자면 200프레임쯤 들어간다. SwiftUI 스택이
    /// 깊어도 통째로 담기는 크기다. (예전 4000자는 들여쓴 JSON 기준이라 13프레임에서
    /// 끊겼다. `stackString` 머리말 참고)
    private static let maxStackLength = 8000

    private override init() { super.init() }

    /// 앱 실행 시 1회 호출. 구독만 하고 즉시 반환한다(런치 비용 없음).
    func start() {
        MXMetricManager.shared.add(self)
        AppLog.info(.diagnostics, "🩺 [DiagnosticsService.start] MetricKit 구독 시작")
    }

    // MARK: - MXMetricManagerSubscriber

    /// 진단(크래시·행·디스크쓰기 예외) 페이로드. 하루 한 번꼴로 묶여서 온다.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard RemoteFlagsService.cachedValue(.usageReportingEnabled) else { return }

        var reports: [Report] = []
        for payload in payloads {
            // 크래시가 **난** 시각. 레코드 생성 시각은 MetricKit 이 배달한 때라 하루까지
            // 늦고, 그 차이만큼 "언제부터 늘었나"가 통째로 밀린다.
            let occurredAt = payload.timeStampEnd

            reports += payload.crashDiagnostics?.prefix(Self.maxReportsPerPayload).map {
                Report(kind: "crash",
                       detail: $0.terminationReason ?? "-",
                       stack: Self.stackString($0.callStackTree),
                       meta: $0.metaData,
                       occurredAt: occurredAt,
                       // 종료 사유 한 줄로는 같은 크래시를 못 묶는다. 신호·예외 코드가
                       // 있어야 "SIGSEGV 인가 워치독인가"가 갈린다.
                       exceptionType: $0.exceptionType?.stringValue,
                       exceptionCode: $0.exceptionCode?.stringValue,
                       signal: $0.signal?.stringValue)
            } ?? []

            reports += payload.hangDiagnostics?.prefix(Self.maxReportsPerPayload).map {
                Report(kind: "hang",
                       detail: "\($0.hangDuration.value)\($0.hangDuration.unit.symbol)",
                       stack: Self.stackString($0.callStackTree),
                       meta: $0.metaData,
                       occurredAt: occurredAt)
            } ?? []

            reports += payload.diskWriteExceptionDiagnostics?.prefix(Self.maxReportsPerPayload).map {
                Report(kind: "disk_write",
                       detail: "\($0.totalWritesCaused.value)\($0.totalWritesCaused.unit.symbol)",
                       stack: Self.stackString($0.callStackTree),
                       meta: $0.metaData,
                       occurredAt: occurredAt)
            } ?? []
        }

        guard !reports.isEmpty else { return }
        AppLog.info(.diagnostics, "🩺 [DiagnosticsService] 진단 \(reports.count)건 수신 → 허브 전송")
        Task(priority: .utility) { await Self.upload(reports) }
    }

    /// 성능 지표 페이로드. 지금은 요약만 로그로 남긴다.
    /// (지표 적재는 크래시 가시성이 자리잡은 뒤 별도로 - 한 번에 다 넣으면 잡음만 는다.)
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            guard let launch = payload.applicationLaunchMetrics else { continue }
            AppLog.info(.diagnostics, "📈 [DiagnosticsService] 앱 시작 시간 분포: \(launch.histogrammedTimeToFirstDraw)")
        }
    }

    // MARK: - 내부

    private struct Report {
        let kind: String
        let detail: String
        let stack: String
        let meta: MXMetaData?
        /// 진단이 **일어난** 시각(페이로드 구간의 끝). 배달 시각과 다르다.
        let occurredAt: Date
        /// 크래시에만 있다. 멈춤·디스크쓰기는 예외가 아니라 nil 이다.
        var exceptionType: String? = nil
        var exceptionCode: String? = nil
        var signal: String? = nil
    }

    /// MXCallStackTree 를 **프레임 한 줄짜리 텍스트**로 편다. 0번이 죽은 자리다.
    ///
    /// ⚠️ `jsonRepresentation()` 을 그대로 넣지 말 것. 그 JSON 은 들여쓴 중첩 구조라
    ///    프레임 하나가 300자를 먹는다. 상한에 걸리면 남는 건 **뿌리 쪽 13프레임**
    ///    (start → main → 런루프)뿐이고, 정작 죽은 자리인 가장 깊은 프레임은 통째로
    ///    잘려 나간다. 게다가 프레임의 `binaryName` 과 `address` 는 `subFrames`
    ///    **뒤에** 오는 필드라 한 번도 도달하지 못해, 어느 줄이 내 코드인지도 알 수 없다.
    ///    실제로 그렇게 올라온 149건이 전부 분석 불가였다.
    ///    (docs/postmortem/CRASH_STACK_TRUNCATION.md)
    ///
    /// 나오는 모양:
    /// ```
    ///  0 ClipKeyboard +820588
    ///  1 SwiftUI +1042364
    ///  2 UIKitCore +88ac0
    /// ... 뿌리 쪽 42프레임 생략
    /// ```
    private static func stackString(_ tree: MXCallStackTree) -> String {
        stackText(fromJSON: tree.jsonRepresentation())
    }

    /// 위 함수의 알맹이. `MXCallStackTree` 는 만들 수가 없어(생성자가 없다) 여기서
    /// 갈라 둔다. 이렇게 해야 실제 페이로드 모양의 JSON 을 넣어 테스트할 수 있다.
    /// (`ClipKeyboardTests/DiagnosticsStackTests.swift`)
    static func stackText(fromJSON data: Data) -> String {
        let raw = String(data: data, encoding: .utf8) ?? "-"

        let parsed = framesByParsing(data)
        var frames = parsed.frames
        var binaries = parsed.binaries
        // 못 읽었으면 글자로라도 건져 본다. 아래 함수 머리말 참고.
        if frames.isEmpty {
            frames = framesBySalvaging(raw)
            binaries = []
        }
        guard !frames.isEmpty else { return String(raw.prefix(maxStackLength)) }

        // 오프셋을 함수 이름으로 되돌리려면 **어느 dSYM 인지** 알아야 하고, 그걸 가리키는
        // 것이 바이너리 UUID 다. 프레임마다 붙이면 줄 길이가 두 배가 되므로
        // 바이너리마다 한 번, 맨 끝에 모아 적는다.
        let legend = binaries.prefix(12).map { "@ \($0.name) \($0.uuid)" }
        let legendText = legend.isEmpty ? "" : "\n--\n" + legend.joined(separator: "\n")
        // 생략 안내가 들어갈 자리도 남겨 둔다.
        let budget = maxStackLength - legendText.count - 40

        var lines: [String] = []
        var length = 0
        for (index, frame) in frames.enumerated() {
            let line = String(format: "%2d ", index) + frame
            if length + line.count + 1 > budget {
                lines.append("... 뿌리 쪽 \(frames.count - index)프레임 생략")
                break
            }
            lines.append(line)
            length += line.count + 1
        }
        return lines.joined(separator: "\n") + legendText
    }

    /// 제대로 읽는 길. **잎부터** 담긴 프레임 목록과, 거기 나온 바이너리들의 UUID 를 준다.
    private static func framesByParsing(_ data: Data) -> (frames: [String], binaries: [(name: String, uuid: String)]) {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stacks = root["callStacks"] as? [[String: Any]],
              !stacks.isEmpty
        else { return ([], []) }

        // 죽은 스레드부터 본다. `threadAttributed` 가 그 표식이고, 아무 스레드에도
        // 표식이 없으면 첫 스레드를 쓴다(멈춤 진단이 대개 그렇다).
        let attributed = stacks.filter { ($0["threadAttributed"] as? Bool) == true }
        let chosen = attributed.isEmpty ? Array(stacks.prefix(1)) : attributed

        var frames: [String] = []
        var uuids: [String: String] = [:]
        for stack in chosen {
            for frame in (stack["callStackRootFrames"] as? [[String: Any]]) ?? [] {
                flatten(frame, into: &frames, uuids: &uuids)
            }
        }
        // 뿌리에서 잎 순으로 모였다. 뒤집어 **0번이 죽은 자리**가 되게 한다.
        // 크래시 리포트를 읽는 사람은 언제나 거기부터 본다.
        let ordered = Array(frames.reversed())
        // 잎에 가까운 바이너리부터. 범례가 잘려도 내 코드 쪽이 남게 한다.
        var seen = Set<String>()
        var binaries: [(name: String, uuid: String)] = []
        for frame in ordered {
            let name = String(frame.prefix(while: { $0 != " " }))
            guard let uuid = uuids[name], seen.insert(name).inserted else { continue }
            binaries.append((name: name, uuid: uuid))
        }
        return (ordered, binaries)
    }

    /// `JSONSerialization` 이 못 읽을 만큼 깊은 스택을 위한 대비책.
    ///
    /// ⚠️ 이게 없으면 **스택 넘침 크래시를 통째로 놓친다.** 프레임 하나가 사전+배열
    ///    두 겹이라 250프레임 언저리에서 파서의 중첩 한도에 걸리는데, 무한 재귀로 죽은
    ///    스택이 정확히 그 모양으로 온다. 거기서 원문을 덤프하면 예전 버그로 되돌아간다.
    ///
    /// 중괄호만 세어 프레임 경계를 잡는다. **안쪽 프레임이 먼저 닫히므로 닫히는 순서가
    /// 곧 잎에서 뿌리 순서**라 따로 뒤집을 필요가 없다.
    ///
    /// 필드가 나오는 **순서에 기대지 않는다**. 한 프레임 안에서 `binaryName` 이
    /// `subFrames` 앞에 오든 뒤에 오든 같은 결과가 나온다. (JSON 객체의 키 순서는
    /// 약속된 것이 아니고, 실제로 iOS 판마다 다르게 나온 적이 있다)
    ///
    /// 원문이 중간에 잘려 닫히지 못한 프레임도 버리지 않는다. 그쪽이 오히려
    /// 죽은 자리에 가깝다.
    private static func framesBySalvaging(_ raw: String) -> [String] {
        var open: [(name: String?, offset: String?)] = []
        var closed: [(name: String?, offset: String?)] = []

        var inString = false
        var escaped = false
        var token = ""
        var candidateKey: String?
        var pendingKey: String?
        var number = ""

        func closeNumber() {
            defer { number = ""; pendingKey = nil }
            guard !number.isEmpty, pendingKey == "offsetIntoBinaryTextSegment", !open.isEmpty else { return }
            open[open.count - 1].offset = number
        }

        for character in raw {
            if inString {
                if escaped {
                    token.append(character)
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                    if pendingKey == nil {
                        // ':' 앞의 문자열은 키다. 그건 다음 글자에서 확정된다.
                        candidateKey = token
                    } else {
                        if pendingKey == "binaryName", !open.isEmpty {
                            open[open.count - 1].name = token
                        }
                        pendingKey = nil
                    }
                    token = ""
                } else {
                    token.append(character)
                }
                continue
            }

            switch character {
            case "\"":
                inString = true
            case ":":
                pendingKey = candidateKey
                candidateKey = nil
            case "{":
                closeNumber()
                open.append((nil, nil))
                candidateKey = nil
            case "}":
                closeNumber()
                if let frame = open.popLast() { closed.append(frame) }
                candidateKey = nil
            case ",", "]", "[":
                closeNumber()
            default:
                if character.isNumber, pendingKey != nil {
                    number.append(character)
                } else if !character.isWhitespace {
                    // true / false / null 같은 값은 쓸 일이 없다.
                    number = ""
                    if !character.isNumber { pendingKey = pendingKey == "binaryName" ? pendingKey : nil }
                }
            }
        }

        // 잘려서 닫히지 못한 프레임은 안쪽부터 이어 붙인다.
        closed += open.reversed()

        return closed
            .filter { $0.offset != nil }
            .map { "\($0.name ?? "?") +\($0.offset ?? "0")" }
    }

    /// 프레임 트리를 뿌리에서 잎 순으로 편다.
    ///
    /// 표본 스택은 갈라질 수 있어(`subFrames` 가 여럿) 재귀로 훑는다. 크래시 트리는
    /// 대개 일직선이라 실제로는 한 갈래다. 한도를 두는 건 갈라진 트리에서 줄 수가
    /// 터지는 걸 막기 위함이다.
    private static func flatten(_ frame: [String: Any],
                        into out: inout [String],
                                uuids: inout [String: String],
                                limit: Int = 400) {
        guard out.count < limit else { return }

        let name = (frame["binaryName"] as? String) ?? "?"
        let offset = (frame["offsetIntoBinaryTextSegment"] as? NSNumber)?.intValue ?? 0
        out.append("\(name) +\(offset)")
        if name != "?", let uuid = frame["binaryUUID"] as? String { uuids[name] = uuid }

        for sub in (frame["subFrames"] as? [[String: Any]]) ?? [] {
            flatten(sub, into: &out, uuids: &uuids, limit: limit)
        }
    }

    private static func upload(_ reports: [Report]) async {
        let config = ClipKeyboardSpec.feedback
        let database = await CloudKitContainer.publicDatabase(config.containerIdentifier)

        // ⚠️ 이건 **지금 깔려 있는** 버전이지, 죽은 버전이 아니다. MetricKit 은 하루까지
        //    늦게 배달하므로 그 사이에 업데이트가 깔렸으면 옛 버전의 크래시가 새 버전
        //    이름표를 달고 올라온다. 죽은 빌드를 정확히 아는 값은 아래 `buildNumber`
        //    (`MXMetaData.applicationBuildVersion`) 쪽이다. 읽는 쪽은 둘이 어긋나면
        //    버전 이름표를 의심해야 한다.
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"

        for report in reports {
            let record = CKRecord(recordType: recordType)
            record["appId"] = config.appIdentifier
            record["kind"] = report.kind
            record["detail"] = report.detail
            record["appVersion"] = appVersion
            record["osVersion"] = report.meta?.osVersion ?? "-"
            record["deviceType"] = report.meta?.deviceType ?? "-"
            record["stack"] = report.stack

            // 여기부터는 5.0.6 에서 늘린 것들. 옛 레코드에는 없으므로 읽는 쪽은
            // 전부 없을 수 있다고 보고 다뤄야 한다.
            record["occurredAt"] = report.occurredAt
            record["buildNumber"] = report.meta?.applicationBuildVersion ?? "-"
            if let exceptionType = report.exceptionType { record["exceptionType"] = exceptionType }
            if let exceptionCode = report.exceptionCode { record["exceptionCode"] = exceptionCode }
            if let signal = report.signal { record["signal"] = signal }

            do {
                _ = try await database.save(record)
            } catch {
                // 진단 전송 실패로 앱이 시끄러워질 이유는 없다 - 로그만 남기고 넘어간다.
                AppLog.warning(.diagnostics, "⚠️ [DiagnosticsService.upload] \(report.kind) 전송 실패: \(error.localizedDescription)")
            }
        }
    }
}

#else

/// MetricKit이 없는 플랫폼(macOS Catalyst 등)용 빈 구현 - 호출부를 #if로 감싸지 않아도 되게 한다.
final class DiagnosticsService {
    static let shared = DiagnosticsService()
    private init() {}
    func start() { }
}

#endif
