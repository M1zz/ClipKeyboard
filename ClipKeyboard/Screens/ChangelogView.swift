//
//  ChangelogView.swift
//  ClipKeyboard
//
//  변경사항(업데이트 기록) - 설정 > 도움말에서 언제든 다시 볼 수 있는 화면.
//
//  `WhatsNewView` 와의 역할 구분:
//   · WhatsNewView  = 업데이트 직후 **1회만** 뜨는 새 기능 소개(놓치면 다시 못 봄)
//   · ChangelogView = **상시 조회**용 버전별 기록. "그 기능이 언제 들어왔더라"에 답한다
//
//  ⚠️ 내용은 `docs/RELEASE_NOTES_*.md` 의 App Store 요약과 **같은 문장**을 쓴다.
//     새 버전을 낼 때 이 파일 맨 위에 항목을 추가하고, 문자열을 ko/en/id 에 넣을 것.
//     (릴리즈 노트를 런타임에 읽지 않는 이유: docs/ 는 앱 번들에 포함되지 않는다)
//

import SwiftUI

/// 한 버전의 변경 기록.
struct ChangelogEntry: Identifiable {
    let version: String
    /// 출시일 (yyyy-MM-dd). 아직 안 나온 버전은 nil.
    let released: String?
    let highlights: [String]

    var id: String { version }
}

enum ChangelogData {

