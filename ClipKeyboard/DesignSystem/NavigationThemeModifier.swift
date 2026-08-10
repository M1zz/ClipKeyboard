//
//  NavigationThemeModifier.swift
//  ClipKeyboard
//
//  (구) Paper 테마용 네비게이션 largeTitle 폰트 오버라이드는 제거됨.
//  이유: iOS 26에서 UINavigationBar.appearance()에 커스텀 appearance 객체를 설정하면
//  해당 바가 시스템 Liquid Glass에서 제외(구형 렌더링 강등)되어, 앱 전체 네비바가
//  불투명해 보였다. 순정 glass가 우선이라 폰트 오버라이드를 포기한다.
//

import SwiftUI

extension View {
    /// (구) 네비게이션 바를 테마 배경색으로 불투명하게 만들던 모디파이어.
    /// iOS 26 Liquid Glass 전환: 불투명 강제를 걷어내고 시스템 기본(맨 위 투명 →
    /// 스크롤 시 glass)에 맡긴다. 27개 호출부를 유지한 채 이 한 곳만 바꿔
    /// 앱 전체 네비게이션 바가 한 번에 glass로 전환된다.
    @ViewBuilder
    func solidNavBar(_ color: Color) -> some View {
        self
    }

    /// [디자인 불변식] 하단(탭바) 배경 언제나 투명 - 플로팅 유리 필이 탭바를 대신한다.
    /// 상단(네비 타이틀)은 시스템 기본에 맡긴다: 맨 위에선 투명, 콘텐츠가 바 밑으로
    /// 들어가면 glass 베일. 상단까지 숨기면 인라인 타이틀이 스크롤된 행 위에 그대로
    /// 겹쳐 그려지고, 투명 네비바 영역이 행 터치까지 삼키는 문제가 생긴다(설정 탭에서
    /// "백업 및 복원"이 안 눌리던 버그).
    @ViewBuilder
    func alwaysTransparentBars() -> some View {
        #if os(iOS)
        self
            .scrollEdgeEffectHidden(true, for: .bottom)
            .toolbarBackgroundVisibility(.hidden, for: .tabBar)
        #else
        self
        #endif
    }
}
