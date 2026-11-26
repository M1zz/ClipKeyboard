//
//  VideoAttachmentComponents.swift
//  ClipKeyboard
//
//  저장 화면의 동영상 붙이기: 사진 보관함에서 고른 동영상을 받는 그릇과 붙인 동영상 미리보기.
//  줄이고 저장하는 일은 `VideoStore` 가 한다.
//

#if os(iOS)
import SwiftUI
import PhotosUI
import CoreTransferable
import UniformTypeIdentifiers

// MARK: - Picked Movie

/// 사진 보관함에서 고른 동영상. 받은 파일은 닫힘 뒤에 지워지므로 임시 폴더에 복사해 둔다.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("picked-\(UUID().uuidString).\(ext)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}

// MARK: - Import

enum VideoAttachmentImport {
    /// 고른 것을 받아 붙일 모양으로 줄인다. 실패하면 사용자에게 보일 말을 담아 던진다.
    @MainActor
    static func prepare(_ item: PhotosPickerItem) async throws -> URL {
        let picked: PickedMovie?
        do {
            picked = try await item.loadTransferable(type: PickedMovie.self)
        } catch {
            print("❌ [VideoAttachmentImport.prepare] 보관함에서 받지 못함: \(error)")
            throw VideoStore.Failure.unreadable
        }
        guard let picked else { throw VideoStore.Failure.unreadable }
        defer { try? FileManager.default.removeItem(at: picked.url) }
        return try await VideoStore.prepareAttachment(from: picked.url)
    }

    static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription
            ?? NSLocalizedString("동영상을 저장하지 못했어요. 다시 시도해 주세요",
                                 comment: "Video attach failed: generic")
    }
}

// MARK: - Preview Row

/// 붙인 동영상 한 줄: 첫 장면 · 길이 · 변경 · 제거.
struct AttachedVideoRow: View {
    let url: URL
    let onReplace: () -> Void
    let onRemove: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var thumbnail: UIImage?
    @State private var duration: TimeInterval?

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    theme.surface
                }
                Image(systemName: AppSymbol.videoFill)
                    .font(.body)
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
            .frame(width: 72, height: 72)
            .cornerRadius(theme.radiusSm)
            .clipped()
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.body)
                    .foregroundColor(theme.textMuted)
                HStack(spacing: 8) {
                    Button(action: onReplace) {
                        Label(NSLocalizedString("변경", comment: "Change image"), systemImage: AppSymbol.videoBadgePlus)
                            .font(.body)
                            .foregroundColor(.accentColor)
                    }
                    Button(action: onRemove) {
                        Label(NSLocalizedString("제거", comment: "Remove image"), systemImage: AppSymbol.trash)
                            .font(.body)
                            .foregroundColor(.red)
                    }
                }
            }
            Spacer()
        }
        .padding(10)
        .background(theme.surfaceAlt)
        .cornerRadius(theme.radiusMd)
        .task(id: url) {
            thumbnail = await VideoStore.thumbnail(for: url, maxPixel: 200)
            duration = await VideoStore.duration(of: url)
        }
    }

    private var title: String {
        guard let duration else {
            return NSLocalizedString("붙인 동영상", comment: "Attached video label")
        }
        let total = Int(duration.rounded())
        let clock = String(format: "%d:%02d", total / 60, total % 60)
        return String(format: NSLocalizedString("붙인 동영상 · %@", comment: "Attached video label with duration like 0:12"), clock)
    }
}

// MARK: - Missing Row

/// 편집 중인 단축어의 동영상이 이 기기에 없다(다른 기기에서 만든 것). 지우거나 새로 붙인다.
struct MissingVideoRow: View {
    let onReplace: () -> Void
    let onRemove: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(VideoStore.message(for: .missing) ?? "", systemImage: AppSymbol.videoFill)
                .font(.body)
                .foregroundColor(theme.textMuted)
            HStack(spacing: 12) {
                Button(action: onReplace) {
                    Label(NSLocalizedString("변경", comment: "Change image"), systemImage: AppSymbol.videoBadgePlus)
                        .font(.body)
                }
                Button(action: onRemove) {
                    Label(NSLocalizedString("제거", comment: "Remove image"), systemImage: AppSymbol.trash)
                        .font(.body)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceAlt)
        .cornerRadius(theme.radiusMd)
    }
}
#endif
