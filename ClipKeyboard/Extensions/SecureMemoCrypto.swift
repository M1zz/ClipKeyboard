//
//  SecureMemoCrypto.swift
//  ClipKeyboard
//
//  보안 메모(value) 암호화. 키는 iCloud 키체인(synchronizable)에 저장돼 사용자의
//  모든 기기로 종단간 동기화된다. 키 자체는 기기 잠금(생체/패스코드) 보호 아래 있고,
//  앱은 추가로 생체/PIN 게이팅을 둔다. 따라서:
//   - 디스크/CloudKit에 저장되는 보안 메모 값은 암호문("smenc1:" 접두)이라 평문 노출 없음.
//   - 다른 기기(맥 포함)는 같은 iCloud 계정이면 키가 동기화돼 인증 후 복호화 가능.
//
//  설계 노트:
//   - 키체인 액세스 그룹은 entitlement의 단일 keychain-access-group을 기본 사용(쿼리에서
//     access group 생략 → 그 그룹 사용). iOS 앱·키보드 익스텐션·맥 앱이 같은 그룹/계정을
//     공유하므로 동일 키를 읽는다.
//   - decrypt()는 평문(마커 없음)을 그대로 통과시켜 레거시/비보안 값에 안전하다.
//   - 키가 아직 동기화되지 않았으면 decrypt는 nil — 호출부는 잠금 상태로 처리(데이터 보존).
//

import Foundation
import CryptoKit
import Security

enum SecureMemoCrypto {

    /// 암호문 식별 접두. 이 접두가 있으면 AES-GCM 암호문(base64)이다.
    static let marker = "smenc1:"

    private static let keychainService = "com.Ysoup.TokenMemo.securememo"
    private static let keychainAccount = "secure_memo_master_key_v1"

    // MARK: - Public

    /// 문자열이 암호문인지.
    static func isEncrypted(_ value: String) -> Bool { value.hasPrefix(marker) }

    /// 키가 현재 기기에서 사용 가능한지(생성됐거나 동기화 완료).
    static var isKeyAvailable: Bool { loadKey() != nil }

    /// 평문을 암호화해 "smenc1:" + base64 형태로 반환. 키 확보 실패 시 nil.
    /// 이미 암호문이면 그대로 반환(중복 암호화 방지).
    static func encrypt(_ plaintext: String) -> String? {
        if isEncrypted(plaintext) { return plaintext }
        guard let key = key() else { return nil }
        guard let data = plaintext.data(using: .utf8),
              let sealed = try? AES.GCM.seal(data, using: key),
              let combined = sealed.combined else { return nil }
        return marker + combined.base64EncodedString()
    }

    /// 암호문이면 복호화, 평문이면 그대로 반환. 복호화 실패(키 미동기화 등) 시 nil.
    static func decrypt(_ value: String) -> String? {
        guard isEncrypted(value) else { return value }
        guard let key = loadKey() else { return nil }
        let b64 = String(value.dropFirst(marker.count))
        guard let combined = Data(base64Encoded: b64),
              let box = try? AES.GCM.SealedBox(combined: combined),
              let opened = try? AES.GCM.open(box, using: key),
              let text = String(data: opened, encoding: .utf8) else { return nil }
        return text
    }

    // MARK: - Key (iCloud Keychain, synchronizable)

    /// 키를 읽고, 없으면 생성. 생성된 키는 동기화로 다른 기기에 전파된다.
    private static func key() -> SymmetricKey? {
        if let existing = loadKey() { return existing }
        let newKey = SymmetricKey(size: .bits256)
        if storeKey(newKey) { return newKey }
        // 저장 경합(다른 기기/스레드가 막 생성) 시 다시 읽기.
        return loadKey()
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            // iCloud 키체인 동기화 — 사용자의 모든 기기로 종단간 전파.
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any
        ]
    }

    private static func loadKey() -> SymmetricKey? {
        var query = baseQuery()
        query[kSecReturnData as String] = kCFBooleanTrue as Any
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data, data.count == 32 else { return nil }
        return SymmetricKey(data: data)
    }

    @discardableResult
    private static func storeKey(_ key: SymmetricKey) -> Bool {
        let data = key.withUnsafeBytes { Data(Array($0)) }
        var query = baseQuery()
        query[kSecValueData as String] = data
        // synchronizable 항목은 ThisDeviceOnly 사용 불가. 첫 잠금 해제 후 접근(익스텐션도 OK).
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem { return true } // 이미 존재(동기화 경합) → 성공 간주
        return status == errSecSuccess
    }
}
