//
//  ClipKeyboardListComponents.swift
//  ClipKeyboard
//
//  ClipKeyboardList에서 분리한 보조 뷰/시트/배너/필터/팁 모음.
//  (메인 뷰는 ClipKeyboardList.swift 유지)
//

import SwiftUI
import TipKit
import LocalAuthentication

// MARK: - Pro Value Nudge Banner

/// 무료 유저가 가치를 느낀 순간(시간 절약 누적·한도 근접)에 1회 노출되는 Pro 넛지.
/// 페이월 노출률을 높이는 상단 레버 — 탭하면 페이월, ×면 영구 닫힘.
struct ProValueNudgeBanner: View {
    let message: String
    let onTap: () -> Void
    let onDismiss: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(message)
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(NSLocalizedString("Pro 보기", comment: "Pro nudge CTA"))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.orange)
                }
                Spacer(minLength: 8)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(theme.textFaint)
                        .padding(6)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(NSLocalizedString("닫기", comment: "Close / dismiss"))
            }
            .padding(14)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                    .stroke(.orange.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityHint(NSLocalizedString("탭하면 Pro 업그레이드 보기", comment: "VoiceOver: open paywall"))
    }
}

// MARK: - Category Activation Banner (v4.1.0)

/// 카테고리 기능이 미활성일 때 메모가 5개 이상이면 상단에 노출.
/// "쓸래요" → enableFeature, "안 쓸래요" → dismissActivationBanner (영구 닫힘).
struct CategoryActivationBanner: View {
    let onEnable: () -> Void
    let onDismiss: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "folder.badge.plus")
                    .font(.title3)
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("메모가 늘었어요", comment: "Category activation banner title"))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.text)
                    Text(NSLocalizedString("카테고리로 분류해서 빠르게 찾아볼까요?", comment: "Category activation banner subtitle"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                Button(action: onDismiss) {
                    Text(NSLocalizedString("괜찮아요", comment: "Decline category activation"))
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.surfaceAlt)
                        .clipShape(Capsule())
                }
                Button(action: onEnable) {
                    Text(NSLocalizedString("써볼게요", comment: "Accept category activation"))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}

// MARK: - Memo Action Sheet (long-press menu)

/// 메모 카드를 long-press 했을 때 뜨는 커스텀 bottom sheet.
/// confirmationDialog는 iOS에서 button icon을 렌더링 안 해서 자체 시트로 구현.
/// 각 행에 SF Symbol + 텍스트 표시 (삭제는 빨간색).
struct MemoActionSheet: View {
    let memo: Memo
    /// 이동 대상 카테고리 목록 (키보드 페이지와 동일한 통일 목록).
    var categories: [String] = []
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    /// 메모를 다른 카테고리로 이동. nil이면 이동 행을 표시하지 않는다.
    var onMoveToCategory: ((String) -> Void)? = nil
    /// "새 카테고리에 추가" — 즉석 생성 후 이 메모 이동 (호스트가 alert 표시).
    var onCreateNewCategory: (() -> Void)? = nil
    /// "순서 바꾸기" — 그리드 흔들기/드래그 재정렬 모드 진입. nil이면 행을 숨긴다.
    var onReorder: (() -> Void)? = nil
    /// "템플릿으로 만들기" — 편집 화면을 열고 본문에 포커스를 둬 변수 삽입바를 바로 노출.
    /// nil이거나 이미 템플릿/콤보/이미지 메모면 행을 숨긴다.
    var onMakeTemplate: (() -> Void)? = nil
    /// "보안 메모로 설정 / 보안 해제" — 값을 암호화/복호화. 해제 시 호스트에서 생체 인증.
    var onToggleSecure: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // 헤더 — 메모 제목
            HStack {
                Text(memo.title)
                    .font(.headline)
                    .foregroundColor(theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // 액션 그룹
            VStack(spacing: 0) {
                actionRow(
                    label: NSLocalizedString("복사", comment: "Action: copy"),
                    systemImage: "doc.on.doc"
                ) {
                    onCopy()
                    dismiss()
                }
                Divider().padding(.leading, 56)
                actionRow(
                    label: memo.isFavorite
                        ? NSLocalizedString("즐겨찾기 해제", comment: "Action: remove favorite")
                        : NSLocalizedString("즐겨찾기 추가", comment: "Action: add favorite"),
                    systemImage: memo.isFavorite ? "heart.slash" : "heart"
                ) {
                    onToggleFavorite()
                    dismiss()
                }
                // 카테고리 지정 — 미분류(흰 배경) 메모는 "추가", 이미 카테고리가 있으면 "이동".
                if let onMoveToCategory {
                    // 카드가 실제로 색을 갖는 조건과 동일(기능 활성 + 커스텀 카테고리 소속)
                    let hasCategory = CategoryStore.shared.isFeatureEnabled && categories.contains(memo.category)
                    Divider().padding(.leading, 56)
                    Menu {
                        // 즐겨찾기 — '전체' 탭은 지정 대상이 아니지만 즐겨찾기는 카테고리처럼 지정 가능.
                        Button {
                            onToggleFavorite()
                            dismiss()
                        } label: {
                            Label(NSLocalizedString("즐겨찾기", comment: "Favorites"),
                                  systemImage: memo.isFavorite ? "checkmark" : "heart")
                        }
                        Divider()
                        ForEach(categories, id: \.self) { cat in
                            Button {
                                onMoveToCategory(cat)
                                dismiss()
                            } label: {
                                // 각 카테고리에 그 카테고리 심볼을 붙여 표시(현재 카테고리는 체크).
                                Label(cat, systemImage: memo.category == cat ? "checkmark" : categoryIcon(cat))
                            }
                        }
                        if let onCreateNewCategory {
                            Divider()
                            Button {
                                dismiss()
                                onCreateNewCategory()
                            } label: {
                                Label(NSLocalizedString("새 카테고리에 추가", comment: "Create new category and assign memo"), systemImage: "folder.badge.plus")
                            }
                        }
                        if hasCategory {
                            Divider()
                            Button {
                                onMoveToCategory("기본")
                                dismiss()
                            } label: {
                                Label(NSLocalizedString("카테고리에서 빼기", comment: "Action: remove memo from its category"), systemImage: "tray")
                            }
                        }
                    } label: {
                        actionRowLabel(
                            label: hasCategory
                                ? NSLocalizedString("카테고리 이동", comment: "Action: move to category")
                                : NSLocalizedString("카테고리에 추가", comment: "Action: add to category"),
                            systemImage: "folder"
                        )
                    }
                }
                if let onReorder {
                    Divider().padding(.leading, 56)
                    actionRow(
                        label: NSLocalizedString("순서 바꾸기", comment: "Action: reorder memos"),
                        systemImage: "arrow.up.arrow.down"
                    ) {
                        dismiss()
                        onReorder()
                    }
                }
                Divider().padding(.leading, 56)
                actionRow(
                    label: NSLocalizedString("수정", comment: "Action: edit"),
                    systemImage: "pencil"
                ) {
                    dismiss()
                    onEdit()
                }
                // 템플릿으로 만들기 — 아직 템플릿/콤보가 아닌 일반 텍스트 메모에서만 노출.
                if let onMakeTemplate, !memo.isTemplate, !memo.isCombo, memo.contentType == .text {
                    Divider().padding(.leading, 56)
                    actionRow(
                        label: NSLocalizedString("템플릿으로 만들기", comment: "Action: turn memo into a template"),
                        systemImage: "wand.and.sparkles"
                    ) {
                        dismiss()
                        onMakeTemplate()
                    }
                }
                // 보안 메모 설정/해제 — 텍스트 메모에서만(이미지/콤보는 제외).
                if let onToggleSecure, memo.contentType == .text, !memo.isCombo {
                    Divider().padding(.leading, 56)
                    actionRow(
                        label: memo.isSecure
                            ? NSLocalizedString("보안 해제", comment: "Action: remove secure lock from memo")
                            : NSLocalizedString("보안 메모로 설정", comment: "Action: make memo secure"),
                        systemImage: memo.isSecure ? "lock.open" : "lock"
                    ) {
                        dismiss()
                        onToggleSecure()
                    }
                }
                Divider().padding(.leading, 56)
                actionRow(
                    label: NSLocalizedString("삭제", comment: "Action: delete"),
                    systemImage: "trash",
                    isDestructive: true
                ) {
                    dismiss()
                    onDelete()
                }
            }
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
            .padding(.horizontal, 16)

            Spacer(minLength: 12)

            // 취소
            Button {
                dismiss()
            } label: {
                Text(NSLocalizedString("취소", comment: "Cancel"))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(theme.bg)
    }

    private func actionRow(
        label: String,
        systemImage: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            actionRowLabel(label: label, systemImage: systemImage, isDestructive: isDestructive)
        }
        .buttonStyle(.plain)
    }

    /// 행 라벨 비주얼 — Button과 Menu(카테고리 이동)가 공유.
    private func actionRowLabel(
        label: String,
        systemImage: String,
        isDestructive: Bool = false
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 24, alignment: .center)
                .foregroundColor(isDestructive ? .red : theme.text)
            Text(label)
                .font(.body)
                .foregroundColor(isDestructive ? .red : theme.text)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    /// 카테고리 심볼 — 카드/키보드와 동일(사용자 지정 우선, 없으면 기본 팔레트).
    private func categoryIcon(_ name: String) -> String {
        categorySymbol(for: name, in: categories)
    }
}

// MARK: - Category Suggestion Tip (TipKit)

/// 메모를 보고 "이 카테고리를 만들어 정리할까요?"를 부드럽게 제안하는 팁.
/// 메모는 자동 분류로 이미 `category` 값을 갖고 있어, 카테고리를 추가하면 곧바로 모인다.
/// id에 카테고리 rawValue를 포함 → 카테고리별로 1회씩 노출/무효화가 추적된다.
struct CategorySuggestionTip: Tip {
    let categoryRawName: String
    let displayName: String
    let count: Int

    var id: String { "category-suggestion-\(categoryRawName)" }

    var title: Text {
        Text(String(format: NSLocalizedString("'%@' 메모가 %d개 있어요", comment: "Category suggestion tip title — category name, memo count"),
                    displayName, count))
    }

    var message: Text? {
        Text(String(format: NSLocalizedString("'%@' 카테고리를 만들어 한 곳에 모아드릴까요?", comment: "Category suggestion tip message — category name"),
                    displayName))
    }

    var image: Image? {
        Image(systemName: "folder.badge.plus")
    }

    var actions: [Tips.Action] {
        [Tips.Action(id: "create") {
            Text(NSLocalizedString("카테고리 만들기", comment: "Category suggestion: create action button"))
        }]
    }
}

/// 페르소나에 맞는 카테고리 '이름'을 제안하는 팁. 액션(카테고리명)을 탭하면 그 카테고리를 만든다.
struct PersonaCategoryTip: Tip {
    let suggestions: [String]

    var id: String { "persona-category-suggestion" }

    var title: Text {
        Text(NSLocalizedString("이런 카테고리는 어때요?", comment: "Persona category suggestion tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("선택한 사용 패턴에 맞는 카테고리예요. 탭하면 만들어서 메모를 한곳에 모을 수 있어요.", comment: "Persona category suggestion tip message"))
    }
    var image: Image? {
        Image(systemName: "folder.badge.plus")
    }
    var actions: [Tips.Action] {
        suggestions.map { name in Tips.Action(id: name) { Text(name) } }
    }
}

struct SwipePageIndicator: View {
    let total: Int
    let selectedIndex: Int
    var accentColor: Color = .blue

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == selectedIndex ? accentColor : theme.textFaint.opacity(0.35))
                    .frame(width: index == selectedIndex ? 20 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: selectedIndex)
        .animation(.easeInOut(duration: 0.3), value: accentColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Memo Image Background Helper

/// 이미지 메모용 배경 뷰 — 로딩 중엔 회색 플레이스홀더, 완료 후 풀-블리드 표시
struct MemoImageBackground: View {
    let fileName: String
    @State private var image: UIImage? = nil

    var body: some View {
        ZStack {
            Color(uiColor: .systemGray5)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundColor(Color(uiColor: .systemGray3))
            }
        }
        .clipped()
        .onAppear {
            guard image == nil, !fileName.isEmpty else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                // 파일 경로 확인
                let containerURL = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo"
                )
                let filePath = containerURL?.appendingPathComponent("Images").appendingPathComponent(fileName).path ?? "nil"
                let exists = FileManager.default.fileExists(atPath: filePath)
                print("🖼️ [MemoImageBackground] fileName='\(fileName)' path='\(filePath)' exists=\(exists)")

                let loaded = MemoStore.shared.loadImage(fileName: fileName)
                print("🖼️ [MemoImageBackground] loaded=\(loaded != nil ? "✅ \(Int(loaded!.size.width))x\(Int(loaded!.size.height))" : "❌ nil")")
                DispatchQueue.main.async { image = loaded }
            }
        }
    }
}

// MARK: - Activation Card (첫 붙여넣기 유도)

struct ActivationCard: View {
    let onPractice: () -> Void
    let onSnooze: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("⌨️")
                    .font(.title3)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("이제 다른 앱에서 써보세요", comment: "Activation card title"))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.text)
                    Text(NSLocalizedString("아무 텍스트 필드 탭 → 🌐 눌러 전환 → 메모 탭", comment: "Activation card hint"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button(action: onPractice) {
                    Text(NSLocalizedString("지금 연습하기", comment: "Activation card: start practice button"))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.accentColor)
                        .cornerRadius(theme.radiusSm)
                }

                Button(action: onSnooze) {
                    Text(NSLocalizedString("나중에", comment: "Activation card: snooze button"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(theme.surfaceAlt)
                        .cornerRadius(theme.radiusSm)
                }
            }
        }
        .padding(14)
        .background(theme.surface)
        .cornerRadius(theme.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMd)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Template Hint Banner

struct TemplateHintBanner: View {
    let onDismiss: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.purple)
                    .font(.body)
                Text(NSLocalizedString("💡 템플릿으로 반복 입력을 자동화해보세요", comment: "Template hint banner title"))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.text)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                        .padding(6)
                        .background(theme.surfaceAlt)
                        .clipShape(Circle())
                }
                .accessibilityLabel(NSLocalizedString("템플릿 힌트 닫기", comment: "Dismiss template hint banner"))
            }

            Text(NSLocalizedString("{이름}님 안녕하세요! 같은 문구를 변수로 바꿔 빠르게 입력해요.", comment: "Template hint description"))
                .font(.body)
                .foregroundColor(theme.textMuted)

            NavigationLink {
                MemoAdd(insertedIsTemplate: true)
            } label: {
                Text(NSLocalizedString("첫 템플릿 만들기", comment: "Template hint CTA button"))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.purple)
                    .cornerRadius(theme.radiusSm)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onDismiss() }
            })
        }
        .padding(14)
        .background(theme.surface)
        .cornerRadius(theme.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMd)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Occasional Suggestion Banner

