import Foundation

struct CodexSessionRateLimitService: LocalSessionRateLimitServiceProtocol {
  enum Error: LocalizedError {
    case sessionsFolderNotFound
    case noRateLimitData

    var errorDescription: String? {
      switch self {
        case .sessionsFolderNotFound:
          return String(localized: "service.codex_sessions.folder_not_found")
        case .noRateLimitData:
          return String(localized: "service.codex_sessions.no_data")
      }
    }
  }

  func loadLatest(maxAge: TimeInterval? = nil) throws -> SessionRateLimitSnapshot {
    let sessionsPath = NSString(string: "~/.codex/sessions").expandingTildeInPath
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: sessionsPath, isDirectory: &isDirectory), isDirectory.boolValue else {
      throw Error.sessionsFolderNotFound
    }

    let files = try allSessionFiles(in: URL(fileURLWithPath: sessionsPath))
    let now = Date()
    for file in files {
      if let maxAge, file.date < now.addingTimeInterval(-maxAge) {
        break
      }
      if let snapshot = try parseLatestRateLimit(in: file.url) {
        return snapshot
      }
    }

    throw Error.noRateLimitData
  }

  private func allSessionFiles(in root: URL) throws -> [(url: URL, date: Date)] {
    guard let enumerator = FileManager.default.enumerator(
      at: root,
      includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    var files: [(url: URL, date: Date)] = []
    for case let fileURL as URL in enumerator {
      guard fileURL.pathExtension == "jsonl" else { continue }
      let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])
      guard values.isRegularFile == true else { continue }
      files.append((fileURL, values.contentModificationDate ?? .distantPast))
    }

    return files.sorted { $0.date > $1.date }
  }

  private func parseLatestRateLimit(in fileURL: URL) throws -> SessionRateLimitSnapshot? {
    let content = try String(contentsOf: fileURL, encoding: .utf8)
    for line in content.split(whereSeparator: \.isNewline).reversed() {
      guard line.contains("\"token_count\""), line.contains("\"rate_limits\"") else { continue }
      guard let data = String(line).data(using: .utf8) else { continue }
      guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
      guard let payload = root["payload"] as? [String: Any],
            (payload["type"] as? String) == "token_count",
            let rateLimits = (payload["rate_limits"] as? [String: Any])
              ?? ((payload["info"] as? [String: Any])?["rate_limits"] as? [String: Any])
      else { continue }

      let primary = rateLimits["primary"] as? [String: Any]
      let secondary = rateLimits["secondary"] as? [String: Any]

      return SessionRateLimitSnapshot(
        primaryUsedPercent: primary?["used_percent"] as? Double,
        primaryWindowMinutes: primary?["window_minutes"] as? Int,
        primaryResetsAt: epochDate(primary?["resets_at"]),
        secondaryUsedPercent: secondary?["used_percent"] as? Double,
        secondaryWindowMinutes: secondary?["window_minutes"] as? Int,
        secondaryResetsAt: epochDate(secondary?["resets_at"])
      )
    }

    return nil
  }

  private func epochDate(_ value: Any?) -> Date? {
    if let intValue = value as? Int {
      return Date(timeIntervalSince1970: TimeInterval(intValue))
    }
    if let doubleValue = value as? Double {
      return Date(timeIntervalSince1970: doubleValue)
    }
    return nil
  }
}
