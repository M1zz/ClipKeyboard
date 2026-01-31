//
//  MemoAddView.swift
//  TokenMemo.tap
//
//  Created by Claude on 2025-12-11.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MemoAddView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var textContent: String = ""
    @State private var category: String = "기본"
    @State private var attachedImages: [NSImage] = []
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 32))
                        .foregroundStyle(.blue)

                    Text("새 메모")
                        .font(.title2)
                        .bold()

                    Spacer()

                    Button {
                        closeWindow()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // 제목 입력
                TextField("제목", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .font(.headline)

                // 카테고리 선택
                HStack {
                    Text("카테고리:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("카테고리", text: $category)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .frame(width: 100)

                    Spacer()
                }
            }
            .padding()

            Divider()

            // 컨텐츠 입력 영역
            ScrollView {
                VStack(spacing: 16) {
                    // 텍스트 입력
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "text.alignleft")
                                .foregroundStyle(.blue)
                            Text("내용")
                                .font(.headline)
                        }

                        TextEditor(text: $textContent)
                            .font(.body)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }

                    // 이미지 첨부 영역
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "photo")
                                .foregroundStyle(.purple)
                            Text("이미지 첨부")
                                .font(.headline)

                            Spacer()

                            if !attachedImages.isEmpty {
                                Text("\(attachedImages.count)개")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // 이미지 추가 버튼
                        HStack(spacing: 12) {
                            Button {
                                selectImageFromFile()
                            } label: {
                                Label("파일에서 선택", systemImage: "folder")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                pasteImageFromClipboard()
                            } label: {
                                Label("클립보드에서 붙여넣기", systemImage: "doc.on.clipboard")
                            }
                            .buttonStyle(.bordered)
                        }

                        // 첨부된 이미지들
                        if !attachedImages.isEmpty {
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 120))
                            ], spacing: 12) {
                                ForEach(Array(attachedImages.enumerated()), id: \.offset) { index, image in
                                    ImageAttachmentView(image: image) {
                                        removeImage(at: index)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        } else {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.secondary)
                                    Text("이미지를 추가해보세요")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 20)
                                Spacer()
                            }
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // 하단 버튼
            HStack(spacing: 12) {
                Spacer()

                Button("취소") {
                    closeWindow()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button("저장") {
                    saveMemo()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(.horizontal)
            .padding(.top, -20)
            .padding(.bottom)
        }
        .frame(width: 550, height: 650)
        .overlay(
            // Toast 메시지
            VStack {
                Spacer()
                if showToast {
                    Text(toastMessage)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: showToast)
        )
        .onTapGesture {
            // 빈 공간 탭 시 키보드 내리기
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }

    // MARK: - Computed Properties

    private var canSave: Bool {
        if title.isEmpty {
            return false
        }
        return !textContent.isEmpty || !attachedImages.isEmpty
    }

    // MARK: - Actions

    private func selectImageFromFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.message = "이미지를 선택하세요"

        if panel.runModal() == .OK {
            for url in panel.urls {
                if let image = NSImage(contentsOf: url) {
                    attachedImages.append(image)
                }
            }
        }
    }

    private func pasteImageFromClipboard() {
        let pasteboard = NSPasteboard.general

        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            attachedImages.append(image)
            showToastMessage("클립보드에서 이미지를 추가했습니다")
        } else {
            showToastMessage("클립보드에 이미지가 없습니다")
        }
    }

    private func removeImage(at index: Int) {
        guard index < attachedImages.count else { return }
        attachedImages.remove(at: index)
    }

    private func saveMemo() {
        do {
            var memos = try MemoStore.shared.load(type: .tokenMemo)

            // 이미지들을 파일로 저장
            var savedImageFileNames: [String] = []
            for image in attachedImages {
                let fileName = "\(UUID().uuidString).png"
                try MemoStore.shared.saveImage(image, fileName: fileName)
                savedImageFileNames.append(fileName)
            }

            // 컨텐츠 타입 결정
            let contentType: ClipboardContentType
            if !textContent.isEmpty && !savedImageFileNames.isEmpty {
                contentType = .mixed
            } else if !savedImageFileNames.isEmpty {
                contentType = .image
            } else {
                contentType = .text
            }

            let newMemo = Memo(
                title: title,
                value: textContent,
                category: category,
                imageFileNames: savedImageFileNames,
                contentType: contentType
            )
            memos.append(newMemo)

            try MemoStore.shared.save(memos: memos, type: .tokenMemo)

            print("✅ [MemoAdd] 메모 저장 완료")
            showToastMessage("메모가 저장되었습니다")

            // 저장 후 창 닫기
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                closeWindow()
            }
        } catch {
            print("❌ [MemoAdd] 메모 저장 실패: \(error)")
            showToastMessage("저장 실패: \(error.localizedDescription)")
        }
    }

    private func closeWindow() {
        // 현재 윈도우 찾아서 닫기
        if let window = NSApp.keyWindow {
            window.close()
        }
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }
}

// MARK: - Image Attachment View

struct ImageAttachmentView: View {
    let image: NSImage
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
                .clipped()
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            if isHovering {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .background(Circle().fill(Color.red))
                }
                .buttonStyle(.plain)
                .padding(4)
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    MemoAddView()
}
