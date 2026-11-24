//
//  Keychain.swift
//  YT Music
//
//  Generic-password Keychain wrapper for auth cookies.
//

import Foundation
import Security

nonisolated enum Keychain {
    @discardableResult
    static func set(_ data: Data, service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
            let updateAttrs: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            ]
            return SecItemUpdate(updateQuery as CFDictionary, updateAttrs as CFDictionary) == errSecSuccess
        }
        return status == errSecSuccess
    }

    @discardableResult
    static func setString(_ value: String, service: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return set(data, service: service, account: account)
    }

    static func getString(service: String, account: String) -> String? {
        guard let data = get(service: service, account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func get(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    @discardableResult
    static func delete(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
