//
//  FeatureSettingsSection.swift
//  ClipKeyboard
//
//  설정 ▸ **기능 더하기.** 백지 사용자만 본다(기존 사용자는 이미 다 켜져 있다).
//
//  위에 조합 셋(단순하게 · 답장이 많아요 · 전부 쓸래요)과 그중 하나의 '추천', 아래에 기능마다
//  미리보기와 스위치. 처음 켜는 기능은 그 자리에서 그림으로 한 번 해 본다(`FeatureLessonView`).
//  조합으로 여럿을 한꺼번에 켤 때는 수업을 줄줄이 띄우지 않는다. 가이드북에 남는다.
//

import SwiftUI
import LeeoKit

struct FeatureSettingsSection: View {
    @State private var on: Set<AppFeature> = Self.currentlyOn()
    @State private var lesson: AppFeature?
    @State private var recommended: FeaturePreset = .simple

    var body: some View {
        Section {
            ForEach(FeaturePreset.allCases) { preset in presetRow(preset) }
            ForEach(AppFeature.allCases) { feature in featureRow(feature) }
        } header: {
            Text(NSLocalizedString("기능 더하기", comment: "Settings: add features section header"))
        } footer: {
            Text(NSLocalizedString("필요한 것만 켜세요. 켜면 그 자리에 바로 생겨요.", comment: "Settings: add features section footer"))
                .font(.body)
        }
        .onAppear {
            on = Self.currentlyOn()
            let memos = ((try? MemoStore.shared.load(type: .memo)) ?? []).map { ($0.title, $0.value) }
            recommended = FeatureNudge.recommendedPreset(memos: memos)
        }
        .onReceive(NotificationCenter.default.publisher(for: .featureSetChanged)) { _ in on = Self.currentlyOn() }
        .fullScreenCover(item: $lesson) { f in
            FeatureLessonView(feature: f) { lesson = nil }
        }
    }

    // MARK: - 조합

    private func presetRow(_ preset: FeaturePreset) -> some View {
        let selected = FeaturePreset.matching(on) == preset
        return Button {
            HapticManager.shared.selection()
            for f in AppFeature.allCases { FeatureSet.set(f, on: preset.features.contains(f)) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(preset.title).font(.body.weight(.semibold))
                        if preset == recommended {
                            Text(NSLocalizedString("추천", comment: "Settings: recommended preset badge"))
                                .font(.body.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.accentColor, in: Capsule())
                        }
                    }
                    Text(preset.detail).font(.body).foregroundStyle(.secondary)
                    if preset == recommended {
                        Text(preset.why).font(.body).foregroundStyle(Color.accentColor)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? AppSymbol.checkmarkCircleFill : AppSymbol.circle)
                    .font(.title3)
                    .foregroundStyle(selected ? Color.accentColor : Color(.tertiaryLabel))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - 하나씩

    private func featureRow(_ feature: AppFeature) -> some View {
        HStack(spacing: 12) {
            FeaturePreviewTile(feature: feature)
            VStack(alignment: .leading, spacing: 3) {
                Text(feature.lesson.title).font(.body.weight(.semibold))
                Text(feature.lesson.subtitle).font(.body).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(
                get: { on.contains(feature) },
                set: { newValue in
                    FeatureSet.set(feature, on: newValue)
                    // 처음 켤 때 그 자리에서 그림으로 한 번 해 본다
                    if newValue && !LessonLedger.hasLearned(feature.lesson) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { lesson = feature }
                    }
                }))
                .labelsHidden()
                .accessibilityLabel(feature.lesson.title)
        }
    }

    private static func currentlyOn() -> Set<AppFeature> {
        Set(AppFeature.allCases.filter { FeatureSet.isOn($0) })
    }
}

// MARK: - 안쪽 화면

/// 설정 ▸ 기능 더하기. 첫 화면에는 이름 한 줄만 있고, 누르면 이 화면으로 들어온다.
struct FeatureSettingsView: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        List { FeatureSettingsSection() }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("기능 더하기", comment: "Settings: add features section header"))
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 조합 이름

