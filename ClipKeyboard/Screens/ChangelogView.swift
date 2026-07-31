//
//  ChangelogView.swift
//  ClipKeyboard
//
//  변경사항(업데이트 기록) — 설정 > 도움말에서 언제든 다시 볼 수 있는 화면.
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
            version: "4.4.3",
            released: "2026-07-30",
            highlights: [
                NSLocalizedString("한 단축어에 여러 값 — \"내용 더 넣기\"로 담고, 기존 단축어에서 값 가져오기도 가능", comment: "Changelog 4.4.3 item 1"),
                NSLocalizedString("앱에서 탭하면 값 목록에서 골라 복사, 키보드에선 2/3 분할로 값을 하나씩 입력", comment: "Changelog 4.4.3 item 2"),
                NSLocalizedString("이미지와 여러 값을 한 단축어에 함께 담을 수 있어요", comment: "Changelog 4.4.3 item 3"),
                NSLocalizedString("새 단축어 화면 정리 — 채우기 버튼과 변수 설명이 또렷해졌어요", comment: "Changelog 4.4.3 item 4"),
                NSLocalizedString("기기 간 동기화(베타) 수정 — 전송이 확정된 뒤에만 완료 처리해 누락을 막아요", comment: "Changelog 4.4.3 item 5")
            ]
        ),
        ChangelogEntry(
            version: "4.4.0",
            released: "2026-07-23",
            highlights: [
                NSLocalizedString("맥에서 단축어 순서를 끌어다 바꾸고, 그 순서를 아이폰·키보드까지 동기화", comment: "Changelog 4.4.0 item 1"),
                NSLocalizedString("아이폰에서 바꾼 순서도 맥의 모든 화면에 그대로 반영", comment: "Changelog 4.4.0 item 2"),
                NSLocalizedString("키보드 검색에서 한글이 흩어지던 문제 수정 — 이제 정확히 조합돼 찾아져요", comment: "Changelog 4.4.0 item 3"),
                NSLocalizedString("켜 둔 빈 카테고리도 탭으로 남아 스와이프로 바로 이동", comment: "Changelog 4.4.0 item 4")
            ]
        ),
        ChangelogEntry(
            version: "4.3.9",
            released: "2026-07-18",
            highlights: [
                NSLocalizedString("맑은 유리 카드와 배경 사진 — 8가지 풍경이 탭마다 다르게 비쳐요", comment: "Changelog 4.3.9 item 1"),
                NSLocalizedString("한번에 가져오기 개편 — 붙여넣으면 서비스명·아이디·비밀번호를 알아서 분리", comment: "Changelog 4.3.9 item 2"),
                NSLocalizedString("비밀번호·PIN·인증서는 가져올 때부터 자동으로 암호화되는 보안 단축어로", comment: "Changelog 4.3.9 item 3"),
                NSLocalizedString("사진·카메라에서 텍스트를 인식해 가져오기 — 카드 사진은 번호와 유효기간만", comment: "Changelog 4.3.9 item 4"),
                NSLocalizedString("콤보가 쉬워졌어요 — 값을 이어 붙이고 보안 콤보로 암호화 저장까지", comment: "Changelog 4.3.9 item 5")
            ]
        ),
        ChangelogEntry(
            version: "4.3.8",
            released: "2026-07-17",
            highlights: [
                NSLocalizedString("iOS 26 순정 디자인 전면 적용 — 유리 탭바와 투명한 상단", comment: "Changelog 4.3.8 item 1"),
                NSLocalizedString("큰 제목이 스크롤에 따라 작아졌다 커지는 순정 타이틀 동작", comment: "Changelog 4.3.8 item 2"),
                NSLocalizedString("만들다 만 단축어만 임시저장 — 열어만 봐도 쌓이던 문제 정리", comment: "Changelog 4.3.8 item 3"),
                NSLocalizedString("이미지와 이름만 넣은 단축어가 저장되지 않던 문제 해결", comment: "Changelog 4.3.8 item 4")
            ]
        ),
        ChangelogEntry(
            version: "4.3.7",
            released: "2026-07-14",
            highlights: [
                NSLocalizedString("메모 구분 표시를 꺼도 남아있던 카드 테두리까지 완전히 숨김", comment: "Changelog 4.3.7 item 1"),
                NSLocalizedString("홈 화면 작성 가이드 카드를 닫으면 조용히 사라져요", comment: "Changelog 4.3.7 item 2"),
                NSLocalizedString("붙여넣기 허용을 한 번에 — 클립보드 화면에서 iOS 설정으로 바로 이동", comment: "Changelog 4.3.7 item 3"),
                NSLocalizedString("여러분이 남겨주신 피드백을 반영한 다듬기 업데이트", comment: "Changelog 4.3.7 item 4")
            ]
        )
    ]

    /// 현재 실행 중인 앱 버전 — 목록에서 강조하는 데 쓴다.
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