struct OccasionalSuggestionBanner: View {
    let suggestion: SuggestionTemplate
    let onDismiss: () -> Void
    let onAdd: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.body)
                Text(NSLocalizedString("이런 것도 써보실래요?", comment: "Occasional suggestion banner title"))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.text)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                        .padding(6)
                        .background(theme.surfaceAlt)
                        .clipShape(Circle())
                }
                .accessibilityLabel(NSLocalizedString("제안 닫기", comment: "Dismiss suggestion banner"))
            }

            HStack(spacing: 10) {
                Text(suggestion.emoji)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(theme.text)
                    Text(suggestion.content.components(separatedBy: "\n").first ?? suggestion.content)
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                        .lineLimit(3)
                }
                Spacer()
            }

            Button(action: onAdd) {
                Text(NSLocalizedString("지금 추가하기", comment: "Accept suggestion button"))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(theme.accent)
                    .cornerRadius(theme.radiusSm)
            }
        }
        .padding(14)
        .background(theme.surface)
        .cornerRadius(theme.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusMd)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Memo Type Filter Bar

struct MemoTypeFilterBar: View {
    @Binding var selectedFilter: ClipboardItemType?
    @Binding var showFavorites: Bool
    let memos: [Memo]
    @State private var isExpanded = false

    private let visibleLimit = 2

