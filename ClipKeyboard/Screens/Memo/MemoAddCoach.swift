//
//  MemoAddCoach.swift
//  ClipKeyboard
//
//  새 단축어를 만들 때 **칸을 위에서부터 하나씩 짚어 주는** 안내.
//
//  ⚠️ 튜토리얼의 마지막 걸음(`SnippetsOnboardingStep.makeOwn`)은 여기서 이어진다.
//     무대에서 남의 것을 눌러 보고 + 를 누르면 빈 칸 네 개가 한꺼번에 펼쳐지는데,
//     그때까지 배운 것은 "누르면 들어간다"뿐이라 **무엇을 어디에 적는지**를 모른다.
//     + 를 가리켜 놓고 그 다음을 안 알려 주면, 가리킨 자리에서 흐름이 끊긴다.
//
//  ⚠️ 짚는 순서는 **화면에 놓인 순서 그대로** 위에서 아래다. 눈이 움직이는 방향과
//     안내가 가는 방향이 다르면 매번 어디를 봐야 하는지 다시 찾아야 한다.
//

import SwiftUI
import LeeoKit

// MARK: - 걸음

/// 새 단축어 화면에서 지금 짚고 있는 칸.
///
/// ⚠️ 순서는 화면 순서와 **같아야** 한다(이름 → 입력 방식 → 내용 → 저장).
///    여기 순서를 바꾸면 안내가 화면을 거슬러 올라간다.
enum MemoAddCoachStep: Int, CaseIterable, Equatable {
    /// ① 키보드에 뜰 이름. 단축어의 얼굴이라 맨 위다.
    case name
    /// ② 값을 어디서 가져올지. 스캔·이미지 붙이기.
    case inputMethod
    /// ③ 눌렀을 때 실제로 들어갈 내용.
    case content
    /// ④ 저장. 여기까지 와야 자기 것이 하나 생긴다.
    case save

    var next: MemoAddCoachStep? {
        MemoAddCoachStep(rawValue: rawValue + 1)
    }

    /// 짚으면서 하는 말. **무엇을 적는 칸인지**를 먼저 말하고, 그 다음에 예를 든다.
    /// 빛은 어디를 알려 주고, 이 줄은 무엇을 알려 준다.
    ///
    /// ⚠️ 저장 걸음만 말이 둘이다. 띠를 눌러 여기까지 건너뛴 사람은 내용이 비어 있어
    ///    **저장 버튼이 잠겨 있다.** 그 사람에게 "다 됐어요"라고 하면 안내가 거짓말이 되고,
    ///    잠긴 버튼을 가리키는 꼴이 된다.
    func line(canSave: Bool) -> String {
        switch self {
        case .name:
            return NSLocalizedString("먼저 이름이에요. 키보드에 이 이름이 뜨니까, 나중에 알아볼 말로 적어요.",
                                     comment: "New snippet coach: name field")
        case .inputMethod:
            return NSLocalizedString("값을 사진에서 가져올 수도 있어요. 직접 칠 거면 그냥 넘어가세요.",
                                     comment: "New snippet coach: input method rows")
        case .content:
            return NSLocalizedString("여기가 실제로 붙여넣어질 내용이에요. 키를 누르면 이게 들어가요.",
                                     comment: "New snippet coach: content field")
        case .save:
            return canSave
                ? NSLocalizedString("다 됐어요. 저장하면 키보드에 바로 올라가요.",
                                    comment: "New snippet coach: save button")
                : NSLocalizedString("붙여넣을 내용을 채우면 저장이 열려요.",
                                    comment: "New snippet coach: save button still locked")
        }
    }

    /// 다음으로 가는 단추에 적을 말.
    ///
    /// ⚠️ 마지막 걸음에서 "다음"이라고 하면 안 된다. 뒤에 아무것도 없는데 다음이 있는 척하면
    ///    누른 사람은 사라진 안내를 찾게 된다. 마지막은 **끝났다는 말**이라야 한다.
    var nextTitle: String {
        next == nil
            ? NSLocalizedString("알겠어요", comment: "New snippet coach: last step, dismiss")
            : NSLocalizedString("다음", comment: "Next button")
    }

    /// 이 칸을 **다 채웠는가.** 채웠으면 누르지 않아도 다음으로 넘어간다.
    ///
    /// ⚠️ 다 채웠는지만 답한다. **언제 물을지는 화면이 정한다** - 첫 글자가 들어가는
    ///    순간 넘겨 버리면 이름을 치는 도중에 안내가 아래로 달아난다. 그래서 화면은
    ///    칸에서 손을 뗐을 때 묻는다(`MemoAdd.advanceCoachIfFilled`).
    ///
    /// ⚠️ 입력 방식은 **사진을 붙였을 때만** 채운 것으로 본다. 스캔도 이미지도
    ///    안 골라도 되는 길이라, 여기서 "골라야 넘어간다"로 묶으면 직접 치려는
    ///    사람은 영영 못 지난다. 그 사람은 띠를 눌러서 지나간다.
    func isFilled(title: String, value: String, hasImage: Bool) -> Bool {
        switch self {
        case .name:        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .inputMethod: return hasImage
        case .content:     return !value.isEmpty || hasImage
        case .save:        return false
        }
    }
}

