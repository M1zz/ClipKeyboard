//
//  Mascot.swift
//  ClipKeyboard
//
//  악어 마스코트가 화면에 서는 자리.
//
//  이 파일은 **그림을 고르지 않는다.** 어떤 순간에 어떤 표정이 필요한지를 `MascotPose` 로
//  이름 붙여 두고, 실제 그림은 에셋 카탈로그의 같은 이름 칸에 나중에 채운다.
//  칸이 비어 있으면 조용히 기본 얼굴(`MascotAvatar`)로 대신 그린다 - 그림이 준비되는
//  속도와 화면이 나가는 속도를 떼어 놓으려는 배치다.
//
//  ⚠️ 에셋은 **original 렌더링**이어야 한다. 템플릿으로 렌더되면 실루엣만 남아 악어가
//     사라진다(`MascotAvatar` 의 Contents.json 에 이미 박혀 있다. 새 칸도 같다).
//
//  ⚠️ 배경이 비어 있는(알파) PNG 를 넣는다. 흰 판이 깔린 그림을 넣으면 다크 모드에서
//     캐릭터를 둘러싼 밝은 사각형이 보인다(온보딩 영상에서 한 번 겪은 일이다).
//

import SwiftUI
import TipKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 포즈 (그림이 들어갈 자리)

/// 마스코트가 지을 표정·자세의 목록. rawValue 가 곧 **에셋 이름**이다.
///
/// 그림을 넣는 법: `ClipKeyboard/Assets.xcassets/<rawValue>.imageset` 에 1x·2x·3x PNG 를
/// 넣으면 끝이다. 코드는 고치지 않는다. 자세한 규격은 `docs/MASCOT.md`.
///
/// 새 포즈가 필요하면 여기에 case 를 추가하고 같은 이름의 imageset 을 만든다.
enum MascotPose: String, CaseIterable, Sendable {

    /// 기본 얼굴. **폴백이자 프로필 사진**이라 항상 채워져 있어야 한다.
    case avatar = "MascotAvatar"

    /// 손 흔들며 인사. 처음 만나는 자리(환영 팁, 온보딩).
    case greeting = "MascotGreeting"

    /// 손가락으로 가리킨다. "여기를 눌러보세요" 류.
    case pointing = "MascotPointing"

    /// 무언가를 펼쳐 보이며 설명한다. 템플릿·콤보 동작 설명.
    case explaining = "MascotExplaining"

    /// 키보드를 두드린다. 키보드 설정·연습 안내.
    case typing = "MascotTyping"

    /// 짐을 안고 옮긴다. 보관함에 담기, 백업·복원·이사.
    case carrying = "MascotCarrying"

    /// 갸웃하며 생각한다. 제안하는 팁("이런 카테고리는 어때요?").
    case thinking = "MascotThinking"

    /// 두 팔 들고 축하한다. 첫 저장, 목표 달성, 구매 완료.
    case celebrating = "MascotCelebrating"

    /// 지키고 서 있다. 보안 단축어, 잠금, 개인정보 안내.
    case guarding = "MascotGuarding"

    /// 껍데기를 깨문다. 미리보기에서 값을 꺼내는 장면(`ShellCrack`).
    ///
    /// ⚠️ `ShellCrack` 은 이 타입을 쓰지 않고 이름만 같이 쓴다 - 그 파일은 익스텐션에도
    ///    컴파일되는데 이 타입은 앱 타겟에만 있다. 이름을 바꾸면 양쪽을 같이 고친다.
    case biting = "MascotBiting"

    /// 잠들어 있다. 아무것도 없는 빈 화면.
    case sleeping = "MascotSleeping"

    /// 머쓱해한다. 오류·실패·복구 안내.
    case apologizing = "MascotApologizing"

    /// 실제로 그릴 에셋 이름. 칸이 비어 있으면 기본 얼굴로 물러선다.
    ///
    /// ⚠️ 결과를 캐시하지 않는다. `UIImage(named:)` 가 이미 내부 캐시를 갖고 있고,
    ///    여기서 따로 들고 있으면 그저 동시성 사고 거리만 하나 늘어난다.
    var resolvedAssetName: String {
        #if canImport(UIKit)
        if UIImage(named: rawValue) != nil { return rawValue }
        return Self.avatar.rawValue
        #else
        return rawValue
        #endif
    }

