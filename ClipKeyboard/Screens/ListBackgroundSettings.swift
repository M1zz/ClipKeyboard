//
//  ListBackgroundSettings.swift
//  ClipKeyboard
//
//  **배경 이미지** - 단축어 목록 뒤에 깔리는 사진.
//
//  ⚠️ 예전에는 목록 화면 ⋯ 메뉴에서만 열 수 있었다. 그 메뉴를 설정으로 옮기면서
//     여기로 왔다(⋯·+·금고를 바에 다 두려니 시스템이 오버플로 ⋯ 를 하나 더 만들었다).
//
//  ⚠️ 목록 화면의 선택기와 다른 점이 하나 있다: 거기서는 "현재 탭만/모든 탭"을 고를 수
//     있지만 여기서는 **모든 탭**에 적용한다. 설정 화면에는 '현재 탭'이라는 것이 없어서,
//     탭별 적용을 흉내 내면 무엇에 적용되는지 아무도 모른다.
//     그래서 여기서 고르면 탭별 덮어쓰기는 지운다 - 고른 대로 보이는 게 먼저다.
//
//  ⚠️ **내 사진을 넣고 지우는 길이 여기에도 있어야 한다.** 오래도록 그 길이 목록 화면의
//     선택기에만 있었다. 배경을 바꾸러 설정에 들어온 사람은 내장 여덟 장만 보고
//     "이게 다구나" 하고 나갔다. 같은 이름의 화면이 둘인데 **할 수 있는 일이 다르면**
//     사람은 자기가 본 쪽을 그 기능의 전부로 안다.
//

import SwiftUI
#if canImport(UIKit)
import LeeoKit
import PhotosUI
import UIKit
#endif

struct ListBackgroundSettings: View {

    @Environment(\.appTheme) private var theme

    @AppStorage(DefaultsKey.listBackgroundImageV1, store: AppGroup.defaults)
    private var listBackgroundImage: String = ""

    /// 내가 넣어 둔 배경들. 최근에 넣은 것이 앞에 온다.
    @State private var myBackgrounds: [String] = []
    /// 사진첩에서 고른 것. 고르는 즉시 저장하고 배경으로 적용한다.
    @State private var pickedItem: PhotosPickerItem?
    /// 지울지 다시 묻는 대상. 지우면 파일이 없어져 되돌릴 수 없다.
    @State private var pendingDeletion: String?
    /// 사진을 못 읽었을 때. 조용히 실패하면 눌렀는데 아무 일도 안 일어난 것으로 보인다.
    @State private var showImportFailed = false

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                thumbnail(name: "", label: NSLocalizedString("없음", comment: "Living skin name: none"))

                // 사진첩으로 가는 문. **"없음" 바로 다음**에 둔다 - 내장 여덟 장 뒤에 두면
                // 스크롤해서 끝까지 간 사람만 이런 길이 있다는 것을 안다.
                photoPickerTile

                // 내가 넣은 것이 내장보다 먼저 - 방금 넣은 것을 찾으러 스크롤하지 않게.
                ForEach(myBackgrounds, id: \.self) { name in
                    thumbnail(name: name, label: nil, deletable: true)
                }

