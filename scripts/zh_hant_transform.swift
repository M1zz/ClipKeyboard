import Foundation
// 표준입력의 각 줄을 ICU Hans-Hant 로 바꿔 표준출력에 그대로 돌려준다(글자 단위 변환).
while let line = readLine(strippingNewline: true) {
    let m = NSMutableString(string: line) as CFMutableString
    CFStringTransform(m, nil, "Hans-Hant" as CFString, false)
    print(m as String)
}
