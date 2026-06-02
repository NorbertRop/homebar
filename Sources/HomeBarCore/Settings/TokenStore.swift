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

/// Token in a `0600` file under Application Support. Avoids the Keychain access prompt
/// that recurs whenever the app's (ad-hoc) code signature changes between builds, at the
/// cost of at-rest encryption — the same trade-off Home Assistant itself makes.
public struct FileTokenStore: TokenStore {
    private let url: URL
    public init(url: URL = FileTokenStore.defaultURL) { self.url = url }

    public static var defaultURL: URL {
        Settings.defaultURL().deletingLastPathComponent().appendingPathComponent("token")
    }

    public func read() -> String? {
        guard let s = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    public func write(_ token: String) throws {
        try token.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func delete() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
