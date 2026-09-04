//
//  OCRService.swift
//  ClipKeyboard
//

import Foundation

// MARK: - OCR Service

#if os(iOS)
import UIKit
import Vision

class OCRService {
    static let shared = OCRService()

    private init() {}

    /// 이미지에서 텍스트 인식
    func recognizeText(from image: UIImage, completion: @escaping ([String]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }

        let request = VNRecognizeTextRequest { (request, error) in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                completion([])
                return
            }

            let recognizedTexts = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }

            DispatchQueue.main.async {
                completion(recognizedTexts)
            }
        }

        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("❌ [OCR] 텍스트 인식 실패: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }

    /// 문단(블록) 단위 텍스트 인식 - 줄 사이 세로 간격이 중간값 줄 높이보다 크면
    /// 문단이 바뀐 것으로 보고 블록을 나눈다. 메모 앱 스크린샷처럼
    /// "빈 줄로 구분된 항목들"을 가져올 때 빈 줄 정보를 복원하는 용도.
    func recognizeBlocks(from image: UIImage, completion: @escaping ([[String]]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }

        let request = VNRecognizeTextRequest { (request, error) in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            // Vision 좌표계는 좌하단 원점 - 위에서 아래 순으로 정렬
            let sorted = observations.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            let heights = sorted.map { $0.boundingBox.height }.sorted()
            let medianHeight = heights.isEmpty ? 0 : heights[heights.count / 2]

            var blocks: [[String]] = []
            var current: [String] = []
            var prevMinY: CGFloat?
            for obs in sorted {
                guard let text = obs.topCandidates(1).first?.string else { continue }
                if let prev = prevMinY {
                    let gap = prev - obs.boundingBox.maxY
                    if gap > medianHeight * 0.9, !current.isEmpty {
                        blocks.append(current)
                        current = []
                    }
                }
                current.append(text)
                prevMinY = obs.boundingBox.minY
            }
            if !current.isEmpty { blocks.append(current) }

            DispatchQueue.main.async { completion(blocks) }
        }

        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("❌ [OCR] 블록 인식 실패: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }

    /// 카드 정보 파싱
    func parseCardInfo(from texts: [String]) -> [String: String] {
        var result: [String: String] = [:]

        for text in texts {
            let cleaned = text
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")

            if cleaned.range(of: "^[0-9]{13,19}$", options: .regularExpression) != nil {
                let formatted = cleaned.enumerated().map { (index, char) -> String in
                    return (index > 0 && index % 4 == 0) ? "-\(char)" : String(char)
                }.joined()
                result["카드번호"] = formatted
            }

            if let match = text.range(of: "(0[1-9]|1[0-2])/([0-9]{2})", options: .regularExpression) {
                result["유효기간"] = String(text[match])
            }
        }

        return result
    }

    /// 주소 정보 파싱
    func parseAddress(from texts: [String]) -> String {
        let addressKeywords = ["시", "도", "구", "동", "로", "길", "번지", "아파트", "빌딩", "타워", "층", "호"]
        var addressComponents: [String] = []

        for text in texts {
            if addressKeywords.contains(where: { text.contains($0) }) {
                addressComponents.append(text)
            }

            if text.range(of: "^[0-9]{5}$", options: .regularExpression) != nil {
                addressComponents.insert(text, at: 0)
            }
        }

        return addressComponents.joined(separator: " ")
    }
}

// MARK: - 낱말 단위 인식 (문질러 담기)

/// 사진에서 읽어낸 글자 한 조각과 그 조각이 사진에서 놓인 자리.
///
/// 왜 자리까지 아는가: 읽은 글자를 통째로 값에 부으면 사용자는 지우는 일을 하게 된다.
/// 손가락이 지나간 곳만 담으려면 **글자가 사진의 어디에 있는지**를 알아야 한다.
struct RecognizedTextPiece: Identifiable, Hashable {
    let id = UUID()
    let text: String
    /// 정규화 좌표(0~1), **좌상단 원점**. Vision 의 좌하단 원점을 뒤집어 둔 값이라
    /// SwiftUI 좌표에 바로 곱해 쓸 수 있다.
    let box: CGRect
    /// 원문에서 이 조각 뒤에 띄어쓰기가 있었는지. 이어 붙일 때 그대로 살린다.
    let hasTrailingSpace: Bool
}

/// 사진에서 읽어낸 한 줄. 조각들은 **읽는 순서**(왼쪽에서 오른쪽)로 들어 있다.
struct RecognizedTextLine: Identifiable, Hashable {
    let id = UUID()
    let text: String
    /// 정규화 좌표(0~1), 좌상단 원점.
    let box: CGRect
    let pieces: [RecognizedTextPiece]
}

/// 사진 한 장에서 읽어낸 글자 전부. 줄은 위에서 아래 순으로 들어 있다.
struct RecognizedTextLayout {
    let lines: [RecognizedTextLine]

    var isEmpty: Bool { lines.isEmpty }

    /// 사진에 보이는 순서 그대로의 모든 조각.
    var allPieces: [RecognizedTextPiece] { lines.flatMap(\.pieces) }

    /// 줄 단위 글자만. 손가락 대신 목록에서 고르는 길(`PhotoValuePicker`)에 넘긴다.
    var plainLines: [String] {
        lines.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
             .filter { !$0.isEmpty }
    }

    /// 고른 조각들을 사진에 보이는 순서대로 이어 붙인다.
    ///
    /// - Parameter keepLineBreaks: 줄이 바뀐 자리를 줄바꿈으로 살릴지. 끄면 한 줄로 이어 붙인다
    ///   (계좌번호처럼 한 값이 두 줄에 걸쳐 있을 때 필요하다).
    func joinedText(selecting selected: Set<UUID>, keepLineBreaks: Bool) -> String {
        var picked: [String] = []

        for line in lines {
            var buffer = ""
            for piece in line.pieces where selected.contains(piece.id) {
                buffer += piece.text
                if piece.hasTrailingSpace { buffer += " " }
            }
            let trimmed = buffer.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { picked.append(trimmed) }
        }

        return picked.joined(separator: keepLineBreaks ? "\n" : " ")
    }
}

extension OCRService {

    /// 사진의 글자를 **줄 + 조각** 구조로 읽는다.
    ///
    /// `recognizeText` 와 무엇이 다른가: 저쪽은 글자만 준다. 이쪽은 조각마다 사진에서의
    /// 자리를 함께 주므로, 손가락이 지나간 곳의 글자만 골라낼 수 있다.
    func recognizeLayout(from image: UIImage, completion: @escaping (RecognizedTextLayout) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(RecognizedTextLayout(lines: []))
            return
        }

        // ⚠️ 방향을 반드시 넘긴다. 카메라로 세로로 찍은 사진은 픽셀이 눕혀져 있어,
        //    방향 없이 읽으면 글자는 읽혀도 **네모의 자리가 90도 어긋난다.**
        let orientation = Self.cgOrientation(from: image.imageOrientation)

        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async { completion(RecognizedTextLayout(lines: [])) }
                return
            }
            let lines = Self.makeLines(from: observations)
            print("✅ [OCRService.recognizeLayout] 줄 \(lines.count)개 · 조각 \(lines.reduce(0) { $0 + $1.pieces.count })개")
            DispatchQueue.main.async {
                completion(RecognizedTextLayout(lines: lines))
            }
        }

        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("❌ [OCRService.recognizeLayout] 낱말 인식 실패: \(error)")
                DispatchQueue.main.async { completion(RecognizedTextLayout(lines: [])) }
            }
        }
    }

    // MARK: - Private Helpers

    /// 인식 결과를 줄 + 조각으로 옮긴다. 순서는 **사진에 보이는 순서**를 지킨다.
    private static func makeLines(from observations: [VNRecognizedTextObservation]) -> [RecognizedTextLine] {
        var lines: [RecognizedTextLine] = []

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let lineText = candidate.string
            guard !lineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let lineBox = flip(observation.boundingBox)

            var pieces: [RecognizedTextPiece] = []
            var cursor = lineText.startIndex
            while cursor < lineText.endIndex {
                if lineText[cursor] == " " {
                    cursor = lineText.index(after: cursor)
                    continue
                }
                let tokenEnd = lineText[cursor...].firstIndex(of: " ") ?? lineText.endIndex
                pieces.append(contentsOf: splitToken(cursor..<tokenEnd,
                                                     in: lineText,
                                                     candidate: candidate,
                                                     fallback: lineBox,
                                                     trailingSpace: tokenEnd < lineText.endIndex))
                cursor = tokenEnd
            }

            // 띄어쓰기가 하나도 없는 줄이라도 통째로는 고를 수 있어야 한다.
            if pieces.isEmpty {
                pieces = [RecognizedTextPiece(text: lineText, box: lineBox, hasTrailingSpace: false)]
            }

            lines.append(RecognizedTextLine(text: lineText, box: lineBox, pieces: pieces))
        }

        // 위 → 아래, 같은 높이면 왼쪽 → 오른쪽 (좌상단 원점이므로 midY 오름차순)
        lines.sort {
            if abs($0.box.midY - $1.box.midY) > min($0.box.height, $1.box.height) * 0.5 {
                return $0.box.midY < $1.box.midY
            }
            return $0.box.minX < $1.box.minX
        }
        return lines
    }

    /// 한 어절을 조각으로 나눈다.
    ///
    /// 긴 어절(하이픈 없는 계좌번호·URL)은 몇 글자씩 쪼갠다. 통째로만 고를 수 있으면
    /// "앞 열 자리만" 같은 일을 손으로 지워야 한다.
    private static func splitToken(_ range: Range<String.Index>,
                                   in text: String,
                                   candidate: VNRecognizedText,
                                   fallback: CGRect,
                                   trailingSpace: Bool) -> [RecognizedTextPiece] {
        let tokenLength = text.distance(from: range.lowerBound, to: range.upperBound)
        guard tokenLength > Self.longTokenThreshold else {
            return [makePiece(range, in: text, candidate: candidate, fallback: fallback, trailingSpace: trailingSpace)]
        }

        var result: [RecognizedTextPiece] = []
        var start = range.lowerBound
        while start < range.upperBound {
            let end = text.index(start, offsetBy: Self.chunkLength, limitedBy: range.upperBound) ?? range.upperBound
            let isLast = end >= range.upperBound
            result.append(makePiece(start..<end,
                                    in: text,
                                    candidate: candidate,
                                    fallback: fallback,
                                    trailingSpace: isLast && trailingSpace))
            start = end
        }
        return result
    }

    private static func makePiece(_ range: Range<String.Index>,
                                  in text: String,
                                  candidate: VNRecognizedText,
                                  fallback: CGRect,
                                  trailingSpace: Bool) -> RecognizedTextPiece {
        let box = (try? candidate.boundingBox(for: range))?.boundingBox
        return RecognizedTextPiece(text: String(text[range]),
                                   box: box.map(flip) ?? fallback,
                                   hasTrailingSpace: trailingSpace)
    }

    /// 이 글자 수를 넘는 어절만 쪼갠다.
    private static let longTokenThreshold = 10
    /// 쪼갤 때 한 조각의 글자 수. 너무 잘게 쪼개면 손가락으로 하나만 짚기 어렵다.
    private static let chunkLength = 5

    /// Vision(좌하단 원점) → 좌상단 원점 정규화 좌표.
    private static func flip(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.origin.x,
               y: 1 - rect.origin.y - rect.height,
               width: rect.width,
               height: rect.height)
    }

    private static func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
#endif
