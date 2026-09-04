//
//  DidYouKnowView.swift
//  ClipKeyboard
//
//  **그거 아세요?** 한 번에 한 가지를 알려 주는 작은 화면.
//
//  ⚠️ 작게 뜬다(`.medium` detent). 전체 화면으로 막아서면 "읽고 싶은 것"이 아니라
//     "치워야 하는 것"이 된다. 하던 일이 뒤에 보여야 잠깐 읽고 돌아갈 수 있다.
//
//  ⚠️ 나가는 길이 둘이다. **알겠어요**(다음에 또 들을게요)와 **그만 볼게요**.
//     끄는 길이 없으면 그때부터 이 화면은 광고다.
//

import SwiftUI

struct DidYouKnowView: View {
    let item: DidYouKnow
    /// 읽고 나서 갈 곳을 골랐다.
    var onAction: (DidYouKnow.Action) -> Void = { _ in }
    let onClose: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 머리말 - 이 화면이 무엇인지 한 단어로.
            Text(NSLocalizedString("그거 아세요?", comment: "Did you know header"))
                .font(.caption.weight(.semibold))
                .kerning(1.2)
                .foregroundColor(theme.accent)
                .padding(.top, 26)

            HStack(alignment: .top, spacing: 14) {
                Image(systemName: item.symbol)
                    .font(.title.weight(.medium))
                    .foregroundColor(theme.accent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(theme.accentSoft))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.title3.weight(.bold))
                        .foregroundColor(theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.body)
                        .font(.subheadline)
                        .foregroundColor(theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 14)

            Spacer(minLength: 18)

            if let action = item.action {
                Button {
                    onAction(action)
                } label: {
                    Text(action.localizedLabel)
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.accentFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                            .fill(theme.accent))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }

            Button(action: onClose) {
                Text(NSLocalizedString("알겠어요", comment: "Did you know: dismiss"))
                    .font(.body.weight(.semibold))
                    .foregroundColor(item.action == nil ? theme.accentFg : theme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous)
                            .fill(item.action == nil ? theme.accent : theme.surfaceAlt)
                    )
            }
            .buttonStyle(.plain)

            // 끄는 길 - 눈에 덜 띄게 두되 **반드시 있어야 한다.**
            Button {
                DidYouKnowScheduler.isOptedOut = true
                onClose()
            } label: {
                Text(NSLocalizedString("이런 안내 그만 볼게요", comment: "Did you know: opt out"))
                    .font(.footnote)
                    .foregroundColor(theme.textFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.bg.ignoresSafeArea())
    }
}

// MARK: - 다 모아 보기

/// 지나간 이야기까지 **언제든 다시 볼 수 있는 자리.**
///
/// ⚠️ 띄엄띄엄 오는 안내에는 반드시 이 자리가 있어야 한다. 사흘에 한 번 스쳐 지나가는
///    것만으로는, 정작 필요해진 날("그때 잠글 수 있다고 하지 않았나?") 다시 찾을 길이 없다.
///
/// ⚠️ 본 것과 안 본 것을 갈라 두지 않는다. 여기 온 사람은 **찾으러** 온 것이지
///    진도를 확인하러 온 것이 아니다.
struct DidYouKnowListView: View {
    @Environment(\.appTheme) private var theme
    @State private var optedOut = DidYouKnowScheduler.isOptedOut
    /// 눌러서 펼쳐 본 이야기. 값이 있을 때만 모달이 올라온다.
    ///
    /// ⚠️ `isPresented` 로 띄우지 않는다. 켜는 값과 그릴 값이 둘로 나뉘면 SwiftUI 가
    ///    시트를 올리는 시점에 그릴 값이 아직 안 들어와 **빈 시트**가 뜬다.
    ///    이 앱에서 실제로 한 번 그렇게 떴다.
    @State private var opened: DidYouKnow?

    var body: some View {
        List {
            Section {
                ForEach(DidYouKnow.all) { item in
                    // ⚠️ 목록에서는 **줄여서** 보여준다. 열세 개를 전문으로 늘어놓으면
                    //    찾으러 온 사람이 스크롤부터 해야 한다. 자세한 것은 눌러서 본다.
                    Button {
                        opened = item
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.symbol)
                                .font(.body.weight(.medium))
                                .foregroundColor(theme.accent)
                                .frame(width: 28)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(theme.text)
                                Text(item.body)
                                    .font(.caption)
                                    .foregroundColor(theme.textMuted)
                                    .lineLimit(2)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 4)
                            Image(systemName: AppSymbol.chevronRight)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(theme.textFaint)
                                .accessibilityHidden(true)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(NSLocalizedString("그거 아세요?", comment: "Did you know header"))
            }

            Section {
                Toggle(isOn: Binding(
                    get: { !optedOut },
                    set: { on in
                        optedOut = !on
                        DidYouKnowScheduler.isOptedOut = !on
                    }
                )) {
                    Text(NSLocalizedString("가끔 새 안내 받기", comment: "Did you know: opt in toggle"))
                }
            } footer: {
                Text(NSLocalizedString("사흘에 한 번, 아직 안 본 것만 하나씩 알려드려요. 다 보고 나면 더 뜨지 않아요.",
                                       comment: "Did you know: cadence footer"))
            }
        }
        .navigationTitle(NSLocalizedString("그거 아세요?", comment: "Did you know header"))
        .navigationBarTitleDisplayMode(.inline)
        // 하나를 누르면 그 이야기만 따로 올라온다 - 처음 만났을 때와 **같은 화면**이다.
        // 여기서만 다른 모양으로 보여주면 "아까 그거"를 못 알아본다.
        .sheet(item: $opened) { item in
            DidYouKnowView(item: item,
                           onAction: { action in
                               opened = nil
                               // 시트가 내려간 뒤에 데려간다 - 겹치면 둘 다 제대로 안 뜬다.
                               DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                   NotificationCenter.postOnMain(name: .didYouKnowAction,
                                                                   object: action)
                               }
                           },
                           onClose: { opened = nil })
                .presentationDetents([.medium])
        }
    }
}
