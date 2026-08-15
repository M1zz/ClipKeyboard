//
//  LocalizedTestSupport.swift
//  ClipKeyboardTests
//
//  화면에 나가는 문자열을 테스트에서 다루는 방법.
//
//  이 앱은 ko/en 두 언어로 나가고, 소스 언어가 한국어라 코드에 적힌 키가 곧 한국어 원문이다.
//  그래서 테스트에서 결과를 비교할 때 한국어를 그대로 적어 두기 쉬웠고, 실제로 그렇게 적혀 있었다.
//
//  문제는 그 테스트가 **시뮬레이터 언어에 따라 달라진다**는 것이다. 영어로 돌리면
//  "1분" 이 "1 min" 으로 나와 열 개가 한꺼번에 실패했는데, 실패의 내용은 버그가 아니라
//  "번역이 정상 동작했다" 였다. 고정해야 할 계약은 문구 자체가 아니라
//  **어느 경우에 어느 문구가 나오는가** 이므로, 양쪽이 같은 키를 지나오게 해서 비교한다.
//
//  이렇게 하면 남는 것도 있다. 구현에서 키를 실수로 바꾸면 여기서 못 찾아 그대로 실패한다.
//

import Foundation
@testable import ClipKeyboard

/// 앱 번들의 번역표에서 값을 꺼낸다.
///
/// `Bundle.main` 에 기대지 않는다. 테스트가 호스트 앱 안에서 돌든 따로 돌든
/// 앱 코드가 들어 있는 번들을 정확히 가리켜야 번역표를 찾을 수 있다.
private let appBundle = Bundle(for: MemoStore.self)

/// 사용자에게 보이는 문자열을 구현과 **같은 통로로** 가져온다.
func localizedForTest(_ key: String) -> String {
    NSLocalizedString(key, bundle: appBundle, comment: "")
}

/// `%d` 하나가 들어가는 형식 문자열.
func localizedForTest(_ key: String, _ number: Int) -> String {
    String(format: localizedForTest(key), number)
}

/// `%d` 둘이 들어가는 형식 문자열.
func localizedForTest(_ key: String, _ first: Int, _ second: Int) -> String {
    String(format: localizedForTest(key), first, second)
}
