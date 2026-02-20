import AppKit
import Combine
import Foundation

@MainActor
final class RateLimitViewModel: ObservableObject {
  enum AuthMode: String {
    case codexLogin
    case apiKey
  }

  @Published var apiKey: String {
    didSet { environment.apiKeyStore.save(apiKey: apiKey) }
  }

  @Published var model: String {
    didSet { UserDefaults.standard.set(model, forKey: Self.modelDefaultsKey) }
  }

  @Published var refreshIntervalSeconds: Int {
    didSet {
      UserDefaults.standard.set(refreshIntervalSeconds, forKey: Self.refreshIntervalDefaultsKey)
      startTimer()
    }
  }

  @Published private(set) var snapshot: RateLimitSnapshot?
  @Published private(set) var isRefreshing = false
  @Published private(set) var statusText = "Not refreshed yet"
  @Published private(set) var errorText: String?
  @Published private(set) var authMode: AuthMode = .apiKey
  @Published private(set) var codexAccountEmail: String?
  @Published private(set) var codexLoginAvailable = false
  @Published private(set) var codexSessionOnly = false

  private let environment: AppEnvironment
  private var timer: Timer?

  private static let modelDefaultsKey = "openai_model"
  private static let refreshIntervalDefaultsKey = "refresh_interval_seconds"
  private static let authModeDefaultsKey = "auth_mode"
  private static let codexSessionRecencySeconds: TimeInterval = 12 * 60 * 60

  static let supportedRefreshIntervals = [60, 120, 300]

  init(environment: AppEnvironment) {
    self.environment = environment

    let defaults = UserDefaults.standard
    let savedKey = environment.apiKeyStore.loadApiKey() ?? ""
    let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""

    apiKey = savedKey.isEmpty ? envKey : savedKey
    model = defaults.string(forKey: Self.modelDefaultsKey) ?? "gpt-5-codex"

    let savedInterval = defaults.integer(forKey: Self.refreshIntervalDefaultsKey)
    refreshIntervalSeconds = Self.supportedRefreshIntervals.contains(savedInterval) ? savedInterval : 60

    reloadCodexSession()

    let savedAuthMode = AuthMode(rawValue: defaults.string(forKey: Self.authModeDefaultsKey) ?? "")
    if let savedAuthMode {
      authMode = savedAuthMode
    } else {
      authMode = codexLoginAvailable ? .codexLogin : .apiKey
    }

    if authMode == .codexLogin {
      refreshCodexSnapshotLocally(force: false)
    }

    startTimer()
    Task { await refreshIfConfigured() }
  }

  deinit {
    timer?.invalidate()
  }

  func refresh() {
    Task { await refreshIfConfigured(force: true) }
  }

  func useCodexLogin() {
    authMode = .codexLogin
    UserDefaults.standard.set(authMode.rawValue, forKey: Self.authModeDefaultsKey)
    statusText = "Waiting for Codex session"
    errorText = nil
    refresh()
  }

  func useAPIKeyLogin() {
    authMode = .apiKey
    UserDefaults.standard.set(authMode.rawValue, forKey: Self.authModeDefaultsKey)
    errorText = nil
    refresh()
  }

  func quit() {
    NSApplication.shared.terminate(nil)
  }

  func reloadCodexSession() {
    var hasAuthToken = false
    do {
      let codexAuth = try environment.codexAuthService.loadSession()
      codexAccountEmail = codexAuth.email
      hasAuthToken = true
    } catch {
      codexAccountEmail = nil
    }

    let hasRecentSession = (try? environment.codexSessionRateLimitService.hasRecentSession(
      maxAge: Self.codexSessionRecencySeconds,
      signedOutAfter: nil
    )) ?? false

    codexSessionOnly = hasRecentSession && !hasAuthToken
    codexLoginAvailable = hasAuthToken || hasRecentSession
  }

  private func startTimer() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(refreshIntervalSeconds), repeats: true) { [weak self] _ in
      Task { @MainActor in
        await self?.refreshIfConfigured(force: true)
      }
    }
    timer?.tolerance = 3
  }

  private func refreshIfConfigured(force: Bool = false) async {
    if isRefreshing {
      if force, authMode == .codexLogin {
        reloadCodexSession()
        refreshCodexSnapshotLocally(force: true)
      }
      return
    }

    isRefreshing = true
    defer { isRefreshing = false }

    reloadCodexSession()

    if authMode == .codexLogin {
      refreshCodexSnapshotLocally(force: force)
      return
    }

    let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
    let authToken = resolveAuthToken()

    guard let authToken else {
      if force {
        statusText = authMode == .codexLogin ? "Waiting for Codex login" : "Waiting for API key"
      }
      return
    }

    guard !trimmedModel.isEmpty else {
      errorText = "Model cannot be empty."
      return
    }

    do {
      let newSnapshot = try await environment.openAIRateLimitService.fetchRateLimit(authToken: authToken, model: trimmedModel)
      snapshot = newSnapshot
      errorText = nil
      statusText = "Last checked \(Self.timeFormatter.string(from: newSnapshot.fetchedAt))"
    } catch {
      errorText = mappedErrorText(error)
      statusText = "Last attempt \(Self.timeFormatter.string(from: Date()))"
    }
  }

  private func resolveAuthToken() -> String? {
    switch authMode {
      case .apiKey:
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
          errorText = "Add an OpenAI API key or switch to Codex login."
          return nil
        }
        return trimmedKey
      case .codexLogin:
        return nil
    }
  }

  private func mappedErrorText(_ error: Error) -> String {
    if case let RateLimitError.httpError(statusCode, body) = error,
       statusCode == 401,
       body.localizedCaseInsensitiveContains("incorrect api key")
    {
      return "Incorrect API key. Paste a valid OpenAI API key."
    }
    return error.localizedDescription
  }

  private func refreshCodexSnapshotLocally(force: Bool) {
    do {
      let codexSnapshot = try environment.codexSessionRateLimitService.loadLatest(
        maxAge: Self.codexSessionRecencySeconds,
        signedOutAfter: nil
      )
      snapshot = RateLimitSnapshot(
        requestsLimit: nil,
        requestsRemaining: nil,
        requestsReset: nil,
        tokensLimit: nil,
        tokensRemaining: nil,
        tokensReset: nil,
        codexPrimaryUsedPercent: codexSnapshot.primaryUsedPercent,
        codexPrimaryWindowMinutes: codexSnapshot.primaryWindowMinutes,
        codexPrimaryResetsAt: codexSnapshot.primaryResetsAt,
        codexSecondaryUsedPercent: codexSnapshot.secondaryUsedPercent,
        codexSecondaryWindowMinutes: codexSnapshot.secondaryWindowMinutes,
        codexSecondaryResetsAt: codexSnapshot.secondaryResetsAt,
        fetchedAt: Date()
      )
      errorText = nil
      statusText = "Last checked \(Self.timeFormatter.string(from: Date()))"
    } catch {
      snapshot = nil
      if case CodexSessionRateLimitService.Error.noRateLimitData = error {
        errorText = nil
        statusText = "Waiting for Codex session"
      } else {
        errorText = error.localizedDescription
        if force {
          statusText = "Last attempt \(Self.timeFormatter.string(from: Date()))"
        }
      }
    }
  }

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .medium
    return formatter
  }()
}
