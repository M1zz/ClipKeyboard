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
#endif
