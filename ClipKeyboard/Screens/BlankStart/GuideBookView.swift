//
//  GuideBookView.swift
//  ClipKeyboard
//
//  설정 ▸ **가이드북.** 지금까지의 그림 · 해 보기를 언제든 다시 본다.
//  본 것에는 "봤어요" 가 붙는다(`LessonLedger`).
//

import SwiftUI
import LeeoKit

struct GuideBookView: View {
    @State private var replay: Replay?
    @State private var refresh = 0

    enum Replay: Identifiable {
        case firstRun, practice, keyboard, feature(AppFeature)
        var id: String {
            switch self {
            case .firstRun: return "firstRun"
            case .practice: return "practice"
            case .keyboard: return "keyboard"
            case .feature(let f): return f.rawValue
            }
        }
    }

    private struct Row: Identifiable {
        let id: String
        let lesson: Lesson
        let replay: Replay
    }

    private var rows: [Row] {
        [Row(id: "intro", lesson: .intro, replay: .firstRun),
         Row(id: "insert", lesson: .insert, replay: .practice),
         Row(id: "keyboard", lesson: .keyboard, replay: .keyboard)]
        + AppFeature.allCases.map { Row(id: $0.rawValue, lesson: $0.lesson, replay: .feature($0)) }
    }

    var body: some View {
        List {
            Section {
                ForEach(rows) { row in
                    let seen = LessonLedger.hasLearned(row.lesson)
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title(row)).font(.body.weight(.semibold))
                            Text(seen ? NSLocalizedString("봤어요", comment: "Guidebook: already seen") + " · " + row.lesson.subtitle
                                      : row.lesson.subtitle)
                                .font(.body)
                                .foregroundStyle(seen ? Color.green : Color.secondary)
                        }
                        Spacer(minLength: 8)
                        Button {
                            HapticManager.shared.selection()
                            replay = row.replay
                        } label: {
                            Text(seen ? NSLocalizedString("다시 보기", comment: "Guidebook: watch again")
                                      : NSLocalizedString("보기", comment: "Guidebook: watch"))
                                .font(.body.weight(.bold))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Color.accentColor.opacity(0.14), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text(NSLocalizedString("처음에 본 그림과 해 보기를 언제든 다시 볼 수 있어요.", comment: "Guidebook footer"))
                    .font(.body)
            }
        }
        .id(refresh)
        .navigationTitle(NSLocalizedString("가이드북", comment: "Guidebook title"))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $replay, onDismiss: { refresh += 1 }) { r in
            switch r {
            case .firstRun: BlankStartView(replayFrom: .intro) { replay = nil }
            case .practice: BlankStartView(replayFrom: .practice(.copy)) { replay = nil }
            case .keyboard: KeyboardLessonView { replay = nil }
            case .feature(let f): FeatureLessonView(feature: f) { replay = nil }
            }
        }
    }

    private func title(_ row: Row) -> String {
        row.lesson == .insert
            ? NSLocalizedString("복사 · 붙여넣기 · 바로 넣기", comment: "Guidebook: the hands-on first run")
            : row.lesson.title
    }
}