    var favoritesCount: Int { memos.filter { $0.isFavorite }.count }

    // resolvedType 기준으로 개수 계산 — 이미지/자동분류 타입까지 반영
    var typeCounts: [ClipboardItemType: Int] {
        var counts: [ClipboardItemType: Int] = [:]
        for memo in memos {
            if let type = ClipboardClassificationService.shared.resolvedType(for: memo) {
                counts[type, default: 0] += 1
            }
        }
        return counts
    }

    // 메모가 있는 타입만, 개수 많은 순 정렬
    var sortedTypes: [ClipboardItemType] {
        ClipboardItemType.allCases
            .filter { typeCounts[$0, default: 0] > 0 }
            .sorted { typeCounts[$0, default: 0] > typeCounts[$1, default: 0] }
    }

    var visibleTypes: [ClipboardItemType] {
        isExpanded ? sortedTypes : Array(sortedTypes.prefix(visibleLimit))
    }

    var hiddenCount: Int { max(0, sortedTypes.count - visibleLimit) }

    // 전체/즐겨찾기 선택 시 타입 필터 해제, 타입 선택 시 즐겨찾기 해제
    private func selectAll() {
        selectedFilter = nil
        showFavorites = false
    }
    private func selectFavorites() {
        selectedFilter = nil
        showFavorites = true
    }
    private func selectType(_ type: ClipboardItemType) {
        showFavorites = false
        selectedFilter = type
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // 전체 버튼
                MemoFilterChip(
                    title: NSLocalizedString("전체", comment: "All"),
                    icon: "list.bullet",
                    count: memos.count,
                    isSelected: selectedFilter == nil && !showFavorites
                ) { selectAll() }

                // 즐겨찾기 버튼 (전체 바로 오른쪽)
                if favoritesCount > 0 {
                    MemoFilterChip(
                        title: NSLocalizedString("즐겨찾기", comment: "Favorites filter chip"),
                        icon: "star.fill",
                        count: favoritesCount,
                        color: "orange",
                        isSelected: showFavorites
                    ) { selectFavorites() }
                }

                // 상위 2개 (또는 전체) 타입 필터
                ForEach(visibleTypes, id: \.self) { type in
                    MemoFilterChip(
                        title: type.localizedName,
                        icon: type.icon,
                        count: typeCounts[type, default: 0],
                        color: type.color,
                        isSelected: selectedFilter == type && !showFavorites
                    ) { selectType(type) }
                }

                // 더 보기 / 접기 버튼
                if hiddenCount > 0 {
                    FilterExpandChip(isExpanded: isExpanded, hiddenCount: hiddenCount) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: selectedFilter) { _, newFilter in
            // 선택된 필터가 숨겨진 영역에 있으면 자동 펼침
            guard let f = newFilter, !visibleTypes.contains(f) else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded = true }
        }
    }
}

