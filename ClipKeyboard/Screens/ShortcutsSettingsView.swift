//
//  ShortcutsSettingsView.swift
//  ClipKeyboard
//
//  설정 > 단축어
//

import SwiftUI
import LeeoKit

/// 단축어 - 무엇을 저장하고 어떻게 정리하는가.
///
/// ⚠️ 예전에는 목록 화면 오른쪽 위 ⋯ 메뉴에 있던 것들이다. 바에 ⋯ 와 + 와
///    금고를 다 두려니 시스템이 넘친다고 보고 오버플로 ⋯ 를 하나 더 만들어서
///    ⋯ 가 둘로 보였고, 금고는 그 안에 접혀 사라졌다. 자주 안 여는 것들은
///    설정에 있는 편이 찾기도 쉽다.
struct ShortcutsSettingsView: View {

    @Environment(\.appTheme) private var theme
    /// `{날짜}` 모양. App Group 이라 키보드도 같은 값을 본다.
    @AppStorage(DefaultsKey.templateDateFormat, store: AppGroup.defaults)
    private var dateTokenFormatRaw: String = DateTokenFormat.automatic.rawValue
    /// `{시간}` 모양.
    @AppStorage(DefaultsKey.templateTimeFormat, store: AppGroup.defaults)
    private var timeTokenFormatRaw: String = TimeTokenFormat.automatic.rawValue

    /// 목록 카드의 누르기와 꾹 누르기를 뒤집는다. 앱 안에서만 쓰므로 표준 UserDefaults.
    @AppStorage(AppPrefs.cardTapOpensMenu.key)
    private var cardTapOpensMenu: Bool = AppPrefs.cardTapOpensMenu.fallback

    var body: some View {
        List {
            usageSection
            cardTapSection
            organizeSection
        }
        .settingsCategoryChrome(title: NSLocalizedString("단축어", comment: "Settings section: shortcuts"))
    }

    // MARK: - 섹션

