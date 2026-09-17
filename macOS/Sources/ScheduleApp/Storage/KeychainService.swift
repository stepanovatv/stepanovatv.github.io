import Foundation
import Security

struct KeychainService {
    private let service = "app.publicavailability.schedule.github"
    private func query(account: String) -> [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] }
    func read(account: String) throws -> String {
        var request = query(account: account); request[kSecReturnData as String] = true; request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?; let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return "" }
        guard status == errSecSuccess, let data = result as? Data, let token = String(data: data, encoding: .utf8) else { throw StorageError.keychain }
        return token
    }
    func save(_ token: String, account: String) throws {
        let request = query(account: account)
        let update: [String: Any] = [kSecValueData as String: Data(token.utf8)]
        var status = SecItemUpdate(request as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var insert = request; insert[kSecValueData as String] = Data(token.utf8)
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(insert as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw StorageError.keychain }
    }
    func delete(account: String) throws {
        let status = SecItemDelete(query(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw StorageError.keychain }
    }
}
