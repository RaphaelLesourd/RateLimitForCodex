import Foundation

struct CodexAuthService: CodexAuthServiceProtocol {
  enum Error: LocalizedError {
    case missingAuthFile
    case missingIdentityToken

    var errorDescription: String? {
      switch self {
        case .missingAuthFile:
          return "Codex auth file was not found."
        case .missingIdentityToken:
          return "Codex login token was not found."
      }
    }
  }

  func loadSession() throws -> CodexAuthSession {
    let authPath = NSString(string: "~/.codex/auth.json").expandingTildeInPath
    guard FileManager.default.fileExists(atPath: authPath) else {
      throw Error.missingAuthFile
    }

    let data = try Data(contentsOf: URL(fileURLWithPath: authPath))
    let authFile = try JSONDecoder().decode(AuthFile.self, from: data)

    guard nonEmpty(authFile.tokens?.accessToken) != nil || nonEmpty(authFile.tokens?.idToken) != nil else {
      throw Error.missingIdentityToken
    }

    let email = emailFromJWT(authFile.tokens?.idToken) ?? emailFromJWT(authFile.tokens?.accessToken)
    return CodexAuthSession(email: email)
  }

  func logout() throws {
    let authPath = NSString(string: "~/.codex/auth.json").expandingTildeInPath
    guard FileManager.default.fileExists(atPath: authPath) else { return }
    try FileManager.default.removeItem(atPath: authPath)
  }

  private func nonEmpty(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private func emailFromJWT(_ token: String?) -> String? {
    guard let token else { return nil }
    let segments = token.split(separator: ".")
    guard segments.count >= 2 else { return nil }

    guard let payloadData = decodeBase64URL(String(segments[1])),
          let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
    else {
      return nil
    }

    if let email = payload["email"] as? String {
      return email
    }

    if let profile = payload["https://api.openai.com/profile"] as? [String: Any],
       let email = profile["email"] as? String {
      return email
    }

    return nil
  }

  private func decodeBase64URL(_ value: String) -> Data? {
    let base64 = value
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let padded = base64.padding(toLength: ((base64.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
    return Data(base64Encoded: padded)
  }
}

private struct AuthFile: Decodable {
  let tokens: Tokens?
}

private struct Tokens: Decodable {
  let accessToken: String?
  let idToken: String?

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case idToken = "id_token"
  }
}
