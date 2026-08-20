//
//  WhatsNewView.swift
//  ClipKeyboard
//
//  업데이트 후 1회 노출되는 "새로운 기능" 시트. 새 기능을 자연스럽게 알리는 announce 층.
//  (지속 리마인드는 TipKit, 상시 노출은 Inbox 배너가 담당.)
//
//  ⚠️ **처음 받은 사람에게는 뜨지 않는다.** 첫 실행이면 본 것으로 표시만 하고 넘어가고
//     (`ClipKeyboardApp.presentWhatsNewIfNeeded`), 그 사람은 온보딩이 맞이한다.
//     새로 온 사람에게 "새로워졌어요"는 무슨 말인지 알 수 없는 말이다.
//
//  ⚠️ 5.0 은 기능 소개가 아니라 **이름이 바뀐 것을 알리는 자리**다. 이름과 아이콘이
//     하룻밤 새 바뀌면 사람들은 새 기능이 궁금한 게 아니라 **"내가 뭘 지웠나"**를 먼저
//     의심한다. 그래서 첫 줄이 기능이 아니라 "같은 앱이에요"다.
//

import SwiftUI

/// What's-New 콘텐츠 + 버전. 새 안내가 필요할 때 `version`을 올리면 그 버전 사용자에게 1회 노출된다.
enum WhatsNewContent {
    /// 이 안내가 소개하는 기능 버전. 무관한 버전 범프에서는 다시 뜨지 않도록 콘텐츠 기준 버전으로 고정.
    ///
    /// ⚠️ **내용을 바꿀 때 이 값도 같이 올릴 것.** 안 올리면 업데이트한 사람은 이미 본 것으로
    ///    기록돼 있어 새 안내를 **한 번도 못 본다** - 새 기능이 있어도 있는 줄 모른다.
    static let version = "5.0.0"
}

struct WhatsNewView: View {
    let onClose: () -> Void
    /// 큰 버튼을 누르면 닫은 뒤 그 기능으로 데려간다(이번 버전은 키보드 화면).
    /// ⚠️ 안내는 **보여주는 데서 끝나면 안 된다** - 읽고 닫으면 아무것도 안 달라진다.
    let onPrimaryAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        // 새 얼굴을 **직접 보여 준다.** 홈 화면에서 바뀐 그 그림이 여기 있어야
                        // "그 앱이 이 앱"이 한눈에 이어진다.
                        MascotView(pose: .greeting, size: 96, framing: .figure)
                            .padding(.top, 24)

                        Text(NSLocalizedString("이름이 크로커클립으로 바뀌었어요", comment: "What's new title 5.0"))
                            .font(.title.bold())
                            .multilineTextAlignment(.center)

