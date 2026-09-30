//
//  FreeUseTestSupport.swift
//  ClipKeyboardTests
//
//  무료 기간을 **끝낸 채로** 시험한다.
//
//  왜 필요한가: 5.2 부터 문턱 전에는 전부 열려 있다(`FreeUse`). 시험 기기는 대개 쓴 횟수가 0 이라
//  늘 무료 기간이고, 그러면 무료 한도를 보는 시험이 "Pro 라서" 조용히 건너뛰어진다. 초록불은 그대로인데
//  아무것도 안 지키는 시험이 된다. 한도를 보는 시험은 이걸로 무료 기간을 끝내고 돌린다.
//

import Foundation
@testable import ClipKeyboard

struct FreeUsePeriodEnded {
    private let saved: Any?

    /// 무료 기간을 끝낸다. 돌려놓을 때 `restore()` 를 부른다.
    init() {
        saved = AppGroup.defaults?.object(forKey: DefaultsKey.freeUseCount)
        AppGroup.defaults?.set(FreeUse.threshold, forKey: DefaultsKey.freeUseCount)
    }

    func restore() {
        if let saved { AppGroup.defaults?.set(saved, forKey: DefaultsKey.freeUseCount) }
        else { AppGroup.defaults?.removeObject(forKey: DefaultsKey.freeUseCount) }
    }
}
