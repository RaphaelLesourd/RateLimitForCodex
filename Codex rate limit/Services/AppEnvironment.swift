import Foundation

protocol APIKeyStore {
  func save(apiKey: String)
  func loadApiKey() -> String?
}

protocol OpenAIRateLimitServiceProtocol {
  func fetchRateLimit(authToken: String, model: String) async throws -> RateLimitSnapshot
}

protocol LocalSessionRateLimitServiceProtocol {
  func loadLatest(maxAge: TimeInterval?) throws -> SessionRateLimitSnapshot
}

struct AppEnvironment {
  let apiKeyStore: any APIKeyStore
  let openAIRateLimitService: any OpenAIRateLimitServiceProtocol
  let localSessionRateLimitService: any LocalSessionRateLimitServiceProtocol

  init(
    apiKeyStore: any APIKeyStore,
    openAIRateLimitService: any OpenAIRateLimitServiceProtocol,
    localSessionRateLimitService: any LocalSessionRateLimitServiceProtocol
  ) {
    self.apiKeyStore = apiKeyStore
    self.openAIRateLimitService = openAIRateLimitService
    self.localSessionRateLimitService = localSessionRateLimitService
  }

  static func live() -> AppEnvironment {
    AppEnvironment(
      apiKeyStore: KeychainAPIKeyStore(),
      openAIRateLimitService: OpenAIRateLimitService(),
      localSessionRateLimitService: CodexSessionRateLimitService()
    )
  }
}
