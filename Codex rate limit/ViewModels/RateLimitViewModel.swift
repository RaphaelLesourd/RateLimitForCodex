import AppKit
import Combine
import Foundation

@MainActor
final class RateLimitViewModel: ObservableObject {
  enum DataCollectionMode: String {
    case officialAPI
    case experimentalLocalSession

    var title: String {
      switch self {
        case .officialAPI:
          return "API Key"
        case .experimentalLocalSession:
          return "Codex Session"
      }
    }
  }

  @Published private(set) var dataCollectionMode: DataCollectionMode

  @Published private(set) var apiKey: String

  @Published var model: String {
    didSet { UserDefaults.standard.set(model, forKey: Self.modelDefaultsKey) }
  }

  @Published var refreshIntervalSeconds: Int {
    didSet {
      UserDefaults.standard.set(refreshIntervalSeconds, forKey: Self.refreshIntervalDefaultsKey)
      nextAutomaticRefreshAt = .distantPast
      startTimer()
    }
  }

  @Published private(set) var snapshot: RateLimitSnapshot?
  @Published private(set) var isRefreshing = false
  @Published private(set) var statusText = "Not refreshed yet"
  @Published private(set) var errorText: String?
  @Published private(set) var burnTrendSymbol = "→"

  var isExperimentalMode: Bool {
    dataCollectionMode == .experimentalLocalSession
  }

  var lastRefreshTokenCost: Int? {
    snapshot?.requestTokensUsed
  }

  var estimatedHourlyTokenBurnPercent: Double? {
    guard dataCollectionMode == .officialAPI,
          let tokensUsed = snapshot?.requestTokensUsed, tokensUsed > 0,
          let tokenLimit = snapshot?.tokensLimit, tokenLimit > 0
    else {
      return nil
    }

    let refreshesPerHour = 3600.0 / Double(refreshIntervalSeconds)
    let hourlyTokenUse = Double(tokensUsed) * refreshesPerHour
    return (hourlyTokenUse / Double(tokenLimit)) * 100.0
  }

  private let environment: AppEnvironment
  private var timer: Timer?
  private var nextAutomaticRefreshAt: Date = .distantPast
  private var consecutiveAutomaticFailures = 0
  private var previousEstimatedHourlyBurnPercent: Double?

  private static let modelDefaultsKey = "openai_model"
  private static let refreshIntervalDefaultsKey = "refresh_interval_seconds"
  private static let dataCollectionModeDefaultsKey = "data_collection_mode"
  private static let localSessionRecencySeconds: TimeInterval = 12 * 60 * 60
  private static let maximumBackoffSeconds = 15 * 60

  static let supportedRefreshIntervals = [60, 120, 300]

  init(environment: AppEnvironment) {
    self.environment = environment

    let defaults = UserDefaults.standard
    let savedKey = environment.apiKeyStore.loadApiKey() ?? ""
    let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""

    apiKey = savedKey.isEmpty ? envKey : savedKey
    model = defaults.string(forKey: Self.modelDefaultsKey) ?? "gpt-5"

    let savedInterval = defaults.integer(forKey: Self.refreshIntervalDefaultsKey)
    refreshIntervalSeconds = Self.supportedRefreshIntervals.contains(savedInterval) ? savedInterval : 60

    dataCollectionMode = DataCollectionMode(rawValue: defaults.string(forKey: Self.dataCollectionModeDefaultsKey) ?? "") ?? .officialAPI

    startTimer()
    Task { await refreshIfConfigured() }
  }

  deinit {
    timer?.invalidate()
  }

  func refresh() {
    Task { await refreshIfConfigured(force: true) }
  }

  func setDataCollectionMode(_ mode: DataCollectionMode) {
    guard dataCollectionMode != mode else { return }
    DispatchQueue.main.async { [weak self] in
      self?.applyDataCollectionMode(mode)
    }
  }

  func setAPIKey(_ value: String) {
    guard apiKey != value else { return }
    DispatchQueue.main.async { [weak self] in
      self?.applyAPIKey(value)
    }
  }

  func quit() {
    NSApplication.shared.terminate(nil)
  }

