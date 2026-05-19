import Foundation
import Security

struct KeychainStore {
    enum StoreError: LocalizedError {
        case unexpectedData
        case unhandledStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .unexpectedData:
                "Unexpected Keychain data."
            case .unhandledStatus(let status):
                "Keychain status \(status)."
            }
        }
    }

    let service: String
    let account: String

    func save(_ value: String) throws {
        let data = Data(value.utf8)
        try delete(ignoringNotFound: true)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw StoreError.unhandledStatus(status)
        }
    }

    func read() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw StoreError.unhandledStatus(status)
        }

        guard let data = item as? Data else {
            throw StoreError.unexpectedData
        }

        return String(data: data, encoding: .utf8)
    }

    func delete() throws {
        try delete(ignoringNotFound: false)
    }

    private func delete(ignoringNotFound: Bool) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || (ignoringNotFound && status == errSecItemNotFound) else {
            throw StoreError.unhandledStatus(status)
        }
    }
}