                        Text(NSLocalizedString("쓰던 그 앱이 맞아요. 단축어도, 설정도 그대로 있어요. 이름과 얼굴만 새로 입었어요.",
                                               comment: "What's new subtitle 5.0"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    VStack(spacing: 18) {
                        featureRow(
                            symbol: "app.badge.checkmark",
                            title: NSLocalizedString("홈 화면 아이콘이 달라졌어요", comment: "What's new 5.0 feature 1 title"),
                            detail: NSLocalizedString("키캡을 문 악어를 찾으세요. 지우고 다시 깔 필요 없어요.", comment: "What's new 5.0 feature 1 detail")
                        )
                        featureRow(
                            symbol: AppSymbol.checkmarkSealFill,
                            title: NSLocalizedString("아낀 시간을 제대로 세기 시작했어요", comment: "What's new 5.0 feature 2 title"),
                            detail: NSLocalizedString("치는 시간만 세던 걸 고쳤어요. 계좌번호처럼 다른 앱에서 찾아와야 했던 값은 찾는 시간까지 셉니다. 어떻게 셌는지도 적어 뒀어요.", comment: "What's new 5.0 feature 2 detail")
                        )
                        featureRow(
                            symbol: "square.and.arrow.up",
                            title: NSLocalizedString("자랑할 영상을 만들 수 있어요", comment: "What's new 5.0 feature 3 title"),
                            detail: NSLocalizedString("아낀 시간을 3초짜리 세로 영상으로 뽑아요. 스토리에 그대로 올릴 수 있어요.", comment: "What's new 5.0 feature 3 detail")
                        )
                        featureRow(
                            symbol: "bubble.left.and.bubble.right.fill",
                            title: NSLocalizedString("막히면 악어를 누르세요", comment: "What's new 5.0 feature 4 title"),
                            detail: NSLocalizedString("키보드 미리보기의 악어 얼굴을 누르면, 단축어·템플릿·콤보가 뭐가 다른지 그 자리에서 알려드려요.", comment: "What's new 5.0 feature 4 detail")
                        )
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
            }

            VStack(spacing: 10) {
                Button {
                    onPrimaryAction()
                } label: {
                    Text(NSLocalizedString("내가 아낀 시간 보기", comment: "What's new 5.0 primary button"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    onClose()
                } label: {
                    Text(NSLocalizedString("Not now", comment: "Dismiss what's new"))
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    private func featureRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 처음 온 사람 · 쓰던 사람

/// 앱을 연 사람이 **어느 쪽인지** 가르는 한 곳.
///
/// ⚠️ 예전에는 이 판단이 두 군데에 흩어져 있었다. 새 단장 안내는 `appLaunchCount` 를 보고,
///    온보딩은 `startedFreshV444` 를 봤다. 둘이 각자 판단하면 **양쪽 다 받는 사람**이나
///    **양쪽 다 못 받는 사람**이 생긴다. 처음 온 사람이 "새로워졌어요"를 보는 것만큼
///    이상한 일도 없다.
///
/// ⚠️ 순수 함수다. 화면이 값을 넣어 주고, 테스트는 같은 입력을 직접 만들어 검증한다.
enum LaunchAudience: Equatable {

    /// 오늘 처음 받은 사람. 온보딩이 맞이한다.
    case newcomer
    /// 쓰던 사람인데 이번에 새 단장을 아직 못 봤다. 안내를 한 번 띄운다.
    case returningNeedsWhatsNew
    /// 쓰던 사람이고 안내도 이미 봤다. 아무것도 하지 않는다.
    case returning

    /// - Parameters:
    ///   - launchCount: 이번 실행을 **세기 전**의 누적 실행 횟수. 0이면 첫 실행.
    ///   - startedFresh: 이 기기가 이 앱을 처음부터 시작했는가(온보딩 대상 표식).
    ///   - lastSeenWhatsNewVersion: 마지막으로 본 안내의 버전. 없으면 nil.
    ///   - currentWhatsNewVersion: 지금 안내의 버전.
    static func resolve(launchCount: Int,
                        startedFresh: Bool,
                        lastSeenWhatsNewVersion: String?,
                        currentWhatsNewVersion: String = WhatsNewContent.version) -> LaunchAudience {
        // ⚠️ 첫 실행 판단은 **실행 횟수**로 한다. `startedFresh` 는 온보딩을 아직 안 끝낸
        //    사람에게도 계속 켜져 있어서, 그것만 보면 두 번째 실행에도 처음 온 사람이 된다.
        if launchCount <= 1 || startedFresh && launchCount <= 1 {
            return .newcomer
        }
        return lastSeenWhatsNewVersion == currentWhatsNewVersion ? .returning : .returningNeedsWhatsNew
    }

    /// 새 단장 안내를 띄워야 하는가.
    var showsWhatsNew: Bool { self == .returningNeedsWhatsNew }

    /// 처음 온 사람에게는 안내 대신 **본 것으로 표시만** 한다.
    /// 안 그러면 온보딩을 끝내고 두 번째로 열 때 "새로워졌어요"가 뒤늦게 튀어나온다.
    var marksWhatsNewSeenSilently: Bool { self == .newcomer }
}