    /// 어떻게 쓸지 고르는 것들.
    private var usageSection: some View {
        Section {
            // 활용 사례는 페르소나로 고르는 화면이라 페르소나와 나란히 둔다.
            // ⚠️ 예전에는 이 행이 "단축어 관리"와 "도움말" 양쪽에 있었다(같은 UsageGuideView).
            //    같은 곳으로 가는 문이 둘이면 다른 화면인 줄 안다. 여기 하나만 남긴다.
            FoldLink(destination: UsageGuideView()) {
                Label(NSLocalizedString("이렇게들 써요", comment: "Use cases / usage scenarios"),
                      systemImage: AppSymbol.lightbulb)
            }
            // 예전에는 페르소나를 고르는 자리였다. 이제 앱이 알아보고, 여기서는 근거를 보고 바로잡는다.
            FoldLink(destination: UsageProfileSettingsView()) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("나에게 맞추기", comment: "Usage profile settings title: the app adapts to how you use it"))
                        Text(PersonaResolver.confident?.localizedTitle
                             ?? NSLocalizedString("자동", comment: "Usage profile row subtitle: automatic, nothing inferred yet"))
                            .font(.body)
                            .foregroundColor(theme.textMuted)
                    }
                } icon: {
                    Image(systemName: AppSymbol.personCropCircleBadgeCheckmark)
                }
            }
        }
    }

    /// 목록에서 카드를 눌렀을 때의 일.
    ///
    /// ⚠️ 기본은 꺼짐이다(누르면 복사). 쓰던 사람의 손이 업데이트로 바뀌면 안 된다.
    ///    켜는 사람은 쓰는 일을 키보드에서 하고 앱에는 고치러 들어오는 사람이다(2026-11 사용자 요청).
    private var cardTapSection: some View {
        Section {
            Toggle(isOn: $cardTapOpensMenu) {
                Label(NSLocalizedString("카드를 누르면 메뉴 열기", comment: "Settings toggle: in the app's list, tapping a Phrase card opens its menu (edit, delete...) instead of copying it"),
                      systemImage: AppSymbol.handTap)
            }
        } footer: {
            Text(NSLocalizedString("켜면 앱에서 단축어를 눌렀을 때 복사하지 않고 편집 · 삭제 메뉴를 열어요. 복사는 길게 눌러서 해요. 키보드는 그대로예요.",
                                   comment: "Footer for the tap-opens-menu toggle: with it on, tapping a Phrase in the app opens the edit/delete menu instead of copying, long press copies, and the keyboard is unchanged"))
                .font(.body)
        }
    }

    /// 만들어 둔 것을 들여다보고 정리하는 것들.
    ///
    /// ⚠️ 빈칸 관리 · 카테고리 관리 · 보관함은 **붙어 있어야 한다.** 보관함이 페르소나 옆에
    ///    있었더니 고르는 것들 사이에 담아 두는 것이 하나 끼어 있는 꼴이었다.
    private var organizeSection: some View {
        Section {
            // ⚠️ **단추가 아니라 `NavigationLink` 다.** 단추로 두면 옆줄들과 달리 오른쪽
            //    화살표가 없어서, 들어가는 줄인지 그 자리에서 무엇이 일어나는 줄인지
            //    모양만으로는 알 수 없었다.
            // ⚠️ 단축어 목록은 들어간 뒤에 메인 밖에서 읽는다. 여기서 읽으면 이 화면을 그릴 때마다 파일을 푼다.
            FoldLink(destination: LoadedPage(load: { (try? MemoStore.shared.load(type: .memo)) ?? [] }) {
                PlaceholderManagementView(allMemos: $0)
            }) {
                Label(NSLocalizedString("빈칸 관리", comment: "Placeholder management title (by name)"),
                      systemImage: AppSymbol.listBullet)
            }
            dateFormatRow
            timeFormatRow
            // 카테고리 아이콘은 이 화면 안에서 이어서 고른다(예전에는 형제 행이었다).
            FoldLink(destination: CategorySettings()) {
                Label(NSLocalizedString("카테고리 관리", comment: "Manage categories settings entry"),
                      systemImage: AppSymbol.folderBadgeGearshape)
            }
            FoldLink(destination: QuickNoteInboxView()) {
                Label(NSLocalizedString("보관함", comment: "Quick note inbox entry"),
                      systemImage: AppSymbol.trayFull)
            }
        }
    }

    // MARK: - 날짜 · 시간 형식

    /// `{날짜}` · `{시간}` 을 어떤 모양으로 넣을지 고르러 가는 행.
    ///
    /// ⚠️ 행에는 **지금 값을 그 모양으로 직접 그려서** 보여준다. "MM/DD/YYYY" 같은
    ///    패턴 글자는 개발자만 읽는다. 08/31/2026 은 누구나 읽는다.
    ///
    /// 예전에는 여기가 `Picker` 였다. 사용자가 자기 모양을 만들 수 있게 되면서
    /// (더하고 지우는 자리가 필요해) 화면으로 옮겼다.
    private func tokenFormatRow<Format: TokenFormat>(
        _ type: Format.Type,
        raw: String,
        title: String,
        systemImage: String,
        chips: [TokenFormatField.Chip]
    ) -> some View {
        FoldLink {
            TokenFormatSettingsView(title: title, chips: chips, of: Format.self)
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text(TokenFormatOption<Format>(raw: raw).sampleText())
                    .foregroundColor(theme.textMuted)
                    .lineLimit(1)
            }
        }
    }

    private var dateFormatRow: some View {
        tokenFormatRow(DateTokenFormat.self,
                       raw: dateTokenFormatRaw,
                       title: NSLocalizedString("날짜 형식", comment: "Date format setting row title"),
                       systemImage: AppSymbol.calendar,
                       chips: TokenFormatField.dateChips)
    }

    /// 날짜 바로 아래에 둔다 - 같은 종류의 선택이다.
    private var timeFormatRow: some View {
        tokenFormatRow(TimeTokenFormat.self,
                       raw: timeTokenFormatRaw,
                       title: NSLocalizedString("시간 형식", comment: "Time format setting row title"),
                       systemImage: AppSymbol.clock,
                       chips: TokenFormatField.timeChips)
    }
}
