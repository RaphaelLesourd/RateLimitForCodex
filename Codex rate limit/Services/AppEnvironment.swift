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

protocol LoginItemServiceProtocol {
  var isEnabled: Bool { get }
  func setEnabled(_ enabled: Bool) throws
}

struct AppEnvironment {
  let apiKeyStore: any APIKeyStore
  let openAIRateLimitService: any OpenAIRateLimitServiceProtocol
  let localSessionRateLimitService: any LocalSessionRateLimitServiceProtocol
  let loginItemService: any LoginItemServiceProtocol

  init(
    apiKeyStore: any APIKeyStore,
    openAIRateLimitService: any OpenAIRateLimitServiceProtocol,
    localSessionRateLimitService: any LocalSessionRateLimitServiceProtocol,
    loginItemService: any LoginItemServiceProtocol
  ) {
    self.apiKeyStore = apiKeyStore
    self.openAIRateLimitService = openAIRateLimitService
    self.localSessionRateLimitService = localSessionRateLimitService
    self.loginItemService = loginItemService
  }

  static func live() -> AppEnvironment {
    AppEnvironment(
      apiKeyStore: KeychainAPIKeyStore(),
      openAIRateLimitService: OpenAIRateLimitService(),
      localSessionRateLimitService: CodexSessionRateLimitService(),
      loginItemService: LoginItemService()
    )
  }
}
