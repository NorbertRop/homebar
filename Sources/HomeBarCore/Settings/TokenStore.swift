import Foundation
import Security

public protocol TokenStore: Sendable {
    func read() -> String?
    func write(_ token: String) throws
    func delete() throws
}

public final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private var token: String?
    public init() {}
    public func read() -> String? { token }
    public func write(_ token: String) throws { self.token = token }
    public func delete() throws { token = nil }
}

public struct KeychainTokenStore: TokenStore {
    private let service = "bot.homebar.token"
    private let account = "ha-long-lived-token"
    public init() {}

    public func read() -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: account,
                                kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func write(_ token: String) throws {
        try delete()
        let attrs: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account,
                                    kSecValueData as String: Data(token.utf8)]
        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else { throw HAError.protocolError("keychain \(status)") }
    }

    public func delete() throws {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: account]
        let status = SecItemDelete(q as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw HAError.protocolError("keychain delete \(status)")
        }
    }
}