    /// 준비된 그림이 있는지. 미리보기·진단용.
    var isPrepared: Bool {
        #if canImport(UIKit)
        return UIImage(named: rawValue) != nil
        #else
        return true
        #endif
    }

    var image: Image { Image(resolvedAssetName) }
}

// MARK: - 마스코트 뷰

/// 마스코트를 어떻게 잘라 놓을지.
enum MascotFraming {
    /// 그림 전체를 보여 준다. 몸까지 그려진 포즈용.
    case figure
    /// 동그랗게 잘라 프로필 사진처럼. 얼굴 그림용.
    case badge
}

/// 화면 어디에나 놓을 수 있는 마스코트 한 마리.
///
/// ⚠️ 뒤에 브랜드색 옅은 원을 깐다. 캐릭터 그림은 배경이 비어 있어서 그냥 두면 허공에
///    뜬 것처럼 보이는데, 이 원이 바닥 노릇을 한다(온보딩·말풍선이 쓰던 방식과 같다).
struct MascotView: View {
    var pose: MascotPose = .avatar
    var size: CGFloat = 56
    var framing: MascotFraming = .figure
    /// 뒤에 까는 옅은 원. 이미 색이 있는 바탕 위라면 끄는 편이 낫다.
    var showsHalo: Bool = true

    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            if showsHalo {
                Circle()
                    .fill(theme.accentSoft)
                    .frame(width: haloSize, height: haloSize)
            }

            switch framing {
            case .figure:
                pose.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            case .badge:
                pose.image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(theme.divider, lineWidth: 0.5))
            }
        }
        // 그림은 장식이다. 뜻은 옆의 글이 전부 지고 있다.
        .accessibilityHidden(true)
    }

    /// 몸이 그려진 포즈는 원보다 살짝 커야 원 밖으로 걸쳐서 살아 있어 보인다.
    private var haloSize: CGFloat {
        framing == .badge ? size : size * 0.82
    }
}

// MARK: - 마스코트가 말하는 팁

/// 마스코트가 건네는 팁. `Tip` 대신 이것을 채택하면 **포즈만 고르면 된다.**
///
/// ⚠️ `Tip` 의 확장이 아니라 별도 프로토콜인 이유: 프로토콜 확장에만 있는 프로퍼티는
///    정적으로 묶여서, 각 팁이 덮어써도 무시된다. 요구사항으로 선언해야 팁마다 고른
///    포즈가 실제로 불린다.
protocol MascotTip: Tip {
    var mascotPose: MascotPose { get }
}

extension MascotTip {
    /// 포즈를 안 고르면 기본 얼굴.
    var mascotPose: MascotPose { .avatar }

    /// 팁 그림은 **전부 마스코트다.**
    ///
    /// ⚠️ 예전에는 팁마다 다른 SF 기호였다(클립보드·플러스·키보드·중괄호…). 기호는 그
    ///    팁의 내용을 설명하지만, 정작 **누가 말하고 있는지**는 매번 달라졌다. 앱 안에서
    ///    말을 거는 얼굴이 하나면 팁이 잔소리가 아니라 안내가 된다.
    var image: Image? { mascotPose.image }
}

/// 팁을 마스코트의 말풍선으로 그린다.
///
/// 기본 TipKit 카드는 그림을 작은 아이콘 자리에 밀어 넣어서, 캐릭터를 넣어도
/// **등장했다는 느낌이 안 난다.** 여기서는 왼쪽에 마스코트를 세우고 오른쪽 말풍선이
/// 그 입에서 나오게 붙인다.
///
/// ⚠️ 액션은 `action.handler` 를 그대로 부른다. `TipView(tip) { action in … }` 로 넘긴
///    콜백도 이 핸들러를 타고 들어온다(TipKit 기본 스타일이 쓰는 경로와 같다).
struct MascotTipViewStyle: TipViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        MascotTipCard(configuration: configuration)
    }
}