struct FilterExpandChip: View {
    let isExpanded: Bool
    let hiddenCount: Int
    let action: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(isExpanded
                     ? NSLocalizedString("접기", comment: "Collapse filter bar")
                     : String(format: NSLocalizedString("+%d개", comment: "More filter count"), hiddenCount))
                    .font(.footnote.weight(.medium))
                Image(systemName: isExpanded ? "chevron.left" : "chevron.right")
                    .font(.caption2.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(theme.surfaceAlt)
            .cornerRadius(theme.radiusLg)
            .foregroundColor(theme.textMuted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded
            ? NSLocalizedString("접기", comment: "Collapse filter bar")
            : String(format: NSLocalizedString("%d개 카테고리 더 보기", comment: "More categories a11y"), hiddenCount))
    }
}

struct MemoFilterChip: View {
    let title: String
    let icon: String
    let count: Int
    var color: String = "blue"
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(isSelected ? .bold : .medium)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        isSelected
                            ? Color.white.opacity(0.25)
                            : Color.black.opacity(0.1)
                    )
                    .cornerRadius(theme.radiusSm)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusLg)
                    .fill(isSelected ? Color.fromName(color) : theme.surfaceAlt)
                    .shadow(
                        color: isSelected ? Color.fromName(color).opacity(0.3) : Color.clear,
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            )
            .foregroundColor(isSelected ? .white : theme.textFaint)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusLg)
                    .strokeBorder(
                        isSelected ? Color.white.opacity(0.2) : Color.clear,
                        lineWidth: 1
                    )
            )
            .scaleEffect(isSelected ? 1.0 : 0.96)
            .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(
            String(format: NSLocalizedString("%@, %d개", comment: "Filter chip: name and count"), title, count)
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(
            isSelected
                ? NSLocalizedString("현재 선택됨", comment: "Filter chip: currently selected")
                : NSLocalizedString("탭하여 이 유형으로 필터링", comment: "Filter chip: tap to filter")
        )
    }
}

