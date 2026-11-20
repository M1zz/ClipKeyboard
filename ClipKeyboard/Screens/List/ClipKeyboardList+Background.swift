//
//  ClipKeyboardList+Background.swift
//  ClipKeyboard
//
//  단축어 목록 화면(`ClipKeyboardList`)의 한 갈래.
//  목록 뒤에 까는 배경 사진: 고르기 · 탭별 덮어쓰기 · 내 사진 들이기 · 제안할 때.
//
//  상태(`@State` · `@AppStorage`)와 화면의 뼈대(`body` · 시트를 거는 단계들)는 `ClipKeyboardList.swift` 에 있다.
//  저장 속성은 확장에 둘 수 없어서 그쪽에 모여 있고, 여기는 그 상태로 그리는 것과 하는 일만 둔다.
//

import SwiftUI
import LocalAuthentication
import TipKit
import UniformTypeIdentifiers
import PhotosUI
import LeeoKit

extension ClipKeyboardList {

    /// 내 사진 하나를 들인다. **고르자마자 적용한다** - 넣고 또 골라야 하면 두 걸음이다.
    func adoptPickedBackground(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task { @MainActor in
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let stored = BackgroundImageStore.add(image) else {
                viewModel.showPlainToast(NSLocalizedString("사진을 가져오지 못했어요",
                                                           comment: "Background import failed"))
                return
            }
            myBackgrounds = BackgroundImageStore.saved()
            applyBackground(stored)
            pickedBackgroundItem = nil
        }
    }

    /// 내가 넣은 배경 하나를 지운다.
    ///
    /// ⚠️ 지금 쓰고 있는 것을 지우면 **배경 없음으로 되돌린다.** 그러지 않으면 파일이
    ///    사라진 이름만 남아, 배경이 조용히 안 보이는 채로 설정만 켜져 있게 된다.
    func removeUserBackground(_ name: String) {
        BackgroundImageStore.remove(name)
        myBackgrounds = BackgroundImageStore.saved()
        if listBackgroundImage == name { listBackgroundImage = "" }
        for (tab, value) in perTabBackgrounds where value == name {
            perTabBackgrounds[tab] = ""
        }
        persistPerTabBackgrounds()
        HapticManager.shared.selection()
    }

    /// 현재 탭에 실제로 보여줄 배경 - 탭 덮어쓰기 우선, 없으면 전체 기본값.
    var resolvedBackgroundImage: String {
        // 홈은 어느 카테고리도 아니다 - 전체 배경만 깐다.
        guard isInCategory else { return listBackgroundImage }
        return perTabBackgrounds[viewModel.selectedCategoryTab.storageKey] ?? listBackgroundImage
    }

    func loadPerTabBackgrounds() {
        perTabBackgrounds = (AppGroup.defaults?
            .dictionary(forKey: DefaultsKey.listBackgroundPerTabV1) as? [String: String]) ?? [:]
        preloadBackgrounds()
    }

    /// 이 화면이 쓸 배경들을 미리 풀어 둔다.
    ///
    /// ⚠️ **탭을 넘긴 뒤에 읽으면 늦다.** 그때 읽으면 디코드가 그 프레임에서 일어나
    ///    배경이 한 박자 늦게 들어오고, 그 사이가 바닥색으로 비친다.
    ///    옆 탭 것까지 미리 읽어 두면 넘기는 순간에는 그릴 일만 남는다.
    func preloadBackgrounds() {
        BackgroundImageStore.preload(Array(perTabBackgrounds.values) + [listBackgroundImage])
    }

    func persistPerTabBackgrounds() {
        AppGroup.defaults?
            .set(perTabBackgrounds, forKey: DefaultsKey.listBackgroundPerTabV1)
        preloadBackgrounds()
    }

    /// 배경 선택 적용 - 범위에 따라 현재 탭 덮어쓰기 또는 전체 기본값(+탭 덮어쓰기 초기화).
    func applyBackground(_ name: String) {
        HapticManager.shared.selection()
        withAnimation(.easeInOut(duration: 0.25)) {
            if backgroundScopeAllTabs {
                listBackgroundImage = name
                perTabBackgrounds = [:]
            } else {
                perTabBackgrounds[viewModel.selectedCategoryTab.storageKey] = name
            }
        }
        persistPerTabBackgrounds()
    }

    /// 배경 제안을 꺼낼 때가 됐는지.
    ///
    /// ⚠️ 예전에는 **설치 첫날 1초 만에** 물었다. 아직 뭐 하는 앱인지도 모르는 사람에게
    ///    "배경 사진 깔아볼래요?"를 들이미는 셈이라, 대부분 그냥 닫고 그걸로 끝이었다
    ///    (한 번 닫으면 다시 안 뜬다 - 가장 좋은 기능을 첫날에 태워 없앤 것).
    ///
    /// 두 가지를 모두 만족해야 꺼낸다:
    ///  ① 설치 후 **최소 일주일** - 꾸미기는 도구가 손에 익은 다음의 즐거움이다.
    ///  ② 단축어가 어느 정도 쌓였을 것 - 카드가 몇 장 없는 화면에 배경을 깔면
    ///     살아나기는커녕 휑한 게 더 드러난다.
    static let backgroundOfferMinDays: Double = 7
    static let backgroundOfferMinMemos = 3

    var isReadyForBackgroundOffer: Bool {
        guard viewModel.memos.count >= Self.backgroundOfferMinMemos else { return false }
        // 설치일이 없으면(아직 기록 전) 아직 이르다고 본다 - 일찍 묻느니 늦게 묻는다.
        guard let installed = UserDefaults.standard.object(forKey: "app_install_date") as? Date else {
            return false
        }
        return Date().timeIntervalSince(installed) >= Self.backgroundOfferMinDays * 86_400
    }

    /// 썸네일 선택 표시 기준 - 현재 범위에서 그 이미지가 적용돼 있는지.
    func isBackgroundSelected(_ name: String) -> Bool {
        backgroundScopeAllTabs ? (listBackgroundImage == name) : (resolvedBackgroundImage == name)
    }
}