    /// 최신 버전이 위로 온다.
    /// ⚠️ 사용자에게 보이는 문장이므로 전부 NSLocalizedString 을 거친다.
    static let entries: [ChangelogEntry] = [
        ChangelogEntry(
            version: "5.0.1",
            released: nil,
            highlights: [
                NSLocalizedString("한 번 꺼내 쓸 때마다 적어도 2분은 아낀 것으로 세요. 깃 토큰처럼 갈래를 못 알아보는 값이 10초로 적히던 걸 고쳤어요", comment: "Changelog 5.0.1 baseline"),
                NSLocalizedString("손으로 쳐 넣은 계좌번호도 이제 계좌번호로 알아봐요. 클립보드에서 온 것만 갈래가 붙던 걸 고쳤어요", comment: "Changelog 5.0.1 resolve type"),
                NSLocalizedString("다른 앱에서 찾아오던 시간을 실제로 재 본 크기로 올렸어요. 은행 앱을 여는 건 28초에 끝나는 일이 아니었어요", comment: "Changelog 5.0.1 retrieval"),
                NSLocalizedString("같은 문구를 잇달아 쓰면 찾아오는 시간을 한 번만 세요. 한 번 꺼내 온 값은 이미 손에 있으니까요", comment: "Changelog 5.0.1 repeat"),
                NSLocalizedString("아주 긴 글은 손으로 옮겨 적었을 만큼까지만 세요. 탭 한 번에 20분을 아꼈다고 적지 않아요", comment: "Changelog 5.0.1 ceiling"),
                NSLocalizedString("사용 기록의 내역에 뺀 시간도 함께 적어서, 줄을 더해 보면 위의 숫자가 나와요", comment: "Changelog 5.0.1 reconcile"),
                NSLocalizedString("셈을 고치기 전에 쓴 기록도 새 셈으로 보여요. 기간마다 같은 한 번이 다른 금액으로 찍히던 걸 고쳤어요", comment: "Changelog 5.0.1 reprice"),

                // 자랑하기
                NSLocalizedString("영수증을 뽑으면 지금 보고 있던 기간이 그대로 찍혀요. 종이 한 장만 뜹니다", comment: "Changelog 5.0.1 receipt period"),
                NSLocalizedString("영수증과 영상을 인스타 스토리에 버튼 하나로 바로 올릴 수 있어요", comment: "Changelog 5.0.1 instagram"),
                NSLocalizedString("친구들에게 알리기를 누르면 영상을 먼저 보고 나서 보낼 수 있어요", comment: "Changelog 5.0.1 video preview"),
            ]
        ),
        ChangelogEntry(
            version: "5.0.0",
            released: nil,
            highlights: [
                // 처음 오는 길
                NSLocalizedString("처음 쓰는 분께는 만들라고 하지 않고, 준비된 단축어를 하나씩 눌러보게 안내해요", comment: "Changelog 5.0.0 item 10"),
                NSLocalizedString("누를 곳마다 물결이 번져서 다음에 무엇을 할지 알 수 있어요", comment: "Changelog 5.0.0 ripple"),
                NSLocalizedString("셋을 눌러 본 뒤에는 직접 하나 만들어 보는 걸음으로 이어져요", comment: "Changelog 5.0.0 make own"),
                NSLocalizedString("연습용 단축어는 다 끝나면 치울지 한 번 물어봐요", comment: "Changelog 5.0.0 cleanup"),
                NSLocalizedString("키보드를 켠 것이 확인될 때까지 안내가 다시 떠요. 닫기만 해서는 끝나지 않아요", comment: "Changelog 5.0.0 keyboard nag"),
                NSLocalizedString("앱 안 키보드 미리보기에서 글이 한 글자씩 흘러 들어가요", comment: "Changelog 5.0.0 typing"),

                // 템플릿
                NSLocalizedString("빈칸마다 무슨 값인지 이름이 보이고, 칸이 따로 구분돼요", comment: "Changelog 5.0.0 blank names"),
                NSLocalizedString("값을 고르면 미리보기가 먼저 바뀌고, 입력하기를 눌러야 들어가요", comment: "Changelog 5.0.0 insert"),
                NSLocalizedString("오늘 날짜처럼 자동으로 채워지는 자리는 구멍이 아니라 값으로 보여요", comment: "Changelog 5.0.0 preview"),
                NSLocalizedString("저장된 값이 없으면 그 자리에서 바로 만들 수 있어요", comment: "Changelog 5.0.0 inline add"),
                NSLocalizedString("플레이스홀더 값 관리를 단축어 목록과 편집 화면에서 바로 열 수 있어요", comment: "Changelog 5.0.0 placeholder reach"),

                // 아낀 시간
                NSLocalizedString("아낀 시간을 다시 셌어요. 치는 시간만 세던 걸 고쳐서, 다른 앱에서 찾아와야 했던 값은 찾는 시간까지 셉니다", comment: "Changelog 5.0.0 item 3"),
                NSLocalizedString("찾은 뒤 선택하고 복사해서 돌아오는 손놀림도 이제 함께 세요", comment: "Changelog 5.0.0 handling"),
                NSLocalizedString("아낀 시간이 어떻게 계산됐는지 사용 기록에서 펼쳐 볼 수 있어요", comment: "Changelog 5.0.0 item 4"),
                NSLocalizedString("1분·5분·한 시간처럼 눈에 잡히는 만큼 아끼면 알려드려요", comment: "Changelog 5.0.0 item 5"),
                NSLocalizedString("아낀 시간을 3초짜리 세로 영상으로 뽑아 스토리에 올릴 수 있어요", comment: "Changelog 5.0.0 item 6"),
                NSLocalizedString("환급 영수증에서 픽셀 그림을 빼고 진짜 영수증처럼 바꿨어요", comment: "Changelog 5.0.0 item 7"),

                // 알려 주는 것들
                NSLocalizedString("며칠에 한 번, 아직 모르실 만한 기능을 하나씩 알려드려요", comment: "Changelog 5.0.0 dyk"),
                NSLocalizedString("고르신 쓰임새에 맞는 갈래와 문구를 골라 알려드려요", comment: "Changelog 5.0.0 persona"),
                NSLocalizedString("잠긴 단축어가 있는데 잠금 번호가 없으면 누르기 전에 알려드려요", comment: "Changelog 5.0.0 pin"),

                // 화면
                NSLocalizedString("목록 배경으로 내 사진을 쓸 수 있어요", comment: "Changelog 5.0.0 background"),
                NSLocalizedString("이렇게들 써요에서 사람을 고르면 그 사람 이야기만 따로 볼 수 있어요", comment: "Changelog 5.0.0 persona detail"),
                NSLocalizedString("키컬러를 주황으로 바꿔 눌러야 할 곳이 분명해졌어요", comment: "Changelog 5.0.0 accent"),
                NSLocalizedString("대비 증가를 켜면 흐린 글자와 선이 또렷해져요", comment: "Changelog 5.0.0 contrast"),
                NSLocalizedString("이름만 없던 버튼들에 이름을 붙여 보이스오버와 음성 제어로 부를 수 있어요", comment: "Changelog 5.0.0 a11y labels"),

                // 고친 것
                NSLocalizedString("앱을 다시 깔거나 새 폰을 켜도, 켜기 전에는 iCloud 데이터를 당겨오지 않아요", comment: "Changelog 5.0.0 sync consent"),
                NSLocalizedString("홈 화면 앱 이름과 아이콘을 바로잡았어요", comment: "Changelog 5.0.0 name icon"),
                NSLocalizedString("목록 탭에 들어갈 때 화면이 한 번 까매지던 것을 고쳤어요", comment: "Changelog 5.0.0 black flash"),
                NSLocalizedString("튜토리얼이 가리키는 단축어가 다른 페이지에 있어 안 보이던 것을 고쳤어요", comment: "Changelog 5.0.0 tutorial page"),
            ]
        ),
        ChangelogEntry(
            version: "4.4.8",
            released: nil,
            highlights: [
                NSLocalizedString("앱을 열다가 멈추던 문제를 고쳤어요. iCloud 준비를 첫 화면 그리는 일에서 떼어 놓았어요", comment: "Changelog 4.4.8 item 1"),
                NSLocalizedString("시작하다 문제가 생겨도 다음 실행은 열려요. 걸린 부분만 쉬고 화면부터 띄워요", comment: "Changelog 4.4.8 item 2"),
                NSLocalizedString("기기 간 동기화에서 처음 올린 뒤의 수정과 삭제가 반영되지 않던 문제를 고쳤어요", comment: "Changelog 4.4.8 item 3"),
                NSLocalizedString("이미지 단축어를 누르면 미리보기 입력창에 바로 붙고, 보내면 그대로 올라가요", comment: "Changelog 4.4.7 item 1"),
                NSLocalizedString("카테고리에 단축어가 들어 있으면 탭을 숨기기 전에 알려드리고, 다른 카테고리로 한 번에 옮길 수 있어요", comment: "Changelog 4.4.7 item 2"),
                NSLocalizedString("탭을 숨긴 카테고리의 단축어가 어디에도 보이지 않던 문제를 고쳤어요. 갈 수 있는 탭이 없으면 기본 탭에 모여요", comment: "Changelog 4.4.7 item 3"),
                NSLocalizedString("키를 길게 누르면 값이 키보드를 꽉 채워 보여요. 잠긴 단축어는 값을 보여주지 않아요", comment: "Changelog 4.4.7 item 4"),
                NSLocalizedString("설정을 열면 단축어를 몇 칸 더 만들 수 있는지 맨 위에 보여요", comment: "Changelog 4.4.7 item 5"),
                NSLocalizedString("탭을 한 번 더 누르면 단축어 목록과 키보드 화면이 오가요", comment: "Changelog 4.4.7 item 6"),
                NSLocalizedString("클립보드는 설정 > 내 데이터로, 사용 기록은 탭으로 자리를 바꿨어요", comment: "Changelog 4.4.7 item 7"),
                NSLocalizedString("설정을 하려는 일로 묶어 16개에서 8개로 정리했어요. 첫 화면은 한 줄로 접히고 현재 값이 보여요", comment: "Changelog 4.4.6 item 1"),
                NSLocalizedString("카테고리 아이콘은 카테고리 관리 안에서 바로 고를 수 있어요", comment: "Changelog 4.4.6 item 2"),
                NSLocalizedString("안정성 화면에 영문 오류 대신 지금 무엇을 기다리는 상태인지 알려드려요", comment: "Changelog 4.4.6 item 3"),
                NSLocalizedString("한꺼번에 가져올 때 저장하기 전에 키보드 모습으로 보여줘요. 키를 눌러 뺄 것만 빼면 돼요", comment: "Changelog 4.4.5 item 1"),
                NSLocalizedString("사진 속 글자를 값으로 바로 넣을 수 있어요. 읽은 줄에서 필요한 것만 고르면 돼요", comment: "Changelog 4.4.5 item 2"),
                NSLocalizedString("단축어 마트가 생겼어요. 상황을 고르고 빈칸만 내 것으로 채우면 바로 키보드에 들어가요", comment: "Changelog 4.4.5 item 4"),
                NSLocalizedString("제어센터와 위젯에서 앱을 열지 않고 바로 복사돼요. 제어센터에 '값 복사' 버튼을 추가해 보세요", comment: "Changelog 4.4.5 item 5"),
                NSLocalizedString("사파리 등에서 공유하면 바로 단축어로 담겨요. 앱에 들어가 한 번 더 누르지 않아도 돼요", comment: "Changelog 4.4.5 item 6"),
                NSLocalizedString("공유 시트 아래 목록의 '단축어로 저장'을 누르면 화면 없이 한 번에 담겨요", comment: "Changelog 4.4.5 item 7"),
                NSLocalizedString("체크해서 함께 쓰는 값들을 콤보 한 키로 묶을 수 있어요. 떨어져 있어도 묶여요", comment: "Changelog 4.4.5 item 3"),
                NSLocalizedString("앱을 열면 키보드가 올라온 모습 그대로, 눌러서 바로 써 볼 수 있어요", comment: "Changelog 4.4.4 item 1"),
                NSLocalizedString("설정 > 첫 화면에서 단축어 목록과 키보드 화면 중 고를 수 있어요(툴바 버튼으로 바로 전환)", comment: "Changelog 4.4.4 item 2"),
                NSLocalizedString("짧게 누르면 입력창에, 길게 누르면 클립보드로: 앱 안에서요", comment: "Changelog 4.4.4 item 4"),
                NSLocalizedString("처음 쓰신다면 단축어를 직접 하나 만들고, 눌러 써 봐야 다음으로 넘어가요", comment: "Changelog 4.4.4 item 3"),
                NSLocalizedString("템플릿 → 있는 걸 템플릿으로 바꾸기 → 콤보까지 차례로 익혀요(\"나중에\"를 고르면 다시 묻지 않아요)", comment: "Changelog 4.4.4 item 8"),
                NSLocalizedString("채우는 칸이 뭔지 같은 문장을 값만 바꿔 두 줄로 보여줘요. { } 기호는 어디서도 안 보여요", comment: "Changelog 4.4.4 item 9"),
                NSLocalizedString("연습으로 만든 단축어는 끝나고 지울지 한 번만 물어봐요(설정에서 다시 볼 수도 있어요)", comment: "Changelog 4.4.4 item 10"),
                NSLocalizedString("카테고리 탭과 좌우 넘기기가 처음부터 보여요", comment: "Changelog 4.4.4 item 5"),
                NSLocalizedString("붙여넣기 허용 팝업을 며칠 써 보신 뒤로 미뤘어요. 설치하자마자 묻지 않아요", comment: "Changelog 4.4.4 item 6"),
                NSLocalizedString("눌러 넣은 글이 사라지던 문제, 안내가 중간에 끊기던 문제, 카테고리 배경색이 없어진 문제를 고쳤어요", comment: "Changelog 4.4.4 item 7")
            ]
        ),
        ChangelogEntry(
            version: "4.4.3",
            released: "2026-07-30",
            highlights: [
                NSLocalizedString("한 단축어에 여러 값: \"내용 더 넣기\"로 담고, 기존 단축어에서 값 가져오기도 가능", comment: "Changelog 4.4.3 item 1"),
                NSLocalizedString("앱에서 탭하면 값 목록에서 골라 복사, 키보드에선 2/3 분할로 값을 하나씩 입력", comment: "Changelog 4.4.3 item 2"),
                NSLocalizedString("이미지와 여러 값을 한 단축어에 함께 담을 수 있어요", comment: "Changelog 4.4.3 item 3"),
                NSLocalizedString("새 단축어 화면 정리, 채우기 버튼과 변수 설명이 또렷해졌어요", comment: "Changelog 4.4.3 item 4"),
                NSLocalizedString("기기 간 동기화(베타) 수정, 전송이 확정된 뒤에만 완료 처리해 누락을 막아요", comment: "Changelog 4.4.3 item 5")
            ]
        ),
        ChangelogEntry(
            version: "4.4.0",
            released: "2026-07-23",
            highlights: [
                NSLocalizedString("맥에서 단축어 순서를 끌어다 바꾸고, 그 순서를 아이폰·키보드까지 동기화", comment: "Changelog 4.4.0 item 1"),
                NSLocalizedString("아이폰에서 바꾼 순서도 맥의 모든 화면에 그대로 반영", comment: "Changelog 4.4.0 item 2"),
                NSLocalizedString("키보드 검색에서 한글이 흩어지던 문제 수정, 이제 정확히 조합돼 찾아져요", comment: "Changelog 4.4.0 item 3"),
                NSLocalizedString("켜 둔 빈 카테고리도 탭으로 남아 스와이프로 바로 이동", comment: "Changelog 4.4.0 item 4")
            ]
        ),
        ChangelogEntry(
            version: "4.3.9",
            released: "2026-07-18",
            highlights: [
                NSLocalizedString("맑은 유리 카드와 배경 사진, 8가지 풍경이 탭마다 다르게 비쳐요", comment: "Changelog 4.3.9 item 1"),
                NSLocalizedString("한번에 가져오기 개편, 붙여넣으면 서비스명·아이디·비밀번호를 알아서 분리", comment: "Changelog 4.3.9 item 2"),
                NSLocalizedString("비밀번호·PIN·인증서는 가져올 때부터 자동으로 암호화되는 보안 단축어로", comment: "Changelog 4.3.9 item 3"),
                NSLocalizedString("사진·카메라에서 텍스트를 인식해 가져오기, 카드 사진은 번호와 유효기간만", comment: "Changelog 4.3.9 item 4"),
                NSLocalizedString("콤보가 쉬워졌어요. 값을 이어 붙이고 보안 콤보로 암호화 저장까지", comment: "Changelog 4.3.9 item 5")
            ]
        ),
        ChangelogEntry(
            version: "4.3.8",
            released: "2026-07-17",
            highlights: [
                NSLocalizedString("iOS 26 순정 디자인 전면 적용, 유리 탭바와 투명한 상단", comment: "Changelog 4.3.8 item 1"),
                NSLocalizedString("큰 제목이 스크롤에 따라 작아졌다 커지는 순정 타이틀 동작", comment: "Changelog 4.3.8 item 2"),
                NSLocalizedString("만들다 만 단축어만 임시저장, 열어만 봐도 쌓이던 문제 정리", comment: "Changelog 4.3.8 item 3"),
                NSLocalizedString("이미지와 이름만 넣은 단축어가 저장되지 않던 문제 해결", comment: "Changelog 4.3.8 item 4")
            ]
        ),
        ChangelogEntry(
            version: "4.3.7",
            released: "2026-07-14",
            highlights: [
                NSLocalizedString("메모 구분 표시를 꺼도 남아있던 카드 테두리까지 완전히 숨김", comment: "Changelog 4.3.7 item 1"),
                NSLocalizedString("홈 화면 작성 가이드 카드를 닫으면 조용히 사라져요", comment: "Changelog 4.3.7 item 2"),
                NSLocalizedString("붙여넣기 허용을 한 번에, 클립보드 화면에서 iOS 설정으로 바로 이동", comment: "Changelog 4.3.7 item 3"),
                NSLocalizedString("여러분이 남겨주신 피드백을 반영한 다듬기 업데이트", comment: "Changelog 4.3.7 item 4")
            ]
        )
    ]

