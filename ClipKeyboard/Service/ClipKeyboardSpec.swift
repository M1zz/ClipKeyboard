//
//  ClipKeyboardSpec.swift
//  ClipKeyboard
//
//  LeeoKit 계약(LeeoAppSpec) 준수 — 이 앱의 공통 기능 설정값 단일 소스.
//  피드백 시스템 구현은 전부 LeeoKit에 있고, 앱은 이 설정만 제공한다.
//
//  ⚠️ feedback의 컨테이너/레코드 타입/구독 ID는 CloudKit Dashboard·기존 사용자
//  기기와의 계약이다 — 변경 금지 (ClipKeyboardSpecTests가 잠근다).
//

import Foundation
import LeeoKit

enum ClipKeyboardSpec: LeeoAppSpec {
    static let appName = "ClipKeyboard"
    static let developerEmail = Constants.developerEmail

    /// CloudKitBackupService와 같은 컨테이너를 써야 Dashboard 한 곳에서 관리된다.
    /// appIdentifier는 nil — 단일 앱 스키마 (appId 필드 미사용, 기존 배포 스키마와 호환).
    static let feedback = LeeoFeedbackConfig(
        containerIdentifier: "iCloud.com.Ysoup.TokenMemo"
    )
}
