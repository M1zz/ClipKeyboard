//
//  BlankStartLearnMoreSheet.swift
//  ClipKeyboard
//
//  "이 앱으로 할 수 있는 일 더 알아보기". 지금 다 외우지 않아도 된다고 말하고,
//  기능마다 배웠는지(장부)를 붙여 보여 준다. 안 배운 것은 "쓸 때 알려 줘요".
//

import SwiftUI

struct BlankStartLearnMoreSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// 첫 실행의 그림(intro)은 빼고, 사람이 알아들을 단위로 보여 준다.
    private let items: [Lesson] = [.copy, .paste, .send, .insert, .makeOwn, .keyboard, .template, .stack, .secure, .category, .recent]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(items) { lesson in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(lesson.title).font(.body.weight(.semibold))
                                Text(lesson.subtitle).font(.body).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            stateTag(LessonLedger.hasLearned(lesson))
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                } footer: {
                    Text(NSLocalizedString("지금 다 외우지 않아도 돼요. 쓸 때가 오면 그 자리에서 보여 드려요.",
                                           comment: "Learn more sheet: footer, you don't need to memorize now"))
                        .font(.body)
                }
            }
            .navigationTitle(NSLocalizedString("이 앱으로 할 수 있는 일", comment: "Learn more sheet: title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    GlassCircleButton(AppSymbol.xmark, role: .secondary,
                                      label: NSLocalizedString("닫기", comment: "")) { dismiss() }
                }
            }
        }
    }

    private func stateTag(_ learned: Bool) -> some View {
        Text(learned
             ? NSLocalizedString("배웠어요", comment: "Learn more sheet: lesson already learned")
             : NSLocalizedString("쓸 때 알려 줘요", comment: "Learn more sheet: lesson will be taught when needed"))
            .font(.body.weight(.semibold))
            .foregroundStyle(learned ? Color.green : Color.secondary)
    }
}

// MARK: - 칸 이름

extension Lesson {
    var title: String {
        switch self {
        case .intro: return NSLocalizedString("처음 보는 그림", comment: "Lesson title: the intro animation")
        case .copy: return NSLocalizedString("눌러서 복사", comment: "Lesson title: tap to copy")
        case .paste: return NSLocalizedString("붙여넣기", comment: "Lesson title: paste")
        case .send: return NSLocalizedString("보내기", comment: "Lesson title: send")
        case .insert: return NSLocalizedString("바로 넣기", comment: "Lesson title: insert with one tap")
        case .makeOwn: return NSLocalizedString("내 단축어 만들기", comment: "Lesson title: make your own snippet")
        case .keyboard: return NSLocalizedString("키보드 켜기", comment: "Lesson title: turn on the keyboard")
        case .template: return NSLocalizedString("템플릿 빈칸", comment: "Lesson title: template blanks")
        case .stack: return NSLocalizedString("여러 값 스택", comment: "Lesson title: stack with several values")
        case .secure: return NSLocalizedString("보안 단축어", comment: "Lesson title: secure snippet")
        case .category: return NSLocalizedString("분류 탭", comment: "Lesson title: category tabs")
        case .recent: return NSLocalizedString("최근 복사한 것", comment: "Lesson title: recently copied")
        case .stage: return NSLocalizedString("키보드 미리보기", comment: "Lesson title: keyboard preview in the app")
        }
    }

    var subtitle: String {
        switch self {
        case .intro: return NSLocalizedString("복사해서 담아 두고 꺼내 쓰기", comment: "Lesson subtitle: intro")
        case .copy: return NSLocalizedString("담아 둔 것을 누르면 복사돼요", comment: "Lesson subtitle: copy")
        case .paste: return NSLocalizedString("입력칸을 눌러 붙여넣어요", comment: "Lesson subtitle: paste")
        case .send: return NSLocalizedString("보내면 말풍선이 돼요", comment: "Lesson subtitle: send")
        case .insert: return NSLocalizedString("붙여넣지 않아도 버튼이 바로 넣어요", comment: "Lesson subtitle: insert")
        case .makeOwn: return NSLocalizedString("자주 쓰는 내 글을 담아요", comment: "Lesson subtitle: make your own")
        case .keyboard: return NSLocalizedString("다른 앱에서 지구본 한 번", comment: "Lesson subtitle: keyboard")
        case .template: return NSLocalizedString("이름만 바꿔 여러 사람에게", comment: "Lesson subtitle: template")
        case .stack: return NSLocalizedString("누를 때마다 다음 값이 들어가요", comment: "Lesson subtitle: stack")
        case .secure: return NSLocalizedString("Face ID 뒤에 잠가 둬요", comment: "Lesson subtitle: secure")
        case .category: return NSLocalizedString("업무 · 개인처럼 나눠 담아요", comment: "Lesson subtitle: category")
        case .recent: return NSLocalizedString("복사한 글이 30일 동안 남아요", comment: "Lesson subtitle: recent")
        case .stage: return NSLocalizedString("다른 앱에서 보일 키보드를 여기서 미리", comment: "Lesson subtitle: keyboard preview")
        }
    }
}
