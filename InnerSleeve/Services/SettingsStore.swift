import Foundation
import Observation
import Security

@Observable
final class SettingsStore {
    var provider: ReleaseProvider {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: providerKey) }
    }

    private let providerKey = "releaseProvider"
    private let tokenAccount = "discogs-token"

    init() {
        let raw = UserDefaults.standard.string(forKey: providerKey) ?? ReleaseProvider.musicBrainz.rawValue
        provider = ReleaseProvider(rawValue: raw) ?? .musicBrainz
    }

    var discogsToken: String {
        get { KeychainTokenStore.read(account: tokenAccount) ?? "" }
        set { KeychainTokenStore.write(newValue, account: tokenAccount) }
    }

    func makeLookupService() -> ReleaseLookupService {
        switch provider {
        case .musicBrainz:
            return MusicBrainzService()
        case .discogs:
            return DiscogsService(tokenProvider: { self.discogsToken })
        }
    }
}

enum KeychainTokenStore {
    static func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String, account: String) {
        let query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty, let data = value.data(using: .utf8) else { return }
        var item = query
        item[kSecValueData as String] = data
        SecItemAdd(item as CFDictionary, nil)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "InnerSleeve",
            kSecAttrAccount as String: account,
        ]
    }
}
