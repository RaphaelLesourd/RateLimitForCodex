import Foundation

protocol APIKeyStore {
  func save(apiKey: String)
  func loadApiKey() -> String?
}

protocol OpenAIRateLimitServiceProtocol {
  func fetchRateLimit(authToken: String, model: String) async throws -> RateLimitSnapshot
}

protocol CodexAuthServiceProtocol {
  func loadSession() throws -> CodexAuthSession
  func logout() throws
}

protocol CodexSessionRateLimitServiceProtocol {
  func loadLatest(maxAge: TimeInterval?, signedOutAfter: Date?) throws -> CodexSessionRateLimitSnapshot
  func hasRecentSession(maxAge: TimeInterval, signedOutAfter: Date?) throws -> Bool
}

struct AppEnvironment {
  let apiKeyStore: any APIKeyStore
  let openAIRateLimitService: any OpenAIRateLimitServiceProtocol
  let codexAuthService: any CodexAuthServiceProtocol
  let codexSessionRateLimitService: any CodexSessionRateLimitServiceProtocol

  init(
    apiKeyStore: any APIKeyStore,
    openAIRateLimitService: any OpenAIRateLimitServiceProtocol,
    codexAuthService: any CodexAuthServiceProtocol,
    codexSessionRateLimitService: any CodexSessionRateLimitServiceProtocol
  ) {
    self.apiKeyStore = apiKeyStore
    self.openAIRateLimitService = openAIRateLimitService
    self.codexAuthService = codexAuthService
    self.codexSessionRateLimitService = codexSessionRateLimitService
  }

  static func live() -> AppEnvironment {
    AppEnvironment(
      apiKeyStore: KeychainAPIKeyStore(),
      openAIRateLimitService: OpenAIRateLimitService(),
      codexAuthService: CodexAuthService(),
      codexSessionRateLimitService: CodexSessionRateLimitService()
    )
  }
}
