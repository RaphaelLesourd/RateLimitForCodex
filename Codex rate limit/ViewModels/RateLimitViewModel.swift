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
          return "Official API"
        case .experimentalLocalSession:
          return "Experimental Local"
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
      startTimer()
    }
  }

  @Published private(set) var snapshot: RateLimitSnapshot?
  @Published private(set) var isRefreshing = false
  @Published private(set) var statusText = "Not refreshed yet"
  @Published private(set) var errorText: String?

  var isExperimentalMode: Bool {
    dataCollectionMode == .experimentalLocalSession
  }

  private let environment: AppEnvironment
  private var timer: Timer?

  private static let modelDefaultsKey = "openai_model"
  private static let refreshIntervalDefaultsKey = "refresh_interval_seconds"
  private static let dataCollectionModeDefaultsKey = "data_collection_mode"
  private static let localSessionRecencySeconds: TimeInterval = 12 * 60 * 60

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
    dataCollectionMode = mode
    UserDefaults.standard.set(mode.rawValue, forKey: Self.dataCollectionModeDefaultsKey)

    // Defer follow-up publishes to avoid emitting multiple changes during picker view updates.
    DispatchQueue.main.async { [weak self] in
      self?.errorText = nil
      self?.refresh()
    }
  }

  func setAPIKey(_ value: String) {
    guard apiKey != value else { return }
    apiKey = value

    // Defer keychain write outside the immediate view update cycle.
    DispatchQueue.main.async { [weak self] in
      self?.environment.apiKeyStore.save(apiKey: value)
    }
  }

  func quit() {
    NSApplication.shared.terminate(nil)
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
    } catch {
      errorText = mappedErrorText(error)
      statusText = "Last attempt \(Self.timeFormatter.string(from: Date()))"
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
    } catch {
      snapshot = nil
      errorText = error.localizedDescription
      if force {
        statusText = "Local session attempt \(Self.timeFormatter.string(from: Date()))"
      }
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

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .medium
    return formatter
  }()
}