// MARK: - Sheet Modifiers
/// 모든 Sheet 프레젠테이션을 관리하는 ViewModifier
struct SheetModifiers: ViewModifier {
    // Sheet 표시 상태
    @Binding var showTemplateInputSheet: Bool
    @Binding var showPlaceholderManagementSheet: Bool
    @Binding var selectedTemplateIdForSheet: UUID?
    @Binding var selectedComboIdForSheet: UUID?

    // 데이터
    let templatePlaceholders: [String]
    @Binding var templateInputs: [String: String]
    let memos: [Memo]
    let currentTemplateMemo: Memo?
    /// v4.0.8: attachedTemplate 흐름이면 본 메모(계좌번호 등). preview 결합용.
    let attachedTemplateBaseMemo: Memo?

    // 콜백
    let onTemplateComplete: () -> Void
    let onTemplateCancel: () -> Void
    let onTemplateCopy: (Memo, String) -> Void
    let onTemplateSheetCancel: () -> Void
    let onComboDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            // 템플릿 입력 시트
            .sheet(isPresented: $showTemplateInputSheet) {
                if let template = currentTemplateMemo {
                    TemplateInputSheet(
                        placeholders: templatePlaceholders,
                        inputs: $templateInputs,
                        onComplete: onTemplateComplete,
                        onCancel: onTemplateCancel,
                        originalText: template.value,
                        baseMemoValue: attachedTemplateBaseMemo?.value ?? "",
                        sourceMemoId: template.id,
                        sourceMemoTitle: template.title
                    )
                    // 메모+템플릿은 합쳐진 결과가 길어 전체 높이로, 일반 템플릿은 중간 높이도 허용.
                    .presentationDetents(attachedTemplateBaseMemo != nil ? [.large] : [.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
            // 플레이스홀더 관리 시트
            .sheet(isPresented: $showPlaceholderManagementSheet) {
                PlaceholderManagementSheet(allMemos: memos)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            // 템플릿 값 입력 하프모달 — 탭하면 키보드 익스텐션과 동일한 UX로
            // 변수를 채우고 우상단 "복사"로 결과를 클립보드에 복사.
            .sheet(item: $selectedTemplateIdForSheet) { templateId in
                if let memo = memos.first(where: { $0.id == templateId }) {
                    TemplateFillSheet(
                        memo: memo,
                        onCopy: { resolved in onTemplateCopy(memo, resolved) },
                        onCancel: onTemplateSheetCancel
                    )
                } else {
                    // 폴백(거의 발생 안 함): 기존 편집 시트.
                    TemplateSheetResolver(
                        templateId: templateId,
                        allMemos: memos,
                        onCopy: onTemplateCopy,
                        onCancel: onTemplateSheetCancel
                    )
                }
            }
            // Combo 미리보기 하프모달 — 탭 시 즉시 복사되고, 순차 입력될 값들을 보여준다.
            .sheet(item: $selectedComboIdForSheet) { comboId in
                ComboPreviewSheet(
                    comboId: comboId,
                    allMemos: memos,
                    onDismiss: onComboDismiss
                )
                // 템플릿 fill 시트와 동일하게 하프모달(필요 시 위로 확장).
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }
}


// MARK: - Category Management Sheet

struct CategoryManagementSheet: View {
    @ObservedObject var viewModel: ClipKeyboardListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showAddAlert = false
    @State private var newName = ""
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            List {
                Section(NSLocalizedString("기본", comment: "Category section: built-in")) {
                    HStack {
                        Label {
                            Text(NSLocalizedString("전체", comment: "Category: all"))
                        } icon: {
                            Image(systemName: "square.grid.2x2.fill")
                                .foregroundColor(.blue)
                        }
                        Spacer()
                        Text(NSLocalizedString("항상 표시", comment: "Category always visible"))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    Toggle(isOn: Binding(
                        get: { viewModel.isCategoryVisible("__favorites__") },
                        set: { viewModel.setCategoryVisible("__favorites__", visible: $0) }
                    )) {
                        Label {
                            Text(NSLocalizedString("즐겨찾기", comment: "Category: favorites"))
                        } icon: {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.clipFavorite)
                        }
                    }
                }

                Section(NSLocalizedString("커스텀", comment: "Category section: custom")) {
                    ForEach(viewModel.customCategories, id: \.self) { cat in
                        Toggle(isOn: Binding(
                            get: { viewModel.isCategoryVisible(cat) },
                            set: { viewModel.setCategoryVisible(cat, visible: $0) }
                        )) {
                            // 실제 카드/키보드에서 쓰는 그 카테고리의 심볼·색으로 표시.
                            Label {
                                Text(cat)
                            } icon: {
                                Image(systemName: categoryIconForName(cat))
                                    .foregroundColor(categoryColorForName(cat))
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for idx in indexSet.sorted(by: >) {
                            viewModel.deleteCustomCategory(viewModel.customCategories[idx])
                        }
                    }
                    .onMove(perform: viewModel.reorderCustomCategories)

                    Button {
                        showAddAlert = true
                    } label: {
                        Label(
                            NSLocalizedString("새 카테고리 추가", comment: "Add new category button"),
                            systemImage: "plus.circle.fill"
                        )
                    }
                }
            }
            .navigationTitle(NSLocalizedString("카테고리 관리", comment: "Category management sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditing
                           ? NSLocalizedString("완료", comment: "Done editing")
                           : NSLocalizedString("편집", comment: "Edit list")) {
                        withAnimation { isEditing.toggle() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("닫기", comment: "Close sheet")) { dismiss() }
                }
            }
        }
        .alert(
            NSLocalizedString("새 카테고리", comment: "Add category alert title"),
            isPresented: $showAddAlert
        ) {
            TextField(NSLocalizedString("카테고리 이름", comment: "Category name placeholder"), text: $newName)
            Button(NSLocalizedString("추가", comment: "Add")) {
                viewModel.addCustomCategory(newName)
                newName = ""
            }
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { newName = "" }
        } message: {
            Text(NSLocalizedString("메모를 분류할 카테고리 이름을 입력하세요.", comment: "Add category alert message"))
        }
    }

    /// 카드/키보드와 동일한 카테고리 심볼·색(공유 헬퍼 위임).
    private func categoryIconForName(_ name: String) -> String {
        categorySymbol(for: name, in: viewModel.customCategories)
    }
    private func categoryColorForName(_ name: String) -> Color {
        categoryTint(for: name, in: viewModel.customCategories)
    }
}
