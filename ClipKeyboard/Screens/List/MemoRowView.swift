//
//  MemoRowView.swift
//  ClipKeyboard
//
//  Created by Leeo on 12/11/25.
//

import SwiftUI

// Separate view for memo row to reduce complexity
// v4.3 Redesign: design-handoff 기반 CatIcon + 인라인 Template/Combo 배지 +
// 새 프리뷰 라인. 기존 business 로직(resolvedType 등)은 그대로 유지.
struct MemoRowView: View {
    let memo: Memo
    let fontSize: CGFloat
    var showFavoriteNudge: Bool = false

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            leadingIcon

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(memo.title)
                        .font(theme.bodyFont(size: 15, weight: .semibold))
                        .foregroundColor(theme.text)
                        .lineLimit(1)
                    if memo.isTemplate {
                        TagBadge(label: NSLocalizedString("Template", comment: "Tag: template"))
                    }
                    if memo.isCombo {
                        TagBadge(label: NSLocalizedString("Combo", comment: "Tag: combo"))
                    }
                    if memo.isSecure {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(theme.textFaint)
                    }
                }

                let previewText = MemoPreviewFormatter.preview(for: memo, resolvedType: resolvedType)
                if !previewText.isEmpty {
                    Text(previewText)
                        .font(theme.bodyFont(size: 13))
                        .foregroundColor(theme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .accessibilityLabel(
                            MemoPreviewFormatter.accessibilityPreview(for: memo, resolvedType: resolvedType)
                        )
                }

                HStack(spacing: 8) {
                    if let relative = relativeTimeLabel {
                        Text(relative)
                            .font(.system(size: 11))
                            .foregroundColor(theme.textFaint)
                    }
                }
                .padding(.top, 1)
            }

            Spacer()

            // 즐겨찾기 하트 표시
            if memo.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.pink)
            }

            if showFavoriteNudge {
                FavoriteNudgeHeart()
            }
        }
    }

    /// 좌측 아이콘. 이미지 메모면 실제 이미지 썸네일을, 아니면 카테고리 CatIcon을 보여준다.
    @ViewBuilder
    private var leadingIcon: some View {
        #if os(iOS)
        if (memo.contentType == .image || memo.contentType == .mixed),
           let firstImageFileName = memo.imageFileNames.first,
           let image = MemoStore.shared.loadImage(fileName: firstImageFileName) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(theme.divider, lineWidth: 0.5)
                )
        } else {
            CatIcon(category: ClipCategory.from(itemType: resolvedType), size: 40)
        }
        #else
        CatIcon(category: ClipCategory.from(itemType: resolvedType), size: 40)
        #endif
    }

    /// 현재 메모에 적용할 타입 결정.
    /// ClipboardClassificationService의 메모이즈된 resolver를 사용한다.
    /// - 명시 카테고리 매칭 → autoDetectedType → contentType(이미지) → 콘텐츠 기반 자동분류
    /// - 결과는 in-memory 캐시되며 memo.value가 바뀔 때만 재계산된다.
    private var resolvedType: ClipboardItemType? {
        ClipboardClassificationService.shared.resolvedType(for: memo)
    }

    /// 카테고리 아이콘
    private var categoryIcon: Image {
        if let type = resolvedType {
            return Image(systemName: type.icon)
        }
        return Image(systemName: "doc.text")
    }

    /// 카테고리 색상
    private var categoryColor: Color {
        if let type = resolvedType {
            return Color.fromName(type.color)
        }
        return .gray
    }

    /// 카테고리명을 다국어 지원 이름으로 변환
    private func categoryLocalizedName(_ category: String) -> String {
        // 카테고리가 ClipboardItemType의 rawValue와 일치하는지 확인
        if let type = ClipboardItemType.allCases.first(where: { $0.rawValue == category }) {
            return type.localizedName
        }
        // 일치하지 않으면 카테고리명을 그대로 번역 시도
        return NSLocalizedString(category, comment: "Category name")
    }

    // MARK: - Time / Usage Signals

    /// "3분 전" 같은 상대 시간 라벨. lastUsedAt 우선, 없으면 lastEdited 폴백.
    private var relativeTimeLabel: String? {
        let reference = memo.lastUsedAt ?? memo.lastEdited
        let interval = Date().timeIntervalSince(reference)
        guard interval >= 0 else { return nil }
        // 30일 이상 지나면 노이즈가 돼서 숨김.
        if interval > 60 * 60 * 24 * 30 { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: reference, relativeTo: Date())
    }

}

// MARK: - Favorite Nudge Heart Animation

/// 즐겨찾기 넛지 하트 애니메이션 뷰
/// 오른쪽 밖에서 spring으로 튀어나오고 3초 후 fade out
struct FavoriteNudgeHeart: View {
    @State private var appear = false

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 20))
            .foregroundColor(.pink)
            .offset(x: appear ? 0 : 40)
            .opacity(appear ? 1 : 0)
            .scaleEffect(appear ? 1.0 : 0.5)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.4)) {
                    appear = true
                }
                // 3초 후 fade out
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        appear = false
                    }
                }
            }
    }
}