  private func startTimer() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(refreshIntervalSeconds), repeats: true) { [weak self] _ in
      Task { @MainActor in
        await self?.refreshIfConfigured(force: false)
      }
    }
    timer?.tolerance = 3
  }

  private func applyDataCollectionMode(_ mode: DataCollectionMode) {
    guard dataCollectionMode != mode else { return }
    dataCollectionMode = mode
    UserDefaults.standard.set(mode.rawValue, forKey: Self.dataCollectionModeDefaultsKey)
    errorText = nil
    previousEstimatedHourlyBurnPercent = nil
    burnTrendSymbol = "→"
    nextAutomaticRefreshAt = .distantPast
    consecutiveAutomaticFailures = 0
    refresh()
  }

  private func applyAPIKey(_ value: String) {
    guard apiKey != value else { return }
    apiKey = value
    environment.apiKeyStore.save(apiKey: value)
  }

  private func refreshIfConfigured(force: Bool = false) async {
    if isRefreshing {
      return
    }

    if !force, Date() < nextAutomaticRefreshAt {
      return
    }

    isRefreshing = true
    defer { isRefreshing = false }

    switch dataCollectionMode {
      case .officialAPI:
        await refreshFromOfficialAPI(force: force)
      case .experimentalLocalSession:
        refreshFromLocalSession(force: force)
    }
  }

  private func refreshFromOfficialAPI(force: Bool) async {
    let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
    let authToken = resolveAuthToken()

    guard let authToken else {
      if force {
        statusText = "Waiting for API key"
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
      updateBurnTrend(with: newSnapshot)
      scheduleNextAutomaticRefreshAfterSuccess(usagePercent: highestOfficialUsagePercent(from: newSnapshot))
    } catch {
      logError("official_api_refresh_failed", error: error)
      errorText = mappedErrorText(error)
      statusText = "Last attempt \(Self.timeFormatter.string(from: Date()))"
      scheduleNextAutomaticRefreshAfterFailure()
    }
  }

  private func refreshFromLocalSession(force: Bool) {
    do {
      let localSnapshot = try environment.localSessionRateLimitService.loadLatest(maxAge: Self.localSessionRecencySeconds)
      snapshot = RateLimitSnapshot(
        requestsLimit: nil,
        requestsRemaining: nil,
        requestsReset: nil,
        tokensLimit: nil,
        tokensRemaining: nil,
        tokensReset: nil,
        requestTokensUsed: nil,
        sessionPrimaryUsedPercent: localSnapshot.primaryUsedPercent,
        sessionPrimaryWindowMinutes: localSnapshot.primaryWindowMinutes,
        sessionPrimaryResetsAt: localSnapshot.primaryResetsAt,
        sessionSecondaryUsedPercent: localSnapshot.secondaryUsedPercent,
        sessionSecondaryWindowMinutes: localSnapshot.secondaryWindowMinutes,
        sessionSecondaryResetsAt: localSnapshot.secondaryResetsAt,
        fetchedAt: Date()
      )
      errorText = nil
      statusText = "Local session checked \(Self.timeFormatter.string(from: Date()))"
      previousEstimatedHourlyBurnPercent = nil
      burnTrendSymbol = "→"
      scheduleNextAutomaticRefreshAfterSuccess(usagePercent: localSnapshot.primaryUsedPercent)
    } catch {
      logError("experimental_local_refresh_failed", error: error)
      snapshot = nil
      errorText = error.localizedDescription
      if force {
        statusText = "Local session attempt \(Self.timeFormatter.string(from: Date()))"
      }
      scheduleNextAutomaticRefreshAfterFailure()
    }
  }

  private func resolveAuthToken() -> String? {
    let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedKey.isEmpty else {
      errorText = "Add an OpenAI API key."
      return nil
    }
    return trimmedKey
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

  private func scheduleNextAutomaticRefreshAfterSuccess(usagePercent: Double?) {
    consecutiveAutomaticFailures = 0

    let nextInterval: Int
    if let usagePercent {
      if usagePercent >= 70 {
        nextInterval = refreshIntervalSeconds
      } else if usagePercent >= 40 {
        nextInterval = max(refreshIntervalSeconds, 120)
      } else {
        nextInterval = max(refreshIntervalSeconds, 300)
      }
    } else {
      nextInterval = max(refreshIntervalSeconds, 120)
    }

    nextAutomaticRefreshAt = Date().addingTimeInterval(TimeInterval(nextInterval))
  }

  private func scheduleNextAutomaticRefreshAfterFailure() {
    consecutiveAutomaticFailures = min(consecutiveAutomaticFailures + 1, 4)
    let multiplier = Int(pow(2.0, Double(consecutiveAutomaticFailures)))
    let backoff = min(refreshIntervalSeconds * multiplier, Self.maximumBackoffSeconds)
    nextAutomaticRefreshAt = Date().addingTimeInterval(TimeInterval(backoff))
  }

  private func highestOfficialUsagePercent(from snapshot: RateLimitSnapshot) -> Double? {
    let requestsUsage = usedPercent(limit: snapshot.requestsLimit, remaining: snapshot.requestsRemaining)
    let tokensUsage = usedPercent(limit: snapshot.tokensLimit, remaining: snapshot.tokensRemaining)
    if let requestsUsage, let tokensUsage {
      return max(requestsUsage, tokensUsage)
    }
    return requestsUsage ?? tokensUsage
  }

  private func usedPercent(limit: Int?, remaining: Int?) -> Double? {
    guard let limit, let remaining, limit > 0 else { return nil }
    let used = max(0, min(limit, limit - remaining))
    return (Double(used) / Double(limit)) * 100.0
  }

  private func updateBurnTrend(with snapshot: RateLimitSnapshot) {
    guard let currentBurn = estimatedHourlyTokenBurnPercent(snapshot: snapshot) else {
      previousEstimatedHourlyBurnPercent = nil
      burnTrendSymbol = "→"
      return
    }

    if let previousBurn = previousEstimatedHourlyBurnPercent {
      if currentBurn > previousBurn + 0.05 {
        burnTrendSymbol = "↗︎"
      } else if currentBurn < previousBurn - 0.05 {
        burnTrendSymbol = "↘︎"
      } else {
        burnTrendSymbol = "→"
      }
    } else {
      burnTrendSymbol = "→"
    }

    previousEstimatedHourlyBurnPercent = currentBurn
  }

  private func estimatedHourlyTokenBurnPercent(snapshot: RateLimitSnapshot) -> Double? {
    guard dataCollectionMode == .officialAPI,
          let tokensUsed = snapshot.requestTokensUsed, tokensUsed > 0,
          let tokenLimit = snapshot.tokensLimit, tokenLimit > 0
    else {
      return nil
    }

    let refreshesPerHour = 3600.0 / Double(refreshIntervalSeconds)
    let hourlyTokenUse = Double(tokensUsed) * refreshesPerHour
    return (hourlyTokenUse / Double(tokenLimit)) * 100.0
  }

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .medium
    return formatter
  }()

  private func logError(_ event: String, error: Error) {
    print("[RateLimitMonitor] \(event): \(error.localizedDescription)")
  }

}
