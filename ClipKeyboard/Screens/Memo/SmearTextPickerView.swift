//
//  SmearTextPickerView.swift
//  ClipKeyboard
//
//  사진 위를 **손가락으로 문질러** 그 자리의 글자만 값으로 가져오는 자리.
//
//  왜 문지르게 하는가: 사진 한 장에는 필요한 것보다 훨씬 많은 글자가 들어 있다.
//  통장 사진에는 은행 이름·예금주·상품명이 계좌번호와 함께 찍히고, 명함에는 회사명·
//  직함·주소가 전화번호와 같이 있다. 읽은 것을 전부 값에 부으면 사용자는 지우는 일을
//  하게 된다 - 손으로 치는 것보다 나을 게 없다. 필요한 곳만 손가락으로 쓸어 담게 하면
//  사진이 비로소 입력을 대신한다.
//
//  ⚠️ 사진은 **첨부하지 않는다.** 여기서 사진은 글자를 담아 온 그릇일 뿐이다.
//     그림 자체를 값으로 쓰는 일은 옆의 '이미지' 버튼이 하는 다른 일이다.
//
//  ⚠️ 손가락이 유일한 길이면 안 된다. VoiceOver 를 쓰거나 손이 불편하면 문지를 수 없다.
//     늘 **줄 목록으로 고르는 길**(`PhotoValuePicker`)을 옆에 열어 둔다.
//

import SwiftUI
import LeeoKit   // HapticManager

#if os(iOS)

/// 문질러 담기 화면에 넘길 한 벌 - 사진과 그 사진에서 읽어낸 글자 자리.
/// (`.sheet(item:)` 로 띄우려면 하나로 묶여 있어야 한다.)
struct SmearSource: Identifiable {
    let id = UUID()
    let image: UIImage
    let layout: RecognizedTextLayout
}

struct SmearTextPickerView: View {

    /// 문지를 사진. 화면에는 이 사진이 그대로 보이고, 글자 네모는 그 위에 얹힌다.
    let image: UIImage
    /// 사진에서 읽어낸 글자와 그 자리.
    let layout: RecognizedTextLayout

    /// 문질러 고른 글자를 값으로 담는다.
    let onPick: (String) -> Void
    /// 손가락 대신 줄 목록에서 고르겠다고 했다.
    var onSwitchToLineList: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 안내 문구를 보여준 횟수. 몇 번 해보면 몸이 먼저 기억한다 - 그다음부터는 자리만 차지한다.
    @AppStorage(DefaultsKey.smearHintShownCount) private var hintShownCount = 0
    private let hintMaxShows = 3

    @State private var selected: Set<UUID> = []
    /// 지금 손가락이 지나가고 있는 자리 - 문지르는 동안만 그린다.
    @State private var strokePoints: [CGPoint] = []
    @State private var eraseMode = false
    @State private var moveMode = false
    /// 줄이 바뀐 자리를 줄바꿈으로 살릴지. 두 줄짜리 주소는 켜고, 두 줄에 걸친 계좌번호는 끈다.
    @State private var keepLineBreaks = false

    // 확대/이동
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    /// 손가락 판정 여유 - 글자 네모를 상하좌우로 넓혀 잡는다. 확대할수록 좁혀 정밀해진다.
    private let touchTolerance: CGFloat = 10
    private let maxScale: CGFloat = 6

