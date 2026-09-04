//
//  SearchNoResultsView.swift
//  ClipKeyboard
//
//  찾는 것이 없을 때의 화면.
//
//  ⚠️ 메모가 하나도 없을 때 쓰는 빈 화면과 **다른 그림**이다. 여기서는 "없다"만 말하지
//     않고, 그 검색어로 하나 만들어 보라고 권한다. 찾으려 했다는 건 그런 게 있으면
//     좋겠다는 뜻이라, 없다고만 하고 끝내면 그 사람은 빈손으로 돌아간다.
//

import SwiftUI
import LeeoKit

struct SearchNoResultsView: View {

    let query: String
    /// 실제 메모 격자와 **같은 열 수**. 제안 카드도 진짜 카드처럼 보여야 한다.
    let columns: [GridItem]
    let cardHeight: CGFloat
    /// 제안 카드를 눌렀을 때 - 이 이름으로 새 단축어 만들기.
    let onCreate: (String) -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(format: NSLocalizedString("'%@' 검색 결과가 없어요", comment: "Search empty state title with query"), query))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(NSLocalizedString("이런 단축어를 만들어 보는 건 어떠세요?", comment: "Search empty state: suggestion subhead"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                // 실제 메모 그리드와 동일한 레이아웃 - 제안 카드도 진짜 메모 카드처럼 보인다.
                LazyVGrid(columns: columns, spacing: 12) {
                    suggestionCard
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 120)
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    /// 검색어를 제목으로 채운 "추가 제안" 카드. 고스트 카드와 같은 비주얼
    /// (실제 메모 카드 치수·제목 스타일 + 반투명·점선으로 "아직 없는 메모" 표현).
    private var suggestionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                // 아이콘을 그냥 띄워 두면 붕 뜬다 - 원형 배지에 담아야 만들다 만 게 아니라
                // 만들어 둔 것으로 보인다.
                Image(systemName: AppSymbol.sparkles)
                    .font(.footnote.weight(.bold))
                    .foregroundColor(theme.accent)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(theme.accent.opacity(0.14)))
                    .accessibilityHidden(true)
                Spacer()
            }
            Spacer(minLength: 16)
            Text(query)
                .font(.title2.weight(.semibold))
                .foregroundColor(theme.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(NSLocalizedString("눌러서 이 이름으로 추가", comment: "Search suggestion card: tap to add with this name"))
                .font(.caption)
                .foregroundColor(theme.textFaint)
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .topLeading)
        .background(theme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
                .strokeBorder(theme.divider, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        )
        .contentShape(RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous))
        .opacity(0.9)
        .onTapGesture {
            HapticManager.shared.selection()
            onCreate(query)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(String(format: NSLocalizedString("'%@' 단축어 만들기", comment: "VoiceOver: create memo from search query"), query))
        .accessibilityHint(NSLocalizedString("눌러서 이 이름으로 단축어를 추가합니다", comment: "VoiceOver: search suggestion hint"))
    }
}