                ForEach(ClipKeyboardList.backgroundOptions, id: \.self) { name in
                    thumbnail(name: name, label: nil)
                }
            }
            .padding(16)
        }
        .background(theme.bg.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("배경 이미지", comment: "Menu: list background image"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { myBackgrounds = BackgroundImageStore.saved() }
        .onChange(of: pickedItem) { _, item in adopt(item) }
        // ⚠️ 지우기는 되묻는다. 파일이 사라지므로 되돌릴 수 없고, 지우는 단추가 썸네일
        //    귀퉁이에 있어서 고르려다 스치기 쉽다.
        .alert(NSLocalizedString("이 배경을 지울까요?", comment: "Delete background confirm title"),
               isPresented: Binding(get: { pendingDeletion != nil },
                                    set: { if !$0 { pendingDeletion = nil } })) {
            Button(NSLocalizedString("지우기", comment: "Sample cleanup: delete"), role: .destructive) {
                if let name = pendingDeletion { remove(name) }
                pendingDeletion = nil
            }
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { pendingDeletion = nil }
        } message: {
            Text(NSLocalizedString("넣어 두신 사진이 지워져요. 사진첩의 원본은 그대로예요.",
                                   comment: "Delete background confirm message"))
        }
        .alert(NSLocalizedString("사진을 가져오지 못했어요", comment: "Background import failed"),
               isPresented: $showImportFailed) {
            Button(NSLocalizedString("확인", comment: "Confirm button"), role: .cancel) { }
        }
    }

    // MARK: - 사진첩으로 가는 문

    private var photoPickerTile: some View {
        PhotosPicker(selection: $pickedItem, matching: .images, photoLibrary: .shared()) {
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
            .frame(height: 120)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("사진에서 배경 고르기", comment: "Background: pick from photos"))
    }

    // MARK: - 한 장

    private func thumbnail(name: String, label: String?, deletable: Bool = false) -> some View {
        Button {
            HapticManager.shared.selection()
            withAnimation(.easeInOut(duration: 0.2)) { apply(name) }
        } label: {
            ZStack {
                if name.isEmpty {
                    RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                        .fill(theme.surfaceAlt)
                    Text(label ?? "")
                        .font(.footnote)
                        .foregroundColor(theme.textMuted)
                } else {
                    // ⚠️ `Image(name)` 이 아니라 이것을 쓴다. 내 사진은 에셋에 없어서
                    //    `Image(name)` 으로는 **빈 칸**이 나온다(이름만 맞고 그림이 없다).
                    BackgroundImageView(name: name)
                        .scaledToFill()
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
            .overlay {
                if listBackgroundImage == name {
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
            // 지우는 단추는 **내가 넣은 것에만** 붙는다. 내장 배경은 지울 수 있는 것이 아니다.
            .overlay(alignment: .topLeading) {
                if deletable {
                    Button {
                        pendingDeletion = name
                    } label: {
                        Image(systemName: AppSymbol.xmarkCircleFill)
                            .font(.title3)
                            .foregroundStyle(.white, .black.opacity(0.45))
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(NSLocalizedString("이 배경 지우기", comment: "Remove my background"))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? NSLocalizedString("배경 이미지", comment: "Menu: list background image"))
        .accessibilityAddTraits(listBackgroundImage == name ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - 들이고 지우기

    /// 내 사진 하나를 들인다. **고르자마자 적용한다** - 넣고 또 골라야 하면 두 걸음이다.
    private func adopt(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task { @MainActor in
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let stored = BackgroundImageStore.add(image) else {
                showImportFailed = true
                pickedItem = nil
                return
            }
            myBackgrounds = BackgroundImageStore.saved()
            withAnimation(.easeInOut(duration: 0.2)) { apply(stored) }
            pickedItem = nil
        }
    }

    /// 내가 넣은 배경 하나를 지운다.
    ///
    /// ⚠️ 지금 쓰고 있는 것을 지우면 **배경 없음으로 되돌린다.** 그러지 않으면 파일이
    ///    사라진 이름만 남아, 배경이 조용히 안 보이는 채로 설정만 켜져 있게 된다.
    ///
    /// ⚠️ 탭별 덮어쓰기에도 같은 이름이 남아 있을 수 있다. 그쪽을 안 지우면 **어떤 탭에서만**
    ///    배경이 사라진 채로 남는다. 여기서는 그 탭들만 "배경 없음"으로 되돌린다
    ///    (덮어쓰기 전체를 지우면 사용자가 다른 탭에 따로 깔아 둔 것까지 날아간다).
    private func remove(_ name: String) {
        BackgroundImageStore.remove(name)
        myBackgrounds = BackgroundImageStore.saved()
        if listBackgroundImage == name { listBackgroundImage = "" }

        if let defaults = AppGroup.defaults,
           var perTab = defaults.dictionary(forKey: DefaultsKey.listBackgroundPerTabV1) as? [String: String] {
            for (tab, value) in perTab where value == name { perTab[tab] = "" }
            defaults.set(perTab, forKey: DefaultsKey.listBackgroundPerTabV1)
        }
        HapticManager.shared.selection()
    }

    private func apply(_ name: String) {
        listBackgroundImage = name
        // 탭별 덮어쓰기를 남겨 두면 여기서 고른 것이 어떤 탭에서는 안 보인다.
        AppGroup.defaults?
            .removeObject(forKey: DefaultsKey.listBackgroundPerTabV1)
    }
}
