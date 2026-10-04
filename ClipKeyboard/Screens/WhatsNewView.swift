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
//  ⚠️ 5.1.8 은 키보드 맨 앞의 **'최근' 탭**을 알린다. 잠깐 쓸 글을 한 주·한 달 담아 두고
//     키보드에서 바로 꺼내 쓰고 싶다는 요청에서 나왔다(단축어 30, 잠깐 쓰는 글 70 으로 쓰는 사람).
//     탭이 저절로 생기므로 "이게 뭐지" 가 되지 않게 알리고, 필요 없는 사람이 끌 자리도 같이 말한다.
//     큰 버튼은 그 스위치가 있는 키보드 설정을 연다.
//  (5.1.3 은 위줄 키를 켜고 끄는 자리를 알렸다. 그 이야기는 git 기록에 있다.)
//
import SwiftUI

/// What's-New 콘텐츠 + 버전. 새 안내가 필요할 때 `version`을 올리면 그 버전 사용자에게 1회 노출된다.
enum WhatsNewContent {
    /// 이 안내가 소개하는 기능 버전. 무관한 버전 범프에서는 다시 뜨지 않도록 콘텐츠 기준 버전으로 고정.
    ///
    /// ⚠️ **내용을 바꿀 때 이 값도 같이 올릴 것.** 안 올리면 업데이트한 사람은 이미 본 것으로
    ///    기록돼 있어 새 안내를 **한 번도 못 본다** - 새 기능이 있어도 있는 줄 모른다.
    static let version = "5.1.8"
}

struct WhatsNewView: View {
    let onClose: () -> Void
    /// 큰 버튼을 누르면 닫은 뒤 그 기능으로 데려간다(키보드 레이아웃 설정, '최근' 탭 스위치가 있는 곳).
    /// ⚠️ 안내는 **보여주는 데서 끝나면 안 된다** - 읽고 닫으면 아무것도 안 달라진다.
    let onPrimaryAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Image(systemName: AppSymbol.docOnClipboard)
                            .font(.system(size: 64, weight: .light))
                            .foregroundColor(.accentColor)
                            .padding(.top, 24)
                            .accessibilityHidden(true)

                        Text(NSLocalizedString("복사한 글을 키보드에서 바로 꺼내 써요", comment: "What's new title 5.1.8"))
                            .font(.title.bold())
                            .multilineTextAlignment(.center)

                        Text(NSLocalizedString("잠깐 쓸 글은 키보드 맨 앞 '최근' 탭에 모아 두세요.",
                                               comment: "What's new subtitle 5.1.8. 'Recent' is the name of the keyboard tab"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    VStack(spacing: 18) {
                        featureRow(
                            symbol: AppSymbol.tray,
                            title: NSLocalizedString("키보드 맨 앞에 '최근' 탭이 생겼어요", comment: "What's new 5.1.8 recent tab title"),
                            detail: NSLocalizedString("앱이 모은 복사 기록과 키보드에서 저장한 글이 한곳에 모여요. 누르면 바로 입력되고, 길게 누르면 복사돼요.", comment: "What's new 5.1.8 recent tab detail")
                        )
                        featureRow(
                            symbol: AppSymbol.docOnClipboard,
                            title: NSLocalizedString("무엇이 저장될지 누르기 전에 보여요", comment: "What's new 5.1.8 save preview title"),
                            detail: NSLocalizedString("저장 버튼에 지금 복사해 둔 글이 미리 보여요. 카드번호는 끝 네 자리만 보여요.", comment: "What's new 5.1.8 save preview detail")
                        )
                        featureRow(
                            symbol: AppSymbol.clockArrowCirclepath,
                            title: String(format: NSLocalizedString("복사한 글이 %d일 동안 남아요", comment: "What's new 5.1.8 retention title. %d is the number of days"),
                                          SmartClipboardHistory.retentionDays),
                            detail: NSLocalizedString("예전에는 7일이 지나면 사라졌어요. 이제 한 달 가까이 두고 쓸 수 있어요.", comment: "What's new 5.1.8 retention detail")
                        )
                        featureRow(
                            symbol: AppSymbol.keyboard,
                            title: NSLocalizedString("필요 없으면 꺼 두세요", comment: "What's new 5.1.8 toggle title"),
                            detail: NSLocalizedString("설정 > 키보드 > 키보드 레이아웃에서 '최근' 탭을 끌 수 있어요.", comment: "What's new 5.1.8 toggle detail. 'Recent' is the name of the keyboard tab")
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
                    Text(NSLocalizedString("키보드 설정 보기", comment: "What's new 5.1.8 primary button: opens keyboard settings where the Recent tab can be turned off"))
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
