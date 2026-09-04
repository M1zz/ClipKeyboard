//
//  ListBackgroundPickerSheet.swift
//  ClipKeyboard
//
//  목록 뒤에 깔 배경을 고르는 시트 - 없음 + 내 사진 + 내가 넣어 둔 것 + 내장 여덟 장.
//
//  ⚠️ 고르는 **자리**만 여기 있다. 무엇이 골라졌는지를 쥐고 저장하는 일은 목록 화면이
//     계속 한다(`@AppStorage`). 설정 화면(`ListBackgroundSettings`)도 같은 키를 쓰는데,
//     그 쪽에서 바꾼 값이 여기로 곧장 흘러들어야 해서 저장은 옮기지 않았다.
//

import SwiftUI
import PhotosUI
import LeeoKit

struct ListBackgroundPickerSheet: View {

    /// 제공되는 배경 이미지 에셋 이름들. 빈 문자열 = 배경 없음(예전 모습 그대로).
    static let options: [String] = (1...8).map { String(format: "ListBackground%02d", $0) }

    /// 적용 범위 - 현재 탭만 / 모든 탭.
    @Binding var scopeAllTabs: Bool
    /// 사진첩에서 고른 것. 고르는 즉시 저장하고 배경으로 적용한다.
    @Binding var pickedItem: PhotosPickerItem?

    /// 지금 탭 이름 - 범위 고르개의 왼쪽 칸에 그대로 들어간다.
    let currentTabName: String
    /// 내가 넣어 둔 배경들.
    let myBackgrounds: [String]

    let isSelected: (String) -> Bool
    let onApply: (String) -> Void
    let onRemoveMine: (String) -> Void
    let onDone: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    scopePicker
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                        noneTile
                        // ⚠️ **사진 고르기가 맨 앞이다.** 내장 여덟 장을 다 지나야 나오면,
                        //    내 사진을 쓸 수 있다는 것부터 모른 채 여덟 개 중에서 고르게 된다.
                        photosTile
                        // 내가 넣은 것이 내장보다 먼저 - 방금 넣은 것을 찾으러 스크롤하지 않게.
                        ForEach(myBackgrounds, id: \.self) { name in
                            mineTile(name: name)
                        }
                        ForEach(Self.options, id: \.self) { name in
                            builtInTile(name: name)
                        }
                    }
                }
                .padding(16)
            }
            .background(theme.bg)
            .navigationTitle(NSLocalizedString("배경 이미지", comment: "Menu: list background image"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("완료", comment: "Done")) { onDone() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 칸들

    private var scopePicker: some View {
        Picker("", selection: $scopeAllTabs) {
            Text(String(format: NSLocalizedString("'%@' 탭만", comment: "Background scope: current tab only, with tab name"),
                        currentTabName))
                .tag(false)
            Text(NSLocalizedString("모든 탭", comment: "Background scope: all tabs"))
                .tag(true)
        }
        .pickerStyle(.segmented)
    }

    private var noneTile: some View {
        Button {
            onApply("")
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                    .fill(theme.surfaceAlt)
                VStack(spacing: 6) {
                    Image(systemName: "slash.circle")
                        .font(.title2)
                    Text(NSLocalizedString("없음", comment: "Background: none"))
                        .font(.footnote.weight(.medium))
                }
                .foregroundColor(theme.textMuted)
            }
            .frame(height: 150)
            .overlay(selectionBadge(selected: isSelected("")))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("배경 없음", comment: "Background: none a11y"))
    }

    private var photosTile: some View {
        PhotosPicker(selection: $pickedItem, matching: .images) {
            ZStack {
                RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                    .fill(theme.accentSoft)
                VStack(spacing: 6) {
                    Image(systemName: AppSymbol.photoOnRectangleAngled)
                        .font(.title2)
                    Text(NSLocalizedString("내 사진", comment: "Background: my photo"))
                        .font(.footnote.weight(.medium))
                }
                .foregroundColor(theme.accent)
            }
            .frame(height: 150)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("사진에서 배경 고르기",
                                              comment: "Background: pick from photos"))
    }

    private func mineTile(name: String) -> some View {
        Button {
            onApply(name)
        } label: {
            thumbnail(name: name)
                .overlay(alignment: .topLeading) {
                    Button {
                        onRemoveMine(name)
                    } label: {
                        Image(systemName: AppSymbol.xmarkCircleFill)
                            .font(.title3)
                            .foregroundStyle(.white, .black.opacity(0.45))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(NSLocalizedString("이 배경 지우기",
                                                          comment: "Remove my background"))
                }
        }
        .buttonStyle(.plain)
    }

    private func builtInTile(name: String) -> some View {
        Button {
            onApply(name)
        } label: {
            thumbnail(name: name)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("배경 이미지", comment: "Menu: list background image"))
    }

    private func thumbnail(name: String) -> some View {
        BackgroundImageView(name: name)
            .scaledToFill()
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
            .overlay(selectionBadge(selected: isSelected(name)))
    }

    /// 선택된 썸네일 표시 - 파란 테두리 + 체크 뱃지.
    @ViewBuilder
    private func selectionBadge(selected: Bool) -> some View {
        if selected {
            RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                .strokeBorder(Color.accentColor, lineWidth: 3)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: AppSymbol.checkmarkCircleFill)
                        .font(.title3)
                        .foregroundStyle(Color.checkOnGreen, Color.checkGreen)
                        .padding(6)
                }
        }
    }
}