    /// 현재 실행 중인 앱 버전 - 목록에서 강조하는 데 쓴다.
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }
}

struct ChangelogView: View {

    @Environment(\.appTheme) private var theme

    var body: some View {
        List {
            ForEach(ChangelogData.entries) { entry in
                Section {
                    ForEach(Array(entry.highlights.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(theme.textFaint)
                                .frame(width: 5, height: 5)
                                .padding(.top, 7)
                            Text(item)
                                .font(.body)
                                .foregroundColor(theme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 1)
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text(entry.version)
                            .font(.headline)
                            .foregroundColor(theme.text)
                        // 지금 쓰고 있는 버전을 표시해 "내 앱이 어디까지 왔는지" 알 수 있게.
                        if entry.version == ChangelogData.currentVersion {
                            Text(NSLocalizedString("사용 중", comment: "Changelog: currently installed version badge"))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .clipShape(Capsule())
                        }
                        Spacer()
                        if let released = entry.released {
                            Text(released)
                                .font(.caption)
                                .foregroundColor(theme.textMuted)
                        }
                    }
                    .textCase(nil)   // 버전 번호가 대문자 변환되지 않도록
                    .accessibilityElement(children: .combine)
                }
            }

            Section {
                Text(NSLocalizedString("더 자세한 내용은 App Store의 '새로운 기능'에서 볼 수 있어요.", comment: "Changelog footer note"))
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
            }
        }
        .navigationTitle(NSLocalizedString("변경사항", comment: "Changelog screen title"))
    }
}

#Preview {
    NavigationStack { ChangelogView() }
}