extension FeaturePreset {
    var title: String {
        switch self {
        case .simple: return NSLocalizedString("단순하게", comment: "Feature preset: simple")
        case .reply: return NSLocalizedString("답장이 많아요", comment: "Feature preset: lots of replies")
        case .all: return NSLocalizedString("전부 쓸래요", comment: "Feature preset: everything")
        }
    }
    var detail: String {
        switch self {
        case .simple: return NSLocalizedString("이름과 내용만. 지금 그대로", comment: "Feature preset simple: what it includes")
        case .reply: return NSLocalizedString("템플릿 빈칸 · 최근 복사한 것", comment: "Feature preset reply: what it includes")
        case .all: return NSLocalizedString("다섯 가지 모두", comment: "Feature preset all: what it includes")
        }
    }
    /// 추천한 까닭 한 줄.
    var why: String {
        switch self {
        case .simple: return NSLocalizedString("지금은 이걸로 충분해요", comment: "Feature preset recommended reason: simple")
        case .reply: return NSLocalizedString("답장 글을 담아 둬서", comment: "Feature preset recommended reason: reply")
        case .all: return NSLocalizedString("담아 둔 것이 많아서", comment: "Feature preset recommended reason: all")
        }
    }
}

// MARK: - 미리보기 조각

/// 기능마다 켜면 생기는 모양을 손톱만 하게 보여 준다. 설정 행 · 넛지가 같이 쓴다.
struct FeaturePreviewTile: View {
    let feature: AppFeature

    var body: some View {
        Group {
            switch feature {
            case .template:
                (Text(NSLocalizedString("이름", comment: "Feature lesson template: the blank's label")).foregroundColor(.accentColor).bold()
                 + Text(NSLocalizedString("님 안녕하세요", comment: "Feature preview: template greeting")))
            case .stack:
                Text("1/3 →").foregroundColor(.accentColor).bold()
            case .secure:
                Text("•••• 1234")
            case .category:
                Text(NSLocalizedString("업무", comment: "Feature lesson category: work tab")).bold()
            case .recent:
                Image(systemName: AppSymbol.clockArrowCirclepath).foregroundStyle(Color.accentColor)
            }
        }
        .font(.body)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
        .multilineTextAlignment(.center)
        .frame(width: 72, height: 54)
        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - 넛지 카드

/// 저장 직후 목록 위에 한 번 뜨는 권유. "괜찮아요" / "켜고 해 보기".
struct FeatureNudgeCard: View {
    let feature: AppFeature
    let onYes: () -> Void
    let onNo: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                FeaturePreviewTile(feature: feature)
                VStack(alignment: .leading, spacing: 3) {
                    Text(headline).font(.body.weight(.bold))
                    Text(detail).font(.body).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                button(NSLocalizedString("괜찮아요", comment: "Feature nudge: no thanks"), primary: false, action: onNo)
                button(NSLocalizedString("켜고 해 보기", comment: "Feature nudge: turn on and try"), primary: true, action: onYes)
            }
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.accentColor, lineWidth: 1.5))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func button(_ t: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            Text(t)
                .font(.body.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(primary ? Color.white : Color.primary)
                .background(primary ? Color.accentColor : Color(.secondarySystemFill),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var headline: String {
        switch feature {
        case .secure: return NSLocalizedString("카드번호 같아요. 잠가 둘까요?", comment: "Feature nudge secure: headline")
        case .template: return NSLocalizedString("앞 글과 이름만 다르네요", comment: "Feature nudge template: headline")
        case .stack: return NSLocalizedString("번호만 다른 단축어가 생겼어요", comment: "Feature nudge stack: headline")
        case .category: return NSLocalizedString("단축어가 많아졌어요", comment: "Feature nudge category: headline")
        case .recent: return NSLocalizedString("붙여넣어 담는 일이 잦네요", comment: "Feature nudge recent: headline")
        }
    }

    private var detail: String {
        switch feature {
        case .secure: return NSLocalizedString("Face ID 로 확인해야 꺼낼 수 있어요", comment: "Feature nudge secure: detail")
        case .template: return NSLocalizedString("빈칸 하나로 두면 단축어 하나로 여러 사람에게 써요", comment: "Feature nudge template: detail")
        case .stack: return NSLocalizedString("누를 때마다 다음 값이 들어가는 키 하나로 묶을 수 있어요", comment: "Feature nudge stack: detail")
        case .category: return NSLocalizedString("업무 · 개인처럼 나눠 담으면 찾기 쉬워요", comment: "Feature nudge category: detail")
        case .recent: return NSLocalizedString("복사한 글이 30일 동안 저절로 남게 할 수 있어요", comment: "Feature nudge recent: detail")
        }
    }
}
