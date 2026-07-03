import Foundation
import Security

enum KeychainService {
    private static let service = "com.weread.notesmanager"
    private static let wereadAccount = "wereadAPIKey"
    private static let openAIAccount = "openAIAPIKey"
    private static let deepSeekAccount = "deepSeekAPIKey"
    private static let glmAccount = "glmAPIKey"
    private static let minimaxAccount = "minimaxAPIKey"
    private static let aliyunAccount = "aliyunAPIKey"
    private static let doubaoAccount = "doubaoAPIKey"
    private static let fallbackPrefix = "localAPIKeyFallback."

    static func loadWeReadAPIKey() -> String? {
        load(account: wereadAccount)
    }

    static func saveWeReadAPIKey(_ value: String) throws {
        try save(value, account: wereadAccount)
    }

    static func deleteWeReadAPIKey() throws {
        try delete(account: wereadAccount)
    }

    static func loadOpenAIAPIKey() -> String? {
        load(account: openAIAccount)
    }

    static func saveOpenAIAPIKey(_ value: String) throws {
        try save(value, account: openAIAccount)
    }

    static func deleteOpenAIAPIKey() throws {
        try delete(account: openAIAccount)
    }

    static func loadAPIKey(for provider: AIProvider) -> String? {
        load(account: account(for: provider))
    }

    static func saveAPIKey(_ value: String, for provider: AIProvider) throws {
        try save(value, account: account(for: provider))
    }

    static func deleteAPIKey(for provider: AIProvider) throws {
        try delete(account: account(for: provider))
    }

    private static func account(for provider: AIProvider) -> String {
        switch provider {
        case .openAI: return openAIAccount
        case .deepSeek: return deepSeekAccount
        case .glm: return glmAccount
        case .minimax: return minimaxAccount
        case .aliyun: return aliyunAccount
        case .doubao: return doubaoAccount
        }
    }

    private static func load(account: String) -> String? {
        if let value = loadFromKeychain(account: account, useDataProtection: false) {
            return value
        }
        if let value = loadFromKeychain(account: account, useDataProtection: true) {
            return value
        }
        return UserDefaults.standard.string(forKey: fallbackKey(account))
    }

    private static func loadFromKeychain(account: String, useDataProtection: Bool) -> String? {
        var query = baseQuery(account: account, useDataProtection: useDataProtection)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func save(_ value: String, account: String) throws {
        do {
            try saveToKeychain(value, account: account, useDataProtection: false)
            UserDefaults.standard.removeObject(forKey: fallbackKey(account))
        } catch {
            do {
                try saveToKeychain(value, account: account, useDataProtection: true)
                UserDefaults.standard.removeObject(forKey: fallbackKey(account))
            } catch {
                UserDefaults.standard.set(value, forKey: fallbackKey(account))
            }
        }
    }

    private static func saveToKeychain(_ value: String, account: String, useDataProtection: Bool) throws {
        let data = Data(value.utf8)
        var query = baseQuery(account: account, useDataProtection: useDataProtection)

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError.unhandled(updateStatus)
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unhandled(addStatus)
        }
    }

    private static func delete(account: String) throws {
        UserDefaults.standard.removeObject(forKey: fallbackKey(account))

        var firstError: OSStatus?
        for useDataProtection in [false, true] {
            let status = SecItemDelete(baseQuery(account: account, useDataProtection: useDataProtection) as CFDictionary)
            if status != errSecSuccess && status != errSecItemNotFound {
                firstError = firstError ?? status
            }
        }
        if let firstError {
            throw KeychainError.unhandled(firstError)
        }
    }

    private static func baseQuery(account: String, useDataProtection: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            // 显式禁用 iCloud Keychain 同步，避免 API Key 跨设备流动。
            kSecAttrSynchronizable as String: false
        ]
        if useDataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

    private static func fallbackKey(_ account: String) -> String {
        fallbackPrefix + account
    }
}

enum KeychainError: LocalizedError {
    case unhandled(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            return "保存 API Key 失败（Keychain 状态码：\(status)）。"
        }
    }
}