    private var pickedText: String {
        layout.joinedText(selecting: selected, keepLineBreaks: keepLineBreaks)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if hintShownCount < hintMaxShows {
                    hintBar
                }

                photoStage

                bottomBar
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("문질러 담기", comment: "Smear text picker title"))
            .navigationBarTitleDisplayMode(.inline)
            .solidNavBar(theme.bg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("취소", comment: "Cancel")) { dismiss() }
                }
                if onSwitchToLineList != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            onSwitchToLineList?()
                            dismiss()
                        } label: {
                            Label(NSLocalizedString("줄로 고르기", comment: "Switch to line list picker"),
                                  systemImage: AppSymbol.listBullet)
                        }
                        .accessibilityHint(NSLocalizedString("문지르는 대신 읽은 줄을 목록에서 고릅니다",
                                                             comment: "Switch to line list picker (a11y hint)"))
                    }
                }
            }
        }
        .onAppear {
            if hintShownCount < hintMaxShows { hintShownCount += 1 }
        }
    }

    // MARK: - 안내

    private var hintBar: some View {
        Label(NSLocalizedString("가져올 글자 위를 손가락으로 쓸어 보세요. 두 손가락으로 벌리면 확대됩니다.",
                                comment: "Smear picker hint"),
              systemImage: AppSymbol.handTap)
            .font(.footnote)
            .foregroundColor(theme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.surfaceAlt)
    }

    // MARK: - 사진 무대

    private var photoStage: some View {
        GeometryReader { geo in
            let fitted = fittedRect(for: image.size, in: geo.size)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)

                // 고른 글자와 지금 지나가는 손가락 자국 (확대/이동 전 좌표에 그린다)
                Canvas { context, _ in
                    for piece in layout.allPieces where selected.contains(piece.id) {
                        let rect = viewRect(for: piece.box, fitted: fitted)
                            .insetBy(dx: -3, dy: -2)
                        context.fill(
                            Path(roundedRect: rect, cornerRadius: 4),
                            with: .color(.yellow.opacity(0.45))
                        )
                    }
                    if strokePoints.count > 1 {
                        var path = Path()
                        path.move(to: strokePoints[0])
                        for point in strokePoints.dropFirst() {
                            path.addLine(to: point)
                        }
                        context.stroke(
                            path,
                            with: .color(eraseMode ? .red.opacity(0.35) : .orange.opacity(0.35)),
                            style: StrokeStyle(lineWidth: 24 / scale, lineCap: .round, lineJoin: .round)
                        )
                    }
                }
                .allowsHitTesting(false)
            }
            .scaleEffect(scale, anchor: .center)
            .offset(offset)
            .contentShape(Rectangle())
            .gesture(dragGesture(fitted: fitted, center: center, container: geo.size))
            .simultaneousGesture(magnifyGesture())
        }
        .coordinateSpace(name: Self.canvasSpace)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(NSLocalizedString("사진 속 글자", comment: "Smear picker canvas (a11y label)"))
        .accessibilityHint(NSLocalizedString("손가락으로 문질러 고릅니다. 문지르기 어려우면 오른쪽 위 줄로 고르기를 쓰세요.",
                                             comment: "Smear picker canvas (a11y hint)"))
    }

    // MARK: - 아래 도구와 담기

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            toolRow

            // 지금까지 고른 글자 - 담기 전에 무엇이 들어갈지 눈으로 확인한다.
            Text(pickedText.isEmpty
                 ? NSLocalizedString("아직 고른 글자가 없어요", comment: "Smear picker: nothing selected yet")
                 : pickedText)
                .font(.subheadline)
                .foregroundColor(pickedText.isEmpty ? theme.textFaint : theme.text)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(theme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
                .accessibilityLabel(NSLocalizedString("고른 글자", comment: "Smear picker: picked text (a11y)"))
                .accessibilityValue(pickedText)

            applyButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(theme.surface)
    }

    private var toolRow: some View {
        HStack(spacing: 8) {
            toolButton(
                title: NSLocalizedString("이동", comment: "Smear picker tool: pan"),
                systemImage: AppSymbol.handDraw,
                isOn: moveMode
            ) {
                moveMode.toggle()
                if moveMode { eraseMode = false }
                HapticManager.shared.light()
            }

            toolButton(
                title: NSLocalizedString("지우개", comment: "Smear picker tool: eraser"),
                systemImage: eraseMode ? AppSymbol.eraserFill : AppSymbol.eraser,
                isOn: eraseMode
            ) {
                eraseMode.toggle()
                if eraseMode { moveMode = false }
                HapticManager.shared.light()
            }
            .disabled(moveMode)

            toolButton(
                title: NSLocalizedString("줄바꿈", comment: "Smear picker tool: keep line breaks"),
                systemImage: AppSymbol.textJustify,
                isOn: keepLineBreaks
            ) {
                keepLineBreaks.toggle()
                HapticManager.shared.light()
            }
            .accessibilityHint(NSLocalizedString("여러 줄을 골랐을 때 줄바꿈을 살립니다",
                                                 comment: "Smear picker: keep line breaks (a11y hint)"))

            Spacer(minLength: 0)

            if scale > 1.01 {
                toolButton(
                    title: NSLocalizedString("원래대로", comment: "Smear picker tool: reset zoom"),
                    systemImage: AppSymbol.arrowCounterclockwise,
                    isOn: false
                ) {
                    resetZoom()
                }
            }

            toolButton(
                title: NSLocalizedString("전체", comment: "Smear picker tool: select all"),
                systemImage: AppSymbol.docPlaintext,
                isOn: false
            ) {
                if selected.count == layout.allPieces.count {
                    selected.removeAll()
                } else {
                    selected = Set(layout.allPieces.map(\.id))
                }
                HapticManager.shared.selection()
            }

            toolButton(
                title: NSLocalizedString("모두 지우기", comment: "Smear picker tool: clear selection"),
                systemImage: AppSymbol.trash,
                isOn: false
            ) {
                selected.removeAll()
                HapticManager.shared.light()
            }
            .disabled(selected.isEmpty)
        }
    }

    private func toolButton(title: String, systemImage: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(minWidth: 46)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(isOn ? theme.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusSm, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundColor(isOn ? theme.accent : theme.textMuted)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    private var applyButton: some View {
        Button {
            let text = pickedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            HapticManager.shared.success()
            onPick(text)
            dismiss()
        } label: {
            Text(pickedText.isEmpty
                 ? NSLocalizedString("글자 위를 문질러 주세요", comment: "Smear picker apply button (none picked)")
                 : String(format: NSLocalizedString("이 글자 담기 (%d자)", comment: "Smear picker apply button (count)"),
                          pickedText.count))
                .font(.body.weight(.semibold))
                .foregroundColor(pickedText.isEmpty ? theme.textFaint : Color.accentForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(pickedText.isEmpty ? theme.surfaceAlt : Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(pickedText.isEmpty)
    }

    // MARK: - 제스처

    private static let canvasSpace = "smearCanvas"

    private func dragGesture(fitted: CGRect, center: CGPoint, container: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.canvasSpace))
            .onChanged { value in
                if moveMode {
                    let next = CGSize(width: lastOffset.width + value.translation.width,
                                      height: lastOffset.height + value.translation.height)
                    offset = clampOffset(next, container: container)
                } else {
                    let local = toLocal(value.location, center: center)
                    strokePoints.append(local)
                    updateSelection(at: local, fitted: fitted)
                }
            }
            .onEnded { _ in
                if moveMode {
                    lastOffset = offset
                } else {
                    strokePoints.removeAll()
                }
            }
    }

    private func magnifyGesture() -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(lastScale * value.magnification, 1), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.01 { resetZoom() }
            }
    }

    /// 화면 좌표 → 확대/이동을 되돌린 좌표. 글자 네모는 확대 전 자리에 그려져 있다.
    private func toLocal(_ point: CGPoint, center: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - center.x - offset.width) / scale + center.x,
                y: (point.y - center.y - offset.height) / scale + center.y)
    }

    /// 확대한 사진이 화면 밖으로 과하게 달아나지 않게 이동량을 묶는다.
    private func clampOffset(_ proposed: CGSize, container: CGSize) -> CGSize {
        let maxX = max(0, container.width * (scale - 1) / 2)
        let maxY = max(0, container.height * (scale - 1) / 2)
        return CGSize(width: min(max(proposed.width, -maxX), maxX),
                      height: min(max(proposed.height, -maxY), maxY))
    }

    private func resetZoom() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            scale = 1
            offset = .zero
        }
        lastScale = 1
        lastOffset = .zero
    }

    // MARK: - 고르기

    /// 손가락이 닿은 자리의 글자를 담거나(지우개면) 뺀다.
    ///
    /// ⚠️ 무엇이 달라졌을 때만 손끝에 알린다. 문지르는 내내 진동하면 손이 아니라 폰이 떨린다.
    private func updateSelection(at point: CGPoint, fitted: CGRect) {
        let tolerance = touchTolerance / scale
        var changed = false

        for piece in layout.allPieces {
            let rect = viewRect(for: piece.box, fitted: fitted)
                .insetBy(dx: -tolerance, dy: -tolerance)
            guard rect.contains(point) else { continue }

            if eraseMode {
                if selected.remove(piece.id) != nil { changed = true }
            } else {
                if selected.insert(piece.id).inserted { changed = true }
            }
        }

        if changed { HapticManager.shared.selection() }
    }

    // MARK: - 좌표 변환

    /// aspect-fit 으로 놓인 사진이 실제로 차지한 자리.
    private func fittedRect(for imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let ratio = min(containerSize.width / imageSize.width,
                        containerSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
        let origin = CGPoint(x: (containerSize.width - size.width) / 2,
                             y: (containerSize.height - size.height) / 2)
        return CGRect(origin: origin, size: size)
    }

    /// 정규화 좌표(좌상단 원점) → 화면 좌표.
    private func viewRect(for normalized: CGRect, fitted: CGRect) -> CGRect {
        CGRect(x: fitted.minX + normalized.minX * fitted.width,
               y: fitted.minY + normalized.minY * fitted.height,
               width: normalized.width * fitted.width,
               height: normalized.height * fitted.height)
    }
}

#endif
