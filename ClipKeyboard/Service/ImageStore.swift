//
//  ImageStore.swift
//  ClipKeyboard
//
//  단축어에 붙인 그림 파일. App Group 의 `Images/` 폴더 하나만 다룬다.
//  상태가 없어 열거형의 정적 함수로 둔다. 앱과 키보드가 같은 문을 쓴다.
//

#if os(iOS)
import UIKit
import ImageIO
import UniformTypeIdentifiers

enum ImageStore {

    enum Failure: Error, LocalizedError {
        case noContainer
        case unencodable

        var errorDescription: String? {
            switch self {
            case .noContainer: return "App Group container not found"
            case .unencodable: return "Could not encode the image"
            }
        }
    }

    // MARK: - 저장

    /// 단축어에 붙인 그림을 저장할 모양으로 만든다. 긴 변 2048px, 투명한 곳이 없으면 JPEG.
    ///
    /// ⚠️ 예전에는 원본 크기 PNG 였다. 1200만 화소 사진 한 장이 15~25MB 가 되고, 그 인코딩만
    ///    저장 버튼을 누른 메인에서 0.5~1초 걸렸다. 그 크기가 iCloud 백업 · 동기화 · 키보드에서
    ///    붙여 넣을 때까지 그대로 따라다녔다. 붙여 넣는 곳(메신저 · 메일)은 어차피 다시 줄인다.
    /// ⚠️ 투명한 곳이 있는 그림(스티커 · 로고)은 PNG 로 둔다. JPEG 는 투명을 검게 메운다.
    private static let maxPixel: CGFloat = 2048

    static func storageEncoding(for image: UIImage) -> (data: Data, fileExtension: String)? {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        var output = image
        if longest > maxPixel {
            let ratio = maxPixel / longest
            let target = CGSize(width: (pixelSize.width * ratio).rounded(), height: (pixelSize.height * ratio).rounded())
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            format.opaque = !hasAlpha(image)
            output = UIGraphicsImageRenderer(size: target, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: target))
            }
        }
        if hasAlpha(image) {
            return output.pngData().map { ($0, "png") }
        }
        return output.jpegData(compressionQuality: 0.82).map { ($0, "jpg") }
    }

    private static func hasAlpha(_ image: UIImage) -> Bool {
        switch image.cgImage?.alphaInfo {
        case .first?, .last?, .premultipliedFirst?, .premultipliedLast?, .alphaOnly?: return true
        default: return false
        }
    }

    /// 그림을 저장하고 파일 이름을 돌려준다. 이름의 확장자가 형식을 말한다(붙여 넣을 때 그 형식으로 얹는다).
    static func save(_ image: UIImage) throws -> String {
        guard let encoded = storageEncoding(for: image) else { throw Failure.unencodable }
        let fileName = "\(UUID().uuidString).\(encoded.fileExtension)"
        try write(encoded.data, fileName: fileName)
        return fileName
    }

    /// 이름을 정해 **원본 그대로 PNG** 로 저장한다. 시험처럼 이름이 미리 정해져야 하는 곳만 쓴다.
    /// 단축어에 붙이는 그림은 `save(_:)` (줄여서 저장)를 쓴다.
    static func save(_ image: UIImage, fileName: String) throws {
        guard let data = image.pngData() else { throw Failure.unencodable }
        try write(data, fileName: fileName)
    }

    private static func write(_ data: Data, fileName: String) throws {
        guard let directory else { throw Failure.noContainer }
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
    }

    static func delete(fileName: String) throws {
        guard let directory else { throw Failure.noContainer }
        let fileURL = directory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - 읽기

    /// App Group 안의 그림 폴더.
    private static var directory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent("Images")
    }

    /// 그림 파일 자리. 없으면 nil.
    static func url(fileName: String) -> URL? {
        guard !fileName.isEmpty, let fileURL = directory?.appendingPathComponent(fileName),
              FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return fileURL
    }

    /// ⚠️ **원본을 통째로 펼친다.** 3000x2000 사진 한 장이 메모리에서 24MB 다.
    ///    앱에서는 괜찮지만 **키보드 익스텐션에서는 이 한 장이 프로세스를 죽인다**
    ///    (익스텐션 메모리 한도는 앱의 몇십 분의 일이다). 익스텐션에서는
    ///    `thumbnail(fileName:maxPixel:)`(그리기) 과 `data(fileName:)`(클립보드)
    ///    을 쓴다. 자세한 것은 `docs/postmortem/KEYBOARD_IMAGE_MEMORY.md`.
    static func load(fileName: String) -> UIImage? {
        guard let fileURL = url(fileName: fileName) else { return nil }
        return UIImage(contentsOfFile: fileURL.path)
    }

    /// 파일 바이트 그대로. **펼치지 않는다.**
    ///
    /// 클립보드에 사진을 얹을 때 `UIImage` 를 거치면 원본을 한 번 펼치고(24MB) 다시
    /// 인코딩해서(또 한 벌) 두 벌이 동시에 잡힌다. 바이트를 그대로 건네면 그 둘이 다 없다.
    /// 메모리 매핑이라 실제로 읽는 만큼만 올라온다.
    static func data(fileName: String) -> Data? {
        guard let fileURL = url(fileName: fileName) else { return nil }
        return try? Data(contentsOf: fileURL, options: .mappedIfSafe)
    }

    /// 파일 이름에서 클립보드용 타입을 고른다. 모르는 것은 png 로 본다(예전 저장이 png 라서).
    static func pasteboardType(fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext), type.conforms(to: .image) else {
            return UTType.png.identifier
        }
        return type.identifier
    }

    /// 긴 변이 `maxPixel` 이 되도록 **파일에서 바로** 줄여 읽는다.
    ///
    /// `UIImage(contentsOfFile:)` 로 읽고 나서 줄이면 이미 원본만큼 펼친 뒤다. ImageIO 는
    /// 디코드 단계에서 줄여 주므로 원본 크기의 버퍼가 아예 안 생긴다.
    static func thumbnail(fileName: String, maxPixel: CGFloat) -> UIImage? {
        guard let fileURL = url(fileName: fileName),
              let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // 사진의 회전 정보를 반영해서 만든다. 안 그러면 세로 사진이 눕는다.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
#endif
