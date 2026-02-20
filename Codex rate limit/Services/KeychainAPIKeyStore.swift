import Foundation
import Security

struct KeychainAPIKeyStore: APIKeyStore {
  private let service = "CodexRateLimitMenuBar"
  private let account = "openai_api_key"

  func save(apiKey: String) {
    let query = baseQuery()

    if apiKey.isEmpty {
      SecItemDelete(query as CFDictionary)
      return
    }

    let data = Data(apiKey.utf8)
    let attributesToUpdate: [String: Any] = [kSecValueData as String: data]
    let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

    if updateStatus == errSecItemNotFound {
      var addQuery = query
      addQuery[kSecValueData as String] = data
      SecItemAdd(addQuery as CFDictionary, nil)
    }
  }

  func loadApiKey() -> String? {
    var query = baseQuery()
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status == errSecSuccess, let data = result as? Data else {
      return nil
    }

    return String(data: data, encoding: .utf8)
  }

  private func baseQuery() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}