/// 스타일이 실제로 그리는 카드. 테마 토큰을 읽어야 해서 별도 `View` 로 뺐다
/// (`TipViewStyle` 자체는 뷰가 아니라 `@Environment` 를 읽지 못한다).
private struct MascotTipCard: View {
    let configuration: TipViewStyleConfiguration

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    /// 팁이 고른 포즈. 마스코트 팁이 아니면 기본 얼굴로 말한다.
    private var pose: MascotPose {
        (configuration.tip as? any MascotTip)?.mascotPose ?? .avatar
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            MascotView(pose: pose, size: 60, framing: .figure)
                // 말풍선 꼭지와 눈높이를 맞춘다.
                .padding(.top, 2)

            bubble
        }
        .padding(.vertical, 2)
        // 살짝 걸어 들어온다. 움직임 줄이기를 켠 사람에게는 그냥 서 있는다.
        .opacity(hasAppeared || reduceMotion ? 1 : 0)
        .offset(x: hasAppeared || reduceMotion ? 0 : -12)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                hasAppeared = true
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    if let title = configuration.title {
                        title
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(theme.text)
                    }
                    if let message = configuration.message {
                        message
                            .font(.footnote)
                            .foregroundColor(theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                closeButton
            }

            if !configuration.actions.isEmpty {
                actionRow
            }
        }
        .padding(.leading, Self.tailWidth + 12)
        .padding(.trailing, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            MascotSpeechShape(cornerRadius: theme.radiusMd, tailWidth: Self.tailWidth)
                .fill(theme.surface)
        )
        .overlay(
            MascotSpeechShape(cornerRadius: theme.radiusMd, tailWidth: Self.tailWidth)
                .strokeBorder(theme.divider, lineWidth: 0.5)
        )
    }

    private var closeButton: some View {
        Button {
            configuration.tip.invalidate(reason: .tipClosed)
        } label: {
            Image(systemName: AppSymbol.xmark)
                .font(.caption2.weight(.bold))
                .foregroundColor(theme.textFaint)
                // 작은 기호에 손가락이 닿는 자리를 넉넉히 준다.
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("닫기", comment: "Close the tip"))
    }

    private var actionRow: some View {
        // 액션이 여럿인 팁(카테고리 이름 제안)은 줄을 넘겨 담는다.
        HStack(spacing: 8) {
            ForEach(configuration.actions) { action in
                Button {
                    action.handler()
                } label: {
                    action.label()
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(theme.accent)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    /// 꼬리가 차지하는 폭. 글이 꼬리에 물리지 않게 이만큼 왼쪽을 비운다.
    fileprivate static let tailWidth: CGFloat = 8
}

/// 왼쪽에 꼭지가 달린 말풍선.
private struct MascotSpeechShape: InsettableShape {
    var cornerRadius: CGFloat
    var tailWidth: CGFloat
    /// 꼭지가 시작되는 높이. 마스코트 얼굴 언저리에 맞춘 값이다.
    var tailTopInset: CGFloat = 16
    var tailHeight: CGFloat = 14
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let body = CGRect(x: r.minX + tailWidth, y: r.minY,
                          width: max(0, r.width - tailWidth), height: r.height)

        var path = Path()
        path.addRoundedRect(in: body,
                            cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
                            style: .continuous)

        // 풍선이 짧으면 꼭지가 모서리를 뚫는다. 들어갈 자리가 없으면 그리지 않는다.
        let top = r.minY + tailTopInset
        guard top + tailHeight <= r.maxY - cornerRadius else { return path }

        var tail = Path()
        tail.move(to: CGPoint(x: body.minX + 0.5, y: top))
        tail.addLine(to: CGPoint(x: r.minX, y: top + tailHeight * 0.45))
        tail.addLine(to: CGPoint(x: body.minX + 0.5, y: top + tailHeight))
        tail.closeSubpath()
        path.addPath(tail)
        return path
    }

    func inset(by amount: CGFloat) -> MascotSpeechShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}