// MARK: - 안내 띠

/// 화면 아래에 눕는 한 줄. 지금 짚고 있는 칸이 무엇인지 말하고, 눌러서 다음으로 간다.
///
/// ⚠️ 무대의 `tutorialCue` 와 **같은 언어**를 쓴다(강조색 바탕에 굵은 글씨).
///    같은 튜토리얼인데 화면마다 안내가 다르게 생기면 이어지는 하나로 안 읽힌다.
///
/// ⚠️ 끄는 자리를 둔다. 안내가 필요 없는 사람에게 네 걸음을 눌러서 지나가게 하면
///    그건 안내가 아니라 통행료다.
///
/// ⚠️ **다음으로 가는 단추가 눈에 보여야 한다.** 처음에는 띠 전체가 "다음"이고 그것뿐이었다.
///    걸음 세기(1/4)가 뒤가 더 있다고 말하는데 **어디를 눌러야 가는지는 어디에도 안 적혀**
///    있어서, 아는 사람만 아무 데나 눌러 지나갔다. 띠를 누르는 길은 그대로 두되(넓어서 편하다),
///    단추를 눌러야 할 곳으로 세워 둔다.
struct MemoAddCoachBar: View {
    let step: MemoAddCoachStep
    /// 지금 저장 버튼이 눌리는 상태인가. 마지막 걸음의 말이 여기서 갈린다.
    let canSave: Bool
    let onNext: () -> Void
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    private var line: String { step.line(canSave: canSave) }

    private var stepCount: String {
        "\(step.rawValue + 1)/\(MemoAddCoachStep.allCases.count)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: AppSymbol.handTap)
                    .font(.subheadline.weight(.bold))
                    .scaleEffect(pulsing ? 1.12 : 1)
                    .accessibilityHidden(true)

                Text(line)
                    .font(.subheadline.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 14) {
                // 걸음 세기 - 몇 개 남았는지 보이면 끝이 있다는 걸 안다.
                Text(verbatim: stepCount)
                    .font(.caption.weight(.heavy))
                    .monospacedDigit()
                    .opacity(0.75)
                    .accessibilityLabel(String(format: NSLocalizedString("%1$d단계 중 %2$d단계",
                                                                        comment: "Coach step counter (a11y)"),
                                               MemoAddCoachStep.allCases.count, step.rawValue + 1))

                Spacer(minLength: 0)

                Button(action: onSkip) {
                    Text(NSLocalizedString("안내 끄기", comment: "Turn off the new snippet coach"))
                        .font(.footnote.weight(.semibold))
                        .opacity(0.85)
                }
                .buttonStyle(.plain)

                // ⚠️ 띠 바탕이 강조색이라 단추는 **색을 뒤집어야** 선다. 같은 강조색 위에
                //    강조색 단추를 얹으면 글자만 떠 있는 꼴이라 누를 곳으로 안 읽힌다.
                Button {
                    HapticManager.shared.light()
                    onNext()
                } label: {
                    HStack(spacing: 5) {
                        Text(step.nextTitle)
                            .font(.subheadline.weight(.bold))
                        Image(systemName: AppSymbol.chevronRight)
                            .font(.caption2.weight(.black))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.accentForeground))
                }
                .buttonStyle(.plain)
                .accessibilityHint(NSLocalizedString("두 번 누르면 다음 칸으로 갑니다",
                                                     comment: "Coach bar accessibility hint"))
            }
        }
        .foregroundColor(Color.accentForeground)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.accentColor)
        // 단추 말고 **띠 아무 데나** 눌러도 넘어간다. 넓은 자리를 두고 좁은 곳을
        // 겨냥하게 할 이유가 없다. 눈에 보이는 길은 위의 단추이고, 이건 덤이다.
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.light()
            onNext()
        }
        // 안에 단추가 둘이라 띠 전체를 하나로 묶지 않는다 - 묶으면 "안내 끄기"에
        // 닿을 길이 사라진다.
        .accessibilityElement(children: .contain)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}

// MARK: - 짚어 주는 표시

extension View {
    /// 이 칸을 지금 짚고 있으면 물결을 두른다.
    ///
    /// ⚠️ 물결은 **칸 밖으로** 번진다(`KeyRipple`). 자르는 것이 위에 있으면 잘리므로,
    ///    번질 자리가 있는 곳에 건다. 새 단축어 화면은 좌우 20pt·칸 사이 22pt 라
    ///    기본값(14)이 그대로 들어간다.
    @ViewBuilder
    func memoAddCoachRipple(_ isOn: Bool, radius: CGFloat, reach: CGFloat = 14) -> some View {
        overlay {
            if isOn {
                KeyRipple(shape: RoundedRectangle(cornerRadius: radius, style: .continuous),
                          color: .accentColor, reach: reach)
            }
        }
    }
}
